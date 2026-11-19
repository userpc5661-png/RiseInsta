#import "RICommon.h"
#import "RITargets.h"
#import "RIMediaResolver.h"
#import "RIIcons.h"
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

static NSUInteger RICurrentCarouselIndex(UIViewController *host, UIView *anchor, NSUInteger count) {
    if (count<2 || !host.viewIfLoaded) return 0;
    NSMutableArray<UIView *> *queue=[NSMutableArray arrayWithObject:host.view]; UIPageControl *best=nil; CGFloat bestDistance=CGFLOAT_MAX; NSUInteger visited=0;
    while (queue.count && visited++<1000) {
        UIView *view=queue.lastObject; [queue removeLastObject];
        if (view.hidden || view.alpha<0.02 || !view.window) continue;
        if ([view isKindOfClass:UIPageControl.class]) {
            UIPageControl *page=(UIPageControl *)view;
            if (page.numberOfPages==(NSInteger)count && page.currentPage>=0 && page.currentPage<(NSInteger)count) {
                CGRect anchorFrame=anchor.window ? [anchor convertRect:anchor.bounds toView:host.view] : host.view.bounds;
                CGFloat distance=fabs(CGRectGetMidY([page convertRect:page.bounds toView:host.view])-CGRectGetMidY(anchorFrame));
                if (distance<bestDistance) { best=page; bestDistance=distance; }
            }
        }
        [queue addObjectsFromArray:view.subviews];
    }
    if (best) return (NSUInteger)best.currentPage;
    RILog(@"Carousel page indicator not found for %lu items; using first item",(unsigned long)count);
    return 0;
}

static void RIPresentMedia(NSDictionary *resolved,UIView *anchor,UIViewController *host) {
    NSArray<NSDictionary *> *allItems=resolved[@"items"];
    NSArray<NSDictionary *> *items=allItems;
    if (allItems.count>1) {
        NSUInteger page=RICurrentCarouselIndex(host,anchor,allItems.count); NSDictionary *current=nil;
        for (NSDictionary *candidate in allItems) if ([candidate[@"index"] respondsToSelector:@selector(unsignedIntegerValue)] && [candidate[@"index"] unsignedIntegerValue]==page) { current=candidate; break; }
        if (!current && page<allItems.count) current=allItems[page];
        if (current) items=@[current];
    }
    if (!items.count) {
        RIAlert(@"RiseInsta",@"لم تُعثر على وسائط متوافقة في هذه الشاشة. انسخ تقرير التشخيص بعد محاولة التحميل.",host); return;
    }
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"وسائط RiseInsta" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [items enumerateObjectsUsingBlock:^(NSDictionary *item,NSUInteger index,BOOL *stop){
        [menu addAction:[UIAlertAction actionWithTitle:@"تحميل" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:NO from:host]; }]];
        [menu addAction:[UIAlertAction actionWithTitle:@"تحميل ومشاركة" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:YES from:host]; }]];
    }];
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

