#import "TGWorkshopButtonCell.h"
#import "../../UI/TGIconAssets.h"
#import "TGWorkshopSurfaceView.h"

static void TGWorkshopDrawCenteredTitle(NSButtonCell *cell,
                                        NSRect rect,
                                        NSColor *color,
                                        BOOL bold) {
    NSString *title = [cell title] ? [cell title] : @"";
    NSFont *font = bold ? [NSFont boldSystemFontOfSize:11.0] : [NSFont systemFontOfSize:11.0];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                color, NSForegroundColorAttributeName,
                                nil];
    NSImage *image = [cell image];
    CGFloat imageWidth = image ? 16.0 : 0.0;
    CGFloat imageGap = (image && [title length] > 0) ? 6.0 : 0.0;
    NSSize titleSize = [title sizeWithAttributes:attributes];
    CGFloat contentWidth = imageWidth + imageGap + titleSize.width;
    CGFloat contentX = NSMidX(rect) - floor(contentWidth / 2.0);
    if (image) {
        NSRect imageRect = NSMakeRect(contentX,
                                      NSMidY(rect) - 8.0,
                                      16.0,
                                      16.0);
        [image drawInRect:imageRect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0
           respectFlipped:NO
                    hints:nil];
    }
    NSRect titleRect = NSMakeRect(contentX + imageWidth + imageGap,
                                  NSMidY(rect) - floor(titleSize.height / 2.0),
                                  MIN(titleSize.width, NSWidth(rect) - imageWidth - imageGap - 12.0),
                                  titleSize.height);
    [title drawInRect:titleRect withAttributes:attributes];
}

@implementation TGWorkshopButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL enabled = [self isEnabled];
    BOOL pressed = [self isHighlighted];
    NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
    NSColor *top = pressed
        ? [NSColor colorWithCalibratedRed:0.52 green:0.36 blue:0.10 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.94 green:0.82 blue:0.39 alpha:1.0];
    NSColor *bottom = pressed
        ? [NSColor colorWithCalibratedRed:0.70 green:0.54 blue:0.19 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.68 green:0.48 blue:0.12 alpha:1.0];
    if (!enabled) {
        top = [NSColor colorWithCalibratedRed:0.48 green:0.47 blue:0.36 alpha:1.0];
        bottom = [NSColor colorWithCalibratedRed:0.34 green:0.34 blue:0.27 alpha:1.0];
    }
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
    [gradient drawInBezierPath:path angle:90.0];
    [[NSColor colorWithCalibratedRed:0.22 green:0.13 blue:0.045 alpha:0.95] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    TGWorkshopDrawCenteredTitle(self,
                                rect,
                                [NSColor colorWithCalibratedRed:0.08 green:0.11 blue:0.075
                                                        alpha:(enabled ? 1.0 : 0.58)],
                                YES);
}

@end

@implementation TGWorkshopSegmentButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL selected = ([self state] == NSOnState);
    if (selected || [self isHighlighted]) {
        NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
        NSColor *top = [NSColor colorWithCalibratedRed:0.55 green:0.075 blue:0.19 alpha:1.0];
        NSColor *bottom = TGWorkshopBurgundyColor();
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
        [gradient drawInBezierPath:path angle:90.0];
        [TGWorkshopGoldColor() setStroke];
        [path setLineWidth:1.0];
        [path stroke];
        TGWorkshopDrawCenteredTitle(self, rect, TGWorkshopCreamColor(), YES);
        return;
    }

    NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
    [TGWorkshopDeepGreenColor() setFill];
    [path fill];
    [[TGWorkshopGoldColor() colorWithAlphaComponent:0.72] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    TGWorkshopDrawCenteredTitle(self,
                                rect,
                                TGWorkshopCreamColor(),
                                NO);
}

@end
