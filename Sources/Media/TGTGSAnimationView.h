#import <Cocoa/Cocoa.h>

@interface TGTGSAnimationView : NSView {
@private
    void *_animation;
    NSImageView *_imageView;
    NSImage *_renderedImage;
    NSBitmapImageRep *_bitmapRepresentation;
    NSOperationQueue *_renderQueue;
    NSOperation *_renderOperation;
    NSTimer *_frameTimer;
    NSDate *_playbackStartDate;
    NSUInteger _lastScheduledFrame;
    NSUInteger _frameCount;
    NSUInteger _pixelWidth;
    NSUInteger _pixelHeight;
    CGFloat _frameRate;
    NSUInteger _renderedFrameCount;
    NSUInteger _lastAppliedFrame;
    BOOL _renderPending;
    BOOL _playbackActive;
    volatile BOOL _invalidated;
}

- (instancetype)initWithFrame:(NSRect)frame tgsPath:(NSString *)path;
- (BOOL)isAnimationValid;
- (void)setPlaybackActive:(BOOL)active;
- (void)invalidate;
- (NSUInteger)renderedFrameCount;
- (NSUInteger)lastAppliedFrame;
- (unsigned long long)currentFrameChecksum;

@end
