// Evidence: Beegram.dylib SHA256 dab378798f0ea2491d13dbbe512cf6543d4bb23e1386b6d36a8f6d252357b843.
// Measured class/selector pairs from reference hook initializers, not target-app verification.
// Version-dependent names live here. No offsets or guessed addresses.
#import <Foundation/Foundation.h>
static inline NSArray<NSDictionary *> *RIGhostTargets(void) {
    return @[
        @{@"class":@"IGDirectThreadViewListAdapterDataSource",@"sel":@"shouldUpdateLastSeenMessage",@"shape":@"bool0",@"pref":@"ghost_seen"},
        @{@"class":@"IGDirectItemSeenMutationBuilder",@"sel":@"builderWithData:metadata:",@"shape":@"object2",@"meta":@YES,@"pref":@"ghost_seen"},
        @{@"class":@"IGStoryViewerItemSeenReporter",@"sel":@"reportSeenItem:sectionController:",@"shape":@"void2",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerViewController",@"sel":@"fullscreenSectionController:didMarkItemAsSeen:",@"shape":@"void2",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"_TtC28IGStoryViewerItemSeenHandler28IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"IGStoryViewerItemSeenHandler.IGStoryViewerItemSeenHandler",@"sel":@"handleItem:sectionController:focusedModelItem:",@"shape":@"void3",@"pref":@"ghost_story"},
        @{@"class":@"IGDirectTypingStatusService",@"sel":@"updateOutgoingStatusIsActive:threadKey:threadMetadata:typingStatusType:",@"shape":@"typing4",@"pref":@"ghost_typing"},
        @{@"class":@"IGStoryAdsResponseParser",@"sel":@"parsedObjectFromResponse:",@"shape":@"object1",@"pref":@"hide_feed_ads"},
        @{@"class":@"IGSundialAdsResponseParser",@"sel":@"parsedObjectFromResponse:",@"shape":@"object1",@"pref":@"hide_feed_ads"}
    ];
}
static inline NSArray<NSString *> *RIMediaViewClasses(void) {
    return @[@"IGUFIButtonBarView",@"IGFeedPhotoView",@"IGVideoPlayerOverlayContainerView",@"IGSundialViewerVideoCell",@"IGSundialViewerPhotoCell",@"IGSundialViewerCarouselCell",@"IGStoryPhotoView",@"IGProfilePictureImageView",@"IGSundialViewerVerticalUFI",@"IGSundialViewerVerticalUFI.IGSundialViewerVerticalUFI",@"IGStoryFullscreenOverlayView"];
}
static inline NSArray<NSString *> *RIModelGetters(void) {
    return @[@"currentPlaybackMedia",@"media",@"currentStoryItem",@"item",@"model",@"viewModel",@"delegate",@"user"];
}
static inline NSDictionary<NSString *,NSString *> *RIReferenceIvars(void) {
    return @{@"media":@"_media",@"currentPlaybackMedia":@"_currentPlaybackMedia",@"url":@"_url",@"user":@"_user",@"delegate":@"_delegate"};
}
static inline NSArray<NSString *> *RIReferenceURLGetters(void) { return @[@"url",@"urlString",@"playbackURL"]; }
#define RI_REFERENCE_VIDEO @"video"
#define RI_REFERENCE_PHOTO @"photo"
#define RI_REFERENCE_ALL_VIDEO_URLS @"allVideoURLs"
#define RI_REFERENCE_NETWORK_VIDEO_URL @"videoURLForCurrentNetworkConditions"
#define RI_REFERENCE_IMAGE_FOR_WIDTH @"imageURLForWidth:"
#define RI_REFERENCE_IMAGE_WIDTH 9999.0
#define RI_FEED_CLASS @"IGMainFeedListAdapterDataSource"
#define RI_FEED_SELECTOR @"objectsForListAdapter:"
#define RI_AD_CLASS @"IGAdItem"
#define RI_IMAGE_VERSIONS @"imageVersions2"
#define RI_VIDEO_VERSIONS @"videoVersions"
#define RI_CAROUSEL @"carouselMedia"
#define RI_AVATAR @"profilePicURL"
#define RI_STORY_SECTION @"IGStoryFullscreenSectionController"
#define RI_STORY_UPDATE @"didUpdateToObject:"
