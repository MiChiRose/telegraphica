#import <Cocoa/Cocoa.h>

@interface TGWebMAnimationView : NSView {
@private
    NSOperationQueue *_decodeQueue;
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
}

- (instancetype)initWithFrame:(NSRect)frame webmPath:(NSString *)path;
- (BOOL)isAnimationValid;
- (void)setPlaybackActive:(BOOL)active;
- (NSUInteger)renderedFrameCount;
- (NSUInteger)lastAppliedFrame;
- (unsigned long long)currentFrameChecksum;

@end
