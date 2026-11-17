#import "../RIRuntime.h"
#include <assert.h>
@interface Parent : NSObject
- (BOOL)enabled;
- (id)echo:(id)value;
- (void)typing:(BOOL)active thread:(id)thread metadata:(id)metadata type:(NSInteger)type;
@end
@implementation Parent
- (BOOL)enabled { return YES; }
- (id)echo:(id)value { return value; }
- (void)typing:(BOOL)active thread:(id)thread metadata:(id)metadata type:(NSInteger)type {}
@end
@interface Child : Parent @end
@implementation Child @end
int main(void) {
    @autoreleasepool {
        assert(RICompatibleMethod(Child.class,@selector(enabled),@"Bc",@[]));
        assert(!RICompatibleMethod(Child.class,@selector(enabled),@"v",@[]));
        assert(!RICompatibleMethod(Child.class,NSSelectorFromString(@"missing"),@"@",@[]));
        assert(!RICompatibleMethod(Child.class,@selector(echo:),@"@",@[@"q"]));
        assert(RICompatibleMethod(Child.class,@selector(typing:thread:metadata:type:),@"v",@[@"Bc",@"@",@"@",@"qQ"]));
        assert(!RICompatibleMethod(Child.class,@selector(typing:thread:metadata:type:),@"v",@[@"Bc",@"@",@"@"]));
        SEL selector=@selector(enabled);
        Method method=RICompatibleMethod(Child.class,selector,@"Bc",@[]);
        IMP original=method_getImplementation(method);
        __block BOOL gate=YES;
        IMP replacement=imp_implementationWithBlock(^BOOL(id object) { return gate ? NO : ((BOOL (*)(id,SEL))original)(object,selector); });
        RIOverrideMethod(Child.class,selector,method,replacement);
        assert(![[Child new] enabled]);
        assert([[Parent new] enabled]);
        gate=NO; assert([[Child new] enabled]);
        SEL echo=@selector(echo:); Method em=RICompatibleMethod(Child.class,echo,@"@",@[@"@"]);
        IMP eo=method_getImplementation(em);
        RIOverrideMethod(Child.class,echo,em,imp_implementationWithBlock(^id(id obj,id value){ return ((id (*)(id,SEL,id))eo)(obj,echo,value); }));
        assert([[[Child new] echo:@"forwarded"] isEqual:@"forwarded"]);
        puts("PASS: ABI rejection, inherited isolation, pref gate and original forwarding");
    } return 0;
}
