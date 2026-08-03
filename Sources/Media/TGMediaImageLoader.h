#import <Cocoa/Cocoa.h>

typedef void (^TGMediaImageLoadCompletion)(NSImage *image);

@interface TGMediaImageLoadToken : NSObject

- (void)cancel;
- (BOOL)isCancelled;

@end

NSImage *TGImageWithCorrectOrientationFromFile(NSString *path);
NSImage *TGImageThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize);
NSImage *TGImageThumbnailFromData(NSData *data, NSUInteger maximumPixelSize);
NSImage *TGMediaCachedThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize);
TGMediaImageLoadToken *TGLoadImageThumbnailFromFileAsync(NSString *path,
                                                         NSUInteger maximumPixelSize,
                                                         TGMediaImageLoadCompletion completion);
void TGMediaImageLoaderSetCacheLimitBytes(NSUInteger bytes);
void TGMediaImageLoaderClearCache(void);
