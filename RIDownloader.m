#import "RICommon.h"
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation RIDownloader
static NSMutableSet<NSURLSessionTask *> *RITasks;
+ (void)initialize { if (self==RIDownloader.class) RITasks=[NSMutableSet set]; }
+ (NSUInteger)activeCount { @synchronized(RITasks) { return RITasks.count; } }
+ (void)cancelAll {
    NSArray *tasks; @synchronized(RITasks) { tasks=RITasks.allObjects; }
    for (NSURLSessionTask *task in tasks) [task cancel];
}
+ (void)removeFile:(NSURL *)file {
    if (file) [NSFileManager.defaultManager removeItemAtURL:file error:NULL];
}
+ (void)share:(NSURL *)file from:(UIViewController *)host {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top=RITopController(host);
        if (!top || [top isKindOfClass:UIAlertController.class]) {
            [self removeFile:file];
            RILog(@"Share could not open: no available host"); return;
        }
        UIActivityViewController *controller=[[UIActivityViewController alloc] initWithActivityItems:@[file] applicationActivities:nil];
        controller.completionWithItemsHandler=^(UIActivityType type,BOOL done,NSArray *items,NSError *error) {
            [self removeFile:file];
        };
        UIPopoverPresentationController *popover=controller.popoverPresentationController;
        popover.sourceView=top.view;
        popover.sourceRect=CGRectMake(CGRectGetMidX(top.view.bounds),CGRectGetMidY(top.view.bounds),1,1);
        popover.permittedArrowDirections=0;
        [top presentViewController:controller animated:YES completion:nil];
    });
}
+ (void)store:(NSURL *)file kind:(NSString *)kind from:(UIViewController *)host {
    NSString *usage=NSBundle.mainBundle.infoDictionary[@"NSPhotoLibraryAddUsageDescription"];
    if (![usage isKindOfClass:NSString.class] || !usage.length) {
        RILog(@"Photos unavailable: NSPhotoLibraryAddUsageDescription missing; sharing instead");
        [self share:file from:host]; return;
    }
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status!=PHAuthorizationStatusAuthorized && status!=PHAuthorizationStatusLimited) {
            RILog(@"Photos permission denied; sharing instead");
            [self share:file from:host]; return;
        }
        __block BOOL created=NO;
        [PHPhotoLibrary.sharedPhotoLibrary performChanges:^{
            PHAssetChangeRequest *request=[kind isEqualToString:@"video"] ?
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:file] :
                [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:file];
            created=(request!=nil);
        } completionHandler:^(BOOL success,NSError *error) {
            if (success && created) {
                [self removeFile:file];
                RIAlert(@"RiseInsta",@"تم الحفظ في الصور",host);
            } else {
                RILog(@"Photos save failed (%ld); sharing instead",(long)error.code);
                [self share:file from:host];
            }
        }];
    }];
}
+ (void)saveURL:(NSURL *)url kind:(NSString *)kind share:(BOOL)share from:(UIViewController *)host {
    if (![url isKindOfClass:NSURL.class] || ![@[@"https",@"http"] containsObject:url.scheme.lowercaseString] || !url.host.length) {
        RIAlert(@"RiseInsta",@"تعذر استخراج رابط وسائط صالح من هذا العنصر",host); return;
    }
    if (![@[@"image",@"video",@"audio"] containsObject:kind]) return;
    __weak UIViewController *weakHost=host;
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval=90;
    __block __weak NSURLSessionDownloadTask *weakTask;
    NSURLSessionDownloadTask *task=[NSURLSession.sharedSession downloadTaskWithRequest:request completionHandler:^(NSURL *location,NSURLResponse *response,NSError *error) {
        @synchronized(RITasks) { if (weakTask) [RITasks removeObject:weakTask]; }
        if (error.code==NSURLErrorCancelled) { RILog(@"Download cancelled"); return; }
        NSHTTPURLResponse *http=[response isKindOfClass:NSHTTPURLResponse.class] ? (id)response : nil;
        if (error || !location || !http || http.statusCode<200 || http.statusCode>=300) {
            RILog(@"Download failed: HTTP %ld, error %ld",(long)http.statusCode,(long)error.code);
            RIAlert(@"RiseInsta",@"فشل التحميل. جرّب تحديث المنشور ثم أعد المحاولة.",weakHost); return;
        }
        NSString *mime=response.MIMEType.lowercaseString ?: @"";
        BOOL mediaType=[mime hasPrefix:[kind stringByAppendingString:@"/"]];
        BOOL generic=[@[@"application/octet-stream",@"binary/octet-stream",@""] containsObject:mime];
        if (!mediaType && !generic) {
            RILog(@"Unexpected media content type: %@",mime);
            RIAlert(@"RiseInsta",@"الخادم لم يرجع ملف وسائط مناسبًا",weakHost); return;
        }
        NSString *extension=mediaType ? [UTType typeWithMIMEType:mime].preferredFilenameExtension : nil;
        if (!extension.length) extension=[kind isEqualToString:@"video"] ? @"mp4" : ([kind isEqualToString:@"audio"] ? @"m4a" : @"jpg");
        NSURL *directory=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:@"RiseInsta" isDirectory:YES];
        NSError *fileError=nil;
        if (![NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&fileError]) {
            RIAlert(@"RiseInsta",@"تعذر إنشاء مجلد التحميل المؤقت",weakHost); return;
        }
        // Clean only abandoned files owned by this downloader, after one day.
        NSArray *oldFiles=[NSFileManager.defaultManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLContentModificationDateKey] options:0 error:NULL];
        for (NSURL *old in oldFiles) {
            NSDate *date=nil; [old getResourceValue:&date forKey:NSURLContentModificationDateKey error:NULL];
            if (date && [date timeIntervalSinceNow]<-86400) [self removeFile:old];
        }
        NSURL *destination=[directory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",NSUUID.UUID.UUIDString,extension]];
        if (![NSFileManager.defaultManager moveItemAtURL:location toURL:destination error:&fileError]) {
            RILog(@"Move failed: %ld",(long)fileError.code);
            RIAlert(@"RiseInsta",@"تعذر حفظ الملف المؤقت",weakHost); return;
        }
        NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:destination.path error:NULL];
        if ([attributes[NSFileSize] unsignedLongLongValue]==0) {
            [self removeFile:destination]; RIAlert(@"RiseInsta",@"ملف التحميل فارغ",weakHost); return;
        }
        if (share || [kind isEqualToString:@"audio"] || !RIPref(RI_SAVE_TO_PHOTOS,YES)) [self share:destination from:weakHost];
        else [self store:destination kind:kind from:weakHost];
    }];
    weakTask=task;
    @synchronized(RITasks) { [RITasks addObject:task]; }
    RILog(@"Started %@ download",kind);
    [task resume];
}
@end
