#import "TGStatusWindowController.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"
#import <ImageIO/ImageIO.h>

static NSUInteger const TGStatusChatPreviewInitialLimit = 40;
static NSUInteger const TGStatusChatPreviewStep = 40;
static NSUInteger const TGStatusChatPreviewMaximumLimit = 500;
static NSUInteger const TGMessagePreviewInitialLimit = 20;
static NSUInteger const TGMessagePrefillMinimumRows = 20;
static NSUInteger const TGMessagePrefillMaxAttempts = 3;
static CGFloat const TGPanelCornerRadius = 8.0;
static CGFloat const TGPanelHeaderHeight = 40.0;
static CGFloat const TGMessageBubbleMaximumWidth = 500.0;
static CGFloat const TGMessagePhotoMaximumSide = 320.0;
static NSString * const TGSectionChats = @"chats";
static NSString * const TGSectionProfile = @"profile";
static NSString * const TGSectionSettings = @"settings";
static NSString * const TGSectionAbout = @"about";
static NSString * const TGSectionLogs = @"logs";

static NSString * const TGThemeDefaultsKey = @"TelegraphicaThemeIdentifier";
static NSString * const TGThemeIdentifierVKBlue = @"vk-blue";
static NSString * const TGThemeIdentifierCoffee = @"coffee-brass";
static NSString * const TGThemeIdentifierCoralPlum = @"coral-plum";
static NSString * const TGThemeIdentifierIceNavy = @"ice-navy";
static NSString * const TGThemeIdentifierRubyObsidian = @"ruby-obsidian";
static NSString * const TGThemeIdentifierEggshellBurgundy = @"eggshell-burgundy";
static NSString * const TGThemeIdentifierMelonOlive = @"melon-olive";

typedef struct {
    CGFloat red;
    CGFloat green;
    CGFloat blue;
} TGRGBColor;

typedef struct {
    TGRGBColor window;
    TGRGBColor panel;
    TGRGBColor header;
    TGRGBColor tablePaper;
    TGRGBColor ink;
    TGRGBColor mutedInk;
    TGRGBColor railStroke;
    TGRGBColor headerSeparator;
    TGRGBColor panelStroke;
    TGRGBColor navigationSelected;
    TGRGBColor navigationHighlighted;
    TGRGBColor navigationNormal;
    TGRGBColor navigationSelectedStroke;
    TGRGBColor navigationNormalStroke;
    TGRGBColor navigationText;
    TGRGBColor navigationMutedText;
    TGRGBColor selectedRow;
    TGRGBColor selectedRowText;
    TGRGBColor unreadText;
    TGRGBColor outgoingBubble;
    TGRGBColor incomingBubble;
    TGRGBColor outgoingBubbleStroke;
    TGRGBColor incomingBubbleStroke;
    TGRGBColor timeText;
    TGRGBColor tableGrid;
    TGRGBColor tableHeader;
    TGRGBColor link;
} TGThemePalette;

static NSString *TGActiveThemeIdentifier = nil;

static TGRGBColor TGRGBMake(NSUInteger hex) {
    TGRGBColor color;
    color.red = (CGFloat)((hex >> 16) & 0xff) / 255.0;
    color.green = (CGFloat)((hex >> 8) & 0xff) / 255.0;
    color.blue = (CGFloat)(hex & 0xff) / 255.0;
    return color;
}

static NSColor *TGColorFromRGB(TGRGBColor color) {
    return [NSColor colorWithCalibratedRed:color.red green:color.green blue:color.blue alpha:1.0];
}

static NSColor *TGColorFromRGBWithAlpha(TGRGBColor color, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:color.red green:color.green blue:color.blue alpha:alpha];
}

static NSImage *TGImageWithCorrectOrientationFromFile(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return nil;
    }

    NSString *resolvedPath = [path stringByStandardizingPath];
    if (![resolvedPath length]) {
        return nil;
    }

    CGImageSourceRef source = nil;
    CGImageRef imageRef = nil;
    NSDictionary *properties = nil;
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)resolvedPath,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
    if (!fileURL) {
        return nil;
    }
    source = CGImageSourceCreateWithURL(fileURL, NULL);
    CFRelease(fileURL);
    if (!source) {
        return nil;
    }

    properties = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    imageRef = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    if (!imageRef) {
        if (properties) {
            CFRelease(properties);
        }
        CFRelease(source);
        return nil;
    }

    NSUInteger orientation = 1;
    if ([properties isKindOfClass:[NSDictionary class]]) {
        id orientationObject = [properties objectForKey:(NSString *)kCGImagePropertyOrientation];
        if ([orientationObject respondsToSelector:@selector(integerValue)]) {
            NSUInteger value = (NSUInteger)[orientationObject integerValue];
            if (value >= 1 && value <= 8) {
                orientation = value;
            }
        }
    }
    if (properties) {
        CFRelease(properties);
    }

    if (orientation > 1) {
        CGFloat imageWidth = (CGFloat)CGImageGetWidth(imageRef);
        CGFloat imageHeight = (CGFloat)CGImageGetHeight(imageRef);
        NSInteger maxPixelSize = (NSInteger)MAX(imageWidth, imageHeight);
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailFromImageAlways,
                                 (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailWithTransform,
                                 [NSNumber numberWithInteger:maxPixelSize], kCGImageSourceThumbnailMaxPixelSize,
                                 nil];
        CGImageRef transformed = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)options);
        if (transformed) {
            CGImageRelease(imageRef);
            imageRef = transformed;
        }
    }

    if (!imageRef) {
        CFRelease(source);
        return nil;
    }

    NSSize size = NSMakeSize((CGFloat)CGImageGetWidth(imageRef), (CGFloat)CGImageGetHeight(imageRef));
    NSImage *image = [[[NSImage alloc] initWithCGImage:imageRef size:size] autorelease];
    CGImageRelease(imageRef);
    CFRelease(source);
    return image;
}

static NSArray *TGThemeIdentifiers(void) {
    return [NSArray arrayWithObjects:
            TGThemeIdentifierVKBlue,
            TGThemeIdentifierCoffee,
            TGThemeIdentifierCoralPlum,
            TGThemeIdentifierIceNavy,
            TGThemeIdentifierRubyObsidian,
            TGThemeIdentifierEggshellBurgundy,
            TGThemeIdentifierMelonOlive,
            nil];
}

static BOOL TGThemeIdentifierIsValid(NSString *identifier) {
    return (identifier && [TGThemeIdentifiers() containsObject:identifier]);
}

static NSString *TGThemeDisplayNameForIdentifier(NSString *identifier) {
    if ([identifier isEqualToString:TGThemeIdentifierCoffee]) {
        return @"Coffee & Brass";
    }
    if ([identifier isEqualToString:TGThemeIdentifierCoralPlum]) {
        return @"Electric Coral / Deep Plum";
    }
    if ([identifier isEqualToString:TGThemeIdentifierIceNavy]) {
        return @"Ice Blue / Deep Navy";
    }
    if ([identifier isEqualToString:TGThemeIdentifierRubyObsidian]) {
        return @"Neon Ruby / Obsidian";
    }
    if ([identifier isEqualToString:TGThemeIdentifierEggshellBurgundy]) {
        return @"Eggshell Cream / Burgundy";
    }
    if ([identifier isEqualToString:TGThemeIdentifierMelonOlive]) {
        return @"Soft Melon / Olive Slate";
    }
    return @"VK Blue";
}

static TGThemePalette TGThemePaletteMake(NSUInteger window,
                                         NSUInteger panel,
                                         NSUInteger header,
                                         NSUInteger tablePaper,
                                         NSUInteger ink,
                                         NSUInteger mutedInk,
                                         NSUInteger line,
                                         NSUInteger selectedRow,
                                         NSUInteger selectedRowText,
                                         NSUInteger unreadText,
                                         NSUInteger outgoingBubble,
                                         NSUInteger incomingBubble,
                                         NSUInteger outgoingBubbleStroke,
                                         NSUInteger incomingBubbleStroke,
                                         NSUInteger timeText,
                                         NSUInteger tableHeader,
                                         NSUInteger link,
                                         NSUInteger navigationText,
                                         NSUInteger navigationMutedText) {
    TGThemePalette palette;
    palette.window = TGRGBMake(window);
    palette.panel = TGRGBMake(panel);
    palette.header = TGRGBMake(header);
    palette.tablePaper = TGRGBMake(tablePaper);
    palette.ink = TGRGBMake(ink);
    palette.mutedInk = TGRGBMake(mutedInk);
    palette.railStroke = TGRGBMake(line);
    palette.headerSeparator = TGRGBMake(window);
    palette.panelStroke = TGRGBMake(line);
    palette.navigationSelected = TGRGBMake(header);
    palette.navigationHighlighted = TGRGBMake(line);
    palette.navigationNormal = TGRGBMake(window);
    palette.navigationSelectedStroke = TGRGBMake(window);
    palette.navigationNormalStroke = TGRGBMake(line);
    palette.navigationText = TGRGBMake(navigationText);
    palette.navigationMutedText = TGRGBMake(navigationMutedText);
    palette.selectedRow = TGRGBMake(selectedRow);
    palette.selectedRowText = TGRGBMake(selectedRowText);
    palette.unreadText = TGRGBMake(unreadText);
    palette.outgoingBubble = TGRGBMake(outgoingBubble);
    palette.incomingBubble = TGRGBMake(incomingBubble);
    palette.outgoingBubbleStroke = TGRGBMake(outgoingBubbleStroke);
    palette.incomingBubbleStroke = TGRGBMake(incomingBubbleStroke);
    palette.timeText = TGRGBMake(timeText);
    palette.tableGrid = TGRGBMake(line);
    palette.tableHeader = TGRGBMake(tableHeader);
    palette.link = TGRGBMake(link);
    return palette;
}

static TGThemePalette TGThemePaletteForIdentifier(NSString *identifier) {
    if ([identifier isEqualToString:TGThemeIdentifierCoffee]) {
        return TGThemePaletteMake(0x33291f, 0xe7ddc6, 0x6a5437, 0xf5ecd8, 0x21170f, 0x6b563b,
                                  0x92734a, 0xd8bd83, 0x20160e, 0x7a5524, 0xd7b46e, 0xfffbf1,
                                  0x9a7440, 0xc8b899, 0x6c5a44, 0xead8b4, 0x6f4b22, 0xfffbef, 0xf0dcc0);
    }
    if ([identifier isEqualToString:TGThemeIdentifierCoralPlum]) {
        return TGThemePaletteMake(0x22092c, 0xf7e7e5, 0xc94e42, 0xfff7f4, 0x22092c, 0x775060,
                                  0xd38378, 0xf7c0b5, 0x22092c, 0xa23d36, 0xf3aa9e, 0xfffbf8,
                                  0xc46f64, 0xdfc7c0, 0x775060, 0xf4d6d0, 0x9d392f, 0xfff7f0, 0xf8d9d2);
    }
    if ([identifier isEqualToString:TGThemeIdentifierIceNavy]) {
        return TGThemePaletteMake(0x141a29, 0xeef4ff, 0x536e99, 0xf9fbff, 0x141a29, 0x536176,
                                  0x9aabc4, 0xd6e4ff, 0x141a29, 0x355780, 0xd6e4ff, 0xffffff,
                                  0x7895c1, 0xc6d1e2, 0x526174, 0xdfe9fb, 0x315f96, 0xf7fbff, 0xdce8ff);
    }
    if ([identifier isEqualToString:TGThemeIdentifierRubyObsidian]) {
        return TGThemePaletteMake(0x0d0c1d, 0xf4edf2, 0xb50944, 0xfff8fb, 0x0d0c1d, 0x62546a,
                                  0xc87396, 0xffb9cf, 0x160716, 0xb50944, 0xffb9cf, 0xffffff,
                                  0xcc6c91, 0xd7c4cf, 0x62546a, 0xf5d7e2, 0xb50944, 0xfff5fa, 0xf7d7e4);
    }
    if ([identifier isEqualToString:TGThemeIdentifierEggshellBurgundy]) {
        return TGThemePaletteMake(0x4a0010, 0xfff5e4, 0x71152a, 0xfffbf1, 0x4a0010, 0x7a4c53,
                                  0xb38673, 0xf4d9c3, 0x4a0010, 0x7a1228, 0xf0d0b7, 0xfffdf7,
                                  0xba806b, 0xe0cbb8, 0x7a4c53, 0xf6e3cb, 0x7a1228, 0xfffbf1, 0xf8dfc9);
    }
    if ([identifier isEqualToString:TGThemeIdentifierMelonOlive]) {
        return TGThemePaletteMake(0x3c4826, 0xfff1cc, 0x5a6a36, 0xfff7df, 0x263018, 0x687247,
                                  0xa79562, 0xffd289, 0x263018, 0x5a6a36, 0xffd289, 0xfffdf3,
                                  0xbc8f48, 0xd7c7a2, 0x687247, 0xf6dda1, 0x52612f, 0xfff7df, 0xf5dfb2);
    }
    return TGThemePaletteMake(0x182537, 0xecf3fb, 0x3c5d8a, 0xf8fbfe, 0x0e141d, 0x4e637c,
                              0x8ca6c4, 0xb3cce9, 0x091321, 0x305d96, 0xc2ddf8, 0xffffff,
                              0x5b88bd, 0xaabace, 0x465d77, 0xd6e4f4, 0x2d5d96, 0xf8fbff, 0xdce9f7);
}

static void TGSetActiveThemeIdentifier(NSString *identifier) {
    NSString *validIdentifier = TGThemeIdentifierIsValid(identifier) ? identifier : TGThemeIdentifierVKBlue;
    if (TGActiveThemeIdentifier && [TGActiveThemeIdentifier isEqualToString:validIdentifier]) {
        return;
    }
    [TGActiveThemeIdentifier release];
    TGActiveThemeIdentifier = [validIdentifier copy];
}

static NSString *TGCurrentThemeIdentifier(void) {
    if (!TGActiveThemeIdentifier) {
        TGSetActiveThemeIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:TGThemeDefaultsKey]);
    }
    return TGActiveThemeIdentifier ? TGActiveThemeIdentifier : TGThemeIdentifierVKBlue;
}

static TGThemePalette TGCurrentThemePalette(void) {
    return TGThemePaletteForIdentifier(TGCurrentThemeIdentifier());
}

static NSColor *TGClassicWindowBottomColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.window);
}

static NSColor *TGClassicPanelBottomColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.panel);
}

static NSColor *TGClassicHeaderBottomColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.header);
}

static NSColor *TGClassicTablePaperColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.tablePaper);
}

static NSColor *TGClassicInkColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.ink);
}

static NSColor *TGClassicMutedInkColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.mutedInk);
}

static NSColor *TGClassicOutgoingBubbleBottomColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.outgoingBubble);
}

static NSColor *TGClassicIncomingBubbleBottomColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.incomingBubble);
}

static NSColor *TGClassicRailStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.railStroke);
}

static NSColor *TGClassicHeaderSeparatorColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.headerSeparator);
}

static NSColor *TGClassicPanelStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.panelStroke);
}

static NSColor *TGClassicNavigationSelectedColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationSelected, alpha);
}

static NSColor *TGClassicNavigationHighlightedColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationHighlighted, alpha);
}

static NSColor *TGClassicNavigationNormalColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationNormal, alpha);
}

static NSColor *TGClassicNavigationSelectedStrokeColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationSelectedStroke, alpha);
}

static NSColor *TGClassicNavigationNormalStrokeColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationNormalStroke, alpha);
}

static NSColor *TGClassicNavigationTextColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationText, alpha);
}

static NSColor *TGClassicNavigationMutedTextColor(CGFloat alpha) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.navigationMutedText, alpha);
}

static NSColor *TGClassicSelectedRowColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.selectedRow);
}

static NSColor *TGClassicSelectedRowTextColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.selectedRowText);
}

static NSColor *TGClassicUnreadTextColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.unreadText);
}

static NSColor *TGClassicOutgoingBubbleStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.outgoingBubbleStroke, 0.85);
}

static NSColor *TGClassicIncomingBubbleStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.incomingBubbleStroke, 0.72);
}

static NSColor *TGClassicTimeTextColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.timeText, 1.0);
}

static NSColor *TGClassicTableGridColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.tableGrid);
}

static NSColor *TGClassicTableHeaderColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.tableHeader);
}

static NSColor *TGClassicLinkColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGB(palette.link);
}

static NSColor *TGClassicHeaderTextColor(CGFloat alpha) {
    if ([TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierCoralPlum]) {
        TGThemePalette palette = TGCurrentThemePalette();
        return TGColorFromRGBWithAlpha(palette.ink, alpha);
    }
    return [NSColor colorWithCalibratedWhite:0.99 alpha:alpha];
}

static NSColor *TGClassicHeaderDetailTextColor(CGFloat alpha) {
    if ([TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierCoralPlum]) {
        TGThemePalette palette = TGCurrentThemePalette();
        return TGColorFromRGBWithAlpha(palette.ink, alpha);
    }
    return [NSColor colorWithCalibratedWhite:0.94 alpha:alpha];
}

static NSString *TGCurrentYearString(void) {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%ld", (long)[components year]];
}

static NSString *TGLogTimestampString(void) {
    return [NSDateFormatter localizedStringFromDate:[NSDate date]
                                          dateStyle:NSDateFormatterNoStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

static NSString *TGLogSectionForDetail(NSString *detail) {
    if (![detail isKindOfClass:[NSString class]] || [detail length] == 0) {
        return @"Activity";
    }
    if ([detail hasPrefix:@"TDLib"] || [detail hasPrefix:@"Loaded:"] || [detail hasPrefix:@"Connecting to Telegram core"]) {
        return @"Telegram Core";
    }
    if ([detail hasPrefix:@"Submitting"] || [detail hasPrefix:@"Login"] || [detail hasPrefix:@"Logout"]) {
        return @"Account";
    }
    if ([detail hasPrefix:@"Loading"] || [detail hasPrefix:@"Select a chat"] || [detail hasPrefix:@"Message text"]) {
        return @"Chat Activity";
    }
    if ([detail hasPrefix:@"Theme changed"] || [detail hasPrefix:@"Opened message link"]) {
        return @"Interface";
    }
    if ([detail hasPrefix:@"Profile"]) {
        return @"Profile";
    }
    return @"Activity";
}

static NSString *TGInitialsForTitle(NSString *title) {
    if (![title isKindOfClass:[NSString class]] || [title length] == 0) {
        return @"T";
    }

    NSArray *parts = [title componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableString *initials = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < [parts count]; index++) {
        NSString *part = [parts objectAtIndex:index];
        if (![part isKindOfClass:[NSString class]] || [part length] == 0) {
            continue;
        }
        NSRange range = [part rangeOfComposedCharacterSequenceAtIndex:0];
        [initials appendString:[[part substringWithRange:range] uppercaseString]];
        if ([initials length] >= 2) {
            break;
        }
    }
    if ([initials length] == 0) {
        NSRange range = [title rangeOfComposedCharacterSequenceAtIndex:0];
        [initials appendString:[[title substringWithRange:range] uppercaseString]];
    }
    return ([initials length] > 0) ? initials : @"T";
}

static NSColor *TGAvatarColorForTitle(NSString *title) {
    static NSUInteger colors[] = {
        0x4f78a8, 0x7c8f55, 0xa66a4e, 0x8a6a9d,
        0x4d8a87, 0xa07d42, 0x63738f, 0x9a5969
    };
    NSUInteger count = sizeof(colors) / sizeof(colors[0]);
    NSUInteger index = 0;
    if ([title isKindOfClass:[NSString class]] && [title length] > 0) {
        index = [title hash] % count;
    }
    return TGColorFromRGB(TGRGBMake(colors[index]));
}

static void TGDrawImageInRect(NSImage *image, NSRect rect, BOOL drawingInFlippedView) {
    (void)drawingInFlippedView;
    if (!image || NSIsEmptyRect(rect)) {
        return;
    }
    NSSize imageSize = [image size];
    NSRect sourceRect = NSZeroRect;
    if (imageSize.width > 0.0 && imageSize.height > 0.0) {
        sourceRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
    }
    [image drawInRect:rect
             fromRect:sourceRect
            operation:NSCompositeSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:nil];
}

static void TGDrawImageAspectFillInRect(NSImage *image, NSRect rect, BOOL drawingInFlippedView) {
    (void)drawingInFlippedView;
    if (!image || NSIsEmptyRect(rect)) {
        return;
    }

    NSSize imageSize = [image size];
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        TGDrawImageInRect(image, rect, drawingInFlippedView);
        return;
    }

    CGFloat imageRatio = imageSize.width / imageSize.height;
    CGFloat rectRatio = NSWidth(rect) / NSHeight(rect);
    NSRect sourceRect = NSZeroRect;
    if (imageRatio > rectRatio) {
        CGFloat sourceWidth = imageSize.height * rectRatio;
        sourceRect = NSMakeRect(floor((imageSize.width - sourceWidth) / 2.0), 0.0, sourceWidth, imageSize.height);
    } else {
        CGFloat sourceHeight = imageSize.width / rectRatio;
        sourceRect = NSMakeRect(0.0, floor((imageSize.height - sourceHeight) / 2.0), imageSize.width, sourceHeight);
    }
    [image drawInRect:rect
             fromRect:sourceRect
            operation:NSCompositeSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:nil];
}

static void TGDrawAvatarInRect(NSString *imagePath, NSString *title, NSRect rect, BOOL selected, BOOL drawingInFlippedView) {
    NSBezierPath *avatarPath = [NSBezierPath bezierPathWithOvalInRect:rect];
    NSImage *image = nil;
    if ([imagePath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        image = TGImageWithCorrectOrientationFromFile(imagePath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
        }
    }

    if (image) {
        [NSGraphicsContext saveGraphicsState];
        [avatarPath addClip];
        TGDrawImageInRect(image, rect, drawingInFlippedView);
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [(selected ? TGClassicSelectedRowTextColor() : TGAvatarColorForTitle(title)) set];
        [avatarPath fill];
        NSString *initials = TGInitialsForTitle(title);
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                    [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                    nil];
        NSSize textSize = [initials sizeWithAttributes:attributes];
        NSRect textRect = NSMakeRect(NSMidX(rect) - floor(textSize.width / 2.0),
                                     NSMidY(rect) - floor(textSize.height / 2.0) - 1.0,
                                     textSize.width,
                                     textSize.height);
        [initials drawInRect:textRect withAttributes:attributes];
    }

    [TGClassicPanelStrokeColor() set];
    [avatarPath setLineWidth:1.0];
    [avatarPath stroke];
}

static NSString *TGShortTimeStringFromDateValue(NSNumber *dateValue) {
    if (![dateValue respondsToSelector:@selector(integerValue)] || [dateValue integerValue] <= 0) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[dateValue integerValue]];
    return [NSDateFormatter localizedStringFromDate:date
                                          dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
}

static NSString *TGDisplayTextForMessageItem(TGMessageItem *item) {
    if (!item) {
        return @"";
    }
    NSString *preview = ([item.preview length] > 0) ? item.preview : @"";
    if ([item isVisualMediaMessage]) {
        NSArray *mediaLabels = [NSArray arrayWithObjects:
                                @"[Photo]",
                                @"[Sticker]",
                                @"[Animation]",
                                @"[GIF]",
                                @"[Video]",
                                nil];
        NSUInteger index = 0;
        for (index = 0; index < [mediaLabels count]; index++) {
            NSString *mediaLabel = [mediaLabels objectAtIndex:index];
            if ([preview isEqualToString:mediaLabel]) {
                return @"";
            }
            NSString *mediaPrefix = [mediaLabel stringByAppendingString:@" "];
            if ([preview hasPrefix:mediaPrefix]) {
                return [preview substringFromIndex:[mediaPrefix length]];
            }
        }
    }
    return preview;
}

static NSDataDetector *TGSharedLinkDetector(void) {
    static NSDataDetector *detector = nil;
    if (!detector) {
        NSError *error = nil;
        detector = [[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error] retain];
    }
    return detector;
}

static NSTextCheckingResult *TGFirstLinkResultInString(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || [text length] == 0) {
        return nil;
    }
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector) {
        return nil;
    }
    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] == NSTextCheckingTypeLink && [result URL]) {
            return result;
        }
    }
    return nil;
}

static NSURL *TGFirstURLInMessageItem(TGMessageItem *item) {
    NSTextCheckingResult *result = TGFirstLinkResultInString(TGDisplayTextForMessageItem(item));
    return [result URL];
}

static NSURL *TGURLAtCharacterIndexInString(NSString *text, NSUInteger characterIndex) {
    if (![text isKindOfClass:[NSString class]] || characterIndex >= [text length]) {
        return nil;
    }
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector) {
        return nil;
    }
    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] == NSTextCheckingTypeLink && [result URL] && NSLocationInRange(characterIndex, [result range])) {
            return [result URL];
        }
    }
    return nil;
}

static NSAttributedString *TGAttributedMessageString(NSString *text, NSDictionary *baseAttributes) {
    if (![text isKindOfClass:[NSString class]]) {
        text = @"";
    }
    NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:text
                                                                                   attributes:baseAttributes] autorelease];
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector || [text length] == 0) {
        return attributed;
    }

    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] != NSTextCheckingTypeLink || ![result URL]) {
            continue;
        }
        [attributed addAttribute:NSForegroundColorAttributeName value:TGClassicLinkColor() range:[result range]];
        [attributed addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:[result range]];
    }
    return attributed;
}

static NSString *TGMediaItemLocalPath(NSDictionary *mediaItem) {
    id path = [mediaItem objectForKey:@"local_path"];
    return [path isKindOfClass:[NSString class]] ? (NSString *)path : nil;
}

static NSString *TGMediaItemFullLocalPath(NSDictionary *mediaItem) {
    id path = [mediaItem objectForKey:@"full_local_path"];
    return [path isKindOfClass:[NSString class]] ? (NSString *)path : nil;
}

static NSNumber *TGMediaItemFullFileID(NSDictionary *mediaItem) {
    id fileID = [mediaItem objectForKey:@"full_file_id"];
    if ([fileID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[fileID integerValue]];
    }
    fileID = [mediaItem objectForKey:@"file_id"];
    if ([fileID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[fileID integerValue]];
    }
    return nil;
}

static NSString *TGMediaItemContentType(NSDictionary *mediaItem) {
    id contentType = [mediaItem objectForKey:@"content_type"];
    return [contentType isKindOfClass:[NSString class]] ? (NSString *)contentType : nil;
}

static BOOL TGMediaItemIsAnimation(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageAnimation"];
}

static BOOL TGMediaItemIsVideo(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageVideo"];
}

