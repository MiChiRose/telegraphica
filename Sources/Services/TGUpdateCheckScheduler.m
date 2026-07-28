#import "TGUpdateCheckScheduler.h"

@interface TGUpdateCheckScheduler ()
@property (nonatomic, retain) NSTimer *timer;
@end

@implementation TGUpdateCheckScheduler

@synthesize timer = _timer;

- (id)initWithTarget:(id)target
            selector:(SEL)selector
            interval:(NSTimeInterval)interval {
    self = [super init];
    if (self) {
        _target = target;
        _selector = selector;
        _interval = MAX(60.0, interval);
    }
    return self;
}

- (void)startWithInitialDelay:(NSTimeInterval)initialDelay {
    [self invalidate];
    NSTimer *timer = [NSTimer timerWithTimeInterval:_interval
                                             target:self
                                           selector:@selector(timerDidFire:)
                                           userInfo:nil
                                            repeats:YES];
    [timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:MAX(1.0, initialDelay)]];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)resetCountdown {
    if (!self.timer || ![self.timer isValid]) {
        [self startWithInitialDelay:_interval];
        return;
    }
    [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:_interval]];
}

- (void)timerDidFire:(NSTimer *)timer {
    if (timer != self.timer || !_target || !_selector ||
        ![_target respondsToSelector:_selector]) {
        return;
    }
    [_target performSelector:_selector];
}

- (void)invalidate {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)dealloc {
    [self invalidate];
    [super dealloc];
}

@end
