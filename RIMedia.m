#import "RICommon.h"
#import "RITargets.h"
static id RIField(id object,NSString *key) {
    return [object isKindOfClass:NSDictionary.class] ? object[key] : RIGet(object,key);
}
static NSURL *RIURL(id value) {
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : ([value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil);
    return url.host.length && [@[@"https",@"http"] containsObject:url.scheme.lowercaseString] ? url : nil;
}
static NSURL *RICandidateURL(id value) { return RIURL(value) ?: RIURL(RIField(value,@"url")) ?: RIURL(RIField(value,@"URL")); }
static NSURL *RIBestURL(id versions) {
    if (![versions isKindOfClass:NSArray.class]) return RICandidateURL(versions);
    NSURL *best=nil; double score=-1;
    for (id candidate in versions) {
        NSURL *url=RICandidateURL(candidate); if (!url) continue;
        id w=RIField(candidate,@"width"), h=RIField(candidate,@"height");
        double area=([w respondsToSelector:@selector(doubleValue)] && [h respondsToSelector:@selector(doubleValue)]) ? [w doubleValue]*[h doubleValue] : 0;
        if (!best || area>score) { best=url; score=area; }
    } return best;
}
static NSDictionary *RIResolveItem(id object) {
    NSURL *video=RIBestURL(RIField(object,RI_VIDEO_VERSIONS));
    if (video) return @{@"url":video,@"kind":@"video"};
    id images=RIField(object,RI_IMAGE_VERSIONS);
    NSURL *image=RIBestURL(RIField(images,@"candidates") ?: images);
    if (image) return @{@"url":image,@"kind":@"image"};
    return nil;
}
static NSDictionary *RIFindMedia(UIView *view) {
    NSMutableArray *queue=[NSMutableArray array];
    // Resolve now, never cache the previous media object of a reused cell.
    UIResponder *responder=view;
    for (NSUInteger i=0; responder && i<12; i++,responder=responder.nextResponder) [queue addObject:responder];
    NSHashTable *visited=[NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    for (NSUInteger index=0; index<queue.count && index<96; index++) {
        id object=queue[index]; if ([visited containsObject:object]) continue;
        [visited addObject:object];
        NSMutableArray *items=[NSMutableArray array]; id carousel=RIField(object,RI_CAROUSEL);
        if ([carousel isKindOfClass:NSArray.class] && [carousel count]) {
            for (id child in carousel) { NSDictionary *item=RIResolveItem(child); if (item) [items addObject:item]; }
        } else { NSDictionary *item=RIResolveItem(object); if (item) [items addObject:item]; }
        if (items.count) return @{@"object":object,@"items":items};
        NSURL *avatar=[NSStringFromClass(view.class) containsString:@"ProfilePicture"] ? RIURL(RIField(object,RI_AVATAR)) : nil;
        if (avatar) return @{@"object":object,@"items":@[@{@"url":avatar,@"kind":@"image"}]};
        if (queue.count<96) for (NSString *key in RIModelGetters()) {
            id next=RIField(object,key);
            if (next && next!=object && ![next isKindOfClass:NSString.class] && ![next isKindOfClass:NSNumber.class] && queue.count<96) [queue addObject:next];
        }
    } return nil;
}
@interface RIMediaGesture : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)shared;
@end
@implementation RIMediaGesture
+ (instancetype)shared { static RIMediaGesture *manager; static dispatch_once_t once; dispatch_once(&once,^{ manager=[self new]; }); return manager; }
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture { return RIPref(RI_DOWNLOAD,YES); }
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b { return YES; }
- (void)open:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state!=UIGestureRecognizerStateBegan || !RIPref(RI_DOWNLOAD,YES)) return;
    static NSTimeInterval lastOpen=0; NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
    if (now-lastOpen<1) return; lastOpen=now;
    UIViewController *host=RITopController(nil);
    if (!host || [host isKindOfClass:UIAlertController.class]) return;
    NSDictionary *resolved=RIFindMedia(gesture.view); NSArray<NSDictionary *> *items=resolved[@"items"];
    if (!items.count) {
        RILog(@"No media resolved from %@",NSStringFromClass(gesture.view.class));
        RIAlert(@"RiseInsta",@"تعذر العثور على الوسائط في هذا العرض. انسخ تقرير التشخيص وأرفق رقم إصدار إنستغرام.",host); return;
    }
    UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"RiseInsta" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [items enumerateObjectsUsingBlock:^(NSDictionary *item,NSUInteger index,BOOL *stop){
        NSString *suffix=items.count>1 ? [NSString stringWithFormat:@" — %lu",(unsigned long)index+1] : @"";
        [menu addAction:[UIAlertAction actionWithTitle:[@"تحميل" stringByAppendingString:suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:NO from:host]; }]];
        [menu addAction:[UIAlertAction actionWithTitle:[@"تحميل ومشاركة" stringByAppendingString:suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ [RIDownloader saveURL:item[@"url"] kind:item[@"kind"] share:YES from:host]; }]];
    }];
    id object=resolved[@"object"], caption=RIField(object,@"caption");
    if (![caption isKindOfClass:NSString.class]) caption=RIField(caption,@"text");
    if ([caption isKindOfClass:NSString.class] && [caption length]) [menu addAction:[UIAlertAction actionWithTitle:@"نسخ الوصف" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ UIPasteboard.generalPasteboard.string=caption; }]];
    id username=RIField(RIField(object,@"user") ?: object,@"username");
    if ([username isKindOfClass:NSString.class] && [username length]) [menu addAction:[UIAlertAction actionWithTitle:@"نسخ اسم المستخدم" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){ UIPasteboard.generalPasteboard.string=username; }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover=menu.popoverPresentationController;
    popover.sourceView=gesture.view; CGPoint point=[gesture locationInView:gesture.view]; popover.sourceRect=CGRectMake(point.x,point.y,1,1);
    [host presentViewController:menu animated:YES completion:nil];
}
@end
void RIAttachMediaMenu(UIView *view) {
    static char key; if (objc_getAssociatedObject(view,&key)) return;
    UILongPressGestureRecognizer *gesture=[[UILongPressGestureRecognizer alloc] initWithTarget:RIMediaGesture.shared action:@selector(open:)];
    gesture.numberOfTouchesRequired=2; gesture.minimumPressDuration=0.55; gesture.cancelsTouchesInView=NO; gesture.delegate=RIMediaGesture.shared;
    view.userInteractionEnabled=YES; [view addGestureRecognizer:gesture];
    objc_setAssociatedObject(view,&key,gesture,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
