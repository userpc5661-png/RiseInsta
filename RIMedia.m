#import "RICommon.h"
#import "RITargets.h"
#import "RIMediaResolver.h"
#import <QuartzCore/QuartzCore.h>

static __weak id RIStoryController;
void RITrackStoryController(id controller) { RIStoryController=controller; }

static NSDictionary *RIFindMedia(UIView *view,UIViewController *host) {
    NSMutableArray *queue=[NSMutableArray array];
    UIResponder *responder=view;
    for (NSUInteger i=0; responder && i<64; i++,responder=responder.nextResponder) [queue addObject:responder];
    if (host) [queue addObject:host];
    BOOL story=[NSStringFromClass(view.class) containsString:@"Story"] || [NSStringFromClass(host.class) containsString:@"Story"];
    if (story) {
        id section=RIStoryController;
        id item=RIReferenceField(section,@"currentStoryItem");
        if (item) [queue insertObject:item atIndex:0];
    }
    BOOL avatar=[NSStringFromClass(view.class) containsString:@"ProfilePicture"];
    NSHashTable *visited=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSMutableArray *classes=[NSMutableArray array];
    for (NSUInteger index=0; index<queue.count && index<192; index++) {
        id object=queue[index]; if ([visited containsObject:object]) continue;
        [visited addObject:object];
        if (classes.count<12) [classes addObject:NSStringFromClass([object class])];
        NSDictionary *result=RIResolveReferenceMedia(object,avatar);
        if (result) { RILog(@"Media resolved via %@",NSStringFromClass([object class])); return result; }
        if (queue.count<192) for (NSString *key in RIModelGetters()) {
            id next=RIReferenceField(object,key);
            if (next && next!=object && ![next isKindOfClass:NSString.class] && ![next isKindOfClass:NSNumber.class] && queue.count<192) [queue addObject:next];
        }
        if ([object isKindOfClass:UIViewController.class]) {
            for (UIViewController *child in ((UIViewController *)object).childViewControllers)
                if (child.viewIfLoaded.window && queue.count<192) [queue addObject:child];
        }
    }
    RILog(@"No media in reference paths. Classes: %@",[classes componentsJoinedByString:@", "]);
    return nil;
}

