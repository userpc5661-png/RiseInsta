#import "RICommon.h"
#import <Security/Security.h>
#import <mach-o/dyld.h>
#import <ReplayKit/ReplayKit.h>

NSString *const RISettingsChanged = @"RiseInstaSettingsChanged";
static NSUserDefaults *RIDefaults(void) {
    // The host's sandbox works with a changed bundle ID and without app-group entitlements.
    return NSUserDefaults.standardUserDefaults;
}
BOOL RIPref(NSString *key, BOOL fallback) {
    NSString *name = [@"com.riseinsta." stringByAppendingString:key];
    id value = [RIDefaults() objectForKey:name];
    if (!value) {
        // Migrate values from the original implementation when that domain is accessible.
        value = [[[NSUserDefaults alloc] initWithSuiteName:@"com.riseinsta.prefs"] objectForKey:key];
    }
    return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : fallback;
}
void RISetPref(NSString *key, BOOL value) {
    [RIDefaults() setBool:value forKey:[@"com.riseinsta." stringByAppendingString:key]];
    [NSNotificationCenter.defaultCenter postNotificationName:RISettingsChanged object:key];
}
NSArray<NSDictionary *> *RIFeatures(void) {
    static NSArray *rows; static dispatch_once_t once;
    dispatch_once(&once, ^{
        rows = @[
            @{@"key":RI_GHOST_SEEN,@"title":@"إخفاء قراءة الرسائل",@"detail":@"يتطلب توفر مسار متوافق في إصدار إنستغرام",@"icon":@"eye.slash",@"default":@NO},
            @{@"key":RI_GHOST_TYPING,@"title":@"إخفاء مؤشر الكتابة",@"detail":@"منع إرسال مؤشر الكتابة عبر المسار المتاح",@"icon":@"text.bubble",@"default":@NO},
            @{@"key":RI_GHOST_STORY,@"title":@"إخفاء مشاهدة القصص",@"detail":@"يتطلب توفر مسار متوافق في إصدار إنستغرام",@"icon":@"eye.slash",@"default":@NO},
            @{@"key":RI_HIDE_FEED_ADS,@"title":@"إخفاء الإعلانات",@"detail":@"في مسارات الخلاصة والقصص والريلز المتاحة",@"icon":@"rectangle.slash",@"default":@NO},
            @{@"key":RI_DOWNLOAD,@"title":@"قائمة الوسائط",@"detail":@"ضغطة مطولة على القصة، وبإصبعين على بقية الوسائط",@"icon":@"arrow.down.circle",@"default":@YES},
            @{@"key":RI_SAVE_TO_PHOTOS,@"title":@"حفظ في الصور",@"detail":@"عند تعطيله تظهر نافذة مشاركة الملف",@"icon":@"photo",@"default":@YES}
        ];
    }); return rows;
}
UIViewController *RITopController(UIViewController *hint) {
    NSCAssert(NSThread.isMainThread, @"UI must run on main thread");
    UIViewController *top = hint.viewIfLoaded.window ? hint : nil;
    if (!top) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) { top = window.rootViewController; break; }
            }
            if (top) break;
        }
    }
    for (NSUInteger n=0; top && n<32; n++) {
        UIViewController *next = nil;
        if (top.presentedViewController && !top.presentedViewController.isBeingDismissed) next = top.presentedViewController;
        else if ([top isKindOfClass:UINavigationController.class]) next = ((UINavigationController *)top).visibleViewController;
        else if ([top isKindOfClass:UITabBarController.class]) next = ((UITabBarController *)top).selectedViewController;
        if (!next || next == top) break;
        top = next;
    } return top;
}
void RIAlert(NSString *title, NSString *message, UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = RITopController(host);
        if (!top || [top isKindOfClass:UIAlertController.class] || top.isBeingDismissed) { RILog(@"%@: %@",title,message); return; }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}
