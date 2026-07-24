#import "TGWorkshopSurfaceView.h"

static NSImage *TGWorkshopFeltTile(void) {
    static NSImage *tile = nil;
    if (tile) return tile;
    tile = [[NSImage alloc] initWithSize:NSMakeSize(48.0, 48.0)];
    [tile lockFocus];
    [[NSColor colorWithCalibratedRed:0.055 green:0.36 blue:0.235 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0.0, 0.0, 48.0, 48.0));
    NSUInteger index = 0;
    for (index = 0; index < 72; index++) {
        CGFloat x = (CGFloat)((index * 17 + 5) % 47);
        CGFloat y = (CGFloat)((index * 29 + 11) % 47);
        CGFloat alpha = (index % 3 == 0) ? 0.055 : 0.028;
        [[NSColor colorWithCalibratedWhite:(index % 2 == 0 ? 1.0 : 0.0) alpha:alpha] setStroke];
        NSBezierPath *fiber = [NSBezierPath bezierPath];
        [fiber setLineWidth:0.55];
        [fiber moveToPoint:NSMakePoint(x, y)];
        [fiber lineToPoint:NSMakePoint(MIN(48.0, x + 2.0 + (index % 4)), y + (index % 2))];
        [fiber stroke];
    }
    [tile unlockFocus];
    return tile;
}

static NSImage *TGWorkshopWoodTile(void) {
    static NSImage *tile = nil;
    if (tile) return tile;
    tile = [[NSImage alloc] initWithSize:NSMakeSize(96.0, 42.0)];
    [tile lockFocus];
    NSGradient *wood = [[[NSGradient alloc]
                         initWithColorsAndLocations:
                         [NSColor colorWithCalibratedRed:0.49 green:0.235 blue:0.105 alpha:1.0], 0.0,
                         [NSColor colorWithCalibratedRed:0.68 green:0.36 blue:0.17 alpha:1.0], 0.44,
                         [NSColor colorWithCalibratedRed:0.39 green:0.17 blue:0.075 alpha:1.0], 1.0,
                         nil] autorelease];
    [wood drawInRect:NSMakeRect(0.0, 0.0, 96.0, 42.0) angle:90.0];
    NSUInteger index = 0;
    for (index = 0; index < 14; index++) {
        CGFloat y = 2.0 + (CGFloat)((index * 11) % 38);
        CGFloat wave = (CGFloat)((index * 7) % 12);
        NSBezierPath *grain = [NSBezierPath bezierPath];
        [grain setLineWidth:(index % 4 == 0) ? 1.1 : 0.6];
        [[NSColor colorWithCalibratedRed:0.19 green:0.07 blue:0.025
                                    alpha:(index % 3 == 0 ? 0.22 : 0.12)] setStroke];
        [grain moveToPoint:NSMakePoint(-4.0, y)];
        [grain curveToPoint:NSMakePoint(100.0, y + 1.0)
              controlPoint1:NSMakePoint(28.0, y + wave * 0.16)
              controlPoint2:NSMakePoint(64.0, y - wave * 0.13)];
        [grain stroke];
    }
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.16] setFill];
    NSRectFill(NSMakeRect(0.0, 40.0, 96.0, 1.0));
    [tile unlockFocus];
    return tile;
}

NSColor *TGWorkshopFeltBaseColor(void) {
    return [NSColor colorWithCalibratedRed:0.055 green:0.36 blue:0.235 alpha:1.0];
}

NSColor *TGWorkshopFeltPatternColor(void) {
    static NSColor *color = nil;
    if (!color) color = [[NSColor colorWithPatternImage:TGWorkshopFeltTile()] retain];
    return color;
}

NSColor *TGWorkshopWoodPatternColor(void) {
    static NSColor *color = nil;
    if (!color) color = [[NSColor colorWithPatternImage:TGWorkshopWoodTile()] retain];
    return color;
}

NSColor *TGWorkshopGoldColor(void) {
    return [NSColor colorWithCalibratedRed:0.86 green:0.73 blue:0.30 alpha:1.0];
}

NSColor *TGWorkshopCreamColor(void) {
    return [NSColor colorWithCalibratedRed:0.98 green:0.94 blue:0.78 alpha:1.0];
}

NSColor *TGWorkshopMutedCreamColor(void) {
    return [NSColor colorWithCalibratedRed:0.83 green:0.82 blue:0.66 alpha:1.0];
}

NSColor *TGWorkshopBurgundyColor(void) {
    return [NSColor colorWithCalibratedRed:0.42 green:0.055 blue:0.15 alpha:1.0];
}

NSColor *TGWorkshopDeepGreenColor(void) {
    return [NSColor colorWithCalibratedRed:0.025 green:0.20 blue:0.13 alpha:1.0];
}

static void TGWorkshopDrawTableSurface(NSRect bounds, BOOL woodenHeader) {
    [[NSColor colorWithCalibratedWhite:0.05 alpha:1.0] setFill];
    NSRectFill(bounds);
    NSRect outerRect = NSInsetRect(bounds, 1.0, 1.0);
    NSBezierPath *outer = [NSBezierPath bezierPathWithRoundedRect:outerRect xRadius:8.0 yRadius:8.0];
    [TGWorkshopWoodPatternColor() setFill];
    [outer fill];

    CGFloat headerHeight = woodenHeader ? 43.0 : 9.0;
    NSRect feltRect = NSMakeRect(NSMinX(outerRect) + 8.0,
                                NSMinY(outerRect) + 8.0,
                                NSWidth(outerRect) - 16.0,
                                NSHeight(outerRect) - headerHeight - 8.0);
    NSBezierPath *felt = [NSBezierPath bezierPathWithRoundedRect:feltRect xRadius:6.0 yRadius:6.0];
    [TGWorkshopFeltPatternColor() setFill];
    [felt fill];
    [TGWorkshopGoldColor() setStroke];
    [felt setLineWidth:1.0];
    [felt stroke];

    if (woodenHeader) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.16] setFill];
        NSRectFill(NSMakeRect(NSMinX(outerRect) + 8.0,
                              NSMaxY(outerRect) - headerHeight,
                              NSWidth(outerRect) - 16.0,
                              1.0));
    }
}

@implementation TGWorkshopSurfaceView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    TGWorkshopDrawTableSurface([self bounds], YES);
}

@end

@implementation TGWorkshopGameSurfaceView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    TGWorkshopDrawTableSurface([self bounds], NO);
}

@end
