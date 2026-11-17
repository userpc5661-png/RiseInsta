// Tweak.x — RiseInsta: clean Instagram enhancement tweak.
// Features: Ghost mode (hide read receipts, typing, story-seen), ad removal,
// media download. Every hook is prefs-gated and guarded with
// respondsToSelector because Instagram renames private symbols between builds.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>
#import "Prefs.h"

#pragma mark - Ghost: read receipts

// Instagram marks a DM thread read by building a "seen" mutation. Suppress it.
%hook IGDirectItemSeenMutationBuilder
- (id)buildMutation {
    if (RIPref(RI_GHOST_SEEN, NO)) return nil;
    return %orig;
}
%end

%hook IGDirectThreadLastSeenMessageTracker
- (void)markThreadSeen {
    if (RIPref(RI_GHOST_SEEN, NO)) return;
    %orig;
}
- (void)updateLastSeenMarkerForThread:(id)thread {
    if (RIPref(RI_GHOST_SEEN, NO)) return;
    %orig;
}
%end

#pragma mark - Ghost: typing indicator

%hook IGDirectTypingStatusService
- (void)sendTypingStatus:(NSInteger)status toThread:(id)thread {
    if (RIPref(RI_GHOST_TYPING, NO)) return;
    %orig;
}
- (void)startTypingInThread:(id)thread {
    if (RIPref(RI_GHOST_TYPING, NO)) return;
    %orig;
}
- (void)sendTypingIndicator:(id)indicator {
    if (RIPref(RI_GHOST_TYPING, NO)) return;
    %orig;
}
%end

#pragma mark - Ghost: story seen

%hook IGDirectVisualMessageViewerController
- (void)markAsSeen {
    if (RIPref(RI_GHOST_STORY, NO)) return;
    %orig;
}
%end

#pragma mark - Ad removal (feed / story / reels sponsored items)

static BOOL RIItemIsAd(id item) {
    if (!item) return NO;
    SEL adSels[] = { @selector(isSponsored), @selector(isAd),
                     @selector(isPaidPartnership), @selector(isAdItem) };
    for (unsigned i = 0; i < sizeof(adSels)/sizeof(adSels[0]); i++) {
        if ([item respondsToSelector:adSels[i]]) {
            if (((BOOL (*)(id, SEL))objc_msgSend)(item, adSels[i])) return YES;
        }
    }
    return NO;
}

%hook IGMainFeedListAdapterDataSource
- (NSArray *)objectsForListAdapter:(id)adapter {
    NSArray *objects = %orig;
    if (!RIPref(RI_HIDE_FEED_ADS, NO) || ![objects isKindOfClass:[NSArray class]]) return objects;
    NSMutableArray *clean = [NSMutableArray arrayWithCapacity:objects.count];
    for (id obj in objects) {
        if (!RIItemIsAd(obj)) [clean addObject:obj];
    }
    return clean;
}
%end

#pragma mark - Download

@interface RIDownloader : NSObject
+ (void)saveURL:(NSURL *)url isVideo:(BOOL)isVideo from:(UIViewController *)host;
@end

@implementation RIDownloader
+ (void)saveURL:(NSURL *)url isVideo:(BOOL)isVideo from:(UIViewController *)host {
    if (!url) return;
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error || !location) { [self toast:@"RiseInsta: فشل التحميل" on:host]; return; }
            NSString *ext = isVideo ? @"mp4" : @"jpg";
            NSString *dest = [NSTemporaryDirectory() stringByAppendingPathComponent:
                              [NSString stringWithFormat:@"RI_%@.%@", [[NSUUID UUID] UUIDString], ext]];
            [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:dest error:nil];
            if (RIPref(RI_SAVE_TO_PHOTOS, YES)) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    NSURL *fileURL = [NSURL fileURLWithPath:dest];
                    if (isVideo) [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
                    else [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
                } completionHandler:^(BOOL success, NSError *e) {
                    [self toast:success ? @"RiseInsta: تم الحفظ في الصور" : @"RiseInsta: فشل الحفظ" on:host];
                }];
            } else {
                [self shareFile:dest from:host];
            }
        }];
    [task resume];
}

+ (void)shareFile:(NSString *)path from:(UIViewController *)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIActivityViewController *av = [[UIActivityViewController alloc]
            initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
        [host presentViewController:av animated:YES completion:nil];
    });
}

+ (void)toast:(NSString *)msg on:(UIViewController *)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = host ?: [UIApplication sharedApplication].keyWindow.rootViewController;
        UIAlertController *a = [UIAlertController alertControllerWithTitle:nil message:msg
            preferredStyle:UIAlertControllerStyleAlert];
        [top presentViewController:a animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [a dismissViewControllerAnimated:YES completion:nil]; });
        }];
    });
}
@end

// Pull a playable/downloadable URL out of an IGMedia object.
static NSURL *RIMediaURL(id media, BOOL *isVideoOut) {
    if (!media) return nil;
    if ([media respondsToSelector:@selector(videoVersions)]) {
        NSArray *vv = ((NSArray *(*)(id, SEL))objc_msgSend)(media, @selector(videoVersions));
        if ([vv isKindOfClass:[NSArray class]] && vv.count) {
            id best = vv.firstObject;
            for (SEL s = @selector(url); [best respondsToSelector:s];) {
                NSString *u = ((NSString *(*)(id, SEL))objc_msgSend)(best, s);
                if (u) { if (isVideoOut) *isVideoOut = YES; return [NSURL URLWithString:u]; }
                break;
            }
        }
    }
    if ([media respondsToSelector:@selector(imageVersions)]) {
        id iv = ((id (*)(id, SEL))objc_msgSend)(media, @selector(imageVersions));
        if ([iv respondsToSelector:@selector(candidates)]) {
            NSArray *c = ((NSArray *(*)(id, SEL))objc_msgSend)(iv, @selector(candidates));
            if ([c isKindOfClass:[NSArray class]] && c.count) {
                id best = c.firstObject;
                if ([best respondsToSelector:@selector(url)]) {
                    NSString *u = ((NSString *(*)(id, SEL))objc_msgSend)(best, @selector(url));
                    if (u) { if (isVideoOut) *isVideoOut = NO; return [NSURL URLWithString:u]; }
                }
            }
        }
    }
    return nil;
}

// Add a Download action to the media long-press action sheet.
%hook IGActionSheetController
- (void)presentFromViewController:(UIViewController *)vc {
    if (RIPref(RI_DOWNLOAD, YES) && [self respondsToSelector:@selector(addAction:)]) {
        id media = objc_getAssociatedObject(self, "ri_media");
        if (media) {
            Class actionCls = objc_getClass("IGActionSheetControllerAction");
            if (actionCls && [actionCls respondsToSelector:@selector(actionWithTitle:style:handler:)]) {
                id action = ((id (*)(id, SEL, NSString *, NSInteger, void (^)(void)))objc_msgSend)(
                    actionCls, @selector(actionWithTitle:style:handler:),
                    @"تحميل (RiseInsta)", 0, ^{
                        BOOL isVideo = NO;
                        NSURL *u = RIMediaURL(media, &isVideo);
                        [RIDownloader saveURL:u isVideo:isVideo from:vc];
                    });
                if (action) ((void (*)(id, SEL, id))objc_msgSend)(self, @selector(addAction:), action);
            }
        }
    }
    %orig;
}
%end