static NSString *TGMediaItemPlaceholder(NSDictionary *mediaItem) {
    id placeholder = [mediaItem objectForKey:@"placeholder"];
    if ([placeholder isKindOfClass:[NSString class]] && [(NSString *)placeholder length] > 0) {
        return (NSString *)placeholder;
    }
    NSString *contentType = TGMediaItemContentType(mediaItem);
    if ([contentType isEqualToString:@"messageSticker"]) {
        return @"Sticker";
    }
    if ([contentType isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([contentType isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    return @"Photo";
}

static BOOL TGMediaItemIsSticker(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageSticker"];
}

static void TGDrawMediaKindBadge(NSString *badgeText, NSRect rect, BOOL flipped) {
    if (![badgeText isKindOfClass:[NSString class]] || [badgeText length] == 0 || NSIsEmptyRect(rect)) {
        return;
    }

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:9.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                nil];
    NSSize badgeSize = [badgeText sizeWithAttributes:attributes];
    CGFloat badgeWidth = ceil(badgeSize.width) + 12.0;
    CGFloat badgeHeight = 18.0;
    CGFloat badgeX = NSMinX(rect) + 6.0;
    CGFloat badgeY = flipped ? (NSMaxY(rect) - badgeHeight - 6.0) : (NSMinY(rect) + 6.0);
    NSRect badgeRect = NSMakeRect(badgeX, badgeY, badgeWidth, badgeHeight);
    NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:9.0 yRadius:9.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.38] set];
    [badgePath fill];

    NSRect textRect = NSMakeRect(NSMinX(badgeRect),
                                 NSMinY(badgeRect) + floor((NSHeight(badgeRect) - badgeSize.height) / 2.0) - 1.0,
                                 NSWidth(badgeRect),
                                 badgeSize.height + 2.0);
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setAlignment:NSCenterTextAlignment];
    NSMutableDictionary *centeredAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    [centeredAttributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
    [badgeText drawInRect:textRect withAttributes:centeredAttributes];
}

static NSSize TGDisplaySizeForMediaDictionary(NSDictionary *mediaItem, CGFloat maximumWidth) {
    BOOL sticker = TGMediaItemIsSticker(mediaItem);
    CGFloat maximumSide = sticker ? 128.0 : TGMessagePhotoMaximumSide;
    CGFloat minimumWidth = sticker ? 88.0 : 140.0;
    CGFloat minimumHeight = sticker ? 88.0 : 92.0;
    CGFloat width = sticker ? 112.0 : 220.0;
    CGFloat height = sticker ? 112.0 : 160.0;
    id widthObject = [mediaItem objectForKey:@"width"];
    id heightObject = [mediaItem objectForKey:@"height"];
    if ([widthObject respondsToSelector:@selector(floatValue)] && [widthObject floatValue] > 0.0) {
        width = [widthObject floatValue];
    }
    if ([heightObject respondsToSelector:@selector(floatValue)] && [heightObject floatValue] > 0.0) {
        height = [heightObject floatValue];
    }
    if (width <= 0.0 || height <= 0.0) {
        width = sticker ? 112.0 : 220.0;
        height = sticker ? 112.0 : 160.0;
    }
    if (sticker && [TGMediaItemLocalPath(mediaItem) length] == 0) {
        width = 112.0;
        height = 112.0;
    }
    CGFloat scale = maximumSide / ((width > height) ? width : height);
    if (scale < 1.0) {
        width *= scale;
        height *= scale;
    }
    if (width < minimumWidth) {
        CGFloat grow = minimumWidth / width;
        width *= grow;
        height *= grow;
    }
    if (height < minimumHeight) {
        CGFloat grow = minimumHeight / height;
        width *= grow;
        height *= grow;
    }
    if (width > maximumSide) {
        CGFloat shrink = maximumSide / width;
        width *= shrink;
        height *= shrink;
    }
    if (height > maximumSide) {
        CGFloat shrink = maximumSide / height;
        width *= shrink;
        height *= shrink;
    }
    if (maximumWidth > 0.0 && width > maximumWidth) {
        CGFloat shrink = maximumWidth / width;
        width *= shrink;
        height *= shrink;
    }
    return NSMakeSize(ceil(width), ceil(height));
}

static NSSize TGPhotoDisplaySizeForMessageItem(TGMessageItem *item, CGFloat maximumWidth) {
    NSArray *mediaItems = [item visualMediaItems];
    if ([mediaItems count] > 1) {
        CGFloat albumWidth = maximumWidth;
        if (albumWidth > 360.0) {
            albumWidth = 360.0;
        }
        if (albumWidth < 220.0) {
            albumWidth = 220.0;
        }
        NSUInteger count = [mediaItems count];
        CGFloat albumHeight = 210.0;
        if (count == 2) {
            albumHeight = 170.0;
        } else if (count == 3) {
            albumHeight = 260.0;
        } else {
            albumHeight = 286.0;
        }
        if (albumHeight > albumWidth) {
            albumHeight = albumWidth;
        }
        return NSMakeSize(ceil(albumWidth), ceil(albumHeight));
    }
    if ([mediaItems count] == 1) {
        return TGDisplaySizeForMediaDictionary((NSDictionary *)[mediaItems objectAtIndex:0], maximumWidth);
    }

    BOOL sticker = [item isStickerMessage];
    CGFloat maximumSide = sticker ? 128.0 : TGMessagePhotoMaximumSide;
    CGFloat minimumWidth = sticker ? 88.0 : 140.0;
    CGFloat minimumHeight = sticker ? 88.0 : 92.0;
    CGFloat width = sticker ? 112.0 : 220.0;
    CGFloat height = sticker ? 112.0 : 160.0;
    if ([item.mediaWidth respondsToSelector:@selector(floatValue)] && [item.mediaWidth floatValue] > 0.0) {
        width = [item.mediaWidth floatValue];
    }
    if ([item.mediaHeight respondsToSelector:@selector(floatValue)] && [item.mediaHeight floatValue] > 0.0) {
        height = [item.mediaHeight floatValue];
    }
    if (width <= 0.0 || height <= 0.0) {
        width = sticker ? 112.0 : 220.0;
        height = sticker ? 112.0 : 160.0;
    }
    if (sticker && [[item mediaLocalPath] length] == 0) {
        width = 112.0;
        height = 112.0;
    }
    CGFloat scale = maximumSide / ((width > height) ? width : height);
    if (scale < 1.0) {
        width *= scale;
        height *= scale;
    }
    if (width < minimumWidth) {
        CGFloat grow = minimumWidth / width;
        width *= grow;
        height *= grow;
    }
    if (height < minimumHeight) {
        CGFloat grow = minimumHeight / height;
        width *= grow;
        height *= grow;
    }
    if (width > maximumSide) {
        CGFloat shrink = maximumSide / width;
        width *= shrink;
        height *= shrink;
    }
    if (height > maximumSide) {
        CGFloat shrink = maximumSide / height;
        width *= shrink;
        height *= shrink;
    }
    if (maximumWidth > 0.0 && width > maximumWidth) {
        CGFloat shrink = maximumWidth / width;
        width *= shrink;
        height *= shrink;
    }
    return NSMakeSize(ceil(width), ceil(height));
}

static NSArray *TGMediaTileRectsForMessageItem(TGMessageItem *item, NSRect imageRect) {
    NSMutableArray *rects = [NSMutableArray array];
    NSArray *mediaItems = [item visualMediaItems];
    NSUInteger count = [mediaItems count];
    CGFloat gap = 3.0;
    if (count <= 1 || NSIsEmptyRect(imageRect)) {
        [rects addObject:[NSValue valueWithRect:imageRect]];
        return rects;
    }

    if (count == 2) {
        CGFloat tileWidth = floor((NSWidth(imageRect) - gap) / 2.0);
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), tileWidth, NSHeight(imageRect))]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + tileWidth + gap, NSMinY(imageRect), NSWidth(imageRect) - tileWidth - gap, NSHeight(imageRect))]];
        return rects;
    }

    if (count == 3) {
        CGFloat leftWidth = floor((NSWidth(imageRect) - gap) * 0.62);
        CGFloat rightWidth = NSWidth(imageRect) - leftWidth - gap;
        CGFloat halfHeight = floor((NSHeight(imageRect) - gap) / 2.0);
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), leftWidth, NSHeight(imageRect))]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + leftWidth + gap, NSMinY(imageRect), rightWidth, halfHeight)]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + leftWidth + gap, NSMinY(imageRect) + halfHeight + gap, rightWidth, NSHeight(imageRect) - halfHeight - gap)]];
        return rects;
    }

    CGFloat columnWidth = floor((NSWidth(imageRect) - gap) / 2.0);
    CGFloat rowHeight = floor((NSHeight(imageRect) - gap) / 2.0);
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), columnWidth, rowHeight)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + columnWidth + gap, NSMinY(imageRect), NSWidth(imageRect) - columnWidth - gap, rowHeight)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect) + rowHeight + gap, columnWidth, NSHeight(imageRect) - rowHeight - gap)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + columnWidth + gap, NSMinY(imageRect) + rowHeight + gap, NSWidth(imageRect) - columnWidth - gap, NSHeight(imageRect) - rowHeight - gap)]];
    return rects;
}

static void TGDrawMediaItemInRect(NSDictionary *mediaItem, NSRect rect, BOOL outgoing, BOOL flipped, BOOL aspectFill, NSUInteger overflowCount) {
    if (![mediaItem isKindOfClass:[NSDictionary class]] || NSIsEmptyRect(rect)) {
        return;
    }

    NSBezierPath *mediaPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:7.0 yRadius:7.0];
    NSString *localPath = TGMediaItemLocalPath(mediaItem);
    NSImage *image = nil;
    if ([localPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        image = TGImageWithCorrectOrientationFromFile(localPath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:localPath] autorelease];
        }
    }

    if (image) {
        [NSGraphicsContext saveGraphicsState];
        [mediaPath addClip];
        if (aspectFill) {
            TGDrawImageAspectFillInRect(image, rect, flipped);
        } else {
            TGDrawImageInRect(image, rect, flipped);
        }
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [[NSColor colorWithCalibratedWhite:0.96 alpha:0.92] set];
        [mediaPath fill];
        NSString *fallbackText = TGMediaItemPlaceholder(mediaItem);
        CGFloat fallbackFontSize = ([fallbackText length] <= 4) ? 34.0 : 13.0;
        NSMutableParagraphStyle *fallbackParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [fallbackParagraph setAlignment:NSCenterTextAlignment];
        NSDictionary *fallbackAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:fallbackFontSize], NSFontAttributeName,
                                            TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                            fallbackParagraph, NSParagraphStyleAttributeName,
                                            nil];
        NSSize fallbackSize = [fallbackText sizeWithAttributes:fallbackAttributes];
        NSRect fallbackRect = NSMakeRect(NSMinX(rect) + 4.0,
                                         NSMidY(rect) - ceil(fallbackSize.height / 2.0) - 1.0,
                                         NSWidth(rect) - 8.0,
                                         fallbackSize.height + 4.0);
        [fallbackText drawInRect:fallbackRect withAttributes:fallbackAttributes];
    }

    [(outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor()) set];
    [mediaPath setLineWidth:1.0];
    [mediaPath stroke];

    if (overflowCount == 0) {
        if (TGMediaItemIsAnimation(mediaItem)) {
            TGDrawMediaKindBadge(@"GIF", rect, flipped);
        } else if (TGMediaItemIsVideo(mediaItem)) {
            TGDrawMediaKindBadge(@"VIDEO", rect, flipped);
        }
    }

    if (overflowCount > 0) {
        [NSGraphicsContext saveGraphicsState];
        [mediaPath addClip];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.38] set];
        NSRectFillUsingOperation(rect, NSCompositeSourceOver);
        [NSGraphicsContext restoreGraphicsState];

        NSString *overflowText = [NSString stringWithFormat:@"+%lu", (unsigned long)overflowCount];
        NSDictionary *overflowAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:22.0], NSFontAttributeName,
                                            [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                            nil];
        NSSize overflowSize = [overflowText sizeWithAttributes:overflowAttributes];
        NSRect overflowRect = NSMakeRect(NSMidX(rect) - floor(overflowSize.width / 2.0),
                                         NSMidY(rect) - floor(overflowSize.height / 2.0) - 1.0,
                                         overflowSize.width,
                                         overflowSize.height + 2.0);
        [overflowText drawInRect:overflowRect withAttributes:overflowAttributes];
    }
}

static CGFloat TGMaximumBubbleWidthForItem(TGMessageItem *item, CGFloat availableWidth) {
    CGFloat widthRatio = ([item isVisualMediaMessage] ? 0.78 : 0.68);
    CGFloat maximumWidth = availableWidth * widthRatio;
    if (maximumWidth > TGMessageBubbleMaximumWidth) {
        maximumWidth = TGMessageBubbleMaximumWidth;
    }
    if (maximumWidth < 180.0) {
        maximumWidth = 180.0;
    }
    return maximumWidth;
}

static CGFloat TGMessageBubbleHeightForItem(TGMessageItem *item, CGFloat availableWidth) {
    if (!item) {
        return 48.0;
    }
    CGFloat maximumTextWidth = TGMaximumBubbleWidthForItem(item, availableWidth);

    NSString *text = [item isStickerMessage] ? @"" : TGDisplayTextForMessageItem(item);
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                paragraph, NSParagraphStyleAttributeName,
                                nil];
    CGFloat textHeight = 0.0;
    if ([text length] > 0) {
        NSRect textRect = [text boundingRectWithSize:NSMakeSize(maximumTextWidth - 24.0, 1000.0)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes];
        textHeight = ceil(NSHeight(textRect));
    }

    CGFloat height = textHeight + 26.0;
    if ([item isVisualMediaMessage]) {
        NSSize photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumTextWidth - 16.0);
        height = photoSize.height + 24.0 + ((textHeight > 0.0) ? (textHeight + 8.0) : 0.0);
    }
    if (height < 42.0) {
        height = 42.0;
    }
    return height + 10.0;
}

static long long TGMessageSortValue(id value) {
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [value longLongValue];
    }
    return 0;
}

static NSInteger TGCompareMessageItemsAscending(id left, id right, void *context) {
    (void)context;
    long long leftDate = 0;
    long long rightDate = 0;
    long long leftMessageID = 0;
    long long rightMessageID = 0;

    if ([left isKindOfClass:[TGMessageItem class]]) {
        leftDate = TGMessageSortValue([(TGMessageItem *)left date]);
        leftMessageID = TGMessageSortValue([(TGMessageItem *)left messageID]);
    }
    if ([right isKindOfClass:[TGMessageItem class]]) {
        rightDate = TGMessageSortValue([(TGMessageItem *)right date]);
        rightMessageID = TGMessageSortValue([(TGMessageItem *)right messageID]);
    }

    if (leftDate < rightDate) {
        return NSOrderedAscending;
    }
    if (leftDate > rightDate) {
        return NSOrderedDescending;
    }
    if (leftMessageID < rightMessageID) {
        return NSOrderedAscending;
    }
    if (leftMessageID > rightMessageID) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

@interface TGChromeView : NSView
@end

@implementation TGChromeView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [TGClassicWindowBottomColor() set];
    NSRectFill(bounds);
}

@end

@interface TGUtilityWindowView : NSView
@end

@implementation TGUtilityWindowView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [[NSColor colorWithCalibratedWhite:0.925 alpha:1.0] set];
    NSRectFill([self bounds]);
}

@end

@interface TGRailView : NSView
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

@interface TGAccountBadgeView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
    BOOL _connected;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
@property (nonatomic, assign) BOOL connected;
@end

@implementation TGAccountBadgeView

@synthesize displayName = _displayName;
@synthesize avatarLocalPath = _avatarLocalPath;
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

@interface TGProfileAvatarView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
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

@interface TGChatListCell : NSTextFieldCell {
    TGChatItem *_chatItem;
}
@property (nonatomic, retain) TGChatItem *chatItem;
@end

@implementation TGChatListCell

@synthesize chatItem = _chatItem;

- (id)copyWithZone:(NSZone *)zone {
    TGChatListCell *cell = [super copyWithZone:zone];
    cell->_chatItem = nil;
    [cell setChatItem:self.chatItem];
    return cell;
}

- (void)setObjectValue:(id)value {
    if ([value isKindOfClass:[TGChatItem class]]) {
        self.chatItem = (TGChatItem *)value;
        [super setObjectValue:@""];
        return;
    }
    self.chatItem = nil;
    [super setObjectValue:(value ? value : @"")];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGChatItem *item = self.chatItem;
    if (!item) {
        id value = [self objectValue];
        if ([value isKindOfClass:[TGChatItem class]]) {
            item = (TGChatItem *)value;
        }
    }
    if (!item) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    BOOL selected = [self isHighlighted];
    if (selected) {
        NSRect selectedRect = NSInsetRect(cellFrame, 0.0, 1.0);
        NSBezierPath *selectedPath = [NSBezierPath bezierPathWithRoundedRect:selectedRect
                                                                     xRadius:8.0
                                                                     yRadius:8.0];
        [TGClassicSelectedRowColor() set];
        [selectedPath fill];
    }

    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 8.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 26.0) / 2.0),
                                   26.0,
                                   26.0);
    TGDrawAvatarInRect([item avatarLocalPath], [item title], avatarRect, selected, [controlView isFlipped]);

    NSInteger unreadCount = [[item unreadCount] respondsToSelector:@selector(integerValue)] ? [[item unreadCount] integerValue] : 0;
    NSString *unreadString = @"";
    if (unreadCount > 999) {
        unreadString = @"999+";
    } else if (unreadCount > 0) {
        unreadString = [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }

    NSColor *unreadTextColor = selected ? TGClassicSelectedRowColor() : TGClassicNavigationTextColor(1.0);
    NSDictionary *unreadAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                      unreadTextColor, NSForegroundColorAttributeName,
                                      nil];
    NSSize unreadSize = [unreadString sizeWithAttributes:unreadAttributes];
    CGFloat unreadWidth = ([unreadString length] > 0) ? MAX(unreadSize.width + 13.0, 20.0) : 0.0;
    CGFloat unreadHeight = ([unreadString length] > 0) ? 18.0 : 0.0;
    NSRect unreadRect = NSMakeRect(NSMaxX(cellFrame) - unreadWidth - 9.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - unreadHeight) / 2.0),
                                   unreadWidth,
                                   unreadHeight);

    CGFloat titleX = NSMaxX(avatarRect) + 9.0;
    CGFloat titleRight = ([unreadString length] > 0) ? (NSMinX(unreadRect) - 12.0) : (NSMaxX(cellFrame) - 9.0);
    NSRect titleRect = NSMakeRect(titleX,
                                  NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                  titleRight - titleX,
                                  16.0);
    if (NSWidth(titleRect) < 40.0) {
        titleRect.size.width = 40.0;
    }

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     selected ? TGClassicSelectedRowTextColor() : TGClassicInkColor(), NSForegroundColorAttributeName,
                                     paragraph, NSParagraphStyleAttributeName,
                                     nil];
    [[item title] drawInRect:titleRect withAttributes:titleAttributes];
    if ([unreadString length] > 0) {
        NSBezierPath *unreadPath = [NSBezierPath bezierPathWithRoundedRect:unreadRect
                                                                    xRadius:(unreadHeight / 2.0)
                                                                    yRadius:(unreadHeight / 2.0)];
        NSColor *unreadFillColor = selected ? TGClassicSelectedRowTextColor() : TGClassicHeaderBottomColor();
        [unreadFillColor set];
        [unreadPath fill];

        NSRect unreadTextRect = NSMakeRect(NSMinX(unreadRect),
                                           NSMinY(unreadRect) + floor((NSHeight(unreadRect) - unreadSize.height) / 2.0) + 1.0,
                                           NSWidth(unreadRect),
                                           unreadSize.height + 2.0);
        NSMutableParagraphStyle *unreadParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [unreadParagraph setAlignment:NSCenterTextAlignment];
        NSMutableDictionary *centeredUnreadAttributes = [NSMutableDictionary dictionaryWithDictionary:unreadAttributes];
        [centeredUnreadAttributes setObject:unreadParagraph forKey:NSParagraphStyleAttributeName];
        [unreadString drawInRect:unreadTextRect withAttributes:centeredUnreadAttributes];
    }
}

- (void)dealloc {
    [_chatItem release];
    [super dealloc];
}

@end

@interface TGPanelView : NSView
@end

@implementation TGPanelView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect panelBounds = NSInsetRect(bounds, 1.0, 1.0);
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelBounds
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];

    [TGClassicPanelBottomColor() set];
    [panelPath fill];

    [NSGraphicsContext saveGraphicsState];
    [panelPath addClip];
    NSRect headerRect = NSMakeRect(NSMinX(panelBounds),
                                   NSMaxY(panelBounds) - TGPanelHeaderHeight,
                                   NSWidth(panelBounds),
                                   TGPanelHeaderHeight);
    [TGClassicHeaderBottomColor() set];
    NSRectFill(headerRect);
    [TGClassicHeaderSeparatorColor() set];
    NSRectFill(NSMakeRect(NSMinX(headerRect), NSMinY(headerRect), NSWidth(headerRect), 1.0));
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(panelBounds, 1.0, 1.0)
                                                               xRadius:(TGPanelCornerRadius - 1.0)
                                                               yRadius:(TGPanelCornerRadius - 1.0)];
    [TGClassicPanelStrokeColor() set];
    [innerPath setLineWidth:1.0];
    [innerPath stroke];
}

@end

@interface TGScrollSurfaceView : NSView
@end

@implementation TGScrollSurfaceView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect surfaceRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *surfacePath = [NSBezierPath bezierPathWithRoundedRect:surfaceRect
                                                                xRadius:8.0
                                                                yRadius:8.0];
    [TGClassicPanelBottomColor() set];
    [surfacePath fill];
    [TGClassicTableGridColor() set];
    [surfacePath setLineWidth:1.0];
    [surfacePath stroke];
}

@end

@interface TGComposerInputBackgroundView : NSView
@end

@implementation TGComposerInputBackgroundView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect inputRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *inputPath = [NSBezierPath bezierPathWithRoundedRect:inputRect xRadius:7.0 yRadius:7.0];
    [TGClassicTablePaperColor() set];
    [inputPath fill];
    [TGClassicTableGridColor() set];
    [inputPath setLineWidth:1.0];
    [inputPath stroke];
}

@end

@interface TGGroupedCardView : NSView
@end

@implementation TGGroupedCardView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect cardRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect
                                                             xRadius:14.0
                                                             yRadius:14.0];
    [[NSColor colorWithCalibratedWhite:0.985 alpha:1.0] set];
    [cardPath fill];
    [[NSColor colorWithCalibratedWhite:0.78 alpha:0.62] set];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];
}

@end

@protocol TGMediaPreviewMagnificationTarget
- (void)mediaPreviewView:(id)sender didMagnifyBy:(NSNumber *)magnificationNumber;
@end

@interface TGMediaPreviewScrollView : NSScrollView {
    id<TGMediaPreviewMagnificationTarget> _magnificationTarget;
}
@property (nonatomic, assign) id<TGMediaPreviewMagnificationTarget> magnificationTarget;
@end

@implementation TGMediaPreviewScrollView

@synthesize magnificationTarget = _magnificationTarget;

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)magnifyWithEvent:(NSEvent *)event {
    if (self.magnificationTarget) {
        [self.magnificationTarget mediaPreviewView:self didMagnifyBy:[NSNumber numberWithDouble:[event magnification]]];
        return;
    }
    [super magnifyWithEvent:event];
}

@end

@interface TGMediaPreviewImageView : NSImageView {
    id<TGMediaPreviewMagnificationTarget> _magnificationTarget;
}
@property (nonatomic, assign) id<TGMediaPreviewMagnificationTarget> magnificationTarget;
@end

@implementation TGMediaPreviewImageView

@synthesize magnificationTarget = _magnificationTarget;

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)magnifyWithEvent:(NSEvent *)event {
    if (self.magnificationTarget) {
        [self.magnificationTarget mediaPreviewView:self didMagnifyBy:[NSNumber numberWithDouble:[event magnification]]];
        return;
    }
    [super magnifyWithEvent:event];
}

@end

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

static void TGDrawNavigationIcon(NSString *title, NSRect iconRect, NSColor *color, BOOL flipped) {
    [color set];
    if ([title isEqualToString:@"Chats"]) {
        NSRect backBubble = TGIconRect(iconRect, 1.0, 5.0, 12.0, 8.0, flipped);
        NSRect frontBubble = TGIconRect(iconRect, 5.0, 2.0, 13.0, 9.0, flipped);
        [[NSBezierPath bezierPathWithRoundedRect:backBubble xRadius:3.0 yRadius:3.0] stroke];
        [[NSBezierPath bezierPathWithRoundedRect:frontBubble xRadius:3.0 yRadius:3.0] fill];
    } else if ([title isEqualToString:@"Profile"]) {
        NSRect headRect = TGIconRect(iconRect, 5.0, 10.0, 8.0, 8.0, flipped);
        [[NSBezierPath bezierPathWithOvalInRect:headRect] stroke];
        NSBezierPath *bodyPath = [NSBezierPath bezierPath];
        [bodyPath setLineWidth:1.4];
        [bodyPath moveToPoint:TGIconPoint(iconRect, 4.0, 3.0, flipped)];
        [bodyPath curveToPoint:TGIconPoint(iconRect, 14.0, 3.0, flipped)
                 controlPoint1:TGIconPoint(iconRect, 6.0, 8.0, flipped)
                 controlPoint2:TGIconPoint(iconRect, 12.0, 8.0, flipped)];
        [bodyPath stroke];
    } else if ([title isEqualToString:@"Settings"]) {
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 14.0, flipped), TGIconPoint(iconRect, 16.0, 14.0, flipped), 1.4);
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 9.0, flipped), TGIconPoint(iconRect, 16.0, 9.0, flipped), 1.4);
        TGStrokeLine(TGIconPoint(iconRect, 2.0, 4.0, flipped), TGIconPoint(iconRect, 16.0, 4.0, flipped), 1.4);
        [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 5.0, 12.0, 4.0, 4.0, flipped)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:TGIconRect(iconRect, 9.0, 7.0, 4.0, 4.0, flipped)] fill];
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

@interface TGNavigationButtonCell : NSButtonCell
@end

@implementation TGNavigationButtonCell

- (id)copyWithZone:(NSZone *)zone {
    TGNavigationButtonCell *cell = [super copyWithZone:zone];
    return cell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL selected = ([self state] == NSOnState);
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];

    NSColor *fillColor = nil;
    if (selected) {
        fillColor = TGClassicNavigationSelectedColor(alpha);
    } else if (highlighted) {
        fillColor = TGClassicNavigationHighlightedColor(alpha);
    } else {
        fillColor = TGClassicNavigationNormalColor(alpha);
    }

    [fillColor set];
    [path fill];

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
}

@end

@interface TGDrawerButtonCell : NSButtonCell
@end

@implementation TGDrawerButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];
    NSColor *fillColor = highlighted ? TGClassicNavigationHighlightedColor(alpha) : TGClassicNavigationNormalColor(alpha);
    [fillColor set];
    [path fill];
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

@interface TGSendButtonCell : NSButtonCell
@end

@implementation TGSendButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:7.0 yRadius:7.0];
    NSColor *fillColor = highlighted ? TGClassicNavigationHighlightedColor(alpha) : TGClassicHeaderBottomColor();
    [fillColor set];
    [buttonPath fill];
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSRect planeRect = NSInsetRect(buttonRect, 9.0, 8.0);
    NSBezierPath *planePath = [NSBezierPath bezierPath];
    [planePath moveToPoint:NSMakePoint(NSMaxX(planeRect), NSMidY(planeRect))];
    [planePath lineToPoint:NSMakePoint(NSMinX(planeRect), NSMaxY(planeRect))];
    [planePath lineToPoint:NSMakePoint(NSMinX(planeRect) + 4.0, NSMidY(planeRect))];
    [planePath lineToPoint:NSMakePoint(NSMinX(planeRect), NSMinY(planeRect))];
    [planePath closePath];
    [TGClassicHeaderTextColor(alpha) set];
    [planePath fill];
}

@end

@interface TGHeaderIconButtonCell : NSButtonCell
@end

@implementation TGHeaderIconButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:5.0 yRadius:5.0];
    NSColor *topColor = highlighted ? TGClassicNavigationHighlightedColor(alpha) : TGClassicNavigationSelectedColor(alpha);
    NSColor *bottomColor = highlighted ? TGClassicNavigationSelectedColor(alpha) : TGClassicNavigationSelectedStrokeColor(alpha);
    NSGradient *buttonGradient = [[[NSGradient alloc] initWithStartingColor:topColor
                                                                endingColor:bottomColor] autorelease];
    [buttonGradient drawInBezierPath:buttonPath angle:90.0];
    [TGClassicTableGridColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSString *title = [self title] ? [self title] : @"";
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

@interface TGMediaZoomButtonCell : NSButtonCell
@end

@implementation TGMediaZoomButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:5.0 yRadius:5.0];
    NSColor *topColor = highlighted ? TGClassicNavigationHighlightedColor(alpha) : TGClassicNavigationSelectedColor(alpha);
    NSColor *bottomColor = highlighted ? TGClassicNavigationSelectedColor(alpha) : TGClassicNavigationSelectedStrokeColor(alpha);
    NSGradient *buttonGradient = [[[NSGradient alloc] initWithStartingColor:topColor
                                                                endingColor:bottomColor] autorelease];
    [buttonGradient drawInBezierPath:buttonPath angle:90.0];
    [TGClassicTableGridColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSColor *iconColor = TGClassicHeaderTextColor(alpha);
    [iconColor set];
    CGFloat circleSide = 11.0;
    NSRect lensRect = NSMakeRect(NSMidX(buttonRect) - 7.0,
                                 NSMidY(buttonRect) - 4.0,
                                 circleSide,
                                 circleSide);
    NSBezierPath *lensPath = [NSBezierPath bezierPathWithOvalInRect:lensRect];
    [lensPath setLineWidth:1.5];
    [lensPath stroke];

    NSBezierPath *handlePath = [NSBezierPath bezierPath];
    [handlePath setLineWidth:1.8];
    BOOL flipped = [controlView isFlipped];
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

@interface TGSettingsListButtonCell : NSButtonCell
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

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect rowRect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *rowPath = [NSBezierPath bezierPathWithRoundedRect:rowRect xRadius:9.0 yRadius:9.0];
    NSColor *rowColor = highlighted ? TGClassicTableHeaderColor() : TGClassicTablePaperColor();
    [rowColor set];
    [rowPath fill];
    [TGClassicPanelStrokeColor() set];
    [rowPath setLineWidth:1.0];
    [rowPath stroke];

    NSString *title = [self title] ? [self title] : @"";
    NSRect iconRect = NSMakeRect(NSMinX(rowRect) + 11.0, NSMidY(rowRect) - 12.0, 24.0, 24.0);
    NSBezierPath *iconPath = [NSBezierPath bezierPathWithRoundedRect:iconRect xRadius:5.0 yRadius:5.0];
    [[self accentColorForTitle:title alpha:alpha] set];
    [iconPath fill];

    NSDictionary *glyphAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                                     [NSColor colorWithCalibratedWhite:1.0 alpha:alpha], NSForegroundColorAttributeName,
                                     nil];
    NSString *glyph = [self glyphForTitle:title];
    NSSize glyphSize = [glyph sizeWithAttributes:glyphAttributes];
    [glyph drawAtPoint:NSMakePoint(NSMidX(iconRect) - (glyphSize.width / 2.0),
                                   NSMidY(iconRect) - (glyphSize.height / 2.0) - 0.5)
        withAttributes:glyphAttributes];

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

