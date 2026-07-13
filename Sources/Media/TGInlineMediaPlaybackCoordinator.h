#import <Cocoa/Cocoa.h>

extern NSString * const TGInlineMediaIdentifierKey;
extern NSString * const TGInlineMediaPathKey;
extern NSString * const TGInlineMediaFrameKey;

@interface TGInlineMediaPlaybackCoordinator : NSObject

- (instancetype)initWithHostView:(NSView *)hostView maximumActiveItems:(NSUInteger)maximumActiveItems;
- (void)updateWithDescriptors:(NSArray *)descriptors;
- (void)removeAllPlayback;
- (void)invalidate;

@end
