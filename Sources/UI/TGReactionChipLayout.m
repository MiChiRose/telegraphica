#import "TGReactionChipLayout.h"
#import "TGMessageLayoutSupport.h"
#import "TGTheme.h"
#import "../Core/TGMessageItem.h"

static NSFont *TGReactionEmojiFont(void) {
    static NSFont *font = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        font = [[NSFont fontWithName:@"Apple Color Emoji" size:14.0] retain];
        if (!font) { font = [[NSFont systemFontOfSize:14.0] retain]; }
    });
    return font;
}

static NSString *TGReactionDisplaySummary(TGMessageItem *item) {
    return [[item reactionAnimationDisplaySummary] length] > 0
        ? [item reactionAnimationDisplaySummary] : [item reactionSummary];
}

static NSString *TGReactionDisplayEmoji(NSString *emoji) {
    NSString *display = TGStringByReplacingUnrenderableEmoji(emoji, TGReactionEmojiFont());
    if (![display isEqualToString:emoji]) {
        // Older AppKit may reject the presentation selector of a stock emoji.
        NSString *base = [emoji stringByReplacingOccurrencesOfString:@"\uFE0F" withString:@""];
        NSString *baseDisplay = TGStringByReplacingUnrenderableEmoji(base, TGReactionEmojiFont());
        if ([baseDisplay isEqualToString:base]) { return base; }
    }
    return display;
}

NSArray *TGReactionChipLayoutForItem(TGMessageItem *item, CGFloat innerWidth) {
    NSString *summary = TGReactionDisplaySummary(item);
    if ([summary length] == 0 || innerWidth <= 0.0) { return [NSArray array]; }
    NSMutableArray *layout = [NSMutableArray array];
    NSDictionary *emojiAttributes = [NSDictionary dictionaryWithObject:TGReactionEmojiFont() forKey:NSFontAttributeName];
    NSDictionary *countAttributes = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:11.0] forKey:NSFontAttributeName];
    CGFloat x = 0.0, y = 0.0;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet *notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    for (NSString *part in [summary componentsSeparatedByString:@"  "]) {
        NSString *entry = [part stringByTrimmingCharactersInSet:whitespace];
        if ([entry length] == 0) { continue; }
        NSString *emoji = entry;
        NSString *count = @"1";
        NSRange separator = [entry rangeOfString:@" " options:NSBackwardsSearch];
        if (separator.location != NSNotFound) {
            NSString *suffix = [entry substringFromIndex:NSMaxRange(separator)];
            if ([suffix length] > 0 && [suffix rangeOfCharacterFromSet:notDigits].location == NSNotFound) {
                emoji = [entry substringToIndex:separator.location];
                count = suffix;
            }
        }
        NSString *displayEmoji = TGReactionDisplayEmoji(emoji);
        CGFloat emojiWidth = MAX(18.0, ceil([displayEmoji sizeWithAttributes:emojiAttributes].width));
        CGFloat countWidth = ceil([count sizeWithAttributes:countAttributes].width);
        CGFloat width = MIN(innerWidth, 16.0 + emojiWidth + 4.0 + countWidth);
        if (x > 0.0 && x + width > innerWidth) { x = 0.0; y += 28.0; }
        NSRect frame = NSMakeRect(x, y, width, 24.0);
        [layout addObject:[NSDictionary dictionaryWithObjectsAndKeys:
            emoji, @"emoji", displayEmoji, @"display_emoji", count, @"count",
            [NSNumber numberWithDouble:emojiWidth], @"emoji_width",
            [NSValue valueWithRect:frame], @"frame", nil]];
        x += width + 4.0;
    }
    return layout;
}

CGFloat TGReactionChipsMinimumWidthForItem(TGMessageItem *item) {
    CGFloat width = 0.0;
    for (NSDictionary *entry in TGReactionChipLayoutForItem(item, 1000.0)) {
        width = MAX(width, NSWidth([[entry objectForKey:@"frame"] rectValue]));
    }
    return width;
}

