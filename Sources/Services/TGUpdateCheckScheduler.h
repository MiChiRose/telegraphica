#import <Foundation/Foundation.h>

@interface TGUpdateCheckScheduler : NSObject {
    NSTimer *_timer;
    id _target;
    SEL _selector;
    NSTimeInterval _interval;
}

- (id)initWithTarget:(id)target
            selector:(SEL)selector
            interval:(NSTimeInterval)interval;
- (void)startWithInitialDelay:(NSTimeInterval)initialDelay;
- (void)resetCountdown;
- (void)invalidate;

@end
