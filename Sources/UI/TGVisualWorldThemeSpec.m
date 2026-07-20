#import "TGVisualWorldThemeSpec.h"
#import "TGTheme.h"

@implementation TGVisualWorldThemeSpec

- (void)dealloc {
    [_identifier release];
    [_displayName release];
    [_themeDescription release];
    [super dealloc];
}

@end

static TGVisualWorldThemeSpec *TGVisualWorldMakeSpec(NSString *identifier,
                                                     NSString *displayName,
                                                     NSString *themeDescription,
                                                     NSUInteger backgroundHex,
                                                     NSUInteger panelHex,
                                                     NSUInteger surfaceHex,
                                                     NSUInteger incomingHex,
                                                     NSUInteger outgoingHex,
                                                     NSUInteger primaryHex,
                                                     NSUInteger secondaryHex,
                                                     NSUInteger textHex,
                                                     NSUInteger mutedHex,
                                                     NSUInteger borderHex,
                                                     NSUInteger warmHex,
                                                     TGVisualWorldDecorationMode decorationMode,
                                                     BOOL darkCards) {
    TGVisualWorldThemeSpec *spec = [[[TGVisualWorldThemeSpec alloc] init] autorelease];
    spec.identifier = identifier;
    spec.displayName = displayName;
    spec.themeDescription = themeDescription;
    spec.backgroundHex = backgroundHex;
    spec.panelHex = panelHex;
    spec.surfaceHex = surfaceHex;
    spec.incomingHex = incomingHex;
    spec.outgoingHex = outgoingHex;
    spec.primaryHex = primaryHex;
    spec.secondaryHex = secondaryHex;
    spec.textHex = textHex;
    spec.mutedHex = mutedHex;
    spec.borderHex = borderHex;
    spec.warmHex = warmHex;
    spec.decorationMode = decorationMode;
    spec.darkCards = darkCards;
    return spec;
}

