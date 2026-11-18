#import "RICommon.h"
#import "RIScreenRecorder.h"
#import "RIAccountFeatures.h"
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
    for (id target in control.allTargets) for (NSNumber *event in events)
        for (NSString *action in [control actionsForTarget:target forControlEvent:event.unsignedIntegerValue]) if (action.length) [actions addObject:action];
    return actions.count ? [actions.array componentsJoinedByString:@","] : @"-";
}

static void RIAppendView(NSMutableString *report, UIView *view, UIWindow *window, NSString *path, NSUInteger depth, NSUInteger *budget) {
    if (!view || !window || *budget>=700 || depth>45 || view.hidden || view.alpha<0.02 || (view!=window && view.window!=window)) return;
    CGRect frame=[view convertRect:view.bounds toView:window];
    if (!CGRectIntersectsRect(frame,window.bounds) && view!=window) return;
    (*budget)++;
    NSString *indent=[@" " stringByPaddingToLength:MIN(depth*2,90) withString:@" " startingAtIndex:0];
    [report appendFormat:@"%@[%@] %@ frame=(%.1f,%.1f,%.1f,%.1f) alpha=%.2f hidden=%d",indent,path,RIViewClassChain(view.class),frame.origin.x,frame.origin.y,frame.size.width,frame.size.height,view.alpha,view.hidden];
    if ([view isKindOfClass:UIControl.class]) [report appendFormat:@" actions=%@",RIControlActions((UIControl *)view)];
    if ([view isKindOfClass:UIStackView.class]) { UIStackView *s=(id)view; [report appendFormat:@" stack(axis=%ld,alignment=%ld,distribution=%ld,spacing=%.1f)",(long)s.axis,(long)s.alignment,(long)s.distribution,s.spacing]; }
    UIImage *image=[view isKindOfClass:UIImageView.class] ? ((UIImageView *)view).image : ([view isKindOfClass:UIButton.class] ? [(UIButton *)view imageForState:UIControlStateNormal] : nil);
    if (image) [report appendFormat:@" imageSize=(%.0fx%.0f)",image.size.width,image.size.height];
    [report appendString:@"\n"];
    NSArray<UIView *> *children=view.subviews;
    for (NSUInteger i=0;i<children.count && *budget<700;i++) RIAppendView(report,children[i],window,[path stringByAppendingFormat:@".%lu",(unsigned long)i],depth+1,budget);
}

static NSString *RIVisibleInterfaceReport(UIViewController *hint) {
    NSCAssert(NSThread.isMainThread,@"UI inspection must run on main thread");
    UIViewController *top=RITopController(hint); UIWindow *window=top.viewIfLoaded.window;
    if (!window) for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState!=UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) if (candidate.isKeyWindow) { window=candidate; break; }
        if (window) break;
    }
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta interface inspection\nInstagram=%@ (%@) iOS=%@\nWindow=%@ size=%.1fx%.1f scale=%.2f\nVisible UIView hierarchy; text, accessibility labels, account data and image contents are intentionally excluded.\n\n",NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"?",UIDevice.currentDevice.systemVersion,window ? NSStringFromClass(window.class) : @"none",window.bounds.size.width,window.bounds.size.height,window.screen.scale];
    if (!window) return [report stringByAppendingString:@"No foreground window found. Open the target screen and retry.\n"];
    NSUInteger budget=0; RIAppendView(report,window,window,@"0",0,&budget); [report appendFormat:@"\nViews recorded: %lu (maximum 700).\n",(unsigned long)budget];
    if (budget>=700) [report appendString:@"Hierarchy was truncated at the safety limit.\n"];
    return report;
}

static BOOL RIRelevantRuntimeClass(NSString *name) {
    NSString *value=name.lowercaseString;
    for (NSString *term in @[@"developer",@"employee",@"internalsettings",@"profileprivacy",@"profilesetting",@"privacysetting",@"mobileconfig",@"pando",@"follower",@"following",@"userdefaults"])
        if ([value containsString:term]) return YES;
    return NO;
}

