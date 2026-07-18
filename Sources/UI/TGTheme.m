#import "TGTheme.h"

NSString * const TGThemeDefaultsKey = @"TelegraphicaThemeIdentifier";
NSString * const TGThemeIdentifierVKBlue = @"vk-blue";
NSString * const TGThemeIdentifierCoffee = @"coffee-brass";
NSString * const TGThemeIdentifierCoralPlum = @"coral-plum";
NSString * const TGThemeIdentifierIceNavy = @"ice-navy";
NSString * const TGThemeIdentifierRubyObsidian = @"ruby-obsidian";
NSString * const TGThemeIdentifierEggshellBurgundy = @"eggshell-burgundy";
NSString * const TGThemeIdentifierMelonOlive = @"melon-olive";
NSString * const TGThemeIdentifierMidnightGraphite = @"midnight-graphite";
NSString * const TGThemeIdentifierNordicNight = @"nordic-night";
NSString * const TGThemeIdentifierTronGrid = @"tron-grid";
NSString * const TGThemeIdentifierSkeuomorphicBlue = @"skeuomorphic-blue";
NSString * const TGThemeIdentifierFrutigerAero = @"frutiger-aero";
NSString * const TGThemeIdentifierFrutigerAeroDream = @"frutiger-aero-dream";
NSString * const TGThemeIdentifierFrutigerMetro = @"frutiger-metro";
NSString * const TGThemeIdentifierFrutigerMetroDark = @"frutiger-metro-dark";
NSString * const TGThemeIdentifierY2KChrome = @"y2k-chrome";
NSString * const TGThemeIdentifierY2KSilver = @"y2k-silver";
NSString * const TGThemeIdentifierPixelTerminal = @"pixel-terminal";
NSString * const TGThemeIdentifierMatrixRain = @"matrix-rain";
NSString * const TGThemeIdentifierVectorPop = @"vector-pop";
NSString * const TGThemeCategoryIdentifierLight = @"theme-category-light";
NSString * const TGThemeCategoryIdentifierDark = @"theme-category-dark";
NSString * const TGThemeCategoryIdentifierOldSchool = @"theme-category-old-school";
NSString * const TGThemeCategoryIdentifierExperimental = @"theme-category-experimental";

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

NSColor *TGColorFromHex(NSUInteger hex) {
    return TGColorFromRGB(TGRGBMake(hex));
}

NSArray *TGThemeIdentifiers(void) {
    return [NSArray arrayWithObjects:
            TGThemeIdentifierVKBlue,
            TGThemeIdentifierCoffee,
            TGThemeIdentifierCoralPlum,
            TGThemeIdentifierIceNavy,
            TGThemeIdentifierRubyObsidian,
            TGThemeIdentifierEggshellBurgundy,
            TGThemeIdentifierMelonOlive,
            TGThemeIdentifierMidnightGraphite,
            TGThemeIdentifierNordicNight,
            TGThemeIdentifierTronGrid,
            TGThemeIdentifierSkeuomorphicBlue,
            TGThemeIdentifierFrutigerAero,
            TGThemeIdentifierFrutigerAeroDream,
            TGThemeIdentifierFrutigerMetro,
            TGThemeIdentifierFrutigerMetroDark,
            TGThemeIdentifierY2KChrome,
            TGThemeIdentifierY2KSilver,
            TGThemeIdentifierPixelTerminal,
            TGThemeIdentifierMatrixRain,
            TGThemeIdentifierVectorPop,
            nil];
}

NSArray *TGThemeCategoryIdentifiers(void) {
    return [NSArray arrayWithObjects:
            TGThemeCategoryIdentifierLight,
            TGThemeCategoryIdentifierDark,
            TGThemeCategoryIdentifierOldSchool,
            TGThemeCategoryIdentifierExperimental,
            nil];
}

NSArray *TGThemeIdentifiersForCategory(NSString *categoryIdentifier) {
    if ([categoryIdentifier isEqualToString:TGThemeCategoryIdentifierDark]) {
        return [NSArray arrayWithObjects:
                TGThemeIdentifierMidnightGraphite,
                TGThemeIdentifierNordicNight,
                TGThemeIdentifierTronGrid,
                nil];
    }
    if ([categoryIdentifier isEqualToString:TGThemeCategoryIdentifierOldSchool]) {
        return [NSArray arrayWithObjects:
                TGThemeIdentifierVKBlue,
                TGThemeIdentifierSkeuomorphicBlue,
                TGThemeIdentifierFrutigerAero,
                TGThemeIdentifierFrutigerAeroDream,
                TGThemeIdentifierFrutigerMetro,
                TGThemeIdentifierFrutigerMetroDark,
                nil];
    }
    if ([categoryIdentifier isEqualToString:TGThemeCategoryIdentifierExperimental]) {
        return [NSArray arrayWithObjects:
                TGThemeIdentifierY2KChrome,
                TGThemeIdentifierY2KSilver,
                TGThemeIdentifierPixelTerminal,
                TGThemeIdentifierMatrixRain,
                TGThemeIdentifierVectorPop,
                nil];
    }
    return [NSArray arrayWithObjects:
            TGThemeIdentifierCoffee,
            TGThemeIdentifierCoralPlum,
            TGThemeIdentifierIceNavy,
            TGThemeIdentifierRubyObsidian,
            TGThemeIdentifierEggshellBurgundy,
            TGThemeIdentifierMelonOlive,
            nil];
}

NSString *TGThemeCategoryIdentifierForThemeIdentifier(NSString *identifier) {
    NSArray *categories = TGThemeCategoryIdentifiers();
    NSUInteger categoryIndex = 0;
    for (categoryIndex = 0; categoryIndex < [categories count]; categoryIndex++) {
        NSString *category = [categories objectAtIndex:categoryIndex];
        if ([TGThemeIdentifiersForCategory(category) containsObject:identifier]) {
            return category;
        }
    }
    return TGThemeCategoryIdentifierOldSchool;
}

BOOL TGThemeIdentifierIsValid(NSString *identifier) {
    return (identifier && [TGThemeIdentifiers() containsObject:identifier]);
}

