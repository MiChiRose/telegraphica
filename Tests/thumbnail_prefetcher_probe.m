#import <Cocoa/Cocoa.h>
#import "TGMessageThumbnailPrefetcher.h"
#import "TGMediaImageLoader.h"
#include <stdio.h>

// A controllable loader models eviction without depending on NSCache's
// nondeterministic eviction policy or performing disk IO in this probe.
NSString * const TGMediaImageLoaderCacheDidClearNotification = @"TGMediaImageLoaderCacheDidClearNotification";
static NSMutableDictionary *images;
static NSUInteger loads = 0;
static NSUInteger finishedLoads = 0;
static BOOL decodeFails = NO;

@implementation TGMediaImageLoadToken
- (void)cancel {}
- (BOOL)isCancelled { return NO; }
@end

static NSString *TGProbeKey(NSString *path, NSUInteger size) {
    return [NSString stringWithFormat:@"%lu:%@", (unsigned long)size, [path stringByStandardizingPath]];
}

NSImage *TGMediaCachedThumbnailFromFile(NSString *path, NSUInteger size) {
    return [images objectForKey:TGProbeKey(path, size)];
}

TGMediaImageLoadToken *TGLoadImageThumbnailFromFileAsync(NSString *path, NSUInteger size,
                                                        TGMediaImageLoadCompletion completion) {
    loads++;
    BOOL fail = decodeFails;
    NSString *key = TGProbeKey(path, size);
    TGMediaImageLoadToken *token = [[[TGMediaImageLoadToken alloc] init] autorelease];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSImage *image = fail ? nil : [[[NSImage alloc] initWithSize:NSMakeSize(16, 16)] autorelease];
        if (image) [images setObject:image forKey:key];
        // Deliberately allow a late completion after cancel: the prefetcher's
        // generation must prevent a stale consumer callback independently.
        completion(image);
        finishedLoads++;
    });
    return token;
}

static BOOL TGWaitForLoads(NSUInteger expected) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
    while (finishedLoads < expected && [deadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return finishedLoads == expected;
}

#define REQUIRE(condition, description) do { if (!(condition)) { fprintf(stderr, "%s\n", description); return 1; } } while (0)

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    images = [[NSMutableDictionary alloc] init];
    TGMessageThumbnailPrefetcher *prefetcher = [[[TGMessageThumbnailPrefetcher alloc] init] autorelease];
    __block NSUInteger callbacks = 0;
    void (^completion)(void) = ^{ callbacks++; };
    NSString *path = @"/tmp/telegraphica-probe-thumbnail.png";
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 1 && TGWaitForLoads(1) && callbacks == 1, "pending decode was not deduplicated");
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 1, "cached thumbnail decoded again");

    // Ordinary NSCache eviction does not post the explicit clear notification.
    [images removeAllObjects];
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 2 && TGWaitForLoads(2) && callbacks == 2, "evicted thumbnail did not reload");
    // A changed file causes the real loader's versioned cache lookup to miss.
    [images removeAllObjects];
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 3 && TGWaitForLoads(3) && callbacks == 3, "changed source did not reload");

    [images removeAllObjects];
    decodeFails = YES;
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 4 && TGWaitForLoads(4) && callbacks == 3, "failed decode called successful consumer");
    NSUInteger index = 0;
    for (index = 0; index < 100; index++) {
        [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    }
    REQUIRE(loads == 4, "corrupt thumbnail retried on every redraw");
    NSMutableDictionary *failureDates = [prefetcher valueForKey:@"failureDatesByKey"];
    REQUIRE([failureDates count] == 1, "failed thumbnail was not recorded");
    [failureDates setObject:[NSDate dateWithTimeIntervalSinceNow:-6.0] forKey:TGProbeKey(path, 128)];
    decodeFails = NO;
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    REQUIRE(loads == 5 && TGWaitForLoads(5) && callbacks == 4, "failed thumbnail did not recover after retry interval");
    REQUIRE([failureDates count] == 0, "successful retry retained negative cache");

    [images removeAllObjects];
    [prefetcher prefetchPath:path maximumPixelSize:128 completion:completion];
    [prefetcher cancelAll];
    REQUIRE(TGWaitForLoads(6) && callbacks == 4, "cancelled generation delivered a stale callback");
    REQUIRE([[prefetcher valueForKey:@"tokensByKey"] count] == 0, "cancel left pending tokens");

    [images removeAllObjects];
    decodeFails = YES;
    for (index = 0; index < 260; index++) {
        NSString *failedPath = [NSString stringWithFormat:@"/tmp/telegraphica-probe-failed-%lu.png", (unsigned long)index];
        [prefetcher prefetchPath:failedPath maximumPixelSize:128 completion:completion];
        REQUIRE(TGWaitForLoads(loads), "failed cache fixture did not finish");
    }
    REQUIRE([failureDates count] == 256, "negative cache grew beyond its bounded limit");
    [prefetcher cancelAll];
    REQUIRE([failureDates count] == 0, "cancel did not clear negative cache");
    [images release];
    [pool drain];
    puts("Thumbnail prefetcher probe passed.");
    return 0;
}