@interface TGMessageBubbleCell : NSTextFieldCell {
    TGMessageItem *_messageItem;
}
@property (nonatomic, retain) TGMessageItem *messageItem;
@end

@implementation TGMessageBubbleCell

@synthesize messageItem = _messageItem;

- (id)copyWithZone:(NSZone *)zone {
    TGMessageBubbleCell *cell = [super copyWithZone:zone];
    cell->_messageItem = nil;
    [cell setMessageItem:self.messageItem];
    return cell;
}

- (void)setObjectValue:(id)value {
    if ([value isKindOfClass:[TGMessageItem class]]) {
        self.messageItem = (TGMessageItem *)value;
        [super setObjectValue:@""];
        return;
    }
    self.messageItem = nil;
    [super setObjectValue:(value ? value : @"")];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGMessageItem *item = self.messageItem;
    if (!item) {
        id value = [self objectValue];
        if ([value isKindOfClass:[TGMessageItem class]]) {
            item = (TGMessageItem *)value;
        }
    }
    if (!item) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSString *rawMessageText = TGDisplayTextForMessageItem(item);
    NSString *messageText = [item isStickerMessage] ? @"" : rawMessageText;
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
        }
    }
    NSAttributedString *attributedMessageText = composedMessageText;
    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [attributedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
    }
    NSSize photoSize = NSZeroSize;
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0;
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:13.0 yRadius:13.0];

    NSColor *bubbleFillColor = outgoing ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor();
    [bubbleFillColor set];
    [bubblePath fill];

    NSColor *strokeColor = outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor();
    [strokeColor set];
    [bubblePath setLineWidth:1.0];
    [bubblePath stroke];

    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    if (visualMediaMessage) {
        NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                      contentTop - photoSize.height,
                                      photoSize.width,
                                      photoSize.height);
        NSArray *mediaItems = [item visualMediaItems];
        NSArray *tileRects = TGMediaTileRectsForMessageItem(item, imageRect);
        NSUInteger tileCount = [tileRects count];
        NSUInteger mediaCount = [mediaItems count];
        if (mediaCount > 0 && tileCount > 0) {
            NSUInteger tileIndex = 0;
            for (tileIndex = 0; tileIndex < tileCount && tileIndex < mediaCount; tileIndex++) {
                id mediaObject = [mediaItems objectAtIndex:tileIndex];
                if (![mediaObject isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSUInteger overflowCount = 0;
                if (tileIndex == tileCount - 1 && mediaCount > tileCount) {
                    overflowCount = mediaCount - tileCount;
                }
                NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
                TGDrawMediaItemInRect((NSDictionary *)mediaObject, tileRect, outgoing, [controlView isFlipped], mediaCount > 1, overflowCount);
            }
        } else {
            NSBezierPath *imagePath = [NSBezierPath bezierPathWithRoundedRect:imageRect xRadius:9.0 yRadius:9.0];
            [(outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor()) set];
            [imagePath setLineWidth:1.0];
            [imagePath stroke];
            NSDictionary *placeholderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                                   TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                                   nil];
            NSString *placeholder = [item visualMediaPlaceholderTitle];
            NSSize placeholderSize = [placeholder sizeWithAttributes:placeholderAttributes];
            NSRect placeholderRect = NSMakeRect(NSMidX(imageRect) - floor(placeholderSize.width / 2.0),
                                                NSMidY(imageRect) - floor(placeholderSize.height / 2.0),
                                                placeholderSize.width,
                                                placeholderSize.height);
            [placeholder drawInRect:placeholderRect withAttributes:placeholderAttributes];
        }
        contentTop = NSMinY(imageRect) - 8.0;
    }

    if ([messageText length] > 0) {
        CGFloat textHeight = ceil(NSHeight(measuredRect));
        NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                     contentTop - textHeight,
                                     NSWidth(bubbleRect) - 24.0,
                                     textHeight + 2.0);
        [attributedMessageText drawWithRect:textRect
                                    options:NSStringDrawingUsesLineFragmentOrigin];
    }

    if ([timeString length] > 0 && [messageText length] == 0) {
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        NSRect timeRect = NSMakeRect(NSMaxX(bubbleRect) - timeSize.width - 12.0,
                                     NSMinY(bubbleRect) + 4.0,
                                     timeSize.width,
                                     10.0);
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
    }
}

- (void)dealloc {
    [_messageItem release];
    [super dealloc];
}

@end

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, TGMediaPreviewMagnificationTarget>
@property (nonatomic, retain) NSView *topPanelView;
@property (nonatomic, retain) NSView *sidebarPanelView;
@property (nonatomic, retain) NSView *conversationPanelView;
@property (nonatomic, retain) NSView *diagnosticsPanelView;
@property (nonatomic, retain) NSView *loginPanelView;
@property (nonatomic, retain) NSView *profilePanelView;
@property (nonatomic, retain) NSView *settingsPanelView;
@property (nonatomic, retain) NSView *aboutPanelView;
@property (nonatomic, retain) TGGroupedCardView *bottomNavigationView;
@property (nonatomic, retain) NSArray *navigationButtons;
@property (nonatomic, retain) NSArray *drawerFolderButtons;
@property (nonatomic, retain) NSArray *chatFilterInfos;
@property (nonatomic, retain) TGAccountBadgeView *accountBadgeView;
@property (nonatomic, retain) NSButton *drawerButton;
@property (nonatomic, retain) TGGroupedCardView *profileSummaryCardView;
@property (nonatomic, retain) TGGroupedCardView *profileInfoCardView;
@property (nonatomic, retain) TGGroupedCardView *profileDetailsCardView;
@property (nonatomic, retain) TGGroupedCardView *profileActionsCardView;
@property (nonatomic, retain) TGProfileAvatarView *profileAvatarView;
@property (nonatomic, retain) TGGroupedCardView *settingsAccountCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsThemeCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsSessionCardView;
@property (nonatomic, retain) TGGroupedCardView *aboutCardView;
@property (nonatomic, retain) TGGroupedCardView *logsCardView;
@property (nonatomic, retain) NSTextField *diagnosticsLabel;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSScrollView *detailsScrollView;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSButton *loadMoreChatsButton;
@property (nonatomic, retain) NSButton *topicBackButton;
@property (nonatomic, retain) NSButton *loadMessagesButton;
@property (nonatomic, retain) NSButton *loadOlderMessagesButton;
@property (nonatomic, retain) NSTextField *sendLabel;
@property (nonatomic, retain) NSView *sendTextFieldBackgroundView;
@property (nonatomic, retain) NSTextField *sendTextField;
@property (nonatomic, retain) NSButton *sendMessageButton;
@property (nonatomic, retain) NSTextField *authLabel;
@property (nonatomic, retain) NSTextField *authStateField;
@property (nonatomic, retain) NSTextField *loginTitleField;
@property (nonatomic, retain) NSTextField *loginHintField;
@property (nonatomic, retain) NSTextField *authTextField;
@property (nonatomic, retain) NSSecureTextField *authSecureField;
@property (nonatomic, retain) NSButton *authButton;
@property (nonatomic, retain) NSTextField *chatsLabel;
@property (nonatomic, retain) NSTextField *messagesLabel;
@property (nonatomic, retain) NSTextField *selectedChatField;
@property (nonatomic, retain) TGProfileAvatarView *selectedChatAvatarView;
@property (nonatomic, retain) NSButton *selectedChatProfileButton;
@property (nonatomic, retain) NSView *chatScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *chatScrollView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) NSArray *chatItemsBeforeTopicList;
@property (nonatomic, retain) NSView *messageScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *messageScrollView;
@property (nonatomic, retain) NSTableView *messageTableView;
@property (nonatomic, retain) NSMutableArray *messageItems;
@property (nonatomic, retain) NSTextField *profileTitleField;
@property (nonatomic, retain) NSTextField *profileNameField;
@property (nonatomic, retain) NSTextField *profileUsernameField;
@property (nonatomic, retain) NSTextField *profileIDField;
@property (nonatomic, retain) NSTextField *profileStateField;
@property (nonatomic, retain) NSTextField *profileAboutSectionField;
@property (nonatomic, retain) NSTextField *profileAccountSectionField;
@property (nonatomic, retain) NSTextField *profileUsernameRowTitleField;
@property (nonatomic, retain) NSTextField *profileUsernameRowValueField;
@property (nonatomic, retain) NSTextField *profilePhoneRowTitleField;
@property (nonatomic, retain) NSTextField *profilePhoneRowValueField;
@property (nonatomic, retain) NSTextField *profileIDRowTitleField;
@property (nonatomic, retain) NSTextField *profileIDRowValueField;
@property (nonatomic, retain) NSBox *profileDetailsSeparatorOne;
@property (nonatomic, retain) NSBox *profileDetailsSeparatorTwo;
@property (nonatomic, retain) NSTextField *settingsTitleField;
@property (nonatomic, retain) NSTextField *settingsStateField;
@property (nonatomic, retain) NSTextField *settingsLibraryField;
@property (nonatomic, retain) NSTextField *settingsStorageField;
@property (nonatomic, retain) NSTextField *settingsThemeLabel;
@property (nonatomic, retain) NSPopUpButton *themePopUpButton;
@property (nonatomic, retain) NSButton *settingsAppearanceButton;
@property (nonatomic, retain) NSButton *settingsLogsButton;
@property (nonatomic, retain) NSButton *settingsAboutButton;
@property (nonatomic, retain) NSButton *logoutButton;
@property (nonatomic, retain) NSImageView *aboutIconView;
@property (nonatomic, retain) NSTextField *aboutTitleField;
@property (nonatomic, retain) NSTextField *aboutVersionField;
@property (nonatomic, retain) NSTextField *aboutCopyrightField;
@property (nonatomic, retain) NSTextField *aboutLinkField;
@property (nonatomic, retain) NSNumber *selectedChatID;
@property (nonatomic, copy) NSString *selectedChatTitle;
@property (nonatomic, copy) NSString *selectedChatTypeSummary;
@property (nonatomic, copy) NSString *selectedChatAvatarLocalPath;
@property (nonatomic, retain) NSNumber *selectedMessageThreadID;
@property (nonatomic, copy) NSString *selectedMessageTopicKind;
@property (nonatomic, retain) NSNumber *topicParentChatID;
@property (nonatomic, copy) NSString *topicParentTitle;
@property (nonatomic, copy) NSString *topicParentAvatarLocalPath;
@property (nonatomic, retain) NSNumber *selectedChatFilterID;
@property (nonatomic, copy) NSString *profileDisplayName;
@property (nonatomic, copy) NSString *profileFirstName;
@property (nonatomic, copy) NSString *profileLastName;
@property (nonatomic, copy) NSString *profileUsername;
@property (nonatomic, copy) NSString *profilePhoneNumber;
@property (nonatomic, retain) NSNumber *profileUserID;
@property (nonatomic, copy) NSString *profileAvatarLocalPath;
@property (nonatomic, copy) NSString *profileBio;
@property (nonatomic, copy) NSString *lastLogSection;
@property (nonatomic, retain) NSWindow *logsWindow;
@property (nonatomic, retain) NSWindow *aboutWindow;
@property (nonatomic, retain) NSWindow *appearanceWindow;
@property (nonatomic, retain) NSWindow *mediaPreviewWindow;
@property (nonatomic, retain) NSScrollView *mediaPreviewScrollView;
@property (nonatomic, retain) NSImageView *mediaPreviewImageView;
@property (nonatomic, copy) NSString *mediaPreviewPath;
@property (nonatomic, assign) NSUInteger mediaPreviewRequestGeneration;
@property (nonatomic, retain) NSTextView *logsWindowDetailsView;
@property (nonatomic, retain) NSButton *logsCheckButton;
@property (nonatomic, retain) NSPopUpButton *appearanceThemePopUpButton;
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState;
@property (nonatomic, copy) NSString *activeSection;
@property (nonatomic, retain) NSTimer *liveUpdateTimer;
@property (nonatomic, assign) BOOL controlsBusy;
@property (nonatomic, assign) BOOL backgroundChatRefreshInFlight;
@property (nonatomic, assign) BOOL backgroundMessageRefreshInFlight;
@property (nonatomic, assign) BOOL pendingLiveChatRefresh;
@property (nonatomic, assign) BOOL pendingLiveMessageRefresh;
@property (nonatomic, assign) NSUInteger chatPreviewLimit;
@property (nonatomic, assign) BOOL chatsExhausted;
@property (nonatomic, assign) BOOL olderMessagesExhausted;
@property (nonatomic, assign) BOOL autoOlderMessagesLoadArmed;
@property (nonatomic, assign) BOOL autoChatListLoadArmed;
@property (nonatomic, assign) BOOL forceMessageScrollToNewest;
@property (nonatomic, assign) BOOL initialConnectStarted;
@property (nonatomic, assign) BOOL profileSummaryLoaded;
@property (nonatomic, assign) BOOL drawerOpen;
@property (nonatomic, assign) BOOL composerRefocusPending;
@property (nonatomic, assign) BOOL chatFilterRefreshInFlight;
@property (nonatomic, assign) NSUInteger chatFilterRefreshRetryCount;
@property (nonatomic, assign) BOOL forumTopicRefreshInFlight;
@property (nonatomic, assign) BOOL suppressChatSelectionHandling;
@property (nonatomic, assign) BOOL showingForumTopicList;
@property (nonatomic, assign) CGFloat mediaPreviewZoomScale;
@end

@implementation TGStatusWindowController

@synthesize topPanelView = _topPanelView;
@synthesize sidebarPanelView = _sidebarPanelView;
@synthesize conversationPanelView = _conversationPanelView;
@synthesize diagnosticsPanelView = _diagnosticsPanelView;
@synthesize loginPanelView = _loginPanelView;
@synthesize profilePanelView = _profilePanelView;
@synthesize settingsPanelView = _settingsPanelView;
@synthesize aboutPanelView = _aboutPanelView;
@synthesize bottomNavigationView = _bottomNavigationView;
@synthesize navigationButtons = _navigationButtons;
@synthesize drawerFolderButtons = _drawerFolderButtons;
@synthesize chatFilterInfos = _chatFilterInfos;
@synthesize accountBadgeView = _accountBadgeView;
@synthesize drawerButton = _drawerButton;
@synthesize profileSummaryCardView = _profileSummaryCardView;
@synthesize profileInfoCardView = _profileInfoCardView;
@synthesize profileDetailsCardView = _profileDetailsCardView;
@synthesize profileActionsCardView = _profileActionsCardView;
@synthesize profileAvatarView = _profileAvatarView;
@synthesize settingsAccountCardView = _settingsAccountCardView;
@synthesize settingsThemeCardView = _settingsThemeCardView;
@synthesize settingsSessionCardView = _settingsSessionCardView;
@synthesize aboutCardView = _aboutCardView;
@synthesize logsCardView = _logsCardView;
@synthesize diagnosticsLabel = _diagnosticsLabel;
@synthesize statusField = _statusField;
@synthesize titleField = _titleField;
@synthesize detailsScrollView = _detailsScrollView;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize loadMoreChatsButton = _loadMoreChatsButton;
@synthesize topicBackButton = _topicBackButton;
@synthesize loadMessagesButton = _loadMessagesButton;
@synthesize loadOlderMessagesButton = _loadOlderMessagesButton;
@synthesize sendLabel = _sendLabel;
@synthesize sendTextFieldBackgroundView = _sendTextFieldBackgroundView;
@synthesize sendTextField = _sendTextField;
@synthesize sendMessageButton = _sendMessageButton;
@synthesize authLabel = _authLabel;
@synthesize authStateField = _authStateField;
@synthesize loginTitleField = _loginTitleField;
@synthesize loginHintField = _loginHintField;
@synthesize authTextField = _authTextField;
@synthesize authSecureField = _authSecureField;
@synthesize authButton = _authButton;
@synthesize chatsLabel = _chatsLabel;
@synthesize messagesLabel = _messagesLabel;
@synthesize selectedChatField = _selectedChatField;
@synthesize selectedChatAvatarView = _selectedChatAvatarView;
@synthesize selectedChatProfileButton = _selectedChatProfileButton;
@synthesize chatScrollSurfaceView = _chatScrollSurfaceView;
@synthesize chatScrollView = _chatScrollView;
@synthesize chatTableView = _chatTableView;
@synthesize chatItems = _chatItems;
@synthesize chatItemsBeforeTopicList = _chatItemsBeforeTopicList;
@synthesize messageScrollSurfaceView = _messageScrollSurfaceView;
@synthesize messageScrollView = _messageScrollView;
@synthesize messageTableView = _messageTableView;
@synthesize messageItems = _messageItems;
@synthesize profileTitleField = _profileTitleField;
@synthesize profileNameField = _profileNameField;
@synthesize profileUsernameField = _profileUsernameField;
@synthesize profileIDField = _profileIDField;
@synthesize profileStateField = _profileStateField;
@synthesize profileAboutSectionField = _profileAboutSectionField;
@synthesize profileAccountSectionField = _profileAccountSectionField;
@synthesize profileUsernameRowTitleField = _profileUsernameRowTitleField;
@synthesize profileUsernameRowValueField = _profileUsernameRowValueField;
@synthesize profilePhoneRowTitleField = _profilePhoneRowTitleField;
@synthesize profilePhoneRowValueField = _profilePhoneRowValueField;
@synthesize profileIDRowTitleField = _profileIDRowTitleField;
@synthesize profileIDRowValueField = _profileIDRowValueField;
@synthesize profileDetailsSeparatorOne = _profileDetailsSeparatorOne;
@synthesize profileDetailsSeparatorTwo = _profileDetailsSeparatorTwo;
@synthesize settingsTitleField = _settingsTitleField;
@synthesize settingsStateField = _settingsStateField;
@synthesize settingsLibraryField = _settingsLibraryField;
@synthesize settingsStorageField = _settingsStorageField;
@synthesize settingsThemeLabel = _settingsThemeLabel;
@synthesize themePopUpButton = _themePopUpButton;
@synthesize settingsAppearanceButton = _settingsAppearanceButton;
@synthesize settingsLogsButton = _settingsLogsButton;
@synthesize settingsAboutButton = _settingsAboutButton;
@synthesize logoutButton = _logoutButton;
@synthesize aboutIconView = _aboutIconView;
@synthesize aboutTitleField = _aboutTitleField;
@synthesize aboutVersionField = _aboutVersionField;
@synthesize aboutCopyrightField = _aboutCopyrightField;
@synthesize aboutLinkField = _aboutLinkField;
@synthesize selectedChatID = _selectedChatID;
@synthesize selectedChatTitle = _selectedChatTitle;
@synthesize selectedChatTypeSummary = _selectedChatTypeSummary;
@synthesize selectedChatAvatarLocalPath = _selectedChatAvatarLocalPath;
@synthesize selectedMessageThreadID = _selectedMessageThreadID;
@synthesize selectedMessageTopicKind = _selectedMessageTopicKind;
@synthesize topicParentChatID = _topicParentChatID;
@synthesize topicParentTitle = _topicParentTitle;
@synthesize topicParentAvatarLocalPath = _topicParentAvatarLocalPath;
@synthesize selectedChatFilterID = _selectedChatFilterID;
@synthesize profileDisplayName = _profileDisplayName;
@synthesize profileFirstName = _profileFirstName;
@synthesize profileLastName = _profileLastName;
@synthesize profileUsername = _profileUsername;
@synthesize profilePhoneNumber = _profilePhoneNumber;
@synthesize profileUserID = _profileUserID;
@synthesize profileAvatarLocalPath = _profileAvatarLocalPath;
@synthesize profileBio = _profileBio;
@synthesize lastLogSection = _lastLogSection;
@synthesize logsWindow = _logsWindow;
@synthesize aboutWindow = _aboutWindow;
@synthesize appearanceWindow = _appearanceWindow;
@synthesize mediaPreviewWindow = _mediaPreviewWindow;
@synthesize mediaPreviewScrollView = _mediaPreviewScrollView;
@synthesize mediaPreviewImageView = _mediaPreviewImageView;
@synthesize mediaPreviewPath = _mediaPreviewPath;
@synthesize mediaPreviewRequestGeneration = _mediaPreviewRequestGeneration;
@synthesize logsWindowDetailsView = _logsWindowDetailsView;
@synthesize logsCheckButton = _logsCheckButton;
@synthesize appearanceThemePopUpButton = _appearanceThemePopUpButton;
@synthesize client = _client;
@synthesize currentAuthState = _currentAuthState;
@synthesize activeSection = _activeSection;
@synthesize liveUpdateTimer = _liveUpdateTimer;
@synthesize controlsBusy = _controlsBusy;
@synthesize backgroundChatRefreshInFlight = _backgroundChatRefreshInFlight;
@synthesize backgroundMessageRefreshInFlight = _backgroundMessageRefreshInFlight;
@synthesize pendingLiveChatRefresh = _pendingLiveChatRefresh;
@synthesize pendingLiveMessageRefresh = _pendingLiveMessageRefresh;
@synthesize chatPreviewLimit = _chatPreviewLimit;
@synthesize chatsExhausted = _chatsExhausted;
@synthesize olderMessagesExhausted = _olderMessagesExhausted;
@synthesize autoOlderMessagesLoadArmed = _autoOlderMessagesLoadArmed;
@synthesize autoChatListLoadArmed = _autoChatListLoadArmed;
@synthesize forceMessageScrollToNewest = _forceMessageScrollToNewest;
@synthesize initialConnectStarted = _initialConnectStarted;
@synthesize profileSummaryLoaded = _profileSummaryLoaded;
@synthesize drawerOpen = _drawerOpen;
@synthesize composerRefocusPending = _composerRefocusPending;
@synthesize chatFilterRefreshInFlight = _chatFilterRefreshInFlight;
@synthesize chatFilterRefreshRetryCount = _chatFilterRefreshRetryCount;
@synthesize forumTopicRefreshInFlight = _forumTopicRefreshInFlight;
@synthesize suppressChatSelectionHandling = _suppressChatSelectionHandling;
@synthesize showingForumTopicList = _showingForumTopicList;
@synthesize mediaPreviewZoomScale = _mediaPreviewZoomScale;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 980, 700);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window setMinSize:NSMakeSize(760, 620)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [[self window] setDelegate:self];
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        TGSetActiveThemeIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:TGThemeDefaultsKey]);
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
        self.chatFilterInfos = [NSArray array];
        self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
        self.activeSection = TGSectionChats;
        self.mediaPreviewZoomScale = 1.0;
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self buildContentView];
        [self startLiveUpdateTimerIfNeeded];
        [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setTextColor:TGClassicInkColor()];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)applyPanelHeaderLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicHeaderTextColor(1.0)];
    [field setFont:[NSFont boldSystemFontOfSize:12.0]];
}

- (void)applyPanelHeaderDetailStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicHeaderDetailTextColor(1.0)];
    [field setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applyMutedLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicMutedInkColor()];
}

- (void)applySkeuomorphicButtonStyle:(NSButton *)button isPrimary:(BOOL)isPrimary {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSTexturedRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    if (isPrimary) {
        [button setFont:[NSFont boldSystemFontOfSize:12.0]];
    } else {
        [button setFont:[NSFont systemFontOfSize:11.0]];
    }
}

- (void)applyUtilityButtonStyle:(NSButton *)button {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [button setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applySettingsListButtonStyle:(NSButton *)button {
    id target = [button target];
    SEL action = [button action];
    NSString *title = [[button title] copy];
    TGSettingsListButtonCell *cell = [[[TGSettingsListButtonCell alloc] initTextCell:[button title]] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:target];
    [button setAction:action];
    [button setBordered:NO];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [title release];
}

- (void)applyDestructiveSettingsButtonStyle:(NSButton *)button {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSRegularSquareBezelStyle];
    [button setBordered:NO];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [button setFont:[NSFont systemFontOfSize:14.0]];
    [[button cell] setAlignment:NSLeftTextAlignment];

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedRed:0.920 green:0.140 blue:0.140 alpha:1.0], NSForegroundColorAttributeName,
                                nil];
    NSAttributedString *title = [[[NSAttributedString alloc] initWithString:@"Logout" attributes:attributes] autorelease];
    [button setAttributedTitle:title];
}

- (void)applySkeuomorphicTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:YES];
    [textField setBordered:YES];
    [textField setBackgroundColor:TGClassicTablePaperColor()];
    [textField setTextColor:TGClassicInkColor()];
    [textField setDrawsBackground:YES];
    [textField setFocusRingType:NSFocusRingTypeExterior];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
    if ([[textField cell] isKindOfClass:[NSTextFieldCell class]]) {
        NSTextFieldCell *textFieldCell = (NSTextFieldCell *)[textField cell];
        [textFieldCell setBezelStyle:NSTextFieldRoundedBezel];
    }
}

- (void)applyComposerTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:NO];
    [textField setBordered:NO];
    [textField setBackgroundColor:[NSColor clearColor]];
    [textField setTextColor:TGClassicInkColor()];
    [textField setDrawsBackground:NO];
    [textField setFocusRingType:NSFocusRingTypeNone];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
    if ([[textField cell] isKindOfClass:[NSTextFieldCell class]]) {
        NSTextFieldCell *textFieldCell = (NSTextFieldCell *)[textField cell];
        [textFieldCell setBezelStyle:NSTextFieldSquareBezel];
    }
}

- (void)applyHeaderIconButtonStyle:(NSButton *)button {
    NSString *title = [[button title] copy];
    id target = [button target];
    SEL action = [button action];
    NSInteger tag = [button tag];
    NSInteger state = [button state];
    BOOL enabled = [button isEnabled];
    NSString *toolTip = [[button toolTip] copy];
    TGHeaderIconButtonCell *cell = [[[TGHeaderIconButtonCell alloc] initTextCell:(title ? title : @"")] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:(title ? title : @"")];
    [button setTarget:target];
    [button setAction:action];
    [button setTag:tag];
    [button setState:state];
    [button setEnabled:enabled];
    [button setToolTip:toolTip];
    [button setBordered:NO];
    [button setFocusRingType:NSFocusRingTypeNone];
    [toolTip release];
    [title release];
}

- (void)applySkeuomorphicScrollStyle:(NSScrollView *)scrollView {
    [scrollView setBorderType:NSNoBorder];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];
    [scrollView setHasVerticalScroller:YES];
}

- (void)applySkeuomorphicTableStyle:(NSTableView *)tableView {
    [tableView setBackgroundColor:TGClassicTablePaperColor()];
    [tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [tableView setGridColor:TGClassicTableGridColor()];
    [tableView setUsesAlternatingRowBackgroundColors:NO];
    [tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
}

- (void)applyTransparentChatTableStyle {
    [self.chatTableView setBackgroundColor:[NSColor clearColor]];
    [self.chatTableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [self.chatTableView setGridColor:TGClassicTableGridColor()];
    [self.chatTableView setUsesAlternatingRowBackgroundColors:NO];
    [self.chatTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [[self.chatScrollView contentView] setDrawsBackground:NO];
    [[self.chatScrollView contentView] setBackgroundColor:[NSColor clearColor]];
}

- (void)applySkeuomorphicHeaderCellStyle:(NSTextFieldCell *)headerCell {
    if (!headerCell) {
        return;
    }
    [headerCell setFont:[NSFont boldSystemFontOfSize:11.0]];
    [headerCell setTextColor:TGClassicMutedInkColor()];
    [headerCell setAlignment:NSLeftTextAlignment];
    [headerCell setDrawsBackground:YES];
    [headerCell setBackgroundColor:TGClassicTableHeaderColor()];
}

- (void)selectThemePopUpItemForIdentifier:(NSString *)identifier {
    NSArray *popUpButtons = [NSArray arrayWithObjects:
                             self.themePopUpButton ? self.themePopUpButton : (id)[NSNull null],
                             self.appearanceThemePopUpButton ? self.appearanceThemePopUpButton : (id)[NSNull null],
                             nil];
    NSUInteger popUpIndex = 0;
    for (popUpIndex = 0; popUpIndex < [popUpButtons count]; popUpIndex++) {
        id candidate = [popUpButtons objectAtIndex:popUpIndex];
        if (![candidate isKindOfClass:[NSPopUpButton class]]) {
            continue;
        }
        NSPopUpButton *popUpButton = (NSPopUpButton *)candidate;
        NSArray *items = [popUpButton itemArray];
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            NSMenuItem *item = [items objectAtIndex:index];
            if ([[item representedObject] isEqual:identifier]) {
                [popUpButton selectItem:item];
                break;
            }
        }
        if ([popUpButton selectedItem] == nil && [items count] > 0) {
            [popUpButton selectItemAtIndex:0];
        }
    }
}

- (void)refreshThemeAppearance {
    [self.titleField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];

    [self.loginTitleField setTextColor:TGClassicInkColor()];
    [self.sendLabel setTextColor:TGClassicInkColor()];
    [self.profileNameField setTextColor:TGClassicInkColor()];
    [self.settingsStateField setTextColor:TGClassicInkColor()];
    [self.aboutTitleField setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.loginHintField];
    [self applyMutedLabelStyle:self.authLabel];
    [self applyMutedLabelStyle:self.authStateField];
    [self applyMutedLabelStyle:self.profileUsernameField];
    [self applyMutedLabelStyle:self.profileIDField];
    [self applyMutedLabelStyle:self.profileStateField];
    [self applyMutedLabelStyle:self.profileAboutSectionField];
    [self applyMutedLabelStyle:self.profileAccountSectionField];
    [self.profileAboutSectionField setFont:[NSFont systemFontOfSize:11.0]];
    [self.profileAccountSectionField setFont:[NSFont systemFontOfSize:11.0]];
    [self.profileUsernameRowTitleField setTextColor:TGClassicInkColor()];
    [self.profilePhoneRowTitleField setTextColor:TGClassicInkColor()];
    [self.profileIDRowTitleField setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.profileUsernameRowValueField];
    [self applyMutedLabelStyle:self.profilePhoneRowValueField];
    [self applyMutedLabelStyle:self.profileIDRowValueField];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [self.settingsThemeLabel setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.aboutVersionField];
    [self applyMutedLabelStyle:self.aboutCopyrightField];
    [self.aboutLinkField setTextColor:TGClassicLinkColor()];
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];

    [self applySkeuomorphicTextFieldStyle:self.authTextField];
    [self applySkeuomorphicTextFieldStyle:self.authSecureField];
    [self applyComposerTextFieldStyle:self.sendTextField];
    [self.sendTextFieldBackgroundView setNeedsDisplay:YES];
    [self.settingsAppearanceButton setNeedsDisplay:YES];
    [self.settingsLogsButton setNeedsDisplay:YES];
    [self.settingsAboutButton setNeedsDisplay:YES];
    [self.bottomNavigationView setNeedsDisplay:YES];
    [self.chatScrollSurfaceView setNeedsDisplay:YES];
    [self.messageScrollSurfaceView setNeedsDisplay:YES];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];

    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self applySkeuomorphicTableStyle:self.messageTableView];
    [self applyTransparentChatTableStyle];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self.messageTableView setGridStyleMask:0];
    [self.messageTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];

    NSArray *tables = [NSArray arrayWithObjects:self.chatTableView, self.messageTableView, nil];
    NSUInteger tableIndex = 0;
    for (tableIndex = 0; tableIndex < [tables count]; tableIndex++) {
        NSTableView *tableView = [tables objectAtIndex:tableIndex];
        NSArray *columns = [tableView tableColumns];
        NSUInteger columnIndex = 0;
        for (columnIndex = 0; columnIndex < [columns count]; columnIndex++) {
            NSTableColumn *column = [columns objectAtIndex:columnIndex];
            [self applySkeuomorphicHeaderCellStyle:[column headerCell]];
        }
    }

    NSView *contentView = [[self window] contentView];
    [contentView setNeedsDisplay:YES];
    NSArray *subviews = [contentView subviews];
    NSUInteger viewIndex = 0;
    for (viewIndex = 0; viewIndex < [subviews count]; viewIndex++) {
        [[subviews objectAtIndex:viewIndex] setNeedsDisplay:YES];
    }
    [self.chatTableView reloadData];
    [self.messageTableView reloadData];
}

