#import "RIRuntime.h"
static BOOL RITypeMatches(const char *type,NSString *allowed) {
    while (*type && strchr("rnNoORV",*type)) type++;
    return *type && strchr(allowed.UTF8String,*type)!=NULL;
}
Method RICompatibleMethod(Class cls,SEL selector,NSString *ret,NSArray<NSString *> *args) {
    Method m=class_getInstanceMethod(cls,selector);
    if (!m || method_getNumberOfArguments(m)!=args.count+2) return NULL;
    char *type=method_copyReturnType(m); BOOL valid=RITypeMatches(type,ret); free(type);
    for (NSUInteger i=0; valid && i<args.count; i++) {
        type=method_copyArgumentType(m,(unsigned)i+2); valid=RITypeMatches(type,args[i]); free(type);
    } return valid ? m : NULL;
}
void RIOverrideMethod(Class cls,SEL sel,Method method,IMP replacement) {
    // Never alter a superclass's implementation while hooking an inherited method.
    if (!class_addMethod(cls,sel,replacement,method_getTypeEncoding(method))) method_setImplementation(class_getInstanceMethod(cls,sel),replacement);
}
