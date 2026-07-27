#import "TGLocationStaticMapView.h"

#include <math.h>

@interface TGLocationStaticMapView ()
@property (nonatomic, assign) NSPoint previewOffset;
@property (nonatomic, assign) NSInteger requestedZoom;
@property (nonatomic, assign) CGFloat magnificationAccumulator;
@end

@implementation TGLocationStaticMapView

@synthesize coordinateTarget = _coordinateTarget;
@synthesize coordinateAction = _coordinateAction;
@synthesize centerLatitude = _centerLatitude;
@synthesize centerLongitude = _centerLongitude;
@synthesize zoom = _zoom;
@synthesize previewOffset = _previewOffset;
@synthesize requestedZoom = _requestedZoom;
@synthesize magnificationAccumulator = _magnificationAccumulator;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _zoom = 15;
        _requestedZoom = 15;
        [self setImageFrameStyle:NSImageFrameNone];
        [self setImageScaling:NSImageScaleAxesIndependently];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)setZoom:(NSInteger)zoom {
    _zoom = MAX(13, MIN(18, zoom));
    _requestedZoom = _zoom;
}

- (void)resetCursorRects {
    [self addCursorRect:[self bounds] cursor:[NSCursor openHandCursor]];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithCalibratedWhite:0.94 alpha:1.0] setFill];
    NSRectFill([self bounds]);
    NSImage *image = [self image];
    if (image) {
        NSRect targetRect = NSOffsetRect([self bounds], self.previewOffset.x, self.previewOffset.y);
        [image drawInRect:targetRect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0];
    }
}

- (CLLocationCoordinate2D)coordinateForPoint:(NSPoint)point {
    point.x -= self.previewOffset.x;
    point.y -= self.previewOffset.y;
    CGFloat worldSize = 256.0 * pow(2.0, (double)self.zoom);
    double centerX = (self.centerLongitude + 180.0) / 360.0 * worldSize;
    double sinLatitude = sin(self.centerLatitude * M_PI / 180.0);
    sinLatitude = MAX(-0.9999, MIN(0.9999, sinLatitude));
    double centerY = (0.5 - log((1.0 + sinLatitude) / (1.0 - sinLatitude)) / (4.0 * M_PI)) * worldSize;
    double pixelX = centerX + point.x - NSMidX([self bounds]);
    double pixelY = centerY + NSMidY([self bounds]) - point.y;
    double longitude = pixelX / worldSize * 360.0 - 180.0;
    double mercator = M_PI - 2.0 * M_PI * pixelY / worldSize;
    double latitude = 180.0 / M_PI * atan(0.5 * (exp(mercator) - exp(-mercator)));
    longitude = fmod(longitude + 540.0, 360.0) - 180.0;
    latitude = MAX(-85.0, MIN(85.0, latitude));
    return CLLocationCoordinate2DMake(latitude, longitude);
}

- (void)notifyCoordinate:(CLLocationCoordinate2D)coordinate zoom:(NSInteger)zoom {
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithDouble:coordinate.latitude], @"latitude",
                             [NSNumber numberWithDouble:coordinate.longitude], @"longitude",
                             [NSNumber numberWithInteger:MAX(13, MIN(18, zoom))], @"zoom",
                             nil];
    if (self.coordinateTarget && self.coordinateAction &&
        [self.coordinateTarget respondsToSelector:self.coordinateAction]) {
        [self.coordinateTarget performSelector:self.coordinateAction withObject:payload];
    }
}

- (void)commitPreviewPan {
    NSPoint centerPoint = NSMakePoint(NSMidX([self bounds]), NSMidY([self bounds]));
    [self notifyCoordinate:[self coordinateForPoint:centerPoint] zoom:self.requestedZoom];
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint startPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint lastPoint = startPoint;
    BOOL dragged = NO;
    [[NSCursor closedHandCursor] push];
    while (YES) {
        NSEvent *nextEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        if ([nextEvent type] == NSLeftMouseDragged) {
            NSPoint currentPoint = [self convertPoint:[nextEvent locationInWindow] fromView:nil];
            CGFloat dx = currentPoint.x - lastPoint.x;
            CGFloat dy = currentPoint.y - lastPoint.y;
            if (fabs(currentPoint.x - startPoint.x) > 2.0 || fabs(currentPoint.y - startPoint.y) > 2.0) {
                dragged = YES;
            }
            self.previewOffset = NSMakePoint(self.previewOffset.x + dx, self.previewOffset.y + dy);
            lastPoint = currentPoint;
            [self setNeedsDisplay:YES];
            continue;
        }
        if ([nextEvent type] == NSLeftMouseUp) {
            break;
        }
    }
    [NSCursor pop];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(commitPreviewPan) object:nil];
    if (dragged) {
        [self commitPreviewPan];
    } else {
        [self notifyCoordinate:[self coordinateForPoint:startPoint] zoom:self.requestedZoom];
    }
}

- (void)scrollWheel:(NSEvent *)event {
    if ([event hasPreciseScrollingDeltas]) {
        self.previewOffset = NSMakePoint(self.previewOffset.x + [event scrollingDeltaX],
                                         self.previewOffset.y + [event scrollingDeltaY]);
        [self setNeedsDisplay:YES];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(commitPreviewPan) object:nil];
        [self performSelector:@selector(commitPreviewPan) withObject:nil afterDelay:0.18];
        return;
    }
    CGFloat delta = [event deltaY];
    if (fabs(delta) < 0.01) {
        delta = [event deltaX];
    }
    if (fabs(delta) >= 0.01) {
        [self requestZoomDelta:(delta > 0.0 ? 1 : -1)];
    }
}

- (void)magnifyWithEvent:(NSEvent *)event {
    self.magnificationAccumulator += [event magnification];
    if (self.magnificationAccumulator >= 0.12) {
        self.magnificationAccumulator = 0.0;
        [self requestZoomDelta:1];
    } else if (self.magnificationAccumulator <= -0.12) {
        self.magnificationAccumulator = 0.0;
        [self requestZoomDelta:-1];
    }
}

- (void)requestZoomDelta:(NSInteger)delta {
    NSInteger targetZoom = MAX(13, MIN(18, self.requestedZoom + delta));
    if (targetZoom == self.requestedZoom) {
        NSBeep();
        return;
    }
    self.requestedZoom = targetZoom;
    NSPoint centerPoint = NSMakePoint(NSMidX([self bounds]), NSMidY([self bounds]));
    [self notifyCoordinate:[self coordinateForPoint:centerPoint] zoom:targetZoom];
}

- (void)setMapImage:(NSImage *)image
     centerLatitude:(double)latitude
          longitude:(double)longitude
               zoom:(NSInteger)zoom {
    self.centerLatitude = latitude;
    self.centerLongitude = longitude;
    self.zoom = zoom;
    self.previewOffset = NSZeroPoint;
    [self setImage:image];
    [self setNeedsDisplay:YES];
}

@end