static NSMutableArray<NSString *> *RILogs(void) {
    static NSMutableArray *logs; static dispatch_once_t once;
    dispatch_once(&once, ^{ logs=[NSMutableArray array]; }); return logs;
}
void RILog(NSString *format, ...) {
    va_list args; va_start(args,format); NSString *message=[[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    @synchronized(RILogs()) {
        if (RILogs().count>=150) [RILogs() removeObjectAtIndex:0];
        [RILogs() addObject:message];
    }
    NSLog(@"[RiseInsta] %@",message);
}
NSString *RIDiagnostics(void) {
    NSDictionary *info=NSBundle.mainBundle.infoDictionary;
    NSMutableDictionary *prefs=[NSMutableDictionary dictionary];
    for (NSDictionary *row in RIFeatures()) prefs[row[@"key"]]=@(RIPref(row[@"key"],[row[@"default"] boolValue]));
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta 1.2.9 beta interface-inspector\nBundle: %@\nInstagram: %@ (%@)\niOS: %@\nDownloads: %lu\nScreenRecording: %@\nPrefs: %@\nCalls=0 means no observed invocation, not working-feature proof.\n\n%@\n\n",NSBundle.mainBundle.bundleIdentifier,info[@"CFBundleShortVersionString"],info[@"CFBundleVersion"],UIDevice.currentDevice.systemVersion,(unsigned long)RIDownloader.activeCount,RPScreenRecorder.sharedRecorder.isRecording?@"active":@"idle",prefs,RIHookStatus()];
    @synchronized(RILogs()) { [report appendString:[RILogs() componentsJoinedByString:@"\n"]]; }
    return report;
}

static NSString *RIKeychainStatusName(OSStatus status) {
    switch (status) {
        case errSecSuccess: return @"success";
        case errSecItemNotFound: return @"item-not-found";
        case errSecMissingEntitlement: return @"missing-entitlement";
        case errSecInteractionNotAllowed: return @"interaction-not-allowed";
        case errSecAuthFailed: return @"authentication-failed";
        default: return [NSString stringWithFormat:@"OSStatus(%d)",(int)status];
    }
}

static NSString *RIKeychainProbe(NSString *service) {
    NSDictionary *query=@{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                          (__bridge id)kSecAttrService:service,
                          (__bridge id)kSecReturnAttributes:@YES,
                          (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitAll,
                          (__bridge id)kSecUseAuthenticationUI:(__bridge id)kSecUseAuthenticationUIFail};
    CFTypeRef result=NULL;
    OSStatus status=SecItemCopyMatching((__bridge CFDictionaryRef)query,&result);
    NSUInteger count=0; NSMutableSet<NSString *> *groups=[NSMutableSet set];
    if (status==errSecSuccess && result) {
        NSArray *items=CFGetTypeID(result)==CFArrayGetTypeID() ? (__bridge NSArray *)result : @[(__bridge id)result];
        count=items.count;
        for (id item in items) {
            id group=[item isKindOfClass:NSDictionary.class] ? item[(__bridge id)kSecAttrAccessGroup] : nil;
            if ([group isKindOfClass:NSString.class] && [group length]) [groups addObject:group];
        }
    }
    if (result) CFRelease(result);
    NSString *groupText=groups.count ? [[groups allObjects] componentsJoinedByString:@","] : @"none-visible";
    return [NSString stringWithFormat:@"service=%@ status=%@ count=%lu accessGroups=%@",service,RIKeychainStatusName(status),(unsigned long)count,groupText];
}

static NSArray<NSString *> *RIInterestingDefaultsKeys(NSUserDefaults *defaults) {
    NSDictionary *snapshot=defaults.dictionaryRepresentation;
    NSArray *needles=@[@"session",@"auth",@"login",@"token",@"cookie",@"credential",@"header"];
    NSMutableArray<NSString *> *matches=[NSMutableArray array];
    for (id candidate in snapshot) {
        if (![candidate isKindOfClass:NSString.class]) continue;
        NSString *key=(NSString *)candidate, *lower=key.lowercaseString;
        BOOL interesting=NO;
        for (NSString *needle in needles) if ([lower containsString:needle]) { interesting=YES; break; }
        if (!interesting) continue;
        id value=snapshot[key]; NSString *shape=NSStringFromClass([value class]) ?: @"unknown"; NSUInteger length=0;
        if ([value isKindOfClass:NSString.class]) length=[value length];
        else if ([value isKindOfClass:NSData.class]) length=[value length];
        else if ([value isKindOfClass:NSArray.class] || [value isKindOfClass:NSDictionary.class] || [value isKindOfClass:NSSet.class]) length=[value count];
        [matches addObject:[NSString stringWithFormat:@"%@ type=%@ size=%lu",key,shape,(unsigned long)length]];
    }
    [matches sortUsingSelector:@selector(compare:)];
    return matches;
}

NSString *RILoginSessionDiagnostics(void) {
    NSDictionary *info=NSBundle.mainBundle.infoDictionary;
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta login-persistence diagnostic (metadata only)\nInstagram=%@ (%@) bundle=%@\niOS=%@ captured=%@ uptime=%.0fs appState=%ld\nNo password, cookie, token, authheader or session value is read or included.\n\nKeychain generic-password metadata (queries request attributes only):\n",
        info[@"CFBundleShortVersionString"] ?: @"?",info[@"CFBundleVersion"] ?: @"?",NSBundle.mainBundle.bundleIdentifier ?: @"?",UIDevice.currentDevice.systemVersion,NSDate.date,NSProcessInfo.processInfo.systemUptime,(long)UIApplication.sharedApplication.applicationState];
    for (NSString *service in @[@"users.authheaders",@"users.authheaders.service",@"com.instagram.usersession.sessiondata"])
        [report appendFormat:@"%@\n",RIKeychainProbe(service)];

    NSString *group=@"group.com.burbn.instagram";
    NSURL *container=nil;
    if ([NSFileManager.defaultManager respondsToSelector:@selector(containerURLForSecurityApplicationGroupIdentifier:)])
        container=[NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:group];
    [report appendFormat:@"AppGroup %@ container=%@\n",group,container ? @"available" : @"unavailable"];
    for (NSString *suiteName in @[group,@"com.beegram.shared.sessionbridge"]) {
        NSUserDefaults *suite=[[NSUserDefaults alloc] initWithSuiteName:suiteName];
        NSArray<NSString *> *keys=suite ? RIInterestingDefaultsKeys(suite) : @[];
        [report appendFormat:@"Defaults suite=%@ readable=%@ matchingKeys=%@\n",suiteName,suite ? @"yes" : @"no",keys.count ? [keys componentsJoinedByString:@"; "] : @"none"];
    }
    NSArray<NSString *> *localKeys=RIInterestingDefaultsKeys(NSUserDefaults.standardUserDefaults);
    [report appendFormat:@"Standard defaults matchingKeys=%@\n",localKeys.count ? [localKeys componentsJoinedByString:@"; "] : @"none"];

    NSMutableArray<NSString *> *modules=[NSMutableArray array];
    for (uint32_t i=0;i<_dyld_image_count();i++) {
        const char *raw=_dyld_get_image_name(i); if (!raw) continue;
        NSString *path=[NSString stringWithUTF8String:raw]; NSString *name=path.lastPathComponent.lowercaseString;
        if ([name containsString:@"riseinsta"] || [name containsString:@"beegram"]) [modules addObject:path.lastPathComponent];
    }
    [report appendFormat:@"Loaded tweak modules=%@\n",modules.count ? [modules componentsJoinedByString:@", "] : @"none detected"];
    [report appendString:@"\nCompare one report immediately after the first successful login and another after relaunch, before trying to log in again. Keychain status/count and matching key names are reported; secret values are never exported.\n"];
    return report;
}
static NSMethodSignature *RISignature(id object, NSString *selector) {
    if (!object) return nil;
    SEL sel=NSSelectorFromString(selector);
    if (![object respondsToSelector:sel]) return nil;
    return [object methodSignatureForSelector:sel];
}
id RIGet(id object, NSString *selector) {
    NSMethodSignature *sig=RISignature(object,selector);
    if (!sig || sig.numberOfArguments!=2 || sig.methodReturnType[0]!='@') return nil;
    @try { return ((id (*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(selector)); }
    @catch (NSException *e) { RILog(@"Getter %@ raised %@",selector,e.name); return nil; }
}
BOOL RIBool(id object, NSString *selector) {
    NSMethodSignature *sig=RISignature(object,selector);
    if (!sig || sig.numberOfArguments!=2 || !strchr("Bc",sig.methodReturnType[0])) return NO;
    return ((BOOL (*)(id,SEL))objc_msgSend)(object,NSSelectorFromString(selector));
}
