#import "TGMediaWorkbenchProcessor.h"

NSString * const TGMediaWorkbenchOutputJPEG = @"jpeg";
NSString * const TGMediaWorkbenchOutputPNG = @"png";
NSString * const TGMediaWorkbenchOutputTIFF = @"tiff";

static NSString * const TGMediaWorkbenchErrorDomain =
    @"com.michirose.telegraphica.workshop.mediaworkbench";

static NSError *TGMediaWorkbenchError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGMediaWorkbenchErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:(message ? message : @"Media processing failed.")
                                                                forKey:NSLocalizedDescriptionKey]];
}

static NSBitmapImageFileType TGMediaWorkbenchBitmapType(NSString *format) {
    if ([format isEqualToString:TGMediaWorkbenchOutputPNG]) return NSPNGFileType;
    if ([format isEqualToString:TGMediaWorkbenchOutputTIFF]) return NSTIFFFileType;
    return NSJPEGFileType;
}

@implementation TGMediaWorkbenchProcessor

+ (NSDictionary *)imageInformationAtPath:(NSString *)path error:(NSError **)error {
    if ([path length] == 0) {
        if (error) *error = TGMediaWorkbenchError(1, @"No source image was selected.");
        return nil;
    }
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    if (!image) {
        if (error) *error = TGMediaWorkbenchError(2, @"The selected file is not a readable image.");
        return nil;
    }
    NSRect proposedRect = NSMakeRect(0, 0, [image size].width, [image size].height);
    CGImageRef cgImage = [image CGImageForProposedRect:&proposedRect context:nil hints:nil];
    NSUInteger width = cgImage ? CGImageGetWidth(cgImage) : (NSUInteger)MAX(1.0, [image size].width);
    NSUInteger height = cgImage ? CGImageGetHeight(cgImage) : (NSUInteger)MAX(1.0, [image size].height);
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    unsigned long long fileSize = [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:width], @"width",
            [NSNumber numberWithUnsignedInteger:height], @"height",
            [NSNumber numberWithUnsignedLongLong:fileSize], @"file_size",
            [path lastPathComponent], @"file_name",
            nil];
}

+ (BOOL)processImageAtPath:(NSString *)sourcePath
                outputPath:(NSString *)outputPath
                    format:(NSString *)format
          maximumDimension:(NSUInteger)maximumDimension
                   quality:(CGFloat)quality
                     error:(NSError **)error {
    NSDictionary *information = [self imageInformationAtPath:sourcePath error:error];
    if (!information) return NO;
    if ([outputPath length] == 0) {
        if (error) *error = TGMediaWorkbenchError(3, @"No output path was selected.");
        return NO;
    }
    if (![format isEqualToString:TGMediaWorkbenchOutputJPEG] &&
        ![format isEqualToString:TGMediaWorkbenchOutputPNG] &&
        ![format isEqualToString:TGMediaWorkbenchOutputTIFF]) {
        if (error) *error = TGMediaWorkbenchError(4, @"Unsupported output format.");
        return NO;
    }

    NSImage *sourceImage = [[[NSImage alloc] initWithContentsOfFile:sourcePath] autorelease];
    NSUInteger sourceWidth = [[information objectForKey:@"width"] unsignedIntegerValue];
    NSUInteger sourceHeight = [[information objectForKey:@"height"] unsignedIntegerValue];
    CGFloat scale = 1.0;
    NSUInteger largest = MAX(sourceWidth, sourceHeight);
    if (maximumDimension > 0 && largest > maximumDimension) {
        scale = (CGFloat)maximumDimension / (CGFloat)largest;
    }
    NSUInteger outputWidth = MAX((NSUInteger)1, (NSUInteger)floor(sourceWidth * scale));
    NSUInteger outputHeight = MAX((NSUInteger)1, (NSUInteger)floor(sourceHeight * scale));

    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL
                      pixelsWide:(NSInteger)outputWidth
                      pixelsHigh:(NSInteger)outputHeight
                   bitsPerSample:8
                 samplesPerPixel:4
                        hasAlpha:YES
                        isPlanar:NO
                  colorSpaceName:NSCalibratedRGBColorSpace
                     bytesPerRow:0
                    bitsPerPixel:0] autorelease];
    if (!bitmap) {
        if (error) *error = TGMediaWorkbenchError(5, @"Could not allocate the output image.");
        return NO;
    }

    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [context setImageInterpolation:NSImageInterpolationHigh];
    [[NSColor clearColor] setFill];
    NSRectFill(NSMakeRect(0, 0, outputWidth, outputHeight));
    [sourceImage drawInRect:NSMakeRect(0, 0, outputWidth, outputHeight)
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0
             respectFlipped:YES
                      hints:nil];
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];

    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    if ([format isEqualToString:TGMediaWorkbenchOutputJPEG]) {
        CGFloat boundedQuality = MIN(1.0, MAX(0.05, quality));
        [properties setObject:[NSNumber numberWithDouble:boundedQuality]
                       forKey:NSImageCompressionFactor];
    }
    NSData *data = [bitmap representationUsingType:TGMediaWorkbenchBitmapType(format)
                                        properties:properties];
    if (![data length]) {
        if (error) *error = TGMediaWorkbenchError(6, @"Could not encode the output image.");
        return NO;
    }
    if (![data writeToFile:outputPath options:NSDataWritingAtomic error:error]) {
        return NO;
    }
    return YES;
}

@end