NSString *TGThemeDisplayNameForIdentifier(NSString *identifier) {
    if ([identifier isEqualToString:TGThemeIdentifierCoffee]) return @"Coffee & Brass";
    if ([identifier isEqualToString:TGThemeIdentifierCoralPlum]) return @"Electric Coral / Deep Plum";
    if ([identifier isEqualToString:TGThemeIdentifierIceNavy]) return @"Ice Blue / Deep Navy";
    if ([identifier isEqualToString:TGThemeIdentifierRubyObsidian]) return @"Neon Ruby / Obsidian";
    if ([identifier isEqualToString:TGThemeIdentifierEggshellBurgundy]) return @"Eggshell Cream / Burgundy";
    if ([identifier isEqualToString:TGThemeIdentifierMelonOlive]) return @"Soft Melon / Olive Slate";
    if ([identifier isEqualToString:TGThemeIdentifierMidnightGraphite]) return @"Midnight Graphite";
    if ([identifier isEqualToString:TGThemeIdentifierNordicNight]) return @"Nordic Night";
    if ([identifier isEqualToString:TGThemeIdentifierTronGrid]) return @"Neon Grid";
    if ([identifier isEqualToString:TGThemeIdentifierSkeuomorphicBlue]) return @"Skeuomorphic Blue";
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerAero]) return @"Frutiger Aero (aqua)";
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerAeroDream]) return @"Frutiger Aero (dream)";
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerMetro]) return @"Frutiger Metro Light";
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerMetroDark]) return @"Frutiger Metro Dark";
    if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) return @"Y2K Chrome";
    if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) return @"Y2K Silver";
    if ([identifier isEqualToString:TGThemeIdentifierPixelTerminal]) return @"Pixel Terminal";
    if ([identifier isEqualToString:TGThemeIdentifierMatrixRain]) return @"Matrix Rain";
    if ([identifier isEqualToString:TGThemeIdentifierVectorPop]) return @"Metro Pop";
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
    if ([identifier isEqualToString:TGThemeIdentifierMidnightGraphite]) {
        return TGThemePaletteMake(0x0b1118, 0x151f2a, 0x22354a, 0x101923, 0xe6eef8, 0x8fa1b6,
                                  0x2f4459, 0x244562, 0xf0f7ff, 0x67b7ff, 0x18334a, 0x111d28,
                                  0x3d6c91, 0x334758, 0x9aaec3, 0x1f2d3b, 0x71c4ff, 0xf4f8ff, 0x92a8bf);
    }
    if ([identifier isEqualToString:TGThemeIdentifierNordicNight]) {
        return TGThemePaletteMake(0x111827, 0x1b2634, 0x334155, 0x16202c, 0xe8edf4, 0x9aa7b7,
                                  0x405166, 0x2f4c67, 0xf4f8fd, 0x8ed0ff, 0x253d54, 0x182331,
                                  0x5f7f9c, 0x3a4d62, 0x9aa7b7, 0x243345, 0x9bd7ff, 0xf6f9fd, 0xa7b5c6);
    }
    if ([identifier isEqualToString:TGThemeIdentifierTronGrid]) {
        return TGThemePaletteMake(0x030914, 0x071629, 0x063b62, 0x04111f, 0xe7fbff, 0x7fe8ff,
                                  0x095f8f, 0x062f4b, 0xdfffff, 0x00e5ff, 0x092d4e, 0x061120,
                                  0x00b9ff, 0x0b729e, 0x6bdcff, 0x07243d, 0x00f5ff, 0xeaffff, 0x79e8ff);
    }
    if ([identifier isEqualToString:TGThemeIdentifierSkeuomorphicBlue]) {
        return TGThemePaletteMake(0x2e3e4b, 0xd9e0e3, 0x29465e, 0xe8e3d5, 0x1c2b35, 0x60717d,
                                  0x7d9ab0, 0xb8c9d6, 0x102435, 0x345f7f, 0xd9e6ee, 0xf6f0e4,
                                  0x6f94ac, 0xc8bfae, 0x6a7070, 0xd8e4ea, 0x2f668d, 0xf6fbff, 0xd6e4ed);
    }
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerAero]) {
        return TGThemePaletteMake(0x4aaed0, 0xe4f7f7, 0x2f91c0, 0xf4fbf8, 0x102d38, 0x52737c,
                                  0x8bcbd4, 0xb9ecf1, 0x082f42, 0x1488b7, 0xcdf5ff, 0xffffff,
                                  0x74c8d7, 0xb8d7d2, 0x4d7580, 0xd8f3f6, 0x1487b8, 0xf8ffff, 0xd8f5fa);
    }
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerAeroDream]) {
        return TGThemePaletteMake(0x5fc7e6, 0xe8fbe8, 0x1e8fc8, 0xf7fff2, 0x143747, 0x507b78,
                                  0x8ad8bc, 0xc9f0d5, 0x0a3a4e, 0x238bc2, 0xd8f8ff, 0xffffff,
                                  0x7fcfe0, 0xbfd8b4, 0x4d7c75, 0xdff8de, 0x1689c4, 0xf8ffff, 0xdff8ff);
    }
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerMetro]) {
        return TGThemePaletteMake(0x6dd4e9, 0xeaf8ff, 0x1b9bd0, 0xf8ffff, 0x10344a, 0x527280,
                                  0x93d2df, 0xc7eef7, 0x08324a, 0x1184bc, 0xd5f7ff, 0xffffff,
                                  0x70c8de, 0xb6d7df, 0x4b7584, 0xe0f6fb, 0x0f83bf, 0xf9ffff, 0xdff6ff);
    }
    if ([identifier isEqualToString:TGThemeIdentifierFrutigerMetroDark]) {
        return TGThemePaletteMake(0x1b1009, 0x2b1a10, 0xd66b18, 0x24170f, 0xfff1df, 0xd5a47a,
                                  0xb35e24, 0x5a2f18, 0xfff6e8, 0xff9c28, 0x4a2613, 0x281a11,
                                  0xd9832d, 0x6a3c1d, 0xe2ae80, 0x3b2417, 0xffa336, 0xfff7ea, 0xf3bc8a);
    }
    if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
        return TGThemePaletteMake(0x151a36, 0xeef3ff, 0x3f6ae5, 0xf9fbff, 0x111832, 0x5c6180,
                                  0x9eb1ff, 0xd9ddff, 0x101633, 0xd817b8, 0xdbe6ff, 0xffffff,
                                  0x8398ff, 0xcfd8f2, 0x5d6380, 0xe9edff, 0xb613a2, 0xffffff, 0xe8eeff);
    }
    if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
        return TGThemePaletteMake(0x4e5668, 0xe9edf3, 0xaab5c8, 0xf8f9fc, 0x1a2333, 0x667085,
                                  0x9fa9ba, 0xdce4f2, 0x162033, 0xa051ff, 0xe5ebf7, 0xffffff,
                                  0xa0adbf, 0xc8d0dc, 0x687284, 0xf0f3f8, 0x7c4dff, 0xffffff, 0xe9eef7);
    }
    if ([identifier isEqualToString:TGThemeIdentifierPixelTerminal]) {
        return TGThemePaletteMake(0x020603, 0x06120a, 0x0f2b17, 0x020803, 0xd7ffd5, 0x74aa71,
                                  0x1d5f2c, 0x123f22, 0xeaffea, 0x6cff73, 0x0d3018, 0x06130a,
                                  0x36b34f, 0x235f34, 0x7bcf80, 0x0b1d11, 0x63ff70, 0xeaffea, 0x83d486);
    }
    if ([identifier isEqualToString:TGThemeIdentifierMatrixRain]) {
        return TGThemePaletteMake(0x000000, 0x031006, 0x061f0b, 0x010602, 0xeaffee, 0x6bb970,
                                  0x0d5920, 0x0b3917, 0xf3fff4, 0x39ff62, 0x093116, 0x030d05,
                                  0x23d64b, 0x155a25, 0x78e882, 0x061609, 0x35ff5d, 0xedfff0, 0x7eff8a);
    }
    if ([identifier isEqualToString:TGThemeIdentifierVectorPop]) {
        return TGThemePaletteMake(0x091a28, 0xf2fff9, 0x129bd3, 0xffffff, 0x101820, 0x4d6470,
                                  0x7fcbde, 0xd5f5fb, 0x0b1720, 0x62b929, 0xd8f5ff, 0xffffff,
                                  0x5bb8d8, 0xbbd9d1, 0x526b75, 0xe4f8f2, 0x18a0d8, 0xffffff, 0xdaf6ee);
    }
    return TGThemePaletteMake(0x182537, 0xecf3fb, 0x3c5d8a, 0xf8fbfe, 0x0e141d, 0x4e637c,
                              0x8ca6c4, 0xb3cce9, 0x091321, 0x305d96, 0xc2ddf8, 0xffffff,
                              0x5b88bd, 0xaabace, 0x465d77, 0xd6e4f4, 0x2d5d96, 0xf8fbff, 0xdce9f7);
}

