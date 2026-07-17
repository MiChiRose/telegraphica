#import "TGTransparentSpinnerView.h"
#import <math.h>

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

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _displayedWhenStopped = NO;
        _animationStep = 0;
    }
    return self;
}

- (void)dealloc {
    [_animationTimer invalidate];
    [_animationTimer release];
    [super dealloc];
}

- (BOOL)isOpaque {
    return NO;
}

- (void)startAnimation:(id)sender {
    (void)sender;
    if (self.animating) {
        return;
    }
    self.animating = YES;
    [self setHidden:NO];
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 15.0)
                                                           target:self
                                                         selector:@selector(advanceAnimation:)
                                                         userInfo:nil
                                                          repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.animationTimer forMode:NSEventTrackingRunLoopMode];
    [self setNeedsDisplay:YES];
}

- (void)stopAnimation:(id)sender {
    (void)sender;
    self.animating = NO;
    [self.animationTimer invalidate];
    self.animationTimer = nil;
    if (!self.displayedWhenStopped) {
        [self setHidden:YES];
    }
    [self setNeedsDisplay:YES];
}

- (void)advanceAnimation:(NSTimer *)timer {
    (void)timer;
    self.animationStep = (self.animationStep + 1) % 12;
    [self setNeedsDisplay:YES];
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
        [[NSColor colorWithCalibratedWhite:0.18 alpha:alpha] setStroke];
        [path moveToPoint:start];
        [path lineToPoint:end];
        [path stroke];
    }
}

@end
