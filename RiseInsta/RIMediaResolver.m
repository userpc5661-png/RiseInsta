// APIs and ivar names measured in Beegram's media download paths.
// See evidence/reference-paths.md for addresses in the supplied reference.
#import "RIMediaResolver.h"
#import "RIRuntime.h"
#import "RITargets.h"
#import <objc/message.h>

id RIReferenceField(id object, NSString *name) {
    if (!object || object==NSNull.null) return nil;
    if ([object isKindOfClass:NSDictionary.class]) {
        id value=[object objectForKey:name]; return value==NSNull.null ? nil : value;
    }
    SEL selector=NSSelectorFromString(name);
    Method method=RICompatibleMethod(object_getClass(object),selector,@"@",@[]);
    @try {
        if (method) return ((id (*)(id,SEL))objc_msgSend)(object,selector);
        // Only object-typed ivars, looked up by measured names, never numeric offsets.
        NSString *ivarName=RIReferenceIvars()[name] ?: ([name hasPrefix:@"_"] ? name : nil);
        if (!ivarName) return nil;
        Ivar ivar=class_getInstanceVariable(object_getClass(object),ivarName.UTF8String);
        const char *type=ivar ? ivar_getTypeEncoding(ivar) : NULL;
        if (type && type[0]=='@') return object_getIvar(object,ivar);
    } @catch (NSException *exception) { return nil; }
    return nil;
}
static NSURL *RIValidURL(id value) {
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    return url.host.length && [@[@"http",@"https"] containsObject:url.scheme.lowercaseString] ? url : nil;
}
static NSURL *RICandidateURL(id object) {
    NSURL *direct=RIValidURL(object); if (direct) return direct;
    for (NSString *key in RIReferenceURLGetters()) {
        NSURL *url=RIValidURL(RIReferenceField(object,key)); if (url) return url;
    } return nil;
}
static double RINumeric(id object,NSString *name) {
    id boxed=RIReferenceField(object,name);
    if ([boxed respondsToSelector:@selector(doubleValue)]) return [boxed doubleValue];
    SEL selector=NSSelectorFromString(name);
    Method method=class_getInstanceMethod(object_getClass(object),selector);
    if (!method || method_getNumberOfArguments(method)!=2) return 0;
    char *encoding=method_copyReturnType(method); double value=0;
    switch (encoding[0]) {
        case 'q': value=((long long (*)(id,SEL))objc_msgSend)(object,selector); break;
        case 'Q': value=((unsigned long long (*)(id,SEL))objc_msgSend)(object,selector); break;
        case 'i': value=((int (*)(id,SEL))objc_msgSend)(object,selector); break;
        case 'I': value=((unsigned (*)(id,SEL))objc_msgSend)(object,selector); break;
        case 'f': value=((float (*)(id,SEL))objc_msgSend)(object,selector); break;
        case 'd': value=((double (*)(id,SEL))objc_msgSend)(object,selector); break;
        default: break;
    } free(encoding); return value;
}
static NSURL *RIBestURL(id collection) {
    if ([collection isKindOfClass:NSSet.class]) collection=[collection allObjects];
    if (![collection isKindOfClass:NSArray.class]) return RICandidateURL(collection);
    NSURL *best=nil; double area=-1;
    for (id candidate in collection) {
        NSURL *url=RICandidateURL(candidate); if (!url) continue;
        double next=RINumeric(candidate,@"width")*RINumeric(candidate,@"height");
        if (!best || next>area || (next==area && [url.absoluteString compare:best.absoluteString]==NSOrderedAscending)) { best=url; area=next; }
    } return best;
}
static NSDictionary *RIItem(id object) {
    id video=RIReferenceField(object,RI_REFERENCE_VIDEO);
    NSURL *url=RIBestURL(RIReferenceField(video,RI_REFERENCE_ALL_VIDEO_URLS));
    if (!url) url=RICandidateURL(RIReferenceField(video,RI_REFERENCE_NETWORK_VIDEO_URL));
    if (!url) url=RICandidateURL(video);
    if (!url) url=RIBestURL(RIReferenceField(object,RI_VIDEO_VERSIONS));
    if (url) return @{@"url":url,@"kind":@"video"};
    id photo=RIReferenceField(object,RI_REFERENCE_PHOTO);
    SEL imageSelector=NSSelectorFromString(RI_REFERENCE_IMAGE_FOR_WIDTH);
    if (RICompatibleMethod(object_getClass(photo),imageSelector,@"@",@[@"d"])) {
        url=RICandidateURL(((id (*)(id,SEL,double))objc_msgSend)(photo,imageSelector,RI_REFERENCE_IMAGE_WIDTH));
    }
    if (!url) {
        id images=RIReferenceField(object,RI_IMAGE_VERSIONS);
        url=RIBestURL(RIReferenceField(images,@"candidates") ?: images);
    }
    if (!url) url=RIBestURL(RIReferenceField(photo,@"_originalImageVersions"));
    if (url) return @{@"url":url,@"kind":@"image"};
    return nil;
}
NSDictionary *RIResolveReferenceMedia(id object,BOOL allowAvatar) {
    id carousel=RIReferenceField(object,RI_CAROUSEL);
    NSMutableArray *items=[NSMutableArray array];
    if ([carousel isKindOfClass:NSArray.class] && [carousel count]) {
        NSUInteger index=0;
        for (id child in carousel) {
            NSDictionary *item=RIItem(child);
            if (item) { NSMutableDictionary *entry=[item mutableCopy]; entry[@"index"]=@(index); [items addObject:entry]; }
            index++;
        }
    } else { NSDictionary *item=RIItem(object); if (item) [items addObject:item]; }
    if (!items.count && allowAvatar) {
        NSURL *avatar=RIValidURL(RIReferenceField(object,RI_AVATAR));
        if (avatar) [items addObject:@{@"url":avatar,@"kind":@"image"}];
    }
    return items.count ? @{@"object":object,@"items":items} : nil;
}
