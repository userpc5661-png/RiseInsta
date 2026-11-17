#import "RICommon.h"
#import "RITargets.h"
#import "RIRuntime.h"

static NSMutableDictionary<NSString *,NSString *> *RIStatuses(void) {
    static NSMutableDictionary *d; static dispatch_once_t once; dispatch_once(&once,^{ d=[NSMutableDictionary dictionary]; }); return d;
}
NSDictionary *RIHookStatus(void) { @synchronized(RIStatuses()) { return [RIStatuses() copy]; } }
static void RIStatus(NSString *key,NSString *status) {
    @synchronized(RIStatuses()) {
        if ([RIStatuses()[key] isEqualToString:status]) return;
        RIStatuses()[key]=status;
    } RILog(@"%@: %@",key,status);
}
static BOOL RIAlready(NSString *key) { @synchronized(RIStatuses()) { return [RIStatuses()[key] isEqualToString:@"installed"]; } }
static void RIReplace(Class cls,SEL sel,Method method,IMP replacement,NSString *key) {
    RIOverrideMethod(cls,sel,method,replacement);
    RIStatus(key,@"installed");
}
static void RIGhost(NSDictionary *target) {
    NSString *name=target[@"class"], *selector=target[@"sel"], *shape=target[@"shape"], *pref=target[@"pref"];
    NSString *key=[NSString stringWithFormat:@"%@/%@",name,selector];
    if (RIAlready(key)) return;
    Class cls=NSClassFromString(name); SEL sel=NSSelectorFromString(selector);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    NSString *ret=[shape isEqualToString:@"bool0"] ? @"Bc" : @"v";
    NSArray *args=@[];
    if ([shape isEqualToString:@"void2"]) args=@[@"@",@"@"];
    else if ([shape isEqualToString:@"void3"]) args=@[@"@",@"@",@"@"];
    else if ([shape isEqualToString:@"typing4"]) args=@[@"Bc",@"@",@"@",@"qQ"];
    Method method=RICompatibleMethod(cls,sel,ret,args);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method), replacement=NULL;
    if ([shape isEqualToString:@"bool0"]) replacement=imp_implementationWithBlock(^BOOL(id object){
        return RIPref(pref,NO) ? NO : ((BOOL (*)(id,SEL))original)(object,sel);
    });
    else if ([shape isEqualToString:@"void2"]) replacement=imp_implementationWithBlock(^(id object,id a,id b){
        if (!RIPref(pref,NO)) ((void (*)(id,SEL,id,id))original)(object,sel,a,b);
    });
    else if ([shape isEqualToString:@"void3"]) replacement=imp_implementationWithBlock(^(id object,id a,id b,id c){
        if (!RIPref(pref,NO)) ((void (*)(id,SEL,id,id,id))original)(object,sel,a,b,c);
    });
    else if ([shape isEqualToString:@"typing4"]) replacement=imp_implementationWithBlock(^(id object,BOOL active,id a,id b,NSInteger type){
        if (!RIPref(pref,NO)) ((void (*)(id,SEL,BOOL,id,id,NSInteger))original)(object,sel,active,a,b,type);
    });
    if (replacement) RIReplace(cls,sel,method,replacement,key);
}
static BOOL RIIsAd(id object) {
    for (NSString *predicate in RIAdPredicates()) if (RIBool(object,predicate)) return YES;
    Class adClass=NSClassFromString(RI_AD_CLASS); return adClass && [object isKindOfClass:adClass];
}
static void RIFeed(void) {
    NSString *key=[RI_FEED_CLASS stringByAppendingFormat:@"/%@",RI_FEED_SELECTOR];
    if (RIAlready(key)) return;
    Class cls=NSClassFromString(RI_FEED_CLASS); SEL sel=NSSelectorFromString(RI_FEED_SELECTOR);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    Method method=RICompatibleMethod(cls,sel,@"@",@[@"@"]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^id(id object,id adapter){
        id result=((id (*)(id,SEL,id))original)(object,sel,adapter);
        if (!RIPref(RI_HIDE_FEED_ADS,NO) || ![result isKindOfClass:NSArray.class]) return result;
        NSMutableArray *filtered=[NSMutableArray arrayWithCapacity:[result count]];
        for (id item in result) if (!RIIsAd(item)) [filtered addObject:item];
        return [filtered copy];
    }); RIReplace(cls,sel,method,replacement,key);
}
static void RIMediaHook(NSString *name) {
    NSString *key=[name stringByAppendingString:@"/didMoveToWindow"];
    if (RIAlready(key)) return;
    Class cls=NSClassFromString(name);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    if (![cls isSubclassOfClass:UIView.class]) { RIStatus(key,@"not a UIView"); return; }
    SEL sel=@selector(didMoveToWindow); Method method=RICompatibleMethod(cls,sel,@"v",@[]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^(UIView *view){
        ((void (*)(id,SEL))original)(view,sel);
        if (view.window) RIAttachMediaMenu(view);
    }); RIReplace(cls,sel,method,replacement,key);
}
void RIInstallHooks(void) {
    NSCAssert(NSThread.isMainThread,@"Hook installation must be serialized");
    for (NSDictionary *target in RIGhostTargets()) RIGhost(target);
    RIFeed();
    for (NSString *name in RIMediaViewClasses()) RIMediaHook(name);
}
__attribute__((constructor)) static void RIStart(void) {
    @autoreleasepool {
        NSString *executable=NSBundle.mainBundle.infoDictionary[@"CFBundleExecutable"];
        // Bundle IDs can change during sideload signing; the executable stays Instagram.
        if (![executable isEqualToString:@"Instagram"]) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            RILog(@"RiseInsta 1.1.0 loaded; no Substrate dependency");
            RIInstallMenu(); RIInstallHooks();
            for (NSNumber *seconds in @[@1,@3,@10]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ RIInstallHooks(); });
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ RIInstallHooks(); }];
        });
    }
}
