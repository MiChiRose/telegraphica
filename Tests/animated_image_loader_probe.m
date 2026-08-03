#import <Cocoa/Cocoa.h>
#import "TGAnimatedImageLoader.h"

static void TGAnimatedImageAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Animated image loader probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

static void TGAnimatedImageRunLoopUntil(BOOL *finished, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!*finished && [deadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    const unsigned char gifBytes[] = {
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x21,
        0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44,
        0x01, 0x00, 0x3b
    };
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"telegraphica-animated-image-probe.gif"];
    NSData *data = [NSData dataWithBytes:gifBytes length:sizeof(gifBytes)];
    TGAnimatedImageAssert([data writeToFile:path atomically:YES], @"fixture should be written");

    __block BOOL finished = NO;
    __block BOOL loaded = NO;
    __block BOOL deliveredOnMainThread = NO;
    TGAnimatedImageLoadToken *token = [TGLoadAnimatedImageFromFileAsync(path, ^(NSImage *image, NSString *failureReason) {
        (void)failureReason;
        loaded = (image != nil);
        deliveredOnMainThread = [NSThread isMainThread];
        finished = YES;
    }) retain];
    TGAnimatedImageAssert(token != nil, @"valid request should return a token");
    TGAnimatedImageRunLoopUntil(&finished, 3.0);
    TGAnimatedImageAssert(finished && loaded, @"valid GIF should load asynchronously");
    TGAnimatedImageAssert(deliveredOnMainThread, @"completion should be delivered on main thread");
    [token release];

    __block BOOL cancelledCompletion = NO;
    TGAnimatedImageLoadToken *cancelledToken = [TGLoadAnimatedImageFromFileAsync(path, ^(NSImage *image, NSString *failureReason) {
        (void)image;
        (void)failureReason;
        cancelledCompletion = YES;
    }) retain];
    [cancelledToken cancel];
    NSDate *cancelDeadline = [NSDate dateWithTimeIntervalSinceNow:0.1];
    while ([cancelDeadline timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:cancelDeadline];
    }
    TGAnimatedImageAssert(!cancelledCompletion, @"cancelled request should suppress completion");
    [cancelledToken release];

    TGAnimatedImageLoaderClearCache();
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    printf("Animated image loader probe passed.\n");
    [pool drain];
    return 0;
}
