#import "TGMessageThumbnailPrefetcher.h"
#import "TGMediaImageLoader.h"
#import "../Core/TGMessageItem.h"

static NSUInteger const TGMessageThumbnailMaximumPendingCount = 24;
static NSUInteger const TGMessageThumbnailMaximumFailedCount = 256;
static NSTimeInterval const TGMessageThumbnailFailureRetryInterval = 5.0;

@interface TGMessageThumbnailPrefetcher ()
@property (nonatomic, retain) NSMutableDictionary *tokensByKey;
@property (nonatomic, retain) NSMutableDictionary *failureDatesByKey;
@property (nonatomic, retain) NSMutableArray *failedKeyOrder;
@property (nonatomic, assign) NSUInteger generation;
@end

@implementation TGMessageThumbnailPrefetcher

@synthesize tokensByKey = _tokensByKey;
@synthesize failureDatesByKey = _failureDatesByKey;
@synthesize failedKeyOrder = _failedKeyOrder;
@synthesize generation = _generation;

- (id)init {
    self = [super init];
    if (self) {
        self.tokensByKey = [NSMutableDictionary dictionary];
        self.failureDatesByKey = [NSMutableDictionary dictionary];
        self.failedKeyOrder = [NSMutableArray array];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mediaImageCacheDidClear:)
                                                     name:TGMediaImageLoaderCacheDidClearNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self cancelAll];
    [_tokensByKey release];
    [_failureDatesByKey release];
    [_failedKeyOrder release];
    [super dealloc];
}

- (void)mediaImageCacheDidClear:(NSNotification *)notification {
    (void)notification;
    [self cancelAll];
}

- (NSString *)keyForPath:(NSString *)path maximumPixelSize:(NSUInteger)maximumPixelSize {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0 || maximumPixelSize == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lu:%@",
            (unsigned long)maximumPixelSize,
            [path stringByStandardizingPath]];
}

- (void)rememberFailedKey:(NSString *)key {
    if ([key length] == 0) {
        return;
    }
    [self.failureDatesByKey setObject:[NSDate date] forKey:key];
    [self.failedKeyOrder removeObject:key];
    [self.failedKeyOrder addObject:key];
    while ([self.failedKeyOrder count] > TGMessageThumbnailMaximumFailedCount) {
        NSString *oldestKey = [self.failedKeyOrder objectAtIndex:0];
        [self.failureDatesByKey removeObjectForKey:oldestKey];
        [self.failedKeyOrder removeObjectAtIndex:0];
    }
}

- (void)prefetchPath:(NSString *)path
    maximumPixelSize:(NSUInteger)maximumPixelSize
          completion:(TGMessageThumbnailPrefetchCompletion)completion {
    NSString *key = [self keyForPath:path maximumPixelSize:maximumPixelSize];
    if ([key length] == 0 || [self.tokensByKey objectForKey:key] != nil ||
        [self.tokensByKey count] >= TGMessageThumbnailMaximumPendingCount) {
        return;
    }

    // NSCache may evict images at any time. A successful decode is not proof
    // that its thumbnail is still cached (or that the source is unchanged).
    if (TGMediaCachedThumbnailFromFile(path, maximumPixelSize)) {
        return;
    }
    NSDate *failureDate = [self.failureDatesByKey objectForKey:key];
    if (failureDate && -[failureDate timeIntervalSinceNow] < TGMessageThumbnailFailureRetryInterval) {
        return;
    }

    NSUInteger generation = self.generation;
    TGMessageThumbnailPrefetcher *prefetcher = self;
    TGMediaImageLoadToken *token = TGLoadImageThumbnailFromFileAsync(path,
                                                                     maximumPixelSize,
                                                                     ^(NSImage *image) {
        if (generation != prefetcher.generation) {
            return;
        }
        [prefetcher.tokensByKey removeObjectForKey:key];
        if (image) {
            [prefetcher.failureDatesByKey removeObjectForKey:key];
            [prefetcher.failedKeyOrder removeObject:key];
        } else {
            // Corrupt or not-yet-present files must not decode on every redraw.
            [prefetcher rememberFailedKey:key];
        }
        if (image && completion) {
            completion();
        }
    });
    if (token) {
        [self.tokensByKey setObject:token forKey:key];
    }
}

- (void)prefetchMessageItem:(TGMessageItem *)item
                 completion:(TGMessageThumbnailPrefetchCompletion)completion {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }

    [self prefetchPath:[item senderAvatarLocalPath]
      maximumPixelSize:128
            completion:completion];

    NSArray *mediaItems = [item visualMediaItems];
    for (NSDictionary *mediaItem in mediaItems) {
        id localPath = [mediaItem objectForKey:@"local_path"];
        [self prefetchPath:[localPath isKindOfClass:[NSString class]] ? localPath : nil
          maximumPixelSize:768
                completion:completion];
    }

    NSDictionary *linkPreviewMedia = [[item linkPreviewInfo] objectForKey:@"media"];
    [self prefetchPath:[linkPreviewMedia objectForKey:@"local_path"]
      maximumPixelSize:768
            completion:completion];
}

- (void)cancelAll {
    self.generation = self.generation + 1;
    for (TGMediaImageLoadToken *token in [self.tokensByKey allValues]) {
        [token cancel];
    }
    [self.tokensByKey removeAllObjects];
    [self.failureDatesByKey removeAllObjects];
    [self.failedKeyOrder removeAllObjects];
}

@end
