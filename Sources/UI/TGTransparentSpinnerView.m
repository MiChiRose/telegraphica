#import "TGTransparentSpinnerView.h"
#import <math.h>
#import "TGResourcePolicy.h"

@interface TGTransparentSpinnerView ()
@property (nonatomic, retain) NSTimer *animationTimer;
@property (nonatomic, assign) NSInteger animationStep;
@property (nonatomic, assign, getter=isAnimating) BOOL animating;
@end

@implementation TGTransparentSpinnerView

@synthesize animationTimer = _animationTimer;
@synthesize animationStep = _animationStep;
@synthesize animating = _animating;
@synthesize displayedWhenStopped = _displayedWhenStopped;
@synthesize tintColor = _tintColor;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _displayedWhenStopped = NO;
        _animationStep = 0;
        _tintColor = [[NSColor colorWithCalibratedWhite:0.18 alpha:1.0] retain];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(animationPolicyDidChange:) name:TGResourcePolicyDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(animationPolicyDidChange:) name:NSApplicationDidResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(animationPolicyDidChange:) name:NSApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_animationTimer invalidate];
    [_animationTimer release];
    [_tintColor release];
    [super dealloc];
}

- (BOOL)isOpaque {
    return NO;
}

- (NSView *)hitTest:(NSPoint)aPoint {
    (void)aPoint;
    return nil;
}

/* Transparent ticking must repaint the surface behind the spinner. Otherwise
   accelerated NSClipView scrolling can copy old spokes into its backing store. */
- (void)invalidateSurfaceInSuperview:(NSView *)parent frame:(NSRect)frame {
    if (!parent) return;
    NSRect dirty = NSInsetRect(frame, -2.0, -2.0);
    NSView *surface = parent;
    while (![surface isOpaque] && [surface superview]) {
        dirty = [[surface superview] convertRect:dirty fromView:surface];
        surface = [surface superview];
    }
    [surface setNeedsDisplayInRect:dirty];
}

- (void)invalidateSpinnerSurface {
    [self invalidateSurfaceInSuperview:[self superview] frame:[self frame]];
    [self setNeedsDisplay:YES];
}

- (void)setFrame:(NSRect)frame {
    [self invalidateSurfaceInSuperview:[self superview] frame:[self frame]];
    [super setFrame:frame];
    [self invalidateSpinnerSurface];
}

- (void)setHidden:(BOOL)hidden {
    [self invalidateSurfaceInSuperview:[self superview] frame:[self frame]];
    [super setHidden:hidden];
    [self updateAnimationTimer];
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
    [self invalidateSurfaceInSuperview:[self superview] frame:[self frame]];
    [super viewWillMoveToSuperview:newSuperview];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateAnimationTimer];
}

- (void)updateAnimationTimer {
    BOOL shouldTick = (self.animating && [self window] && ![self isHiddenOrHasHiddenAncestor] &&
                       !TGResourcePolicyEconomyModeEnabled() &&
                       (!TGResourcePolicyStopAnimationsWhenInactive() || [NSApp isActive]));
    if (!shouldTick) {
        [self.animationTimer invalidate];
        self.animationTimer = nil;
    } else if (!self.animationTimer) {
        self.animationTimer = [NSTimer timerWithTimeInterval:(1.0 / 15.0)
                                                    target:self selector:@selector(advanceAnimation:)
                                                  userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)animationPolicyDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateAnimationTimer];
    [self invalidateSpinnerSurface];
}

- (void)startAnimation:(id)sender {
    (void)sender;
    self.animating = YES;
    [self setHidden:NO];
    [self updateAnimationTimer];
    [self invalidateSpinnerSurface];
}

- (void)stopAnimation:(id)sender {
    (void)sender;
    self.animating = NO;
    [self updateAnimationTimer];
    if (!self.displayedWhenStopped) [self setHidden:YES];
    [self invalidateSpinnerSurface];
}

- (void)advanceAnimation:(NSTimer *)timer {
    (void)timer;
    [self updateAnimationTimer];
    if (!self.animationTimer) return;
    self.animationStep = (self.animationStep + 1) % 12;
    [self invalidateSpinnerSurface];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    if (!self.animating && !self.displayedWhenStopped) {
        return;
    }

    NSRect bounds = [self bounds];
    CGFloat side = MIN(NSWidth(bounds), NSHeight(bounds));
    if (side < 8.0) {
        return;
    }

    NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    CGFloat radius = side * 0.35;
    CGFloat innerRadius = side * 0.16;
    CGFloat lineWidth = MAX(1.4, side * 0.075);
    NSInteger count = 12;
    NSInteger index = 0;

    for (index = 0; index < count; index++) {
        NSInteger age = (index - self.animationStep + count) % count;
        CGFloat alpha = 1.0 - ((CGFloat)age / (CGFloat)count);
        if (alpha < 0.16) {
            alpha = 0.16;
        }
        CGFloat angle = ((CGFloat)index / (CGFloat)count) * 2.0 * (CGFloat)M_PI;
        CGFloat sinValue = sin(angle);
        CGFloat cosValue = cos(angle);
        NSPoint start = NSMakePoint(center.x + (cosValue * innerRadius), center.y + (sinValue * innerRadius));
        NSPoint end = NSMakePoint(center.x + (cosValue * radius), center.y + (sinValue * radius));

        NSBezierPath *path = [NSBezierPath bezierPath];
        [path setLineWidth:lineWidth];
        [path setLineCapStyle:NSRoundLineCapStyle];
        [[self.tintColor colorWithAlphaComponent:alpha] setStroke];
        [path moveToPoint:start];
        [path lineToPoint:end];
        [path stroke];
    }
}

@end
