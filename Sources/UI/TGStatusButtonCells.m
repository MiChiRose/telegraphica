#import "TGStatusButtonCells.h"
#import "TGIconAssets.h"
#import "TGIconDrawing.h"
#import "TGTheme.h"
#include <math.h>

static void TGStrokeLine(NSPoint startPoint, NSPoint endPoint, CGFloat width) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:width];
    [path moveToPoint:startPoint];
    [path lineToPoint:endPoint];
    [path stroke];
}

static CGFloat TGIconY(NSRect rect, CGFloat y, CGFloat height, BOOL flipped) {
    return flipped ? (NSMaxY(rect) - y - height) : (NSMinY(rect) + y);
}

static NSRect TGIconRect(NSRect rect, CGFloat x, CGFloat y, CGFloat width, CGFloat height, BOOL flipped) {
    return NSMakeRect(NSMinX(rect) + x, TGIconY(rect, y, height, flipped), width, height);
}

static NSPoint TGIconPoint(NSRect rect, CGFloat x, CGFloat y, BOOL flipped) {
    return NSMakePoint(NSMinX(rect) + x, flipped ? (NSMaxY(rect) - y) : (NSMinY(rect) + y));
}

void TGDrawMutedSpeakerIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSBezierPath *speakerPath = [NSBezierPath bezierPath];
    [speakerPath moveToPoint:TGIconPoint(iconRect, 3.0, 7.0, flipped)];
    [speakerPath lineToPoint:TGIconPoint(iconRect, 6.5, 7.0, flipped)];
    [speakerPath lineToPoint:TGIconPoint(iconRect, 11.0, 3.5, flipped)];
    [speakerPath lineToPoint:TGIconPoint(iconRect, 11.0, 14.5, flipped)];
    [speakerPath lineToPoint:TGIconPoint(iconRect, 6.5, 11.0, flipped)];
    [speakerPath lineToPoint:TGIconPoint(iconRect, 3.0, 11.0, flipped)];
    [speakerPath closePath];
    [speakerPath fill];

    NSBezierPath *wavePath = [NSBezierPath bezierPath];
    [wavePath setLineWidth:1.25];
    [wavePath moveToPoint:TGIconPoint(iconRect, 13.0, 6.0, flipped)];
    [wavePath curveToPoint:TGIconPoint(iconRect, 13.0, 12.0, flipped)
             controlPoint1:TGIconPoint(iconRect, 15.0, 7.4, flipped)
             controlPoint2:TGIconPoint(iconRect, 15.0, 10.6, flipped)];
    [wavePath stroke];

    TGStrokeLine(TGIconPoint(iconRect, 3.0, 3.5, flipped),
                 TGIconPoint(iconRect, 16.0, 15.5, flipped),
                 1.7);
}