static NSDictionary *RIFindVisibleMedia(UIViewController *host) {
    NSDictionary *result=RIFindMedia(host.view,host); if (result) return result;
    NSMutableArray<UIView *> *views=[NSMutableArray arrayWithObject:host.view];
    NSUInteger budget=0;
    while (views.count && budget++<256) {
        UIView *view=views.lastObject; [views removeLastObject];
        if (view.hidden || view.alpha<0.01 || !view.window) continue;
        if ([RIMediaViewClasses() containsObject:NSStringFromClass(view.class)]) {
            result=RIFindMedia(view,host); if (result) return result;
        }
        [views addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void RIPresentMedia(NSDictionary *resolved,UIView *anchor,UIViewController *host) {
    NSArray<NSDictionary *> *items=resolved[@"items"];
    if (!items.count) {
        RIAlert(@"RiseInsta",@"لم تُعثر على وسائط عبر مسارات Beegram في هذه الشاشة. انسخ تقرير التشخيص بعد محاولة التحميل.",host); return;
    }
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"وسائط RiseInsta" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [items enumerateObjectsUsingBlock:^(NSDictionary *item,NSUInteger index,BOOL *stop){
        NSUInteger actual=item[@"index"] ? [item[@"index"] unsignedIntegerValue] : index;
        NSString *suffix=items.count>1 ? [NSString stringWithFormat:@" — %lu",(unsigned long)actual+1] : @"";
        [menu addAction:[UIAlertAction actionWithTitle:[@"تحميل" stringByAppendingString:suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:NO from:host]; }]];
        [menu addAction:[UIAlertAction actionWithTitle:[@"تحميل ومشاركة" stringByAppendingString:suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:YES from:host]; }]];
    }];
    id object=resolved[@"object"], caption=RIReferenceField(object,@"caption");
    if (![caption isKindOfClass:NSString.class]) caption=RIReferenceField(caption,@"text");
    if ([caption isKindOfClass:NSString.class] && [caption length]) [menu addAction:[UIAlertAction actionWithTitle:@"نسخ الوصف" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ UIPasteboard.generalPasteboard.string=caption; }]];
    id username=RIReferenceField(RIReferenceField(object,@"user") ?: object,@"username");
    if ([username isKindOfClass:NSString.class] && [username length]) [menu addAction:[UIAlertAction actionWithTitle:@"نسخ اسم المستخدم" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ UIPasteboard.generalPasteboard.string=username; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    UIView *source=anchor.window ? anchor : host.view;
    menu.popoverPresentationController.sourceView=source;
    menu.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(source.bounds),CGRectGetMidY(source.bounds),1,1);
    [host presentViewController:menu animated:YES completion:nil];
}
void RIShowCurrentMediaMenu(UIViewController *hint) {
    dispatch_async(dispatch_get_main_queue(),^{
        UIViewController *host=RITopController(hint);
        if (!RIPref(RI_DOWNLOAD,YES)) { RIAlert(@"RiseInsta",@"فعّل قائمة الوسائط من الإعدادات أولًا",host); return; }
        if (host && ![host isKindOfClass:UIAlertController.class]) RIPresentMedia(RIFindVisibleMedia(host),host.view,host);
    });
}

static char RIMediaGestureKey,RIMediaButtonKey;
@interface RIMediaGesture : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic,strong) NSHashTable<UIView *> *views;
+ (instancetype)shared;
@end
@implementation RIMediaGesture
+ (instancetype)shared {
    static RIMediaGesture *manager; static dispatch_once_t once;
    dispatch_once(&once,^{
        manager=[self new]; manager.views=[NSHashTable weakObjectsHashTable];
        [NSNotificationCenter.defaultCenter addObserverForName:RISettingsChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            for (UIView *view in manager.views) {
                UIButton *button=objc_getAssociatedObject(view,&RIMediaButtonKey);
                button.hidden=!RIPref(RI_DOWNLOAD,YES);
            }
        }];
    }); return manager;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture { return RIPref(RI_DOWNLOAD,YES); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { return YES; }
- (void)showFrom:(UIView *)view {
    if (!RIPref(RI_DOWNLOAD,YES)) return;
    static NSTimeInterval lastOpen=0; NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if (now-lastOpen<0.7) return; lastOpen=now;
    UIViewController *host=RITopController(nil);
    if (host && ![host isKindOfClass:UIAlertController.class]) RIPresentMedia(RIFindMedia(view,host),view,host);
}
- (void)open:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state==UIGestureRecognizerStateBegan) [self showFrom:gesture.view];
}
- (void)tap:(UIButton *)button { [self showFrom:button.superview]; }
@end
void RIAttachMediaMenu(UIView *view) {
    if (!objc_getAssociatedObject(view,&RIMediaGestureKey)) {
        UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:RIMediaGesture.shared action:@selector(open:)];
        gesture.numberOfTouchesRequired=2; gesture.minimumPressDuration=0.55; gesture.cancelsTouchesInView=NO; gesture.delegate=RIMediaGesture.shared;
        view.userInteractionEnabled=YES; [view addGestureRecognizer:gesture];
        objc_setAssociatedObject(view,&RIMediaGestureKey,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [RIMediaGesture.shared.views addObject:view];
    }
    // Keep narrow Instagram action bars intact; the gear menu is always an alternative.
    if (view.bounds.size.width>=120 && view.bounds.size.height>=100 && !objc_getAssociatedObject(view,&RIMediaButtonKey)) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints=NO; button.backgroundColor=UIColor.secondarySystemBackgroundColor;
        button.layer.cornerRadius=22; button.accessibilityLabel=@"تحميل الوسائط — RiseInsta";
        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"] forState:UIControlStateNormal];
        [button addTarget:RIMediaGesture.shared action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(view,&RIMediaButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [view addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.widthAnchor constraintEqualToConstant:44],[button.heightAnchor constraintEqualToConstant:44],
            [button.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:8],
            [button.topAnchor constraintEqualToAnchor:view.topAnchor constant:8]
        ]];
    }
    UIButton *button=objc_getAssociatedObject(view,&RIMediaButtonKey); button.hidden=!RIPref(RI_DOWNLOAD,YES);
}
