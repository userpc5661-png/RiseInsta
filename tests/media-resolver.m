#import "../RIMediaResolver.h"
#include <assert.h>

@interface PhotoFixture : NSObject
@property(nonatomic) double requestedWidth;
- (NSURL *)imageURLForWidth:(double)width;
@end
@implementation PhotoFixture
- (NSURL *)imageURLForWidth:(double)width { self.requestedWidth=width; return [NSURL URLWithString:@"https://example.invalid/photo.jpg"]; }
@end
@interface IvarFixture : NSObject {
    id _media;
    id _currentPlaybackMedia;
    NSInteger _scalar;
}
- (instancetype)initWithMedia:(id)media;
@end
@implementation IvarFixture
- (instancetype)initWithMedia:(id)media {
    if ((self=[super init])) { _media=media; _currentPlaybackMedia=media; _scalar=9; } return self;
}
@end
@interface WrongPhotoFixture : NSObject
- (NSURL *)imageURLForWidth:(NSInteger)width;
@end
@implementation WrongPhotoFixture
- (NSURL *)imageURLForWidth:(NSInteger)width { abort(); }
@end

int main(void) {
    @autoreleasepool {
        PhotoFixture *photo=[PhotoFixture new];
        NSDictionary *resolved=RIResolveReferenceMedia(@{@"photo":photo},NO);
        assert([resolved[@"items"][0][@"kind"] isEqual:@"image"]);
        assert(photo.requestedWidth==9999.0);
        NSDictionary *video=@{@"video":@{@"allVideoURLs":[NSSet setWithObjects:@"https://example.invalid/video.mp4",nil]}};
        resolved=RIResolveReferenceMedia(video,NO);
        assert([resolved[@"items"][0][@"kind"] isEqual:@"video"]);
        resolved=RIResolveReferenceMedia(@{@"video":@{@"videoURLForCurrentNetworkConditions":@"https://example.invalid/network.mp4"}},NO);
        assert([resolved[@"items"][0][@"url"] isKindOfClass:NSURL.class]);
        IvarFixture *fixture=[[IvarFixture alloc] initWithMedia:video];
        assert(RIReferenceField(fixture,@"media")==video);
        assert(RIReferenceField(fixture,@"currentPlaybackMedia")==video);
        assert(RIReferenceField(fixture,@"_scalar")==nil);
        assert(RIReferenceField(fixture,@"missing")==nil);
        assert(RIResolveReferenceMedia(@{@"photo":[WrongPhotoFixture new]},NO)==nil);
        assert(RIResolveReferenceMedia(@{@"video":@{@"allVideoURLs":@[@"file:///etc/passwd",@"relative.mp4"]}},NO)==nil);
        NSDictionary *variants=@{@"imageVersions2":@{@"candidates":@[
            @{@"urlString":@"https://example.invalid/small.jpg",@"width":@10,@"height":@10},
            @{@"urlString":@"https://example.invalid/large.jpg",@"width":@100,@"height":@100}
        ]}};
        resolved=RIResolveReferenceMedia(variants,NO);
        assert([resolved[@"items"][0][@"url"] isEqual:[NSURL URLWithString:@"https://example.invalid/large.jpg"]]);
        resolved=RIResolveReferenceMedia(@{@"carouselMedia":@[@{},video,variants]},NO);
        assert([resolved[@"items"] count]==2);
        assert([resolved[@"items"][0][@"index"] unsignedIntegerValue]==1);
        assert([resolved[@"items"][1][@"index"] unsignedIntegerValue]==2);
        assert(RIResolveReferenceMedia(@{@"profilePicURL":@"https://example.invalid/avatar.jpg"},NO)==nil);
        assert(RIResolveReferenceMedia(@{@"profilePicURL":@"https://example.invalid/avatar.jpg"},YES)!=nil);
        assert(RIResolveReferenceMedia(NSNull.null,NO)==nil);
        puts("PASS: Beegram photo/video APIs, ABI rejection, named ivars, URL validation, quality and carousel indexing");
    } return 0;
}
