#import "TGWorkshopButtonCell.h"
#import "../../UI/TGTheme.h"

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
    NSSize titleSize = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMidX(rect) - floor(titleSize.width / 2.0),
                                  NSMidY(rect) - floor(titleSize.height / 2.0),
                                  MIN(titleSize.width, NSWidth(rect) - 12.0),
                                  titleSize.height);
    [title drawInRect:titleRect withAttributes:attributes];
}

@implementation TGWorkshopButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL enabled = [self isEnabled];
    BOOL pressed = [self isHighlighted];
    NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
    TGThemeDrawEnamelButtonInPath(path,
                                 rect,
                                 pressed,
                                 YES,
                                 enabled,
                                 [controlView isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [path setLineWidth:1.0];
    [path stroke];
    TGWorkshopDrawCenteredTitle(self,
                                rect,
                                TGClassicHeaderTextColor(enabled ? 1.0 : 0.48),
                                YES);
}

@end

@implementation TGWorkshopSegmentButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL selected = ([self state] == NSOnState);
    if (selected || [self isHighlighted]) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6.0 yRadius:6.0];
    TGThemeDrawRecessedBackgroundInPath(path, rect, [controlView isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [path setLineWidth:1.0];
    [path stroke];
    TGWorkshopDrawCenteredTitle(self,
                                rect,
                                TGClassicCardInkColor(),
                                NO);
}

@end
