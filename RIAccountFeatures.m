#import "RIAccountFeatures.h"
#import "RICommon.h"

static UIColor *RIFeatureColor(NSInteger hex) {
    return [UIColor colorWithRed:((hex>>16)&255)/255.0 green:((hex>>8)&255)/255.0 blue:(hex&255)/255.0 alpha:1.0];
}

static NSArray<NSDictionary *> *RIAccountFeatureCatalog(void) {
    static NSArray *sections; static dispatch_once_t once;
    dispatch_once(&once, ^{
        sections=@[
            @{@"title":@"القنوات والملاحظات وخريطة الأصدقاء",@"items":@[
                @{@"title":@"إنشاء قناة بث في إنستغرام",@"detail":@"إنشاء قناة عامة جديدة وإرسال التحديثات للمتابعين",@"icon":@"antenna.radiowaves.left.and.right"},
                @{@"title":@"خريطة الأصدقاء (Friends Map)",@"detail":@"عرض مواقع الأصدقاء والملاحظات على الخريطة",@"icon":@"map"},
                @{@"title":@"إضافة الموقع والأماكن في الملاحظات",@"detail":@"إرفاق اسم المكان أو الموقع بالملاحظة",@"icon":@"mappin.and.ellipse"},
                @{@"title":@"ملاحظة «استمع الآن» الموسيقية",@"detail":@"مشاركة المقطع الذي تستمع إليه في الملاحظات",@"icon":@"music.note"},
                @{@"title":@"البحث عن القنوات واستكشافها في الرسائل",@"detail":@"البحث عن قنوات البث واكتشافها من الرسائل",@"icon":@"magnifyingglass"},
                @{@"title":@"اقتراح القنوات في الرسائل",@"detail":@"عرض القنوات المقترحة ضمن تبويب الرسائل",@"icon":@"bubble.left.and.text"},
                @{@"title":@"المحادثات المباشرة (Live Chats)",@"detail":@"بدء غرف ومحادثات مباشرة مع المتابعين",@"icon":@"person.2.wave.2"}
            ]},
            @{@"title":@"الرسائل والمحادثات الخاصة",@"items":@[
                @{@"title":@"خلاصة الريلز المشتركة مع الأصدقاء (Blend)",@"detail":@"خلاصة ريلز مشتركة داخل المحادثة",@"icon":@"person.2"},
                @{@"title":@"إرسال الصور والفيديوهات بجودة عالية (HD)",@"detail":@"إرسال الوسائط بالجودة العالية في المحادثات",@"icon":@"4k.tv"},
                @{@"title":@"الرسم الحر المباشر على خلفية المحادثة (Doodle)",@"detail":@"الرسم على شاشة المحادثة وحفظه كملصق",@"icon":@"scribble"},
                @{@"title":@"الشريط العائم للرسائل المثبتة أعلى المحادثة",@"detail":@"عرض الرسائل المثبتة في شريط أعلى المحادثة",@"icon":@"pin"},
                @{@"title":@"إضافة صورة كخلفية للمحادثة",@"detail":@"تعيين صورة من الاستوديو كخلفية للمحادثة",@"icon":@"photo"},
                @{@"title":@"إنشاء مجلدات مخصصة لتنظيم الرسائل",@"detail":@"تقسيم صندوق الرسائل إلى مجلدات مخصصة",@"icon":@"folder"},
                @{@"title":@"تصميم الصندوق المقسم وتبويب الكل",@"detail":@"تخصيص تصنيفات الرسائل وطريقة عرضها",@"icon":@"line.3.horizontal.decrease"}
            ]},
            @{@"title":@"الريلز والفيديو",@"items":@[
                @{@"title":@"تشغيل الريلز بنافذة عائمة مصغرة (PiP)",@"detail":@"متابعة الريلز بنافذة صغيرة عند الانتقال داخل التطبيق",@"icon":@"pip"},
                @{@"title":@"تسريع الفيديو بالضغط المطول (2x)",@"detail":@"ضغط مطول على جانب الفيديو لتشغيله بسرعة مضاعفة",@"icon":@"speedometer"},
                @{@"title":@"المعالجة الفائقة لرفع وضوح الفيديو",@"detail":@"تحسين جودة العرض تلقائيًا أثناء التشغيل",@"icon":@"wand.and.stars"},
                @{@"title":@"إظهار ترجمة الريلز",@"detail":@"عرض ترجمة للمقاطع عند توفرها",@"icon":@"captions.bubble"}
            ]},
            @{@"title":@"القصص والملف الشخصي",@"items":@[
                @{@"title":@"التصميم الحديث لعرض الهايلايت",@"detail":@"تجربة تصميم أحدث للقصص المثبتة",@"icon":@"circle.hexagongrid"},
                @{@"title":@"الوضع الهادئ وجدولة كتم الإشعارات",@"detail":@"إيقاف الإشعارات تلقائيًا في أوقات محددة",@"icon":@"moon"},
                @{@"title":@"إشعارات وربط حساب Threads",@"detail":@"عرض تنبيهات Threads والتنقل بين الحسابات",@"icon":@"at"},
                @{@"title":@"التصميم الممتد الحديث لأزرار الملف الشخصي",@"detail":@"تجربة الشكل الحديث لأزرار المتابعة والروابط",@"icon":@"person.crop.circle.badge.plus"},
                @{@"title":@"أزرار الملف الشخصي",@"detail":@"إظهار قائمة إجراءات الملف الشخصي",@"icon":@"person.crop.circle"}
            ]},
            @{@"title":@"التعليقات",@"items":@[
                @{@"title":@"تثبيت التعليقات المميزة أعلى المنشور",@"detail":@"تثبيت تعليق لعرضه دائمًا في المقدمة",@"icon":@"pin"},
                @{@"title":@"مشاركة أي تعليق مباشرة إلى القصص",@"detail":@"مشاركة التعليق كملصق تفاعلي في القصة",@"icon":@"arrowshape.turn.up.right"},
                @{@"title":@"الترجمة التلقائية الفورية للتعليقات",@"detail":@"ترجمة التعليقات المكتوبة بلغات أخرى",@"icon":@"character.bubble"},
                @{@"title":@"الرد المرئي على التعليق بمقطع ريلز",@"detail":@"الرد على التعليقات بمقطع فيديو مع معاينة",@"icon":@"video.bubble"}
            ]},
            @{@"title":@"الخصوصية والتنزيلات",@"items":@[
                @{@"title":@"إخفاء قراءة الرسائل",@"detail":@"إعداد محلي؛ يعتمد على مسار إنستغرام المتاح",@"icon":@"eye.slash",@"pref":@"ghost_seen"},
                @{@"title":@"إخفاء مؤشر الكتابة",@"detail":@"إعداد محلي؛ يعتمد على مسار إنستغرام المتاح",@"icon":@"text.bubble",@"pref":@"ghost_typing"},
                @{@"title":@"إخفاء مشاهدة القصص",@"detail":@"إعداد محلي؛ يعتمد على مسار إنستغرام المتاح",@"icon":@"eye.slash",@"pref":@"ghost_story"},
                @{@"title":@"إخفاء الإعلانات",@"detail":@"تصفية محلية في المسارات المتاحة",@"icon":@"rectangle.slash",@"pref":@"hide_feed_ads"},
                @{@"title":@"قائمة تنزيل الوسائط",@"detail":@"إظهار أدوات تنزيل الوسائط",@"icon":@"arrow.down.circle",@"pref":@"download"}
            ]}
        ];
    });
    return sections;
}