static void TGDrawNavigationIcon(NSString *title, NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    if ([title isEqualToString:@"Chats"] || [title isEqualToString:@"Чаты"]) {
        TGDrawTemplateIconAsset(@"chat", iconRect, color, 1.0, flipped);
    } else if ([title isEqualToString:@"Profile"] || [title isEqualToString:@"Профиль"] || [title isEqualToString:@"Профіль"]) {
        TGDrawTemplateIconAsset(@"user", iconRect, color, 1.0, flipped);
    } else if ([title isEqualToString:@"Settings"] || [title isEqualToString:@"Настройки"] || [title isEqualToString:@"Налады"]) {
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 14.0, flipped),
                     TGIconPoint(iconRect, 16.0, 14.0, flipped),
                     1.4);
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 9.0, flipped),
                     TGIconPoint(iconRect, 16.0, 9.0, flipped),
                     1.4);
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 4.0, flipped),
                     TGIconPoint(iconRect, 16.0, 4.0, flipped),
                     1.4);
        [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 5.0, 12.0, 4.0, 4.0, flipped)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 11.0, 7.0, 4.0, 4.0, flipped)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 7.0, 2.0, 4.0, 4.0, flipped)] fill];
    } else if ([title isEqualToString:@"All"] || [title isEqualToString:@"Private"] || [title isEqualToString:@"Groups"]) {
        NSRect folderBody = TGIconRect(iconRect, 2.0, 4.0, 14.0, 10.0, flipped);
        NSRect folderTab = TGIconRect(iconRect, 3.0, 12.0, 6.0, 3.0, flipped);
        NSBezierPath *folderPath = [NSBezierPath bezierPath];
        [folderPath appendBezierPathWithRoundedRect:folderBody xRadius:2.0 yRadius:2.0];
        [folderPath appendBezierPathWithRoundedRect:folderTab xRadius:1.5 yRadius:1.5];
        [folderPath fill];

        NSColor *detailColor = TGClassicWindowBottomColor();
        [detailColor set];
        if ([title isEqualToString:@"Private"]) {
            [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 7.0, 8.0, 4.0, 4.0, flipped)] fill];
            TGStrokeLine(TGIconPoint(iconRect, 6.0, 6.0, flipped), TGIconPoint(iconRect, 12.0, 6.0, flipped), 1.1);
        } else if ([title isEqualToString:@"Groups"]) {
            [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 4.0, 8.0, 3.4, 3.4, flipped)] fill];
            [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 10.6, 8.0, 3.4, 3.4, flipped)] fill];
            TGStrokeLine(TGIconPoint(iconRect, 5.0, 6.0, flipped), TGIconPoint(iconRect, 13.0, 6.0, flipped), 1.0);
        } else {
            TGStrokeLine(TGIconPoint(iconRect, 5.0, 9.5, flipped), TGIconPoint(iconRect, 13.0, 9.5, flipped), 1.0);
            TGStrokeLine(TGIconPoint(iconRect, 5.0, 7.0, flipped), TGIconPoint(iconRect, 13.0, 7.0, flipped), 1.0);
        }
    } else if ([title isEqualToString:@"Logs"]) {
        NSRect pageRect = TGIconRect(iconRect, 3.0, 2.0, 12.0, 14.0, flipped);
        [[NSBezierPath bezierPathWithRoundedRect:pageRect xRadius:2.0 yRadius:2.0] stroke];
        TGStrokeLine(TGIconPoint(iconRect, 6.0, 12.0, flipped), TGIconPoint(iconRect, 12.0, 12.0, flipped), 1.1);
        TGStrokeLine(TGIconPoint(iconRect, 6.0, 8.0, flipped), TGIconPoint(iconRect, 12.0, 8.0, flipped), 1.1);
        TGStrokeLine(TGIconPoint(iconRect, 6.0, 4.0, flipped), TGIconPoint(iconRect, 10.0, 4.0, flipped), 1.1);
    } else if ([title isEqualToString:@"About"]) {
        NSRect circleRect = TGIconRect(iconRect, 2.5, 2.5, 13.0, 13.0, flipped);
        [[NSBezierPath bezierPathWithOvalInRect:circleRect] stroke];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                                    color, NSForegroundColorAttributeName,
                                    nil];
        NSSize size = [@"i" sizeWithAttributes:attributes];
        [@"i" drawAtPoint:NSMakePoint(NSMidX(circleRect) - (size.width / 2.0),
                                      NSMidY(circleRect) - (size.height / 2.0) - 0.5)
           withAttributes:attributes];
    } else {
        NSRect folderBody = TGIconRect(iconRect, 2.0, 4.0, 14.0, 10.0, flipped);
        NSRect folderTab = TGIconRect(iconRect, 3.0, 12.0, 6.0, 3.0, flipped);
        NSBezierPath *folderPath = [NSBezierPath bezierPath];
        [folderPath appendBezierPathWithRoundedRect:folderBody xRadius:2.0 yRadius:2.0];
        [folderPath appendBezierPathWithRoundedRect:folderTab xRadius:1.5 yRadius:1.5];
        [folderPath fill];
    }
}

