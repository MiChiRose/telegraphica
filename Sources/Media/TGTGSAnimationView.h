#import <Cocoa/Cocoa.h>

@interface TGTGSAnimationView : NSView {
@private
    void *_animation;
    NSImageView *_imageView;
    NSBitmapImageRep *_bitmapRepresentation;
    NSOperationQueue *_renderQueue;
    NSTimer *_frameTimer;
    NSDate *_playbackStartDate;
    NSUInteger _lastScheduledFrame;
    NSUInteger _frameCount;
    NSUInteger _pixelWidth;
    NSUInteger _pixelHeight;
    CGFloat _frameRate;
    BOOL _renderPending;
    BOOL _playbackActive;
}

- (instancetype)initWithFrame:(NSRect)frame tgsPath:(NSString *)path;
- (BOOL)isAnimationValid;
- (void)setPlaybackActive:(BOOL)active;

@end
