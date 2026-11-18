#import "RICommon.h"
#import <QuartzCore/QuartzCore.h>

static NSString *RIViewClassChain(Class cls) {
    NSMutableArray<NSString *> *names=[NSMutableArray array];
    for (Class current=cls; current && current!=NSObject.class; current=class_getSuperclass(current)) {
        [names addObject:NSStringFromClass(current) ?: @"?"];
        if (current==UIView.class) break;
    }
    return [names componentsJoinedByString:@" < "];
}

static NSString *RIControlActions(UIControl *control) {
    NSMutableOrderedSet<NSString *> *actions=[NSMutableOrderedSet orderedSet];
    NSArray<NSNumber *> *events=@[@(UIControlEventTouchUpInside),@(UIControlEventTouchDown),@(UIControlEventValueChanged)];
    for (id target in control.allTargets) {
        for (NSNumber *event in events) {
            for (NSString *action in [control actionsForTarget:target forControlEvent:event.unsignedIntegerValue])
                if (action.length) [actions addObject:action];
        }
    }
    return actions.count ? [actions.array componentsJoinedByString:@","] : @"-";
}

static void RIAppendView(NSMutableString *report, UIView *view, UIWindow *window, NSString *path, NSUInteger depth, NSUInteger *budget) {
    if (!view || !window || *budget>=700 || depth>45 || view.hidden || view.alpha<0.02 || (view!=window && view.window!=window)) return;
    CGRect frame=[view convertRect:view.bounds toView:window];
    if (!CGRectIntersectsRect(frame,window.bounds) && view!=window) return;
    (*budget)++;
    NSString *indent=[@"  " stringByPaddingToLength:MIN(depth*2,90) withString:@" " startingAtIndex:0];
    NSString *name=RIViewClassChain(view.class);
    NSString *identifier=view.accessibilityIdentifier.length ? view.accessibilityIdentifier : @"-";
    [report appendFormat:@"%@[%@] %@ frame=(%.1f,%.1f,%.1f,%.1f) alpha=%.2f hidden=%d axID=%@",
     indent,path,name,frame.origin.x,frame.origin.y,frame.size.width,frame.size.height,view.alpha,view.hidden,identifier];
    if ([view isKindOfClass:UIControl.class]) [report appendFormat:@" actions=%@",RIControlActions((UIControl *)view)];
    if ([view isKindOfClass:UIStackView.class]) {
        UIStackView *stack=(UIStackView *)view;
        [report appendFormat:@" stack(axis=%ld,alignment=%ld,distribution=%ld,spacing=%.1f)",(long)stack.axis,(long)stack.alignment,(long)stack.distribution,stack.spacing];
    }
    UIImage *image=nil;
    if ([view isKindOfClass:UIImageView.class]) image=((UIImageView *)view).image;
    else if ([view isKindOfClass:UIButton.class]) image=[(UIButton *)view imageForState:UIControlStateNormal];
    if (image) [report appendFormat:@" imageSize=(%.0fx%.0f)",image.size.width,image.size.height];
    NSArray *gestures=view.gestureRecognizers;
    if (gestures.count) {
        NSMutableArray *classes=[NSMutableArray array];
        for (UIGestureRecognizer *gesture in gestures) [classes addObject:NSStringFromClass(gesture.class) ?: @"?"];
        [report appendFormat:@" gestures=%@",[classes componentsJoinedByString:@","]];
    }
    [report appendString:@"\n"];
    NSArray<UIView *> *children=view.subviews;
    for (NSUInteger i=0;i<children.count && *budget<700;i++)
        RIAppendView(report,children[i],window,[path stringByAppendingFormat:@".%lu",(unsigned long)i],depth+1,budget);
}

static NSString *RIVisibleInterfaceReport(UIViewController *hint) {
    NSCAssert(NSThread.isMainThread,@"UI inspection must run on main thread");
    UIViewController *top=RITopController(hint);
    UIWindow *window=top.viewIfLoaded.window;
    if (!window) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState!=UISceneActivationStateForegroundActive) continue;
            for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) { window=candidate; break; }
            if (window) break;
        }
    }
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta interface inspection\nInstagram=%@ (%@) iOS=%@\nWindow=%@ size=%.1fx%.1f scale=%.2f\nVisible UIView hierarchy; text, accessibility labels, account data and image contents are intentionally excluded.\n\n",
        NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"?",UIDevice.currentDevice.systemVersion,window ? NSStringFromClass(window.class) : @"none",window.bounds.size.width,window.bounds.size.height,window.screen.scale];
    if (!window) return [report stringByAppendingString:@"No foreground window found. Open the target post, Reel or Story and retry.\n"];
    NSUInteger budget=0;
    RIAppendView(report,window,window,@"0",0,&budget);
    [report appendFormat:@"\nViews recorded: %lu (maximum 700).\n",(unsigned long)budget];
    if (budget>=700) [report appendString:@"Hierarchy was truncated at the safety limit.\n"];
    return report;
}