- (void)refreshProfileDisplay {
    NSString *displayName = ([self.profileDisplayName length] > 0) ? self.profileDisplayName : @"Telegraphica";
    [self.accountBadgeView setDisplayName:displayName];
    [self.accountBadgeView setAvatarLocalPath:self.profileAvatarLocalPath];
    [self.accountBadgeView setConnected:[self.currentAuthState isEqualToString:@"ready"]];
    [self.profileAvatarView setDisplayName:displayName];
    [self.profileAvatarView setAvatarLocalPath:self.profileAvatarLocalPath];

    if ([self.profileDisplayName length] > 0) {
        NSString *fullName = nil;
        if ([self.profileFirstName length] > 0 && [self.profileLastName length] > 0) {
            fullName = [NSString stringWithFormat:@"%@ %@", self.profileFirstName, self.profileLastName];
        } else if ([self.profileFirstName length] > 0) {
            fullName = self.profileFirstName;
        } else {
            fullName = self.profileDisplayName;
        }
        [self.profileNameField setStringValue:fullName ? fullName : @"Profile"];
    } else {
        [self.profileNameField setStringValue:@"Profile"];
    }
    [self.settingsStateField setStringValue:@""];

    BOOL hasProfileUserID = [self.profileUserID respondsToSelector:@selector(longLongValue)];
    [self.settingsLibraryField setStringValue:@""];

    if ([self.profileUsername length] > 0) {
        [self.profileUsernameRowValueField setStringValue:[NSString stringWithFormat:@"@%@", self.profileUsername]];
    } else {
        [self.profileUsernameRowValueField setStringValue:@""];
    }
    if ([self.profilePhoneNumber length] > 0) {
        NSString *phoneText = self.profilePhoneNumber;
        if (![phoneText hasPrefix:@"+"]) {
            phoneText = [@"+" stringByAppendingString:phoneText];
        }
        [self.profilePhoneRowValueField setStringValue:phoneText];
    } else {
        [self.profilePhoneRowValueField setStringValue:@""];
    }
    if (hasProfileUserID) {
        [self.profileIDRowValueField setStringValue:[NSString stringWithFormat:@"%lld", [self.profileUserID longLongValue]]];
    } else {
        [self.profileIDRowValueField setStringValue:@""];
    }

    NSMutableString *profileSubtitle = [NSMutableString string];
    if ([self.profileUsername length] > 0) {
        [profileSubtitle appendFormat:@"@%@", self.profileUsername];
    }
    if (hasProfileUserID) {
        if ([profileSubtitle length] > 0) {
            [profileSubtitle appendString:@" "];
        }
        [profileSubtitle appendFormat:@"(%lld)", [self.profileUserID longLongValue]];
    }
    [self.profileUsernameField setStringValue:profileSubtitle ? profileSubtitle : @""];

    [self.profileIDField setStringValue:@""];
    [self.profileStateField setStringValue:([self.profileBio length] > 0) ? self.profileBio : @""];
    [self.settingsStorageField setStringValue:@""];
}

- (void)refreshSelectedChatHeaderDisplay {
    NSString *title = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Select a chat";
    [self.selectedChatField setStringValue:title];
    [self.selectedChatAvatarView setDisplayName:title];
    [self.selectedChatAvatarView setAvatarLocalPath:self.selectedChatAvatarLocalPath];
    [self.selectedChatProfileButton setToolTip:(self.selectedChatID ? @"Open chat profile" : @"Select a chat")];
    [self.selectedChatAvatarView setNeedsDisplay:YES];
}

- (void)clearForumTopicListState {
    self.showingForumTopicList = NO;
    self.chatItemsBeforeTopicList = nil;
    self.topicParentChatID = nil;
    self.topicParentTitle = nil;
    self.topicParentAvatarLocalPath = nil;
    [self.chatsLabel setStringValue:@"Chats"];
    [self.loadChatsButton setToolTip:@"Refresh chats"];
}

- (void)clearProfileDisplayCache {
    self.profileDisplayName = nil;
    self.profileFirstName = nil;
    self.profileLastName = nil;
    self.profileUsername = nil;
    self.profilePhoneNumber = nil;
    self.profileUserID = nil;
    self.profileAvatarLocalPath = nil;
    self.profileBio = nil;
    [self.profileStateField setStringValue:@""];
    [self.profileUsernameRowValueField setStringValue:@""];
    [self.profilePhoneRowValueField setStringValue:@""];
    [self.profileIDRowValueField setStringValue:@""];
    [self refreshProfileDisplay];
    [self layoutContentView];
}

- (void)buildContentView {
    TGChromeView *contentView = [[[TGChromeView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:contentView];
    [contentView setAutoresizesSubviews:YES];

    self.topPanelView = [[[TGRailView alloc] initWithFrame:NSMakeRect(16, 628, 948, 56)] autorelease];
    [self.topPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.topPanelView];

    self.accountBadgeView = [[[TGAccountBadgeView alloc] initWithFrame:NSMakeRect(30, 626, 60, 60)] autorelease];
    [self.accountBadgeView setDisplayName:@"Telegraphica"];
    [self.accountBadgeView setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    [contentView addSubview:self.accountBadgeView];

    self.drawerButton = [[[NSButton alloc] initWithFrame:NSMakeRect(18, 636, 34, 34)] autorelease];
    TGDrawerButtonCell *drawerCell = [[[TGDrawerButtonCell alloc] initTextCell:@""] autorelease];
    [drawerCell setButtonType:NSMomentaryPushInButton];
    [self.drawerButton setCell:drawerCell];
    [self.drawerButton setTitle:@""];
    [self.drawerButton setBordered:NO];
    [self.drawerButton setToolTip:@"Chat folders"];
    [self.drawerButton setTarget:self];
    [self.drawerButton setAction:@selector(toggleDrawer:)];
    [self.drawerButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
    [contentView addSubview:self.drawerButton];

    self.sidebarPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 286, 480)] autorelease];
    [self.sidebarPanelView setAutoresizingMask:(NSViewHeightSizable | NSViewMaxXMargin)];
    [contentView addSubview:self.sidebarPanelView];

    self.conversationPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(314, 132, 650, 480)] autorelease];
    [self.conversationPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.conversationPanelView];

    self.diagnosticsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 16, 948, 104)] autorelease];
    [self.diagnosticsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.diagnosticsPanelView];

    self.loginPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(180, 150, 620, 360)] autorelease];
    [self.loginPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.loginPanelView];

    self.profilePanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.profilePanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.profilePanelView];

    self.settingsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.settingsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.settingsPanelView];

    self.aboutPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.aboutPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.aboutPanelView];

    self.bottomNavigationView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(126, 18, 276, 54)] autorelease];
    [self.bottomNavigationView setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.bottomNavigationView];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 668, 712, 28)
                                      text:@"Telegraphica"
                                      font:[NSFont boldSystemFontOfSize:20.0]];
    [self.titleField setTextColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
    [self.titleField setHidden:YES];
    [contentView addSubview:self.titleField];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 636, 712, 22)
                                     text:@"Connecting..."
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [self.statusField setHidden:YES];
    [contentView addSubview:self.statusField];

    NSArray *navigationTitles = [NSArray arrayWithObjects:@"Chats", @"Profile", @"Settings", nil];
    NSInteger navigationTags[] = {0, 1, 2};
    NSMutableArray *navigationButtons = [NSMutableArray arrayWithCapacity:[navigationTitles count]];
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [navigationTitles count]; navigationIndex++) {
        NSString *buttonTitle = [navigationTitles objectAtIndex:navigationIndex];
        NSButton *navigationButton = [[[NSButton alloc] initWithFrame:NSMakeRect(260 + (navigationIndex * 82), 636, 78, 28)] autorelease];
        TGNavigationButtonCell *navigationCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [navigationCell setButtonType:NSToggleButton];
        [navigationButton setCell:navigationCell];
        [navigationButton setTitle:buttonTitle];
        [navigationButton setButtonType:NSToggleButton];
        [navigationButton setBordered:NO];
        [navigationButton setTag:navigationTags[navigationIndex]];
        [navigationButton setToolTip:buttonTitle];
        [navigationButton setTarget:self];
        [navigationButton setAction:@selector(navigationChanged:)];
        [navigationButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
        [contentView addSubview:navigationButton];
        [navigationButtons addObject:navigationButton];
    }
    self.navigationButtons = navigationButtons;

    self.drawerFolderButtons = [NSArray array];

    self.logsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.logsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.logsCardView];

    self.detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.detailsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[self.detailsScrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];
    [self.detailsView setString:@"Diagnostic Logs\n"];
    [self.detailsScrollView setDocumentView:self.detailsView];
    [contentView addSubview:self.detailsScrollView];

    self.diagnosticsLabel = [self labelWithFrame:NSMakeRect(24, 104, 112, 18)
                                            text:@"Diagnostic Logs"
                                            font:[NSFont boldSystemFontOfSize:11.0]];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [contentView addSubview:self.diagnosticsLabel];

    self.loginTitleField = [self labelWithFrame:NSMakeRect(230, 430, 520, 26)
                                           text:@"Sign in to Telegram"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.loginTitleField setAlignment:NSCenterTextAlignment];
    [self.loginTitleField setTextColor:TGClassicInkColor()];
    [contentView addSubview:self.loginTitleField];

    self.loginHintField = [self labelWithFrame:NSMakeRect(250, 392, 480, 44)
                                          text:@"Telegraphica will connect automatically. If this Mac is not signed in yet, continue with your phone number, login code, and password."
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.loginHintField setAlignment:NSCenterTextAlignment];
    [[self.loginHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.loginHintField];
    [contentView addSubview:self.loginHintField];

    self.authLabel = [self labelWithFrame:NSMakeRect(24, 374, 76, 22)
                                     text:@"Auth:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authLabel];
    [contentView addSubview:self.authLabel];

    self.authStateField = [self labelWithFrame:NSMakeRect(104, 374, 560, 22)
                                          text:@"not checked"
                                          font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authStateField];
    [[self.authStateField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.authStateField];

    self.authTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authTextField setEnabled:NO];
    [self.authTextField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authTextField];
    [self.authTextField setDelegate:(id)self];
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authSecureField];
    [self.authSecureField setDelegate:(id)self];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 366, 116, 32)] autorelease];
    [self.authButton setTitle:@"Send"];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self applySkeuomorphicButtonStyle:self.authButton isPrimary:NO];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    self.chatsLabel = [self labelWithFrame:NSMakeRect(24, 338, 76, 22)
                                      text:@"Chats"
                                      font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [contentView addSubview:self.chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 332, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"↻"];
    [self.loadChatsButton setToolTip:@"Refresh chats"];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadChatsButton];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    self.loadMoreChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(224, 332, 80, 32)] autorelease];
    [self.loadMoreChatsButton setTitle:@"+"];
    [self.loadMoreChatsButton setToolTip:@"Load more chats"];
    [self.loadMoreChatsButton setTarget:self];
    [self.loadMoreChatsButton setAction:@selector(loadMoreChats:)];
    [self.loadMoreChatsButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadMoreChatsButton];
    [self.loadMoreChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMoreChatsButton];

    self.topicBackButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 332, 32, 32)] autorelease];
    [self.topicBackButton setTitle:@"‹"];
    [self.topicBackButton setToolTip:@"Back to chats"];
    [self.topicBackButton setTarget:self];
    [self.topicBackButton setAction:@selector(closeForumTopicList:)];
    [self.topicBackButton setEnabled:YES];
    [self applyHeaderIconButtonStyle:self.topicBackButton];
    [self.topicBackButton setAutoresizingMask:NSViewMaxYMargin];
    [self.topicBackButton setHidden:YES];
    [contentView addSubview:self.topicBackButton];

    self.chatScrollSurfaceView = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollSurfaceView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.chatScrollSurfaceView];

    self.chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[self.chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setTarget:self];
    [self.chatTableView setAction:@selector(activateSelectedChatRow:)];
    [self.chatTableView setDoubleAction:@selector(activateSelectedChatRow:)];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];
    [self.chatTableView setRowHeight:38.0];
    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self applyTransparentChatTableStyle];
    [self.chatTableView setHeaderView:nil];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"chat"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Chat"];
    TGChatListCell *chatCell = [[[TGChatListCell alloc] initTextCell:@""] autorelease];
    [chatCell setEditable:NO];
    [chatCell setSelectable:NO];
    [chatColumn setDataCell:chatCell];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    [self.chatScrollView setDocumentView:self.chatTableView];
    [[self.chatScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chatScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.chatScrollView contentView]];
    [contentView addSubview:self.chatScrollView];

    self.messagesLabel = [self labelWithFrame:NSMakeRect(24, 198, 86, 22)
                                         text:@"Conversation"
                                         font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [contentView addSubview:self.messagesLabel];

    self.loadMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(116, 192, 136, 32)] autorelease];
    [self.loadMessagesButton setTitle:@"↻"];
    [self.loadMessagesButton setToolTip:@"Reload messages"];
    [self.loadMessagesButton setTarget:self];
    [self.loadMessagesButton setAction:@selector(loadMessages:)];
    [self.loadMessagesButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadMessagesButton];
    [self.loadMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMessagesButton];

    self.loadOlderMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(264, 192, 112, 32)] autorelease];
    [self.loadOlderMessagesButton setTitle:@"↑"];
    [self.loadOlderMessagesButton setToolTip:@"Load older messages"];
    [self.loadOlderMessagesButton setTarget:self];
    [self.loadOlderMessagesButton setAction:@selector(loadOlderMessages:)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadOlderMessagesButton];
    [self.loadOlderMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadOlderMessagesButton];

    self.selectedChatField = [self labelWithFrame:NSMakeRect(264, 198, 472, 22)
                                             text:@"Select a chat"
                                             font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];
    [[self.selectedChatField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.selectedChatField];

    self.selectedChatAvatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(232, 194, 26, 26)] autorelease];
    [self.selectedChatAvatarView setDisplayName:@"Select a chat"];
    [self.selectedChatAvatarView setHidden:YES];
    [contentView addSubview:self.selectedChatAvatarView];

    self.selectedChatProfileButton = [[[NSButton alloc] initWithFrame:NSMakeRect(232, 194, 400, 28)] autorelease];
    [self.selectedChatProfileButton setTitle:@""];
    [self.selectedChatProfileButton setBordered:NO];
    [self.selectedChatProfileButton setTransparent:YES];
    [self.selectedChatProfileButton setTarget:self];
    [self.selectedChatProfileButton setAction:@selector(openSelectedChatProfile:)];
    [self.selectedChatProfileButton setToolTip:@"Open chat profile"];
    [self.selectedChatProfileButton setHidden:YES];
    [contentView addSubview:self.selectedChatProfileButton];

    self.messageScrollSurfaceView = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollSurfaceView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.messageScrollSurfaceView];

    self.messageScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];

    self.messageTableView = [[[NSTableView alloc] initWithFrame:[[self.messageScrollView contentView] bounds]] autorelease];
    [self.messageTableView setDataSource:self];
    [self.messageTableView setDelegate:self];
    [self.messageTableView setAllowsColumnReordering:NO];
    [self.messageTableView setAllowsMultipleSelection:NO];
    [self.messageTableView setTarget:self];
    [self.messageTableView setAction:@selector(openMessageLink:)];
    [self.messageTableView setRowHeight:52.0];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self applySkeuomorphicTableStyle:self.messageTableView];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self.messageTableView setGridStyleMask:0];
    [self.messageTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [self.messageTableView setHeaderView:nil];

    NSTableColumn *bubbleColumn = [[[NSTableColumn alloc] initWithIdentifier:@"bubble"] autorelease];
    [[bubbleColumn headerCell] setStringValue:@"Conversation"];
    TGMessageBubbleCell *bubbleCell = [[[TGMessageBubbleCell alloc] initTextCell:@""] autorelease];
    [bubbleCell setEditable:NO];
    [bubbleCell setSelectable:NO];
    [bubbleColumn setDataCell:bubbleCell];
    [bubbleColumn setWidth:500.0];
    [self.messageTableView addTableColumn:bubbleColumn];

    [self.messageScrollView setDocumentView:self.messageTableView];
    [[self.messageScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.messageScrollView contentView]];
    [contentView addSubview:self.messageScrollView];

    self.sendLabel = [self labelWithFrame:NSMakeRect(24, 58, 48, 22)
                                     text:@""
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.sendLabel];

    self.sendTextFieldBackgroundView = [[[TGComposerInputBackgroundView alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextFieldBackgroundView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextFieldBackgroundView];

    self.sendTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextField setEnabled:NO];
    [self applyComposerTextFieldStyle:self.sendTextField];
    [self.sendTextField setDelegate:(id)self];
    [self.sendTextField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextField];

    self.sendMessageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(588, 50, 148, 32)] autorelease];
    TGSendButtonCell *sendCell = [[[TGSendButtonCell alloc] initTextCell:@""] autorelease];
    [sendCell setButtonType:NSMomentaryPushInButton];
    [self.sendMessageButton setCell:sendCell];
    [self.sendMessageButton setTitle:@""];
    [self.sendMessageButton setTarget:self];
    [self.sendMessageButton setAction:@selector(sendMessage:)];
    [self.sendMessageButton setEnabled:NO];
    [self.sendMessageButton setBordered:NO];
    [self.sendMessageButton setToolTip:@"Send message"];
    [self.sendMessageButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.sendMessageButton];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Check Connection"];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self applySkeuomorphicButtonStyle:self.checkButton isPrimary:YES];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    self.profileSummaryCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 370, 620, 160)] autorelease];
    [self.profileSummaryCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileSummaryCardView];

    self.profileInfoCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 300, 620, 54)] autorelease];
    [self.profileInfoCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileInfoCardView];

    self.profileDetailsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 230, 620, 124)] autorelease];
    [self.profileDetailsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsCardView];

    self.profileActionsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 166, 620, 54)] autorelease];
    [self.profileActionsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileActionsCardView];

    self.profileAvatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(446, 424, 88, 88)] autorelease];
    [self.profileAvatarView setAutoresizingMask:NSViewMinYMargin];
    [contentView addSubview:self.profileAvatarView];

    self.profileTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                             text:@"My Profile"
                                             font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [contentView addSubview:self.profileTitleField];

    self.profileNameField = [self labelWithFrame:NSMakeRect(64, 458, 620, 24)
                                            text:@"Profile"
                                            font:[NSFont boldSystemFontOfSize:16.0]];
    [self.profileNameField setAlignment:NSLeftTextAlignment];
    [[self.profileNameField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.profileNameField];

    self.profileUsernameField = [self labelWithFrame:NSMakeRect(64, 424, 620, 24)
                                                text:@""
                                                font:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameField setAlignment:NSLeftTextAlignment];
    [[self.profileUsernameField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self applyMutedLabelStyle:self.profileUsernameField];
    [contentView addSubview:self.profileUsernameField];

    self.profileIDField = [self labelWithFrame:NSMakeRect(64, 392, 620, 24)
                                           text:@""
                                           font:[NSFont systemFontOfSize:13.0]];
    [self.profileIDField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.profileIDField];
    [contentView addSubview:self.profileIDField];

    self.profileStateField = [self labelWithFrame:NSMakeRect(64, 348, 720, 38)
                                             text:@""
                                             font:[NSFont systemFontOfSize:12.0]];
    [[self.profileStateField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.profileStateField];
    [contentView addSubview:self.profileStateField];

    self.profileAboutSectionField = [self labelWithFrame:NSMakeRect(64, 320, 620, 18)
                                                    text:@"About"
                                                    font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:self.profileAboutSectionField];
    [contentView addSubview:self.profileAboutSectionField];

    self.profileAccountSectionField = [self labelWithFrame:NSMakeRect(64, 250, 620, 18)
                                                      text:@"Account"
                                                      font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:self.profileAccountSectionField];
    [contentView addSubview:self.profileAccountSectionField];

    self.profileUsernameRowTitleField = [self labelWithFrame:NSMakeRect(64, 248, 180, 20)
                                                        text:@"Username"
                                                        font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profileUsernameRowTitleField];
    self.profileUsernameRowValueField = [self labelWithFrame:NSMakeRect(260, 248, 360, 20)
                                                        text:@""
                                                        font:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameRowValueField setAlignment:NSRightTextAlignment];
    [[self.profileUsernameRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profileUsernameRowValueField];
    [contentView addSubview:self.profileUsernameRowValueField];

    self.profilePhoneRowTitleField = [self labelWithFrame:NSMakeRect(64, 206, 180, 20)
                                                     text:@"Phone"
                                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profilePhoneRowTitleField];
    self.profilePhoneRowValueField = [self labelWithFrame:NSMakeRect(260, 206, 360, 20)
                                                     text:@""
                                                     font:[NSFont systemFontOfSize:13.0]];
    [self.profilePhoneRowValueField setAlignment:NSRightTextAlignment];
    [[self.profilePhoneRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profilePhoneRowValueField];
    [contentView addSubview:self.profilePhoneRowValueField];

    self.profileIDRowTitleField = [self labelWithFrame:NSMakeRect(64, 164, 180, 20)
                                                  text:@"Telegram ID"
                                                  font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profileIDRowTitleField];
    self.profileIDRowValueField = [self labelWithFrame:NSMakeRect(260, 164, 360, 20)
                                                  text:@""
                                                  font:[NSFont systemFontOfSize:13.0]];
    [self.profileIDRowValueField setAlignment:NSRightTextAlignment];
    [[self.profileIDRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profileIDRowValueField];
    [contentView addSubview:self.profileIDRowValueField];

    self.profileDetailsSeparatorOne = [[[NSBox alloc] initWithFrame:NSMakeRect(64, 228, 620, 1)] autorelease];
    [self.profileDetailsSeparatorOne setBoxType:NSBoxSeparator];
    [self.profileDetailsSeparatorOne setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsSeparatorOne];

    self.profileDetailsSeparatorTwo = [[[NSBox alloc] initWithFrame:NSMakeRect(64, 186, 620, 1)] autorelease];
    [self.profileDetailsSeparatorTwo setBoxType:NSBoxSeparator];
    [self.profileDetailsSeparatorTwo setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsSeparatorTwo];

    self.settingsAccountCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 380, 760, 100)] autorelease];
    [self.settingsAccountCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsAccountCardView];

    self.settingsThemeCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 316, 760, 54)] autorelease];
    [self.settingsThemeCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsThemeCardView];

    self.settingsSessionCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 250, 760, 54)] autorelease];
    [self.settingsSessionCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsSessionCardView];

    self.settingsTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                              text:@"Settings"
                                              font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [contentView addSubview:self.settingsTitleField];

    self.settingsStateField = [self labelWithFrame:NSMakeRect(64, 458, 760, 24)
                                              text:@"Account"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsStateField];

    self.settingsLibraryField = [self labelWithFrame:NSMakeRect(64, 424, 760, 24)
                                                text:@""
                                                font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [[self.settingsLibraryField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.settingsLibraryField];

    self.settingsStorageField = [self labelWithFrame:NSMakeRect(64, 380, 760, 44)
                                                text:@""
                                                font:[NSFont systemFontOfSize:12.0]];
    [[self.settingsStorageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [contentView addSubview:self.settingsStorageField];

    self.settingsThemeLabel = [self labelWithFrame:NSMakeRect(64, 332, 88, 24)
                                              text:@"Theme"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsThemeLabel];

    self.themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(154, 326, 300, 30) pullsDown:NO] autorelease];
    NSArray *themeIdentifiers = TGThemeIdentifiers();
    NSUInteger themeIndex = 0;
    for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
        NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
        [self.themePopUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
        [[self.themePopUpButton lastItem] setRepresentedObject:themeIdentifier];
    }
    [self.themePopUpButton setTarget:self];
    [self.themePopUpButton setAction:@selector(themeSelectionChanged:)];
    [self.themePopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [contentView addSubview:self.themePopUpButton];

    self.settingsAppearanceButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 328, 260, 40)] autorelease];
    [self.settingsAppearanceButton setTitle:@"Appearance"];
    [self.settingsAppearanceButton setToolTip:@"Open appearance settings"];
    [self.settingsAppearanceButton setTarget:self];
    [self.settingsAppearanceButton setAction:@selector(showAppearanceWindow:)];
    [self applySettingsListButtonStyle:self.settingsAppearanceButton];
    [self.settingsAppearanceButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsAppearanceButton];

    self.settingsLogsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 276, 260, 40)] autorelease];
    [self.settingsLogsButton setTitle:@"Diagnostic Logs"];
    [self.settingsLogsButton setToolTip:@"Open diagnostic logs"];
    [self.settingsLogsButton setTarget:self];
    [self.settingsLogsButton setAction:@selector(showLogsWindow:)];
    [self applySettingsListButtonStyle:self.settingsLogsButton];
    [self.settingsLogsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsLogsButton];

    self.settingsAboutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(334, 276, 260, 40)] autorelease];
    [self.settingsAboutButton setTitle:@"About Telegraphica"];
    [self.settingsAboutButton setToolTip:@"Open application information"];
    [self.settingsAboutButton setTarget:self];
    [self.settingsAboutButton setAction:@selector(showAboutWindow:)];
    [self applySettingsListButtonStyle:self.settingsAboutButton];
    [self.settingsAboutButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsAboutButton];

    self.logoutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 276, 132, 32)] autorelease];
    [self.logoutButton setTitle:@"Logout"];
    [self.logoutButton setTarget:self];
    [self.logoutButton setAction:@selector(logout:)];
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];
    [self.logoutButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.logoutButton];

    self.aboutCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(240, 230, 500, 310)] autorelease];
    [self.aboutCardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.aboutCardView];

    self.aboutIconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(430, 396, 120, 120)] autorelease];
    NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
    if (!appIcon) {
        appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
    }
    [self.aboutIconView setImage:appIcon];
    [self.aboutIconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [contentView addSubview:self.aboutIconView];

    self.aboutTitleField = [self labelWithFrame:NSMakeRect(240, 352, 500, 30)
                                           text:@"Telegraphica"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.aboutTitleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:self.aboutTitleField];

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [info objectForKey:@"CFBundleVersion"];
    NSString *versionText = [NSString stringWithFormat:@"Version %@ (%@)", version ? version : @"0.1.0", build ? build : @"0.1.0"];
    self.aboutVersionField = [self labelWithFrame:NSMakeRect(240, 324, 500, 22)
                                             text:versionText
                                             font:[NSFont systemFontOfSize:12.0]];
    [self.aboutVersionField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutVersionField];
    [contentView addSubview:self.aboutVersionField];

    NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@ Yura Menschikov. All rights reserved.", TGCurrentYearString()];
    self.aboutCopyrightField = [self labelWithFrame:NSMakeRect(240, 292, 500, 22)
                                               text:copyrightText
                                               font:[NSFont systemFontOfSize:12.0]];
    [self.aboutCopyrightField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutCopyrightField];
    [contentView addSubview:self.aboutCopyrightField];

    self.aboutLinkField = [self labelWithFrame:NSMakeRect(240, 260, 500, 22)
                                          text:@"Project page: coming soon"
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.aboutLinkField setAlignment:NSCenterTextAlignment];
    [self.aboutLinkField setSelectable:YES];
    [self.aboutLinkField setTextColor:TGClassicLinkColor()];
    [contentView addSubview:self.aboutLinkField];

    [self refreshThemeAppearance];
    [self refreshProfileDisplay];
    [self rebuildDrawerFolderButtons];
    [self layoutContentView];
    [self updateVisibleSection];
}