static NSArray *TGVisualWorldSpecs(void) {
    static NSArray *specs = nil;
    if (specs) {
        return specs;
    }
    specs = [[NSArray alloc] initWithObjects:
             TGVisualWorldMakeSpec(@"visual-macintosh-desktop", @"Macintosh Desktop", @"Grey-blue desktop plastic, fine bevels, and quiet early-Mac texture.", 0xD7DBE0, 0xE7EAED, 0xF5F6F7, 0xFFFFFF, 0xDCEAF7, 0x356B9E, 0x7E9BB8, 0x20262D, 0x6D7780, 0xAAB4BE, 0x7E9BB8, TGVisualWorldDecorationMacintoshDesktop, NO),
             TGVisualWorldMakeSpec(@"visual-blueprint", @"Blueprint", @"Technical blue paper with precise grid lines, arcs, and drafting marks.", 0x153A61, 0x1C4A73, 0xE8F0F6, 0xF5FAFD, 0xCFE4F1, 0x2D80C4, 0x7EA6C1, 0x12283C, 0x6D8799, 0x8EB3CC, 0xD88A3B, TGVisualWorldDecorationBlueprint, NO),
             TGVisualWorldMakeSpec(@"visual-notebook", @"Notebook", @"Warm ruled paper with subtle fibers and a calm note-taking mood.", 0xEFE3C5, 0xF5EBD6, 0xFFFDF5, 0xFFFDF4, 0xE4F0E5, 0x356D91, 0x6C8C9B, 0x263746, 0x7C7A70, 0xC8D1D4, 0xB35B52, TGVisualWorldDecorationNotebook, NO),
             TGVisualWorldMakeSpec(@"visual-crt-terminal", @"CRT Terminal", @"Dark phosphor glass with scanlines, tiny static, and readable green text.", 0x0B1512, 0x102019, 0x142A20, 0x10251C, 0x173825, 0x67D391, 0xA8D9A0, 0xC7EAC2, 0x71967A, 0x2E6A3F, 0xE1B866, TGVisualWorldDecorationCRTTerminal, YES),
             TGVisualWorldMakeSpec(@"visual-newspaper", @"Newspaper", @"Aged paper, soft ink, fine fibers, and modest halftone texture.", 0xD5CBB7, 0xE4D8C2, 0xF4EEDC, 0xFBF6E8, 0xE6E0D1, 0x8B3F32, 0x6E756E, 0x2C2A27, 0x777064, 0xB6AA91, 0x8B3F32, TGVisualWorldDecorationNewspaper, NO),
             TGVisualWorldMakeSpec(@"visual-old-computer", @"Old Computer", @"Light 90s plastic, pixel seams, 1px bevels, and hardware-console restraint.", 0x8A9AAF, 0xC4C7C9, 0xD9D9D7, 0xF1F1ED, 0xC7DDE1, 0x24558E, 0x4D7C88, 0x1E2933, 0x60666B, 0x7D858B, 0xA66A28, TGVisualWorldDecorationOldComputer, NO),
             TGVisualWorldMakeSpec(@"visual-greenhouse", @"Greenhouse", @"Soft leaf-line motifs, pale botanical surfaces, and fresh green controls.", 0xC7DDBA, 0xDCEBD2, 0xF6FAEF, 0xFFFFFF, 0xE0F0D9, 0x4D8D61, 0x79A97A, 0x294239, 0x718276, 0x9CB797, 0xC28A4B, TGVisualWorldDecorationGreenhouse, NO),
             TGVisualWorldMakeSpec(@"visual-space-terminal", @"Space Terminal", @"A dark navigation console with star-map points and orbital guide lines.", 0x0F1A2D, 0x18283E, 0x20354D, 0x1B3147, 0x244B62, 0x4BB5D6, 0x78C7D7, 0xEAF6FF, 0x8BA9BA, 0x3F5F78, 0xE1B56C, TGVisualWorldDecorationSpaceTerminal, YES),
             TGVisualWorldMakeSpec(@"visual-vinyl-studio", @"Vinyl Studio", @"Warm studio browns, faint record grooves, and amber mixer lights.", 0x25211D, 0x332C25, 0x40372E, 0x4A4035, 0x5B4433, 0xD17B45, 0xB78A5E, 0xFFF5E5, 0xB9A58D, 0x725944, 0xF0D9B5, TGVisualWorldDecorationVinylStudio, YES),
             TGVisualWorldMakeSpec(@"visual-postcard", @"Postcard", @"Soft travel-card paper with route curves, contour hints, and stamp-like accents.", 0xD5E1E2, 0xE4ECEB, 0xFFF8E7, 0xFFFDF2, 0xE2F0F0, 0x2F78A5, 0x6A9CA6, 0x2E3D44, 0x718088, 0xB9C5C2, 0xD36C58, TGVisualWorldDecorationPostcard, NO),
             nil];
    return specs;
}

NSArray *TGVisualWorldThemeIdentifiers(void) {
    NSMutableArray *identifiers = [NSMutableArray array];
    NSArray *specs = TGVisualWorldSpecs();
    NSUInteger index = 0;
    for (index = 0; index < [specs count]; index++) {
        [identifiers addObject:[[specs objectAtIndex:index] identifier]];
    }
    return identifiers;
}

TGVisualWorldThemeSpec *TGVisualWorldThemeSpecForIdentifier(NSString *identifier) {
    if (![identifier isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSArray *specs = TGVisualWorldSpecs();
    NSUInteger index = 0;
    for (index = 0; index < [specs count]; index++) {
        TGVisualWorldThemeSpec *spec = [specs objectAtIndex:index];
        if ([spec.identifier isEqualToString:identifier]) {
            return spec;
        }
    }
    return nil;
}

BOOL TGVisualWorldThemeIdentifierIsValid(NSString *identifier) {
    return TGVisualWorldThemeSpecForIdentifier(identifier) != nil;
}

static void TGVisualWorldDrawDot(CGFloat x, CGFloat y, CGFloat size, NSColor *color) {
    [color set];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, y, size, size)] fill];
}