static char RIMediaGestureKey,RIMediaButtonKey,RIMediaButtonSourceKey,RIProfileContextKey;
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
    if (host && ![host isKindOfClass:UIAlertController.class]) {
        NSDictionary *media=RIFindMedia(view,host);
        if (!media) media=RIFindVisibleMedia(host);
        RIPresentMedia(media,view,host);
    }
}
- (void)open:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state==UIGestureRecognizerStateBegan) [self showFrom:gesture.view];
}
- (void)tap:(UIButton *)button {
    UIView *source=objc_getAssociatedObject(button,&RIMediaButtonSourceKey);
    [self showFrom:source.window ? source : button.superview];
}
- (void)openProfileSettings:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state==UIGestureRecognizerStateBegan) RIShowSettings(nil);
}
@end
// RiseInsta-owned controls must never resize/reorder Instagram's native controls.
// A button is shown only when its entire tap area has an unused slot.
static BOOL RINativeControlOverlaps(UIView *root, CGRect candidate, UIButton *ours) {
    NSMutableArray<UIView *> *pending=[NSMutableArray arrayWithObject:root];
    NSUInteger scanned=0;
    while (pending.count && scanned++<350) {
        UIView *v=pending.lastObject; [pending removeLastObject];
        if (v==ours || v.hidden || v.alpha<0.05) continue;
        BOOL nativeAction=([v isKindOfClass:UIControl.class] && v!=root) ||
            [NSStringFromClass(v.class) containsString:@"IGUFIButtonWithCountsView"];
        if (nativeAction && CGRectGetWidth(v.bounds)>8 && CGRectGetHeight(v.bounds)>8) {
            CGRect frame=[v convertRect:v.bounds toView:root];
            if (CGRectIntersectsRect(CGRectInset(candidate,-3,-3),frame)) return YES;
        }
        [pending addObjectsFromArray:v.subviews];
    }
    return NO;
}
static void RIPositionDownloadButton(UIView *view, UIButton *button, BOOL reels) {
    if (!view || !button) return;
    BOOL enabled=RIPref(RI_DOWNLOAD,YES) &&
        RIPref(reels ? @"editor_reels" : @"editor_post",YES);
    button.hidden=YES;
    if (!enabled || CGRectGetWidth(view.bounds)<40 || CGRectGetHeight(view.bounds)<36) return;
    // Discover an empty slot from actual on-screen controls, not assumptions
    // about the last Instagram button being Save or Like.
    CGFloat width=CGRectGetWidth(view.bounds);
    CGFloat height=CGRectGetHeight(view.bounds);
    CGFloat size=reels?40.0:34.0;
    CGRect selected=CGRectNull;
    if (reels) {
        CGFloat x=(width-size)*0.5;
        for (CGFloat y=4;y+size<=height-2;y+=8) {
            CGRect slot=CGRectMake(x,y,size,size);
            if (!RINativeControlOverlaps(view,slot,button)) { selected=slot; break; }
        }
    } else {
        for (CGFloat x=width-size-2;x>=2;x-=6) {
            CGRect slot=CGRectMake(x,(height-size)*0.5,size,size);
            if (!RINativeControlOverlaps(view,slot,button)) { selected=slot; break; }
        }
    }
    if (CGRectIsNull(selected)) {
        // Preserve Instagram buttons; the existing long-press download remains.
        return;
    }
    button.frame=selected;
    button.tintColor=UIColor.labelColor;
    button.accessibilityLabel=@"تحميل الوسائط — RiseInsta";
    [button setImage:[RIDownloadIcon() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
           forState:UIControlStateNormal];
    button.hidden=NO;
    [view bringSubviewToFront:button];
}
void RIAttachMediaMenu(UIView *view) {
    NSString *viewName=NSStringFromClass(view.class); BOOL story=[viewName containsString:@"Story"]; BOOL profile=[viewName containsString:@"ProfilePicture"];
    if (!objc_getAssociatedObject(view,&RIMediaGestureKey)) {
        UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:RIMediaGesture.shared action:@selector(open:)];
        gesture.numberOfTouchesRequired=(story||profile)?1:2; gesture.minimumPressDuration=0.55; gesture.cancelsTouchesInView=NO; gesture.delegate=RIMediaGesture.shared;
        view.userInteractionEnabled=YES; [view addGestureRecognizer:gesture];
        objc_setAssociatedObject(view,&RIMediaGestureKey,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC); [RIMediaGesture.shared.views addObject:view];
    }
    NSString *name=NSStringFromClass(view.class);
    BOOL post=[name isEqualToString:@"IGUFIInteractionCountsView"];
    BOOL reels=[name containsString:@"IGSundialViewerVerticalUFI"];
    if (!(post || reels)) return;
    UIButton *button=objc_getAssociatedObject(view,&RIMediaButtonKey);
    if (!button) {
        button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.tag=7102;
        button.backgroundColor=UIColor.clearColor;
        [button addTarget:RIMediaGesture.shared action:@selector(tap:)
         forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(view,&RIMediaButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button,&RIMediaButtonSourceKey,view,OBJC_ASSOCIATION_ASSIGN);
        [view addSubview:button];
    }
    if (button.superview!=view) { [button removeFromSuperview]; [view addSubview:button]; }
    RIPositionDownloadButton(view,button,reels);
}
// Reuse Instagram's own profile More control instead of placing a second
// floating button that can overlap its native hit target.
void RIAttachContextMenuButton(UIView *view) {
    NSString *name=NSStringFromClass(view.class);
    if (![name containsString:@"IGBadgedNavigationButton"]) return;
    NSString *identity=view.accessibilityIdentifier.lowercaseString ?: @"";
    NSString *label=view.accessibilityLabel.lowercaseString ?: @"";
    BOOL profile=[identity containsString:@"profile-more"] ||
        [identity containsString:@"profile_menu"] ||
        [identity containsString:@"profile-menu"] ||
        [label containsString:@"profile options"] ||
        [label containsString:@"خيارات الملف"];
    if (!profile || objc_getAssociatedObject(view,&RIProfileContextKey)) return;
    UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc]
        initWithTarget:RIMediaGesture.shared action:@selector(openProfileSettings:)];
    hold.minimumPressDuration=0.65;
    hold.cancelsTouchesInView=NO;
    hold.delegate=RIMediaGesture.shared;
    [view addGestureRecognizer:hold];
    objc_setAssociatedObject(view,&RIProfileContextKey,hold,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
