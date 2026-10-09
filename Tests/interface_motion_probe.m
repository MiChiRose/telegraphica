#import <Cocoa/Cocoa.h>
#import "TGAnimationSupport.h"
#import "TGTranscriptMotion.h"
#import "TGTransparentSpinnerView.h"
#import "TGResourcePolicy.h"
#import <math.h>

static void Check(BOOL condition, NSString *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", [message UTF8String]); exit(1); }
}
@interface ProbeWindow : NSObject
@end
@implementation ProbeWindow
- (BOOL)isVisible { return YES; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [super methodSignatureForSelector:selector] ?: [NSWindow instanceMethodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    NSUInteger length = [[invocation methodSignature] methodReturnLength];
    if (length) { void *bytes = calloc(1, length); [invocation setReturnValue:bytes]; free(bytes); }
}
- (NSResponder *)firstResponder { return nil; }
- (NSView *)contentView { return nil; }
- (BOOL)makeFirstResponder:(NSResponder *)responder { (void)responder; return YES; }
@end
@interface ProbeTable : NSObject { ProbeWindow *_window; }
@property (nonatomic, assign) NSUInteger dirtyCount;
@end
@implementation ProbeTable
@synthesize dirtyCount = _dirtyCount;
- (id)init { self = [super init]; if (self) _window = [[ProbeWindow alloc] init]; return self; }
- (void)dealloc { [_window release]; [super dealloc]; }
- (NSWindow *)window { return (NSWindow *)_window; }
- (NSInteger)numberOfRows { return 20; }
- (NSRect)visibleRect { return NSMakeRect(0, 0, 300, 250); }
- (NSRect)rectOfRow:(NSInteger)row { return NSMakeRect(0, row * 50, 300, 50); }
- (void)setNeedsDisplayInRect:(NSRect)rect { Check(NSHeight(rect) <= 70.0, @"motion dirties only one row and its travel margin"); _dirtyCount++; }
@end
@interface ProbeView : NSView { ProbeWindow *_probeWindow; }
@property (nonatomic, assign) NSUInteger dirtyCount;
@end
@implementation ProbeView
@synthesize dirtyCount = _dirtyCount;
- (id)initWithFrame:(NSRect)frame { self = [super initWithFrame:frame]; if (self) _probeWindow = [[ProbeWindow alloc] init]; return self; }
- (void)dealloc { [_probeWindow release]; _probeWindow = nil; [super dealloc]; }
- (NSWindow *)window { return (NSWindow *)_probeWindow; }
- (BOOL)isOpaque { return YES; }
- (void)setNeedsDisplayInRect:(NSRect)rect { _dirtyCount++; [super setNeedsDisplayInRect:rect]; }
@end
@interface ProbeSpinner : TGTransparentSpinnerView { ProbeWindow *_probeWindow; }
@end
@implementation ProbeSpinner
- (id)initWithFrame:(NSRect)frame { self = [super initWithFrame:frame]; if (self) _probeWindow = [[ProbeWindow alloc] init]; return self; }
- (void)dealloc { [_probeWindow release]; _probeWindow = nil; [super dealloc]; }
- (NSWindow *)window { return (NSWindow *)_probeWindow; }
@end

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGResourcePolicySetEconomyModeEnabled(NO);
    TGResourcePolicySetStopAnimationsWhenInactive(NO);
    NSPoint in = TGTranscriptMotionOffset(0, NO, YES, NO);
    NSPoint out = TGTranscriptMotionOffset(0, YES, YES, NO);
    Check(in.x < 0 && out.x > 0 && in.y > 0, @"incoming/outgoing reveal direction and flipped baseline");
    Check(TGTranscriptMotionOffset(0, YES, NO, NO).y < 0, @"nonflipped travel mirrors vertical direction");
    Check(NSEqualPoints(TGTranscriptMotionOffset(1, YES, YES, NO), NSZeroPoint), @"arrival ends at stable layout");
    Check(TGTranscriptMotionOpacity(1, NO) == 1 && TGTranscriptMotionOpacity(1, YES) == 0, @"final opacity");

    ProbeTable *table = [[ProbeTable alloc] init];
    TGTranscriptMotionController *motion = [[TGTranscriptMotionController alloc] initWithTableView:(NSTableView *)table];
    for (NSUInteger index = 0; index < 8; index++)
        [motion beginArrivalForChatID:@1 messageID:[NSNumber numberWithUnsignedInteger:index + 1] row:index outgoing:NO];
    Check([motion activeAnimationCount] == 4, @"burst is capped instead of queuing more work");
    Check([motion activeRemovalCount] == 0, @"arrivals do not defer deletion refreshes");
    [motion cancelAllAnimations];
    Check([motion activeAnimationCount] == 0 && [motion valueForKey:@"timer"] == nil, @"idle leaves no ticking timer");
    __block NSUInteger completions = 0;
    [motion beginRemovalForChatID:@1 messageID:@2 row:1 outgoing:YES completion:^{ completions++; }];
    [motion beginArrivalForChatID:@1 messageID:@1 row:0 outgoing:NO];
    Check([motion activeRemovalCount] == 1 && [motion activeAnimationCount] == 2,
          @"removal count distinguishes pending deletion from arrivals");
    [motion cancelAllAnimations];
    [motion cancelAllAnimations];
    Check(completions == 1, @"cancel completes confirmed removal once");
    Check([motion activeRemovalCount] == 0, @"cancellation clears pending removals");
    [motion beginRemovalForChatID:@1 messageID:@2 row:1 outgoing:YES completion:^{ completions++; }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    Check(completions == 2 && [motion activeAnimationCount] == 0 && [motion valueForKey:@"timer"] == nil,
          @"natural completion finalizes deletion and removes the timer");
    Check([motion activeRemovalCount] == 0, @"natural completion permits pending refreshes");
    [motion beginArrivalForChatID:@1 messageID:@9 row:19 outgoing:NO];
    Check([motion activeAnimationCount] == 0, @"offscreen arrival does not allocate motion");
    [motion beginRemovalForChatID:@1 messageID:@3 row:2 outgoing:YES completion:^{ completions++; }];
    TGResourcePolicySetEconomyModeEnabled(YES);
    Check([motion activeAnimationCount] == 0 && completions == 3, @"economy cancels active motion and finalizes model removal");
    Check([motion activeRemovalCount] == 0, @"economy does not leave refreshes deferred");
    [motion beginRemovalForChatID:@1 messageID:@4 row:3 outgoing:NO completion:^{ completions++; }];
    Check(completions == 4 && [motion activeAnimationCount] == 0, @"economy removes immediately");

    ProbeView *panel = [[ProbeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    [panel setHidden:YES];
    TGSetViewVisibleAnimated(panel, YES);
    Check(![panel isHidden] && [panel alphaValue] == 1, @"economy reveal is immediate");
    TGResourcePolicySetEconomyModeEnabled(NO);
    TGResourcePolicySetStopAnimationsWhenInactive(NO);
    TGSetViewVisibleAnimated(panel, NO);
    TGSetViewVisibleAnimated(panel, YES);
    TGCancelViewVisibilityAnimation(panel);
    Check(![panel isHidden] && [panel alphaValue] == 1, @"reversed panel completion cannot hide newly opened panel");

    ProbeSpinner *spinner = [[ProbeSpinner alloc] initWithFrame:NSMakeRect(10, 10, 24, 24)];
    [panel addSubview:spinner];
    [spinner startAnimation:nil];
    Check([spinner valueForKey:@"animationTimer"] != nil, @"normal loading indicator ticks");
    NSUInteger before = panel.dirtyCount;
    [spinner performSelector:@selector(advanceAnimation:) withObject:nil];
    Check(panel.dirtyCount > before, @"transparent spinner erases spokes from parent backing store each tick");
    before = panel.dirtyCount;
    [spinner setFrame:NSMakeRect(20, 20, 24, 24)];
    Check(panel.dirtyCount >= before + 2, @"moving spinner repaints old and new areas");
    TGResourcePolicySetEconomyModeEnabled(YES);
    Check([spinner valueForKey:@"animationTimer"] == nil && ![spinner isHidden], @"economy keeps static loading feedback without timer");
    [spinner stopAnimation:nil];
    Check([spinner isHidden] && [spinner valueForKey:@"animationTimer"] == nil, @"stopped indicator is hidden and timer-free");
    [spinner removeFromSuperview]; [spinner release]; [panel release];
    [motion release]; [table release];
    puts("PASS: bounded transcript motion, cancellation, economy, panel reversal and transparent spinner repaint");
    [pool drain];
    return 0;
}