- (NSString *)sectionIdentifierForNavigationTag:(NSInteger)navigationTag {
    if (navigationTag == 1) {
        return TGSectionProfile;
    }
    if (navigationTag == 2) {
        return TGSectionSettings;
    }
    if (navigationTag == 3) {
        return TGSectionAbout;
    }
    if (navigationTag == 4) {
        return TGSectionLogs;
    }
    return TGSectionChats;
}

- (NSInteger)navigationTagForSectionIdentifier:(NSString *)section {
    if ([section isEqualToString:TGSectionProfile]) {
        return 1;
    }
    if ([section isEqualToString:TGSectionSettings]) {
        return 2;
    }
    if ([section isEqualToString:TGSectionAbout]) {
        return 3;
    }
    if ([section isEqualToString:TGSectionLogs]) {
        return 4;
    }
    return 0;
}

- (void)updateDrawerFolderButtonStates {
    NSUInteger index = 0;
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        BOOL selected = NO;
        if ([button tag] < 0) {
            selected = (self.selectedChatFilterID == nil);
        } else if (self.selectedChatFilterID && [button tag] == [self.selectedChatFilterID integerValue]) {
            selected = YES;
        }
        [button setState:selected ? NSOnState : NSOffState];
    }
}

- (void)rebuildDrawerFolderButtons {
    NSView *contentView = [[self window] contentView];
    if (!contentView) {
        return;
    }

    NSUInteger index = 0;
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        [button removeFromSuperview];
    }

    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *folderItems = [NSMutableArray array];
    NSDictionary *allItem = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInteger:-1], @"id",
                             @"All", @"title",
                             nil];
    [folderItems addObject:allItem];
    if ([self.chatFilterInfos count] > 0) {
        [folderItems addObjectsFromArray:self.chatFilterInfos];
    }

    for (index = 0; index < [folderItems count]; index++) {
        NSDictionary *folderInfo = [folderItems objectAtIndex:index];
        NSString *buttonTitle = [folderInfo objectForKey:@"title"];
        id filterID = [folderInfo objectForKey:@"id"];
        if (![buttonTitle isKindOfClass:[NSString class]] || [buttonTitle length] == 0 || ![filterID respondsToSelector:@selector(integerValue)]) {
            continue;
        }

        NSButton *folderButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 500 - (index * 48), 92, 42)] autorelease];
        TGNavigationButtonCell *folderCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [folderCell setButtonType:NSToggleButton];
        [folderButton setCell:folderCell];
        [folderButton setTitle:buttonTitle];
        [folderButton setButtonType:NSToggleButton];
        [folderButton setBordered:NO];
        [folderButton setTag:[filterID integerValue]];
        [folderButton setToolTip:([filterID integerValue] < 0) ? @"All chats" : [NSString stringWithFormat:@"%@ folder", buttonTitle]];
        [folderButton setTarget:self];
        [folderButton setAction:@selector(folderFilterChanged:)];
        [folderButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:folderButton];
        [buttons addObject:folderButton];
    }

    self.drawerFolderButtons = buttons;
    [self updateDrawerFolderButtonStates];
    [self layoutContentView];
}

- (void)reloadChatFiltersIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.chatFilterRefreshInFlight) {
        return;
    }

    self.chatFilterRefreshInFlight = YES;
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *filters = [[client chatFilterInfoItemsWithTimeout:1.5] retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client && [self.currentAuthState isEqualToString:@"ready"]) {
                self.chatFilterInfos = filters ? filters : [NSArray array];
                BOOL selectedFilterWasCleared = NO;
                if (self.selectedChatFilterID) {
                    BOOL selectedFilterStillExists = NO;
                    NSUInteger filterIndex = 0;
                    for (filterIndex = 0; filterIndex < [self.chatFilterInfos count]; filterIndex++) {
                        NSDictionary *filterInfo = [self.chatFilterInfos objectAtIndex:filterIndex];
                        id filterID = [filterInfo objectForKey:@"id"];
                        if ([filterID respondsToSelector:@selector(integerValue)] && [filterID integerValue] == [self.selectedChatFilterID integerValue]) {
                            selectedFilterStillExists = YES;
                            break;
                        }
                    }
                    if (!selectedFilterStillExists) {
                        self.selectedChatFilterID = nil;
                        selectedFilterWasCleared = YES;
                    }
                }
                [self rebuildDrawerFolderButtons];
                if ([self.chatFilterInfos count] > 0) {
                    self.chatFilterRefreshRetryCount = 0;
                }
                if (selectedFilterWasCleared) {
                    self.chatsExhausted = NO;
                    self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
                    [self.client invalidateMainChatListExhaustion];
                    [self reloadChatsInteractive:NO preserveSelection:NO requestedLimit:TGStatusChatPreviewInitialLimit];
                }
            }
            self.chatFilterRefreshInFlight = NO;
            [filters release];
            [client release];
        });

        [pool drain];
    });
}

- (void)updateNavigationButtonsForSection:(NSString *)section enabled:(BOOL)enabled {
    NSInteger selectedTag = [self navigationTagForSectionIdentifier:section];
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        NSButton *button = [self.navigationButtons objectAtIndex:index];
        [button setEnabled:(enabled && ready)];
        [button setHidden:!ready];
        [button setState:([button tag] == selectedTag) ? NSOnState : NSOffState];
    }
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        [button setEnabled:(enabled && ready)];
        [button setHidden:(!ready || !self.drawerOpen)];
    }
    [self updateDrawerFolderButtonStates];
}

- (void)navigationChanged:(id)sender {
    if ([sender respondsToSelector:@selector(tag)]) {
        NSInteger navigationTag = [sender tag];
        if (![self.currentAuthState isEqualToString:@"ready"]) {
            navigationTag = 0;
        }
        self.activeSection = [self sectionIdentifierForNavigationTag:navigationTag];
    }
    [self updateVisibleSection];
}

- (void)folderFilterChanged:(id)sender {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![sender respondsToSelector:@selector(tag)]) {
        [self updateDrawerFolderButtonStates];
        return;
    }

    NSInteger tag = [sender tag];
    NSNumber *filterID = nil;
    if (tag >= 0) {
        filterID = [NSNumber numberWithInteger:tag];
    }

    BOOL sameFilter = NO;
    if (!filterID && !self.selectedChatFilterID) {
        sameFilter = YES;
    } else if (filterID && self.selectedChatFilterID && [filterID integerValue] == [self.selectedChatFilterID integerValue]) {
        sameFilter = YES;
    }

    self.selectedChatFilterID = filterID;
    [self updateDrawerFolderButtonStates];
    if (sameFilter) {
        return;
    }

    [self clearForumTopicListState];
    self.chatsExhausted = NO;
    self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
    self.autoChatListLoadArmed = YES;
    if (!self.selectedChatFilterID) {
        [self.client invalidateMainChatListExhaustion];
    }
    [self reloadChatsInteractive:YES preserveSelection:NO requestedLimit:TGStatusChatPreviewInitialLimit];
}

- (void)toggleDrawer:(id)sender {
    (void)sender;
    self.drawerOpen = !self.drawerOpen;
    [self layoutContentView];
    [self updateVisibleSection];
}

- (NSButton *)modalCloseButtonWithFrame:(NSRect)frame {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setTitle:@"Close"];
    [button setTarget:self];
    [button setAction:@selector(closeUtilityWindow:)];
    [self applyUtilityButtonStyle:button];
    return button;
}

- (void)closeUtilityWindow:(id)sender {
    if ([sender respondsToSelector:@selector(window)]) {
        [[sender window] close];
    }
}

- (void)ensureMediaPreviewWindow {
    if (self.mediaPreviewWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 760, 560);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@""];
    [window setMinSize:NSMakeSize(420, 340)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    TGMediaPreviewScrollView *scrollView = [[[TGMediaPreviewScrollView alloc] initWithFrame:NSMakeRect(16, 58, 728, 486)] autorelease];
    [scrollView setMagnificationTarget:self];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];

    TGMediaPreviewImageView *imageView = [[[TGMediaPreviewImageView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
    [imageView setMagnificationTarget:self];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageFrameStyle:NSImageFrameNone];
    [imageView setAnimates:YES];
    [scrollView setDocumentView:imageView];
    [contentView addSubview:scrollView];
    self.mediaPreviewScrollView = scrollView;
    self.mediaPreviewImageView = imageView;

    NSButton *zoomOutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(16, 18, 42, 30)] autorelease];
    [zoomOutButton setTitle:@"zoom-out"];
    [zoomOutButton setCell:[[[TGMediaZoomButtonCell alloc] initTextCell:@"zoom-out"] autorelease]];
    [zoomOutButton setBordered:NO];
    [zoomOutButton setFocusRingType:NSFocusRingTypeNone];
    [zoomOutButton setToolTip:@"Zoom out"];
    [zoomOutButton setTarget:self];
    [zoomOutButton setAction:@selector(zoomOutMediaPreview:)];
    [zoomOutButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:zoomOutButton];

    NSButton *fitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(66, 18, 74, 30)] autorelease];
    [fitButton setTitle:@"Fit"];
    [fitButton setToolTip:@"Fit media to window"];
    [fitButton setTarget:self];
    [fitButton setAction:@selector(fitMediaPreview:)];
    [self applyUtilityButtonStyle:fitButton];
    [fitButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:fitButton];

    NSButton *zoomInButton = [[[NSButton alloc] initWithFrame:NSMakeRect(148, 18, 42, 30)] autorelease];
    [zoomInButton setTitle:@"zoom-in"];
    [zoomInButton setCell:[[[TGMediaZoomButtonCell alloc] initTextCell:@"zoom-in"] autorelease]];
    [zoomInButton setBordered:NO];
    [zoomInButton setFocusRingType:NSFocusRingTypeNone];
    [zoomInButton setToolTip:@"Zoom in"];
    [zoomInButton setTarget:self];
    [zoomInButton setAction:@selector(zoomInMediaPreview:)];
    [zoomInButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:zoomInButton];

    NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(624, 18, 120, 30)];
    [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:closeButton];

    self.mediaPreviewWindow = window;
}

- (void)applyMediaPreviewZoomScale:(CGFloat)scale {
    NSImage *image = [self.mediaPreviewImageView image];
    if (!image) {
        return;
    }

    if (scale < 0.10) {
        scale = 0.10;
    }
    if (scale > 6.0) {
        scale = 6.0;
    }
    self.mediaPreviewZoomScale = scale;

    NSSize imageSize = [image size];
    CGFloat width = ceil(imageSize.width * scale);
    CGFloat height = ceil(imageSize.height * scale);
    if (width < 1.0) {
        width = 1.0;
    }
    if (height < 1.0) {
        height = 1.0;
    }
    [self.mediaPreviewImageView setFrame:NSMakeRect(0, 0, width, height)];
    [self.mediaPreviewImageView setNeedsDisplay:YES];
}

- (void)fitMediaPreview:(id)sender {
    (void)sender;
    NSImage *image = [self.mediaPreviewImageView image];
    if (!image) {
        return;
    }

    NSSize imageSize = [image size];
    NSRect visibleRect = [[self.mediaPreviewScrollView contentView] bounds];
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || NSWidth(visibleRect) <= 0.0 || NSHeight(visibleRect) <= 0.0) {
        [self applyMediaPreviewZoomScale:1.0];
        return;
    }

    CGFloat scaleX = NSWidth(visibleRect) / imageSize.width;
    CGFloat scaleY = NSHeight(visibleRect) / imageSize.height;
    CGFloat scale = (scaleX < scaleY) ? scaleX : scaleY;
    if (scale > 1.0) {
        scale = 1.0;
    }
    [self applyMediaPreviewZoomScale:scale];
}

- (void)zoomInMediaPreview:(id)sender {
    (void)sender;
    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    [self applyMediaPreviewZoomScale:scale * 1.25];
}

- (void)zoomOutMediaPreview:(id)sender {
    (void)sender;
    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    [self applyMediaPreviewZoomScale:scale / 1.25];
}

- (void)mediaPreviewView:(id)sender didMagnifyBy:(NSNumber *)magnificationNumber {
    (void)sender;
    CGFloat delta = [magnificationNumber respondsToSelector:@selector(doubleValue)] ? (CGFloat)[magnificationNumber doubleValue] : 0.0;
    if (delta > -0.002 && delta < 0.002) {
        return;
    }

    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    CGFloat factor = 1.0 + delta;
    if (factor < 0.25) {
        factor = 0.25;
    }
    if (factor > 4.0) {
        factor = 4.0;
    }
    [self applyMediaPreviewZoomScale:scale * factor];
}

- (BOOL)openMediaPreviewAtPath:(NSString *)path preferAnimated:(BOOL)preferAnimated {
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self appendDetail:@"Media preview file is not available yet."];
        return NO;
    }

    NSString *extension = [[path pathExtension] lowercaseString];
    BOOL likelyAnimated = preferAnimated || [extension isEqualToString:@"gif"];
    NSImage *image = nil;
    if (likelyAnimated) {
        image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    }
    if (!image) {
        image = TGImageWithCorrectOrientationFromFile(path);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
    }
    if (!image) {
        [self appendDetail:@"Could not open media preview."];
        return NO;
    }

    [self ensureMediaPreviewWindow];
    self.mediaPreviewPath = path;
    [self.mediaPreviewImageView setImage:image];
    [self.mediaPreviewImageView setAnimates:YES];
    [self.mediaPreviewWindow setTitle:@""];
    [self fitMediaPreview:nil];
    [self.mediaPreviewWindow center];
    [self.mediaPreviewWindow makeKeyAndOrderFront:nil];
    [self.mediaPreviewWindow makeFirstResponder:self.mediaPreviewImageView];
    return YES;
}

- (BOOL)openMediaPreviewAtPath:(NSString *)path {
    return [self openMediaPreviewAtPath:path preferAnimated:NO];
}

- (void)openMediaPreviewForMediaItem:(NSDictionary *)mediaItem {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSUInteger requestGeneration = self.mediaPreviewRequestGeneration + 1;
    self.mediaPreviewRequestGeneration = requestGeneration;
    BOOL preferAnimated = TGMediaItemIsAnimation(mediaItem);
    NSString *fullPath = TGMediaItemFullLocalPath(mediaItem);
    if ([fullPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        if ([self openMediaPreviewAtPath:fullPath preferAnimated:preferAnimated]) {
            return;
        }
        NSString *fallbackPath = TGMediaItemLocalPath(mediaItem);
        if ([fallbackPath length] > 0 && ![fallbackPath isEqualToString:fullPath]) {
            [self openMediaPreviewAtPath:fallbackPath];
        }
        return;
    }

    NSString *fallbackPath = TGMediaItemLocalPath(mediaItem);
    NSNumber *fileID = TGMediaItemFullFileID(mediaItem);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        if ([fallbackPath length] > 0) {
            [self openMediaPreviewAtPath:fallbackPath];
        }
        return;
    }

    NSNumber *fileIDCopy = [fileID retain];
    NSString *fallbackPathCopy = [fallbackPath copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Loading full media..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSString *downloadedPath = [[client downloadedLocalPathForFileID:fileIDCopy timeout:12.0 error:&downloadError] copy];
        NSString *fallback = [fallbackPathCopy copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestGeneration != self.mediaPreviewRequestGeneration) {
                [downloadedPath release];
                [fallback release];
                [fileIDCopy release];
                [fallbackPathCopy release];
                [client release];
                return;
            }
            if ([downloadedPath length] > 0) {
                if ([self openMediaPreviewAtPath:downloadedPath preferAnimated:preferAnimated]) {
                    [self.statusField setStringValue:@"Connected"];
                } else if ([fallback length] > 0) {
                    [self openMediaPreviewAtPath:fallback];
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:@"Full media format is not previewable yet; opened cached preview."];
                } else {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:@"Full media format is not previewable yet."];
                }
            } else if ([fallback length] > 0) {
                [self openMediaPreviewAtPath:fallback];
                [self.statusField setStringValue:@"Connected"];
                [self appendDetail:@"Full media was not available yet; opened cached preview."];
            } else {
                [self.statusField setStringValue:@"Connected"];
                [self appendDetail:@"Full media was not available yet."];
            }
            [downloadedPath release];
            [fallback release];
            [fileIDCopy release];
            [fallbackPathCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)openSelectedChatProfile:(id)sender {
    (void)sender;
    if (!self.selectedChatID) {
        return;
    }

    NSString *title = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Selected chat";
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = @"Selected chat";
    }

    NSMutableString *details = [NSMutableString string];
    if ([self.selectedChatTypeSummary length] > 0) {
        [details appendFormat:@"%@\n", self.selectedChatTypeSummary];
    }
    if ([self.selectedChatID respondsToSelector:@selector(longLongValue)]) {
        [details appendFormat:@"Chat ID: %lld", [self.selectedChatID longLongValue]];
    }
    if ([self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)]) {
        if ([details length] > 0) {
            [details appendString:@"\n"];
        }
        [details appendFormat:@"Topic ID: %lld", [self.selectedMessageThreadID longLongValue]];
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title];
    [alert setInformativeText:([details length] > 0) ? details : @"No additional profile fields are available yet."];
    [alert addButtonWithTitle:@"Close"];
    if ([self.selectedChatAvatarLocalPath length] > 0) {
        NSImage *avatarImage = [[[NSImage alloc] initWithContentsOfFile:self.selectedChatAvatarLocalPath] autorelease];
        if (avatarImage) {
            [alert setIcon:avatarImage];
        }
    }
    [alert runModal];
}

- (void)showAppearanceWindow:(id)sender {
    (void)sender;
    if (!self.appearanceWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 260);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Appearance"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 72, 420, 124)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [contentView addSubview:cardView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(34, 214, 220, 22)
                                                  text:@"Appearance"
                                                  font:[NSFont boldSystemFontOfSize:14.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSTextField *themeLabel = [self labelWithFrame:NSMakeRect(54, 142, 86, 22)
                                                  text:@"Theme"
                                                  font:[NSFont systemFontOfSize:13.0]];
        [contentView addSubview:themeLabel];

        NSPopUpButton *themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(142, 136, 282, 30) pullsDown:NO] autorelease];
        NSArray *themeIdentifiers = TGThemeIdentifiers();
        NSUInteger themeIndex = 0;
        for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
            NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
            [themePopUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
            [[themePopUpButton lastItem] setRepresentedObject:themeIdentifier];
        }
        [themePopUpButton setTarget:self];
        [themePopUpButton setAction:@selector(themeSelectionChanged:)];
        [themePopUpButton setAutoresizingMask:NSViewMaxYMargin];
        [contentView addSubview:themePopUpButton];
        self.appearanceThemePopUpButton = themePopUpButton;

        NSTextField *hintField = [self labelWithFrame:NSMakeRect(54, 98, 370, 22)
                                                 text:@"Theme changes apply immediately."
                                                 font:[NSFont systemFontOfSize:12.0]];
        [self applyMutedLabelStyle:hintField];
        [contentView addSubview:hintField];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(330, 22, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.appearanceWindow = window;
    }

    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [self.appearanceWindow center];
    [self.appearanceWindow makeKeyAndOrderFront:nil];
}

- (void)showLogsWindow:(id)sender {
    (void)sender;
    if (!self.logsWindow) {
        NSRect frame = NSMakeRect(0, 0, 660, 440);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Diagnostic Logs"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 58, 624, 354)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 70, 600, 330)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];

        NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:YES];
        [textView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
        [textView setTextColor:TGClassicMutedInkColor()];
        [textView setBackgroundColor:TGClassicTablePaperColor()];
        [scrollView setDocumentView:textView];
        [contentView addSubview:scrollView];
        self.logsWindowDetailsView = textView;

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(22, 414, 300, 20)
                                                  text:@"Diagnostic Logs"
                                                  font:[NSFont boldSystemFontOfSize:13.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSButton *checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(390, 18, 120, 30)] autorelease];
        [checkButton setTitle:@"Check"];
        [checkButton setTarget:self];
        [checkButton setAction:@selector(checkTDLib:)];
        [self applyUtilityButtonStyle:checkButton];
        [checkButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:checkButton];
        self.logsCheckButton = checkButton;

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(522, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.logsWindow = window;
    }

    [self.logsCheckButton setEnabled:!self.controlsBusy];
    [self.logsWindowDetailsView setString:(self.detailsView ? [self.detailsView string] : @"")];
    NSRange endRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
    [self.logsWindowDetailsView scrollRangeToVisible:endRange];
    [self.logsWindow center];
    [self.logsWindow makeKeyAndOrderFront:nil];
}

