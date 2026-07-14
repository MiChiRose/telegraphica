#import "TGTGSAnimationView.h"
#import "TGTGSFileValidator.h"
#import <rlottie_capi.h>
#include <math.h>
#include <string.h>

static const NSUInteger TGTGSMaximumFrameCount = 180;
static const CGFloat TGTGSMaximumFrameRate = 60.0;
static const CGFloat TGTGSMaximumDuration = 3.1;

static NSOperationQueue *TGTGSSharedRenderQueue(void) {
    static NSOperationQueue *queue = nil;
    @synchronized([TGTGSAnimationView class]) {
        if (!queue) {
            queue = [[NSOperationQueue alloc] init];
            [queue setMaxConcurrentOperationCount:1];
        }
    }
    return queue;
}

static NSLock *TGTGSSharedRenderLock(void) {
    static NSLock *lock = nil;
    @synchronized([TGTGSAnimationView class]) {
        if (!lock) {
            lock = [[NSLock alloc] init];
        }
    }
    return lock;
}

static void TGTGSDestroyAnimation(Lottie_Animation *animation) {
    if (!animation) {
        return;
    }
    NSLock *lock = TGTGSSharedRenderLock();
    [lock lock];
    lottie_animation_destroy(animation);
    [lock unlock];
}

@interface TGTGSAnimationView ()
- (void)scheduleRenderFrame:(NSUInteger)frameIndex;
- (void)renderFrameInBackground:(NSNumber *)frameNumber;
- (void)applyRenderedFrame:(NSDictionary *)payload;
- (void)advanceFrame:(NSTimer *)timer;
- (void)startFrameTimer;
- (void)stopFrameTimer;
@end

@implementation TGTGSAnimationView

- (instancetype)initWithFrame:(NSRect)frame tgsPath:(NSString *)path {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    NSUInteger validatedFrameCount = 0;
    CGFloat validatedFrameRate = 0.0;
    NSData *jsonData = TGTGSValidatedJSONDataAtPath(path, &validatedFrameCount, &validatedFrameRate);
    if (!jsonData) {
        return self;
    }
    NSString *jsonText = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease];
    if (![jsonText isKindOfClass:[NSString class]] || [jsonText length] == 0) {
        return self;
    }

    NSMutableData *terminatedJSON = [NSMutableData dataWithData:jsonData];
    const unsigned char terminator = 0;
    [terminatedJSON appendBytes:&terminator length:1];
    const char *jsonBytes = (const char *)[terminatedJSON bytes];
    NSString *cacheKey = [NSString stringWithFormat:@"telegraphica-tgs-%lu-%lu",
                          (unsigned long)[path hash],
                          (unsigned long)[jsonData length]];
    Lottie_Animation *animation = NULL;
    NSUInteger frameCount = 0;
    CGFloat frameRate = 0.0;
    size_t sourceWidth = 0;
    size_t sourceHeight = 0;
    CGFloat duration = 0.0;
    NSLock *renderLock = TGTGSSharedRenderLock();
    [renderLock lock];
    animation = lottie_animation_from_data(jsonBytes, [cacheKey UTF8String], "");
    if (animation) {
        frameCount = (NSUInteger)lottie_animation_get_totalframe(animation);
        frameRate = (CGFloat)lottie_animation_get_framerate(animation);
        lottie_animation_get_size(animation, &sourceWidth, &sourceHeight);
        duration = (CGFloat)lottie_animation_get_duration(animation);
    }
    [renderLock unlock];
    if (!animation) {
        return self;
    }

    _animation = animation;
    _frameCount = frameCount;
    _frameRate = frameRate;
    BOOL frameCountMatches = (_frameCount == validatedFrameCount || _frameCount == validatedFrameCount + 1);
    if (!frameCountMatches || fabs(_frameRate - validatedFrameRate) > 0.01 ||
        _frameCount == 0 || _frameCount > TGTGSMaximumFrameCount + 1 ||
        _frameRate <= 0.0 || _frameRate > TGTGSMaximumFrameRate ||
        duration <= 0.0 || duration > TGTGSMaximumDuration ||
        sourceWidth == 0 || sourceWidth > 512 ||
        sourceHeight == 0 || sourceHeight > 512) {
        TGTGSDestroyAnimation(animation);
        _animation = NULL;
        return self;
    }

    _pixelWidth = MIN((NSUInteger)320, (NSUInteger)MAX(1.0, floor(NSWidth(frame))));
    _pixelHeight = MIN((NSUInteger)320, (NSUInteger)MAX(1.0, floor(NSHeight(frame))));
    _bitmapRepresentation = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:(NSInteger)_pixelWidth
                                                                    pixelsHigh:(NSInteger)_pixelHeight
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bitmapFormat:NSAlphaFirstBitmapFormat
                                                                    bytesPerRow:(NSInteger)(_pixelWidth * 4)
                                                                   bitsPerPixel:32];
    if (!_bitmapRepresentation) {
        TGTGSDestroyAnimation(animation);
        _animation = NULL;
        return self;
    }

    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(_pixelWidth, _pixelHeight)] autorelease];
    [image addRepresentation:_bitmapRepresentation];
    _imageView = [[NSImageView alloc] initWithFrame:[self bounds]];
    [_imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [_imageView setImage:image];
    [self addSubview:_imageView];
    _renderQueue = [TGTGSSharedRenderQueue() retain];
    _lastScheduledFrame = NSNotFound;
    _lastAppliedFrame = NSNotFound;
    [self scheduleRenderFrame:0];
    return self;
}

