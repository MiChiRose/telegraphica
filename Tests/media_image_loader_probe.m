#import <Cocoa/Cocoa.h>
#import "TGMediaImageLoader.h"
#import "TGMessageThumbnailPrefetcher.h"
#import "TGMessageItem.h"
#import "TGWebPDecoder.h"
#include <stdio.h>
#include <math.h>

BOOL TGDataHasWebPHeader(NSData *data) {
    (void)data;
    return NO;
}

NSImage *TGWebPImageFromData(NSData *data) {
    (void)data;
    return nil;
}

NSImage *TGWebPImageFromFile(NSString *path) {
    (void)path;
    return nil;
}

static BOOL TGWritePNG(NSString *path, NSInteger width, NSInteger height, NSColor *color) {
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:width
                      pixelsHigh:height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0] autorelease];
    if (!bitmap) {
        return NO;
    }
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [color setFill];
    NSRectFill(NSMakeRect(0, 0, width, height));
    [NSGraphicsContext restoreGraphicsState];
    NSData *data = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    return [data writeToFile:path atomically:YES];
}

static BOOL TGSizeMatches(NSImage *image, CGFloat width, CGFloat height) {
    NSSize size = [image size];
    return image && fabs(size.width - width) < 0.5 && fabs(size.height - height) < 0.5;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int result = 0;
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"telegraphica-image-loader-%u", arc4random()]];
    NSString *path = [directory stringByAppendingPathComponent:@"fixture.png"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    if (!TGWritePNG(path, 32, 16, [NSColor redColor])) {
        result = 2;
    }
    NSImage *thumbnail = (result == 0) ? TGImageThumbnailFromFile(path, 16) : nil;
    if (result == 0 && !TGSizeMatches(thumbnail, 16, 8)) {
        fprintf(stderr, "thumbnail downsample failed\n");
        result = 3;
    }
    if (result == 0 && !TGMediaCachedThumbnailFromFile(path, 16)) {
        fprintf(stderr, "thumbnail cache lookup failed\n");
        result = 4;
    }

    if (result == 0 && !TGWritePNG(path, 16, 32, [NSColor blueColor])) {
        result = 5;
    }
    if (result == 0 && TGMediaCachedThumbnailFromFile(path, 16)) {
        fprintf(stderr, "changed source reused a stale cache entry\n");
        result = 6;
    }

    __block BOOL completed = NO;
    __block BOOL callbackWasOnMainThread = NO;
    __block NSSize asyncSize = NSZeroSize;
    if (result == 0) {
        TGMediaImageLoadToken *token = TGLoadImageThumbnailFromFileAsync(path, 16, ^(NSImage *image) {
            completed = YES;
            callbackWasOnMainThread = [NSThread isMainThread];
            asyncSize = [image size];
        });
        if (!token) {
            result = 7;
        }
    }
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
    while (result == 0 && !completed && [deadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
    if (result == 0 && (!completed || !callbackWasOnMainThread ||
                        fabs(asyncSize.width - 8.0) >= 0.5 || fabs(asyncSize.height - 16.0) >= 0.5)) {
        fprintf(stderr, "async thumbnail completion failed\n");
        result = 8;
    }

    NSString *avatarPath = [directory stringByAppendingPathComponent:@"avatar.png"];
    NSString *mediaPath = [directory stringByAppendingPathComponent:@"media.png"];
    NSString *previewPath = [directory stringByAppendingPathComponent:@"preview.png"];
    if (result == 0 &&
        (!TGWritePNG(avatarPath, 24, 24, [NSColor greenColor]) ||
         !TGWritePNG(mediaPath, 80, 40, [NSColor orangeColor]) ||
         !TGWritePNG(previewPath, 40, 80, [NSColor purpleColor]))) {
        result = 9;
    }
    __block NSUInteger prefetchCompletionCount = 0;
    TGMessageThumbnailPrefetcher *prefetcher = nil;
    TGMessageItem *messageItem = nil;
    if (result == 0) {
        prefetcher = [[[TGMessageThumbnailPrefetcher alloc] init] autorelease];
        messageItem = [[[TGMessageItem alloc] initWithChatID:@1
                                                  messageID:@2
                                                       date:@3
                                                   outgoing:NO
                                                    preview:@"Photo"] autorelease];
        [messageItem setSenderAvatarLocalPath:avatarPath];
        [messageItem setContentType:@"messagePhoto"];
        [messageItem setMediaItems:[NSArray arrayWithObject:
                                    [NSDictionary dictionaryWithObject:mediaPath forKey:@"local_path"]]];
        [messageItem setLinkPreviewInfo:
                     [NSDictionary dictionaryWithObject:
                      [NSDictionary dictionaryWithObject:previewPath forKey:@"local_path"]
                                                 forKey:@"media"]];
        [prefetcher prefetchMessageItem:messageItem completion:^{
            prefetchCompletionCount += 1;
        }];
    }
    deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
    while (result == 0 && prefetchCompletionCount < 3 && [deadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
    if (result == 0 && (prefetchCompletionCount != 3 ||
                        !TGMediaCachedThumbnailFromFile(avatarPath, 128) ||
                        !TGMediaCachedThumbnailFromFile(mediaPath, 768) ||
                        !TGMediaCachedThumbnailFromFile(previewPath, 768))) {
        fprintf(stderr, "message thumbnail prefetch failed\n");
        result = 10;
    }
    if (result == 0) {
        [prefetcher prefetchMessageItem:messageItem completion:^{
            prefetchCompletionCount += 1;
        }];
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        if (prefetchCompletionCount != 3) {
            fprintf(stderr, "completed message thumbnails were scheduled twice\n");
            result = 11;
        }
    }

    if (result == 0) {
        TGMediaImageLoaderClearCache();
        [prefetcher prefetchPath:avatarPath maximumPixelSize:128 completion:^{
            prefetchCompletionCount += 1;
        }];
        deadline = [NSDate dateWithTimeIntervalSinceNow:3.0];
        while (prefetchCompletionCount < 4 && [deadline timeIntervalSinceNow] > 0.0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (prefetchCompletionCount != 4) {
            fprintf(stderr, "cache clear did not invalidate completed prefetch keys\n");
            result = 12;
        }
    }

    TGMediaImageLoaderClearCache();
    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    if (result == 0) {
        fprintf(stdout, "Media image loader probe passed.\n");
    }
    [pool drain];
    return result;
}
