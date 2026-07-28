#import <Cocoa/Cocoa.h>

NSImage *TGImageWithCorrectOrientationFromFile(NSString *path);
NSImage *TGImageThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize);
NSImage *TGImageThumbnailFromData(NSData *data, NSUInteger maximumPixelSize);
void TGMediaImageLoaderSetCacheLimitBytes(NSUInteger bytes);
void TGMediaImageLoaderClearCache(void);