@implementation TGNavigationButtonCell

@synthesize badgeText = _badgeText;

- (id)copyWithZone:(NSZone *)zone {
    TGNavigationButtonCell *cell = [super copyWithZone:zone];
    [cell setBadgeText:self.badgeText];
    return cell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL selected = ([self state] == NSOnState);
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];

    TGThemeDrawEnamelButtonInPath(path, buttonRect, highlighted, selected, enabled, [controlView isFlipped]);

    NSColor *strokeColor = selected ? TGClassicNavigationSelectedStrokeColor(0.95) : TGClassicNavigationNormalStrokeColor(0.75);
    [strokeColor set];
    [path setLineWidth:1.0];
    [path stroke];

    NSString *title = [self title] ? [self title] : @"";
    NSFont *font = selected ? [NSFont boldSystemFontOfSize:11.0] : [NSFont systemFontOfSize:11.0];
    NSColor *textColor = selected ? TGClassicNavigationTextColor(alpha) : TGClassicNavigationMutedTextColor(alpha);
    BOOL flipped = [controlView isFlipped];
    NSRect iconRect = NSMakeRect(floor(NSMidX(cellFrame) - 9.0),
                                 flipped ? (NSMinY(cellFrame) + 6.0) : (NSMaxY(cellFrame) - 24.0),
                                 18.0,
                                 18.0);
    TGDrawNavigationIcon(title, iconRect, textColor, flipped);
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                textColor, NSForegroundColorAttributeName,
                                nil];
    NSSize titleSize = [title sizeWithAttributes:attributes];
    CGFloat titleY = flipped ? (NSMaxY(cellFrame) - titleSize.height - 7.0) : (NSMinY(cellFrame) + 7.0);
    NSRect titleRect = NSMakeRect(NSMinX(cellFrame) + floor((NSWidth(cellFrame) - titleSize.width) / 2.0),
                                  titleY,
                                  titleSize.width,
                                  titleSize.height);
    [title drawInRect:titleRect withAttributes:attributes];

    if ([self.badgeText length] > 0) {
        NSFont *badgeFont = [NSFont boldSystemFontOfSize:8.5];
        NSDictionary *badgeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         badgeFont, NSFontAttributeName,
                                         [NSColor whiteColor], NSForegroundColorAttributeName,
                                         nil];
        NSSize badgeTextSize = [self.badgeText sizeWithAttributes:badgeAttributes];
        CGFloat badgeHeight = 15.0;
        CGFloat badgeWidth = ceil(badgeTextSize.width) + 8.0;
        if (badgeWidth < badgeHeight) {
            badgeWidth = badgeHeight;
        }
        NSRect badgeRect = NSMakeRect(NSMaxX(cellFrame) - badgeWidth - 4.0,
                                     flipped ? (NSMinY(cellFrame) + 3.0) : (NSMaxY(cellFrame) - badgeHeight - 3.0),
                                     badgeWidth,
                                     badgeHeight);
        NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect
                                                                  xRadius:(badgeHeight / 2.0)
                                                                  yRadius:(badgeHeight / 2.0)];
        [[NSColor colorWithCalibratedRed:0.820 green:0.180 blue:0.170 alpha:alpha] set];
        [badgePath fill];
        NSRect badgeTextRect = NSMakeRect(NSMinX(badgeRect) + floor((badgeWidth - badgeTextSize.width) / 2.0),
                                         NSMinY(badgeRect) + floor((badgeHeight - badgeTextSize.height) / 2.0) - 0.5,
                                         badgeTextSize.width,
                                         badgeTextSize.height);
        [self.badgeText drawInRect:badgeTextRect withAttributes:badgeAttributes];
    }
}

- (void)dealloc {
    [_badgeText release];
    [super dealloc];
}

@end

