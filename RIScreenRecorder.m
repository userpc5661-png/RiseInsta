#import "RIScreenRecorder.h"
#import <ReplayKit/ReplayKit.h>
#import "RICommon.h"

@interface RIScreenPreviewDelegate : NSObject <RPPreviewViewControllerDelegate>
+ (instancetype)shared;
@end

@implementation RIScreenPreviewDelegate
+ (instancetype)shared {
    static RIScreenPreviewDelegate *delegate; static dispatch_once_t once;
    dispatch_once(&once,^{ delegate=[self new]; }); return delegate;
}
- (void)previewControllerDidFinish:(RPPreviewViewController *)previewController {
    [previewController dismissViewControllerAnimated:YES completion:nil];
}
@end

BOOL RIScreenRecorderIsRecording(void) { return RPScreenRecorder.sharedRecorder.isRecording; }

void RIScreenRecorderStart(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(),^{
        RPScreenRecorder *recorder=RPScreenRecorder.sharedRecorder;
        if (!recorder.available) { RIAlert(@"تسجيل الشاشة",@"تسجيل الشاشة غير متاح في هذه اللحظة.",host); return; }
        if (recorder.isRecording) { RIAlert(@"تسجيل الشاشة",@"التسجيل يعمل بالفعل. أوقفه من القائمة عند الانتهاء.",host); return; }
        [recorder startRecordingWithMicrophoneEnabled:NO handler:^(NSError *error){
            if (error) RIAlert(@"تعذر بدء التسجيل",error.localizedDescription ?: @"أعاد النظام خطأ غير محدد.",host);
            else RILog(@"ReplayKit screen capture started");
        }];
    });
}

void RIScreenRecorderStop(UIViewController *host) {
    dispatch_async(dispatch_get_main_queue(),^{
        RPScreenRecorder *recorder=RPScreenRecorder.sharedRecorder;
        if (!recorder.isRecording) { RIAlert(@"تسجيل الشاشة",@"لا يوجد تسجيل جارٍ.",host); return; }
        [recorder stopRecordingWithHandler:^(RPPreviewViewController *preview,NSError *error){
            dispatch_async(dispatch_get_main_queue(),^{
                if (error) { RIAlert(@"تعذر إنهاء التسجيل",error.localizedDescription ?: @"أعاد النظام خطأ غير محدد.",host); return; }
                if (!preview) { RIAlert(@"تسجيل الشاشة",@"انتهى التسجيل لكن لم يوفر النظام شاشة معاينة.",host); return; }
                UIViewController *top=RITopController(host);
                if (!top || [top isKindOfClass:UIAlertController.class]) { RILog(@"ReplayKit preview unavailable: no presentation host"); return; }
                preview.previewControllerDelegate=[RIScreenPreviewDelegate shared];
                [top presentViewController:preview animated:YES completion:nil];
            });
        }];
    });
}
