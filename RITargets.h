// Evidence: Beegram.dylib SHA256 dab378798f0ea2491d13dbbe512cf6543d4bb23e1386b6d36a8f6d252357b843.
// Measured class/selector pairs from reference hook initializers, not target-app verification.
// Version-dependent names live here. No offsets or guessed addresses.
#import <Foundation/Foundation.h>
static inline NSArray<NSDictionary *> *RIGhostTargets(void) {
    return @[
        @{@"class":@"IGDirectThreadViewListAdapterDataSource",@"sel":@"shouldUpdateLastSeenMessage",@"shape":@"bool0",@"pref":@"ghost_seen"},
        @{@"class":@"IGStoryViewerItemSeenReporter",@"sel":@"reportSeenItem:sectionController:",@"shape":@"void2",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerViewController",@"sel":@"fullscreenSectionController:didMarkItemAsSeen:",@"shape":@"void2",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"_TtC28IGStoryViewerItemSeenHandler28IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerItemSeenHandler.IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"IGDirectTypingStatusService",@"sel":@"updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:",@"shape":@"typing4",@"pref":@"ghost_typing"}
    ];
}
static inline NSArray<NSString *> *RIMediaViewClasses(void) {
    return @[@"IGFeedPhotoView",@"IGVideoPlayerOverlayContainerView",@"IGSundialViewerVideoCell",@"IGSundialViewerPhotoCell",@"IGSundialViewerCarouselCell",@"IGStoryPhotoView",@"IGProfilePictureImageView"];
}
static inline NSArray<NSString *> *RIModelGetters(void) {
    return @[@"media",@"item",@"model",@"viewModel",@"currentStoryItem",@"user"];
}
static inline NSArray<NSString *> *RIAdPredicates(void) { return @[@"isSponsored",@"isAd",@"isAdItem"]; }
#define RI_FEED_CLASS @"IGMainFeedListAdapterDataSource"
#define RI_FEED_SELECTOR @"objectsForListAdapter:"
#define RI_AD_CLASS @"IGAdItem"
#define RI_IMAGE_VERSIONS @"imageVersions2"
#define RI_VIDEO_VERSIONS @"videoVersions"
#define RI_CAROUSEL @"carouselMedia"
#define RI_AVATAR @"profilePicURL"
