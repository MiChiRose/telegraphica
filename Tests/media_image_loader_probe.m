#import <Cocoa/Cocoa.h>
#import "TGMediaImageLoader.h"
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

    TGMediaImageLoaderClearCache();
    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    if (result == 0) {
        fprintf(stdout, "Media image loader probe passed.\n");
    }
    [pool drain];
    return result;
}