@implementation TGDrawerButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];
    TGThemeDrawEnamelButtonInPath(path, buttonRect, highlighted, NO, enabled, [controlView isFlipped]);
    [TGClassicNavigationNormalStrokeColor(0.75) set];
    [path setLineWidth:1.0];
    [path stroke];

    NSColor *lineColor = TGClassicNavigationTextColor(alpha);
    [lineColor set];
    BOOL flipped = [controlView isFlipped];
    NSRect iconRect = NSMakeRect(NSMinX(cellFrame) + floor((NSWidth(cellFrame) - 18.0) / 2.0),
                                 NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 14.0) / 2.0),
                                 18.0,
                                 14.0);
    TGStrokeLine(TGIconPoint(iconRect, 2.0, 12.0, flipped), TGIconPoint(iconRect, 16.0, 12.0, flipped), 1.8);
    TGStrokeLine(TGIconPoint(iconRect, 2.0, 7.0, flipped), TGIconPoint(iconRect, 16.0, 7.0, flipped), 1.8);
    TGStrokeLine(TGIconPoint(iconRect, 2.0, 2.0, flipped), TGIconPoint(iconRect, 16.0, 2.0, flipped), 1.8);
}

@end

@implementation TGSendButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSRect sendRect = NSMakeRect(NSMidX(buttonRect) - 9.0,
                                 NSMidY(buttonRect) - 9.0,
                                 18.0,
                                 18.0);
    TGDrawTemplateIconAsset(@"send", sendRect, TGClassicHeaderTextColor(alpha), 1.0, [controlView isFlipped]);
}

@end

@implementation TGAttachButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSRect iconRect = NSMakeRect(NSMidX(buttonRect) - 10.5,
                                 NSMidY(buttonRect) - 10.5,
                                 21.0,
                                 21.0);
    TGDrawTemplateIconAsset(@"upload", iconRect, TGClassicHeaderTextColor(alpha), 1.0, [controlView isFlipped]);
}

@end

@implementation TGComposerSymbolButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSString *title = [self title] ? [self title] : @"";
    BOOL flipped = [controlView isFlipped];
    NSColor *iconColor = TGClassicHeaderTextColor(alpha);
    [iconColor set];
    if ([title isEqualToString:@"mic"]) {
        NSRect micRect = NSMakeRect(NSMidX(buttonRect) - 11.0, NSMidY(buttonRect) - 11.0, 22.0, 22.0);
        TGDrawTemplateIconAsset(@"microphone", micRect, iconColor, 1.0, flipped);
        return;
    }
    if ([title isEqualToString:@"☺"] || [title isEqualToString:@"stickers"]) {
        NSRect smileRect = NSMakeRect(NSMidX(buttonRect) - 12.0, NSMidY(buttonRect) - 12.0, 24.0, 24.0);
        TGDrawTemplateIconAsset(@"emoji-smile", smileRect, iconColor, 1.0, flipped);
        return;
    }

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:18.0], NSFontAttributeName,
                                iconColor, NSForegroundColorAttributeName,
                                nil];
    NSString *symbol = ([title length] > 0) ? title : @"☺";
    NSSize size = [symbol sizeWithAttributes:attributes];
    NSRect symbolRect = NSMakeRect(NSMidX(buttonRect) - floor(size.width / 2.0),
                                   NSMidY(buttonRect) - floor(size.height / 2.0) - 1.0,
                                   size.width + 2.0,
                                   size.height + 2.0);
    [symbol drawInRect:symbolRect withAttributes:attributes];
}

@end

