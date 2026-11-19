#import "RIIcons.h"
#import "RIIconsData.h"

static UIImage *RIEmbeddedIcon(NSString *encoded) {
    NSData *data=[[NSData alloc] initWithBase64EncodedString:encoded options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *image=data ? [UIImage imageWithData:data scale:4.0] : nil;
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

UIImage *RIDownloadIcon(void) {
    static UIImage *image; static dispatch_once_t once;
    dispatch_once(&once,^{ image=RIEmbeddedIcon(RIArchiveDownPNGBase64); });
    return image;
}

UIImage *RIBookmarkMinusIcon(void) {
    static UIImage *image; static dispatch_once_t once;
    dispatch_once(&once,^{ image=RIEmbeddedIcon(RIBookmarkMinusPNGBase64); });
    return image;
}