void TGSetActiveThemeIdentifier(NSString *identifier) {
    NSString *validIdentifier = TGThemeIdentifierIsValid(identifier) ? identifier : TGThemeIdentifierVKBlue;
    if (TGActiveThemeIdentifier && [TGActiveThemeIdentifier isEqualToString:validIdentifier]) return;
    [TGActiveThemeIdentifier release];
    TGActiveThemeIdentifier = [validIdentifier copy];
}

NSString *TGCurrentThemeIdentifier(void) {
    if (!TGActiveThemeIdentifier) {
        TGSetActiveThemeIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:TGThemeDefaultsKey]);
    }
    return TGActiveThemeIdentifier ? TGActiveThemeIdentifier : TGThemeIdentifierVKBlue;
}

BOOL TGThemeIsSkeuomorphicBlue(void) {
    return [TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierSkeuomorphicBlue];
}

BOOL TGThemeIsFrutigerAero(void) {
    NSString *identifier = TGCurrentThemeIdentifier();
    return [identifier isEqualToString:TGThemeIdentifierFrutigerAero] ||
           [identifier isEqualToString:TGThemeIdentifierFrutigerAeroDream] ||
           [identifier isEqualToString:TGThemeIdentifierFrutigerMetro] ||
           [identifier isEqualToString:TGThemeIdentifierFrutigerMetroDark];
}

BOOL TGThemeIsFrutigerAeroDream(void) {
    return [TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierFrutigerAeroDream];
}

BOOL TGThemeIsFrutigerMetro(void) {
    return [TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierFrutigerMetro];
}

BOOL TGThemeIsFrutigerMetroDark(void) {
    return [TGCurrentThemeIdentifier() isEqualToString:TGThemeIdentifierFrutigerMetroDark];
}

BOOL TGThemeIsExperimental2000s(void) {
    NSString *identifier = TGCurrentThemeIdentifier();
    return [identifier isEqualToString:TGThemeIdentifierY2KChrome] ||
           [identifier isEqualToString:TGThemeIdentifierY2KSilver] ||
           [identifier isEqualToString:TGThemeIdentifierPixelTerminal] ||
           [identifier isEqualToString:TGThemeIdentifierMatrixRain] ||
           [identifier isEqualToString:TGThemeIdentifierVectorPop];
}

static BOOL TGThemeIsTerminalLikeIdentifier(NSString *identifier) {
    return [identifier isEqualToString:TGThemeIdentifierPixelTerminal] ||
           [identifier isEqualToString:TGThemeIdentifierMatrixRain];
}

static BOOL TGThemeUsesLayeredMaterials(void) {
    return TGThemeIsSkeuomorphicBlue() || TGThemeIsFrutigerAero() || TGThemeIsExperimental2000s();
}

static TGThemePalette TGCurrentThemePalette(void) {
    return TGThemePaletteForIdentifier(TGCurrentThemeIdentifier());
}

#define TG_THEME_COLOR_FUNCTION(name, field) \
    NSColor *name(void) { TGThemePalette palette = TGCurrentThemePalette(); return TGColorFromRGB(palette.field); }

TG_THEME_COLOR_FUNCTION(TGClassicWindowBottomColor, window)
TG_THEME_COLOR_FUNCTION(TGClassicPanelBottomColor, panel)
TG_THEME_COLOR_FUNCTION(TGClassicHeaderBottomColor, header)
TG_THEME_COLOR_FUNCTION(TGClassicTablePaperColor, tablePaper)
TG_THEME_COLOR_FUNCTION(TGClassicInkColor, ink)
TG_THEME_COLOR_FUNCTION(TGClassicMutedInkColor, mutedInk)
TG_THEME_COLOR_FUNCTION(TGClassicOutgoingBubbleBottomColor, outgoingBubble)
TG_THEME_COLOR_FUNCTION(TGClassicIncomingBubbleBottomColor, incomingBubble)
TG_THEME_COLOR_FUNCTION(TGClassicRailStrokeColor, railStroke)
TG_THEME_COLOR_FUNCTION(TGClassicHeaderSeparatorColor, headerSeparator)
TG_THEME_COLOR_FUNCTION(TGClassicPanelStrokeColor, panelStroke)
TG_THEME_COLOR_FUNCTION(TGClassicSelectedRowColor, selectedRow)
TG_THEME_COLOR_FUNCTION(TGClassicSelectedRowTextColor, selectedRowText)
TG_THEME_COLOR_FUNCTION(TGClassicUnreadTextColor, unreadText)
TG_THEME_COLOR_FUNCTION(TGClassicTableGridColor, tableGrid)
TG_THEME_COLOR_FUNCTION(TGClassicTableHeaderColor, tableHeader)
TG_THEME_COLOR_FUNCTION(TGClassicLinkColor, link)

NSColor *TGClassicCardInkColor(void) {
    return [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
}

NSColor *TGClassicCardMutedInkColor(void) {
    return [NSColor colorWithCalibratedWhite:0.36 alpha:1.0];
}

NSColor *TGClassicCardLinkColor(void) {
    return TGColorFromHex(0x2d5d96);
}

#define TG_THEME_ALPHA_COLOR_FUNCTION(name, field) \
    NSColor *name(CGFloat alpha) { TGThemePalette palette = TGCurrentThemePalette(); return TGColorFromRGBWithAlpha(palette.field, alpha); }

TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationSelectedColor, navigationSelected)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationHighlightedColor, navigationHighlighted)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationNormalColor, navigationNormal)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationSelectedStrokeColor, navigationSelectedStroke)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationNormalStrokeColor, navigationNormalStroke)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationTextColor, navigationText)
TG_THEME_ALPHA_COLOR_FUNCTION(TGClassicNavigationMutedTextColor, navigationMutedText)

NSColor *TGClassicOutgoingBubbleStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.outgoingBubbleStroke, 0.85);
}

NSColor *TGClassicIncomingBubbleStrokeColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.incomingBubbleStroke, 0.72);
}

NSColor *TGClassicTimeTextColor(void) {
    TGThemePalette palette = TGCurrentThemePalette();
    return TGColorFromRGBWithAlpha(palette.timeText, 1.0);
}

