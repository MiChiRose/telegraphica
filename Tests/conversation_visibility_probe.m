#import <Cocoa/Cocoa.h>
#import "TGConversationVisibility.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", [message UTF8String]); exit(1); }
}

/* Native view attachment and ancestor behavior, with simulated foreground
 * window states instead of ordering or changing a user's real windows. */
@interface ConversationProbeWindow : NSWindow {
    BOOL _probeVisible, _probeKey, _probeMiniaturized;
}
@property (nonatomic, assign) BOOL probeVisible;
@property (nonatomic, assign) BOOL probeKey;
@property (nonatomic, assign) BOOL probeMiniaturized;
@end
@implementation ConversationProbeWindow
@synthesize probeVisible = _probeVisible;
@synthesize probeKey = _probeKey;
@synthesize probeMiniaturized = _probeMiniaturized;
- (BOOL)isVisible { return _probeVisible; }
- (BOOL)isKeyWindow { return _probeKey; }
- (BOOL)isMiniaturized { return _probeMiniaturized; }
@end

static BOOL Visible(NSView *view, NSWindow *window) {
    return TGConversationTranscriptIsVisible(view, window, YES, YES, NO, NO);
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    ConversationProbeWindow *window = [[ConversationProbeWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 640, 480) styleMask:NSTitledWindowMask
        backing:NSBackingStoreBuffered defer:NO];
    [window setProbeVisible:YES]; [window setProbeKey:YES];
    NSView *outer = [[[NSView alloc] initWithFrame:NSMakeRect(20, 20, 600, 440)] autorelease];
    NSView *inner = [[[NSView alloc] initWithFrame:NSMakeRect(10, 10, 580, 420)] autorelease];
    NSScrollView *transcript = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 580, 420)] autorelease];
    [[window contentView] addSubview:outer]; [outer addSubview:inner]; [inner addSubview:transcript];
    Check(Visible(transcript, window), @"foreground visible key host and attached transcript allow automatic reads");
    Check(!TGConversationTranscriptIsVisible(transcript, window, NO, YES, NO, NO), @"inactive application blocks automatic reads");
    Check(!TGConversationTranscriptIsVisible(transcript, window, YES, NO, NO, NO), @"other navigation sections block automatic reads");
    Check(!TGConversationTranscriptIsVisible(transcript, window, YES, YES, YES, NO), @"user-closed conversation blocks automatic reads");
    Check(!TGConversationTranscriptIsVisible(transcript, window, YES, YES, NO, YES), @"media center hiding transcript blocks automatic reads");
    [window setProbeKey:NO];
    Check(!Visible(transcript, window), @"another key window blocks automatic reads");
    [window setProbeKey:YES]; [window setProbeVisible:NO];
    Check(!Visible(transcript, window), @"hidden host blocks automatic reads");
    [window setProbeVisible:YES]; [window setProbeMiniaturized:YES];
    Check(!Visible(transcript, window), @"minimized host blocks automatic reads");
    [window setProbeMiniaturized:NO];
    NSArray *ancestors = [NSArray arrayWithObjects:transcript, inner, outer, [window contentView], nil];
    for (NSView *ancestor in ancestors) {
        [ancestor setHidden:YES];
        Check(!Visible(transcript, window), @"hidden transcript or any hidden ancestor blocks automatic reads");
        [ancestor setHidden:NO];
        Check(Visible(transcript, window), @"restoring ancestor visibility restores eligibility");
    }
    NSScrollView *detached = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
    Check(!Visible(detached, window), @"transcript unattached to host window is rejected");
    ConversationProbeWindow *otherWindow = [[ConversationProbeWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 640, 480) styleMask:NSTitledWindowMask
        backing:NSBackingStoreBuffered defer:NO];
    [otherWindow setProbeVisible:YES]; [otherWindow setProbeKey:YES];
    Check(!Visible(transcript, otherWindow), @"transcript in a different account/window is rejected");
    [transcript removeFromSuperview];
    Check(!Visible(transcript, window), @"detaching the previously visible transcript invalidates eligibility immediately");
    [inner addSubview:transcript];
    Check(Visible(transcript, window), @"reattaching transcript restores native window membership");
    Check(!Visible(nil, window) && !Visible(transcript, nil), @"missing host or transcript safely blocks automatic reads");
    [otherWindow release]; [window release];
    puts("PASS: conversation visibility gates foreground/key/minimized/window attachment, navigation, closure, media and every hidden ancestor");
    [pool drain]; return 0;
}
