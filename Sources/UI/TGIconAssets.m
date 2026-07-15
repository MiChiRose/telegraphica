#import "TGIconAssets.h"

static NSMutableDictionary *TGIconAssetSourceCache(void) {
    static NSMutableDictionary *cache = nil;
    if (!cache) {
        cache = [[NSMutableDictionary alloc] init];
    }
    return cache;
}

static NSMutableDictionary *TGIconAssetRenderedCache(void) {
    static NSMutableDictionary *cache = nil;
    if (!cache) {
        cache = [[NSMutableDictionary alloc] init];
    }
    return cache;
}

static NSString *TGIconAssetCacheKey(NSString *name, NSSize size, NSColor *color, CGFloat alpha) {
    CGFloat red = 0.0;
    CGFloat green = 0.0;
    CGFloat blue = 0.0;
    CGFloat colorAlpha = 0.0;
    if (color) {
        NSColor *rgb = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        if (rgb) {
            [rgb getRed:&red green:&green blue:&blue alpha:&colorAlpha];
        }
    }
    return [NSString stringWithFormat:@"%@|%.1fx%.1f|%.3f,%.3f,%.3f,%.3f|%.3f",
            name, size.width, size.height, red, green, blue, colorAlpha, alpha];
}

static NSString *TGIconAssetPathForName(NSString *name) {
    if ([name length] == 0) {
        return nil;
    }
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:name ofType:@"png" inDirectory:@"Icons"];
    if ([path length] == 0) {
        path = [bundle pathForResource:name ofType:@"png"];
    }
    return path;
}

NSImage *TGIconAssetImageNamed(NSString *name) {
    if ([name length] == 0) {
        return nil;
    }
    NSMutableDictionary *cache = TGIconAssetSourceCache();
    NSImage *cached = [cache objectForKey:name];
    if (cached) {
        return cached;
    }
    NSString *path = TGIconAssetPathForName(name);
    if ([path length] == 0) {
        return nil;
    }
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    if (!image) {
        return nil;
    }
    [cache setObject:image forKey:name];
    return image;
}

NSImage *TGTemplateIconAssetImage(NSString *name, NSSize size, NSColor *color, CGFloat alpha) {
    NSImage *source = TGIconAssetImageNamed(name);
    if (!source || size.width <= 0.0 || size.height <= 0.0) {
        return nil;
    }

    NSSize sourceSize = [source size];
    if (sourceSize.width <= 0.0 || sourceSize.height <= 0.0) {
        return nil;
    }

    NSString *cacheKey = TGIconAssetCacheKey(name, size, color, alpha);
    NSImage *cached = [TGIconAssetRenderedCache() objectForKey:cacheKey];
    if (cached) {
        return cached;
    }

    NSImage *tinted = [[[NSImage alloc] initWithSize:size] autorelease];
    [tinted lockFocus];
    NSRect targetRect = NSMakeRect(0.0, 0.0, size.width, size.height);
    [source drawInRect:targetRect
              fromRect:NSZeroRect
             operation:NSCompositeSourceOver
              fraction:1.0
        respectFlipped:NO
                 hints:nil];
    if (color) {
        [[color colorWithAlphaComponent:alpha] set];
        NSRectFillUsingOperation(targetRect, NSCompositeSourceIn);
    }
    [tinted unlockFocus];
    [TGIconAssetRenderedCache() setObject:tinted forKey:cacheKey];
    return tinted;
}

void TGDrawTemplateIconAsset(NSString *name, NSRect rect, NSColor *color, CGFloat alpha, BOOL flipped) {
    if (NSIsEmptyRect(rect)) {
        return;
    }
    NSImage *tinted = TGTemplateIconAssetImage(name, rect.size, color, alpha);
    if (!tinted) {
        return;
    }
    [tinted drawInRect:rect
              fromRect:NSZeroRect
             operation:NSCompositeSourceOver
              fraction:(color ? 1.0 : alpha)
        respectFlipped:flipped
                 hints:nil];
}
