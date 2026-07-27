#import "TGRetroDisplayView.h"
#import "TGRetroLibretroAPI.h"

static BOOL TGRetroPathHasSupportedExtension(NSString *path) {
    NSString *extension = [[path pathExtension] lowercaseString];
    return [extension isEqualToString:@"nes"] ||
           [extension isEqualToString:@"md"] ||
           [extension isEqualToString:@"smd"] ||
           [extension isEqualToString:@"gen"] ||
           [extension isEqualToString:@"bin"] ||
           [extension isEqualToString:@"sms"] ||
           [extension isEqualToString:@"gg"] ||
           [extension isEqualToString:@"sg"];
}

static NSInteger TGRetroButtonForKeyCode(unsigned short keyCode) {
    switch (keyCode) {
        case 126: return TGRetroAPIJoypadUp;
        case 125: return TGRetroAPIJoypadDown;
        case 123: return TGRetroAPIJoypadLeft;
        case 124: return TGRetroAPIJoypadRight;
        case 6: return TGRetroAPIJoypadB;       // Z
        case 7: return TGRetroAPIJoypadA;       // X
        case 0: return TGRetroAPIJoypadY;       // A
        case 1: return TGRetroAPIJoypadX;       // S
        case 36: return TGRetroAPIJoypadStart;  // Return
        case 56:
        case 60: return TGRetroAPIJoypadSelect; // Shift
        default: return -1;
    }
}

@implementation TGRetroDisplayView

@synthesize delegate = _delegate;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)updateFrameData:(NSData *)data width:(NSUInteger)width height:(NSUInteger)height {
    if (!data || width == 0 || height == 0) return;
    [_frameData release];
    _frameData = [data copy];
    _frameWidth = width;
    _frameHeight = height;
    [self setNeedsDisplay:YES];
}

- (void)clearFrame {
    [_frameData release];
    _frameData = nil;
    _frameWidth = 0;
    _frameHeight = 0;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [[NSColor colorWithCalibratedWhite:0.035 alpha:1.0] set];
    NSRectFill(bounds);

    if (_frameData && _frameWidth > 0 && _frameHeight > 0) {
        CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)_frameData);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef image = CGImageCreate(_frameWidth,
                                         _frameHeight,
                                         8,
                                         32,
                                         _frameWidth * 4,
                                         colorSpace,
                                         kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
                                         provider,
                                         NULL,
                                         false,
                                         kCGRenderingIntentDefault);
        if (image) {
            CGFloat sourceRatio = (CGFloat)_frameWidth / (CGFloat)_frameHeight;
            CGFloat availableRatio = NSWidth(bounds) / MAX(1.0, NSHeight(bounds));
            NSRect target = bounds;
            if (availableRatio > sourceRatio) {
                target.size.width = floor(NSHeight(bounds) * sourceRatio);
                target.origin.x = floor((NSWidth(bounds) - NSWidth(target)) / 2.0);
            } else {
                target.size.height = floor(NSWidth(bounds) / sourceRatio);
                target.origin.y = floor((NSHeight(bounds) - NSHeight(target)) / 2.0);
            }
            CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
            CGContextSaveGState(context);
            CGContextSetInterpolationQuality(context, kCGInterpolationNone);
            CGContextTranslateCTM(context, 0.0, NSHeight(bounds));
            CGContextScaleCTM(context, 1.0, -1.0);
            CGRect quartzTarget = CGRectMake(NSMinX(target),
                                             NSHeight(bounds) - NSMaxY(target),
                                             NSWidth(target),
                                             NSHeight(target));
            CGContextDrawImage(context, quartzTarget, image);
            CGContextRestoreGState(context);
            CGImageRelease(image);
        }
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
    }

    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5, 0.5)
                                                           xRadius:8.0
                                                           yRadius:8.0];
    [(_acceptingDrop
       ? [NSColor colorWithCalibratedRed:0.27 green:0.62 blue:0.91 alpha:1.0]
       : [NSColor colorWithCalibratedWhite:0.44 alpha:1.0]) setStroke];
    [border setLineWidth:(_acceptingDrop ? 2.0 : 1.0)];
    [border stroke];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSArray *paths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    NSString *path = [paths count] == 1 ? [paths objectAtIndex:0] : nil;
    _acceptingDrop = TGRetroPathHasSupportedExtension(path);
    [self setNeedsDisplay:YES];
    return _acceptingDrop ? NSDragOperationCopy : NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    (void)sender;
    _acceptingDrop = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSArray *paths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    NSString *path = [paths count] == 1 ? [paths objectAtIndex:0] : nil;
    BOOL accepted = TGRetroPathHasSupportedExtension(path);
    _acceptingDrop = NO;
    [self setNeedsDisplay:YES];
    if (accepted && [_delegate respondsToSelector:@selector(retroDisplayView:didReceiveROMPath:)]) {
        [_delegate retroDisplayView:self didReceiveROMPath:path];
    }
    return accepted;
}

- (void)keyDown:(NSEvent *)event {
    NSInteger button = TGRetroButtonForKeyCode([event keyCode]);
    if (button >= 0) {
        if ([_delegate respondsToSelector:@selector(retroDisplayView:setButton:pressed:)]) {
            [_delegate retroDisplayView:self setButton:(NSUInteger)button pressed:YES];
        }
        return;
    }
    [super keyDown:event];
}

- (void)keyUp:(NSEvent *)event {
    NSInteger button = TGRetroButtonForKeyCode([event keyCode]);
    if (button >= 0) {
        if ([_delegate respondsToSelector:@selector(retroDisplayView:setButton:pressed:)]) {
            [_delegate retroDisplayView:self setButton:(NSUInteger)button pressed:NO];
        }
        return;
    }
    [super keyUp:event];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    [[self window] makeFirstResponder:self];
}

- (void)dealloc {
    [self unregisterDraggedTypes];
    [_frameData release];
    [super dealloc];
}

@end

