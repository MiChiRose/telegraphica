#import <Cocoa/Cocoa.h>
#import "TGTGSAnimationView.h"
#include <stdio.h>

int main(int argc, const char **argv) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *views = [NSMutableArray array];
    BOOL valid = YES;
    if (argc != 3) return 2;

    NSUInteger index = 0;
    for (index = 0; index < 5; index++) {
        TGTGSAnimationView *view = [[[TGTGSAnimationView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)
                                                                      tgsPath:[NSString stringWithUTF8String:argv[1]]] autorelease];
        valid = (valid && [view isAnimationValid] && [view hitTest:NSMakePoint(20, 20)] == nil);
        [view setPlaybackActive:YES];
        [views addObject:view];
    }
    TGTGSAnimationView *rawJSONView = [[[TGTGSAnimationView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)
                                                                        tgsPath:[NSString stringWithUTF8String:argv[2]]] autorelease];
    valid = (valid && ![rawJSONView isAnimationValid]);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.20]];
    for (TGTGSAnimationView *view in views) {
        [view setPlaybackActive:NO];
    }
    [pool drain];
    if (!valid) {
        fprintf(stderr, "TGS AppKit view probe failed.\n");
        return 3;
    }
    printf("TGS AppKit view probe passed: five bounded views; raw JSON rejected.\n");
    return 0;
}
