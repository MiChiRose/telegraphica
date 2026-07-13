#import <Cocoa/Cocoa.h>
#import "TGMediaImageLoader.h"
#include <stdio.h>

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int result = 0;
    if (argc != 2) {
        result = 2;
    } else {
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSImage *image = TGImageWithCorrectOrientationFromFile(path);
        NSSize size = [image size];
        if (!image || size.width != 128.0 || size.height != 128.0) {
            fprintf(stderr, "WebP NSImage decode failed: %.0fx%.0f\n", size.width, size.height);
            result = 3;
        } else {
            fprintf(stdout, "WebP NSImage decode passed: %.0fx%.0f\n", size.width, size.height);
        }
    }
    [pool drain];
    return result;
}
