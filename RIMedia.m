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

static char RIMediaGestureKey,RIMediaButtonKey,RIProfileContextKey,RISettingsContextKey;
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
                RIAttachMediaMenu(view);
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
- (void)openSettings:(UIButton *)button { RIShowSettings(nil); }
@end
static NSString *RIStringPref(NSString *key, NSString *fallback) { id v=[[NSUserDefaults standardUserDefaults] objectForKey:[@"com.riseinsta." stringByAppendingString:key]]; return [v isKindOfClass:NSString.class] ? v : fallback; }
static CGFloat RIBtnSize(void) { return MAX(32,MIN(56,RIStringPref(@"editor_size",@"40").doubleValue)); }
static NSString *RIIcon(void) { return RIStringPref(@"editor_icon",@"arrow.down.circle.fill"); }
static void RIPlacePostButton(UIButton *button,UIView *view) {
    CGFloat size=RIBtnSize(); NSString *place=RIStringPref(@"editor_post_position",@"center");
    CGFloat x=[place isEqualToString:@"left"]?CGRectGetMinX(view.bounds)+232:([place isEqualToString:@"right"]?CGRectGetMaxX(view.bounds)-size-50:CGRectGetMinX(view.bounds)+CGRectGetWidth(view.bounds)*0.72-size/2);
    button.frame=CGRectMake(x,CGRectGetMidY(view.bounds)-size/2,size,size);
}
void RIAttachMediaMenu(UIView *view) {
    BOOL story=[NSStringFromClass(view.class) containsString:@"Story"];
    if (!objc_getAssociatedObject(view,&RIMediaGestureKey)) {
        UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:RIMediaGesture.shared action:@selector(open:)];
        gesture.numberOfTouchesRequired=story?1:2; gesture.minimumPressDuration=0.55; gesture.cancelsTouchesInView=NO; gesture.delegate=RIMediaGesture.shared;
        view.userInteractionEnabled=YES; [view addGestureRecognizer:gesture];
        objc_setAssociatedObject(view,&RIMediaGestureKey,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC); [RIMediaGesture.shared.views addObject:view];
    }
    NSString *name=NSStringFromClass(view.class); BOOL post=[name isEqualToString:@"IGUFIInteractionCountsView"] || [name isEqualToString:@"IGUFIButtonBarView"];
    BOOL reels=[name containsString:@"IGSundialViewerVerticalUFI"];
    if (((post && RIPref(@"editor_post",YES)) || (reels && RIPref(@"editor_reels",YES))) && !objc_getAssociatedObject(view,&RIMediaButtonKey)) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.tag=7102; button.backgroundColor=UIColor.clearColor;
        button.accessibilityLabel=@"تحميل الوسائط — RiseInsta"; [button setImage:[UIImage systemImageNamed:RIIcon()] forState:UIControlStateNormal];
        [button addTarget:RIMediaGesture.shared action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(view,&RIMediaButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC); [view addSubview:button];
    }
    UIButton *button=objc_getAssociatedObject(view,&RIMediaButtonKey);
    if (button) { button.hidden=!RIPref(RI_DOWNLOAD,YES) || (post&&!RIPref(@"editor_post",YES)) || (reels&&!RIPref(@"editor_reels",YES));
        if(post) RIPlacePostButton(button,view); else { CGFloat z=RIBtnSize(); button.frame=CGRectMake((CGRectGetWidth(view.bounds)-z)/2,CGRectGetHeight(view.bounds)-z-54,z,z); }
        [button setImage:[UIImage systemImageNamed:RIIcon()] forState:UIControlStateNormal];
    }
    // The reel rail and post UFI are supported; media surfaces keep the gesture-only affordance.
} 
static BOOL RIContainsClass(UIView *root, NSString *needle) {
    NSMutableArray *todo=[NSMutableArray arrayWithObject:root]; NSUInteger n=0;
    while(todo.count && n++<300) { UIView *v=todo.lastObject; [todo removeLastObject]; if([NSStringFromClass(v.class) containsString:needle]) return YES; [todo addObjectsFromArray:v.subviews]; }
    return NO;
}
void RIAttachContextMenuButton(UIView *view) {
    NSString *name=NSStringFromClass(view.class); BOOL profile=[name containsString:@"IGBadgedNavigationButton"] && [view.accessibilityIdentifier isEqualToString:@"profile-more-button"];
    UIViewController *top=RITopController(nil);
    NSString *topName=top ? NSStringFromClass(top.view.class) : @"";
    BOOL settings=[name isEqualToString:@"IGNavigationBar"] && (RIContainsClass(view,@"IGSettingScreenView") || [topName containsString:@"IGSettingScreenView"]);
    if(!profile&&!settings) return;
    UIView *parent=profile?view.superview:view; if(!parent) return;
    void *assoc=profile?&RIProfileContextKey:&RISettingsContextKey;
    UIButton *button=objc_getAssociatedObject(parent,assoc);
    if(!button) { button=[UIButton buttonWithType:UIButtonTypeSystem]; [button setImage:[UIImage systemImageNamed:@"sparkles"] forState:UIControlStateNormal]; button.accessibilityLabel=@"RiseInsta"; [button addTarget:RIMediaGesture.shared action:@selector(openSettings:) forControlEvents:UIControlEventTouchUpInside]; [parent addSubview:button]; objc_setAssociatedObject(parent,assoc,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    CGFloat s=40; button.frame=CGRectMake(settings?CGRectGetMaxX(parent.bounds)-s-8:MAX(0,CGRectGetMinX(view.frame)-s-4),profile?CGRectGetMinY(view.frame)+2:7,s,s); button.tintColor=UIColor.labelColor;
    button.hidden=(profile&&!RIPref(@"editor_profile",YES)) || (settings&&!RIPref(@"editor_settings",YES));
}