NSColor *TGClassicHeaderTextColor(CGFloat alpha) {
    NSString *identifier = TGCurrentThemeIdentifier();
    if ([identifier isEqualToString:TGThemeIdentifierCoralPlum]) {
        TGThemePalette palette = TGCurrentThemePalette();
        return TGColorFromRGBWithAlpha(palette.ink, alpha);
    }
    return [NSColor colorWithCalibratedWhite:0.99 alpha:alpha];
}

NSColor *TGClassicHeaderDetailTextColor(CGFloat alpha) {
    NSString *identifier = TGCurrentThemeIdentifier();
    if ([identifier isEqualToString:TGThemeIdentifierCoralPlum]) {
        TGThemePalette palette = TGCurrentThemePalette();
        return TGColorFromRGBWithAlpha(palette.ink, alpha);
    }
    return [NSColor colorWithCalibratedWhite:0.94 alpha:alpha];
}

typedef enum {
    TGSkeuomorphicPatternCanvas = 1,
    TGSkeuomorphicPatternPaper = 2,
    TGSkeuomorphicPatternEnamel = 3,
    TGSkeuomorphicPatternAero = 4,
    TGSkeuomorphicPatternAeroDream = 5,
    TGSkeuomorphicPatternMetro = 6,
    TGSkeuomorphicPatternMetroDark = 7,
    TGSkeuomorphicPatternY2K = 8,
    TGSkeuomorphicPatternY2KSilver = 9,
    TGSkeuomorphicPatternPixel = 10,
    TGSkeuomorphicPatternMatrix = 11,
    TGSkeuomorphicPatternVector = 12
} TGSkeuomorphicPattern;

static void TGDrawPatternDot(CGFloat x, CGFloat y, CGFloat alpha) {
    [[NSColor colorWithCalibratedWhite:1.0 alpha:alpha] set];
    NSRectFill(NSMakeRect(x, y, 1.0, 1.0));
}

