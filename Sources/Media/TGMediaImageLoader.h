#import <Cocoa/Cocoa.h>

NSImage *TGImageWithCorrectOrientationFromFile(NSString *path);
void TGMediaImageLoaderSetCacheLimitBytes(NSUInteger bytes);
void TGMediaImageLoaderClearCache(void);
