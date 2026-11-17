// Prefs.h — RiseInsta shared preferences. Every toggle is read here so the
// menu switches actually control the hooks (not hardcoded YES/NO).
#import <Foundation/Foundation.h>

static NSString *const RIPrefsDomain = @"com.riseinsta.prefs";

static inline BOOL RIPref(NSString *key, BOOL defaultValue) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:RIPrefsDomain];
    id v = [d objectForKey:key];
    return v == nil ? defaultValue : [v boolValue];
}

static inline void RISetPref(NSString *key, BOOL value) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:RIPrefsDomain];
    [d setBool:value forKey:key];
    [d synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RiseInstaSettingsChanged" object:nil];
}

// Keys
#define RI_GHOST_SEEN      @"ghost_seen"       // don't send read receipts in DMs
#define RI_GHOST_TYPING    @"ghost_typing"     // don't broadcast typing indicator
#define RI_GHOST_STORY     @"ghost_story"      // don't mark stories as seen
#define RI_HIDE_FEED_ADS   @"hide_feed_ads"    // remove sponsored feed/story/reel items
#define RI_DOWNLOAD        @"download"         // enable download buttons
#define RI_SAVE_TO_PHOTOS  @"save_to_photos"   // downloads go to Photos