- (BOOL)isAnimationValid {
    return (_animation != NULL && _bitmapRepresentation != nil && _frameCount > 0);
}

- (void)scheduleRenderFrame:(NSUInteger)frameIndex {
    if (![self isAnimationValid] || _renderPending || frameIndex == _lastScheduledFrame) {
        return;
    }
    _renderPending = YES;
    _lastScheduledFrame = frameIndex;
    NSInvocationOperation *operation = [[[NSInvocationOperation alloc] initWithTarget:self
                                                                              selector:@selector(renderFrameInBackground:)
                                                                                object:[NSNumber numberWithUnsignedInteger:frameIndex]] autorelease];
    [_renderQueue addOperation:operation];
}

- (void)renderFrameInBackground:(NSNumber *)frameNumber {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSUInteger frameIndex = [frameNumber unsignedIntegerValue];
    NSMutableData *pixels = [[NSMutableData alloc] initWithLength:_pixelWidth * _pixelHeight * 4];
    NSLock *renderLock = TGTGSSharedRenderLock();
    [renderLock lock];
    lottie_animation_render((Lottie_Animation *)_animation,
                            frameIndex % _frameCount,
                            (uint32_t *)[pixels mutableBytes],
                            _pixelWidth,
                            _pixelHeight,
                            _pixelWidth * 4);
    [renderLock unlock];
    NSDictionary *payload = [[NSDictionary alloc] initWithObjectsAndKeys:
                             frameNumber, @"frame",
                             pixels, @"pixels",
                             nil];
    [self performSelectorOnMainThread:@selector(applyRenderedFrame:)
                           withObject:payload
                        waitUntilDone:NO];
    [payload release];
    [pixels release];
    [pool drain];
}

- (void)applyRenderedFrame:(NSDictionary *)payload {
    NSData *pixels = [payload objectForKey:@"pixels"];
    NSUInteger expectedLength = _pixelWidth * _pixelHeight * 4;
    if ([self isAnimationValid] && [pixels length] == expectedLength) {
        memcpy([_bitmapRepresentation bitmapData], [pixels bytes], expectedLength);
        [_imageView setNeedsDisplay:YES];
        _renderedFrameCount++;
        _lastAppliedFrame = [[payload objectForKey:@"frame"] unsignedIntegerValue];
    }
    _renderPending = NO;
}

- (NSUInteger)renderedFrameCount {
    return _renderedFrameCount;
}

- (NSUInteger)lastAppliedFrame {
    return _lastAppliedFrame;
}

- (unsigned long long)currentFrameChecksum {
    if (!_bitmapRepresentation) {
        return 0;
    }
    const uint32_t *pixels = (const uint32_t *)[_bitmapRepresentation bitmapData];
    NSUInteger pixelCount = _pixelWidth * _pixelHeight;
    unsigned long long checksum = 1469598103934665603ULL;
    NSUInteger index = 0;
    for (index = 0; index < pixelCount; index++) {
        checksum ^= pixels[index];
        checksum *= 1099511628211ULL;
    }
    return checksum;
}

- (void)advanceFrame:(NSTimer *)timer {
    if (timer != _frameTimer || !_playbackActive || _frameCount == 0 || !_playbackStartDate) {
        return;
    }
    NSTimeInterval elapsed = -[_playbackStartDate timeIntervalSinceNow];
    NSUInteger frameIndex = ((NSUInteger)floor(elapsed * _frameRate)) % _frameCount;
    [self scheduleRenderFrame:frameIndex];
}

- (void)startFrameTimer {
    if (_frameTimer || ![self isAnimationValid]) {
        return;
    }
    [_playbackStartDate release];
    _playbackStartDate = [[NSDate date] retain];
    _lastScheduledFrame = NSNotFound;
    [self scheduleRenderFrame:0];
    _frameTimer = [[NSTimer timerWithTimeInterval:(1.0 / 30.0)
                                          target:self
                                        selector:@selector(advanceFrame:)
                                        userInfo:nil
                                         repeats:YES] retain];
    [[NSRunLoop mainRunLoop] addTimer:_frameTimer forMode:NSRunLoopCommonModes];
}

- (void)stopFrameTimer {
    [_frameTimer invalidate];
    [_frameTimer release];
    _frameTimer = nil;
    [_playbackStartDate release];
    _playbackStartDate = nil;
}

- (void)setPlaybackActive:(BOOL)active {
    _playbackActive = active;
    if (active) {
        [self startFrameTimer];
    } else {
        [self stopFrameTimer];
    }
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
    if (!newSuperview) {
        [self setPlaybackActive:NO];
    }
    [super viewWillMoveToSuperview:newSuperview];
}

- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (void)dealloc {
    [self stopFrameTimer];
    [_renderQueue release];
    _renderQueue = nil;
    if (_animation) {
        TGTGSDestroyAnimation((Lottie_Animation *)_animation);
        _animation = NULL;
    }
    [_playbackStartDate release];
    [_imageView release];
    [_bitmapRepresentation release];
    [super dealloc];
}

@end