static void RICopyInterfaceReport(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(),^{
        NSString *report=RIVisibleInterfaceReport(host);
        UIPasteboard.generalPasteboard.string=report;
        RIAlert(@"فحص الواجهة",[NSString stringWithFormat:@"نُسخ التقرير (%lu حرفًا). أرسله هنا بعد فتح الشاشة المطلوبة.",(unsigned long)report.length],host);
    });
}

@interface RISettingsController : UITableViewController
@end
@implementation RISettingsController
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"RiseInsta";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=80;
    self.view.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft;
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 6; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section {
    switch (section) { case 0:return 3; case 1:return 2; case 2:return 3; case 3:return 7; case 4:return 1; default:return 3; }
}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)section {
    return @[@"الخصوصية",@"المنشورات والريلز والقصص",@"الملف الشخصي والواجهة",@"محرر أزرار RiseInsta",@"أدوات الوسائط",@"التشخيص والصيانة"][section];
}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section {
    return section==0 ? @"تتوقف بعض الخيارات إذا لم يتوفر مسار متوافق في إصدار إنستغرام." : (section==3 ? @"تخصيص أزرار RiseInsta المضافة فقط؛ لا يغير وظائف أزرار إنستغرام الأصلية." : (section==5 ? @"التشخيص يفحص الواجهة الظاهرة ولا ينسخ نصوصها أو بيانات الحساب." : @"نسخة تجريبية 1.2.1؛ تحقق من كل ميزة على جهازك."));
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    NSArray *featureIndexes = ip.section==0 ? @[@0,@1,@2] : (ip.section==1 ? @[@3,@4] : (ip.section==2 ? @[@5,@6,@7] : @[]));
    if (featureIndexes.count) {
        NSUInteger index=[featureIndexes[ip.row] unsignedIntegerValue]; NSDictionary *row=RIFeatures()[index];
        cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"]; cell.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch *sw=[[UISwitch alloc] init]; sw.tag=(NSInteger)index; sw.on=RIPref(row[@"key"],[row[@"default"] boolValue]);
        [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; return cell;
    }
    if (ip.section==3) {
        NSArray *labels=@[@"إظهار زر تنزيل المنشور",@"إظهار زر تنزيل الريلز",@"إظهار أيقونة الملف الشخصي",@"إظهار أيقونة الإعدادات",@"أيقونة أزرار التنزيل",@"حجم أزرار التنزيل",@"موضع زر المنشور"];
        NSArray *keys=@[@"editor_post",@"editor_reels",@"editor_profile",@"editor_settings",@"editor_icon",@"editor_size",@"editor_post_position"];
        cell.textLabel.text=labels[ip.row]; cell.detailTextLabel.text=ip.row<2 ? @"تطبيق مباشر عند تحديث الواجهة" : @"اضغط للاختيار";
        if (ip.row<4) { UISwitch *sw=[UISwitch new]; sw.tag=100+ip.row; sw.on=RIPref(keys[ip.row],YES); [sw addTarget:self action:@selector(editorToggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; }
        else cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    if (ip.section==4) { cell.textLabel.text=@"تحميل الوسائط المعروضة"; cell.detailTextLabel.text=@"قائمة تحميل ومشاركة من المنشور أو الريلز أو القصة"; }
    else if (ip.section==5) {
        NSArray *labels=@[@"تشخيص ونسخ التقرير",@"فحص الواجهة ونسخ الكلاسات",@"إلغاء التحميلات الجارية"];
        cell.textLabel.text=labels[ip.row]; cell.detailTextLabel.text=ip.row==1 ? @"افتح الشاشة المطلوبة ثم انسخ شجرتها الظاهرة" : @"";
    }
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return cell;
}
- (void)editorToggle:(UISwitch *)sw { NSArray *keys=@[@"editor_post",@"editor_reels",@"editor_profile",@"editor_settings"]; if(sw.tag>=100 && sw.tag<104) RISetPref(keys[sw.tag-100],sw.on); }
- (void)showChoice:(NSArray<NSString *> *)titles key:(NSString *)key values:(NSArray<NSString *> *)values {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"تخصيص الزر" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSUInteger i=0;i<titles.count;i++) { NSString *v=values[i]; [a addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ [[NSUserDefaults standardUserDefaults] setObject:v forKey:[@"com.riseinsta." stringByAppendingString:key]]; [NSNotificationCenter.defaultCenter postNotificationName:RISettingsChanged object:key]; }]]; }
    [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]]; a.popoverPresentationController.sourceView=self.view; a.popoverPresentationController.sourceRect=CGRectMake(CGRectGetMidX(self.view.bounds),CGRectGetMidY(self.view.bounds),1,1); [self presentViewController:a animated:YES completion:nil];
}
- (void)toggle:(UISwitch *)sw {
    if (sw.tag<0 || (NSUInteger)sw.tag>=RIFeatures().count) return;
    RISetPref(RIFeatures()[sw.tag][@"key"],sw.on);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.section<3 || (ip.section==3 && ip.row<4)) return;
    if (ip.section==3) {
        if (ip.row==4) [self showChoice:@[@"سهم لأسفل",@"تنزيل",@"حفظ",@"نجمة"] key:@"editor_icon" values:@[@"arrow.down.circle.fill",@"arrow.down.to.line",@"square.and.arrow.down",@"star"]];
        else if (ip.row==5) [self showChoice:@[@"صغير 36",@"متوسط 44",@"كبير 52"] key:@"editor_size" values:@[@"36",@"44",@"52"]];
        else [self showChoice:@[@"يسار الشريط",@"وسط الشريط",@"يمين الشريط"] key:@"editor_post_position" values:@[@"left",@"center",@"right"]];
        return;
    }
    UIViewController *host=self.navigationController.presentingViewController;
    if (ip.section==4) { [self dismissViewControllerAnimated:YES completion:^{ RIShowCurrentMediaMenu(host); }]; return; }
    if (ip.row==0) {
        NSString *report=RIDiagnostics(); UIAlertController *a=[UIAlertController alertControllerWithTitle:@"تشخيص RiseInsta" message:report preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"نسخ التقرير" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ UIPasteboard.generalPasteboard.string=report; }]]; [a addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
    } else if (ip.row==1) [self dismissViewControllerAnimated:YES completion:^{ RICopyInterfaceReport(host); }];
    else { [RIDownloader cancelAll]; RIAlert(@"RiseInsta",@"تم طلب إلغاء التحميلات",self); }
}
@end

