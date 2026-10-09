#import <Cocoa/Cocoa.h>
#import "TGSectionTransition.h"
#import "TGResourcePolicy.h"

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", [message UTF8String]); exit(1); }
}
// An actual AppKit window/view hierarchy without displaying a test window.
@interface SectionProbeWindow : NSWindow { BOOL _probeVisible; }
@property (nonatomic, assign) BOOL probeVisible;
@end
@implementation SectionProbeWindow
@synthesize probeVisible = _probeVisible;
- (BOOL)isVisible { return _probeVisible; }
@end

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    TGResourcePolicySetEconomyModeEnabled(NO);
    TGResourcePolicySetStopAnimationsWhenInactive(NO);
    SectionProbeWindow *window = [[SectionProbeWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
        styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
    [window setProbeVisible:YES];
    NSView *root = [window contentView];
    NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(180, 200, 160, 30)] autorelease];
    [button setTitle:@"Pause"];
    [root addSubview:button];
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(400, 100, 200, 300)] autorelease];
    NSView *document = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 900)] autorelease];
    [scroll setDocumentView:document]; [root addSubview:scroll];
    [[scroll contentView] scrollToPoint:NSMakePoint(0, 300)];
    NSRect originalButton = [button frame], originalScroll = [[scroll contentView] bounds];
    NSUInteger baselineSubviews = [[root subviews] count];
    NSObject *account = [[[NSObject alloc] init] autorelease];
    NSObject *otherAccount = [[[NSObject alloc] init] autorelease];
    TGSectionTransitionController *transition = [[TGSectionTransitionController alloc] initWithContentView:root];
    NSRect body = NSMakeRect(140, 80, 650, 450);
    NSColor *color = [NSColor colorWithCalibratedWhite:0.3 alpha:1];
    [transition presentSection:@"chats" contentRect:body backgroundColor:color context:account];
    Check(![transition isAnimating], @"initial presentation has no effect");
    [transition presentSection:@"settings" contentRect:body backgroundColor:color context:account];
    NSView *oldVeil = [[transition valueForKey:@"veilView"] retain];
    Check([transition isAnimating] && [[root subviews] count] == baselineSubviews + 1, @"one effect covers a genuine section change");
    Check([oldVeil alphaValue] <= 0.15 && ![oldVeil isOpaque], @"subtle transparent effect avoids full-pane flash");
    Check([oldVeil hitTest:NSMakePoint(200, 210)] == nil && [root hitTest:NSMakePoint(200, 210)] == button,
          @"buttons receive input immediately through the effect");
    Check(NSEqualRects([button frame], originalButton) && NSEqualRects([[scroll contentView] bounds], originalScroll),
          @"presentation does not move controls or alter scroll state");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.08]];
    Check([oldVeil alphaValue] > 0 && [oldVeil alphaValue] < 0.15, @"production timer advances the actual AppKit reveal");
    NSTimer *originalTimer = [transition valueForKey:@"timer"];
    [transition presentSection:@"settings" contentRect:body backgroundColor:color context:account];
    Check([transition valueForKey:@"timer"] == originalTimer, @"same-section polling does not restart or duplicate animation");
    [transition presentSection:@"profile" contentRect:body backgroundColor:color context:account];
    Check([oldVeil superview] == nil && [[root subviews] count] == baselineSubviews + 1,
          @"rapid switching removes previous effect instead of queuing completions");
    [oldVeil release];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    Check(![transition isAnimating] && [transition valueForKey:@"veilView"] == nil && [[root subviews] count] == baselineSubviews,
          @"natural completion removes its view and timer");
    [transition presentSection:@"contacts" contentRect:body backgroundColor:color context:account];
    TGResourcePolicySetEconomyModeEnabled(YES);
    Check(![transition isAnimating] && [[root subviews] count] == baselineSubviews, @"economy cancels an active transition synchronously");
    [transition presentSection:@"workshop" contentRect:body backgroundColor:color context:account];
    Check(![transition isAnimating] && [transition valueForKey:@"veilView"] == nil, @"economy creates neither timer nor overlay");
    TGResourcePolicySetEconomyModeEnabled(NO); TGResourcePolicySetStopAnimationsWhenInactive(NO);
    [transition presentSection:@"settings" contentRect:body backgroundColor:color context:otherAccount];
    Check(![transition isAnimating], @"account replacement starts a new baseline without old-account presentation");
    [transition presentSection:nil contentRect:body backgroundColor:color context:nil];
    [transition presentSection:@"chats" contentRect:body backgroundColor:color context:account];
    Check(![transition isAnimating], @"authentication and unsupported/calls boundaries reset presentation");
    [transition presentSection:@"settings" contentRect:body backgroundColor:color context:account];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResizeNotification object:window];
    Check(![transition isAnimating], @"window resize immediately removes the old-sized effect");
    [window setProbeVisible:NO];
    [transition presentSection:@"contacts" contentRect:body backgroundColor:color context:account];
    Check(![transition isAnimating] && [transition valueForKey:@"veilView"] == nil, @"hidden window does not allocate an effect");
    [window setProbeVisible:YES];
    [transition presentSection:@"profile" contentRect:body backgroundColor:color context:account];
    TGResourcePolicySetStopAnimationsWhenInactive(YES);
    [[NSNotificationCenter defaultCenter] postNotificationName:NSApplicationDidResignActiveNotification object:nil];
    Check(![transition isAnimating], @"inactive policy stops effect");
    TGResourcePolicySetStopAnimationsWhenInactive(NO);
    [transition presentSection:@"contacts" contentRect:body backgroundColor:color context:account];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSWindowWillCloseNotification object:window];
    Check(![transition isAnimating], @"window close removes its presentation immediately");
    [transition presentSection:@"settings" contentRect:NSMakeRect(-100, -100, 1200, 900) backgroundColor:color context:account];
    Check(NSEqualRects([[transition valueForKey:@"veilView"] frame], [root bounds]), @"effect is clipped to the owning view bounds");
    [transition reset]; [transition release];
    Check([[root subviews] count] == baselineSubviews, @"explicit teardown leaves no effect or timer-owned content");
    [window release];
    puts("PASS: main section reveal, immediate input, preserved geometry/scroll, rapid switching, account/auth boundaries, economy and teardown");
    [pool drain]; return 0;
}
