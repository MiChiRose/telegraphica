#import <Cocoa/Cocoa.h>
#import "TGMediaItemSupport.h"

NSString * const TGInlineMediaKindGIF = @"gif";
NSString * const TGInlineMediaKindVideo = @"video";
NSString * const TGInlineMediaKindWebM = @"webm";
NSString * const TGInlineMediaKindTGS = @"tgs";

static NSDictionary *TGItem(NSString *contentType) {
    return [NSDictionary dictionaryWithObject:contentType forKey:@"content_type"];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL passed = (TGMediaItemSupportsPreview(TGItem(@"messagePhoto")) &&
                   TGMediaItemSupportsPreview(TGItem(@"messageVideo")) &&
                   TGMediaItemSupportsPreview(TGItem(@"messageVideoNote")) &&
                   !TGMediaItemSupportsPreview(TGItem(@"messageSticker")) &&
                   !TGMediaItemSupportsPreview(TGItem(@"messageAnimation")) &&
                   !TGMediaItemSupportsPreview(TGItem(@"messageDocument")));
    [pool drain];
    return passed ? 0 : 1;
}