static NSImage *TGSkeuomorphicPatternImage(TGSkeuomorphicPattern pattern) {
    static NSImage *canvasImage = nil;
    static NSImage *paperImage = nil;
    static NSImage *enamelImage = nil;
    static NSImage *aeroImage = nil;
    static NSImage *aeroDreamImage = nil;
    static NSImage *metroImage = nil;
    static NSImage *metroDarkImage = nil;
    static NSImage *y2kImage = nil;
    static NSImage *y2kSilverImage = nil;
    static NSImage *pixelImage = nil;
    static NSImage *matrixImage = nil;
    static NSImage *vectorImage = nil;
    NSImage **slot = NULL;
    if (pattern == TGSkeuomorphicPatternCanvas) {
        slot = &canvasImage;
    } else if (pattern == TGSkeuomorphicPatternPaper) {
        slot = &paperImage;
    } else if (pattern == TGSkeuomorphicPatternAero) {
        slot = &aeroImage;
    } else if (pattern == TGSkeuomorphicPatternAeroDream) {
        slot = &aeroDreamImage;
    } else if (pattern == TGSkeuomorphicPatternMetro) {
        slot = &metroImage;
    } else if (pattern == TGSkeuomorphicPatternMetroDark) {
        slot = &metroDarkImage;
    } else if (pattern == TGSkeuomorphicPatternY2K) {
        slot = &y2kImage;
    } else if (pattern == TGSkeuomorphicPatternY2KSilver) {
        slot = &y2kSilverImage;
    } else if (pattern == TGSkeuomorphicPatternPixel) {
        slot = &pixelImage;
    } else if (pattern == TGSkeuomorphicPatternMatrix) {
        slot = &matrixImage;
    } else if (pattern == TGSkeuomorphicPatternVector) {
        slot = &vectorImage;
    } else {
        slot = &enamelImage;
    }
    if (*slot) {
        return *slot;
    }

    CGFloat tileSize = 8.0;
    if (pattern == TGSkeuomorphicPatternCanvas) {
        tileSize = 16.0;
    } else if (pattern == TGSkeuomorphicPatternPaper) {
        tileSize = 18.0;
    } else if (pattern == TGSkeuomorphicPatternAero) {
        tileSize = 96.0;
    } else if (pattern == TGSkeuomorphicPatternAeroDream) {
        tileSize = 128.0;
    } else if (pattern == TGSkeuomorphicPatternMetro) {
        tileSize = 96.0;
    } else if (pattern == TGSkeuomorphicPatternMetroDark) {
        tileSize = 128.0;
    } else if (pattern == TGSkeuomorphicPatternY2K) {
        tileSize = 72.0;
    } else if (pattern == TGSkeuomorphicPatternY2KSilver) {
        tileSize = 96.0;
    } else if (pattern == TGSkeuomorphicPatternPixel) {
        tileSize = 24.0;
    } else if (pattern == TGSkeuomorphicPatternMatrix) {
        tileSize = 96.0;
    } else if (pattern == TGSkeuomorphicPatternVector) {
        tileSize = 128.0;
    } else {
        tileSize = 18.0;
    }

    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(tileSize, tileSize)];
    [image lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0.0, 0.0, tileSize, tileSize));

    if (pattern == TGSkeuomorphicPatternCanvas) {
        NSBezierPath *lightThread = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.050] set];
        [lightThread setLineWidth:1.0];
        [lightThread moveToPoint:NSMakePoint(-3.0, 15.0)];
        [lightThread lineToPoint:NSMakePoint(15.0, -3.0)];
        [lightThread moveToPoint:NSMakePoint(7.0, 19.0)];
        [lightThread lineToPoint:NSMakePoint(19.0, 7.0)];
        [lightThread stroke];

        NSBezierPath *shadowThread = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.030] set];
        [shadowThread setLineWidth:1.0];
        [shadowThread moveToPoint:NSMakePoint(-2.0, 7.0)];
        [shadowThread lineToPoint:NSMakePoint(7.0, -2.0)];
        [shadowThread moveToPoint:NSMakePoint(10.0, 18.0)];
        [shadowThread lineToPoint:NSMakePoint(18.0, 10.0)];
        [shadowThread stroke];

        TGDrawPatternDot(5.0, 6.0, 0.020);
        TGDrawPatternDot(12.0, 2.0, 0.018);
    } else if (pattern == TGSkeuomorphicPatternPaper) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.070] set];
        NSRectFill(NSMakeRect(0.0, 1.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedRed:0.34 green:0.48 blue:0.62 alpha:0.090] set];
        NSRectFill(NSMakeRect(0.0, 14.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.050] set];
        NSRectFill(NSMakeRect(0.0, 15.0, tileSize, 1.0));
        TGDrawPatternDot(3.0, 4.0, 0.035);
        TGDrawPatternDot(11.0, 10.0, 0.028);
    } else if (pattern == TGSkeuomorphicPatternAero) {
        NSRect bubbleRects[] = {
            NSMakeRect(6.0, 8.0, 18.0, 18.0),
            NSMakeRect(47.0, 14.0, 9.0, 9.0),
            NSMakeRect(68.0, 58.0, 24.0, 24.0),
            NSMakeRect(20.0, 66.0, 13.0, 13.0)
        };
        NSUInteger bubbleIndex = 0;
        for (bubbleIndex = 0; bubbleIndex < 4; bubbleIndex++) {
            NSBezierPath *bubble = [NSBezierPath bezierPathWithOvalInRect:bubbleRects[bubbleIndex]];
            [[NSColor colorWithCalibratedWhite:1.0 alpha:(bubbleIndex == 2 ? 0.040 : 0.030)] set];
            [bubble fill];
            [[NSColor colorWithCalibratedRed:0.20 green:0.72 blue:0.92 alpha:0.060] set];
            [bubble setLineWidth:1.0];
            [bubble stroke];
        }
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.040] set];
        NSBezierPath *glint = [NSBezierPath bezierPath];
        [glint setLineWidth:1.0];
        [glint moveToPoint:NSMakePoint(2.0, 82.0)];
        [glint curveToPoint:NSMakePoint(96.0, 70.0)
              controlPoint1:NSMakePoint(30.0, 96.0)
              controlPoint2:NSMakePoint(66.0, 54.0)];
        [glint stroke];
        [[NSColor colorWithCalibratedRed:0.0 green:0.36 blue:0.52 alpha:0.018] set];
        NSRectFill(NSMakeRect(0.0, 47.0, tileSize, 1.0));
    } else if (pattern == TGSkeuomorphicPatternAeroDream) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.055] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8.0, 12.0, 25.0, 25.0)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(78.0, 76.0, 17.0, 17.0)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(105.0, 30.0, 8.0, 8.0)] fill];
        [[NSColor colorWithCalibratedRed:0.18 green:0.78 blue:0.95 alpha:0.075] set];
        NSBezierPath *largeBubble = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(46.0, 30.0, 34.0, 34.0)];
        [largeBubble setLineWidth:1.0];
        [largeBubble stroke];

        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.052] set];
        NSBezierPath *cloud = [NSBezierPath bezierPath];
        [cloud appendBezierPathWithOvalInRect:NSMakeRect(9.0, 82.0, 18.0, 10.0)];
        [cloud appendBezierPathWithOvalInRect:NSMakeRect(21.0, 78.0, 24.0, 14.0)];
        [cloud appendBezierPathWithOvalInRect:NSMakeRect(40.0, 83.0, 18.0, 9.0)];
        [cloud fill];

        [[NSColor colorWithCalibratedRed:0.36 green:0.82 blue:0.22 alpha:0.045] set];
        NSBezierPath *grass = [NSBezierPath bezierPath];
        [grass setLineWidth:1.0];
        NSUInteger blade = 0;
        for (blade = 0; blade < 10; blade++) {
            CGFloat x = 8.0 + ((CGFloat)blade * 12.0);
            [grass moveToPoint:NSMakePoint(x, 4.0)];
            [grass curveToPoint:NSMakePoint(x + 6.0, 18.0)
                  controlPoint1:NSMakePoint(x + 1.0, 9.0)
                  controlPoint2:NSMakePoint(x + 8.0, 12.0)];
        }
        [grass stroke];
    } else if (pattern == TGSkeuomorphicPatternMetro) {
        [[NSColor colorWithCalibratedRed:0.10 green:0.55 blue:0.86 alpha:0.055] set];
        NSRectFill(NSMakeRect(0.0, 20.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 64.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(18.0, 0.0, 1.0, tileSize));
        NSRectFill(NSMakeRect(62.0, 0.0, 1.0, tileSize));

        NSBezierPath *blueLine = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedRed:0.05 green:0.52 blue:0.92 alpha:0.125] set];
        [blueLine setLineWidth:3.0];
        [blueLine moveToPoint:NSMakePoint(-8.0, 12.0)];
        [blueLine lineToPoint:NSMakePoint(38.0, 58.0)];
        [blueLine lineToPoint:NSMakePoint(104.0, 58.0)];
        [blueLine stroke];

        NSBezierPath *greenLine = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedRed:0.30 green:0.78 blue:0.28 alpha:0.105] set];
        [greenLine setLineWidth:2.0];
        [greenLine moveToPoint:NSMakePoint(4.0, 90.0)];
        [greenLine lineToPoint:NSMakePoint(44.0, 50.0)];
        [greenLine lineToPoint:NSMakePoint(44.0, -6.0)];
        [greenLine stroke];

        NSBezierPath *orangeLine = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedRed:1.0 green:0.54 blue:0.12 alpha:0.105] set];
        [orangeLine setLineWidth:2.0];
        [orangeLine moveToPoint:NSMakePoint(88.0, -4.0)];
        [orangeLine lineToPoint:NSMakePoint(52.0, 32.0)];
        [orangeLine lineToPoint:NSMakePoint(4.0, 32.0)];
        [orangeLine stroke];

        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.22] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(35.0, 55.0, 7.0, 7.0)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(41.0, 29.0, 6.0, 6.0)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(59.0, 55.0, 6.0, 6.0)] fill];
    } else if (pattern == TGSkeuomorphicPatternMetroDark) {
        [[NSColor colorWithCalibratedRed:1.0 green:0.42 blue:0.06 alpha:0.075] set];
        NSUInteger dotY = 0;
        for (dotY = 0; dotY < 8; dotY++) {
            NSUInteger dotX = 0;
            for (dotX = 0; dotX < 8; dotX++) {
                CGFloat x = (CGFloat)dotX * 16.0 + ((dotY % 2) ? 8.0 : 0.0);
                CGFloat y = (CGFloat)dotY * 16.0;
                [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x + 3.0, y + 3.0, 7.0, 7.0)] fill];
            }
        }

        NSBezierPath *orangeRibbon = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedRed:1.0 green:0.54 blue:0.12 alpha:0.16] set];
        [orangeRibbon setLineWidth:9.0];
        [orangeRibbon moveToPoint:NSMakePoint(-14.0, 32.0)];
        [orangeRibbon curveToPoint:NSMakePoint(142.0, 74.0)
                      controlPoint1:NSMakePoint(30.0, 70.0)
                      controlPoint2:NSMakePoint(90.0, 18.0)];
        [orangeRibbon stroke];

        NSBezierPath *inkSwoop = [NSBezierPath bezierPath];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.20] set];
        [inkSwoop setLineWidth:3.0];
        [inkSwoop moveToPoint:NSMakePoint(4.0, 102.0)];
        [inkSwoop curveToPoint:NSMakePoint(118.0, 10.0)
                 controlPoint1:NSMakePoint(28.0, 56.0)
                 controlPoint2:NSMakePoint(76.0, 144.0)];
        [inkSwoop stroke];

        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(84.0, 18.0, 28.0, 28.0)] stroke];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(92.0, 26.0, 12.0, 12.0)] fill];
    } else if (pattern == TGSkeuomorphicPatternY2K) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.070] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(4.0, 6.0, 24.0, 24.0)] fill];
        [[NSColor colorWithCalibratedRed:0.76 green:0.86 blue:1.0 alpha:0.075] set];
        NSBezierPath *chrome = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(34.0, 11.0, 30.0, 18.0) xRadius:9.0 yRadius:9.0];
        [chrome fill];
        [[NSColor colorWithCalibratedRed:1.0 green:0.14 blue:0.86 alpha:0.060] set];
        NSRectFill(NSMakeRect(0.0, 50.0, tileSize, 2.0));
        [[NSColor colorWithCalibratedRed:0.12 green:0.75 blue:1.0 alpha:0.070] set];
        NSRectFill(NSMakeRect(18.0, 0.0, 2.0, tileSize));
    } else if (pattern == TGSkeuomorphicPatternY2KSilver) {
        NSGradient *chromeWash = [[[NSGradient alloc] initWithColorsAndLocations:
                                   [NSColor colorWithCalibratedWhite:1.0 alpha:0.20], 0.0,
                                   [NSColor colorWithCalibratedWhite:0.52 alpha:0.12], 0.44,
                                   [NSColor colorWithCalibratedWhite:1.0 alpha:0.16], 0.68,
                                   [NSColor colorWithCalibratedWhite:0.35 alpha:0.10], 1.0,
                                   nil] autorelease];
        [chromeWash drawInRect:NSMakeRect(0.0, 0.0, tileSize, tileSize) angle:24.0];

        [[NSColor colorWithCalibratedRed:0.56 green:0.38 blue:1.0 alpha:0.08] set];
        NSBezierPath *wireA = [NSBezierPath bezierPath];
        [wireA setLineWidth:1.0];
        [wireA moveToPoint:NSMakePoint(-8.0, 18.0)];
        [wireA curveToPoint:NSMakePoint(105.0, 72.0)
              controlPoint1:NSMakePoint(22.0, 52.0)
              controlPoint2:NSMakePoint(70.0, 18.0)];
        [wireA stroke];

        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.11] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(7.0, 8.0, 30.0, 30.0)] stroke];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(62.0, 50.0, 18.0, 18.0)] fill];

        [[NSColor colorWithCalibratedRed:1.0 green:0.48 blue:0.94 alpha:0.09] set];
        NSRectFill(NSMakeRect(0.0, 70.0, tileSize, 2.0));
        [[NSColor colorWithCalibratedRed:0.26 green:0.95 blue:1.0 alpha:0.08] set];
        NSRectFill(NSMakeRect(42.0, 0.0, 2.0, tileSize));
    } else if (pattern == TGSkeuomorphicPatternPixel) {
        [[NSColor colorWithCalibratedRed:0.09 green:0.55 blue:0.15 alpha:0.13] set];
        NSRectFill(NSMakeRect(0.0, 0.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 8.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 16.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedRed:0.13 green:1.0 blue:0.28 alpha:0.13] set];
        NSRectFill(NSMakeRect(3.0, 5.0, 2.0, 2.0));
        NSRectFill(NSMakeRect(11.0, 13.0, 3.0, 2.0));
        NSRectFill(NSMakeRect(18.0, 2.0, 2.0, 4.0));
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.028] set];
        NSRectFill(NSMakeRect(0.0, 4.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 12.0, tileSize, 1.0));
    } else if (pattern == TGSkeuomorphicPatternMatrix) {
        [[NSColor colorWithCalibratedRed:0.13 green:1.0 blue:0.28 alpha:0.12] set];
        NSUInteger column = 0;
        for (column = 0; column < 8; column++) {
            CGFloat x = 5.0 + (CGFloat)column * 12.0;
            NSUInteger glyph = 0;
            for (glyph = 0; glyph < 6; glyph++) {
                CGFloat y = (CGFloat)((column * 9 + glyph * 13) % 96);
                CGFloat a = 0.03 + ((CGFloat)((glyph + column) % 4) * 0.018);
                [[NSColor colorWithCalibratedRed:0.28 green:1.0 blue:0.40 alpha:a] set];
                NSRectFill(NSMakeRect(x, y, 2.0, 6.0));
                if ((glyph + column) % 3 == 0) {
                    NSRectFill(NSMakeRect(x + 4.0, y + 2.0, 2.0, 2.0));
                }
            }
        }
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.035] set];
        NSRectFill(NSMakeRect(0.0, 14.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 46.0, tileSize, 1.0));
        NSRectFill(NSMakeRect(0.0, 78.0, tileSize, 1.0));
    } else if (pattern == TGSkeuomorphicPatternVector) {
        [[NSColor colorWithCalibratedRed:0.05 green:0.55 blue:0.86 alpha:0.075] set];
        NSUInteger ray = 0;
        for (ray = 0; ray < 7; ray++) {
            NSBezierPath *band = [NSBezierPath bezierPath];
            CGFloat x = -20.0 + (CGFloat)ray * 24.0;
            [band moveToPoint:NSMakePoint(64.0, 64.0)];
            [band lineToPoint:NSMakePoint(x, 140.0)];
            [band lineToPoint:NSMakePoint(x + 15.0, 140.0)];
            [band closePath];
            [band fill];
        }

        [[NSColor colorWithCalibratedRed:0.36 green:0.78 blue:0.18 alpha:0.095] set];
        NSBezierPath *inkCloud = [NSBezierPath bezierPath];
        [inkCloud appendBezierPathWithOvalInRect:NSMakeRect(8.0, 8.0, 26.0, 26.0)];
        [inkCloud appendBezierPathWithOvalInRect:NSMakeRect(28.0, 19.0, 18.0, 18.0)];
        [inkCloud appendBezierPathWithOvalInRect:NSMakeRect(86.0, 70.0, 24.0, 24.0)];
        [inkCloud fill];

        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.14] set];
        NSBezierPath *speakerLine = [NSBezierPath bezierPath];
        [speakerLine setLineWidth:5.0];
        [speakerLine moveToPoint:NSMakePoint(4.0, 98.0)];
        [speakerLine curveToPoint:NSMakePoint(122.0, 22.0)
                    controlPoint1:NSMakePoint(36.0, 118.0)
                    controlPoint2:NSMakePoint(78.0, -8.0)];
        [speakerLine stroke];

        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] set];
        NSBezierPath *whiteCut = [NSBezierPath bezierPath];
        [whiteCut setLineWidth:3.0];
        [whiteCut moveToPoint:NSMakePoint(12.0, 31.0)];
        [whiteCut lineToPoint:NSMakePoint(118.0, 116.0)];
        [whiteCut stroke];
    } else {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.035] set];
        NSRectFill(NSMakeRect(0.0, 2.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.024] set];
        NSRectFill(NSMakeRect(4.0, 0.0, 1.0, tileSize));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.018] set];
        NSRectFill(NSMakeRect(0.0, 15.0, tileSize, 1.0));
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.014] set];
        NSRectFill(NSMakeRect(13.0, 0.0, 1.0, tileSize));
        TGDrawPatternDot(8.0, 8.0, 0.012);
    }
    [image unlockFocus];
    *slot = image;
    return *slot;
}

