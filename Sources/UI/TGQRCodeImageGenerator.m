#import "TGQRCodeImageGenerator.h"

#include "../../Vendor/qrcodegen/qrcodegen.h"
#include <math.h>
#include <stdlib.h>

@implementation TGQRCodeImageGenerator

+ (NSImage *)imageForString:(NSString *)string maximumSide:(CGFloat)maximumSide {
    if (![string isKindOfClass:[NSString class]] || [string length] == 0) {
        return nil;
    }

    const char *text = [string UTF8String];
    if (!text) {
        return nil;
    }

    uint8_t *temporaryBuffer = (uint8_t *)calloc(qrcodegen_BUFFER_LEN_MAX, sizeof(uint8_t));
    uint8_t *qrBuffer = (uint8_t *)calloc(qrcodegen_BUFFER_LEN_MAX, sizeof(uint8_t));
    if (!temporaryBuffer || !qrBuffer) {
        free(temporaryBuffer);
        free(qrBuffer);
        return nil;
    }

    BOOL encoded = qrcodegen_encodeText(text,
                                        temporaryBuffer,
                                        qrBuffer,
                                        qrcodegen_Ecc_MEDIUM,
                                        qrcodegen_VERSION_MIN,
                                        qrcodegen_VERSION_MAX,
                                        qrcodegen_Mask_AUTO,
                                        YES);
    free(temporaryBuffer);
    if (!encoded) {
        free(qrBuffer);
        return nil;
    }

    int qrSize = qrcodegen_getSize(qrBuffer);
    int quietZone = 4;
    int moduleCount = qrSize + (quietZone * 2);
    NSInteger pixelScale = (NSInteger)floor(maximumSide / (CGFloat)moduleCount);
    if (pixelScale < 2) {
        pixelScale = 2;
    }
    NSInteger pixelSide = moduleCount * pixelScale;
    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:pixelSide
                      pixelsHigh:pixelSide
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:(pixelSide * 4)
                    bitsPerPixel:32] autorelease];
    if (!bitmap) {
        free(qrBuffer);
        return nil;
    }

    unsigned char *pixels = [bitmap bitmapData];
    NSInteger y = 0;
    for (y = 0; y < pixelSide; y++) {
        NSInteger moduleY = (y / pixelScale) - quietZone;
        NSInteger x = 0;
        for (x = 0; x < pixelSide; x++) {
            NSInteger moduleX = (x / pixelScale) - quietZone;
            BOOL dark = (moduleX >= 0 && moduleY >= 0 &&
                         moduleX < qrSize && moduleY < qrSize &&
                         qrcodegen_getModule(qrBuffer, (int)moduleX, (int)moduleY));
            unsigned char component = dark ? 0 : 255;
            NSUInteger offset = (NSUInteger)((y * pixelSide + x) * 4);
            pixels[offset + 0] = component;
            pixels[offset + 1] = component;
            pixels[offset + 2] = component;
            pixels[offset + 3] = 255;
        }
    }
    free(qrBuffer);

    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(pixelSide, pixelSide)] autorelease];
    [image addRepresentation:bitmap];
    return image;
}

@end
