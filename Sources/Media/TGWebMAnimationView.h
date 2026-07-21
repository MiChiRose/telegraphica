#import <Cocoa/Cocoa.h>

@interface TGWebMAnimationView : NSView {
@private
    NSOperationQueue *_decodeQueue;
    NSOperation *_decodeOperation;
    NSArray *_frames;
    NSTimer *_frameTimer;
    NSDate *_playbackStartDate;
    NSUInteger _lastAppliedFrame;
    NSUInteger _renderedFrameCount;
    unsigned long long _currentFrameChecksum;
    CGFloat _frameRate;
    BOOL _decodePending;
    BOOL _playbackActive;
    BOOL _animationValid;
    volatile BOOL _decodeCancelled;
}

- (instancetype)initWithFrame:(NSRect)frame webmPath:(NSString *)path;
- (BOOL)isAnimationValid;
- (void)setPlaybackActive:(BOOL)active;
- (void)invalidate;
- (NSUInteger)renderedFrameCount;
- (NSUInteger)lastAppliedFrame;
- (unsigned long long)currentFrameChecksum;

@end
