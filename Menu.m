#import "RICommon.h"
#import <QuartzCore/QuartzCore.h>

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
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section { return section==0 ? RIFeatures().count : (section==1 ? 1 : 3); }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section {
    return section==0 ? @"الإعدادات تطبق مباشرة. أعد فتح المحتوى لتحديث العناصر. اضغط مطولًا بثلاثة أصابع لفتح هذه الصفحة." : @"نسخة تجريبية: توفر الكلاسات لا يثبت أن الميزة تعمل على إصدارك.";
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    cell.textLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    cell.detailTextLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.textLabel.adjustsFontForContentSizeCategory=YES; cell.detailTextLabel.adjustsFontForContentSizeCategory=YES;
    if (ip.section==0) {
        NSDictionary *row=RIFeatures()[ip.row];
        cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"];
        cell.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch *sw=[[UISwitch alloc] init]; sw.tag=ip.row;
        sw.accessibilityLabel=row[@"title"];
        sw.on=RIPref(row[@"key"],[row[@"default"] boolValue]);
        [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw;
    } else if (ip.section==1) {
        cell.textLabel.text=@"تحميل الوسائط المعروضة";
        cell.detailTextLabel.text=@"افتح منشورًا أو ريلًا أو قصة، ثم استخدم هذا الخيار";
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.text=@[@"التشخيص ونسخ التقرير",@"إلغاء التحميلات الجارية",@"إعادة ضبط إعدادات RiseInsta"][ip.row];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } return cell;
}
- (void)toggle:(UISwitch *)sw {
    if (sw.tag<0 || (NSUInteger)sw.tag>=RIFeatures().count) return;
    RISetPref(RIFeatures()[sw.tag][@"key"],sw.on);
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES];
    if (ip.section==0) return;
    if (ip.section==1) {
        UIViewController *host=self.navigationController.presentingViewController;
        [self dismissViewControllerAnimated:YES completion:^{ RIShowCurrentMediaMenu(host); }]; return;
    }
    if (ip.row==0) {
        NSString *report=RIDiagnostics();
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"تشخيص RiseInsta" message:report preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"نسخ التقرير" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ UIPasteboard.generalPasteboard.string=report; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if (ip.row==1) { [RIDownloader cancelAll]; RIAlert(@"RiseInsta",@"تم طلب إلغاء التحميلات",self); }
    else {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"إعادة ضبط الإعدادات؟" message:@"تُعاد إعدادات RiseInsta فقط إلى قيمها الافتراضية." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"إعادة الضبط" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a){
            for (NSDictionary *row in RIFeatures()) RISetPref(row[@"key"],[row[@"default"] boolValue]);
            [self.tableView reloadData];
        }]]; [self presentViewController:alert animated:YES completion:nil];
    }
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
