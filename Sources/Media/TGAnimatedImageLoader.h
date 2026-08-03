#import <Cocoa/Cocoa.h>

typedef void (^TGAnimatedImageLoadCompletion)(NSImage *image, NSString *failureReason);

@interface TGAnimatedImageLoadToken : NSObject

- (void)cancel;
- (BOOL)isCancelled;

@end

TGAnimatedImageLoadToken *TGLoadAnimatedImageFromFileAsync(NSString *path,
                                                            TGAnimatedImageLoadCompletion completion);
void TGAnimatedImageLoaderClearCache(void);
