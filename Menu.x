// Menu.x — RiseInsta settings screen, injected into Instagram's own settings.
// Each switch writes a pref that the hooks in Tweak.x read live.
#import <UIKit/UIKit.h>
#import "Prefs.h"

@interface RISettingsController : UITableViewController
@end

typedef struct { NSString *key; NSString *title; NSString *sub; BOOL def; } RIRow;

@implementation RISettingsController {
    NSArray<NSValue *> *_rows;
    NSArray<NSString *> *_titles;
    NSArray<NSString *> *_subs;
    NSArray<NSString *> *_keys;
    NSArray<NSNumber *> *_defs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"RiseInsta";
    _titles = @[ @"الوضع الشبح — إخفاء المشاهدة", @"الوضع الشبح — منع علم الكتابة",
                 @"الوضع الشبح — عدم مشاهدة الستوري", @"إخفاء الإعلانات الممولة",
                 @"زر التحميل", @"حفظ التحميلات في الصور" ];
    _subs = @[ @"لا تُرسل إشعار القراءة في الرسائل", @"لا يظهر أنك تكتب",
               @"لا يُسجّل أنك شاهدت الستوري", @"إزالة المنشورات الممولة من الفيد",
               @"زر تحميل على الصور والفيديو", @"بدل مشاركة الملف" ];
    _keys = @[ RI_GHOST_SEEN, RI_GHOST_TYPING, RI_GHOST_STORY,
               RI_HIDE_FEED_ADS, RI_DOWNLOAD, RI_SAVE_TO_PHOTOS ];
    _defs = @[ @NO, @NO, @NO, @NO, @YES, @YES ];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return _keys.count; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.textLabel.text = _titles[ip.row];
    cell.detailTextLabel.text = _subs[ip.row];
    cell.detailTextLabel.numberOfLines = 0;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *sw = [[UISwitch alloc] init];
    sw.tag = ip.row;
    sw.on = RIPref(_keys[ip.row], [_defs[ip.row] boolValue]);
    [sw addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)toggle:(UISwitch *)sw { RISetPref(_keys[sw.tag], sw.on); }

@end

// Add a "RiseInsta" row to Instagram's settings/options list.
%hook IGOptionsTableViewController
- (void)viewDidLoad {
    %orig;
    UIBarButtonItem *b = [[UIBarButtonItem alloc] initWithTitle:@"RiseInsta"
        style:UIBarButtonItemStylePlain target:self action:@selector(ri_open)];
    self.navigationItem.rightBarButtonItem = b;
}
%new
- (void)ri_open {
    RISettingsController *vc = [[RISettingsController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:vc animated:YES];
}
%end
