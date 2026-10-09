#import "TGAnimationSupport.h"
#import "TGResourcePolicy.h"
#import <objc/runtime.h>

static NSTimeInterval const TGDefaultRevealDuration = 0.16;
static char TGVisibilityAnimationKey;

BOOL TGInterfaceAnimationsEnabledForView(NSView *view) {
    if (!view || TGResourcePolicyEconomyModeEnabled()) return NO;
    if (![[view window] isVisible]) return NO;
    return !TGResourcePolicyStopAnimationsWhenInactive() || [NSApp isActive];
}

/* One bounded timer per changing panel; no per-row layers or queued completions. */
@interface TGVisibilityAnimation : NSObject {
    NSView *_view;
    NSTimer *_timer;
    NSTimeInterval _started;
    CGFloat _initialAlpha;
    BOOL _visible;
}
- (id)initWithView:(NSView *)view visible:(BOOL)visible;
- (BOOL)targetVisible;
- (void)finish;
@end

@implementation TGVisibilityAnimation
- (id)initWithView:(NSView *)view visible:(BOOL)visible {
    self = [super init];
    if (self) {
        _view = [view retain];
        _visible = visible;
        _initialAlpha = [view isHidden] ? 0.0 : [view alphaValue];
        _started = [NSDate timeIntervalSinceReferenceDate];
        [view setHidden:NO];
        [view setAlphaValue:_initialAlpha];
        _timer = [[NSTimer timerWithTimeInterval:(1.0 / 15.0) target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(policyChanged:) name:TGResourcePolicyDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(policyChanged:) name:NSApplicationDidResignActiveNotification object:nil];
    }
    return self;
}
- (BOOL)targetVisible { return _visible; }
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
    [_timer release];
    [_view release];
    [super dealloc];
}
- (void)finish {
    [self retain];
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    [_view setHidden:!_visible];
    [_view setAlphaValue:1.0];
    if (objc_getAssociatedObject(_view, &TGVisibilityAnimationKey) == self)
        objc_setAssociatedObject(_view, &TGVisibilityAnimationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [_view release];
    _view = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self release];
}
- (void)policyChanged:(NSNotification *)notification {
    (void)notification;
    if (!TGInterfaceAnimationsEnabledForView(_view)) [self finish];
}
- (void)tick:(NSTimer *)timer {
    (void)timer;
    CGFloat progress = ([NSDate timeIntervalSinceReferenceDate] - _started) / TGDefaultRevealDuration;
    if (progress >= 1.0 || !TGInterfaceAnimationsEnabledForView(_view)) {
        [self finish];
        return;
    }
    CGFloat eased = 1.0 - (1.0 - MAX(0.0, progress)) * (1.0 - MAX(0.0, progress));
    CGFloat target = _visible ? 1.0 : 0.0;
    [_view setAlphaValue:_initialAlpha + (target - _initialAlpha) * eased];
}
@end

void TGCancelViewVisibilityAnimation(NSView *view) {
    TGVisibilityAnimation *animation = objc_getAssociatedObject(view, &TGVisibilityAnimationKey);
    [animation finish];
}

void TGSetViewVisibleAnimated(NSView *view, BOOL visible) {
    if (!view) return;
    TGVisibilityAnimation *current = objc_getAssociatedObject(view, &TGVisibilityAnimationKey);
    if (current && [current targetVisible] == visible && TGInterfaceAnimationsEnabledForView(view)) return;
    [current finish];
    if ((![view isHidden]) == visible || !TGInterfaceAnimationsEnabledForView(view)) {
        [view setHidden:!visible];
        [view setAlphaValue:1.0];
        return;
    }
    TGVisibilityAnimation *animation = [[[TGVisibilityAnimation alloc] initWithView:view visible:visible] autorelease];
    objc_setAssociatedObject(view, &TGVisibilityAnimationKey, animation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
