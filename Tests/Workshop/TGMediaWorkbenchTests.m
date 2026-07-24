#import <Cocoa/Cocoa.h>
#import "../../WorkshopModules/MediaWorkbench/TGMediaWorkbenchProcessor.h"

static NSUInteger TGMediaTestsRun = 0;
static NSUInteger TGMediaTestsFailed = 0;

static void TGMediaAssert(BOOL condition, NSString *message) {
    TGMediaTestsRun++;
    if (!condition) {
        TGMediaTestsFailed++;
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    }
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *temporaryDirectory = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"telegraphica-media-test-%d", getpid()]];
    [[NSFileManager defaultManager] createDirectoryAtPath:temporaryDirectory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    NSString *sourcePath = [temporaryDirectory stringByAppendingPathComponent:@"source.png"];
    NSString *outputPath = [temporaryDirectory stringByAppendingPathComponent:@"output.jpg"];

    NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:64 pixelsHigh:32 bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
        bytesPerRow:0 bitsPerPixel:0] autorelease];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    [[NSColor colorWithCalibratedRed:0.2 green:0.6 blue:0.9 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0, 0, 64, 32));
    [context flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    NSData *sourceData = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    TGMediaAssert([sourceData writeToFile:sourcePath atomically:YES], @"Fixture image is written.");

    NSError *error = nil;
    NSDictionary *information = [TGMediaWorkbenchProcessor imageInformationAtPath:sourcePath error:&error];
    TGMediaAssert(information != nil && error == nil, @"Image information is readable.");
    TGMediaAssert([[information objectForKey:@"width"] unsignedIntegerValue] == 64 &&
                  [[information objectForKey:@"height"] unsignedIntegerValue] == 32,
                  @"Image information preserves pixel dimensions.");

    error = nil;
    BOOL processed = [TGMediaWorkbenchProcessor processImageAtPath:sourcePath
                                                        outputPath:outputPath
                                                            format:TGMediaWorkbenchOutputJPEG
                                                  maximumDimension:16
                                                           quality:0.75
                                                             error:&error];
    TGMediaAssert(processed && error == nil, @"Image converts to JPEG.");
    NSDictionary *outputInformation = [TGMediaWorkbenchProcessor imageInformationAtPath:outputPath error:&error];
    TGMediaAssert([[outputInformation objectForKey:@"width"] unsignedIntegerValue] == 16 &&
                  [[outputInformation objectForKey:@"height"] unsignedIntegerValue] == 8,
                  @"Maximum dimension resizes proportionally.");

    error = nil;
    TGMediaAssert(![TGMediaWorkbenchProcessor processImageAtPath:sourcePath
                                                     outputPath:outputPath
                                                         format:@"invalid"
                                               maximumDimension:0
                                                        quality:1.0
                                                          error:&error] && error != nil,
                  @"Unsupported output formats fail safely.");

    [[NSFileManager defaultManager] removeItemAtPath:temporaryDirectory error:NULL];
    printf("Media Workbench tests: %lu assertions, %lu failures\n",
           (unsigned long)TGMediaTestsRun, (unsigned long)TGMediaTestsFailed);
    NSUInteger failures = TGMediaTestsFailed;
    [pool drain];
    return failures == 0 ? 0 : 1;
}
