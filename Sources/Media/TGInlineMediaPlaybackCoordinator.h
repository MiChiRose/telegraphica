#import <Cocoa/Cocoa.h>

extern NSString * const TGInlineMediaIdentifierKey;
extern NSString * const TGInlineMediaPathKey;
extern NSString * const TGInlineMediaFrameKey;
extern NSString * const TGInlineMediaKindKey;

extern NSString * const TGInlineMediaKindGIF;
extern NSString * const TGInlineMediaKindVideo;
extern NSString * const TGInlineMediaKindWebM;
extern NSString * const TGInlineMediaKindTGS;
extern NSString * const TGInlineMediaPlaybackDiagnosticNotification;
extern NSString * const TGInlineMediaPlaybackDiagnosticMessageKey;

@interface TGInlineMediaPlaybackCoordinator : NSObject

- (instancetype)initWithHostView:(NSView *)hostView maximumActiveItems:(NSUInteger)maximumActiveItems;
- (void)updateWithDescriptors:(NSArray *)descriptors;
- (void)removeAllPlayback;
- (void)invalidate;

@end