@implementation TGHeaderIconButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:5.0 yRadius:5.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicTableGridColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSString *title = [self title] ? [self title] : @"";
    NSString *assetName = nil;
    if ([title isEqualToString:@"↻"]) {
        assetName = @"refresh";
    } else if ([title isEqualToString:@"+"]) {
        assetName = @"plus";
    } else if ([title isEqualToString:@"↑"]) {
        assetName = @"upload";
    } else if ([title isEqualToString:@"search"]) {
        assetName = @"search";
    } else if ([title isEqualToString:@"jump-newest"]) {
        assetName = @"arrow-down";
    } else if ([title isEqualToString:@"zoom-in"]) {
        assetName = @"add-ellipse";
    } else if ([title isEqualToString:@"zoom-out"]) {
        assetName = @"remove-ellipse";
    }
    if ([assetName length] > 0) {
        NSRect iconRect = NSMakeRect(NSMidX(buttonRect) - 9.0,
                                     NSMidY(buttonRect) - 9.0,
                                     18.0,
                                     18.0);
        TGDrawTemplateIconAsset(assetName, iconRect, TGClassicHeaderTextColor(alpha), 1.0, [controlView isFlipped]);
        return;
    }
    if ([controlView isKindOfClass:[NSButton class]]) {
        NSImage *image = [(NSButton *)controlView image];
        if (image) {
            NSSize imageSize = [image size];
            if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
                imageSize = NSMakeSize(18.0, 18.0);
            }
            CGFloat side = 18.0;
            NSRect iconRect = NSMakeRect(NSMidX(buttonRect) - (side / 2.0),
                                         NSMidY(buttonRect) - (side / 2.0),
                                         side,
                                         side);
            [image drawInRect:iconRect
                      fromRect:NSZeroRect
                     operation:NSCompositeSourceOver
                      fraction:alpha
                respectFlipped:[controlView isFlipped]
                         hints:nil];
            return;
        }
    }
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setAlignment:NSCenterTextAlignment];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:16.0], NSFontAttributeName,
                                TGClassicHeaderTextColor(alpha), NSForegroundColorAttributeName,
                                paragraph, NSParagraphStyleAttributeName,
                                nil];
    NSSize titleSize = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMinX(buttonRect),
                                  NSMinY(buttonRect) + floor((NSHeight(buttonRect) - titleSize.height) / 2.0),
                                  NSWidth(buttonRect),
                                  titleSize.height + 2.0);
    [title drawInRect:titleRect withAttributes:attributes];
}

@end

@implementation TGMediaZoomButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    BOOL flipped = [controlView isFlipped];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:5.0 yRadius:5.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicTableGridColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSColor *iconColor = TGClassicHeaderTextColor(alpha);
    [iconColor set];
    CGFloat circleSide = 11.0;
    CGFloat visualYOffset = flipped ? -2.0 : 2.0;
    NSRect lensRect = NSMakeRect(NSMidX(buttonRect) - 7.0,
                                 NSMidY(buttonRect) - 4.0 + visualYOffset,
                                 circleSide,
                                 circleSide);
    NSBezierPath *lensPath = [NSBezierPath bezierPathWithOvalInRect:lensRect];
    [lensPath setLineWidth:1.5];
    [lensPath stroke];

    NSBezierPath *handlePath = [NSBezierPath bezierPath];
    [handlePath setLineWidth:1.8];
    CGFloat handleStartY = flipped ? (NSMaxY(lensRect) - 1.5) : (NSMinY(lensRect) + 1.5);
    CGFloat handleEndY = flipped ? (NSMaxY(lensRect) + 5.0) : (NSMinY(lensRect) - 5.0);
    [handlePath moveToPoint:NSMakePoint(NSMaxX(lensRect) - 1.5, handleStartY)];
    [handlePath lineToPoint:NSMakePoint(NSMaxX(lensRect) + 5.0, handleEndY)];
    [handlePath stroke];

    NSBezierPath *minusPath = [NSBezierPath bezierPath];
    [minusPath setLineWidth:1.5];
    [minusPath moveToPoint:NSMakePoint(NSMinX(lensRect) + 3.0, NSMidY(lensRect))];
    [minusPath lineToPoint:NSMakePoint(NSMaxX(lensRect) - 3.0, NSMidY(lensRect))];
    [minusPath stroke];

    if ([[self title] isEqualToString:@"zoom-in"]) {
        NSBezierPath *plusPath = [NSBezierPath bezierPath];
        [plusPath setLineWidth:1.5];
        [plusPath moveToPoint:NSMakePoint(NSMidX(lensRect), NSMinY(lensRect) + 3.0)];
        [plusPath lineToPoint:NSMakePoint(NSMidX(lensRect), NSMaxY(lensRect) - 3.0)];
        [plusPath stroke];
    }
}

