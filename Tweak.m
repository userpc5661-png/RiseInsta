#import "RICommon.h"
#import "RITargets.h"
#import "RIRuntime.h"

static NSMutableDictionary<NSString *,NSString *> *RIStatuses(void) {
    static NSMutableDictionary *d; static dispatch_once_t once; dispatch_once(&once,^{ d=[NSMutableDictionary dictionary]; }); return d;
}
static NSMutableDictionary *RICounters(void) {
    static NSMutableDictionary *d; static dispatch_once_t once; dispatch_once(&once,^{ d=[NSMutableDictionary dictionary]; }); return d;
}
static NSMutableDictionary *RIEncodings(void) {
    static NSMutableDictionary *d; static dispatch_once_t once; dispatch_once(&once,^{ d=[NSMutableDictionary dictionary]; }); return d;
}
NSDictionary *RIHookStatus(void) {
    @synchronized(RIStatuses()) {
        NSMutableDictionary *report=[NSMutableDictionary dictionary];
        for (NSString *key in RIStatuses()) report[key]=@{@"state":RIStatuses()[key],@"encoding":RIEncodings()[key] ?: @"unavailable",@"activity":RICounters()[key] ?: @{@"calls":@0,@"blocked":@0}};
        return report;
    }
}
static void RIHit(NSString *key,BOOL blocked) {
    @synchronized(RIStatuses()) {
        NSDictionary *last=RICounters()[key];
        RICounters()[key]=@{@"calls":@([last[@"calls"] unsignedLongLongValue]+1),@"blocked":@([last[@"blocked"] unsignedLongLongValue]+(blocked ? 1 : 0))};
    }
}
static Method RICheck(NSString *key,Class cls,SEL sel,NSString *ret,NSArray *args) {
    Method actual=class_getInstanceMethod(cls,sel);
    if (actual) {
        @synchronized(RIStatuses()) { RIEncodings()[key]=[NSString stringWithUTF8String:method_getTypeEncoding(actual)]; }
    }
    return RICompatibleMethod(cls,sel,ret,args);
}
static void RIStatus(NSString *key,NSString *status) {
    @synchronized(RIStatuses()) {
        if ([RIStatuses()[key] isEqualToString:status]) return;
        RIStatuses()[key]=status;
    } RILog(@"%@: %@",key,status);
}
static BOOL RIAlready(NSString *key) { @synchronized(RIStatuses()) { return [RIStatuses()[key] hasPrefix:@"installed"]; } }
static void RIReplace(Class cls,SEL sel,Method method,IMP replacement,NSString *key) {
    static NSMutableDictionary *owners; static dispatch_once_t once;
    dispatch_once(&once,^{ owners=[NSMutableDictionary dictionary]; });
    NSString *identity=[NSString stringWithFormat:@"%p/%s",cls,sel_getName(sel)];
    if (owners[identity]) {
        imp_removeBlock(replacement);
        RIStatus(key,[@"installed alias of " stringByAppendingString:owners[identity]]); return;
    }
    RIOverrideMethod(cls,sel,method,replacement);
    owners[identity]=key;
    RIStatus(key,@"installed");
}
static void RIGhost(NSDictionary *target) {
    NSString *name=target[@"class"], *selector=target[@"sel"], *shape=target[@"shape"], *pref=target[@"pref"];
    BOOL meta=[target[@"meta"] boolValue];
    NSString *key=[NSString stringWithFormat:@"%@%@/%@",meta ? @"+" : @"-",name,selector];
    if (RIAlready(key)) return;
    Class cls=objc_getClass(name.UTF8String) ?: NSClassFromString(name); SEL sel=NSSelectorFromString(selector);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    if (meta) cls=object_getClass(cls);
    NSString *ret=[shape isEqualToString:@"bool0"] ? @"Bc" : ([shape hasPrefix:@"object"] ? @"@" : @"v");
    NSArray *args=@[];
    if ([shape isEqualToString:@"void2"] || [shape isEqualToString:@"object2"]) args=@[@"@",@"@"];
    else if ([shape isEqualToString:@"object1"]) args=@[@"@"];
    else if ([shape isEqualToString:@"void3"]) args=@[@"@",@"@",@"@"];
    else if ([shape isEqualToString:@"typing4"]) args=@[@"Bc",@"@",@"@",@"iIqQ"];
    Method method=RICheck(key,cls,sel,ret,args);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method), replacement=NULL;
    if ([shape isEqualToString:@"bool0"]) replacement=imp_implementationWithBlock(^BOOL(id object){
        BOOL block=RIPref(pref,NO); RIHit(key,block);
        return block ? NO : ((BOOL (*)(id,SEL))original)(object,sel);
    });
    else if ([shape isEqualToString:@"object1"]) replacement=imp_implementationWithBlock(^id(id object,id a){
        BOOL block=RIPref(pref,NO); RIHit(key,block);
        return block ? nil : ((id (*)(id,SEL,id))original)(object,sel,a);
    });
    else if ([shape isEqualToString:@"object2"]) replacement=imp_implementationWithBlock(^id(id object,id a,id b){
        BOOL block=RIPref(pref,NO); RIHit(key,block);
        return block ? nil : ((id (*)(id,SEL,id,id))original)(object,sel,a,b);
    });
    else if ([shape isEqualToString:@"void2"]) replacement=imp_implementationWithBlock(^(id object,id a,id b){
        BOOL block=RIPref(pref,NO); RIHit(key,block);
        if (!block) ((void (*)(id,SEL,id,id))original)(object,sel,a,b);
    });
    else if ([shape isEqualToString:@"void3"]) replacement=imp_implementationWithBlock(^(id object,id a,id b,id c){
        BOOL block=RIPref(pref,NO); RIHit(key,block);
        if (!block) ((void (*)(id,SEL,id,id,id))original)(object,sel,a,b,c);
    });
    else if ([shape isEqualToString:@"typing4"]) {
        char *type=method_copyArgumentType(method,5), *unqualified=type;
        while (*unqualified && strchr("rnNoORV",*unqualified)) unqualified++;
        BOOL wide=strchr("qQ",*unqualified)!=NULL; free(type);
        if (wide) replacement=imp_implementationWithBlock(^(id object,BOOL active,id a,id b,NSInteger value){
            BOOL block=RIPref(pref,NO); RIHit(key,block);
            if (!block) ((void (*)(id,SEL,BOOL,id,id,NSInteger))original)(object,sel,active,a,b,value);
        });
        else replacement=imp_implementationWithBlock(^(id object,BOOL active,id a,id b,int value){
            BOOL block=RIPref(pref,NO); RIHit(key,block);
            if (!block) ((void (*)(id,SEL,BOOL,id,id,int))original)(object,sel,active,a,b,value);
        });
    }
    if (replacement) RIReplace(cls,sel,method,replacement,key);
}
static BOOL RIIsAd(id object) {
    Class adClass=NSClassFromString(RI_AD_CLASS); return adClass && [object isKindOfClass:adClass];
}
static void RIFeed(void) {
    NSString *key=[RI_FEED_CLASS stringByAppendingFormat:@"/%@",RI_FEED_SELECTOR];
    if (RIAlready(key)) return;
    Class cls=NSClassFromString(RI_FEED_CLASS); SEL sel=NSSelectorFromString(RI_FEED_SELECTOR);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    Method method=RICheck(key,cls,sel,@"@",@[@"@"]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^id(id object,id adapter){
        id result=((id (*)(id,SEL,id))original)(object,sel,adapter);
        if (!RIPref(RI_HIDE_FEED_ADS,NO) || ![result isKindOfClass:NSArray.class]) { RIHit(key,NO); return result; }
        NSMutableArray *filtered=[NSMutableArray arrayWithCapacity:[result count]];
        for (id item in result) if (!RIIsAd(item)) [filtered addObject:item];
        RIHit(key,filtered.count!=[result count]);
        return [filtered copy];
    }); RIReplace(cls,sel,method,replacement,key);
}
static void RIMediaHook(NSString *name) {
    SEL sel=@selector(layoutSubviews);
    NSString *key=[name stringByAppendingFormat:@"/%@",NSStringFromSelector(sel)];
    if (RIAlready(key)) return;
    Class cls=NSClassFromString(name);
    if (!cls) { RIStatus(key,@"class missing"); return; }
    if (![cls isSubclassOfClass:UIView.class]) { RIStatus(key,@"not a UIView"); return; }
    Method method=RICheck(key,cls,sel,@"v",@[]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^(UIView *view){
        ((void (*)(id,SEL))original)(view,sel);
        RIHit(key,NO);
        if (view.window) {
            NSString *className=NSStringFromClass(view.class);
            if ([className isEqualToString:@"IGNavigationBar"] || [className containsString:@"IGBadgedNavigationButton"]) RIAttachContextMenuButton(view);
            else RIAttachMediaMenu(view);
        }
    }); RIReplace(cls,sel,method,replacement,key);
}
static void RIStoryCapture(void) {
    NSString *key=[RI_STORY_SECTION stringByAppendingFormat:@"/%@",RI_STORY_UPDATE];
    if (RIAlready(key)) return;
    Class cls=objc_getClass(RI_STORY_SECTION.UTF8String); SEL sel=NSSelectorFromString(RI_STORY_UPDATE);
    Method method=RICheck(key,cls,sel,@"v",@[@"@"]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    RIReplace(cls,sel,method,imp_implementationWithBlock(^(id object,id item){
        ((void (*)(id,SEL,id))original)(object,sel,item); RIHit(key,NO); RITrackStoryController(object);
    }),key);
}
static void RITestFlightReceiptHook(void) {
    NSString *key=@"NSBundle/appStoreReceiptURL";
    if (RIAlready(key)) return;
    Class cls=NSBundle.class; SEL sel=@selector(appStoreReceiptURL);
    Method method=RICheck(key,cls,sel,@"@",@[]);
    if (!method) { RIStatus(key,@"method missing or ABI mismatch"); return; }
    IMP original=method_getImplementation(method);
    IMP replacement=imp_implementationWithBlock(^NSURL *(NSBundle *bundle){
        NSURL *url=((NSURL *(*)(id,SEL))original)(bundle,sel);
        BOOL hide=bundle==NSBundle.mainBundle && [url.lastPathComponent isEqualToString:@"sandboxReceipt"];
        RIHit(key,hide);
        return hide ? [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"receipt"] : url;
    });
    RIReplace(cls,sel,method,replacement,key);
}
void RIInstallHooks(void) {
    NSCAssert(NSThread.isMainThread,@"Hook installation must be serialized");
    for (NSDictionary *target in RIGhostTargets()) RIGhost(target);
    RIFeed(); RIStoryCapture(); RITestFlightReceiptHook();
    for (NSString *name in RIMediaViewClasses()) RIMediaHook(name);
}
__attribute__((constructor)) static void RIStart(void) {
    @autoreleasepool {
        NSString *executable=NSBundle.mainBundle.infoDictionary[@"CFBundleExecutable"];
        // Bundle IDs can change during sideload signing; the executable stays Instagram.
        if (![executable isEqualToString:@"Instagram"]) return;
        // Install before Instagram's startup path asks the receipt for beta status.
        RITestFlightReceiptHook();
        dispatch_async(dispatch_get_main_queue(), ^{
            RILog(@"RiseInsta 1.2.9 beta loaded; profile menu and native screen recorder active");
            RIInstallMenu(); RIInstallHooks();
            for (NSNumber *seconds in @[@1,@3,@10]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(seconds.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ RIInstallMenu(); RIInstallHooks(); });
            // Some Instagram view classes are lazy-loaded after opening Reels,
            // Stories or the profile. Re-check periodically while foreground.
            [NSTimer scheduledTimerWithTimeInterval:8.0 repeats:YES block:^(NSTimer *timer) {
                if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) return;
                RIInstallMenu();
                RIInstallHooks();
            }];
            [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ RIInstallMenu(); RIInstallHooks(); }];
        });
    }
}
