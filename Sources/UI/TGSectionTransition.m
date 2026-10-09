#import "TGSectionTransition.h"
#import "TGAnimationSupport.h"
#import "TGResourcePolicy.h"

static NSTimeInterval const TGSectionTransitionDuration = 0.16;
static CGFloat const TGSectionTransitionMaximumAlpha = 0.15;

@interface TGSectionTransitionVeil : NSView {
    NSColor *_color;
}
- (id)initWithFrame:(NSRect)frame color:(NSColor *)color;
@end

@implementation TGSectionTransitionVeil
- (id)initWithFrame:(NSRect)frame color:(NSColor *)color {
    self = [super initWithFrame:frame];
    if (self) _color = [color retain];
    return self;
}
- (void)dealloc { [_color release]; [super dealloc]; }
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)point { (void)point; return nil; }
- (void)drawRect:(NSRect)dirtyRect {
    [_color setFill];
    NSRectFill(NSIntersectionRect(dirtyRect, [self bounds]));
}
@end

@implementation TGSectionTransitionController
- (id)initWithContentView:(NSView *)contentView {
    self = [super init];
    if (self) {
        _contentView = [contentView retain];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(policyChanged:) name:TGResourcePolicyDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(policyChanged:) name:NSApplicationDidResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(windowChanged:) name:NSWindowDidResizeNotification object:[contentView window]];
        [center addObserver:self selector:@selector(windowChanged:) name:NSWindowWillCloseNotification object:[contentView window]];
    }
    return self;
}
- (void)dealloc {
    [self reset];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_contentView release];
    [super dealloc];
}
- (BOOL)isAnimating { return _timer != nil; }
- (void)cancelAnimation {
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    [_veilView removeFromSuperview];
    [_veilView release];
    _veilView = nil;
}
- (void)reset {
    [self cancelAnimation];
    [_section release]; _section = nil;
    [_context release]; _context = nil;
}
- (void)policyChanged:(NSNotification *)notification {
    (void)notification;
    if (!TGInterfaceAnimationsEnabledForView(_contentView)) [self cancelAnimation];
}
- (void)windowChanged:(NSNotification *)notification {
    if ([notification object] == [_contentView window]) [self cancelAnimation];
}
- (void)presentSection:(NSString *)section contentRect:(NSRect)rect backgroundColor:(NSColor *)color context:(id)context {
    if (![section length] || !context) { [self reset]; return; }
    BOOL changed = _section && ![_section isEqualToString:section] && _context == context;
    BOOL sameSection = [_section isEqualToString:section] && _context == context;
    rect = NSIntersectionRect(rect, [_contentView bounds]);
    if (sameSection) {
        if (!TGInterfaceAnimationsEnabledForView(_contentView) ||
            (_veilView && !NSEqualRects(rect, [_veilView frame]))) [self cancelAnimation];
        return;
    }
    [self cancelAnimation];
    [_section release]; _section = [section copy];
    [_context release]; _context = [context retain];
    if (!changed || !color || NSIsEmptyRect(rect) || !TGInterfaceAnimationsEnabledForView(_contentView)) return;

    /* No screenshots, layers, child animations or delayed navigation callbacks.
     * Only three bounded redraws of the incoming section's body at 15fps. */
    _veilView = [[TGSectionTransitionVeil alloc] initWithFrame:rect color:color];
    [_veilView setAlphaValue:TGSectionTransitionMaximumAlpha];
    [_contentView addSubview:_veilView positioned:NSWindowAbove relativeTo:nil];
    _started = [NSDate timeIntervalSinceReferenceDate];
    _timer = [[NSTimer timerWithTimeInterval:(1.0 / 15.0) target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}
- (void)tick:(NSTimer *)timer {
    (void)timer;
    [self retain]; // Timer invalidation can release its last external owner.
    NSTimeInterval progress = ([NSDate timeIntervalSinceReferenceDate] - _started) / TGSectionTransitionDuration;
    if (progress >= 1.0 || !TGInterfaceAnimationsEnabledForView(_contentView)) {
        [self cancelAnimation];
        [self release];
        return;
    }
    CGFloat remaining = 1.0 - MAX(0.0, progress);
    [_veilView setAlphaValue:TGSectionTransitionMaximumAlpha * remaining * remaining];
    [self release];
}
@end
