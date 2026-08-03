#import "TGCustomEmojiImageLoader.h"
#import "TGMediaImageLoader.h"
#import "../Core/TGCustomEmojiParser.h"
#import "../Services/TGResourcePolicy.h"

NSString * const TGCustomEmojiImageDidLoadNotification = @"TGCustomEmojiImageDidLoadNotification";
NSString * const TGCustomEmojiImageIdentifierUserInfoKey = @"custom_emoji_id";

static NSCache *TGCustomEmojiImageCache(void) {
    static NSCache *cache = nil;
    @synchronized([NSImage class]) {
        if (!cache) {
            cache = [[NSCache alloc] init];
            [cache setCountLimit:96];
            [cache setTotalCostLimit:(12 * 1024 * 1024)];
        }
    }
    return cache;
}

static NSMutableSet *TGCustomEmojiPendingKeys(void) {
    static NSMutableSet *keys = nil;
    if (!keys) {
        keys = [[NSMutableSet alloc] init];
    }
    return keys;
}

static NSString *TGCustomEmojiCacheKey(NSDictionary *entity, NSUInteger maximumPixelSize) {
    id identifier = [entity objectForKey:TGCustomEmojiIdentifierKey];
    NSString *path = [entity objectForKey:TGCustomEmojiLocalPathKey];
    NSString *format = [entity objectForKey:TGCustomEmojiFormatKey];
    if (![identifier respondsToSelector:@selector(longLongValue)] || [identifier longLongValue] <= 0 ||
        ![path isKindOfClass:[NSString class]] || [path length] == 0 || maximumPixelSize == 0) {
        return nil;
    }
    if ([format length] > 0 && ![format isEqualToString:@"stickerFormatWebp"] &&
        ![format isEqualToString:@"stickerFormatStatic"]) {
        return nil;
    }
    NSString *resolvedPath = [path stringByStandardizingPath];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:resolvedPath error:NULL];
    NSNumber *size = [attributes objectForKey:NSFileSize];
    NSDate *modified = [attributes objectForKey:NSFileModificationDate];
    return [NSString stringWithFormat:@"%lld:%lu:%@:%@:%0.6f",
            [identifier longLongValue],
            (unsigned long)maximumPixelSize,
            resolvedPath,
            (size ?: @0),
            ([modified isKindOfClass:[NSDate class]] ? [modified timeIntervalSince1970] : 0.0)];
}

NSImage *TGCustomEmojiCachedImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize) {
    NSString *key = TGCustomEmojiCacheKey(entity, maximumPixelSize);
    if ([key length] == 0) {
        return nil;
    }
    NSImage *image = [TGCustomEmojiImageCache() objectForKey:key];
    return [[image retain] autorelease];
}

void TGCustomEmojiRequestImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize) {
    NSString *key = TGCustomEmojiCacheKey(entity, maximumPixelSize);
    NSString *path = [entity objectForKey:TGCustomEmojiLocalPathKey];
    NSNumber *identifier = [entity objectForKey:TGCustomEmojiIdentifierKey];
    if ([key length] == 0 || TGCustomEmojiCachedImageForEntity(entity, maximumPixelSize)) {
        return;
    }

    BOOL shouldStart = NO;
    @synchronized([NSImage class]) {
        NSUInteger maximumPending = TGResourcePolicyEconomyModeEnabled() ? 6 : 18;
        if (![TGCustomEmojiPendingKeys() containsObject:key] &&
            [TGCustomEmojiPendingKeys() count] < maximumPending) {
            [TGCustomEmojiPendingKeys() addObject:key];
            shouldStart = YES;
        }
    }
    if (!shouldStart) {
        return;
    }

    TGLoadImageThumbnailFromFileAsync(path, maximumPixelSize, ^(NSImage *image) {
        if (image) {
            NSSize imageSize = [image size];
            NSUInteger cost = (NSUInteger)MAX(1.0, imageSize.width * imageSize.height * 4.0);
            [TGCustomEmojiImageCache() setObject:image forKey:key cost:cost];
        }
        @synchronized([NSImage class]) {
            [TGCustomEmojiPendingKeys() removeObject:key];
        }
        if (image) {
            NSDictionary *userInfo = identifier
                ? [NSDictionary dictionaryWithObject:identifier forKey:TGCustomEmojiImageIdentifierUserInfoKey]
                : nil;
            [[NSNotificationCenter defaultCenter] postNotificationName:TGCustomEmojiImageDidLoadNotification
                                                                object:nil
                                                              userInfo:userInfo];
        }
    });
}

void TGCustomEmojiImageLoaderClearCache(void) {
    [TGCustomEmojiImageCache() removeAllObjects];
}