static NSString *RIFeatureClassProbeReport(UIViewController *hint) {
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta developer/profile-privacy class probe\nInstagram=%@ (%@) iOS=%@\nThe report excludes UI text, accessibility labels, account data, request values and image contents.\n\n%@\nRuntime classes and method encodings:\n",
        NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?",NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"?",UIDevice.currentDevice.systemVersion,RIVisibleInterfaceReport(hint)];
    int count=objc_getClassList(NULL,0); if (count<=0) return [report stringByAppendingString:@"No Objective-C runtime classes found.\n"];
    Class *classes=(Class *)calloc((size_t)count,sizeof(Class)); if (!classes) return [report stringByAppendingString:@"Class list allocation failed.\n"];
    int loaded=objc_getClassList(classes,count); NSMutableArray<NSString *> *matches=[NSMutableArray array]; NSUInteger methodBudget=0;
    for (int i=0;i<loaded;i++) {
        NSString *name=NSStringFromClass(classes[i]); if (!RIRelevantRuntimeClass(name)) continue;
        [matches addObject:name];
    }
    [matches sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    for (NSString *name in matches) {
        if (methodBudget>=900) break;
        Class cls=NSClassFromString(name); unsigned int methodCount=0; Method *methods=class_copyMethodList(cls,&methodCount);
        [report appendFormat:@"\n[%@]\n",name];
        for (unsigned int j=0;j<methodCount && methodBudget<900;j++,methodBudget++) {
            SEL selector=method_getName(methods[j]); const char *encoding=method_getTypeEncoding(methods[j]);
            [report appendFormat:@"  -%s %s\n",sel_getName(selector),encoding ?: "?"];
        }
        free(methods);
    }
    free(classes);
    [report appendFormat:@"\nMatching classes=%lu; method entries=%lu (maximum 900).\n",(unsigned long)matches.count,(unsigned long)methodBudget];
    if (!matches.count) [report appendString:@"No matching loaded classes. Open the profile privacy or developer settings screen and capture again.\n"];
    return report;
}

static void RICopyInterfaceReport(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(),^{ NSString *report=RIVisibleInterfaceReport(host); UIPasteboard.generalPasteboard.string=report; RIAlert(@"فحص الواجهة",[NSString stringWithFormat:@"نُسخ التقرير (%lu حرفًا). أرسله هنا بعد فتح الشاشة المطلوبة.",(unsigned long)report.length],host); });
}

@interface RISettingsController : UITableViewController
@property(nonatomic,copy) NSString *page;
@property(nonatomic,strong) UIColor *menuBackgroundColor;
- (instancetype)initWithPage:(NSString *)page backgroundColor:(UIColor *)backgroundColor;
@end

static NSArray<NSDictionary *> *RIMenuPages(void) {
    return @[
        @{@"id":@"privacy",@"title":@"الخصوصية",@"detail":@"الظهور والقراءة ومؤشرات النشاط",@"icon":@"hand.raised"},
        @{@"id":@"messages",@"title":@"الرسائل والوسائط الصوتية",@"detail":@"القراءة والكتابة والوسائط",@"icon":@"bubble.left.and.bubble.right"},
        @{@"id":@"stories",@"title":@"القصص",@"detail":@"المشاهدة والتنزيل",@"icon":@"circle.dashed"},
        @{@"id":@"posts",@"title":@"المنشورات والريلز",@"detail":@"التنزيل وأزرار التفاعل",@"icon":@"play.rectangle"},
        @{@"id":@"profile",@"title":@"الملف الشخصي",@"detail":@"تنزيل صورة الملف الشخصي",@"icon":@"person.crop.circle"},
        @{@"id":@"comments",@"title":@"التعليقات والتفاعل",@"detail":@"البحث والفرز ونسخ التعليقات",@"icon":@"bubble.left.and.text.bubble.right"},
        @{@"id":@"calls",@"title":@"المكالمات والصوتيات",@"detail":@"أدوات المكالمات والرسائل الصوتية",@"icon":@"phone.arrow.up.right"},
        @{@"id":@"ai",@"title":@"Rise AI",@"detail":@"الردود الذكية والمساعد والتخصيص",@"icon":@"sparkles"},
        @{@"id":@"appearance",@"title":@"المظهر والأزرار",@"detail":@"إظهار أزرار التنزيل",@"icon":@"slider.horizontal.3"},
        @{@"id":@"media",@"title":@"التحميلات والوسائط",@"detail":@"الحفظ والمشاركة وإدارة التنزيلات",@"icon":@"arrow.down.circle"},
        @{@"id":@"account_features",@"title":@"ميزات الحساب والتحديثات",@"detail":@"كتالوج الميزات وحالة توفرها",@"icon":@"sparkles.rectangle.stack"},
        @{@"id":@"diagnostics",@"title":@"التشخيص والصيانة",@"detail":@"تقارير الواجهة وحالة المكتبة",@"icon":@"stethoscope"},
        @{@"id":@"developer",@"title":@"خيارات المطوّر",@"detail":@"فتح الخيارات الداخلية المتاحة في إنستغرام",@"icon":@"hammer"}
    ];
}

