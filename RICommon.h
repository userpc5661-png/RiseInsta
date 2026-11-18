#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

FOUNDATION_EXPORT NSString *const RISettingsChanged;
FOUNDATION_EXPORT BOOL RIPref(NSString *key, BOOL fallback);
FOUNDATION_EXPORT void RISetPref(NSString *key, BOOL value);
FOUNDATION_EXPORT NSArray<NSDictionary *> *RIFeatures(void);
FOUNDATION_EXPORT UIViewController *RITopController(UIViewController *hint);
FOUNDATION_EXPORT void RIAlert(NSString *title, NSString *message, UIViewController *host);
FOUNDATION_EXPORT void RILog(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);
FOUNDATION_EXPORT NSString *RIDiagnostics(void);
FOUNDATION_EXPORT id RIGet(id object, NSString *selector);
FOUNDATION_EXPORT BOOL RIBool(id object, NSString *selector);
FOUNDATION_EXPORT void RIInstallHooks(void);
FOUNDATION_EXPORT void RIInstallMenu(void);
FOUNDATION_EXPORT void RIShowSettings(UIViewController *host);
FOUNDATION_EXPORT void RIAttachMediaMenu(UIView *view);
FOUNDATION_EXPORT void RITrackStoryController(id controller);
FOUNDATION_EXPORT void RIShowCurrentMediaMenu(UIViewController *host);
FOUNDATION_EXPORT void RIAttachContextMenuButton(UIView *view);
FOUNDATION_EXPORT NSDictionary *RIHookStatus(void);

#define RI_GHOST_SEEN @"ghost_seen"
#define RI_GHOST_TYPING @"ghost_typing"
#define RI_GHOST_STORY @"ghost_story"
#define RI_HIDE_FEED_ADS @"hide_feed_ads"
#define RI_DOWNLOAD @"download"
#define RI_SAVE_TO_PHOTOS @"save_to_photos"

@interface RIDownloader : NSObject
+ (void)saveURL:(NSURL *)url kind:(NSString *)kind share:(BOOL)share from:(UIViewController *)host;
+ (void)cancelAll;
+ (NSUInteger)activeCount;
@end
