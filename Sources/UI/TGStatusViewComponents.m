#import "TGStatusViewComponents.h"
#import "TGMessageLayoutSupport.h"
#import "TGTheme.h"
#include <math.h>

static CGFloat const TGPanelCornerRadius = 8.0;

@implementation TGChromeView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [TGClassicWindowBottomColor() set];
    NSRectFill(bounds);
}

@end

@implementation TGDropOverlayView

- (NSView *)hitTest:(NSPoint)aPoint {
    (void)aPoint;
    return nil;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect([self bounds], 2.0, 2.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:14.0 yRadius:14.0];

    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.94] set];
    [path fill];

    CGFloat dashPattern[2] = { 10.0, 7.0 };
    [path setLineDash:dashPattern count:2 phase:0.0];
    [path setLineWidth:2.0];
    [TGClassicNavigationSelectedColor(0.78) set];
    [path stroke];

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setAlignment:NSCenterTextAlignment];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:17.0], NSFontAttributeName,
                                     TGClassicNavigationSelectedStrokeColor(0.88), NSForegroundColorAttributeName,
                                     paragraph, NSParagraphStyleAttributeName,
                                     nil];
    NSDictionary *subtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                        TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                        paragraph, NSParagraphStyleAttributeName,
                                        nil];
    NSString *title = @"Drop files here to send them";
    NSString *subtitle = @"in a quick way";
    NSSize titleSize = [title sizeWithAttributes:titleAttributes];
    NSSize subtitleSize = [subtitle sizeWithAttributes:subtitleAttributes];
    CGFloat totalHeight = titleSize.height + 4.0 + subtitleSize.height;
    CGFloat titleY = NSMidY(bounds) - floor(totalHeight / 2.0);
    [title drawInRect:NSMakeRect(NSMinX(bounds) + 24.0,
                                 titleY,
                                 NSWidth(bounds) - 48.0,
                                 titleSize.height + 2.0)
        withAttributes:titleAttributes];
    [subtitle drawInRect:NSMakeRect(NSMinX(bounds) + 24.0,
                                    titleY + titleSize.height + 4.0,
                                    NSWidth(bounds) - 48.0,
                                    subtitleSize.height + 2.0)
           withAttributes:subtitleAttributes];
}

@end

@implementation TGMessageTableView

@synthesize dropOverlayTarget = _dropOverlayTarget;

- (void)notifyDropOverlayTarget {
    SEL selector = NSSelectorFromString(@"messageTableViewDragDidEnd:");
    if (_dropOverlayTarget && [_dropOverlayTarget respondsToSelector:selector]) {
        [_dropOverlayTarget performSelector:selector withObject:self];
    }
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
    (void)sender;
    [self notifyDropOverlayTarget];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender {
    (void)sender;
    [self notifyDropOverlayTarget];
}

@end

@implementation TGUtilityWindowView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithCalibratedWhite:0.925 alpha:1.0] set];
    NSRectFill([self bounds]);
}

@end

@implementation TGRailView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSBezierPath *railPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 1.0, 1.0)
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];
    [TGClassicWindowBottomColor() set];
    [railPath fill];

    [TGClassicRailStrokeColor() set];
    [railPath setLineWidth:1.0];
    [railPath stroke];
}

@end

@implementation TGAccountBadgeView

@synthesize displayName = _displayName;
@synthesize avatarLocalPath = _avatarLocalPath;
@synthesize target = _target;
@synthesize action = _action;
@synthesize connected = _connected;

- (void)setDisplayName:(NSString *)displayName {
    if (_displayName == displayName || [_displayName isEqualToString:displayName]) {
        return;
    }
    [_displayName release];
    _displayName = [displayName copy];
    [self setNeedsDisplay:YES];
}

- (void)setAvatarLocalPath:(NSString *)avatarLocalPath {
    if (_avatarLocalPath == avatarLocalPath || [_avatarLocalPath isEqualToString:avatarLocalPath]) {
        return;
    }
    [_avatarLocalPath release];
    _avatarLocalPath = [avatarLocalPath copy];
    [self setNeedsDisplay:YES];
}

- (void)setConnected:(BOOL)connected {
    _connected = connected;
    [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    if (self.target && self.action && [self.target respondsToSelector:self.action]) {
        [NSApp sendAction:self.action to:self.target from:self];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    CGFloat avatarSide = 44.0;
    NSRect avatarRect = NSMakeRect(floor(NSMidX(bounds) - (avatarSide / 2.0)),
                                   floor(NSMidY(bounds) - (avatarSide / 2.0)),
                                   avatarSide,
                                   avatarSide);
    TGDrawAvatarInRect(self.avatarLocalPath, self.displayName, avatarRect, NO, [self isFlipped]);

    NSRect statusRect = NSMakeRect(NSMaxX(avatarRect) - 11.0, NSMinY(avatarRect) + 2.0, 12.0, 12.0);
    NSBezierPath *outerDot = [NSBezierPath bezierPathWithOvalInRect:statusRect];
    [TGClassicWindowBottomColor() set];
    [outerDot fill];
    NSRect innerRect = NSInsetRect(statusRect, 2.0, 2.0);
    NSBezierPath *innerDot = [NSBezierPath bezierPathWithOvalInRect:innerRect];
    NSColor *dotColor = self.connected ? [NSColor colorWithCalibratedRed:0.210 green:0.700 blue:0.315 alpha:1.0]
                                       : TGClassicMutedInkColor();
    [dotColor set];
    [innerDot fill];
}

- (void)dealloc {
    [_displayName release];
    [_avatarLocalPath release];
    [super dealloc];
}

@end

@implementation TGProfileAvatarView

@synthesize displayName = _displayName;
@synthesize avatarLocalPath = _avatarLocalPath;

- (void)setDisplayName:(NSString *)displayName {
    if (_displayName == displayName || [_displayName isEqualToString:displayName]) {
        return;
    }
    [_displayName release];
    _displayName = [displayName copy];
    [self setNeedsDisplay:YES];
}

- (void)setAvatarLocalPath:(NSString *)avatarLocalPath {
    if (_avatarLocalPath == avatarLocalPath || [_avatarLocalPath isEqualToString:avatarLocalPath]) {
        return;
    }
    [_avatarLocalPath release];
    _avatarLocalPath = [avatarLocalPath copy];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    CGFloat avatarSide = floor(MIN(NSWidth(bounds), NSHeight(bounds)));
    if (avatarSide > 92.0) {
        avatarSide = 92.0;
    }
    if (avatarSide < 1.0) {
        return;
    }
    NSRect avatarRect = NSMakeRect(floor(NSMidX(bounds) - (avatarSide / 2.0)),
                                   floor(NSMidY(bounds) - (avatarSide / 2.0)),
                                   avatarSide,
                                   avatarSide);
    TGDrawAvatarInRect(self.avatarLocalPath, self.displayName, avatarRect, NO, [self isFlipped]);
}

- (void)dealloc {
    [_displayName release];
    [_avatarLocalPath release];
    [super dealloc];
}

@end