static TGSkeuomorphicPattern TGThemeCurrentAeroPattern(void) {
    if (TGThemeIsFrutigerMetroDark()) {
        return TGSkeuomorphicPatternMetroDark;
    }
    if (TGThemeIsFrutigerMetro()) {
        return TGSkeuomorphicPatternMetro;
    }
    return TGThemeIsFrutigerAeroDream() ? TGSkeuomorphicPatternAeroDream : TGSkeuomorphicPatternAero;
}

static TGSkeuomorphicPattern TGThemeCurrentExperimentalPattern(void) {
    NSString *identifier = TGCurrentThemeIdentifier();
    if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
        return TGSkeuomorphicPatternY2K;
    }
    if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
        return TGSkeuomorphicPatternY2KSilver;
    }
    if ([identifier isEqualToString:TGThemeIdentifierPixelTerminal]) {
        return TGSkeuomorphicPatternPixel;
    }
    if ([identifier isEqualToString:TGThemeIdentifierMatrixRain]) {
        return TGSkeuomorphicPatternMatrix;
    }
    return TGSkeuomorphicPatternVector;
}

static void TGThemeDrawPatternInClippedRect(NSRect rect, TGSkeuomorphicPattern pattern, CGFloat alpha) {
    (void)alpha;
    NSColor *patternColor = [NSColor colorWithPatternImage:TGSkeuomorphicPatternImage(pattern)];
    [patternColor set];
    NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}

