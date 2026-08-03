#import "TGMessageThumbnailPrefetcher.h"
#import "TGMediaImageLoader.h"
#import "../Core/TGMessageItem.h"

static NSUInteger const TGMessageThumbnailMaximumPendingCount = 24;
static NSUInteger const TGMessageThumbnailMaximumCompletedCount = 256;

@interface TGMessageThumbnailPrefetcher ()
@property (nonatomic, retain) NSMutableDictionary *tokensByKey;
@property (nonatomic, retain) NSMutableSet *completedKeys;
@property (nonatomic, retain) NSMutableArray *completedKeyOrder;
@property (nonatomic, assign) NSUInteger generation;
@end

@implementation TGMessageThumbnailPrefetcher

@synthesize tokensByKey = _tokensByKey;
@synthesize completedKeys = _completedKeys;
@synthesize completedKeyOrder = _completedKeyOrder;
@synthesize generation = _generation;

- (id)init {
    self = [super init];
    if (self) {
        self.tokensByKey = [NSMutableDictionary dictionary];
        self.completedKeys = [NSMutableSet set];
        self.completedKeyOrder = [NSMutableArray array];
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
    [_completedKeys release];
    [_completedKeyOrder release];
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

- (void)rememberCompletedKey:(NSString *)key {
    if ([key length] == 0 || [self.completedKeys containsObject:key]) {
        return;
    }
    [self.completedKeys addObject:key];
    [self.completedKeyOrder addObject:key];
    while ([self.completedKeyOrder count] > TGMessageThumbnailMaximumCompletedCount) {
        NSString *oldestKey = [self.completedKeyOrder objectAtIndex:0];
        [self.completedKeys removeObject:oldestKey];
        [self.completedKeyOrder removeObjectAtIndex:0];
    }
}

- (void)prefetchPath:(NSString *)path
    maximumPixelSize:(NSUInteger)maximumPixelSize
          completion:(TGMessageThumbnailPrefetchCompletion)completion {
    NSString *key = [self keyForPath:path maximumPixelSize:maximumPixelSize];
    if ([key length] == 0 || [self.completedKeys containsObject:key] ||
        [self.tokensByKey objectForKey:key] != nil ||
        [self.tokensByKey count] >= TGMessageThumbnailMaximumPendingCount) {
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
        [prefetcher rememberCompletedKey:key];
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
    [self.completedKeys removeAllObjects];
    [self.completedKeyOrder removeAllObjects];
}

@end