static NSImage *TGVisualWorldPatternImageForMode(TGVisualWorldDecorationMode mode) {
    static NSImage *images[11] = { nil };
    NSUInteger slotIndex = (NSUInteger)mode;
    if (slotIndex >= 11) {
        slotIndex = 1;
    }
    if (images[slotIndex]) {
        return images[slotIndex];
    }

    CGFloat tileSize = 128.0;
    if (mode == TGVisualWorldDecorationBlueprint || mode == TGVisualWorldDecorationSpaceTerminal) {
        tileSize = 160.0;
    } else if (mode == TGVisualWorldDecorationCRTTerminal || mode == TGVisualWorldDecorationNotebook) {
        tileSize = 96.0;
    }

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(tileSize, tileSize)];
    [image lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0.0, 0.0, tileSize, tileSize));

    if (mode == TGVisualWorldDecorationMacintoshDesktop) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.070] set];
        NSRectFill(NSMakeRect(0.0, 22.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 74.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.035] set];
        NSRectFill(NSMakeRect(18.0, 0.0, 1.0, tileSize));
        NSRectFill(NSMakeRect(92.0, 0.0, 1.0, tileSize));
        NSBezierPath *diagonal = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.040] set];
        [diagonal setLineWidth:1.0];
        [diagonal moveToPoint:NSMakePoint(-10.0, 118.0)];
        [diagonal lineToPoint:NSMakePoint(118.0, -10.0)];
        [diagonal moveToPoint:NSMakePoint(36.0, 138.0)];
        [diagonal lineToPoint:NSMakePoint(138.0, 36.0)];
        [diagonal stroke];
    } else if (mode == TGVisualWorldDecorationBlueprint) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.070] set];
        NSUInteger line = 0;
        for (line = 0; line <= 160; line += 20) {
            NSRectFill(NSMakeRect((CGFloat)line, 0.0, 1.0, tileSize));
            NSRectFill(NSMakeRect(0.0, (CGFloat)line, tileSize, 1.0));
        }
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.035] set];
        for (line = 10; line <= 160; line += 20) {
            NSRectFill(NSMakeRect((CGFloat)line, 0.0, 1.0, tileSize));
            NSRectFill(NSMakeRect(0.0, (CGFloat)line, tileSize, 1.0));
        }
        NSBezierPath *arc = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.090] set];
        [arc setLineWidth:1.0];
        [arc appendBezierPathWithArcWithCenter:NSMakePoint(64.0, 64.0) radius:42.0 startAngle:18.0 endAngle:280.0];
        [arc moveToPoint:NSMakePoint(20.0, 94.0)];
        [arc lineToPoint:NSMakePoint(132.0, 18.0)];
        [arc stroke];
    } else if (mode == TGVisualWorldDecorationNotebook) {
        [[NSColor colorWithCalibratedRed:0.43 green:0.55 blue:0.67 alpha:0.120] set];
        NSUInteger y = 15;
        for (y = 15; y < 96; y += 24) {
            NSRectFill(NSMakeRect(0.0, (CGFloat)y, tileSize, 1.0));
        }
        [[NSColor colorWithCalibratedRed:0.78 green:0.32 blue:0.30 alpha:0.075] set];
        NSRectFill(NSMakeRect(20.0, 0.0, 1.0, tileSize));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.022] set];
        TGVisualWorldDrawDot(8.0, 8.0, 1.0, [NSColor colorWithCalibratedWhite:0.0 alpha:0.026]);
        TGVisualWorldDrawDot(53.0, 42.0, 1.0, [NSColor colorWithCalibratedWhite:0.0 alpha:0.026]);
    } else if (mode == TGVisualWorldDecorationCRTTerminal) {
        [[NSColor colorWithCalibratedRed:0.25 green:1.0 blue:0.46 alpha:0.055] set];
        NSUInteger y = 0;
        for (y = 0; y < 96; y += 4) {
            NSRectFill(NSMakeRect(0.0, (CGFloat)y, tileSize, 1.0));
        }
        NSUInteger dot = 0;
        for (dot = 0; dot < 34; dot++) {
            CGFloat x = (CGFloat)((dot * 29) % 94);
            CGFloat py = (CGFloat)((dot * 47) % 94);
            TGVisualWorldDrawDot(x, py, 1.0, [NSColor colorWithCalibratedRed:0.55 green:1.0 blue:0.60 alpha:0.050]);
        }
    } else if (mode == TGVisualWorldDecorationNewspaper) {
        NSUInteger dot = 0;
        for (dot = 0; dot < 80; dot++) {
            CGFloat x = (CGFloat)((dot * 17) % 124);
            CGFloat y = (CGFloat)((dot * 31) % 124);
            CGFloat alpha = 0.018 + (CGFloat)(dot % 3) * 0.006;
            TGVisualWorldDrawDot(x, y, 1.0, [NSColor colorWithCalibratedWhite:0.0 alpha:alpha]);
        }
        [[NSColor colorWithCalibratedRed:0.22 green:0.20 blue:0.18 alpha:0.040] set];
        NSBezierPath *halftone = [NSBezierPath bezierPath];
        [halftone setLineWidth:1.0];
        [halftone moveToPoint:NSMakePoint(-8.0, 34.0)];
        [halftone curveToPoint:NSMakePoint(132.0, 86.0)
                 controlPoint1:NSMakePoint(30.0, 10.0)
                 controlPoint2:NSMakePoint(92.0, 118.0)];
        [halftone stroke];
    } else if (mode == TGVisualWorldDecorationOldComputer) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.060] set];
        NSRectFill(NSMakeRect(0.0, 0.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 32.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 64.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 96.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.040] set];
        NSRectFill(NSMakeRect(31.0, 0.0, 1.0, tileSize));
        NSRectFill(NSMakeRect(95.0, 0.0, 1.0, tileSize));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.050] set];
        NSFrameRect(NSMakeRect(12.0, 13.0, 32.0, 21.0));
        NSFrameRect(NSMakeRect(70.0, 70.0, 38.0, 24.0));
    } else if (mode == TGVisualWorldDecorationGreenhouse) {
        NSBezierPath *leaf = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedRed:0.15 green:0.43 blue:0.22 alpha:0.070] set];
        [leaf setLineWidth:1.0];
        [leaf moveToPoint:NSMakePoint(14.0, 22.0)];
        [leaf curveToPoint:NSMakePoint(46.0, 74.0)
             controlPoint1:NSMakePoint(28.0, 28.0)
             controlPoint2:NSMakePoint(52.0, 42.0)];
        [leaf moveToPoint:NSMakePoint(82.0, 108.0)];
        [leaf curveToPoint:NSMakePoint(118.0, 48.0)
             controlPoint1:NSMakePoint(111.0, 92.0)
             controlPoint2:NSMakePoint(96.0, 62.0)];
        [leaf stroke];
        TGVisualWorldDrawDot(18.0, 86.0, 7.0, [NSColor colorWithCalibratedRed:0.48 green:0.78 blue:0.38 alpha:0.060]);
        TGVisualWorldDrawDot(88.0, 20.0, 5.0, [NSColor colorWithCalibratedRed:0.48 green:0.78 blue:0.38 alpha:0.052]);
    } else if (mode == TGVisualWorldDecorationSpaceTerminal) {
        NSUInteger dot = 0;
        for (dot = 0; dot < 44; dot++) {
            CGFloat x = (CGFloat)((dot * 37) % 157);
            CGFloat y = (CGFloat)((dot * 61) % 157);
            TGVisualWorldDrawDot(x, y, (dot % 5 == 0) ? 2.0 : 1.0, [NSColor colorWithCalibratedRed:0.70 green:0.90 blue:1.0 alpha:0.080]);
        }
        [[NSColor colorWithCalibratedRed:0.40 green:0.80 blue:1.0 alpha:0.070] set];
        NSBezierPath *orbit = [NSBezierPath bezierPath];
        [orbit setLineWidth:1.0];
        [orbit appendBezierPathWithArcWithCenter:NSMakePoint(90.0, 58.0) radius:54.0 startAngle:210.0 endAngle:35.0];
        [orbit appendBezierPathWithArcWithCenter:NSMakePoint(42.0, 96.0) radius:25.0 startAngle:18.0 endAngle:350.0];
        [orbit stroke];
    } else if (mode == TGVisualWorldDecorationVinylStudio) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.045] set];
        NSBezierPath *grooves = [NSBezierPath bezierPath];
        [grooves setLineWidth:1.0];
        NSUInteger radius = 16;
        for (radius = 16; radius < 78; radius += 12) {
            [grooves appendBezierPathWithOvalInRect:NSMakeRect(64.0 - radius, 64.0 - radius, radius * 2.0, radius * 2.0)];
        }
        [grooves stroke];
        [[NSColor colorWithCalibratedRed:1.0 green:0.47 blue:0.18 alpha:0.080] set];
        NSRectFill(NSMakeRect(0.0, 30.0, tileSize, 2.0));
        NSRectFill(NSMakeRect(82.0, 0.0, 2.0, tileSize));
    } else if (mode == TGVisualWorldDecorationPostcard) {
        [[NSColor colorWithCalibratedRed:0.22 green:0.49 blue:0.61 alpha:0.060] set];
        NSBezierPath *route = [NSBezierPath bezierPath];
        [route setLineWidth:1.0];
        [route moveToPoint:NSMakePoint(-4.0, 28.0)];
        [route curveToPoint:NSMakePoint(132.0, 70.0)
              controlPoint1:NSMakePoint(34.0, 74.0)
              controlPoint2:NSMakePoint(78.0, 12.0)];
        [route moveToPoint:NSMakePoint(18.0, 106.0)];
        [route curveToPoint:NSMakePoint(122.0, 104.0)
              controlPoint1:NSMakePoint(44.0, 88.0)
              controlPoint2:NSMakePoint(86.0, 124.0)];
        [route stroke];
        [[NSColor colorWithCalibratedRed:0.83 green:0.36 blue:0.30 alpha:0.050] set];
        NSFrameRect(NSMakeRect(88.0, 18.0, 22.0, 16.0));
    }

    [image unlockFocus];
    images[slotIndex] = image;
    return images[slotIndex];
}

