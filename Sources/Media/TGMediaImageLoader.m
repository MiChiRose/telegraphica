#import "TGMediaImageLoader.h"
#import "TGWebPDecoder.h"
#import <ImageIO/ImageIO.h>

@interface TGMediaImageLoadToken ()
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy) TGMediaImageLoadCompletion completion;
- (id)initWithCompletion:(TGMediaImageLoadCompletion)completion;
- (void)finishWithImage:(NSImage *)image;
@end

@implementation TGMediaImageLoadToken

@synthesize cancelled = _cancelled;
@synthesize completion = _completion;

- (id)initWithCompletion:(TGMediaImageLoadCompletion)completion {
    self = [super init];
    if (self) {
        self.completion = completion;
    }
    return self;
}

- (void)dealloc {
    [_completion release];
    [super dealloc];
}

- (void)cancel {
    @synchronized(self) {
        _cancelled = YES;
        self.completion = nil;
    }
}

- (BOOL)isCancelled {
    @synchronized(self) {
        return _cancelled;
    }
}

- (void)finishWithImage:(NSImage *)image {
    TGMediaImageLoadCompletion completion = nil;
    @synchronized(self) {
        if (!_cancelled && _completion) {
            completion = [_completion copy];
        }
        self.completion = nil;
    }
    if (completion) {
        completion(image);
        [completion release];
    }
}

@end

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

static NSString *TGMediaFileCacheKey(NSString *path,
                                     NSString *kind,
                                     NSUInteger maximumPixelSize) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return nil;
    }
    NSString *resolvedPath = [path stringByStandardizingPath];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:resolvedPath error:NULL];
    NSNumber *fileSize = [attributes objectForKey:NSFileSize];
    NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
    NSNumber *fileNumber = [attributes objectForKey:NSFileSystemFileNumber];
    return [NSString stringWithFormat:@"%@:%lu:%@:%@:%@:%0.6f",
            ([kind length] > 0 ? kind : @"file"),
            (unsigned long)maximumPixelSize,
            resolvedPath,
            (fileNumber ?: @0),
            (fileSize ?: @0),
            ([modificationDate isKindOfClass:[NSDate class]] ? [modificationDate timeIntervalSince1970] : 0.0)];
}

static NSImage *TGMediaCachedImage(NSString *cacheKey) {
    if ([cacheKey length] == 0) {
        return nil;
    }
    NSImage *image = [TGMediaImageCache() objectForKey:cacheKey];
    return [[image retain] autorelease];
}

static NSImage *TGMediaCacheImage(NSImage *image, NSString *cacheKey) {
    if (image && [cacheKey length] > 0) {
        NSSize imageSize = [image size];
        NSUInteger cost = 1;
        if (imageSize.width > 0.0 && imageSize.height > 0.0) {
            cost = (NSUInteger)MAX(1.0, imageSize.width * imageSize.height * 4.0);
        }
        [TGMediaImageCache() setObject:image forKey:cacheKey cost:cost];
    }
    return image;
}

static NSImage *TGMediaThumbnailFromImageSource(CGImageSourceRef source,
                                                 NSUInteger maximumPixelSize) {
    if (!source || maximumPixelSize == 0) {
        return nil;
    }

    NSDictionary *thumbnailOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                      (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailFromImageAlways,
                                      (id)kCFBooleanTrue, kCGImageSourceCreateThumbnailWithTransform,
                                      (id)kCFBooleanFalse, kCGImageSourceShouldCacheImmediately,
                                      [NSNumber numberWithUnsignedInteger:maximumPixelSize], kCGImageSourceThumbnailMaxPixelSize,
                                      nil];
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source,
                                                              0,
                                                              (CFDictionaryRef)thumbnailOptions);
    if (!imageRef) {
        return nil;
    }

    NSSize size = NSMakeSize((CGFloat)CGImageGetWidth(imageRef),
                             (CGFloat)CGImageGetHeight(imageRef));
    NSImage *image = [[[NSImage alloc] initWithCGImage:imageRef size:size] autorelease];
    CGImageRelease(imageRef);
    return image;
}

NSImage *TGImageThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0 || maximumPixelSize == 0) {
        return nil;
    }

    NSString *resolvedPath = [path stringByStandardizingPath];
    if ([resolvedPath length] == 0) {
        return nil;
    }
    NSString *cacheKey = TGMediaFileCacheKey(resolvedPath, @"file-thumbnail", maximumPixelSize);
    NSImage *cachedImage = TGMediaCachedImage(cacheKey);
    if (cachedImage) {
        return cachedImage;
    }

    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     (CFStringRef)resolvedPath,
                                                     kCFURLPOSIXPathStyle,
                                                     false);
    CGImageSourceRef source = fileURL ? CGImageSourceCreateWithURL(fileURL, NULL) : nil;
    if (fileURL) {
        CFRelease(fileURL);
    }
    if (!source) {
        return TGMediaCacheImage(TGWebPImageFromFile(resolvedPath), cacheKey);
    }

    NSImage *image = TGMediaThumbnailFromImageSource(source, maximumPixelSize);
    CFRelease(source);
    if (!image) {
        image = TGWebPImageFromFile(resolvedPath);
    }
    return TGMediaCacheImage(image, cacheKey);
}

NSImage *TGMediaCachedThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize) {
    if (maximumPixelSize == 0) {
        return nil;
    }
    return TGMediaCachedImage(TGMediaFileCacheKey(path, @"file-thumbnail", maximumPixelSize));
}

TGMediaImageLoadToken *TGLoadImageThumbnailFromFileAsync(NSString *path,
                                                         NSUInteger maximumPixelSize,
                                                         TGMediaImageLoadCompletion completion) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0 ||
        maximumPixelSize == 0 || !completion) {
        return nil;
    }

    TGMediaImageLoadToken *token = [[[TGMediaImageLoadToken alloc] initWithCompletion:completion] autorelease];
    NSString *pathCopy = [path copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSImage *image = nil;
        if (![token isCancelled]) {
            image = [TGImageThumbnailFromFile(pathCopy, maximumPixelSize) retain];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [token finishWithImage:image];
        });
        [image release];
        [pool drain];
    });
    [pathCopy release];
    return token;
}

NSImage *TGImageThumbnailFromData(NSData *data, NSUInteger maximumPixelSize) {
    if (![data isKindOfClass:[NSData class]] || [data length] == 0 || maximumPixelSize == 0) {
        return nil;
    }

    NSString *cacheKey = [NSString stringWithFormat:@"data-thumbnail:%lu:%lu:%lu",
                          (unsigned long)maximumPixelSize,
                          (unsigned long)[data length],
                          (unsigned long)[data hash]];
    NSImage *cachedImage = TGMediaCachedImage(cacheKey);
    if (cachedImage) {
        return cachedImage;
    }

    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
    NSImage *image = nil;
    if (source) {
        image = TGMediaThumbnailFromImageSource(source, maximumPixelSize);
        CFRelease(source);
    }
    if (!image) {
        image = [[[NSImage alloc] initWithData:data] autorelease];
    }
    return TGMediaCacheImage(image, cacheKey);
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
    NSString *cacheKey = TGMediaFileCacheKey(resolvedPath, @"file-oriented", 2200);
    NSImage *cachedImage = TGMediaCachedImage(cacheKey);
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
        return TGMediaCacheImage(TGWebPImageFromFile(resolvedPath), cacheKey);
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
        return TGMediaCacheImage(TGWebPImageFromFile(resolvedPath), cacheKey);
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
    return TGMediaCacheImage(image, cacheKey);
}
