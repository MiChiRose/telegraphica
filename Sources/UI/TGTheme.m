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
            nil];
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
