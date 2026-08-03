#import <Cocoa/Cocoa.h>

@class TGMessageItem;

typedef void (^TGMessageThumbnailPrefetchCompletion)(void);

@interface TGMessageThumbnailPrefetcher : NSObject

- (void)prefetchMessageItem:(TGMessageItem *)item
                 completion:(TGMessageThumbnailPrefetchCompletion)completion;
- (void)prefetchPath:(NSString *)path
    maximumPixelSize:(NSUInteger)maximumPixelSize
          completion:(TGMessageThumbnailPrefetchCompletion)completion;
- (void)cancelAll;

@end
