#import <Foundation/Foundation.h>
#import <objc/runtime.h>
FOUNDATION_EXPORT Method RICompatibleMethod(Class cls,SEL selector,NSString *returnCodes,NSArray<NSString *> *argumentCodes);
FOUNDATION_EXPORT void RIOverrideMethod(Class cls,SEL selector,Method method,IMP replacement);
