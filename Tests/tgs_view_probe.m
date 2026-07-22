#import <Cocoa/Cocoa.h>
#import "TGTGSAnimationView.h"
#import "TGInlineMediaPlaybackCoordinator.h"
#include <stdio.h>

int main(int argc, const char **argv) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableArray *views = [NSMutableArray array];
    NSMutableArray *firstChecksums = [NSMutableArray array];
    NSMutableArray *firstFrameCounts = [NSMutableArray array];
    BOOL valid = YES;
    if (argc != 4) return 2;

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
    TGTGSAnimationView *unsafeRepeaterView = [[[TGTGSAnimationView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)
                                                                              tgsPath:[NSString stringWithUTF8String:argv[3]]] autorelease];
    valid = (valid && ![unsafeRepeaterView isAnimationValid]);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    for (TGTGSAnimationView *view in views) {
        valid = (valid && [view renderedFrameCount] >= 2);
        [firstChecksums addObject:[NSNumber numberWithUnsignedLongLong:[view currentFrameChecksum]]];
        [firstFrameCounts addObject:[NSNumber numberWithUnsignedInteger:[view renderedFrameCount]]];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.35]];
    NSUInteger viewIndex = 0;
    for (viewIndex = 0; viewIndex < [views count]; viewIndex++) {
        TGTGSAnimationView *view = [views objectAtIndex:viewIndex];
        unsigned long long firstChecksum = [[firstChecksums objectAtIndex:viewIndex] unsignedLongLongValue];
        valid = (valid && [view renderedFrameCount] > [[firstFrameCounts objectAtIndex:viewIndex] unsignedIntegerValue]);
        valid = (valid && [view currentFrameChecksum] != 0 && [view currentFrameChecksum] != firstChecksum);
        [view setPlaybackActive:NO];
    }
    [views removeAllObjects];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.20]];

    NSView *hostView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)] autorelease];
    TGTGSAnimationView *removedView = [[TGTGSAnimationView alloc] initWithFrame:[hostView bounds]
                                                                        tgsPath:[NSString stringWithUTF8String:argv[1]]];
    [hostView addSubview:removedView];
    [removedView setPlaybackActive:YES];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.20]];
    [removedView removeFromSuperview];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.10]];
    NSUInteger stoppedFrameCount = [removedView renderedFrameCount];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.20]];
    valid = (valid && [removedView renderedFrameCount] == stoppedFrameCount);
    [removedView release];

    NSView *coordinatorHost = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 160, 160)] autorelease];
    TGInlineMediaPlaybackCoordinator *coordinator = [[TGInlineMediaPlaybackCoordinator alloc] initWithHostView:coordinatorHost
                                                                                           maximumActiveItems:1];
    NSDictionary *descriptor = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"tgs-probe", TGInlineMediaIdentifierKey,
                                [NSString stringWithUTF8String:argv[1]], TGInlineMediaPathKey,
                                [NSValue valueWithRect:NSMakeRect(0, 0, 128, 128)], TGInlineMediaFrameKey,
                                TGInlineMediaKindTGS, TGInlineMediaKindKey,
                                nil];
    [coordinator updateWithDescriptors:[NSArray arrayWithObject:descriptor]];
    valid = (valid && [[coordinatorHost subviews] count] == 1);
    [[[coordinatorHost subviews] lastObject] removeFromSuperview];
    valid = (valid && [[coordinatorHost subviews] count] == 0);
    [coordinator updateWithDescriptors:[NSArray arrayWithObject:descriptor]];
    valid = (valid && [[coordinatorHost subviews] count] == 1);
    [coordinator invalidate];
    [coordinator release];

    NSUInteger releaseIndex = 0;
    for (releaseIndex = 0; releaseIndex < 10; releaseIndex++) {
        NSView *releaseHost = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 64, 64)] autorelease];
        TGTGSAnimationView *releaseView = [[TGTGSAnimationView alloc] initWithFrame:[releaseHost bounds]
                                                                            tgsPath:[NSString stringWithUTF8String:argv[1]]];
        [releaseHost addSubview:releaseView];
        [releaseView setPlaybackActive:YES];
        [releaseView removeFromSuperview];
        [releaseView release];
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.50]];
    [pool drain];
    if (!valid) {
        fprintf(stderr, "TGS AppKit view probe failed.\n");
        return 3;
    }
    printf("TGS AppKit view probe passed: pixels changed; removed view stopped; detached overlay reattached; pending views released; raw JSON and unsafe repeater rejected.\n");
    return 0;
}