static NSColor *TGReactionChosenInk(NSColor *background) {
    NSColor *rgb = [background colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat r = [rgb redComponent], g = [rgb greenComponent], b = [rgb blueComponent];
    r = r <= 0.04045 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
    g = g <= 0.04045 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
    b = b <= 0.04045 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.179
        ? [NSColor blackColor] : [NSColor whiteColor];
}

CGFloat TGReactionChipsHeightForItem(TGMessageItem *item, CGFloat innerWidth) {
    NSArray *layout = TGReactionChipLayoutForItem(item, innerWidth);
    if ([layout count] == 0) { return 0.0; }
    CGFloat height = NSMaxY([[[layout lastObject] objectForKey:@"frame"] rectValue]) + 6.0;
    if (![item reactionAnimationChangesHeight]) { return height; }
    CGFloat progress = MAX(0.0, MIN(1.0, [item reactionAnimationProgress]));
    CGFloat phase = [item reactionAnimationRemoving]
        ? (progress <= 0.45 ? 1.0 : MAX(0.0, 1.0 - (progress - 0.45) / 0.55))
        : MIN(1.0, progress / 0.50);
    CGFloat inverse = 1.0 - phase;
    return height * (1.0 - inverse * inverse * inverse);
}

void TGDrawReactionChipsForItem(TGMessageItem *item, NSRect bandRect, BOOL flipped) {
    NSArray *layout = TGReactionChipLayoutForItem(item, NSWidth(bandRect));
    if ([layout count] == 0 || NSHeight(bandRect) <= 0.0) { return; }
    BOOL animating = [[item reactionAnimationDisplaySummary] length] > 0;
    CGFloat progress = animating ? MAX(0.0, MIN(1.0, [item reactionAnimationProgress])) : 1.0;
    CGFloat opacity = [item reactionAnimationRemoving] && animating
        ? MAX(0.0, 1.0 - progress / 0.55)
        : (animating ? MAX(0.0, MIN(1.0, (progress - 0.46) / 0.54)) : 1.0);
    if (opacity <= 0.0) { return; }
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(bandRect);
    for (NSDictionary *entry in layout) {
        NSRect local = [[entry objectForKey:@"frame"] rectValue];
        NSRect rect = NSMakeRect(NSMinX(bandRect) + NSMinX(local),
            flipped ? NSMinY(bandRect) + 2.0 + NSMinY(local) : NSMaxY(bandRect) - 2.0 - NSMaxY(local),
            NSWidth(local), NSHeight(local));
        BOOL chosen = [[item chosenReactionEmojis] containsObject:[entry objectForKey:@"emoji"]];
        NSColor *background = chosen ? TGClassicNavigationSelectedColor(1.0)
            : [NSColor colorWithCalibratedRed:0.86 green:0.92 blue:0.97 alpha:1.0];
        NSColor *ink = chosen ? TGReactionChosenInk(background)
            : [NSColor colorWithCalibratedRed:0.12 green:0.35 blue:0.57 alpha:1.0];
        [[background colorWithAlphaComponent:opacity] set];
        [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:12.0 yRadius:12.0] fill];
        NSDictionary *emojiAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            TGReactionEmojiFont(), NSFontAttributeName, [ink colorWithAlphaComponent:opacity], NSForegroundColorAttributeName, nil];
        NSDictionary *countAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont boldSystemFontOfSize:11.0], NSFontAttributeName, [ink colorWithAlphaComponent:opacity], NSForegroundColorAttributeName, nil];
        NSString *emoji = [entry objectForKey:@"display_emoji"], *count = [entry objectForKey:@"count"];
        NSSize emojiSize = [emoji sizeWithAttributes:emojiAttributes], countSize = [count sizeWithAttributes:countAttributes];
        CGFloat emojiWidth = [[entry objectForKey:@"emoji_width"] doubleValue];
        // Apple Color Emoji's line box places its visible glyph below the
        // centre of ordinary numeric text on legacy AppKit.
        CGFloat emojiY = NSMidY(rect) - floor(emojiSize.height / 2.0) + (flipped ? -2.0 : 2.0);
        [emoji drawInRect:NSMakeRect(NSMinX(rect) + 8.0, emojiY, emojiWidth, emojiSize.height + 1.0) withAttributes:emojiAttributes];
        [count drawInRect:NSMakeRect(NSMinX(rect) + 8.0 + emojiWidth + 4.0, NSMidY(rect) - floor(countSize.height / 2.0), MAX(0.0, NSWidth(rect) - emojiWidth - 20.0), countSize.height + 1.0) withAttributes:countAttributes];
    }
    [NSGraphicsContext restoreGraphicsState];
}
