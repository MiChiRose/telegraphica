#import "TGIconDrawing.h"
#include <math.h>

static NSPoint TGIconPoint24(NSRect rect, CGFloat x, CGFloat y, BOOL flipped) {
    CGFloat px = NSMinX(rect) + (NSWidth(rect) * (x / 24.0));
    CGFloat py = flipped ? (NSMinY(rect) + (NSHeight(rect) * (y / 24.0)))
                         : (NSMaxY(rect) - (NSHeight(rect) * (y / 24.0)));
    return NSMakePoint(px, py);
}

static NSRect TGIconRect24(NSRect rect, CGFloat x, CGFloat y, CGFloat width, CGFloat height, BOOL flipped) {
    CGFloat rx = NSMinX(rect) + (NSWidth(rect) * (x / 24.0));
    CGFloat rh = NSHeight(rect) * (height / 24.0);
    CGFloat ry = flipped ? (NSMinY(rect) + (NSHeight(rect) * (y / 24.0)))
                         : (NSMaxY(rect) - (NSHeight(rect) * ((y + height) / 24.0)));
    return NSMakeRect(rx, ry, NSWidth(rect) * (width / 24.0), rh);
}

static void TGStrokeIconLine(NSRect rect, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, BOOL flipped, CGFloat width) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:width];
    [path setLineCapStyle:NSRoundLineCapStyle];
    [path moveToPoint:TGIconPoint24(rect, x1, y1, flipped)];
    [path lineToPoint:TGIconPoint24(rect, x2, y2, flipped)];
    [path stroke];
}

void TGDrawChatsIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSBezierPath *backBubble = [NSBezierPath bezierPathWithRoundedRect:TGIconRect24(iconRect, 2.0, 3.0, 19.0, 13.0, flipped)
                                                               xRadius:6.0
                                                               yRadius:6.0];
    [backBubble setLineWidth:2.0];
    [backBubble stroke];

    NSBezierPath *backTail = [NSBezierPath bezierPath];
    [backTail setLineWidth:2.0];
    [backTail setLineJoinStyle:NSRoundLineJoinStyle];
    [backTail moveToPoint:TGIconPoint24(iconRect, 7.6, 15.2, flipped)];
    [backTail curveToPoint:TGIconPoint24(iconRect, 3.0, 21.0, flipped)
             controlPoint1:TGIconPoint24(iconRect, 6.9, 18.0, flipped)
             controlPoint2:TGIconPoint24(iconRect, 5.6, 19.8, flipped)];
    [backTail curveToPoint:TGIconPoint24(iconRect, 8.6, 18.0, flipped)
             controlPoint1:TGIconPoint24(iconRect, 5.3, 21.0, flipped)
             controlPoint2:TGIconPoint24(iconRect, 7.0, 19.8, flipped)];
    [backTail stroke];

    NSBezierPath *frontBubble = [NSBezierPath bezierPathWithRoundedRect:TGIconRect24(iconRect, 9.0, 10.5, 13.0, 9.0, flipped)
                                                                xRadius:4.5
                                                                yRadius:4.5];
    [frontBubble fill];

    NSBezierPath *frontTail = [NSBezierPath bezierPath];
    [frontTail moveToPoint:TGIconPoint24(iconRect, 18.0, 18.2, flipped)];
    [frontTail curveToPoint:TGIconPoint24(iconRect, 22.0, 21.0, flipped)
              controlPoint1:TGIconPoint24(iconRect, 19.1, 19.6, flipped)
              controlPoint2:TGIconPoint24(iconRect, 20.3, 20.5, flipped)];
    [frontTail curveToPoint:TGIconPoint24(iconRect, 17.6, 19.5, flipped)
              controlPoint1:TGIconPoint24(iconRect, 20.1, 21.0, flipped)
              controlPoint2:TGIconPoint24(iconRect, 18.8, 20.4, flipped)];
    [frontTail closePath];
    [frontTail fill];
}

void TGDrawMicrophoneIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSBezierPath *mic = [NSBezierPath bezierPathWithRoundedRect:TGIconRect24(iconRect, 8.7, 2.2, 6.6, 12.7, flipped)
                                                        xRadius:(NSWidth(iconRect) * 3.3 / 24.0)
                                                        yRadius:(NSWidth(iconRect) * 3.3 / 24.0)];
    [mic setLineWidth:2.0];
    [mic stroke];

    NSBezierPath *standPath = [NSBezierPath bezierPath];
    [standPath setLineWidth:2.0];
    [standPath setLineCapStyle:NSRoundLineCapStyle];
    [standPath moveToPoint:TGIconPoint24(iconRect, 5.0, 10.0, flipped)];
    [standPath curveToPoint:TGIconPoint24(iconRect, 12.0, 19.0, flipped)
              controlPoint1:TGIconPoint24(iconRect, 5.0, 15.0, flipped)
              controlPoint2:TGIconPoint24(iconRect, 8.2, 19.0, flipped)];
    [standPath curveToPoint:TGIconPoint24(iconRect, 19.0, 10.0, flipped)
              controlPoint1:TGIconPoint24(iconRect, 15.8, 19.0, flipped)
              controlPoint2:TGIconPoint24(iconRect, 19.0, 15.0, flipped)];
    [standPath stroke];

    TGStrokeIconLine(iconRect, 12.0, 19.0, 12.0, 22.0, flipped, 2.0);
    TGStrokeIconLine(iconRect, 8.0, 22.0, 16.0, 22.0, flipped, 2.0);
}

void TGDrawPinIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSBezierPath *head = [NSBezierPath bezierPathWithRoundedRect:TGIconRect24(iconRect, 7.0, 3.0, 10.0, 4.8, flipped)
                                                         xRadius:1.8
                                                         yRadius:1.8];
    [head fill];

    NSBezierPath *body = [NSBezierPath bezierPath];
    [body setLineJoinStyle:NSRoundLineJoinStyle];
    [body moveToPoint:TGIconPoint24(iconRect, 9.2, 7.1, flipped)];
    [body lineToPoint:TGIconPoint24(iconRect, 14.8, 7.1, flipped)];
    [body lineToPoint:TGIconPoint24(iconRect, 16.4, 13.8, flipped)];
    [body lineToPoint:TGIconPoint24(iconRect, 7.6, 13.8, flipped)];
    [body closePath];
    [body fill];

    TGStrokeIconLine(iconRect, 12.0, 13.0, 12.0, 21.0, flipped, 2.0);
    TGStrokeIconLine(iconRect, 8.7, 21.0, 15.3, 21.0, flipped, 2.0);
}

void TGDrawReloadIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSPoint center = TGIconPoint24(iconRect, 12.0, 12.0, flipped);
    CGFloat radius = MIN(NSWidth(iconRect), NSHeight(iconRect)) * 0.34;
    NSBezierPath *arc = [NSBezierPath bezierPath];
    [arc appendBezierPathWithArcWithCenter:center
                                    radius:radius
                                startAngle:(flipped ? 38.0 : -38.0)
                                  endAngle:(flipped ? 318.0 : -318.0)
                                 clockwise:flipped];
    [arc setLineWidth:2.2];
    [arc setLineCapStyle:NSRoundLineCapStyle];
    [arc stroke];

    NSBezierPath *arrow = [NSBezierPath bezierPath];
    [arrow setLineJoinStyle:NSRoundLineJoinStyle];
    [arrow moveToPoint:TGIconPoint24(iconRect, 18.1, 6.0, flipped)];
    [arrow lineToPoint:TGIconPoint24(iconRect, 21.0, 6.0, flipped)];
    [arrow lineToPoint:TGIconPoint24(iconRect, 21.0, 3.0, flipped)];
    [arrow closePath];
    [arrow fill];
}

void TGDrawSettingsIconInRect(NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    NSPoint center = TGIconPoint24(iconRect, 12.0, 12.0, flipped);
    CGFloat outerRadius = MIN(NSWidth(iconRect), NSHeight(iconRect)) * 0.36;
    CGFloat innerRadius = MIN(NSWidth(iconRect), NSHeight(iconRect)) * 0.18;
    NSInteger tooth = 0;
    for (tooth = 0; tooth < 8; tooth++) {
        CGFloat angle = ((CGFloat)tooth / 8.0) * 2.0 * (CGFloat)M_PI;
        CGFloat x1 = center.x + cos(angle) * (outerRadius * 0.82);
        CGFloat y1 = center.y + sin(angle) * (outerRadius * 0.82);
        CGFloat x2 = center.x + cos(angle) * (outerRadius * 1.12);
        CGFloat y2 = center.y + sin(angle) * (outerRadius * 1.12);
        NSBezierPath *toothPath = [NSBezierPath bezierPath];
        [toothPath setLineWidth:2.2];
        [toothPath setLineCapStyle:NSRoundLineCapStyle];
        [toothPath moveToPoint:NSMakePoint(x1, y1)];
        [toothPath lineToPoint:NSMakePoint(x2, y2)];
        [toothPath stroke];
    }

    NSBezierPath *outer = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - outerRadius,
                                                                            center.y - outerRadius,
                                                                            outerRadius * 2.0,
                                                                            outerRadius * 2.0)];
    [outer setLineWidth:2.0];
    [outer stroke];

    NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - innerRadius,
                                                                            center.y - innerRadius,
                                                                            innerRadius * 2.0,
                                                                            innerRadius * 2.0)];
    [inner setLineWidth:2.0];
    [inner stroke];
}