@interface RIAccountFeaturesController : UIViewController <UITableViewDataSource,UITableViewDelegate,UISearchBarDelegate>
@property(nonatomic,strong) UITableView *tableView;
@property(nonatomic,strong) UISearchBar *searchBar;
@property(nonatomic,strong) UISegmentedControl *filter;
@property(nonatomic,copy) NSString *query;
@property(nonatomic) NSInteger filterIndex;
@property(nonatomic,strong) UILabel *scanSummary;
@end

@implementation RIAccountFeaturesController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title=@"ميزات وتحديثات الحساب";
    self.view.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft;
    self.view.backgroundColor=RIFeatureColor(0x101415);
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.navigationController.navigationBar.tintColor=UIColor.whiteColor;
    if (@available(iOS 13.0,*)) {
        UINavigationBarAppearance *appearance=[UINavigationBarAppearance new]; [appearance configureWithOpaqueBackground]; appearance.backgroundColor=RIFeatureColor(0x101415); appearance.titleTextAttributes=@{NSForegroundColorAttributeName:UIColor.whiteColor}; self.navigationController.navigationBar.standardAppearance=appearance; self.navigationController.navigationBar.scrollEdgeAppearance=appearance;
    }
    self.tableView=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped]; self.tableView.translatesAutoresizingMaskIntoConstraints=NO; self.tableView.backgroundColor=self.view.backgroundColor; self.tableView.dataSource=self; self.tableView.delegate=self; self.tableView.separatorStyle=UITableViewCellSeparatorStyleNone; self.tableView.contentInset=UIEdgeInsetsMake(-18,0,16,0); [self.view addSubview:self.tableView];
    [NSLayoutConstraint activateConstraints:@[[self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
    UIView *header=[[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width,194)]; header.backgroundColor=self.view.backgroundColor;
    UILabel *summary=[UILabel new]; summary.translatesAutoresizingMaskIntoConstraints=NO; summary.text=@"حالة الميزات لهذا الحساب"; summary.textColor=UIColor.whiteColor; summary.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; summary.textAlignment=NSTextAlignmentRight; [header addSubview:summary];
    UILabel *count=[UILabel new]; count.translatesAutoresizingMaskIntoConstraints=NO; count.text=@"الكتالوج المحلي • حالة الخادم غير متاحة"; count.textColor=RIFeatureColor(0x9ba2a3); count.font=[UIFont systemFontOfSize:12]; count.textAlignment=NSTextAlignmentRight; [header addSubview:count];
    self.filter=[[UISegmentedControl alloc] initWithItems:@[@"الكل",@"موصولة",@"غير موصولة",@"محلية"]]; self.filter.translatesAutoresizingMaskIntoConstraints=NO; self.filter.selectedSegmentIndex=0; [self.filter addTarget:self action:@selector(filterChanged:) forControlEvents:UIControlEventValueChanged]; [header addSubview:self.filter];
    self.searchBar=[UISearchBar new]; self.searchBar.translatesAutoresizingMaskIntoConstraints=NO; self.searchBar.delegate=self; self.searchBar.placeholder=@"البحث في الميزات"; self.searchBar.searchBarStyle=UISearchBarStyleMinimal; self.searchBar.tintColor=UIColor.whiteColor; [header addSubview:self.searchBar];
    [NSLayoutConstraint activateConstraints:@[[summary.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],[summary.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-18],[summary.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18],[count.topAnchor constraintEqualToAnchor:summary.bottomAnchor constant:5],[count.trailingAnchor constraintEqualToAnchor:summary.trailingAnchor],[count.leadingAnchor constraintEqualToAnchor:summary.leadingAnchor],[self.filter.topAnchor constraintEqualToAnchor:count.bottomAnchor constant:10],[self.filter.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],[self.filter.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14],[self.searchBar.topAnchor constraintEqualToAnchor:self.filter.bottomAnchor constant:4],[self.searchBar.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:4],[self.searchBar.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-4],[self.searchBar.heightAnchor constraintEqualToConstant:48]]];
    UIButton *scan=[UIButton buttonWithType:UIButtonTypeSystem];
    scan.translatesAutoresizingMaskIntoConstraints=NO;
    [scan setTitle:@"فحص المميزات المحلية وإعادة التحقق" forState:UIControlStateNormal];
    scan.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    scan.backgroundColor=RIFeatureColor(0x26323a);
    scan.tintColor=UIColor.whiteColor;
    scan.layer.cornerRadius=10;
    [scan addTarget:self action:@selector(scanLocalFeatures) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:scan];
    [NSLayoutConstraint activateConstraints:@[
        [scan.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:4],
        [scan.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],
        [scan.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-14],
        [scan.heightAnchor constraintEqualToConstant:40]
    ]];
    [self refreshScanSummary];
    self.tableView.tableHeaderView=header;
}
- (void)refreshScanSummary {
    NSUInteger total=0, local=0, enabled=0;
    for (NSDictionary *section in RIAccountFeatureCatalog()) {
        for (NSDictionary *item in section[@"items"]) {
            total++;
            NSString *pref=item[@"pref"];
            if (!pref) continue;
            local++;
            if (RIPref(pref,[pref isEqualToString:@"download"])) enabled++;
        }
    }
    self.scanSummary.text=[NSString stringWithFormat:@"%lu ميزة في الكتالوج • %lu مفاتيح محلية • %lu مفعلة محليًا • حالة الخادم غير معروفة",
                           (unsigned long)total,(unsigned long)local,(unsigned long)enabled];
}
- (void)scanLocalFeatures {
    [self refreshScanSummary];
    NSDictionary *hookStatus=RIHookStatus();
    NSUInteger installed=0;
    for (NSDictionary *entry in hookStatus.allValues)
        if ([entry[@"state"] hasPrefix:@"installed"]) installed++;
    NSString *message=[NSString stringWithFormat:@"فُحصت إعدادات RiseInsta المحلية. عدد مسارات Hooks المثبتة بحسب التشخيص: %lu من %lu. هذا لا يكشف أهلية الحساب على خوادم إنستغرام، ولا يمنح ميزات تجريبية أو صلاحيات موظف.",(unsigned long)installed,(unsigned long)hookStatus.count];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"نتيجة فحص المميزات المحلية" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"نسخ تقرير التشخيص" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIPasteboard.generalPasteboard.string=RIDiagnostics();
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    [self.tableView reloadData];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)filterChanged:(UISegmentedControl *)sender { self.filterIndex=sender.selectedSegmentIndex; [self.tableView reloadData]; }
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { self.query=searchText.lowercaseString; [self.tableView reloadData]; }
- (NSArray<NSDictionary *> *)visibleSections {
    NSMutableArray *result=[NSMutableArray array];
    for (NSDictionary *section in RIAccountFeatureCatalog()) {
        NSMutableArray *items=[NSMutableArray array];
        for (NSDictionary *item in section[@"items"]) {
            BOOL local=item[@"pref"]!=nil;
            if (self.filterIndex==1 && !local) continue;
            if (self.filterIndex==2 && local) continue;
            if (self.filterIndex==3 && !local) continue;
            if (self.query.length && ![[NSString stringWithFormat:@"%@ %@",item[@"title"],item[@"detail"]].lowercaseString containsString:self.query]) continue;
            [items addObject:item];
        }
        if (items.count) [result addObject:@{@"title":section[@"title"],@"items":items}];
    }
    return result;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.visibleSections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.visibleSections[section][@"items"] count]; }
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(0,0,tableView.bounds.size.width,40)]; label.text=self.visibleSections[section][@"title"]; label.textColor=RIFeatureColor(0xaeb4b5); label.font=[UIFont systemFontOfSize:15 weight:UIFontWeightBold]; label.textAlignment=NSTextAlignmentRight; label.backgroundColor=self.view.backgroundColor; label.layoutMargins=UIEdgeInsetsMake(0,18,0,18); label.autoresizingMask=UIViewAutoresizingFlexibleWidth; return label;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 42; }
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 9; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item=self.visibleSections[indexPath.section][@"items"][indexPath.row]; UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil]; cell.backgroundColor=RIFeatureColor(0x181d1e); cell.contentView.backgroundColor=cell.backgroundColor; cell.textLabel.text=item[@"title"]; cell.textLabel.textColor=UIColor.whiteColor; cell.textLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; cell.textLabel.textAlignment=NSTextAlignmentRight; cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0; cell.detailTextLabel.textAlignment=NSTextAlignmentRight;
    NSString *pref=item[@"pref"]; BOOL local=pref!=nil;
    cell.detailTextLabel.text=local?item[@"detail"]:[NSString stringWithFormat:@"%@\nغير موصولة في هذه النسخة",item[@"detail"]]; cell.detailTextLabel.textColor=local?RIFeatureColor(0x9da5a6):RIFeatureColor(0x808889); cell.detailTextLabel.font=[UIFont systemFontOfSize:12]; cell.imageView.image=[UIImage systemImageNamed:item[@"icon"]]; cell.imageView.tintColor=RIFeatureColor(0xe8eeee);
    if (local) { UISwitch *toggle=[UISwitch new]; toggle.on=RIPref(pref,[pref isEqualToString:@"download"]); toggle.accessibilityIdentifier=pref; [toggle addTarget:self action:@selector(toggleFeature:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=toggle; }
    else { UILabel *state=[UILabel new]; state.text=@"غير متاحة"; state.textColor=RIFeatureColor(0x929999); state.font=[UIFont systemFontOfSize:10 weight:UIFontWeightMedium]; [state sizeToFit]; cell.accessoryView=state; }
    cell.selectionStyle=UITableViewCellSelectionStyleNone; return cell;
}
- (void)toggleFeature:(UISwitch *)sender { if (sender.accessibilityIdentifier.length) RISetPref(sender.accessibilityIdentifier,sender.on); }
@end

void RIShowAccountFeatures(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top=RITopController(host); if (!top) return;
        RIAccountFeaturesController *root=[RIAccountFeaturesController new]; UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:root]; nav.modalPresentationStyle=UIModalPresentationPageSheet;
        if (@available(iOS 15.0,*)) {
            UISheetPresentationController *sheet=nav.sheetPresentationController;
            sheet.detents=@[UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible=YES;
        }
        nav.overrideUserInterfaceStyle=UIUserInterfaceStyleDark; [top presentViewController:nav animated:YES completion:nil];
    });
}
