// RiseInsta Settings — original UIKit implementation.
// Instagram-inspired accent colors and native SF Symbols; no SCInsta code is used.
#import <UIKit/UIKit.h>
#import "Prefs.h"

static UIColor *RIColor(CGFloat r, CGFloat g, CGFloat b) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0];
}
static UIColor *RIPink(void) { return RIColor(225, 48, 108); }
static UIColor *RIPurple(void) { return RIColor(131, 58, 180); }

@interface RIGradientHeader : UIView
@end
@implementation RIGradientHeader
+ (Class)layerClass { return [CAGradientLayer class]; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        CAGradientLayer *gradient = (CAGradientLayer *)self.layer;
        gradient.colors = @[(id)RIColor(81,91,212).CGColor,
                            (id)RIPurple().CGColor,
                            (id)RIPink().CGColor,
                            (id)RIColor(245,133,41).CGColor];
        gradient.startPoint = CGPointMake(0, 0.25);
        gradient.endPoint = CGPointMake(1, 0.85);
        self.layer.cornerRadius = 20;
        self.layer.masksToBounds = YES;
        UILabel *title = [[UILabel alloc] init];
        title.text = @"RiseInsta";
        title.textColor = UIColor.whiteColor;
        title.font = [UIFont systemFontOfSize:29 weight:UIFontWeightBold];
        UILabel *subtitle = [[UILabel alloc] init];
        subtitle.text = @"Your Instagram, your way";
        subtitle.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        subtitle.textColor = [UIColor colorWithWhite:1 alpha:0.87];
        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, subtitle]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 5;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:stack];
        [NSLayoutConstraint activateConstraints:@[
            [stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:22],
            [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-18],
            [stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}
@end

@interface RISettingsController : UITableViewController
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *sections;
@end

@implementation RISettingsController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RiseInsta";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.tableView.rowHeight = 75;
    self.tableView.estimatedSectionHeaderHeight = 48;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.sections = @[
        @{@"name": @"الخصوصية", @"subtitle": @"تحكم بطريقة ظهور نشاطك",
          @"items": @[
              @{@"title": @"إخفاء قراءة الرسائل", @"detail": @"لا ترسل إشعار المشاهدة", @"icon": @"eye.slash.fill", @"key": RI_GHOST_SEEN, @"default": @NO},
              @{@"title": @"إخفاء حالة الكتابة", @"detail": @"لا يظهر أنك تكتب رسالة", @"icon": @"ellipsis.bubble.fill", @"key": RI_GHOST_TYPING, @"default": @NO},
              @{@"title": @"إخفاء مشاهدة الستوري", @"detail": @"لا تسجل مشاهدتك للقصص", @"icon": @"circle.dashed.inset.filled", @"key": RI_GHOST_STORY, @"default": @NO}
          ]},
        @{@"name": @"التصفح", @"subtitle": @"تجربة مشاهدة أنظف",
          @"items": @[
              @{@"title": @"إخفاء المنشورات الممولة", @"detail": @"فلترة الإعلانات من الخلاصة", @"icon": @"rectangle.stack.badge.minus", @"key": RI_HIDE_FEED_ADS, @"default": @NO}
          ]},
        @{@"name": @"التحميلات", @"subtitle": @"احتفظ بالصور والفيديوهات",
          @"items": @[
              @{@"title": @"إظهار خيار التحميل", @"detail": @"إضافة تحميل لقائمة الوسائط", @"icon": @"arrow.down.circle.fill", @"key": RI_DOWNLOAD, @"default": @YES},
              @{@"title": @"الحفظ في تطبيق الصور", @"detail": @"بدلاً من فتح نافذة المشاركة", @"icon": @"photo.on.rectangle.angled", @"key": RI_SAVE_TO_PHOTOS, @"default": @YES}
          ]}
    ];
    RIGradientHeader *header = [[RIGradientHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 135)];
    UIView *holder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 155)];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [holder addSubview:header];
    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:holder.leadingAnchor constant:16],
        [header.trailingAnchor constraintEqualToAnchor:holder.trailingAnchor constant:-16],
        [header.topAnchor constraintEqualToAnchor:holder.topAnchor constant:10],
        [header.heightAnchor constraintEqualToConstant:135]
    ]];
    self.tableView.tableHeaderView = holder;
    UILabel *footer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 74)];
    footer.text = @"RiseInsta • إعدادات مستقلة\nقد تختلف فاعلية بعض الخيارات حسب إصدار إنستغرام.";
    footer.font = [UIFont systemFontOfSize:12];
    footer.textColor = UIColor.secondaryLabelColor;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.numberOfLines = 0;
    self.tableView.tableFooterView = footer;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"items"] count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"name"];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section][@"subtitle"];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"RISettingsRow";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    cell.detailTextLabel.text = item[@"detail"];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.layer.cornerRadius = 12;
    cell.layer.masksToBounds = YES;
    UIImageSymbolConfiguration *symbolConfig = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    UIImage *iconImage = [UIImage systemImageNamed:item[@"icon"] withConfiguration:symbolConfig];
    cell.imageView.image = iconImage;
    cell.imageView.tintColor = (indexPath.section == 2) ? RIPurple() : RIPink();
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.onTintColor = RIPink();
    toggle.accessibilityLabel = item[@"title"];
    toggle.on = RIPref(item[@"key"], [item[@"default"] boolValue]);
    toggle.tag = indexPath.section * 100 + indexPath.row;
    [toggle addTarget:self action:@selector(ri_toggle:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = toggle;
    return cell;
}
- (void)ri_toggle:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    if (section < 0 || section >= (NSInteger)self.sections.count) return;
    NSArray *items = self.sections[section][@"items"];
    if (row < 0 || row >= (NSInteger)items.count) return;
    RISetPref(items[row][@"key"], sender.isOn);
}
@end

// Keep the existing app settings, adding one entry to open RiseInsta.
%hook IGOptionsTableViewController
- (void)viewDidLoad {
    %orig;
    UIBarButtonItem *entry = [[UIBarButtonItem alloc] initWithTitle:@"RiseInsta ✦"
        style:UIBarButtonItemStylePlain target:self action:@selector(ri_openSettings)];
    entry.tintColor = RIPink();
    self.navigationItem.rightBarButtonItem = entry;
}
%new
- (void)ri_openSettings {
    RISettingsController *settings = [[RISettingsController alloc] init];
    if (self.navigationController) {
        [self.navigationController pushViewController:settings animated:YES];
    } else {
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
        [self presentViewController:nav animated:YES completion:nil];
    }
}
%end