void RIShowSettings(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top=RITopController(host);
        if (!top || [top isKindOfClass:RISettingsController.class] || [top isKindOfClass:UIAlertController.class]) return;
        UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:[[RISettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped]];
        [top presentViewController:nav animated:YES completion:nil];
    });
}
@interface RIWindowMenu : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)attach:(UIWindow *)window;
@end
@implementation RIWindowMenu
static char RIWindowGestureKey,RIWindowButtonKey;
+ (instancetype)shared { static RIWindowMenu *manager; static dispatch_once_t once; dispatch_once(&once,^{ manager=[self new]; }); return manager; }
- (void)attach:(UIWindow *)window {
    if (!window || window.windowLevel!=UIWindowLevelNormal || objc_getAssociatedObject(window,&RIWindowGestureKey)) return;
    UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(open:)];
    gesture.numberOfTouchesRequired=3; gesture.minimumPressDuration=0.65; gesture.cancelsTouchesInView=NO; gesture.delegate=self;
    [window addGestureRecognizer:gesture]; objc_setAssociatedObject(window,&RIWindowGestureKey,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    button.backgroundColor=UIColor.secondarySystemBackgroundColor; button.layer.cornerRadius=22;
    button.accessibilityLabel=@"إعدادات RiseInsta";
    button.translatesAutoresizingMaskIntoConstraints=NO;
    [button addTarget:self action:@selector(openButton:) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:44], [button.heightAnchor constraintEqualToConstant:44],
        [button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-64]
    ]];
    button.hidden=!RIPref(@"floating_settings",YES);
    objc_setAssociatedObject(window,&RIWindowButtonKey,button,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)openButton:(UIButton *)button { RIShowSettings(nil); }
- (void)refreshButtons {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIButton *button=objc_getAssociatedObject(window,&RIWindowButtonKey); button.hidden=!RIPref(@"floating_settings",YES);
        }
    }
}
- (void)open:(UILongPressGestureRecognizer *)gesture { if (gesture.state==UIGestureRecognizerStateBegan) RIShowSettings(nil); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { return YES; }
@end
void RIInstallMenu(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:RISettingsChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ [[RIWindowMenu shared] refreshButtons]; }];
    [NSNotificationCenter.defaultCenter addObserverForName:UIWindowDidBecomeKeyNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ [[RIWindowMenu shared] attach:note.object]; }];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) for (UIWindow *window in ((UIWindowScene *)scene).windows) [[RIWindowMenu shared] attach:window];
    }
}