@implementation RISettingsController
- (instancetype)initWithPage:(NSString *)page backgroundColor:(UIColor *)backgroundColor {
    self=[super initWithStyle:UITableViewStylePlain];
    if (self) { _page=[page copy] ?: @"home"; _menuBackgroundColor=backgroundColor ?: UIColor.systemBackgroundColor; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=[self titleForPage]; self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    self.tableView.rowHeight=UITableViewAutomaticDimension; self.tableView.estimatedRowHeight=56; self.view.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft;
    self.view.backgroundColor=self.menuBackgroundColor; self.tableView.backgroundColor=self.menuBackgroundColor;
    self.tableView.separatorColor=[UIColor.separatorColor colorWithAlphaComponent:0.28]; self.tableView.separatorInset=UIEdgeInsetsMake(0,62,0,18); self.navigationController.navigationBar.tintColor=UIColor.labelColor;
    if (@available(iOS 13.0,*)) {
        UINavigationBarAppearance *appearance=[UINavigationBarAppearance new]; [appearance configureWithOpaqueBackground]; appearance.backgroundColor=self.menuBackgroundColor; appearance.titleTextAttributes=@{NSForegroundColorAttributeName:UIColor.labelColor};
        self.navigationController.navigationBar.standardAppearance=appearance; self.navigationController.navigationBar.scrollEdgeAppearance=appearance; self.navigationController.navigationBar.compactAppearance=appearance;
    }
}
- (NSString *)titleForPage {
    if ([self.page isEqualToString:@"home"]) return @"RiseInsta";
    for (NSDictionary *item in RIMenuPages()) if ([item[@"id"] isEqual:self.page]) return item[@"title"];
    return @"RiseInsta";
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSArray<NSDictionary *> *)rows {
    if ([self.page isEqualToString:@"home"]) return RIMenuPages();
    if ([self.page isEqualToString:@"privacy"]) return @[@{@"feature":@2},@{@"feature":@3},@{@"target_toggle":@"priv_switch",@"title":@"إخفاء قوائم المتابعين والمتابَعين",@"detail":@"مفتاح RiseInsta محلي تجريبي؛ لا يغير إخفاء القوائم على الخادم.",@"icon":@"person.2.slash"}];
    if ([self.page isEqualToString:@"developer"]) return @[@{@"action":@"feature_probe",@"title":@"فحص كلاسات وإعدادات المطوّر",@"detail":@"استخراج أسماء الكلاسات والـselectors المتاحة في نسخة إنستغرام الحالية",@"icon":@"hammer"},@{@"action":@"interface",@"title":@"فحص واجهة القائمة الداخلية",@"detail":@"افتح قائمة الهز الأصلية أولًا، ثم انسخ شجرة الواجهة",@"icon":@"rectangle.3.group"},@{@"target_toggle":@"meta_employee_enabled",@"title":@"مفتاح تجربة المطوّر المحلي",@"detail":@"تفضيل محلي تجريبي فقط؛ لا يمنح صفة موظف أو صلاحيات Meta",@"icon":@"switch.2"},@{@"info":@YES,@"title":@"Internal Settings / Dogfooding Assistant",@"detail":@"فتح الأدوات الأصلية يتطلب تحديد نقطة الربط الفعلية؛ لا يتم تجاوز أهلية الحساب."}];
    if ([self.page isEqualToString:@"messages"]) return @[@{@"feature":@0},@{@"feature":@1}];
    if ([self.page isEqualToString:@"stories"]) return @[@{@"feature":@2},@{@"feature":@3},@{@"feature":@4}];
    if ([self.page isEqualToString:@"posts"]) return @[@{@"feature":@3},@{@"feature":@4}];
    if ([self.page isEqualToString:@"media"]) return @[@{@"action":@"open_media",@"title":@"تحميل الوسائط الظاهرة",@"detail":@"خيارات العنصر الحالي فقط",@"icon":@"arrow.down.to.line"},@{@"feature":@5},@{@"action":@"screen_record",@"title":RIScreenRecorderIsRecording()?@"إيقاف تسجيل الشاشة":@"بدء تسجيل الشاشة",@"detail":@"يسجل شاشة التطبيق؛ لا يسجل صوت المكالمات",@"icon":RIScreenRecorderIsRecording()?@"stop.circle":@"record.circle"},@{@"action":@"cancel",@"title":@"إلغاء التحميلات الجارية",@"icon":@"xmark.circle"}];
    if ([self.page isEqualToString:@"comments"]) return @[
        @{@"info":@YES,@"title":@"بحث التعليقات",@"detail":@"قيد الربط: يحتاج كلاس قائمة التعليقات في Instagram 456.0.0."},
        @{@"info":@YES,@"title":@"ترتيب التعليقات",@"detail":@"الأحدث والأقدم والأكثر إعجابًا وردودًا — يحتاج ربط الواجهة."},
        @{@"info":@YES,@"title":@"نسخ التعليق واسم المستخدم",@"detail":@"قيد الربط: القائمة المطولة للتعليقات."},
        @{@"info":@YES,@"title":@"تصدير أسماء المستخدمين",@"detail":@"قيد الربط: لا يتم جمع بيانات الحسابات تلقائيًا."}
    ];
    if ([self.page isEqualToString:@"calls"]) return @[
        @{@"info":@YES,@"title":@"تنزيل الرسائل الصوتية",@"detail":@"يحتاج ربط كلاس الرسالة الصوتية ومصدر الملف."},
        @{@"info":@YES,@"title":@"تسجيل المكالمات",@"detail":@"غير منفذ؛ يتطلب موافقة الأطراف والتحقق من قدرة التقاط الصوت."},
        @{@"info":@YES,@"title":@"تغيير الصوت ومعاينته",@"detail":@"غير منفذ؛ يحتاج محرك معالجة الصوت."}
    ];
    if ([self.page isEqualToString:@"ai"]) return @[
        @{@"info":@YES,@"title":@"مساعد Rise AI",@"detail":@"غير مربوط بخدمة AI؛ لا يتم إرسال محادثاتك لأي مزود."},
        @{@"info":@YES,@"title":@"الردود التلقائية",@"detail":@"غير منفذة؛ تحتاج API وإعدادات موافقة وصلاحيات."},
        @{@"info":@YES,@"title":@"شخصية المساعد وقاعدة المعرفة",@"detail":@"واجهة مخططة، لا يوجد مخزن بيانات."}
    ];
    if ([self.page isEqualToString:@"appearance"]) return @[@{@"editor":@0,@"title":@"إظهار زر تنزيل المنشور",@"icon":@"square.and.arrow.down"},@{@"editor":@1,@"title":@"إظهار زر تنزيل الريلز",@"icon":@"play.rectangle"}];
    if ([self.page isEqualToString:@"diagnostics"]) return @[@{@"action":@"diagnostics",@"title":@"تشخيص ونسخ التقرير",@"icon":@"doc.text.magnifyingglass"},@{@"action":@"interface",@"title":@"فحص الواجهة ونسخ الكلاسات",@"detail":@"افتح الشاشة المطلوبة أولًا لنسخ شجرتها الظاهرة",@"icon":@"rectangle.3.group"},@{@"action":@"feature_probe",@"title":@"فحص خصوصية الملف وخيارات المطوّر",@"detail":@"انسخ كلاسات الشاشة وتواقيع الدوال المتاحة",@"icon":@"text.magnifyingglass"},@{@"action":@"login",@"title":@"تشخيص حفظ تسجيل الدخول",@"detail":@"ينسخ مؤشرات metadata فقط؛ دون قيم الجلسة",@"icon":@"person.badge.key"}];
    if ([self.page isEqualToString:@"profile"]) return @[@{@"action":@"profile_media",@"title":@"تنزيل صورة الملف الشخصي",@"detail":@"افتح الملف الشخصي واضغط مطولًا على الصورة، ثم اختر تنزيل أو مشاركة.",@"icon":@"person.crop.square"}];
    return @[@{@"info":@YES,@"title":@"إعدادات الواجهة",@"detail":@"ألوان الصفحة تتبع مظهر النظام الفاتح أو الداكن."}];
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section { return self.rows.count; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)section { return nil; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)section {
    if ([self.page isEqualToString:@"privacy"]) return @"مفتاح إخفاء القوائم لا يثبت وحده تحديث إعداد الحساب؛ تحقق من ظهور القوائم من حساب آخر.";
    if ([self.page isEqualToString:@"messages"] || [self.page isEqualToString:@"stories"]) return @"تعتمد فعالية مفاتيح الخصوصية على توافق مسارات إنستغرام؛ راجع تقرير التشخيص للتحقق من تركيبها.";
    if ([self.page isEqualToString:@"appearance"]) return @"تظهر أيقونة التنزيل ضمن شريط تفاعلات المنشور؛ تظل مقاسات الخلايا متبعة لتخطيط إنستغرام.";
    if ([self.page isEqualToString:@"diagnostics"]) return @"تقارير الجلسة لا تتضمن كلمات مرور أو cookies أو tokens أو قيم الجلسة.";
    if ([self.page isEqualToString:@"media"]) return @"القصص: ضغطة مطولة بإصبع واحد. المنشورات والريلز: أزرار مدمجة أو ضغطة مطولة بإصبعين.";
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *row=self.rows[ip.row]; UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0; cell.backgroundColor=self.menuBackgroundColor;
    NSString *symbol=row[@"icon"];
    if (row[@"target_toggle"]) {
        NSString *key=row[@"target_toggle"]; cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"]; cell.imageView.image=[UIImage systemImageNamed:row[@"icon"]]; cell.imageView.tintColor=UIColor.systemBlueColor;
        UISwitch *sw=[UISwitch new]; sw.on=[NSUserDefaults.standardUserDefaults boolForKey:key]; sw.accessibilityIdentifier=key; [sw addTarget:self action:@selector(targetToggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if (row[@"feature"]) {
        NSUInteger index=[row[@"feature"] unsignedIntegerValue]; NSDictionary *feature=RIFeatures()[index]; cell.textLabel.text=feature[@"title"]; cell.detailTextLabel.text=feature[@"detail"]; cell.imageView.image=[UIImage systemImageNamed:feature[@"icon"]]; cell.imageView.tintColor=UIColor.systemBlueColor;
        UISwitch *sw=[UISwitch new]; sw.tag=(NSInteger)index; sw.on=RIPref(feature[@"key"],[feature[@"default"] boolValue]); [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if (row[@"editor"]) {
        cell.textLabel.text=row[@"title"]; UIImage *image=[UIImage systemImageNamed:row[@"icon"]]; cell.imageView.image=image; cell.imageView.tintColor=UIColor.secondaryLabelColor;
        NSArray *keys=@[@"editor_post",@"editor_reels"]; UISwitch *sw=[UISwitch new]; sw.tag=100+[row[@"editor"] integerValue]; sw.on=RIPref(keys[[row[@"editor"] unsignedIntegerValue]],YES); [sw addTarget:self action:@selector(editorToggle:) forControlEvents:UIControlEventValueChanged]; cell.accessoryView=sw; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if (row[@"action"]) {
        cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"]; cell.imageView.image=[UIImage systemImageNamed:row[@"icon"]]; cell.imageView.tintColor=UIColor.systemBlueColor; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else if (row[@"feature"]==nil && row[@"info"]) {
        cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"]; cell.textLabel.textColor=UIColor.secondaryLabelColor; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else {
        cell.textLabel.text=row[@"title"]; cell.detailTextLabel.text=row[@"detail"]; cell.imageView.image=[UIImage systemImageNamed:symbol]; cell.imageView.tintColor=UIColor.systemBlueColor; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (void)editorToggle:(UISwitch *)sw { NSArray *keys=@[@"editor_post",@"editor_reels"]; if(sw.tag>=100&&sw.tag<102) RISetPref(keys[sw.tag-100],sw.on); }
- (void)targetToggle:(UISwitch *)sw { NSString *key=sw.accessibilityIdentifier; if (!key.length) return; [NSUserDefaults.standardUserDefaults setBool:sw.on forKey:key]; [NSUserDefaults.standardUserDefaults synchronize]; RISetPref([@"target_" stringByAppendingString:key],sw.on); }
- (void)toggle:(UISwitch *)sw { if (sw.tag>=0 && (NSUInteger)sw.tag<RIFeatures().count) RISetPref(RIFeatures()[sw.tag][@"key"],sw.on); }
- (void)showDiagnostics {
    NSString *report=RIDiagnostics(); UIAlertController *a=[UIAlertController alertControllerWithTitle:@"تشخيص RiseInsta" message:report preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"نسخ التقرير" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){ UIPasteboard.generalPasteboard.string=report; }]]; [a addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tableView deselectRowAtIndexPath:ip animated:YES]; NSDictionary *row=self.rows[ip.row];
    if ([self.page isEqualToString:@"home"]) { if ([row[@"id"] isEqualToString:@"account_features"]) { RIShowAccountFeatures(self); return; } RISettingsController *next=[[RISettingsController alloc] initWithPage:row[@"id"] backgroundColor:self.menuBackgroundColor]; [self.navigationController pushViewController:next animated:YES]; return; }
    NSString *action=row[@"action"]; if ([action isEqualToString:@"cancel"]) { [RIDownloader cancelAll]; RIAlert(@"RiseInsta",@"تم طلب إلغاء التحميلات",self); }
    else if ([action isEqualToString:@"diagnostics"]) [self showDiagnostics];
    else if ([action isEqualToString:@"interface"]) { UIViewController *host=self.navigationController.presentingViewController; [self dismissViewControllerAnimated:YES completion:^{ RICopyInterfaceReport(host); }]; }
    else if ([action isEqualToString:@"feature_probe"]) { UIViewController *host=self.navigationController.presentingViewController; [self dismissViewControllerAnimated:YES completion:^{ dispatch_async(dispatch_get_main_queue(),^{ NSString *report=RIFeatureClassProbeReport(host); UIPasteboard.generalPasteboard.string=report; RIAlert(@"فحص الخصوصية والمطوّر",[NSString stringWithFormat:@"نُسخ التقرير (%lu حرفًا). أرسله هنا بعد فتح شاشة الخصوصية أو إعدادات المطوّر.",(unsigned long)report.length],host); }); }]; }
    else if ([action isEqualToString:@"login"]) { UIPasteboard.generalPasteboard.string=RILoginSessionDiagnostics(); RIAlert(@"تشخيص حفظ تسجيل الدخول",@"نُسخ تقرير الحالة metadata دون أسرار الجلسة.",self); }
    else if ([action isEqualToString:@"screen_record"]) { UIViewController *host=self.navigationController.presentingViewController; BOOL recording=RIScreenRecorderIsRecording(); [self dismissViewControllerAnimated:YES completion:^{ if(recording) RIScreenRecorderStop(host); else RIScreenRecorderStart(host); }]; }
    else if ([action isEqualToString:@"open_media"] || [action isEqualToString:@"profile_media"]) { UIViewController *host=self.navigationController.presentingViewController; [self dismissViewControllerAnimated:YES completion:^{ RIShowCurrentMediaMenu(host); }]; }
}
@end

void RIShowSettings(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(),^{ UIViewController *top=RITopController(host); if (!top || [top isKindOfClass:RISettingsController.class] || [top isKindOfClass:UIAlertController.class]) return;
        UIColor *background=top.viewIfLoaded.backgroundColor;
        if (!background || CGColorGetAlpha(background.CGColor)<0.95) background=top.traitCollection.userInterfaceStyle==UIUserInterfaceStyleDark ? UIColor.blackColor : UIColor.whiteColor;
        if (@available(iOS 13.0,*)) background=[background resolvedColorWithTraitCollection:top.traitCollection];
        RISettingsController *root=[[RISettingsController alloc] initWithPage:@"home" backgroundColor:background];
        UINavigationController *nav=[[UINavigationController alloc] initWithRootViewController:root];
        nav.modalPresentationStyle=UIModalPresentationPageSheet;
        if (@available(iOS 15.0,*)) {
            UISheetPresentationController *sheet=nav.sheetPresentationController;
            sheet.detents=@[UISheetPresentationControllerDetent.mediumDetent,UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible=YES;
            sheet.prefersScrollingExpandsWhenScrolledToEdge=YES;
        }
        if (@available(iOS 13.0,*)) nav.overrideUserInterfaceStyle=top.traitCollection.userInterfaceStyle;
        [top presentViewController:nav animated:YES completion:nil];
    });
}

// Temporary, unobtrusive entry point while the Instagram 456.0.0
// profile navigation class is being mapped. Does not add an overlay button.
@interface RIMenuGestureRelay : NSObject <UIGestureRecognizerDelegate>
@end
@implementation RIMenuGestureRelay
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
- (void)openOnHold:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    UIWindow *window=[gesture.view isKindOfClass:UIWindow.class] ? (UIWindow *)gesture.view : gesture.view.window;
    if (window) RIShowSettings(window.rootViewController);
}
- (void)openOnTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    UIWindow *window=[gesture.view isKindOfClass:UIWindow.class] ? (UIWindow *)gesture.view : gesture.view.window;
    if (window) RIShowSettings(window.rootViewController);
}
@end

void RIInstallMenu(void) {
    NSCAssert(NSThread.isMainThread,@"Menu gestures must be installed on the main thread");
    static RIMenuGestureRelay *relay=nil;
    static dispatch_once_t once;
    dispatch_once(&once,^{ relay=[RIMenuGestureRelay new]; });
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.isKeyWindow) continue;
            BOOL already=NO;
            for (UIGestureRecognizer *g in window.gestureRecognizers)
                if ([g.name isEqualToString:@"RiseInstaMenuThreeFingerHold"]) {
                    already=YES; break;
                }
            if (already) continue;
            UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:relay action:@selector(openOnHold:)];
            hold.name=@"RiseInstaMenuThreeFingerHold";
            hold.numberOfTouchesRequired=3;
            hold.minimumPressDuration=0.7;
            hold.cancelsTouchesInView=NO;
            hold.delegate=relay;
            [window addGestureRecognizer:hold];

            // A separate fallback for Instagram screens that consume long presses.
            UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:relay action:@selector(openOnTap:)];
            tap.name=@"RiseInstaMenuThreeFingerDoubleTap";
            tap.numberOfTouchesRequired=3;
            tap.numberOfTapsRequired=2;
            tap.cancelsTouchesInView=NO;
            tap.delegate=relay;
            [window addGestureRecognizer:tap];
            RILog(@"Installed RiseInsta 3-finger menu gestures in %@",NSStringFromClass(window.class));
        }
    }
}
