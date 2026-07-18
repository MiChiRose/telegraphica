#import "TGMediaImageLoader.h"
#import "TGWebPDecoder.h"
#import <ImageIO/ImageIO.h>

static NSCache *TGMediaImageCache(void) {
    static NSCache *cache = nil;
    @synchronized([NSImage class]) {
        if (!cache) {
            cache = [[NSCache alloc] init];
            [cache setCountLimit:160];
            [cache setTotalCostLimit:(64 * 1024 * 1024)];
        }
    }
    return cache;
}

static NSImage *TGMediaCachedImage(NSString *path) {
    NSImage *image = [TGMediaImageCache() objectForKey:path];
    return [[image retain] autorelease];
}

static NSImage *TGMediaCacheImage(NSImage *image, NSString *path) {
    if (image && [path length] > 0) {
        NSSize imageSize = [image size];
        NSUInteger cost = 1;
        if (imageSize.width > 0.0 && imageSize.height > 0.0) {
            cost = (NSUInteger)MAX(1.0, imageSize.width * imageSize.height * 4.0);
        }
        [TGMediaImageCache() setObject:image forKey:path cost:cost];
    }
    return image;
}

void TGMediaImageLoaderSetCacheLimitBytes(NSUInteger bytes) {
    NSCache *cache = TGMediaImageCache();
    NSUInteger limit = bytes > 0 ? bytes : (64 * 1024 * 1024);
    [cache setTotalCostLimit:limit];
    [cache setCountLimit:(limit < (128 * 1024 * 1024)) ? 80 : 160];
}

void TGMediaImageLoaderClearCache(void) {
    [TGMediaImageCache() removeAllObjects];
}

NSImage *TGImageWithCorrectOrientationFromFile(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return nil;
    }

    NSString *resolvedPath = [path stringByStandardizingPath];
    if (![resolvedPath length]) {
        return nil;
    }
    NSImage *cachedImage = TGMediaCachedImage(resolvedPath);
    if (cachedImage) {
        return cachedImage;
    }

    CGImageSourceRef source = nil;
    CGImageRef imageRef = nil;
    NSDictionary *properties = nil;
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)resolvedPath,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
    if (fileURL) {
        source = CGImageSourceCreateWithURL(fileURL, NULL);
        CFRelease(fileURL);
    }
    if (!source) {
        return TGMediaCacheImage(TGWebPImageFromFile(resolvedPath), resolvedPath);
    }

    properties = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSUInteger sourceWidth = 0;
    NSUInteger sourceHeight = 0;
    if ([properties isKindOfClass:[NSDictionary class]]) {
        id widthObject = [properties objectForKey:(NSString *)kCGImagePropertyPixelWidth];
        id heightObject = [properties objectForKey:(NSString *)kCGImagePropertyPixelHeight];
        if ([widthObject respondsToSelector:@selector(unsignedIntegerValue)]) {
            sourceWidth = [widthObject unsignedIntegerValue];
        }
        if ([heightObject respondsToSelector:@selector(unsignedIntegerValue)]) {
            sourceHeight = [heightObject unsignedIntegerValue];
        }
    }

    NSUInteger maxSourceSide = MAX(sourceWidth, sourceHeight);
    NSUInteger decodeMaxSide = 2200;
    if (maxSourceSide > decodeMaxSide) {
        NSDictionary *thumbnailOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                          (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailFromImageAlways,
                                          (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailWithTransform,
                                          (id)kCFBooleanFalse, kCGImageSourceShouldCacheImmediately,
                                          [NSNumber numberWithUnsignedInteger:decodeMaxSide], kCGImageSourceThumbnailMaxPixelSize,
                                          nil];
        imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)thumbnailOptions);
    } else {
        NSDictionary *imageOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                      (id)kCFBooleanFalse, kCGImageSourceShouldCacheImmediately,
                                      nil];
        imageRef = CGImageSourceCreateImageAtIndex(source, 0, (CFDictionaryRef)imageOptions);
    }
    if (!imageRef) {
        if (properties) {
            CFRelease(properties);
        }
        CFRelease(source);
        return TGMediaCacheImage(TGWebPImageFromFile(resolvedPath), resolvedPath);
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

    if (orientation > 1 && maxSourceSide <= decodeMaxSide) {
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

    NSSize size = NSMakeSize((CGFloat)CGImageGetWidth(imageRef), (CGFloat)CGImageGetHeight(imageRef));
    NSImage *image = [[[NSImage alloc] initWithCGImage:imageRef size:size] autorelease];
    CGImageRelease(imageRef);
    CFRelease(source);
    return TGMediaCacheImage(image, resolvedPath);
}