@end

@implementation TGMediaPlaybackButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, enabled, [controlView isFlipped]);
    [TGClassicTableGridColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSColor *iconColor = TGClassicHeaderTextColor(alpha);
    [iconColor set];
    BOOL pauseIcon = [[[self title] lowercaseString] isEqualToString:@"pause"];
    NSRect iconRect = NSMakeRect(NSMidX(buttonRect) - 8.0,
                                 NSMidY(buttonRect) - 8.0,
                                 16.0,
                                 16.0);
    TGDrawTemplateIconAsset((pauseIcon ? @"pause" : @"play"), iconRect, iconColor, 1.0, [controlView isFlipped]);
}

@end

@implementation TGSettingsListButtonCell

- (NSColor *)accentColorForTitle:(NSString *)title alpha:(CGFloat)alpha {
    if ([title isEqualToString:@"Appearance"]) {
        return [NSColor colorWithCalibratedRed:0.180 green:0.600 blue:0.860 alpha:alpha];
    }
    if ([title isEqualToString:@"Diagnostic Logs"]) {
        return [NSColor colorWithCalibratedRed:0.520 green:0.540 blue:0.590 alpha:alpha];
    }
    return [NSColor colorWithCalibratedRed:0.950 green:0.520 blue:0.160 alpha:alpha];
}

- (NSString *)glyphForTitle:(NSString *)title {
    if ([title isEqualToString:@"Appearance"]) {
        return @"A";
    }
    if ([title isEqualToString:@"Diagnostic Logs"]) {
        return @"L";
    }
    return @"i";
}

- (NSString *)iconNameForTitle:(NSString *)title {
    if ([title isEqualToString:@"Appearance"]) {
        return @"image";
    }
    if ([title isEqualToString:@"Diagnostic Logs"]) {
        return @"document";
    }
    return @"info";
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect rowRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *rowPath = [NSBezierPath bezierPathWithRoundedRect:rowRect xRadius:9.0 yRadius:9.0];
    if (TGThemeIsSkeuomorphicBlue()) {
        TGThemeDrawRecessedBackgroundInPath(rowPath, rowRect, [controlView isFlipped]);
    } else {
        NSColor *rowColor = highlighted ? TGClassicTableHeaderColor() : TGClassicTablePaperColor();
        [rowColor set];
        [rowPath fill];
    }
    [TGClassicPanelStrokeColor() set];
    [rowPath setLineWidth:1.0];
    [rowPath stroke];

    NSString *title = [self title] ? [self title] : @"";
    NSRect iconRect = NSMakeRect(NSMinX(rowRect) + 11.0, NSMidY(rowRect) - 12.0, 24.0, 24.0);
    NSBezierPath *iconPath = [NSBezierPath bezierPathWithRoundedRect:iconRect xRadius:5.0 yRadius:5.0];
    [[self accentColorForTitle:title alpha:alpha] set];
    [iconPath fill];

    NSRect rowIconRect = NSInsetRect(iconRect, 4.0, 4.0);
    TGDrawTemplateIconAsset([self iconNameForTitle:title],
                            rowIconRect,
                            [NSColor colorWithCalibratedWhite:1.0 alpha:alpha],
                            1.0,
                            [controlView isFlipped]);

    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                                     TGClassicInkColor(), NSForegroundColorAttributeName,
                                     nil];
    NSRect titleRect = NSMakeRect(NSMinX(rowRect) + 48.0,
                                  NSMidY(rowRect) - 9.0,
                                  NSWidth(rowRect) - 82.0,
                                  18.0);
    [title drawInRect:titleRect withAttributes:titleAttributes];

    NSDictionary *chevronAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont systemFontOfSize:18.0], NSFontAttributeName,
                                       TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                       nil];
    [@">" drawAtPoint:NSMakePoint(NSMaxX(rowRect) - 24.0, NSMidY(rowRect) - 12.0)
       withAttributes:chevronAttributes];
}

