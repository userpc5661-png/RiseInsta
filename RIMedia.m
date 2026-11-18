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

static char RIMediaGestureKey,RIMediaButtonKey,RIMediaButtonSourceKey,RIProfileContextKey,RIStackAxisKey,RIPostUFIStatusKey,RIOriginalFramesKey,RIOriginalParentWidthKey,RIParentStackConfigKey;
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
- (void)openSettings:(UIButton *)button { RIShowSettings(nil); }
@end
static CGFloat RIBtnSize(void) { return 44.0; }
static void RITree(UIView *root, NSMutableArray<UIView *> *out, NSUInteger *budget);
static BOOL RITextContainsAny(NSString *text, NSArray<NSString *> *terms) {
    NSString *value=text.lowercaseString;
    for (NSString *term in terms) if ([value containsString:term]) return YES;
    return NO;
}
static CGRect RIHeartFrameInRail(UIView *rail) {
    NSMutableArray<UIView *> *tree=[NSMutableArray array]; NSUInteger budget=0; RITree(rail,tree,&budget);
    NSArray<NSString *> *terms=@[@"like",@"heart",@"reaction",@"أعجب",@"إعجاب"];
    for (UIView *candidate in tree) {
        if (![candidate isKindOfClass:UIControl.class]) continue;
        UIControl *control=(UIControl *)candidate;
        BOOL match=RITextContainsAny(control.accessibilityLabel ?: @"",terms) || RITextContainsAny(control.accessibilityIdentifier ?: @"",terms);
        if (!match) for (id target in control.allTargets) for (NSString *action in [control actionsForTarget:target forControlEvent:UIControlEventAllEvents])
            if (RITextContainsAny(action,terms)) { match=YES; break; }
        if (match && CGRectGetWidth(control.bounds)>8 && CGRectGetHeight(control.bounds)>8) return [control convertRect:control.bounds toView:rail];
    }
    return CGRectNull;
}
static void RITree(UIView *root, NSMutableArray<UIView *> *out, NSUInteger *budget) {
    if (!root || *budget>=250) return; (*budget)++; [out addObject:root];
    for (UIView *child in root.subviews) RITree(child,out,budget);
}
static NSArray<UIView *> *RIUFIActionItems(UIView *parent) {
    NSMutableArray<UIView *> *items=[NSMutableArray array];
    for (UIView *child in parent.subviews)
        if ([NSStringFromClass(child.class) containsString:@"IGUFIButtonWithCountsView"]) [items addObject:child];
    return items;
}
static UIView *RIActionParent(UIView *root) {
    NSMutableArray<UIView *> *tree=[NSMutableArray array]; NSUInteger budget=0; RITree(root,tree,&budget);
    NSMutableDictionary<NSValue *,NSMutableArray<UIView *> *> *groups=[NSMutableDictionary dictionary];
    for (UIView *candidate in tree) {
        if (![NSStringFromClass(candidate.class) containsString:@"IGUFIButtonWithCountsView"] || !candidate.superview) continue;
        NSValue *key=[NSValue valueWithNonretainedObject:candidate.superview];
        if (!groups[key]) groups[key]=[NSMutableArray array]; [groups[key] addObject:candidate];
    }
    UIView *best=nil; NSUInteger count=0;
    for (NSValue *key in groups) if (groups[key].count>count) { best=key.nonretainedObjectValue; count=groups[key].count; }
    return count>=3 ? best : nil;
}
static NSUInteger RIVerticalizeCountStack(UIView *item, BOOL enabled) {
    NSMutableArray<UIView *> *tree=[NSMutableArray array]; NSUInteger budget=0; RITree(item,tree,&budget);
    NSUInteger matched=0;
    for (UIView *view in tree) if ([view isKindOfClass:UIStackView.class]) {
        UIStackView *stack=(UIStackView *)view; BOOL hasIcon=NO,hasLabel=NO;
        for (UIView *child in stack.arrangedSubviews) {
            NSMutableArray<UIView *> *subtree=[NSMutableArray array]; NSUInteger childBudget=0; RITree(child,subtree,&childBudget);
            for (UIView *part in subtree) { if ([part isKindOfClass:UIImageView.class]) hasIcon=YES; if ([part isKindOfClass:UILabel.class]) hasLabel=YES; }
        }
        if (!hasIcon || !hasLabel) continue;
        matched++;
        NSDictionary *original=objc_getAssociatedObject(stack,&RIStackAxisKey);
        if (!original) { original=@{@"axis":@(stack.axis),@"alignment":@(stack.alignment),@"spacing":@(stack.spacing)}; objc_setAssociatedObject(stack,&RIStackAxisKey,original,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        stack.axis=enabled ? UILayoutConstraintAxisVertical : (UILayoutConstraintAxis)[original[@"axis"] integerValue];
        if (enabled) { stack.alignment=UIStackViewAlignmentCenter; stack.spacing=1.0; }
        else { stack.alignment=(UIStackViewAlignment)[original[@"alignment"] integerValue]; stack.spacing=[original[@"spacing"] doubleValue]; }
    }
    return matched;
}
static void RILayoutPostActions(UIView *root, UIView *parent, UIButton *download) {
    NSArray<UIView *> *items=RIUFIActionItems(parent); if (items.count<3 || !parent.bounds.size.width) { download.hidden=YES; return; }
    NSMutableDictionary<NSValue *,NSValue *> *originalFrames=objc_getAssociatedObject(parent,&RIOriginalFramesKey);
    NSNumber *storedWidth=objc_getAssociatedObject(parent,&RIOriginalParentWidthKey);
    if (!originalFrames || !storedWidth) {
        originalFrames=[NSMutableDictionary dictionary];
        for (UIView *item in items) originalFrames[[NSValue valueWithNonretainedObject:item]]=[NSValue valueWithCGRect:item.frame];
        storedWidth=@(CGRectGetWidth(parent.bounds));
        objc_setAssociatedObject(parent,&RIOriginalFramesKey,originalFrames,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(parent,&RIOriginalParentWidthKey,storedWidth,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    BOOL layoutEnabled=RIPref(@"editor_post",YES);
    BOOL downloadEnabled=layoutEnabled && RIPref(RI_DOWNLOAD,YES);
    NSMutableArray<UIView *> *ordered=[items mutableCopy];
    [ordered sortUsingComparator:^NSComparisonResult(UIView *a,UIView *b){ return CGRectGetMinX(a.frame)<CGRectGetMinX(b.frame)?NSOrderedAscending:(CGRectGetMinX(a.frame)>CGRectGetMinX(b.frame)?NSOrderedDescending:NSOrderedSame); }];
    // Keep Instagram's native save action untouched; insert download immediately before the trailing native action.
    UIView *save=ordered.lastObject;
    NSUInteger countStacks=0; for (UIView *item in ordered) countStacks+=RIVerticalizeCountStack(item,layoutEnabled);
    if (!objc_getAssociatedObject(root,&RIPostUFIStatusKey)) {
        objc_setAssociatedObject(root,&RIPostUFIStatusKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        RILog(@"Post UFI integration: nativeCells=%lu countStacksMatched=%lu vertical=%d",(unsigned long)items.count,(unsigned long)countStacks,layoutEnabled);
    }
    if ([parent isKindOfClass:UIStackView.class]) {
        UIStackView *stack=(UIStackView *)parent;
        NSDictionary *config=objc_getAssociatedObject(stack,&RIParentStackConfigKey);
        if (downloadEnabled && !config) {
            config=@{@"axis":@(stack.axis),@"alignment":@(stack.alignment),@"distribution":@(stack.distribution),@"spacing":@(stack.spacing)};
            objc_setAssociatedObject(stack,&RIParentStackConfigKey,config,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        if (!downloadEnabled) {
            if ([stack.arrangedSubviews containsObject:download]) { [stack removeArrangedSubview:download]; [download removeFromSuperview]; }
            if (config) { stack.axis=(UILayoutConstraintAxis)[config[@"axis"] integerValue]; stack.alignment=(UIStackViewAlignment)[config[@"alignment"] integerValue]; stack.distribution=(UIStackViewDistribution)[config[@"distribution"] integerValue]; stack.spacing=[config[@"spacing"] doubleValue]; }
            download.hidden=YES; return;
        }
        NSUInteger insertIndex=[ordered indexOfObject:save];
        if (![stack.arrangedSubviews containsObject:download]) [stack insertArrangedSubview:download atIndex:MIN(insertIndex,stack.arrangedSubviews.count)];
        stack.axis=UILayoutConstraintAxisHorizontal; stack.alignment=UIStackViewAlignmentFill; stack.distribution=UIStackViewDistributionFillEqually;
        download.hidden=NO; download.tintColor=UIColor.whiteColor;
        [download setImage:[RIDownloadIcon() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        download.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter; download.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter; download.imageView.contentMode=UIViewContentModeScaleAspectFit;
        return;
    }
    if (!layoutEnabled) {
        CGFloat scale=CGRectGetWidth(parent.bounds)/MAX(1.0,storedWidth.doubleValue),height=CGRectGetHeight(parent.bounds);
        for (UIView *item in items) {
            CGRect frame=[originalFrames[[NSValue valueWithNonretainedObject:item]] CGRectValue];
            frame.origin.x*=scale; frame.size.width*=scale; frame.size.height=height; item.frame=frame;
        }
        download.hidden=YES; return;
    }
    if (downloadEnabled) { NSUInteger saveIndex=[ordered indexOfObject:save]; [ordered insertObject:download atIndex:saveIndex]; }
    CGFloat width=CGRectGetWidth(parent.bounds)/(CGFloat)ordered.count, height=CGRectGetHeight(parent.bounds);
    for (NSUInteger i=0;i<ordered.count;i++) {
        UIView *item=ordered[i]; item.frame=CGRectMake((CGFloat)i*width,0,width,height);
        if (item==download) {
            download.hidden=NO; download.tintColor=UIColor.whiteColor;
            [download setImage:[RIDownloadIcon() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            download.contentHorizontalAlignment=UIControlContentHorizontalAlignmentCenter; download.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
            download.imageView.contentMode=UIViewContentModeScaleAspectFit;
            download.accessibilityLabel=@"تحميل الوسائط — RiseInsta";
        } else { item.clipsToBounds=NO; [item setNeedsLayout]; }
    }
    if (!downloadEnabled) download.hidden=YES;
}
void RIAttachMediaMenu(UIView *view) {
    NSString *viewName=NSStringFromClass(view.class); BOOL story=[viewName containsString:@"Story"]; BOOL profile=[viewName containsString:@"ProfilePicture"];
    if (!objc_getAssociatedObject(view,&RIMediaGestureKey)) {
        UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:RIMediaGesture.shared action:@selector(open:)];
        gesture.numberOfTouchesRequired=(story||profile)?1:2; gesture.minimumPressDuration=0.55; gesture.cancelsTouchesInView=NO; gesture.delegate=RIMediaGesture.shared;
        view.userInteractionEnabled=YES; [view addGestureRecognizer:gesture];
        objc_setAssociatedObject(view,&RIMediaGestureKey,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC); [RIMediaGesture.shared.views addObject:view];
    }
    NSString *name=NSStringFromClass(view.class); BOOL post=[name isEqualToString:@"IGUFIInteractionCountsView"];
    BOOL reels=[name containsString:@"IGSundialViewerVerticalUFI"];
    if ((post || (reels && RIPref(@"editor_reels",YES))) && !objc_getAssociatedObject(view,&RIMediaButtonKey)) {
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem]; button.tag=7102; button.backgroundColor=UIColor.clearColor;
        button.accessibilityLabel=@"تحميل الوسائط — RiseInsta"; [button setImage:RIDownloadIcon() forState:UIControlStateNormal];
        [button addTarget:RIMediaGesture.shared action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
        UIView *parent=post ? (RIActionParent(view) ?: view) : view;
        objc_setAssociatedObject(view,&RIMediaButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button,&RIMediaButtonSourceKey,view,OBJC_ASSOCIATION_ASSIGN);
        [parent addSubview:button];
    }
    UIButton *button=objc_getAssociatedObject(view,&RIMediaButtonKey);
    if (button) { button.hidden=!RIPref(RI_DOWNLOAD,YES) || (post&&!RIPref(@"editor_post",YES)) || (reels&&!RIPref(@"editor_reels",YES));
        if(post) {
            UIView *parent=RIActionParent(view);
            if (!parent) button.hidden=YES;
            else { if (button.superview!=parent) { [button removeFromSuperview]; [parent addSubview:button]; } RILayoutPostActions(view,parent,button); }
        }
        else if (reels) {
            CGRect heart=RIHeartFrameInRail(view); CGFloat z=RIBtnSize();
            if (CGRectIsNull(heart)) {
                // Instagram 456 may not provide accessibility names on the rail.
                // Fall back to a visible position within the rail rather than hiding the button.
                CGFloat y=MAX(4,MIN(CGRectGetHeight(view.bounds)-z,CGRectGetHeight(view.bounds)*0.32));
                button.frame=CGRectMake(MAX(0,(CGRectGetWidth(view.bounds)-z)*0.5),y,z,z);
                RILog(@"Reels heart class not resolved; using safe rail fallback");
            } else {
                button.frame=CGRectMake(CGRectGetMidX(heart)-z*0.5,MAX(0,CGRectGetMinY(heart)-z-3),z,z);
                button.tintColor=UIColor.whiteColor; button.backgroundColor=UIColor.clearColor;
                [button setImage:[RIDownloadIcon() imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
            }
        }
        if (!button.hidden) [button.superview bringSubviewToFront:button];
    }
    // The reel rail and post UFI are supported; media surfaces keep the gesture-only affordance.
}
void RIAttachContextMenuButton(UIView *view) {
    NSString *name=NSStringFromClass(view.class);
    BOOL navButton=[name containsString:@"IGBadgedNavigationButton"];
    NSString *identity=view.accessibilityIdentifier.lowercaseString ?: @"";
    NSString *label=view.accessibilityLabel.lowercaseString ?: @"";
    BOOL profile=[identity containsString:@"profile-more"] || [identity containsString:@"profile_menu"] ||
                 [identity containsString:@"profile-menu"] ||
                 [label containsString:@"profile options"] || [label containsString:@"خيارات الملف"];
    if (!navButton || !profile) return;
    UIView *parent=view.superview; if(!parent) return;
    void *assoc=&RIProfileContextKey;
    UIButton *button=objc_getAssociatedObject(parent,assoc);
    if(!button) { button=[UIButton buttonWithType:UIButtonTypeSystem]; [button setImage:[UIImage systemImageNamed:@"line.3.horizontal"] forState:UIControlStateNormal]; button.accessibilityLabel=@"قائمة RiseInsta"; [button addTarget:RIMediaGesture.shared action:@selector(openSettings:) forControlEvents:UIControlEventTouchUpInside]; [parent addSubview:button]; objc_setAssociatedObject(parent,assoc,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    CGFloat s=40; button.frame=CGRectMake(MAX(0,CGRectGetMinX(view.frame)-s-4),CGRectGetMinY(view.frame)+2,s,s); button.tintColor=UIColor.labelColor;
    button.hidden=NO; button.userInteractionEnabled=YES; [parent bringSubviewToFront:button];
}
