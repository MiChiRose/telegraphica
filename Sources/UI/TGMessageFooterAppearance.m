#import "TGMessageFooterAppearance.h"
#import "TGTheme.h"
#import "TGChatDisplayPreferences.h"
#import "../Core/TGMessageItem.h"
#include <math.h>

static CGFloat TGMessageColorLuminance(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat channels[] = {[rgb redComponent], [rgb greenComponent], [rgb blueComponent]};
    NSUInteger index = 0;
    for (index = 0; index < 3; index++) {
        channels[index] = channels[index] <= 0.04045 ? channels[index] / 12.92 : pow((channels[index] + 0.055) / 1.055, 2.4);
    }
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

NSColor *TGMessageMetadataSurfaceColor(TGMessageItem *item, BOOL flipped) {
    if (!TGChatMessagesAsBlocksEnabled()) { return TGThemeMessageBubbleFooterColor([item outgoing], flipped); }
    NSColor *bubble = [([item outgoing] ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor()) colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSColor *paper = [TGClassicTablePaperColor() colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat alpha = [item outgoing] ? 0.50 : 0.62;
    return [NSColor colorWithCalibratedRed:[bubble redComponent] * alpha + [paper redComponent] * (1.0 - alpha)
                                   green:[bubble greenComponent] * alpha + [paper greenComponent] * (1.0 - alpha)
                                    blue:[bubble blueComponent] * alpha + [paper blueComponent] * (1.0 - alpha) alpha:1.0];
}

static NSColor *TGMessageReadableInk(NSColor *preferred, NSColor *surface, CGFloat minimumContrast) {
    NSColor *rgb = [preferred colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat background = TGMessageColorLuminance(surface);
    CGFloat endpoint = background > 0.179 ? 0.0 : 1.0;
    NSUInteger step = 0;
    for (step = 0; step <= 20; step++) {
        CGFloat mix = (CGFloat)step / 20.0;
        NSColor *candidate = [NSColor colorWithCalibratedRed:[rgb redComponent] * (1.0 - mix) + endpoint * mix
                                                      green:[rgb greenComponent] * (1.0 - mix) + endpoint * mix
                                                       blue:[rgb blueComponent] * (1.0 - mix) + endpoint * mix alpha:1.0];
        CGFloat ink = TGMessageColorLuminance(candidate);
        if ((MAX(background, ink) + 0.05) / (MIN(background, ink) + 0.05) >= minimumContrast || step == 20) {
            return candidate;
        }
    }
    return preferred;
}

static NSColor *TGMessageCachedFooterInk(NSString *role, TGMessageItem *item, BOOL flipped, NSColor *preferred, CGFloat minimumContrast) {
    static NSCache *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [[NSCache alloc] init]; [cache setCountLimit:256]; });
    NSString *key = [NSString stringWithFormat:@"%@|%@|%d|%d|%d", role, TGCurrentThemeIdentifier(),
                     [item outgoing], flipped, TGChatMessagesAsBlocksEnabled()];
    NSColor *ink = [cache objectForKey:key];
    if (!ink) {
        ink = TGMessageReadableInk(preferred, TGMessageMetadataSurfaceColor(item, flipped), minimumContrast);
        [cache setObject:ink forKey:key];
    }
    return ink;
}

NSColor *TGMessageMetadataInkColor(TGMessageItem *item, BOOL flipped) {
    return TGMessageCachedFooterInk(@"time", item, flipped, TGClassicTimeTextColor(), 4.5);
}

NSColor *TGMessageDeliveryStatusInkColor(TGMessageItem *item, BOOL active, BOOL flipped) {
    NSColor *preferred = [NSColor colorWithCalibratedWhite:(active ? 0.38 : 0.72) alpha:1.0];
    return TGMessageCachedFooterInk(active ? @"status-active" : @"status-inactive", item, flipped, preferred, active ? 4.5 : 3.0);
}