static void TGVisualWorldFillPattern(TGVisualWorldDecorationMode mode, NSRect rect) {
    NSColor *patternColor = [NSColor colorWithPatternImage:TGVisualWorldPatternImageForMode(mode)];
    [patternColor set];
    NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}

void TGVisualWorldDrawWindowBackground(NSString *identifier, NSRect rect) {
    TGVisualWorldThemeSpec *spec = TGVisualWorldThemeSpecForIdentifier(identifier);
    if (!spec) {
        spec = TGVisualWorldThemeSpecForIdentifier(@"visual-macintosh-desktop");
    }
    NSColor *top = TGColorFromHex(spec.backgroundHex);
    NSColor *bottom = TGColorFromHex(spec.panelHex);
    if (spec.darkCards) {
        top = TGColorFromHex(spec.panelHex);
        bottom = TGColorFromHex(spec.backgroundHex);
    }
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
    [gradient drawInRect:rect angle:90.0];
    TGVisualWorldFillPattern(spec.decorationMode, rect);
}

void TGVisualWorldDrawSurfacePattern(NSString *identifier, NSRect rect, CGFloat alpha) {
    TGVisualWorldThemeSpec *spec = TGVisualWorldThemeSpecForIdentifier(identifier);
    if (!spec || alpha <= 0.0) {
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetAlpha(context, alpha);
    TGVisualWorldFillPattern(spec.decorationMode, rect);
    [NSGraphicsContext restoreGraphicsState];
}
