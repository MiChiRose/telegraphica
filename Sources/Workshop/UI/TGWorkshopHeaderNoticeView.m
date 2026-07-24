#import "TGWorkshopHeaderNoticeView.h"
#import "TGWorkshopSurfaceView.h"

@implementation TGWorkshopHeaderNoticeView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setHidden:YES];
        [self setAlphaValue:0.0];
        _messageField = [[NSTextField alloc] initWithFrame:NSInsetRect([self bounds], 12.0, 5.0)];
        [_messageField setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [_messageField setEditable:NO];
        [_messageField setSelectable:NO];
        [_messageField setBordered:NO];
        [_messageField setDrawsBackground:NO];
        [_messageField setAlignment:NSCenterTextAlignment];
        [_messageField setFont:[NSFont boldSystemFontOfSize:11.0]];
        [_messageField setTextColor:TGWorkshopCreamColor()];
        [[_messageField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [self addSubview:_messageField];
    }
    return self;
}

- (BOOL)isOpaque {
    return NO;
}

- (NSView *)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect([self bounds], 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:7.0 yRadius:7.0];
    [NSGraphicsContext saveGraphicsState];
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowOffset:NSMakeSize(0.0, -1.0)];
    [shadow setShadowBlurRadius:3.0];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.35]];
    [shadow set];
    [[NSColor colorWithCalibratedRed:0.39 green:0.07 blue:0.15 alpha:0.96] setFill];
    [path fill];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedRed:0.91 green:0.75 blue:0.31 alpha:0.95] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
}

- (void)showMessage:(NSString *)message duration:(NSTimeInterval)duration {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_messageField setStringValue:[message length] > 0 ? message : @""];
    [self setHidden:NO];
    [self setAlphaValue:0.0];
    [self setNeedsDisplay:YES];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.18];
    [[self animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
    if (duration > 0.0) {
        [self performSelector:@selector(hideAnimated) withObject:nil afterDelay:duration];
    }
}

- (void)hideAnimated {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(hideAnimated)
                                               object:nil];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.28];
    [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
    [self performSelector:@selector(finishHiding) withObject:nil afterDelay:0.3];
}

- (void)finishHiding {
    [self setHidden:YES];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_messageField release];
    [super dealloc];
}

@end