@end

@implementation TGStickerPickerButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.52;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:5.0 yRadius:5.0];

    if (TGThemeIsSkeuomorphicBlue()) {
        TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, NO, enabled, [controlView isFlipped]);
    } else {
        NSColor *topColor = highlighted ? TGClassicNavigationHighlightedColor(alpha) : TGClassicTablePaperColor();
        NSColor *bottomColor = highlighted ? TGClassicNavigationNormalColor(alpha) : TGClassicPanelBottomColor();
        NSGradient *backgroundGradient = [[[NSGradient alloc] initWithStartingColor:topColor
                                                                        endingColor:bottomColor] autorelease];
        [backgroundGradient drawInBezierPath:buttonPath angle:90.0];
    }
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSRect contentRect = NSInsetRect(buttonRect, 5.0, 5.0);
    NSImage *image = [self image];
    if (image) {
        NSSize imageSize = [image size];
        if (imageSize.width > 0.0 && imageSize.height > 0.0 && !NSIsEmptyRect(contentRect)) {
            CGFloat scale = MIN(NSWidth(contentRect) / imageSize.width,
                                NSHeight(contentRect) / imageSize.height);
            if (scale > 1.0) {
                scale = 1.0;
            }
            NSSize drawSize = NSMakeSize(floor(imageSize.width * scale),
                                         floor(imageSize.height * scale));
            NSRect drawRect = NSMakeRect(NSMidX(contentRect) - floor(drawSize.width / 2.0),
                                         NSMidY(contentRect) - floor(drawSize.height / 2.0),
                                         drawSize.width,
                                         drawSize.height);
            NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:contentRect xRadius:4.0 yRadius:4.0];
            [NSGraphicsContext saveGraphicsState];
            [clipPath addClip];
            [image drawInRect:drawRect
                     fromRect:NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height)
                    operation:NSCompositeSourceOver
                     fraction:alpha
               respectFlipped:YES
                        hints:nil];
            [NSGraphicsContext restoreGraphicsState];
        }
    } else {
        NSString *title = [self title];
        if ([title length] == 0) {
            title = @"?";
        }
        if ([title isEqualToString:@"☺"] || [title isEqualToString:@"stickers"]) {
            NSRect iconRect = NSMakeRect(NSMidX(contentRect) - 12.0,
                                         NSMidY(contentRect) - 12.0,
                                         24.0,
                                         24.0);
            TGDrawTemplateIconAsset(@"emoji-smile",
                                    iconRect,
                                    [NSColor colorWithCalibratedWhite:0.05 alpha:alpha],
                                    1.0,
                                    [controlView isFlipped]);
            return;
        }
        NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [paragraph setAlignment:NSCenterTextAlignment];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:30.0], NSFontAttributeName,
                                    [NSColor colorWithCalibratedWhite:0.05 alpha:alpha], NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
        NSSize titleSize = [title sizeWithAttributes:attributes];
        NSRect titleRect = NSMakeRect(NSMinX(contentRect),
                                      NSMidY(contentRect) - floor(titleSize.height / 2.0) - 1.0,
                                      NSWidth(contentRect),
                                      titleSize.height + 2.0);
        [title drawInRect:titleRect withAttributes:attributes];
    }
}

@end