static void TGThemeDrawInnerShadow(NSBezierPath *path, NSRect rect, CGFloat alpha) {
    (void)rect;
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:alpha] set];
    [path setLineWidth:1.0];
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];
}

void TGThemeDrawWindowBackgroundInRect(NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [TGClassicWindowBottomColor() set];
        NSRectFill(rect);
        return;
    }
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x06120a)
                                                      endingColor:TGColorFromHex(0x000000)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x3b65e8)
                                                      endingColor:TGColorFromHex(0xe8efff)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xdde5f2)
                                                      endingColor:TGColorFromHex(0x667184)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf6fff8)
                                                      endingColor:TGColorFromHex(0x159bd4)] autorelease];
        }
        [gradient drawInRect:rect angle:90.0];
        TGThemeDrawPatternInClippedRect(rect, TGThemeCurrentExperimentalPattern(), 0.30);
        return;
    }
    if (TGThemeIsFrutigerAeroDream()) {
        NSRect skyRect = NSMakeRect(NSMinX(rect), NSMinY(rect) + floor(NSHeight(rect) * 0.26), NSWidth(rect), ceil(NSHeight(rect) * 0.74));
        NSRect grassRect = NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), ceil(NSHeight(rect) * 0.34));
        NSGradient *skyGradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf4fbff)
                                                                 endingColor:TGColorFromHex(0x36a9ee)] autorelease];
        [skyGradient drawInRect:skyRect angle:90.0];
        NSGradient *grassGradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xbdf26a)
                                                                   endingColor:TGColorFromHex(0x42b84a)] autorelease];
        [grassGradient drawInRect:grassRect angle:90.0];
        [[NSColor colorWithCalibratedRed:0.36 green:0.88 blue:1.0 alpha:0.18] set];
        NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMinY(rect) + floor(NSHeight(rect) * 0.30), NSWidth(rect), 8.0), NSCompositeSourceOver);
        NSRect sunRect = NSMakeRect(NSMaxX(rect) - 98.0, NSMaxY(rect) - 92.0, 68.0, 68.0);
        NSGradient *sunGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.85]
                                                                 endingColor:[NSColor colorWithCalibratedRed:0.55 green:0.90 blue:1.0 alpha:0.0]] autorelease];
        [sunGradient drawInBezierPath:[NSBezierPath bezierPathWithOvalInRect:sunRect] angle:90.0];
        TGThemeDrawPatternInClippedRect(rect, TGSkeuomorphicPatternAeroDream, 0.35);
        return;
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x3b1f10)
                                                  endingColor:TGColorFromHex(0x120905)] autorelease];
    } else if (TGThemeIsFrutigerMetro()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf6fcff)
                                                  endingColor:TGColorFromHex(0x65cde6)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x69c8e1)
                                                  endingColor:TGColorFromHex(0xd8f6ee)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x3b5161)
                                                  endingColor:TGColorFromHex(0x223747)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternCanvas, 0.35);
}

void TGThemeDrawPanelBackgroundInPath(NSBezierPath *path, NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [TGClassicPanelBottomColor() set];
        [path fill];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x0a1d0f)
                                                      endingColor:TGColorFromHex(0x031007)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xd3dce9)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xe2edff)] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x3a2315)
                                                  endingColor:TGColorFromHex(0x1d1008)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf8ffff)
                                                  endingColor:TGColorFromHex(0xcfeef2)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xe6edf0)
                                                  endingColor:TGColorFromHex(0xc5d2d9)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternEnamel), 0.28);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.24] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMaxY(rect) - 1.0, NSWidth(rect), 1.0), NSCompositeSourceOver);
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.12] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
}

void TGThemeDrawRailBackgroundInPath(NSBezierPath *path, NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [TGClassicWindowBottomColor() set];
        [path fill];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x0d2a13)
                                                      endingColor:TGColorFromHex(0x020804)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x4d69d8)
                                                      endingColor:TGColorFromHex(0x20264c)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xbec8d8)
                                                      endingColor:TGColorFromHex(0x596273)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x2b7fdb)
                                                      endingColor:TGColorFromHex(0x17345d)] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x4d2a14)
                                                  endingColor:TGColorFromHex(0x1b0f08)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x2c9fca)
                                                  endingColor:TGColorFromHex(0x16455e)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x3a4d59)
                                                  endingColor:TGColorFromHex(0x223644)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternCanvas), 0.35);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.14] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 1.0, NSMaxY(rect) - 1.0, NSWidth(rect) - 2.0, 1.0), NSCompositeSourceOver);
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.24] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 1.0, NSMinY(rect), NSWidth(rect) - 2.0, 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
}

void TGThemeDrawHeaderBackgroundInRect(NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [TGClassicHeaderBottomColor() set];
        NSRectFill(rect);
        return;
    }
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x12421d)
                                                      endingColor:TGColorFromHex(0x041208)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x7890ff)
                                                      endingColor:TGColorFromHex(0x3151d6)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf4f6fa)
                                                      endingColor:TGColorFromHex(0x8a96aa)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x42a4ee)
                                                      endingColor:TGColorFromHex(0x185fc2)] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf08a2a)
                                                  endingColor:TGColorFromHex(0x8a3d12)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x63c7e8)
                                                  endingColor:TGColorFromHex(0x207eaa)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x4d789c)
                                                  endingColor:TGColorFromHex(0x29465e)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternCanvas), 0.32);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMaxY(rect) - 1.0, NSWidth(rect), 1.0), NSCompositeSourceOver);
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMinY(rect), NSWidth(rect), 1.0), NSCompositeSourceOver);
}