- (void)showAboutWindow:(id)sender {
    (void)sender;
    if (!self.aboutWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 420);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"About Telegraphica"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 54, 420, 332)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSImageView *iconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(180, 246, 120, 120)] autorelease];
        NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
        if (!appIcon) {
            appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
        }
        [iconView setImage:appIcon];
        [iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [iconView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:iconView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(70, 206, 340, 30)
                                                  text:@"Telegraphica"
                                                  font:[NSFont boldSystemFontOfSize:22.0]];
        [titleField setAlignment:NSCenterTextAlignment];
        [contentView addSubview:titleField];

        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [info objectForKey:@"CFBundleVersion"];
        NSString *versionText = [NSString stringWithFormat:@"Version %@ (%@)", version ? version : @"0.1.0", build ? build : @"0.1.0"];
        NSTextField *versionField = [self labelWithFrame:NSMakeRect(70, 176, 340, 22)
                                                    text:versionText
                                                    font:[NSFont systemFontOfSize:12.0]];
        [versionField setAlignment:NSCenterTextAlignment];
        [self applyMutedLabelStyle:versionField];
        [contentView addSubview:versionField];

        NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@ Yura Menschikov. All rights reserved.", TGCurrentYearString()];
        NSTextField *copyrightField = [self labelWithFrame:NSMakeRect(60, 136, 360, 36)
                                                      text:copyrightText
                                                      font:[NSFont systemFontOfSize:12.0]];
        [copyrightField setAlignment:NSCenterTextAlignment];
        [[copyrightField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [self applyMutedLabelStyle:copyrightField];
        [contentView addSubview:copyrightField];

        NSTextField *linkField = [self labelWithFrame:NSMakeRect(70, 104, 340, 22)
                                                 text:@"Project page: coming soon"
                                                 font:[NSFont systemFontOfSize:12.0]];
        [linkField setAlignment:NSCenterTextAlignment];
        [linkField setSelectable:YES];
        [linkField setTextColor:TGClassicLinkColor()];
        [contentView addSubview:linkField];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(180, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.aboutWindow = window;
    }

    [self.aboutWindow center];
    [self.aboutWindow makeKeyAndOrderFront:nil];
}

- (void)themeSelectionChanged:(id)sender {
    NSPopUpButton *sourcePopUpButton = [sender isKindOfClass:[NSPopUpButton class]] ? (NSPopUpButton *)sender : self.themePopUpButton;
    NSMenuItem *selectedItem = [sourcePopUpButton selectedItem];
    NSString *themeIdentifier = [selectedItem representedObject];
    if (!TGThemeIdentifierIsValid(themeIdentifier)) {
        themeIdentifier = TGThemeIdentifierVKBlue;
    }
    TGSetActiveThemeIdentifier(themeIdentifier);
    [[NSUserDefaults standardUserDefaults] setObject:themeIdentifier forKey:TGThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self selectThemePopUpItemForIdentifier:themeIdentifier];
    [self refreshThemeAppearance];
    [self appendDetail:[NSString stringWithFormat:@"Theme changed: %@", TGThemeDisplayNameForIdentifier(themeIdentifier)]];
}

- (void)showView:(NSView *)view visible:(BOOL)visible {
    [view setHidden:!visible];
}

- (void)updateVisibleSection {
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSString *section = self.activeSection ? self.activeSection : TGSectionChats;
    if (!ready && ![section isEqualToString:TGSectionChats]) {
        section = TGSectionChats;
        self.activeSection = TGSectionChats;
    }
    BOOL showLogin = !ready;

    [self updateNavigationButtonsForSection:section enabled:!self.controlsBusy];
    [self showView:self.drawerButton visible:ready];
    [self showView:self.accountBadgeView visible:(ready && self.drawerOpen)];
    [self showView:self.bottomNavigationView visible:ready];

    [self showView:self.loginPanelView visible:showLogin];
    [self showView:self.loginTitleField visible:showLogin];
    [self showView:self.loginHintField visible:showLogin];

    [self showView:self.authLabel visible:showLogin];
    [self showView:self.authStateField visible:(showLogin && ![self isAuthInputState:self.currentAuthState])];
    [self showView:self.authTextField visible:(showLogin && ([self.currentAuthState isEqualToString:@"waitPhoneNumber"] || [self.currentAuthState isEqualToString:@"waitCode"]))];
    [self showView:self.authSecureField visible:(showLogin && [self.currentAuthState isEqualToString:@"waitPassword"])];
    [self showView:self.authButton visible:(showLogin && [self isAuthInputState:self.currentAuthState])];

    BOOL showChats = (ready && [section isEqualToString:TGSectionChats]);
    [self showView:self.sidebarPanelView visible:showChats];
    [self showView:self.conversationPanelView visible:showChats];
    [self showView:self.chatsLabel visible:showChats];
    [self showView:self.topicBackButton visible:(showChats && self.showingForumTopicList)];
    [self showView:self.loadChatsButton visible:showChats];
    [self showView:self.loadMoreChatsButton visible:(showChats && !self.showingForumTopicList)];
    [self showView:self.chatScrollSurfaceView visible:showChats];
    [self showView:self.chatScrollView visible:showChats];
    [self showView:self.messagesLabel visible:NO];
    [self showView:self.loadMessagesButton visible:showChats];
    [self showView:self.loadOlderMessagesButton visible:showChats];
    [self showView:self.selectedChatField visible:showChats];
    BOOL showSelectedChatProfile = (showChats && self.selectedChatID != nil);
    [self showView:self.selectedChatAvatarView visible:showSelectedChatProfile];
    [self showView:self.selectedChatProfileButton visible:showSelectedChatProfile];
    [self showView:self.messageScrollSurfaceView visible:showChats];
    [self showView:self.messageScrollView visible:showChats];
    [self showView:self.sendLabel visible:NO];
    [self showView:self.sendTextFieldBackgroundView visible:showChats];
    [self showView:self.sendTextField visible:showChats];
    [self showView:self.sendMessageButton visible:showChats];

    BOOL showProfile = (ready && [section isEqualToString:TGSectionProfile]);
    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    BOOL showProfileDetails = (showProfile && profileDetailRows > 0);
    [self showView:self.profilePanelView visible:showProfile];
    [self showView:self.profileSummaryCardView visible:showProfile];
    [self showView:self.profileInfoCardView visible:(showProfile && profileHasBio)];
    [self showView:self.profileDetailsCardView visible:showProfileDetails];
    [self showView:self.profileActionsCardView visible:showProfile];
    [self showView:self.profileAvatarView visible:showProfile];
    [self showView:self.profileTitleField visible:showProfile];
    [self showView:self.profileNameField visible:(showProfile && [[self.profileNameField stringValue] length] > 0)];
    [self showView:self.profileUsernameField visible:(showProfile && [[self.profileUsernameField stringValue] length] > 0)];
    [self showView:self.profileIDField visible:NO];
    [self showView:self.profileStateField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAboutSectionField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAccountSectionField visible:showProfileDetails];
    [self showView:self.profileUsernameRowTitleField visible:(showProfile && profileHasUsername)];
    [self showView:self.profileUsernameRowValueField visible:(showProfile && profileHasUsername)];
    [self showView:self.profilePhoneRowTitleField visible:(showProfile && profileHasPhone)];
    [self showView:self.profilePhoneRowValueField visible:(showProfile && profileHasPhone)];
    [self showView:self.profileIDRowTitleField visible:(showProfile && profileHasID)];
    [self showView:self.profileIDRowValueField visible:(showProfile && profileHasID)];
    [self showView:self.profileDetailsSeparatorOne visible:(showProfileDetails && profileDetailRows > 1)];
    [self showView:self.profileDetailsSeparatorTwo visible:(showProfileDetails && profileDetailRows > 2)];
    [self showView:self.logoutButton visible:showProfile];

    BOOL showSettings = (ready && [section isEqualToString:TGSectionSettings]);
    [self showView:self.settingsPanelView visible:showSettings];
    [self showView:self.settingsAccountCardView visible:NO];
    [self showView:self.settingsThemeCardView visible:NO];
    [self showView:self.settingsSessionCardView visible:showSettings];
    [self showView:self.settingsTitleField visible:showSettings];
    [self showView:self.settingsStateField visible:NO];
    [self showView:self.settingsLibraryField visible:NO];
    [self showView:self.settingsStorageField visible:NO];
    [self showView:self.settingsThemeLabel visible:NO];
    [self showView:self.themePopUpButton visible:NO];
    [self showView:self.settingsAppearanceButton visible:showSettings];
    [self showView:self.settingsLogsButton visible:showSettings];
    [self showView:self.settingsAboutButton visible:showSettings];

    [self showView:self.aboutPanelView visible:NO];
    [self showView:self.aboutCardView visible:NO];
    [self showView:self.aboutIconView visible:NO];
    [self showView:self.aboutTitleField visible:NO];
    [self showView:self.aboutVersionField visible:NO];
    [self showView:self.aboutCopyrightField visible:NO];
    [self showView:self.aboutLinkField visible:NO];

    [self showView:self.diagnosticsPanelView visible:NO];
    [self showView:self.logsCardView visible:NO];
    [self showView:self.diagnosticsLabel visible:NO];
    [self showView:self.detailsScrollView visible:NO];
    [self showView:self.checkButton visible:NO];
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 10.0;
    CGFloat gutter = 10.0;
    CGFloat railWidth = self.drawerOpen ? 108.0 : 44.0;
    CGFloat railX = margin;
    CGFloat railY = margin;
    CGFloat railHeight = height - (margin * 2.0);
    CGFloat railTop = railY + railHeight;
    CGFloat mainX = railX + railWidth + gutter;
    CGFloat mainY = margin;
    CGFloat mainWidth = width - mainX - margin;
    CGFloat mainHeight = railHeight;
    CGFloat mainTop = mainY + mainHeight;
    CGFloat sidebarWidth = 292.0;

    if (railHeight < 520.0) {
        railHeight = 520.0;
        railTop = railY + railHeight;
        mainHeight = railHeight;
        mainTop = mainY + mainHeight;
    }
    if (width < 900.0) {
        sidebarWidth = 248.0;
    } else if (width < 1040.0) {
        sidebarWidth = 272.0;
    }

    CGFloat conversationX = mainX + sidebarWidth + gutter;
    CGFloat conversationWidth = width - conversationX - margin;
    if (conversationWidth < 320.0) {
        CGFloat reduction = 320.0 - conversationWidth;
        sidebarWidth -= reduction;
        if (sidebarWidth < 220.0) {
            sidebarWidth = 220.0;
        }
        conversationX = mainX + sidebarWidth + gutter;
        conversationWidth = width - conversationX - margin;
    }
    if (mainWidth < 420.0) {
        mainWidth = 420.0;
    }

    [self.topPanelView setFrame:NSMakeRect(railX, railY, railWidth, railHeight)];
    [self.sidebarPanelView setFrame:NSMakeRect(mainX, mainY, sidebarWidth, mainHeight)];
    [self.conversationPanelView setFrame:NSMakeRect(conversationX, mainY, conversationWidth, mainHeight)];
    [self.diagnosticsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.profilePanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.settingsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.aboutPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];

    [self.drawerButton setFrame:NSMakeRect(railX + 5.0, railTop - 39.0, 34.0, 34.0)];
    CGFloat accountBadgeWidth = railWidth - 48.0;
    if (accountBadgeWidth < 0.0) {
        accountBadgeWidth = 0.0;
    }
    [self.accountBadgeView setFrame:NSMakeRect(railX + 24.0, railTop - 124.0, accountBadgeWidth, 60.0)];
    [self.titleField setFont:[NSFont boldSystemFontOfSize:13.0]];
    [[self.titleField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.titleField setFrame:NSMakeRect(railX + 9.0, railTop - 48.0, railWidth - 18.0, 18.0)];
    [self.statusField setFont:[NSFont systemFontOfSize:9.0]];
    [[self.statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.statusField setFrame:NSMakeRect(railX + 9.0, railTop - 66.0, railWidth - 18.0, 14.0)];

    CGFloat drawerFolderButtonHeight = 46.0;
    CGFloat drawerFolderButtonGap = 8.0;
    CGFloat drawerFolderButtonY = railTop - 196.0;
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [self.drawerFolderButtons count]; navigationIndex++) {
        NSButton *folderButton = [self.drawerFolderButtons objectAtIndex:navigationIndex];
        [folderButton setFrame:NSMakeRect(railX + 8.0, drawerFolderButtonY, railWidth - 16.0, drawerFolderButtonHeight)];
        drawerFolderButtonY -= (drawerFolderButtonHeight + drawerFolderButtonGap);
    }

    CGFloat bottomNavigationHeight = 62.0;
    CGFloat bottomNavigationX = mainX + 8.0;
    CGFloat bottomNavigationY = mainY + 8.0;
    CGFloat bottomNavigationWidth = sidebarWidth - 16.0;
    if (bottomNavigationWidth < 204.0) {
        bottomNavigationWidth = sidebarWidth - 8.0;
        bottomNavigationX = mainX + 4.0;
    }
    [self.bottomNavigationView setFrame:NSMakeRect(bottomNavigationX,
                                                   bottomNavigationY,
                                                   bottomNavigationWidth,
                                                   bottomNavigationHeight)];
    CGFloat bottomNavigationInnerX = bottomNavigationX + 8.0;
    CGFloat bottomNavigationButtonGap = 6.0;
    CGFloat bottomNavigationButtonHeight = 48.0;
    CGFloat bottomNavigationButtonY = bottomNavigationY + floor((bottomNavigationHeight - bottomNavigationButtonHeight) / 2.0);
    CGFloat bottomNavigationButtonWidth = floor((bottomNavigationWidth - 16.0 - (bottomNavigationButtonGap * 2.0)) / 3.0);
    if (bottomNavigationButtonWidth < 58.0) {
        bottomNavigationButtonWidth = 58.0;
    }
    for (navigationIndex = 0; navigationIndex < [self.navigationButtons count]; navigationIndex++) {
        NSButton *navigationButton = [self.navigationButtons objectAtIndex:navigationIndex];
        CGFloat buttonX = bottomNavigationInnerX + ((bottomNavigationButtonWidth + bottomNavigationButtonGap) * navigationIndex);
        [navigationButton setFrame:NSMakeRect(buttonX,
                                              bottomNavigationButtonY,
                                              bottomNavigationButtonWidth,
                                              bottomNavigationButtonHeight)];
    }
    CGFloat loginWidth = mainWidth - 96.0;
    if (loginWidth > 580.0) {
        loginWidth = 580.0;
    }
    if (loginWidth < 390.0) {
        loginWidth = mainWidth - 24.0;
    }
    CGFloat loginHeight = 300.0;
    CGFloat loginX = mainX + ((mainWidth - loginWidth) / 2.0);
    CGFloat loginY = mainY + ((mainHeight - loginHeight) / 2.0);
    if (loginY < mainY + 18.0) {
        loginY = mainY + 18.0;
    }
    [self.loginPanelView setFrame:NSMakeRect(loginX, loginY, loginWidth, loginHeight)];
    [self.loginTitleField setFrame:NSMakeRect(loginX + 36.0, loginY + loginHeight - 70.0, loginWidth - 72.0, 28.0)];
    [self.loginHintField setFrame:NSMakeRect(loginX + 42.0, loginY + loginHeight - 132.0, loginWidth - 84.0, 52.0)];
    [self.authLabel setFrame:NSMakeRect(loginX + 52.0, loginY + 128.0, loginWidth - 104.0, 18.0)];
    [self.authStateField setFrame:NSMakeRect(loginX + 52.0, loginY + 82.0, loginWidth - 104.0, 48.0)];
    CGFloat loginButtonWidth = 92.0;
    CGFloat loginInputX = loginX + 52.0;
    CGFloat loginButtonX = loginX + loginWidth - 52.0 - loginButtonWidth;
    CGFloat loginInputWidth = loginButtonX - loginInputX - 10.0;
    if (loginInputWidth < 180.0) {
        loginInputWidth = 180.0;
    }
    [self.authTextField setFrame:NSMakeRect(loginInputX, loginY + 92.0, loginInputWidth, 26.0)];
    [self.authSecureField setFrame:NSMakeRect(loginInputX, loginY + 92.0, loginInputWidth, 26.0)];
    [self.authButton setFrame:NSMakeRect(loginButtonX, loginY + 89.0, loginButtonWidth, 32.0)];

    CGFloat headerButtonSize = 30.0;
    CGFloat sectionHeaderVisualOffset = -2.0;
    CGFloat headerButtonY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - headerButtonSize) / 2.0) + sectionHeaderVisualOffset;
    CGFloat headerLabelY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - 20.0) / 2.0) + sectionHeaderVisualOffset;
    CGFloat chatHeaderTitleX = self.showingForumTopicList ? (mainX + 52.0) : (mainX + 16.0);
    [self.topicBackButton setFrame:NSMakeRect(mainX + 12.0, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.chatsLabel setFrame:NSMakeRect(chatHeaderTitleX, headerLabelY, sidebarWidth - (chatHeaderTitleX - mainX) - 96.0, 20.0)];
    [self.loadMoreChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    if (self.showingForumTopicList) {
        [self.loadChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    } else {
        [self.loadChatsButton setFrame:NSMakeRect(NSMinX([self.loadMoreChatsButton frame]) - 8.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    }
    CGFloat chatListX = mainX + 8.0;
    CGFloat chatListBottom = bottomNavigationY + bottomNavigationHeight + 9.0;
    CGFloat chatListTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat chatListHeight = chatListTop - chatListBottom;
    if (chatListHeight < 128.0) {
        chatListHeight = 128.0;
    }
    CGFloat chatListWidth = sidebarWidth - 16.0;
    if (chatListWidth < 132.0) {
        chatListWidth = 132.0;
    }
    NSRect chatSurfaceFrame = NSMakeRect(chatListX, chatListBottom, chatListWidth, chatListHeight);
    [self.chatScrollSurfaceView setFrame:chatSurfaceFrame];
    [self.chatScrollView setFrame:NSInsetRect(chatSurfaceFrame, 5.0, 5.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"chat"];
    if (chatColumn) {
        [self.chatScrollView tile];
        CGFloat chatWidth = NSWidth([[self.chatScrollView contentView] bounds]);
        if (chatWidth < 132.0) {
            chatWidth = 132.0;
        }
        [chatColumn setWidth:chatWidth];
    }

    [self.loadOlderMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.loadMessagesButton setFrame:NSMakeRect(NSMinX([self.loadOlderMessagesButton frame]) - 8.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.messagesLabel setFrame:NSMakeRect(conversationX + 16.0, headerLabelY, 0.0, 20.0)];
    CGFloat selectedAvatarSize = 24.0;
    CGFloat selectedAvatarX = conversationX + 16.0;
    CGFloat selectedAvatarY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - selectedAvatarSize) / 2.0) + sectionHeaderVisualOffset;
    [self.selectedChatAvatarView setFrame:NSMakeRect(selectedAvatarX, selectedAvatarY, selectedAvatarSize, selectedAvatarSize)];
    CGFloat selectedTitleX = NSMaxX([self.selectedChatAvatarView frame]) + 8.0;
    CGFloat selectedTitleWidth = NSMinX([self.loadMessagesButton frame]) - selectedTitleX - 12.0;
    if (selectedTitleWidth < 120.0) {
        selectedTitleWidth = 120.0;
    }
    [self.selectedChatField setFrame:NSMakeRect(selectedTitleX,
                                                headerLabelY,
                                                selectedTitleWidth,
                                                20.0)];
    [self.selectedChatProfileButton setFrame:NSMakeRect(selectedAvatarX,
                                                        selectedAvatarY - 2.0,
                                                        NSMaxX([self.selectedChatField frame]) - selectedAvatarX,
                                                        selectedAvatarSize + 4.0)];

    CGFloat composerHeight = 42.0;
    CGFloat composerY = mainY + 8.0;
    CGFloat messageBottom = composerY + composerHeight + 4.0;
    CGFloat messageTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat messageHeight = messageTop - messageBottom;
    if (messageHeight < 160.0) {
        messageHeight = 160.0;
    }
    CGFloat messageScrollX = conversationX + 8.0;
    CGFloat messageScrollWidth = conversationWidth - 16.0;
    if (messageScrollWidth < 260.0) {
        messageScrollWidth = 260.0;
    }
    NSRect messageSurfaceFrame = NSMakeRect(messageScrollX, messageBottom, messageScrollWidth, messageHeight);
    [self.messageScrollSurfaceView setFrame:messageSurfaceFrame];
    [self.messageScrollView setFrame:NSInsetRect(messageSurfaceFrame, 5.0, 5.0)];
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (bubbleColumn) {
        [self.messageScrollView tile];
        CGFloat bubbleWidth = NSWidth([[self.messageScrollView contentView] bounds]);
        if (bubbleWidth < 260.0) {
            bubbleWidth = 260.0;
        }
        [bubbleColumn setWidth:bubbleWidth];
    }

    CGFloat sendButtonWidth = 38.0;
    CGFloat sendFieldX = conversationX + 14.0;
    CGFloat sendButtonX = conversationX + conversationWidth - sendButtonWidth - 12.0;
    CGFloat sendFieldWidth = sendButtonX - sendFieldX - 10.0;
    if (sendFieldWidth < 160.0) {
        sendFieldWidth = 160.0;
    }
    [self.sendLabel setFrame:NSMakeRect(conversationX + 14.0, composerY + 8.0, 0.0, 22.0)];
    [self.sendTextFieldBackgroundView setFrame:NSMakeRect(sendFieldX, composerY + 6.0, sendFieldWidth, 30.0)];
    [self.sendTextField setFrame:NSMakeRect(sendFieldX + 8.0, composerY + 11.0, sendFieldWidth - 16.0, 20.0)];
    [self.sendMessageButton setFrame:NSMakeRect(sendButtonX, composerY + 5.0, sendButtonWidth, 32.0)];

    CGFloat panelTitleY = headerLabelY;
    CGFloat contentTop = mainTop - TGPanelHeaderHeight;
    CGFloat groupedWidth = mainWidth - 56.0;
    if (groupedWidth > 760.0) {
        groupedWidth = 760.0;
    }
    if (groupedWidth < 360.0) {
        groupedWidth = mainWidth - 32.0;
    }
    CGFloat groupedX = mainX + floor((mainWidth - groupedWidth) / 2.0);

    [self.profileTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];
    CGFloat profileSummaryHeight = 124.0;
    CGFloat profileSummaryY = contentTop - profileSummaryHeight - 22.0;
    [self.profileSummaryCardView setFrame:NSMakeRect(groupedX, profileSummaryY, groupedWidth, profileSummaryHeight)];
    CGFloat profileAvatarSize = 78.0;
    CGFloat profileAvatarX = groupedX + 26.0;
    CGFloat profileAvatarY = profileSummaryY + floor((profileSummaryHeight - profileAvatarSize) / 2.0);
    [self.profileAvatarView setFrame:NSMakeRect(profileAvatarX,
                                                profileAvatarY,
                                                profileAvatarSize,
                                                profileAvatarSize)];
    CGFloat profileTextX = NSMaxX([self.profileAvatarView frame]) + 24.0;
    CGFloat profileTextWidth = groupedWidth - (profileTextX - groupedX) - 26.0;
    if (profileTextWidth < 180.0) {
        profileTextWidth = groupedWidth - 52.0;
        profileTextX = groupedX + 26.0;
    }
    [self.profileNameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 68.0, profileTextWidth, 24.0)];
    [self.profileUsernameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 40.0, profileTextWidth, 22.0)];

    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    CGFloat profileNextTop = profileSummaryY - 14.0;

    if (profileHasBio) {
        [self.profileAboutSectionField setFrame:NSMakeRect(groupedX + 20.0, profileNextTop - 18.0, groupedWidth - 40.0, 16.0)];
        NSDictionary *bioAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont systemFontOfSize:13.0], NSFontAttributeName,
                                       nil];
        NSString *bioText = [self.profileStateField stringValue];
        NSRect bioRect = [bioText boundingRectWithSize:NSMakeSize(groupedWidth - 48.0, 1000.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:bioAttributes];
        CGFloat bioTextHeight = ceil(NSHeight(bioRect));
        CGFloat profileInfoHeight = bioTextHeight + 30.0;
        if (profileInfoHeight < 58.0) {
            profileInfoHeight = 58.0;
        }
        if (profileInfoHeight > 112.0) {
            profileInfoHeight = 112.0;
        }
        CGFloat profileInfoY = profileNextTop - 18.0 - profileInfoHeight - 8.0;
        [self.profileInfoCardView setFrame:NSMakeRect(groupedX, profileInfoY, groupedWidth, profileInfoHeight)];
        [self.profileStateField setFrame:NSMakeRect(groupedX + 24.0, profileInfoY + 14.0, groupedWidth - 48.0, profileInfoHeight - 26.0)];
        profileNextTop = profileInfoY - 14.0;
    } else {
        [self.profileAboutSectionField setFrame:NSMakeRect(groupedX + 20.0, profileNextTop, groupedWidth - 40.0, 0.0)];
        [self.profileInfoCardView setFrame:NSMakeRect(groupedX, profileNextTop, groupedWidth, 0.0)];
        [self.profileStateField setFrame:NSMakeRect(groupedX + 24.0, profileNextTop, groupedWidth - 48.0, 0.0)];
    }

    if (profileDetailRows > 0) {
        CGFloat rowHeight = 42.0;
        CGFloat detailsHeight = ((CGFloat)profileDetailRows * rowHeight) + 12.0;
        CGFloat accountSectionY = profileNextTop - 18.0;
        CGFloat detailsY = accountSectionY - detailsHeight - 8.0;
        [self.profileAccountSectionField setFrame:NSMakeRect(groupedX + 20.0, accountSectionY, groupedWidth - 40.0, 16.0)];
        [self.profileDetailsCardView setFrame:NSMakeRect(groupedX, detailsY, groupedWidth, detailsHeight)];

        CGFloat rowTitleX = groupedX + 24.0;
        CGFloat rowValueX = groupedX + 210.0;
        CGFloat rowValueWidth = groupedWidth - 234.0;
        if (rowValueWidth < 160.0) {
            rowValueX = groupedX + 150.0;
            rowValueWidth = groupedWidth - 174.0;
        }
        CGFloat rowY = detailsY + detailsHeight - 31.0;
        NSUInteger laidOutRows = 0;
        CGFloat separatorOneY = 0.0;
        CGFloat separatorTwoY = 0.0;

        if (profileHasUsername) {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            separatorOneY = rowY - 11.0;
            rowY -= rowHeight;
        } else {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasPhone) {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            if (laidOutRows == 1) {
                separatorOneY = rowY - 11.0;
            } else {
                separatorTwoY = rowY - 11.0;
            }
            rowY -= rowHeight;
        } else {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasID) {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
        } else {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileDetailRows > 1) {
            [self.profileDetailsSeparatorOne setFrame:NSMakeRect(groupedX + 24.0, separatorOneY, groupedWidth - 48.0, 1.0)];
        }
        if (profileDetailRows > 2) {
            if (separatorTwoY <= 0.0) {
                separatorTwoY = separatorOneY - rowHeight;
            }
            [self.profileDetailsSeparatorTwo setFrame:NSMakeRect(groupedX + 24.0, separatorTwoY, groupedWidth - 48.0, 1.0)];
        }
        profileNextTop = detailsY - 14.0;
    } else {
        [self.profileAccountSectionField setFrame:NSMakeRect(groupedX + 20.0, profileNextTop, groupedWidth - 40.0, 0.0)];
        [self.profileDetailsCardView setFrame:NSMakeRect(groupedX, profileNextTop, groupedWidth, 0.0)];
        [self.profileUsernameRowTitleField setFrame:NSMakeRect(groupedX + 24.0, profileNextTop, 0.0, 0.0)];
        [self.profileUsernameRowValueField setFrame:NSMakeRect(groupedX + 210.0, profileNextTop, 0.0, 0.0)];
        [self.profilePhoneRowTitleField setFrame:NSMakeRect(groupedX + 24.0, profileNextTop, 0.0, 0.0)];
        [self.profilePhoneRowValueField setFrame:NSMakeRect(groupedX + 210.0, profileNextTop, 0.0, 0.0)];
        [self.profileIDRowTitleField setFrame:NSMakeRect(groupedX + 24.0, profileNextTop, 0.0, 0.0)];
        [self.profileIDRowValueField setFrame:NSMakeRect(groupedX + 210.0, profileNextTop, 0.0, 0.0)];
    }

    CGFloat profileActionsHeight = 54.0;
    CGFloat profileActionsY = profileNextTop - profileActionsHeight;
    [self.profileActionsCardView setFrame:NSMakeRect(groupedX, profileActionsY, groupedWidth, profileActionsHeight)];
    [self.logoutButton setFrame:NSMakeRect(groupedX + 22.0, profileActionsY + 12.0, groupedWidth - 44.0, 30.0)];
    [self.profileIDField setFrame:NSMakeRect(groupedX + 22.0, profileActionsY, 0.0, 0.0)];

    [self.settingsTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];
    CGFloat themeCardY = contentTop - 96.0;
    [self.settingsThemeCardView setFrame:NSMakeRect(groupedX, themeCardY, groupedWidth, 54.0)];
    CGFloat themePopupWidth = 300.0;
    if (themePopupWidth > groupedWidth - 150.0) {
        themePopupWidth = groupedWidth - 150.0;
    }
    if (themePopupWidth < 180.0) {
        themePopupWidth = 180.0;
    }
    CGFloat themeLabelWidth = 72.0;
    CGFloat themeClusterWidth = themeLabelWidth + 16.0 + themePopupWidth;
    CGFloat themeClusterX = groupedX + floor((groupedWidth - themeClusterWidth) / 2.0);
    if (themeClusterX < groupedX + 22.0) {
        themeClusterX = groupedX + 22.0;
    }
    [self.settingsThemeLabel setFrame:NSMakeRect(themeClusterX, themeCardY + 17.0, themeLabelWidth, 20.0)];
    [self.themePopUpButton setFrame:NSMakeRect(themeClusterX + themeLabelWidth + 16.0,
                                               themeCardY + 12.0,
                                               themePopupWidth,
                                               30.0)];

    CGFloat sessionCardHeight = 164.0;
    CGFloat sessionCardY = contentTop - sessionCardHeight - 22.0;
    [self.settingsSessionCardView setFrame:NSMakeRect(groupedX, sessionCardY, groupedWidth, sessionCardHeight)];
    CGFloat settingsButtonWidth = groupedWidth - 28.0;
    CGFloat settingsButtonX = groupedX + 14.0;
    [self.settingsAppearanceButton setFrame:NSMakeRect(settingsButtonX, sessionCardY + 110.0, settingsButtonWidth, 42.0)];
    [self.settingsLogsButton setFrame:NSMakeRect(settingsButtonX, sessionCardY + 62.0, settingsButtonWidth, 42.0)];
    [self.settingsAboutButton setFrame:NSMakeRect(settingsButtonX, sessionCardY + 14.0, settingsButtonWidth, 42.0)];

    CGFloat aboutWidth = groupedWidth;
    if (aboutWidth > 560.0) {
        aboutWidth = 560.0;
    }
    CGFloat aboutX = mainX + floor((mainWidth - aboutWidth) / 2.0);
    CGFloat aboutHeight = 326.0;
    CGFloat aboutY = contentTop - aboutHeight - 24.0;
    [self.aboutCardView setFrame:NSMakeRect(aboutX, aboutY, aboutWidth, aboutHeight)];
    CGFloat aboutIconSize = 118.0;
    CGFloat aboutCenterX = aboutX + (aboutWidth / 2.0);
    [self.aboutIconView setFrame:NSMakeRect(aboutCenterX - (aboutIconSize / 2.0), aboutY + aboutHeight - aboutIconSize - 26.0, aboutIconSize, aboutIconSize)];
    [self.aboutTitleField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 134.0, aboutWidth - 72.0, 30.0)];
    [self.aboutVersionField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 104.0, aboutWidth - 72.0, 22.0)];
    [self.aboutCopyrightField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 72.0, aboutWidth - 72.0, 22.0)];
    [self.aboutLinkField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 40.0, aboutWidth - 72.0, 22.0)];

    [self.diagnosticsLabel setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 160.0, 18.0)];
    [self.checkButton setFrame:NSMakeRect(mainX + mainWidth - 166.0, headerButtonY, 150.0, headerButtonSize)];
    CGFloat logsCardX = mainX + 18.0;
    CGFloat logsCardY = mainY + 18.0;
    CGFloat logsCardWidth = mainWidth - 36.0;
    CGFloat logsCardHeight = mainHeight - TGPanelHeaderHeight - 36.0;
    [self.logsCardView setFrame:NSMakeRect(logsCardX, logsCardY, logsCardWidth, logsCardHeight)];
    [self.detailsScrollView setFrame:NSMakeRect(logsCardX + 12.0, logsCardY + 12.0, logsCardWidth - 24.0, logsCardHeight - 24.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
    if ([notification object] != [self window]) {
        return;
    }
    [self layoutContentView];
    [self.messageTableView reloadData];
    [self updateVisibleSection];
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == self.mediaPreviewWindow) {
        self.mediaPreviewRequestGeneration = self.mediaPreviewRequestGeneration + 1;
        self.mediaPreviewPath = nil;
        self.mediaPreviewZoomScale = 1.0;
        [self.mediaPreviewImageView setImage:nil];
    }
}

- (void)startLiveUpdateTimerIfNeeded {
    if (self.liveUpdateTimer) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(pollLiveUpdates:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.liveUpdateTimer = timer;
}

- (void)stopLiveUpdateTimer {
    if (!self.liveUpdateTimer) {
        return;
    }

    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)prepareForApplicationTermination {
    [self stopLiveUpdateTimer];
    [self setControlsBusy:YES];
    [self.client shutdownWithTimeout:3.0];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (void)updateSendControls {
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    BOOL canTargetChat = [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget;
    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.sendTextField setEnabled:canTargetChat];
    [self.sendMessageButton setEnabled:(canTargetChat && [trimmedText length] > 0 && [text length] <= 4096)];
}

- (void)refocusComposerIfPossible {
    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        (self.showingForumTopicList && self.selectedMessageThreadID == nil) ||
        [self.sendTextField isHidden]) {
        return;
    }
    [self updateSendControls];
    [self.sendTextField setEnabled:YES];
    [[self window] makeFirstResponder:self.sendTextField];
}

- (void)consumePendingComposerRefocus:(id)sender {
    (void)sender;
    if (!self.composerRefocusPending) {
        return;
    }
    if (self.controlsBusy || self.backgroundMessageRefreshInFlight) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(consumePendingComposerRefocus:)
                                                   object:nil];
        [self performSelector:@selector(consumePendingComposerRefocus:)
                    withObject:nil
                    afterDelay:0.12];
        return;
    }
    self.composerRefocusPending = NO;
    [self refocusComposerIfPossible];
}

- (void)requestComposerRefocus {
    self.composerRefocusPending = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(consumePendingComposerRefocus:)
                                               object:nil];
    [self performSelector:@selector(consumePendingComposerRefocus:)
                withObject:nil
                afterDelay:0.05];
}

- (BOOL)canLoadMoreChats {
    return (!self.controlsBusy &&
            [self.currentAuthState isEqualToString:@"ready"] &&
            !self.showingForumTopicList &&
            [self.chatItems count] > 0 &&
            !self.chatsExhausted &&
            [self.chatItems count] < TGStatusChatPreviewMaximumLimit);
}

