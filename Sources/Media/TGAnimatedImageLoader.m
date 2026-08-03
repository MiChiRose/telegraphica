#import "TGAnimatedImageLoader.h"
#import "TGMediaSecurityLimits.h"
#import <ImageIO/ImageIO.h>

@interface TGAnimatedImageLoadToken ()
@property (nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, copy) TGAnimatedImageLoadCompletion completion;
- (id)initWithCompletion:(TGAnimatedImageLoadCompletion)completion;
- (void)finishWithImage:(NSImage *)image failureReason:(NSString *)failureReason;
@end

@implementation TGAnimatedImageLoadToken

@synthesize cancelled = _cancelled;
@synthesize completion = _completion;

- (id)initWithCompletion:(TGAnimatedImageLoadCompletion)completion {
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

- (void)finishWithImage:(NSImage *)image failureReason:(NSString *)failureReason {
    TGAnimatedImageLoadCompletion completion = nil;
    @synchronized(self) {
        if (!_cancelled && _completion) {
            completion = [_completion copy];
        }
        self.completion = nil;
    }
    if (completion) {
        completion(image, failureReason);
        [completion release];
    }
}

@end

static NSCache *TGAnimatedImageCache(void) {
    static NSCache *cache = nil;
    @synchronized([NSImage class]) {
        if (!cache) {
            cache = [[NSCache alloc] init];
            [cache setCountLimit:16];
            [cache setTotalCostLimit:(48 * 1024 * 1024)];
        }
    }
    return cache;
}

static dispatch_queue_t TGAnimatedImageDecodeQueue(void) {
    static dispatch_queue_t queue = NULL;
    @synchronized([NSImage class]) {
        if (!queue) {
            queue = dispatch_queue_create("org.telegraphica.animated-image-decode", DISPATCH_QUEUE_SERIAL);
        }
    }
    return queue;
}

static NSString *TGAnimatedImageCacheKey(NSString *path) {
    NSString *resolvedPath = [path stringByStandardizingPath];
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:resolvedPath error:NULL];
    NSNumber *fileSize = [attributes objectForKey:NSFileSize];
    NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
    NSNumber *fileNumber = [attributes objectForKey:NSFileSystemFileNumber];
    return [NSString stringWithFormat:@"animated:%@:%@:%@:%0.6f",
            resolvedPath,
            (fileNumber ?: @0),
            (fileSize ?: @0),
            ([modificationDate isKindOfClass:[NSDate class]] ? [modificationDate timeIntervalSince1970] : 0.0)];
}

static BOOL TGAnimatedImageInspectBudget(NSString *path,
                                         NSUInteger *decodedCost,
                                         NSString **failureReason) {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
    if (!source) {
        if (failureReason) {
            *failureReason = @"GIF image could not be opened.";
        }
        return NO;
    }

    size_t frameCount = CGImageSourceGetCount(source);
    if (frameCount == 0 || frameCount > TGMediaMaximumAnimatedFrameCount) {
        CFRelease(source);
        if (failureReason) {
            *failureReason = @"GIF exceeds the safe animation frame limit.";
        }
        return NO;
    }

    unsigned long long totalBytes = 0;
    size_t index = 0;
    for (index = 0; index < frameCount; index++) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, index, NULL);
        NSNumber *widthNumber = properties ? [(NSDictionary *)properties objectForKey:(NSString *)kCGImagePropertyPixelWidth] : nil;
        NSNumber *heightNumber = properties ? [(NSDictionary *)properties objectForKey:(NSString *)kCGImagePropertyPixelHeight] : nil;
        NSUInteger width = [widthNumber respondsToSelector:@selector(unsignedIntegerValue)] ? [widthNumber unsignedIntegerValue] : 0;
        NSUInteger height = [heightNumber respondsToSelector:@selector(unsignedIntegerValue)] ? [heightNumber unsignedIntegerValue] : 0;
        if (properties) {
            CFRelease(properties);
        }
        if (!TGMediaDimensionsFitDecodedBudget(width, height, 4, TGMediaMaximumDecodedBytes)) {
            CFRelease(source);
            if (failureReason) {
                *failureReason = @"GIF frame exceeds the safe decoded image budget.";
            }
            return NO;
        }
        unsigned long long frameBytes = (unsigned long long)width * (unsigned long long)height * 4ULL;
        if (frameBytes > TGMediaMaximumDecodedBytes - totalBytes) {
            CFRelease(source);
            if (failureReason) {
                *failureReason = @"GIF exceeds the safe decoded animation budget.";
            }
            return NO;
        }
        totalBytes += frameBytes;
    }
    CFRelease(source);
    if (decodedCost) {
        *decodedCost = (NSUInteger)MAX(1ULL, totalBytes);
    }
    return YES;
}

TGAnimatedImageLoadToken *TGLoadAnimatedImageFromFileAsync(NSString *path,
                                                            TGAnimatedImageLoadCompletion completion) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0 || !completion) {
        return nil;
    }

    TGAnimatedImageLoadToken *token = [[[TGAnimatedImageLoadToken alloc] initWithCompletion:completion] autorelease];
    NSString *pathCopy = [[path stringByStandardizingPath] copy];
    NSString *cacheKey = [TGAnimatedImageCacheKey(pathCopy) copy];
    NSImage *cachedImage = [TGAnimatedImageCache() objectForKey:cacheKey];
    if (cachedImage) {
        NSImage *retainedImage = [cachedImage retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            [token finishWithImage:retainedImage failureReason:nil];
            [retainedImage release];
        });
        [cacheKey release];
        [pathCopy release];
        return token;
    }

    dispatch_async(TGAnimatedImageDecodeQueue(), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSImage *image = nil;
        NSString *failureReason = nil;
        NSUInteger decodedCost = 1;
        if (![token isCancelled] && TGAnimatedImageInspectBudget(pathCopy, &decodedCost, &failureReason)) {
            image = [[NSImage alloc] initWithContentsOfFile:pathCopy];
            if (image) {
                [TGAnimatedImageCache() setObject:image forKey:cacheKey cost:decodedCost];
            } else {
                failureReason = @"GIF image could not be decoded.";
            }
        }
        NSImage *resultImage = [image retain];
        NSString *resultFailureReason = [failureReason copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [token finishWithImage:resultImage failureReason:resultFailureReason];
            [resultImage release];
            [resultFailureReason release];
        });
        [image release];
        [pool drain];
    });
    [cacheKey release];
    [pathCopy release];
    return token;
}

void TGAnimatedImageLoaderClearCache(void) {
    [TGAnimatedImageCache() removeAllObjects];
}