void TGThemeDrawRecessedBackgroundInPath(NSBezierPath *path, NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [TGClassicTablePaperColor() set];
        [path fill];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x07170b)
                                                      endingColor:TGColorFromHex(0x020904)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xe7ecf3)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xe9f3ff)] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x2a1b12)
                                                  endingColor:TGColorFromHex(0x180d07)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xe8fbff)
                                                  endingColor:TGColorFromHex(0xf7fff8)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xd8d7ce)
                                                  endingColor:TGColorFromHex(0xf4f0e6)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternPaper), 0.30);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.24] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 2.0, NSMinY(rect) + 1.0, NSWidth(rect) - 4.0, 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.13] set];
    [path setLineWidth:1.0];
    [path stroke];
}

void TGThemeDrawGroupedCardInPath(NSBezierPath *path, NSRect rect, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [[NSColor colorWithCalibratedWhite:0.985 alpha:1.0] set];
        [path fill];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x0a1b0e)
                                                      endingColor:TGColorFromHex(0x041006)] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xe4e9f2)] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                      endingColor:TGColorFromHex(0xeaf4ff)] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x342116)
                                                  endingColor:TGColorFromHex(0x21130b)] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xffffff)
                                                  endingColor:TGColorFromHex(0xdff7f4)] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0xf7f3e9)
                                                  endingColor:TGColorFromHex(0xe7dfcf)] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternPaper), 0.25);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.36] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect), NSMaxY(rect) - 1.0, NSWidth(rect), 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
}

void TGThemeDrawEnamelButtonInPath(NSBezierPath *path, NSRect rect, BOOL highlighted, BOOL selected, BOOL enabled, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        NSColor *fillColor = selected ? TGClassicNavigationSelectedColor(enabled ? 1.0 : 0.46)
                                      : (highlighted ? TGClassicNavigationHighlightedColor(enabled ? 1.0 : 0.46)
                                                     : TGClassicNavigationNormalColor(enabled ? 1.0 : 0.46));
        [fillColor set];
        [path fill];
        return;
    }
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSColor *top = nil;
    NSColor *bottom = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            if (highlighted) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x0b2411), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x020804), alpha);
            } else if (selected) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x1f7a32), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x083114), alpha);
            } else {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x145122), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x041407), alpha);
            }
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KChrome]) {
            if (highlighted) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x263ca5), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x141a55), alpha);
            } else if (selected) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0xaed2ff), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x4d67e4), alpha);
            } else {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x7c93ff), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x3552dd), alpha);
            }
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            if (highlighted) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x6c7586), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x363f4f), alpha);
            } else if (selected) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0xffffff), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x9aa7bc), alpha);
            } else {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0xe8edf6), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x8f9bae), alpha);
            }
        } else {
            if (highlighted) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x1253a5), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x082d62), alpha);
            } else if (selected) {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x78d8ff), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x217bd8), alpha);
            } else {
                top = TGColorFromRGBWithAlpha(TGRGBMake(0x48a9f2), alpha);
                bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x1969c9), alpha);
            }
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        if (highlighted) {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0x6a3215), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x2a1509), alpha);
        } else if (selected) {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0xffa14a), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0xbd5318), alpha);
        } else {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0xd36d22), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x7b3714), alpha);
        }
    } else if (TGThemeIsFrutigerAero()) {
        if (highlighted) {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0x1f81a9), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x115372), alpha);
        } else if (selected) {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0x8ce9f5), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x2aa0cd), alpha);
        } else {
            top = TGColorFromRGBWithAlpha(TGRGBMake(0x62c7e7), alpha);
            bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x267fa9), alpha);
        }
    } else if (highlighted) {
        top = TGColorFromRGBWithAlpha(TGRGBMake(0x335875), alpha);
        bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x1d3448), alpha);
    } else if (selected) {
        top = TGColorFromRGBWithAlpha(TGRGBMake(0x6fa7d1), alpha);
        bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x38698d), alpha);
    } else {
        top = TGColorFromRGBWithAlpha(TGRGBMake(0x4d789c), alpha);
        bottom = TGColorFromRGBWithAlpha(TGRGBMake(0x29465e), alpha);
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternEnamel), 0.20);
    if (!highlighted) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:(0.24 * alpha)] set];
        NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 2.0, NSMaxY(rect) - 2.0, NSWidth(rect) - 4.0, 1.0), NSCompositeSourceOver);
    }
    [[NSColor colorWithCalibratedWhite:0.0 alpha:(highlighted ? 0.22 : 0.15) * alpha] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 1.0, NSMinY(rect), NSWidth(rect) - 2.0, 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
}

void TGThemeDrawMessageBubbleInPath(NSBezierPath *path, NSRect rect, BOOL outgoing, BOOL flipped) {
    (void)flipped;
    if (!TGThemeUsesLayeredMaterials()) {
        [(outgoing ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor()) set];
        [path fill];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [path addClip];
    NSGradient *gradient = nil;
    if (TGThemeIsExperimental2000s()) {
        NSString *identifier = TGCurrentThemeIdentifier();
        if (TGThemeIsTerminalLikeIdentifier(identifier)) {
            gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0x10361a) : TGColorFromHex(0x07170b))
                                                      endingColor:(outgoing ? TGColorFromHex(0x08200f) : TGColorFromHex(0x020904))] autorelease];
        } else if ([identifier isEqualToString:TGThemeIdentifierY2KSilver]) {
            gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0xeaf0f8) : TGColorFromHex(0xffffff))
                                                      endingColor:(outgoing ? TGColorFromHex(0xcfd9e8) : TGColorFromHex(0xecf0f6))] autorelease];
        } else {
            gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0xddecff) : TGColorFromHex(0xffffff))
                                                      endingColor:(outgoing ? TGColorFromHex(0xc0dcff) : TGColorFromHex(0xecf4ff))] autorelease];
        }
    } else if (TGThemeIsFrutigerMetroDark()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0x4a2816) : TGColorFromHex(0x2b1a10))
                                                  endingColor:(outgoing ? TGColorFromHex(0x2f180c) : TGColorFromHex(0x1d1009))] autorelease];
    } else if (TGThemeIsFrutigerAero()) {
        gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0xd8f8ff) : TGColorFromHex(0xffffff))
                                                  endingColor:(outgoing ? TGColorFromHex(0xa9e7f2) : TGColorFromHex(0xe8fbf5))] autorelease];
    } else {
        gradient = [[[NSGradient alloc] initWithStartingColor:(outgoing ? TGColorFromHex(0xe5eef4) : TGColorFromHex(0xfffbf2))
                                                  endingColor:(outgoing ? TGColorFromHex(0xc7dcea) : TGColorFromHex(0xeee5d5))] autorelease];
    }
    [gradient drawInRect:rect angle:90.0];
    TGThemeDrawPatternInClippedRect(rect, TGThemeIsExperimental2000s() ? TGThemeCurrentExperimentalPattern() : (TGThemeIsFrutigerAero() ? TGThemeCurrentAeroPattern() : TGSkeuomorphicPatternPaper), outgoing ? 0.20 : 0.28);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.30] set];
    NSRectFillUsingOperation(NSMakeRect(NSMinX(rect) + 5.0, NSMaxY(rect) - 2.0, NSWidth(rect) - 10.0, 1.0), NSCompositeSourceOver);
    [NSGraphicsContext restoreGraphicsState];
    TGThemeDrawInnerShadow(path, rect, 0.06);
}