- (void)updateAuthControlsForState:(NSString *)state {
    NSString *previousState = [self.currentAuthState copy];
    self.currentAuthState = state;
    [self.authTextField setStringValue:@""];
    [self.authSecureField setStringValue:@""];
    [self.loadChatsButton setEnabled:NO];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.sendMessageButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.selectedChatTypeSummary = nil;
        self.selectedChatAvatarLocalPath = nil;
        self.selectedMessageThreadID = nil;
        self.selectedMessageTopicKind = nil;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self refreshSelectedChatHeaderDisplay];
        [self.sendTextField setStringValue:@""];
        self.activeSection = TGSectionChats;
    }

    if (![state isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        self.drawerOpen = NO;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        self.selectedChatFilterID = nil;
        self.chatFilterInfos = [NSArray array];
        self.chatFilterRefreshRetryCount = 0;
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(reloadChatFiltersIfReady)
                                                   object:nil];
        self.profileSummaryLoaded = NO;
        [self clearProfileDisplayCache];
        [self.client invalidateMainChatListExhaustion];
        self.pendingLiveChatRefresh = NO;
        self.pendingLiveMessageRefresh = NO;
    } else if (![previousState isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        self.chatFilterRefreshRetryCount = 0;
        if ([self.chatItems count] == 0) {
            self.pendingLiveChatRefresh = YES;
            [self handlePendingLiveRefreshesIfPossible];
        }
    }

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.statusField setStringValue:@"Sign in required"];
        [self.loginTitleField setStringValue:@"Sign in to Telegram"];
        [self.loginHintField setStringValue:@"Enter the phone number connected to your Telegram account."];
        [self.authLabel setStringValue:@"Phone number"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Continue"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.statusField setStringValue:@"Login code required"];
        [self.loginTitleField setStringValue:@"Enter login code"];
        [self.loginHintField setStringValue:@"Telegram sent a login code to your account. Enter it here to continue."];
        [self.authLabel setStringValue:@"Login code"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Verify"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.statusField setStringValue:@"Password required"];
        [self.loginTitleField setStringValue:@"Two-step password"];
        [self.loginHintField setStringValue:@"Enter your Telegram cloud password. It is sent only to TDLib and is not logged."];
        [self.authLabel setStringValue:@"Password:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Unlock"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    [self.authLabel setStringValue:@"Status"];
    if ([state isEqualToString:@"ready"]) {
        [self.statusField setStringValue:@"Connected"];
        [self.authStateField setStringValue:@"ready"];
    } else if ([state length] > 0) {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:state];
    } else {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@"Preparing connection..."];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [self.authButton setTitle:@"Send"];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:([state isEqualToString:@"ready"] && hasMessageTarget && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self.logoutButton setEnabled:([state isEqualToString:@"ready"] && !self.controlsBusy)];
    [self updateSendControls];
    [self refreshProfileDisplay];
    [self updateVisibleSection];
    if ([state isEqualToString:@"ready"] && !self.profileSummaryLoaded && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }

    [previousState release];
}

- (void)setControlsBusy:(BOOL)busy {
    _controlsBusy = busy;
    [self.checkButton setEnabled:!busy];
    [self.logsCheckButton setEnabled:!busy];
    [self.logoutButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self updateNavigationButtonsForSection:(self.activeSection ? self.activeSection : TGSectionChats) enabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self.sendTextField setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.sendMessageButton setEnabled:NO];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMoreChatsButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
        [self.loadOlderMessagesButton setEnabled:NO];
        [self.logoutButton setEnabled:NO];
        [self.chatTableView setEnabled:NO];
        [self.messageTableView setEnabled:NO];
        [self.sendTextField setEnabled:NO];
        [self.sendMessageButton setEnabled:NO];
    } else {
        [self.chatTableView setEnabled:YES];
        [self.messageTableView setEnabled:YES];
        [self updateAuthControlsForState:self.currentAuthState];
        [self handlePendingLiveRefreshesIfPossible];
    }
    [self updateVisibleSection];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.sendTextField) {
        [self updateSendControls];
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (control == self.sendTextField && commandSelector == @selector(insertNewline:)) {
        [self sendMessage:control];
        return YES;
    }
    if ((control == self.authTextField || control == self.authSecureField) && commandSelector == @selector(insertNewline:)) {
        [self submitAuthInput:control];
        return YES;
    }
    return NO;
}

- (void)appendDetail:(NSString *)detail {
    if (![detail isKindOfClass:[NSString class]] || [detail length] == 0) {
        return;
    }
    NSString *current = [self.detailsView string];
    NSString *section = TGLogSectionForDetail(detail);
    NSMutableString *addition = [NSMutableString string];
    if (![self.lastLogSection isEqualToString:section]) {
        [addition appendFormat:@"%@%@\n", ([current length] > 0 ? @"\n" : @""), section];
        self.lastLogSection = section;
    }
    [addition appendFormat:@"%@  %@\n", TGLogTimestampString(), detail];
    [self.detailsView setString:[current stringByAppendingString:addition]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
    if (self.logsWindowDetailsView) {
        [self.logsWindowDetailsView setString:[self.detailsView string]];
        NSRange logsEndRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
        [self.logsWindowDetailsView scrollRangeToVisible:logsEndRange];
    }
}

- (NSRect)messageBubbleCellFrameForRow:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return NSZeroRect;
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (!bubbleColumn) {
        return NSZeroRect;
    }
    NSUInteger columnIndex = [[self.messageTableView tableColumns] indexOfObject:bubbleColumn];
    if (columnIndex == NSNotFound) {
        return NSZeroRect;
    }
    return [self.messageTableView frameOfCellAtColumn:(NSInteger)columnIndex row:row];
}

- (NSDictionary *)mediaItemForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isVisualMediaMessage] || NSIsEmptyRect(cellFrame)) {
        return nil;
    }

    NSString *messageText = [item isStickerMessage] ? @"" : TGDisplayTextForMessageItem(item);
    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
        }
    }

    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [composedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                         options:NSStringDrawingUsesLineFragmentOrigin];
    }

    NSSize photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    CGFloat photoBubbleWidth = photoSize.width + 16.0;
    if (photoBubbleWidth > bubbleWidth) {
        bubbleWidth = photoBubbleWidth;
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat bubbleHeight = photoSize.height + 24.0;
    if (NSHeight(measuredRect) > 0.0) {
        bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                  contentTop - photoSize.height,
                                  photoSize.width,
                                  photoSize.height);
    if (!NSPointInRect(tablePoint, imageRect)) {
        return nil;
    }

    NSArray *mediaItems = [item visualMediaItems];
    NSArray *tileRects = TGMediaTileRectsForMessageItem(item, imageRect);
    NSUInteger tileIndex = 0;
    NSUInteger tileCount = [tileRects count];
    NSUInteger mediaCount = [mediaItems count];
    for (tileIndex = 0; tileIndex < tileCount && tileIndex < mediaCount; tileIndex++) {
        NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
        if (!NSPointInRect(tablePoint, tileRect)) {
            continue;
        }
        id mediaObject = [mediaItems objectAtIndex:tileIndex];
        if (![mediaObject isKindOfClass:[NSDictionary class]]) {
            return nil;
        }
        return (NSDictionary *)mediaObject;
    }
    return nil;
}

- (NSURL *)messageLinkURLForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || NSIsEmptyRect(cellFrame)) {
        return nil;
    }
    NSString *messageText = TGDisplayTextForMessageItem(item);
    if ([messageText length] == 0 || !TGFirstURLInMessageItem(item)) {
        return nil;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
        }
    }
    NSAttributedString *attributedMessageText = composedMessageText;
    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [attributedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
    } else {
        measuredRect = NSZeroRect;
    }
    NSSize photoSize = NSZeroSize;
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0;
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    if (visualMediaMessage) {
        NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                      contentTop - photoSize.height,
                                      photoSize.width,
                                      photoSize.height);
        contentTop = NSMinY(imageRect) - 8.0;
    }

    CGFloat textHeight = ceil(NSHeight(measuredRect));
    if (textHeight <= 0.0) {
        return nil;
    }
    NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                 contentTop - textHeight,
                                 NSWidth(bubbleRect) - 24.0,
                                 textHeight + 2.0);
    if (!NSPointInRect(tablePoint, textRect)) {
        return nil;
    }

    NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:attributedMessageText] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
    NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSWidth(textRect), 1000.0)] autorelease];
    [textContainer setLineFragmentPadding:0.0];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];

    NSPoint textPoint = NSMakePoint(tablePoint.x - NSMinX(textRect), tablePoint.y - NSMinY(textRect));
    CGFloat fraction = 0.0;
    NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:textPoint
                                               inTextContainer:textContainer
                        fractionOfDistanceThroughGlyph:&fraction];
    if (glyphIndex >= [layoutManager numberOfGlyphs]) {
        return nil;
    }
    NSRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                inTextContainer:textContainer];
    if (!NSPointInRect(textPoint, NSInsetRect(glyphRect, -3.0, -4.0))) {
        return nil;
    }
    NSUInteger characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    if (characterIndex >= [messageText length]) {
        return nil;
    }
    return TGURLAtCharacterIndexInString(messageText, characterIndex);
}

- (void)openMessageLink:(id)sender {
    (void)sender;
    NSInteger row = [self.messageTableView clickedRow];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSEvent *event = [NSApp currentEvent];
    if (!event) {
        return;
    }
    NSPoint tablePoint = [self.messageTableView convertPoint:[event locationInWindow] fromView:nil];
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:tablePoint];
    if (mediaItem) {
        [self openMediaPreviewForMediaItem:mediaItem];
        return;
    }

    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:tablePoint];
    if (!url) {
        return;
    }
    if ([[NSWorkspace sharedWorkspace] openURL:url]) {
        [self appendDetail:@"Opened message link in default browser."];
    } else {
        [self appendDetail:@"Could not open message link in default browser."];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.messageTableView) {
        return (NSInteger)[self.messageItems count];
    }
    return (NSInteger)[self.chatItems count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != self.messageTableView) {
        return [tableView rowHeight];
    }
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return [tableView rowHeight];
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return [tableView rowHeight];
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    CGFloat availableWidth = bubbleColumn ? [bubbleColumn width] : NSWidth([self.messageScrollView frame]);
    return TGMessageBubbleHeightForItem((TGMessageItem *)item, availableWidth);
}

- (NSString *)tableView:(NSTableView *)tableView
      toolTipForCell:(NSCell *)cell
                rect:(NSRectPointer)rect
         tableColumn:(NSTableColumn *)tableColumn
                 row:(NSInteger)row
       mouseLocation:(NSPoint)mouseLocation {
    (void)cell;
    (void)rect;
    (void)tableColumn;
    (void)mouseLocation;
    if (tableView != self.messageTableView || row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return nil;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:mouseLocation];
    if (mediaItem) {
        return @"Open media preview";
    }
    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:mouseLocation];
    return url ? @"Open link in default browser" : nil;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    id identifier = [tableColumn identifier];
    if (tableView == self.chatTableView && [identifier isEqual:@"chat"] && [cell isKindOfClass:[TGChatListCell class]]) {
        TGChatItem *chatItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.chatItems count]) {
            id item = [self.chatItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGChatItem class]]) {
                chatItem = (TGChatItem *)item;
            }
        }
        [(TGChatListCell *)cell setHighlighted:[tableView isRowSelected:row]];
        [(TGChatListCell *)cell setChatItem:chatItem];
        return;
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"bubble"] && [cell isKindOfClass:[TGMessageBubbleCell class]]) {
        TGMessageItem *messageItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.messageItems count]) {
            id item = [self.messageItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGMessageItem class]]) {
                messageItem = (TGMessageItem *)item;
            }
        }
        [(TGMessageBubbleCell *)cell setMessageItem:messageItem];
        return;
    }
    [textCell setAlignment:NSLeftTextAlignment];
    [textCell setFont:[NSFont systemFontOfSize:12.0]];
    [textCell setTextColor:TGClassicInkColor()];
    [textCell setDrawsBackground:NO];
    [textCell setLineBreakMode:NSLineBreakByTruncatingTail];

    if (tableView == self.chatTableView) {
        BOOL selected = [tableView isRowSelected:row];
        if (selected) {
            [textCell setDrawsBackground:YES];
            [textCell setBackgroundColor:TGClassicSelectedRowColor()];
            [textCell setTextColor:TGClassicSelectedRowTextColor()];
        }
        if ([identifier isEqual:@"title"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:12.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicInkColor()];
            }
        } else if ([identifier isEqual:@"unread_count"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicUnreadTextColor()];
            }
            [textCell setAlignment:NSCenterTextAlignment];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicMutedInkColor()];
            }
        }
    } else if (tableView == self.messageTableView) {
        if ([identifier isEqual:@"date"] || [identifier isEqual:@"direction"]) {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            [textCell setTextColor:TGClassicMutedInkColor()];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:12.0]];
            [textCell setTextColor:TGClassicInkColor()];
        }
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    id item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = nil;
    if (tableView == self.messageTableView && [item isKindOfClass:[TGMessageItem class]]) {
        if ([identifier isEqual:@"bubble"]) {
            value = @"";
        } else {
            value = [(TGMessageItem *)item valueForTableColumnIdentifier:identifier];
        }
    } else if (tableView == self.chatTableView && [item isKindOfClass:[TGChatItem class]]) {
        if ([identifier isEqual:@"chat"]) {
            value = @"";
        } else {
            value = [(TGChatItem *)item valueForTableColumnIdentifier:identifier];
        }
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"date"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger timestamp = [value integerValue];
        if (timestamp <= 0) {
            return @"";
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
        return [NSDateFormatter localizedStringFromDate:date
                                              dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
    }
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger unreadCount = [value integerValue];
        if (unreadCount <= 0) {
            return @"";
        }
        if (unreadCount > 999) {
            return @"999+";
        }
        return [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }
    return value ? value : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] != self.chatTableView) {
        return;
    }
    if (self.suppressChatSelectionHandling) {
        return;
    }

    NSNumber *previousChatID = [self.selectedChatID retain];
    NSNumber *previousThreadID = [self.selectedMessageThreadID retain];
    NSString *previousTopicKind = [self.selectedMessageTopicKind copy];
    NSInteger clickedRow = [self.chatTableView clickedRow];
    NSInteger row = (clickedRow >= 0) ? clickedRow : [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.selectedChatTypeSummary = nil;
        self.selectedChatAvatarLocalPath = nil;
        self.selectedMessageThreadID = nil;
        self.selectedMessageTopicKind = nil;
        [self refreshSelectedChatHeaderDisplay];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateAuthControlsForState:self.currentAuthState];
        [previousChatID release];
        [previousThreadID release];
        [previousTopicKind release];
        return;
    }

    TGChatItem *item = [[self.chatItems objectAtIndex:(NSUInteger)row] retain];
    BOOL selectedForumTopic = [item isForumTopic];
    id chatID = selectedForumTopic ? [item parentChatID] : [item chatID];
    id title = [item title];
    NSNumber *newChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        newChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        self.selectedChatID = newChatID;
    } else {
        self.selectedChatID = nil;
    }
    NSNumber *newThreadID = nil;
    NSString *newTopicKind = nil;
    if (selectedForumTopic && [[item messageThreadID] respondsToSelector:@selector(longLongValue)]) {
        newThreadID = [NSNumber numberWithLongLong:[[item messageThreadID] longLongValue]];
        newTopicKind = [[item messageTopicKind] length] > 0 ? [item messageTopicKind] : @"forum";
    }
    self.selectedMessageThreadID = newThreadID;
    self.selectedMessageTopicKind = newTopicKind;

    BOOL sameChat = ((previousChatID && newChatID) && ([previousChatID longLongValue] == [newChatID longLongValue]));
    BOOL sameThread = ((!previousThreadID && !newThreadID) ||
                       (previousThreadID && newThreadID && [previousThreadID longLongValue] == [newThreadID longLongValue]));
    BOOL sameTopicKind = ((!previousTopicKind && !newTopicKind) ||
                          (previousTopicKind && newTopicKind && [previousTopicKind isEqualToString:newTopicKind]));
    BOOL selectionChanged = !(sameChat && sameThread && sameTopicKind);
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"Selected chat";
    self.selectedChatTypeSummary = [item typeSummary];
    self.selectedChatAvatarLocalPath = [item avatarLocalPath];
    [self refreshSelectedChatHeaderDisplay];
    if (selectionChanged) {
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
    }
    [self updateAuthControlsForState:self.currentAuthState];
    BOOL shouldOpenTopicList = (!selectedForumTopic && !self.showingForumTopicList && [[item typeSummary] isEqualToString:@"Supergroup"]);
    if (selectedForumTopic) {
        if (newThreadID) {
            [self appendDetail:[NSString stringWithFormat:@"Forum topic selected: %@ (%lld).", self.selectedChatTitle ? self.selectedChatTitle : @"Topic", [newThreadID longLongValue]]];
        }
    } else if (shouldOpenTopicList) {
        [self removeForumTopicRowsPreservingChatID:newChatID];
        [self loadForumTopicsForChatItem:item];
    }
    if (newChatID && (selectionChanged || [self.messageItems count] == 0)) {
        if (selectedForumTopic) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
        } else if (!shouldOpenTopicList) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
        }
    }
    [previousChatID release];
    [previousThreadID release];
    [previousTopicKind release];
    [item release];
}

- (void)activateSelectedChatRow:(id)sender {
    (void)sender;
    if (self.suppressChatSelectionHandling || self.showingForumTopicList || self.forumTopicRefreshInFlight) {
        return;
    }

    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        return;
    }

    id candidate = [self.chatItems objectAtIndex:(NSUInteger)row];
    if (![candidate isKindOfClass:[TGChatItem class]]) {
        return;
    }

    TGChatItem *item = [(TGChatItem *)candidate retain];
    if ([item isForumTopic] || ![[item typeSummary] isEqualToString:@"Supergroup"]) {
        [item release];
        return;
    }

    id chatID = [item chatID];
    NSNumber *selectedChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    }
    [self removeForumTopicRowsPreservingChatID:selectedChatID];
    [self loadForumTopicsForChatItem:item];
    [item release];
}

- (void)applyChatItems:(NSArray *)items preserveSelection:(BOOL)preserveSelection preferredChatID:(NSNumber *)preferredChatID {
    [self clearForumTopicListState];
    NSUInteger selectedIndex = NSNotFound;

    if (preserveSelection && preferredChatID) {
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            TGChatItem *item = [items objectAtIndex:index];
            id chatID = [item chatID];
            if ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [preferredChatID longLongValue]) {
                selectedIndex = index;
                break;
            }
        }
    }

    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:items];
    [self.chatTableView reloadData];
    self.autoChatListLoadArmed = YES;

    if (selectedIndex != NSNotFound) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:selectedIndex];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        return;
    }

    if ([items count] > 0 && [self.currentAuthState isEqualToString:@"ready"]) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:0];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:0];
        return;
    }

    [self.chatTableView deselectAll:nil];
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    self.selectedChatTypeSummary = nil;
    self.selectedChatAvatarLocalPath = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self.sendTextField setStringValue:@""];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self updateAuthControlsForState:self.currentAuthState];
}

- (BOOL)chatItemsContainForumTopicRows {
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id item = [self.chatItems objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray *)chatItemsByRemovingForumTopicRowsFromItems:(NSArray *)items {
    NSMutableArray *baseItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        [baseItems addObject:item];
    }
    return baseItems;
}

- (NSUInteger)indexOfChatID:(NSNumber *)chatID inChatItems:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return NSNotFound;
    }
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if (![item isKindOfClass:[TGChatItem class]] || [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        id itemChatID = [(TGChatItem *)item chatID];
        if ([itemChatID respondsToSelector:@selector(longLongValue)] && [itemChatID longLongValue] == [chatID longLongValue]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)removeForumTopicRowsPreservingChatID:(NSNumber *)chatID {
    if (![self chatItemsContainForumTopicRows]) {
        return;
    }
    NSArray *baseItems = [self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems];
    NSUInteger selectedIndex = [self indexOfChatID:chatID inChatItems:baseItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:baseItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
    }
    self.suppressChatSelectionHandling = NO;
}

- (NSString *)displayTitleForTopicItem:(TGChatItem *)item {
    NSString *title = [item title];
    if (![title isKindOfClass:[NSString class]]) {
        return @"Topic";
    }
    return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)showForumTopicListForChatItem:(TGChatItem *)chatItem topics:(NSArray *)topics {
    if (!chatItem || [topics count] == 0) {
        return;
    }

    self.chatItemsBeforeTopicList = [NSArray arrayWithArray:[self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems]];
    self.topicParentChatID = [chatItem chatID];
    self.topicParentTitle = [chatItem title];
    self.topicParentAvatarLocalPath = [chatItem avatarLocalPath];
    self.showingForumTopicList = YES;
    [self.loadChatsButton setToolTip:@"Refresh topics"];
    self.chatsExhausted = YES;
    self.autoChatListLoadArmed = NO;

    NSMutableArray *topicItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [topics count]; index++) {
        id candidate = [topics objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *topicItem = (TGChatItem *)candidate;
        [topicItem setAvatarLocalPath:self.topicParentAvatarLocalPath];
        [topicItems addObject:topicItem];
    }

    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:topicItems];
    [self.chatTableView reloadData];
    [self.chatTableView deselectAll:nil];
    self.suppressChatSelectionHandling = NO;

    self.selectedChatID = self.topicParentChatID;
    self.selectedChatTitle = self.topicParentTitle;
    self.selectedChatTypeSummary = @"Forum";
    self.selectedChatAvatarLocalPath = self.topicParentAvatarLocalPath;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self.sendTextField setStringValue:@""];
    NSString *topicListTitle = ([self.topicParentTitle length] > 0 ? self.topicParentTitle : @"Topics");
    [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
}

- (void)closeForumTopicList:(id)sender {
    (void)sender;
    if (!self.showingForumTopicList) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    self.showingForumTopicList = NO;
    self.topicParentChatID = nil;
    self.topicParentTitle = nil;
    self.topicParentAvatarLocalPath = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    self.chatsExhausted = NO;

    NSArray *restoreItems = self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : [NSArray array];
    NSUInteger selectedIndex = [self indexOfChatID:parentChatID inChatItems:restoreItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:restoreItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
    } else {
        [self.chatTableView deselectAll:nil];
    }
    self.suppressChatSelectionHandling = NO;
    self.chatItemsBeforeTopicList = nil;
    [self.chatsLabel setStringValue:@"Chats"];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
    [parentChatID release];
}

- (void)reloadCurrentForumTopicListInteractive:(BOOL)interactive {
    if (!self.showingForumTopicList || ![self.topicParentChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    NSString *parentTitle = [self.topicParentTitle copy];
    NSString *parentAvatarPath = [self.topicParentAvatarLocalPath copy];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading topics..."];
        [self appendDetail:@"Reloading forum topics from TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:parentChatID limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL stillCurrent = (self.showingForumTopicList && self.topicParentChatID && [self.topicParentChatID longLongValue] == [parentChatID longLongValue]);
            if (stillCurrent && [topics count] > 0) {
                NSMutableArray *topicItems = [NSMutableArray array];
                NSUInteger index = 0;
                for (index = 0; index < [topics count]; index++) {
                    id candidate = [topics objectAtIndex:index];
                    if (![candidate isKindOfClass:[TGChatItem class]]) {
                        continue;
                    }
                    TGChatItem *topicItem = (TGChatItem *)candidate;
                    [topicItem setAvatarLocalPath:parentAvatarPath];
                    [topicItems addObject:topicItem];
                }
                self.suppressChatSelectionHandling = YES;
                [self.chatItems removeAllObjects];
                [self.chatItems addObjectsFromArray:topicItems];
                [self.chatTableView reloadData];
                [self.chatTableView deselectAll:nil];
                self.suppressChatSelectionHandling = NO;
                self.selectedChatID = parentChatID;
                self.selectedChatTitle = parentTitle;
                self.selectedChatTypeSummary = @"Forum";
                self.selectedChatAvatarLocalPath = parentAvatarPath;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                [self refreshSelectedChatHeaderDisplay];
                [self.messageItems removeAllObjects];
                [self.messageTableView reloadData];
                NSString *topicListTitle = ([parentTitle length] > 0 ? parentTitle : @"Topics");
                [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: loaded %lu topics.", (unsigned long)[topicItems count]]];
            } else if (stillCurrent && [topicErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            }
            [topics release];
            [topicErrorMessage release];
            [parentChatID release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}

- (void)loadForumTopicsForChatItem:(TGChatItem *)chatItem {
    if (!chatItem || [chatItem isForumTopic] || self.forumTopicRefreshInFlight) {
        return;
    }
    id chatID = [chatItem chatID];
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    if (![[chatItem typeSummary] isEqualToString:@"Supergroup"]) {
        return;
    }

    self.forumTopicRefreshInFlight = YES;
    NSNumber *chatIDCopy = [[NSNumber numberWithLongLong:[chatID longLongValue]] retain];
    TGChatItem *chatItemCopy = [chatItem retain];
    NSString *parentTitle = [[chatItem title] copy];
    NSString *parentAvatarPath = [[chatItem avatarLocalPath] copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:chatIDCopy limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.forumTopicRefreshInFlight = NO;
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && self.selectedMessageThreadID == nil);
            if (selectionStillCurrent && [topics count] > 0) {
                [self showForumTopicListForChatItem:chatItemCopy topics:topics];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: found %lu topics in %@", (unsigned long)[topics count], parentTitle ? parentTitle : @"selected chat"]];
            } else if (selectionStillCurrent) {
                if ([topicErrorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
                }
                [self reloadMessagesForChatID:chatIDCopy interactive:NO];
            }
            [topics release];
            [topicErrorMessage release];
            [chatIDCopy release];
            [chatItemCopy release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}

- (NSNumber *)oldestLoadedMessageID {
    long long minimumMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            long long value = [messageID longLongValue];
            if (minimumMessageID == 0 || value < minimumMessageID) {
                minimumMessageID = value;
            }
        }
    }
    if (minimumMessageID > 0) {
        return [NSNumber numberWithLongLong:minimumMessageID];
    }
    return nil;
}

- (NSArray *)messageItemsInDisplayOrderFromItems:(NSArray *)items {
    return [items sortedArrayUsingFunction:TGCompareMessageItemsAscending context:NULL];
}

- (NSString *)deduplicationKeyForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }

    id chatID = [item chatID];
    id date = [item date];
    NSString *preview = [item preview] ? [item preview] : @"";
    long long chatValue = [chatID respondsToSelector:@selector(longLongValue)] ? [chatID longLongValue] : 0;
    long long dateValue = [date respondsToSelector:@selector(longLongValue)] ? [date longLongValue] : 0;

    return [NSString stringWithFormat:@"%lld|%lld|%d|%@", chatValue, dateValue, [item outgoing] ? 1 : 0, preview];
}

- (BOOL)messageItem:(TGMessageItem *)left isLikelyLocalDuplicateOfMessageItem:(TGMessageItem *)right {
    if (![left isKindOfClass:[TGMessageItem class]] || ![right isKindOfClass:[TGMessageItem class]]) {
        return NO;
    }
    if (![left outgoing] || ![right outgoing]) {
        return NO;
    }
    id leftChatID = [left chatID];
    id rightChatID = [right chatID];
    if (![leftChatID respondsToSelector:@selector(longLongValue)] ||
        ![rightChatID respondsToSelector:@selector(longLongValue)] ||
        [leftChatID longLongValue] != [rightChatID longLongValue]) {
        return NO;
    }
    NSString *leftPreview = [left preview] ? [left preview] : @"";
    NSString *rightPreview = [right preview] ? [right preview] : @"";
    NSString *leftContentType = [left contentType] ? [left contentType] : @"";
    NSString *rightContentType = [right contentType] ? [right contentType] : @"";
    if (![leftContentType isEqualToString:rightContentType]) {
        return NO;
    }
    if (![leftPreview isEqualToString:rightPreview]) {
        return NO;
    }
    long long leftDate = [[left date] respondsToSelector:@selector(longLongValue)] ? [[left date] longLongValue] : 0;
    long long rightDate = [[right date] respondsToSelector:@selector(longLongValue)] ? [[right date] longLongValue] : 0;
    long long delta = leftDate - rightDate;
    if (delta < 0) {
        delta = -delta;
    }
    if ([left sending] || [right sending]) {
        return (delta <= 300);
    }
    return (delta <= 30);
}

- (TGMessageItem *)preferredMessageItemForDuplicateLeft:(TGMessageItem *)left right:(TGMessageItem *)right {
    if ([left sending] && ![right sending]) {
        return right;
    }
    if (![left sending] && [right sending]) {
        return left;
    }
    id leftID = [left messageID];
    id rightID = [right messageID];
    BOOL leftHasID = ([leftID respondsToSelector:@selector(longLongValue)] && [leftID longLongValue] > 0);
    BOOL rightHasID = ([rightID respondsToSelector:@selector(longLongValue)] && [rightID longLongValue] > 0);
    if (rightHasID && !leftHasID) {
        return right;
    }
    if (leftHasID && !rightHasID) {
        return left;
    }
    long long leftIDValue = leftHasID ? [leftID longLongValue] : 0;
    long long rightIDValue = rightHasID ? [rightID longLongValue] : 0;
    if (rightIDValue > leftIDValue) {
        return right;
    }
    return left;
}

- (NSArray *)deduplicatedMessageItemsFromItems:(NSArray *)items {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        if (![item isKindOfClass:[TGMessageItem class]]) {
            continue;
        }

        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            NSString *messageKey = [NSString stringWithFormat:@"id:%lld", [messageID longLongValue]];
            if ([messageIDs containsObject:messageKey]) {
                continue;
            }
            [messageIDs addObject:messageKey];
        }

        TGMessageItem *previousItem = [result lastObject];
        if ([item outgoing] && previousItem && [previousItem isKindOfClass:[TGMessageItem class]] && [previousItem outgoing]) {
            if ([self messageItem:item isLikelyLocalDuplicateOfMessageItem:previousItem]) {
                TGMessageItem *preferredItem = [self preferredMessageItemForDuplicateLeft:previousItem right:item];
                [result replaceObjectAtIndex:([result count] - 1) withObject:preferredItem];
                continue;
            }
            NSString *currentFallbackKey = [self deduplicationKeyForMessageItem:item];
            NSString *previousFallbackKey = [self deduplicationKeyForMessageItem:previousItem];
            if ([currentFallbackKey length] > 0 && [currentFallbackKey isEqualToString:previousFallbackKey]) {
                id currentID = [item messageID];
                id previousID = [previousItem messageID];
                BOOL currentHasID = ([currentID respondsToSelector:@selector(longLongValue)] && [currentID longLongValue] > 0);
                BOOL previousHasID = ([previousID respondsToSelector:@selector(longLongValue)] && [previousID longLongValue] > 0);
                if (currentHasID && !previousHasID) {
                    [result replaceObjectAtIndex:([result count] - 1) withObject:item];
                }
                continue;
            }
        }

        [result addObject:item];
    }

    return result;
}

- (void)scrollMessagesToNewestIfAvailable {
    NSUInteger count = [self.messageItems count];
    if (count > 0) {
        [self.messageTableView scrollRowToVisible:(count - 1)];
    }
}

- (void)applyRecentMessageItems:(NSArray *)items preservingOlderItems:(BOOL)preserveOlder {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    BOOL forceScrollToNewest = self.forceMessageScrollToNewest;
    self.forceMessageScrollToNewest = NO;
    if (!preserveOlder || [self.messageItems count] == 0) {
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:orderedItems]];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self.messageTableView reloadData];
        [self scrollMessagesToNewestIfAvailable];
        return;
    }

    BOOL shouldScrollToNewest = forceScrollToNewest || [self isMessageHistoryNearBottom];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:self.messageItems];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [mergedItems addObject:item];
    }

    [self.messageItems removeAllObjects];
    [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    [self.messageTableView reloadData];
    if (shouldScrollToNewest) {
        [self scrollMessagesToNewestIfAvailable];
    }
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items preservingVisiblePosition:(BOOL)preserveVisiblePosition {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSInteger firstVisibleRow = 0;
    if (preserveVisiblePosition) {
        NSPoint visibleOrigin = [[self.messageScrollView contentView] bounds].origin;
        firstVisibleRow = [self.messageTableView rowAtPoint:visibleOrigin];
        if (firstVisibleRow < 0) {
            firstVisibleRow = 0;
        }
    }
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *existingItem = [self.messageItems objectAtIndex:index];
        id messageID = [existingItem messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    NSMutableArray *itemsToPrepend = [NSMutableArray array];
    NSUInteger added = 0;
    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [itemsToPrepend addObject:item];
        added++;
    }

    if (added > 0) {
        NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:itemsToPrepend];
        [mergedItems addObjectsFromArray:self.messageItems];
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    }

    [self.messageTableView reloadData];
    if (added > 0) {
        if (preserveVisiblePosition) {
            NSUInteger targetRow = (NSUInteger)firstVisibleRow + added;
            if (targetRow >= [self.messageItems count]) {
                targetRow = [self.messageItems count] - 1;
            }
            [self.messageTableView scrollRowToVisible:targetRow];
        } else {
            [self scrollMessagesToNewestIfAvailable];
        }
    }
    return added;
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items {
    return [self appendOlderMessageItems:items preservingVisiblePosition:YES];
}

- (BOOL)isChatListNearBottom {
    if ([self.chatItems count] == 0 || self.chatsExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (void)chatScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.chatScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        self.controlsBusy ||
        self.backgroundChatRefreshInFlight ||
        self.chatsExhausted ||
        [self.chatItems count] == 0) {
        return;
    }

    if (![self isChatListNearBottom]) {
        self.autoChatListLoadArmed = YES;
        return;
    }

    if (!self.autoChatListLoadArmed) {
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }

    if (nextLimit <= self.chatPreviewLimit) {
        self.autoChatListLoadArmed = NO;
        return;
    }

    self.autoChatListLoadArmed = NO;
    [self reloadChatsInteractive:NO preserveSelection:YES requestedLimit:nextLimit];
}

- (BOOL)isMessageHistoryNearBottom {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isMessageHistoryScrollable {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.messageTableView rowHeight] + [self.messageTableView intercellSpacing].height) * (CGFloat)[self.messageItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)messageHistoryNeedsPrefill {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }
    return ([self.messageItems count] < TGMessagePrefillMinimumRows || ![self isMessageHistoryScrollable]);
}

