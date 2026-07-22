#import "TGWebPDecoder.h"
#import "TGMediaSecurityLimits.h"
#import "webp/decode.h"
#include <string.h>

BOOL TGDataHasWebPHeader(NSData *data) {
    if (![data isKindOfClass:[NSData class]] || [data length] < 12) {
        return NO;
    }
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    return memcmp(bytes, "RIFF", 4) == 0 && memcmp(bytes + 8, "WEBP", 4) == 0;
}

NSImage *TGWebPImageFromData(NSData *data) {
    if (!TGDataHasWebPHeader(data)) {
        return nil;
    }

    int width = 0;
    int height = 0;
    const uint8_t *bytes = (const uint8_t *)[data bytes];
    size_t length = (size_t)[data length];
    if (!WebPGetInfo(bytes, length, &width, &height) || width <= 0 || height <= 0) {
        return nil;
    }
    if (!TGMediaDimensionsFitDecodedBudget((NSUInteger)width,
                                           (NSUInteger)height,
                                           4,
                                           TGMediaMaximumDecodedBytes)) {
        return nil;
    }

    int decodedWidth = 0;
    int decodedHeight = 0;
    uint8_t *decoded = WebPDecodeRGBA(bytes, length, &decodedWidth, &decodedHeight);
    if (!decoded || decodedWidth != width || decodedHeight != height) {
        WebPFree(decoded);
        return nil;
    }

    NSBitmapImageRep *representation = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:width
                      pixelsHigh:height
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                      bytesPerRow:0
                     bitsPerPixel:0] autorelease];
    if (!representation || ![representation bitmapData]) {
        WebPFree(decoded);
        return nil;
    }

    NSUInteger sourceRowBytes = (NSUInteger)width * 4;
    NSUInteger destinationRowBytes = (NSUInteger)[representation bytesPerRow];
    unsigned char *destination = [representation bitmapData];
    NSUInteger row = 0;
    for (row = 0; row < (NSUInteger)height; row++) {
        memcpy(destination + row * destinationRowBytes,
               decoded + row * sourceRowBytes,
               sourceRowBytes);
    }
    WebPFree(decoded);

    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
    [image addRepresentation:representation];
    return image;
}

NSImage *TGWebPImageFromFile(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:[path stringByStandardizingPath]];
    return TGWebPImageFromData(data);
}
