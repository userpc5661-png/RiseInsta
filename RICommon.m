#import "RICommon.h"

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
            @{@"key":RI_GHOST_SEEN,@"title":@"إخفاء قراءة الرسائل",@"detail":@"يعمل فقط عند توفر hooks متوافقة؛ راجع التشخيص",@"default":@NO},
            @{@"key":RI_GHOST_TYPING,@"title":@"إخفاء مؤشر الكتابة",@"detail":@"منع إرسال مؤشر الكتابة عبر المسارات المتاحة",@"default":@NO},
            @{@"key":RI_GHOST_STORY,@"title":@"إخفاء مشاهدة القصص",@"detail":@"التوافق يعتمد على إصدار إنستغرام؛ اختبر بحساب ثانٍ",@"default":@NO},
            @{@"key":RI_HIDE_FEED_ADS,@"title":@"إخفاء الإعلانات",@"detail":@"مسارات الخلاصة والقصص والريلز المرصودة في Beegram، عند توفرها",@"default":@NO},
            @{@"key":RI_DOWNLOAD,@"title":@"قائمة الوسائط",@"detail":@"اضغط مطولًا بإصبعين على الوسائط للتحميل أو النسخ",@"default":@YES},
            @{@"key":RI_SAVE_TO_PHOTOS,@"title":@"حفظ في الصور",@"detail":@"عند تعطيله تظهر نافذة مشاركة الملف",@"default":@YES},
            @{@"key":@"floating_settings",@"title":@"زر الإعدادات العائم",@"detail":@"يمكن فتح الإعدادات أيضًا بالضغط المطول بثلاثة أصابع",@"default":@YES}
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
    NSMutableString *report=[NSMutableString stringWithFormat:@"RiseInsta 1.1.3 interface-inspector\nBundle: %@\nInstagram: %@ (%@)\niOS: %@\nDownloads: %lu\nPrefs: %@\nCalls=0 means no observed invocation, not working-feature proof.\n\n%@\n\n",NSBundle.mainBundle.bundleIdentifier,info[@"CFBundleShortVersionString"],info[@"CFBundleVersion"],UIDevice.currentDevice.systemVersion,(unsigned long)RIDownloader.activeCount,prefs,RIHookStatus()];
    @synchronized(RILogs()) { [report appendString:[RILogs() componentsJoinedByString:@"\n"]]; }
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