- (BOOL)isMessageHistoryNearTop {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    if (![self isMessageHistoryScrollable]) {
        return NO;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 48.0);
}

- (void)messageScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.messageScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        self.olderMessagesExhausted ||
        [self.messageItems count] == 0) {
        return;
    }

    if (![self isMessageHistoryNearTop]) {
        self.autoOlderMessagesLoadArmed = YES;
        return;
    }

    if (!self.autoOlderMessagesLoadArmed) {
        return;
    }

    self.autoOlderMessagesLoadArmed = NO;
    [self reloadOlderMessagesInteractive];
}

- (void)prefillOlderMessagesIfNeededWithAttemptsRemaining:(NSUInteger)attemptsRemaining {
    if (attemptsRemaining == 0 ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        ![self messageHistoryNeedsPrefill]) {
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    self.backgroundMessageRefreshInFlight = YES;

      TGTDLibClient *client = [self.client retain];
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        BOOL hadMessageError = (messageError != nil);
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
          NSArray *itemsCopy = [items copy];

          dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            NSUInteger added = 0;
            if (selectionStillCurrent && itemsCopy) {
                added = [self appendOlderMessageItems:itemsCopy preservingVisiblePosition:NO];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: prefilled %lu older previews", (unsigned long)added]];
                }
            } else if (selectionStillCurrent && hadMessageError) {
                self.autoOlderMessagesLoadArmed = YES;
            }

            self.backgroundMessageRefreshInFlight = NO;
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            } else {
                [self updateAuthControlsForState:self.currentAuthState];
            }

            if (selectionStillCurrent &&
                added > 0 &&
                attemptsRemaining > 1 &&
                [self messageHistoryNeedsPrefill]) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:(attemptsRemaining - 1)];
            } else {
                [self handlePendingLiveRefreshesIfPossible];
            }

            [itemsCopy release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection {
    [self reloadChatsInteractive:interactive preserveSelection:preserveSelection requestedLimit:self.chatPreviewLimit];
}

- (NSArray *)readReceiptMessageIDsFromItems:(NSArray *)items {
    if (![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *messageIDs = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        if ([item outgoing]) {
            continue;
        }
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            [messageIDs addObject:[NSNumber numberWithLongLong:[messageID longLongValue]]];
        }
    }
    return messageIDs;
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID {
    [self clearUnreadCountForChatID:chatID messageThreadID:nil];
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    BOOL wantsTopic = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    BOOL didClear = NO;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        if (wantsTopic != [item isForumTopic]) {
            continue;
        }
        id itemChatID = [item chatID];
        if (![itemChatID respondsToSelector:@selector(longLongValue)] || [itemChatID longLongValue] != [chatID longLongValue]) {
            continue;
        }
        if (wantsTopic) {
            id itemThreadID = [item messageThreadID];
            if (![itemThreadID respondsToSelector:@selector(longLongValue)] || [itemThreadID longLongValue] != [messageThreadID longLongValue]) {
                continue;
            }
        }
        if ([[item unreadCount] respondsToSelector:@selector(integerValue)] && [[item unreadCount] integerValue] > 0) {
            [item setUnreadCount:[NSNumber numberWithInteger:0]];
            didClear = YES;
        }
        break;
    }

    if (didClear) {
        [self.chatTableView reloadData];
    }
}

- (void)scheduleMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    NSArray *itemsCopy = [items copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                           (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
        BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                              (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
        BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
        BOOL messagePaneVisible = ([self.messageScrollView window] != nil && ![self.messageScrollView isHidden]);
        if (selectionStillCurrent && messagePaneVisible && [self.currentAuthState isEqualToString:@"ready"]) {
            [self markMessageItemsReadForChatID:chatIDCopy messageThreadID:messageThreadIDCopy messageTopicKind:messageTopicKindCopy items:itemsCopy];
        }
        [chatIDCopy release];
        [messageThreadIDCopy release];
        [messageTopicKindCopy release];
        [itemsCopy release];
    });
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind items:(NSArray *)items {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSArray *messageIDs = [self readReceiptMessageIDsFromItems:items];
    if ([messageIDs count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [messageThreadID retain];
    NSString *messageTopicKindCopy = [messageTopicKind copy];
    NSArray *messageIDsCopy = [messageIDs copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *readError = nil;
        BOOL success = [client markMessagesAsReadForChatID:chatIDCopy
                                           messageThreadID:messageThreadIDCopy
                                          messageTopicKind:messageTopicKindCopy
                                                messageIDs:messageIDsCopy
                                                   timeout:4.0
                                                     error:&readError];
        NSString *readErrorMessage = [[readError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self clearUnreadCountForChatID:chatIDCopy messageThreadID:messageThreadIDCopy];
                [self appendDetail:@"TDLib read state: selected chat messages marked as read."];
            } else if ([readErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib read state: %@", readErrorMessage]];
            }
            [readErrorMessage release];
            [chatIDCopy release];
            [messageThreadIDCopy release];
            [messageTopicKindCopy release];
            [messageIDsCopy release];
            [client release];
        });

        [pool drain];
    });
}

- (void)reloadProfileSummaryIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy) {
        return;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *profileError = nil;
        NSDictionary *profile = [[client currentUserProfileSummaryWithTimeout:6.0 error:&profileError] retain];
        NSString *profileErrorMessage = [[profileError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client != client || ![self.currentAuthState isEqualToString:@"ready"]) {
                [profile release];
                [profileErrorMessage release];
                return;
            }

            if (profile) {
                NSString *displayName = [profile objectForKey:@"display_name"];
                NSString *firstName = [profile objectForKey:@"first_name"];
                NSString *lastName = [profile objectForKey:@"last_name"];
                NSString *username = [profile objectForKey:@"username"];
                NSString *phoneNumber = [profile objectForKey:@"phone_number"];
                NSString *bio = [profile objectForKey:@"bio"];
                id userID = [profile objectForKey:@"id"];
                if ([userID respondsToSelector:@selector(longLongValue)]) {
                    self.profileUserID = [NSNumber numberWithLongLong:[userID longLongValue]];
                } else {
                    self.profileUserID = nil;
                }
                self.profileDisplayName = ([displayName length] > 0) ? displayName : nil;
                self.profileFirstName = ([firstName length] > 0) ? firstName : nil;
                self.profileLastName = ([lastName length] > 0) ? lastName : nil;
                self.profileUsername = ([username length] > 0) ? username : nil;
                self.profilePhoneNumber = ([phoneNumber length] > 0) ? phoneNumber : nil;
                self.profileAvatarLocalPath = [profile objectForKey:@"avatar_path"];
                self.profileBio = ([bio length] > 0) ? bio : nil;
                [self refreshProfileDisplay];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = YES;
            } else {
                self.profileFirstName = nil;
                self.profileLastName = nil;
                self.profilePhoneNumber = nil;
                self.profileBio = nil;
                [self.profileStateField setStringValue:@""];
                [self refreshProfileDisplay];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = YES;
                if (profileErrorMessage) {
                    [self appendDetail:[NSString stringWithFormat:@"Profile: %@", profileErrorMessage]];
                }
            }
            [profile release];
            [profileErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection requestedLimit:(NSUInteger)requestedLimit {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        if (interactive) {
            [self appendDetail:@"Chats are available only after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = YES;
        return;
    }

    NSNumber *preferredChatID = preserveSelection ? [self.selectedChatID retain] : nil;
    NSNumber *activeFilterID = [self.selectedChatFilterID retain];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading chats..."];
        [self appendDetail:activeFilterID ? @"Loading folder chat previews from TDLib..." : @"Loading main chat previews from TDLib..."];
    } else {
        self.backgroundChatRefreshInFlight = YES;
    }

    if (requestedLimit == 0) {
        requestedLimit = TGStatusChatPreviewInitialLimit;
    } else if (requestedLimit > TGStatusChatPreviewMaximumLimit) {
        requestedLimit = TGStatusChatPreviewMaximumLimit;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        BOOL chatsExhausted = NO;
        NSArray *items = nil;
        if (activeFilterID) {
            items = [client chatPreviewItemsForChatFilterID:activeFilterID
                                                      limit:requestedLimit
                                                    timeout:10.0
                                                  exhausted:&chatsExhausted
                                                      error:&chatError];
        } else {
            items = [client mainChatPreviewItemsWithLimit:requestedLimit timeout:10.0 error:&chatError];
            chatsExhausted = [client mainChatListExhausted];
        }
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL filterStillCurrent = NO;
            if (!activeFilterID && !self.selectedChatFilterID) {
                filterStillCurrent = YES;
            } else if (activeFilterID && self.selectedChatFilterID && [activeFilterID integerValue] == [self.selectedChatFilterID integerValue]) {
                filterStillCurrent = YES;
            }

            if (!filterStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib chats: ignored stale folder result after selection changed."];
                } else {
                    [self appendDetail:@"TDLib live refresh: ignored stale folder result after selection changed."];
                }
            } else if (itemsCopy) {
                self.chatPreviewLimit = [itemsCopy count];
                self.chatsExhausted = chatsExhausted;
                [self applyChatItems:itemsCopy preserveSelection:preserveSelection preferredChatID:preferredChatID];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu %@chat previews (limit %lu)", (unsigned long)[itemsCopy count], activeFilterID ? @"folder " : @"", (unsigned long)requestedLimit]];
                    if (self.chatsExhausted) {
                        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
                    }
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = chatErrorMessage ? @"Chat preview request failed. Check connection state and try again." : @"Chat list did not return a result.";
                    [self.statusField setStringValue:@"Chats unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: chat preview refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundChatRefreshInFlight = NO;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
            [activeFilterID release];
            [preferredChatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadMessagesForChatID:(NSNumber *)chatID interactive:(BOOL)interactive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !chatID) {
        if (interactive) {
            [self appendDetail:@"Select a chat after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading messages..."];
        [self appendDetail:(messageThreadIDCopy ? @"Loading recent topic message previews from TDLib..." : @"Loading recent message previews from TDLib...")];
    } else {
        self.backgroundMessageRefreshInFlight = YES;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatIDCopy
                                                    messageThreadID:messageThreadIDCopy
                                                   messageTopicKind:messageTopicKindCopy
                                                              limit:TGMessagePreviewInitialLimit
                                                            timeout:8.0
                                                              error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
                }
            } else if (itemsCopy) {
                BOOL preserveOlder = (!interactive && [self.messageItems count] > 0);
                [self applyRecentMessageItems:itemsCopy preservingOlderItems:preserveOlder];
                [self scheduleMessageItemsReadForChatID:chatIDCopy items:itemsCopy];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = messageErrorMessage ? @"Message preview request failed. Check connection state and try again." : @"Message history did not return a result.";
                    [self.statusField setStringValue:@"Messages unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: selected chat refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            BOOL shouldPrefillOlderMessages = (selectionStillCurrent && itemsCopy && [self messageHistoryNeedsPrefill]);
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundMessageRefreshInFlight = NO;
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (shouldPrefillOlderMessages) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:TGMessagePrefillMaxAttempts];
            } else if (!interactive) {
                [self handlePendingLiveRefreshesIfPossible];
            }
            if (self.composerRefocusPending && selectionStillCurrent) {
                [self consumePendingComposerRefocus:nil];
            }
            [itemsCopy release];
              [messageErrorMessage release];
              [authorizationState release];
              [messageTopicKindCopy release];
              [messageThreadIDCopy release];
              [chatIDCopy release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadOlderMessagesInteractive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after sign-in is ready."];
        return;
    }

    if (self.backgroundMessageRefreshInFlight) {
        [self appendDetail:@"TDLib messages: wait for the current message load to finish."];
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [self appendDetail:@"TDLib messages: load recent messages before requesting older history."];
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Loading older messages..."];
    [self appendDetail:(messageThreadIDCopy ? @"Loading older topic message previews from TDLib..." : @"Loading older message previews from TDLib...")];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale older-history result for previous chat selection."];
            } else if (itemsCopy) {
                NSUInteger added = [self appendOlderMessageItems:itemsCopy];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added == 0) {
                    self.autoOlderMessagesLoadArmed = NO;
                }
                [self.statusField setStringValue:(added > 0) ? @"Connected" : @"No older messages"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: appended %lu older previews", (unsigned long)added]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib older message previews appended: %lu", (unsigned long)added]];
            } else {
                [self.statusField setStringValue:@"Older messages unavailable"];
                NSString *message = messageErrorMessage ? messageErrorMessage : @"Older message history did not return a result.";
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib older message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [self handlePendingLiveRefreshesIfPossible];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)handlePendingLiveRefreshesIfPossible {
    if (self.controlsBusy || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (self.pendingLiveMessageRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && hasMessageTarget) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.pendingLiveMessageRefresh = NO;
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }

    if (self.pendingLiveChatRefresh && !self.backgroundChatRefreshInFlight && !self.showingForumTopicList) {
        self.pendingLiveChatRefresh = NO;
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)pollLiveUpdates:(NSTimer *)timer {
    (void)timer;
    if (!self.client) {
        return;
    }

    NSArray *updates = [self.client drainSafeUpdateSummaries];
    if ([updates count] == 0) {
        return;
    }

    NSNumber *selectedChatID = [self.selectedChatID retain];
    NSString *latestAuthorizationState = nil;
    BOOL needsChatRefresh = NO;
    BOOL needsMessageRefresh = NO;
    BOOL needsChatFilterRefresh = NO;

    NSUInteger index = 0;
    for (index = 0; index < [updates count]; index++) {
        NSDictionary *summary = [updates objectAtIndex:index];
        if (![summary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *kind = [summary objectForKey:@"kind"];
        if ([kind isEqualToString:@"authorization"]) {
            NSString *state = [summary objectForKey:@"state"];
            if ([state length] > 0) {
                latestAuthorizationState = state;
            }
            continue;
        }

        if ([kind isEqualToString:@"new_message"] || [kind isEqualToString:@"chat_update"]) {
            needsChatRefresh = YES;
            self.chatsExhausted = NO;
            [self.client invalidateMainChatListExhaustion];
            id chatID = [summary objectForKey:@"chat_id"];
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsMessageRefresh = YES;
            }
        } else if ([kind isEqualToString:@"chat_filters"]) {
            needsChatFilterRefresh = YES;
        }
    }

    if ([latestAuthorizationState length] > 0 && ![latestAuthorizationState isEqualToString:self.currentAuthState]) {
        [self updateAuthControlsForState:latestAuthorizationState];
    }

    if (needsChatRefresh) {
        self.pendingLiveChatRefresh = YES;
    }
    if (needsMessageRefresh) {
        self.pendingLiveMessageRefresh = YES;
    }
    if (needsChatFilterRefresh) {
        [self reloadChatFiltersIfReady];
    }

    [selectedChatID release];
    [self handlePendingLiveRefreshesIfPossible];
}

- (void)connectOnLaunch:(id)sender {
    (void)sender;
    if (self.initialConnectStarted) {
        return;
    }
    self.initialConnectStarted = YES;
    [self checkTDLib:nil];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    if (self.controlsBusy) {
        return;
    }
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Connecting..."];
    [self appendDetail:@"Connecting to Telegram core..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *parametersError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:&parametersError];
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
            if (![finalAuthorizationState length]) {
                NSError *fallbackAuthorizationError = nil;
                NSString *fallbackAuthorizationState = [client authorizationStateSummaryWithTimeout:4.0 error:&fallbackAuthorizationError];
                if ([fallbackAuthorizationState length] > 0) {
                    finalAuthorizationState = fallbackAuthorizationState;
                } else if (!finalAuthorizationError && fallbackAuthorizationError) {
                    finalAuthorizationError = fallbackAuthorizationError;
                }
            }
            if (![finalAuthorizationState length] && [authorizationState length] > 0) {
                finalAuthorizationState = authorizationState;
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];
        NSString *receiverSummary = [[client receiverStatusSummary] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (probeSummary) {
                [self.statusField setStringValue:[finalAuthorizationState isEqualToString:@"ready"] ? @"Connected" : @"Login required"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (receiverSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib receiver: %@", receiverSummary]];
                }
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", [parametersError localizedDescription]]];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
                [self setControlsBusy:NO];
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self setControlsBusy:NO];
                [self.statusField setStringValue:@"Connection unavailable"];
                [self.authStateField setStringValue:@"Connection unavailable. Check local build files and try again."];
                [self updateVisibleSection];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
        });

        [client release];
        [receiverSummary release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Login input is not available for the current connection state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    NSString *input = [[inputField stringValue] copy];
    [inputField setStringValue:@""];
    if ([input length] == 0) {
        [input release];
        [state release];
        [self appendDetail:@"Login input is empty."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Signing in..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (authSummary) {
                [self.statusField setStringValue:@"Sign-in step submitted"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"Sign-in needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
            } else {
                [self updateAuthControlsForState:state];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    if (self.showingForumTopicList) {
        [self reloadCurrentForumTopicListInteractive:YES];
        return;
    }
    self.autoChatListLoadArmed = YES;
    [self reloadChatsInteractive:YES preserveSelection:YES];
}

- (void)loadMoreChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    if (self.chatsExhausted) {
        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }
    if (nextLimit == self.chatPreviewLimit) {
        [self appendDetail:@"TDLib chats: maximum preview limit reached for this build."];
        return;
    }
    [self reloadChatsInteractive:YES preserveSelection:YES requestedLimit:nextLimit];
}

- (void)loadMessages:(id)sender {
    (void)sender;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self reloadMessagesForChatID:self.selectedChatID interactive:YES];
}

- (void)loadOlderMessages:(id)sender {
    (void)sender;
    [self reloadOlderMessagesInteractive];
}

- (void)sendMessage:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before sending."];
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] == 0) {
        [self appendDetail:@"Message text is empty."];
        [self updateSendControls];
        return;
    }
    if ([text length] > 4096) {
        [self appendDetail:@"Message text is too long for this spike."];
        [self updateSendControls];
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    NSString *messageText = [text copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending..."];
    [self appendDetail:(messageThreadID ? @"Submitting topic text message to TDLib..." : @"Submitting text message to TDLib...")];
    [[TGLogger sharedLogger] log:@"TDLib text message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSString *sendSummary = [client sendTextMessageToChatID:chatID
                                                messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
                                                           text:messageText
                                                        timeout:8.0
                                                          error:&sendError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        BOOL sendSucceeded = ([sendSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if (sendSucceeded) {
                [self.statusField setStringValue:@"Message sent"];
                [self appendDetail:@"TDLib send: text message accepted by TDLib."];
                [[TGLogger sharedLogger] log:@"TDLib text message send accepted."];
                if (selectionStillCurrent) {
                    [self.sendTextField setStringValue:@""];
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                [self.statusField setStringValue:@"Send not confirmed"];
                [self appendDetail:@"TDLib send: text message was not confirmed. Do not retry automatically; it may or may not have been sent."];
                [[TGLogger sharedLogger] log:@"TDLib text message send not confirmed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (sendSucceeded && selectionStillCurrent) {
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            }
            [authorizationState release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [messageText release];
        });

        [client release];
        [pool drain];
    });
}

- (void)logout:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Logout is available only after sign-in is ready."];
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Log out of Telegram?"];
    [alert setInformativeText:@"Telegraphica will close the current local TDLib session. You will need to sign in again on this Mac."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Logout"];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Logging out..."];
    [self appendDetail:@"Submitting Telegram logout to TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *logoutError = nil;
        NSString *logoutSummary = [[client logOutWithTimeout:8.0 error:&logoutError] copy];
        NSString *logoutErrorMessage = [[logoutError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (logoutSummary) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", logoutSummary]];
                [[TGLogger sharedLogger] log:@"TDLib logout accepted."];
                self.client = [[[TGTDLibClient alloc] init] autorelease];
                self.initialConnectStarted = NO;
                self.profileSummaryLoaded = NO;
                self.pendingLiveChatRefresh = NO;
                self.pendingLiveMessageRefresh = NO;
                [self.chatItems removeAllObjects];
                [self.messageItems removeAllObjects];
                [self.chatTableView deselectAll:nil];
                [self.chatTableView reloadData];
                [self.messageTableView reloadData];
                self.selectedChatID = nil;
                self.selectedChatTitle = nil;
                self.selectedChatTypeSummary = nil;
                self.selectedChatAvatarLocalPath = nil;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                self.chatsExhausted = NO;
                self.olderMessagesExhausted = NO;
                self.autoChatListLoadArmed = YES;
                self.autoOlderMessagesLoadArmed = YES;
                [self refreshSelectedChatHeaderDisplay];
                [self.sendTextField setStringValue:@""];
                [self updateAuthControlsForState:@"closed"];
                [self setControlsBusy:NO];
                [self checkTDLib:nil];
            } else {
                NSString *message = logoutErrorMessage ? logoutErrorMessage : @"TDLib logout did not return a result.";
                [self.statusField setStringValue:@"Logout failed"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", message]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib logout failed: %@", message]];
                [self setControlsBusy:NO];
            }
            [logoutSummary release];
            [logoutErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(consumePendingComposerRefocus:)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(reloadChatFiltersIfReady)
                                               object:nil];
    [self stopLiveUpdateTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_messageTableView setDataSource:nil];
    [_messageTableView setDelegate:nil];
    [_sendTextField setDelegate:nil];
    [_authTextField setDelegate:nil];
    [_authSecureField setDelegate:nil];
    [_topPanelView release];
    [_sidebarPanelView release];
    [_conversationPanelView release];
    [_diagnosticsPanelView release];
    [_loginPanelView release];
    [_profilePanelView release];
    [_settingsPanelView release];
    [_aboutPanelView release];
    [_bottomNavigationView release];
    [_navigationButtons release];
    [_drawerFolderButtons release];
    [_chatFilterInfos release];
    [_accountBadgeView release];
    [_drawerButton release];
    [_profileSummaryCardView release];
    [_profileInfoCardView release];
    [_profileDetailsCardView release];
    [_profileActionsCardView release];
    [_profileAvatarView release];
    [_settingsAccountCardView release];
    [_settingsThemeCardView release];
    [_settingsSessionCardView release];
    [_aboutCardView release];
    [_logsCardView release];
    [_diagnosticsLabel release];
    [_titleField release];
    [_statusField release];
    [_detailsScrollView release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_loadMoreChatsButton release];
    [_topicBackButton release];
    [_loadMessagesButton release];
    [_loadOlderMessagesButton release];
    [_sendLabel release];
    [_sendTextFieldBackgroundView release];
    [_sendTextField release];
    [_sendMessageButton release];
    [_authLabel release];
    [_authStateField release];
    [_loginTitleField release];
    [_loginHintField release];
    [_authTextField release];
    [_authSecureField release];
    [_authButton release];
    [_chatsLabel release];
    [_messagesLabel release];
    [_selectedChatField release];
    [_selectedChatAvatarView release];
    [_selectedChatProfileButton release];
    [_chatScrollSurfaceView release];
    [_chatScrollView release];
    [_chatTableView release];
    [_chatItems release];
    [_chatItemsBeforeTopicList release];
    [_messageScrollSurfaceView release];
    [_messageScrollView release];
    [_messageTableView release];
    [_messageItems release];
    [_profileTitleField release];
    [_profileNameField release];
    [_profileUsernameField release];
    [_profileIDField release];
    [_profileStateField release];
    [_profileAboutSectionField release];
    [_profileAccountSectionField release];
    [_profileUsernameRowTitleField release];
    [_profileUsernameRowValueField release];
    [_profilePhoneRowTitleField release];
    [_profilePhoneRowValueField release];
    [_profileIDRowTitleField release];
    [_profileIDRowValueField release];
    [_profileDetailsSeparatorOne release];
    [_profileDetailsSeparatorTwo release];
    [_settingsTitleField release];
    [_settingsStateField release];
    [_settingsLibraryField release];
    [_settingsStorageField release];
    [_settingsThemeLabel release];
    [_themePopUpButton release];
    [_settingsAppearanceButton release];
    [_settingsLogsButton release];
    [_settingsAboutButton release];
    [_logoutButton release];
    [_aboutIconView release];
    [_aboutTitleField release];
    [_aboutVersionField release];
    [_aboutCopyrightField release];
    [_aboutLinkField release];
    [_selectedChatID release];
    [_selectedChatTitle release];
    [_selectedChatTypeSummary release];
    [_selectedChatAvatarLocalPath release];
    [_selectedMessageThreadID release];
    [_selectedMessageTopicKind release];
    [_topicParentChatID release];
    [_topicParentTitle release];
    [_topicParentAvatarLocalPath release];
    [_selectedChatFilterID release];
    [_client release];
    [_currentAuthState release];
    [_activeSection release];
    [_liveUpdateTimer release];
    [_profileDisplayName release];
    [_profileFirstName release];
    [_profileLastName release];
    [_profileUsername release];
    [_profilePhoneNumber release];
    [_profileUserID release];
    [_profileAvatarLocalPath release];
    [_profileBio release];
    [_lastLogSection release];
    [_logsWindow close];
    [_aboutWindow close];
    [_appearanceWindow close];
    [_mediaPreviewWindow setDelegate:nil];
    [_mediaPreviewWindow close];
    [_logsWindow release];
    [_aboutWindow release];
    [_appearanceWindow release];
    [_mediaPreviewWindow release];
    [_mediaPreviewScrollView release];
    [_mediaPreviewImageView release];
    [_mediaPreviewPath release];
    [_logsWindowDetailsView release];
    [_logsCheckButton release];
    [_appearanceThemePopUpButton release];
    [super dealloc];
}

@end
