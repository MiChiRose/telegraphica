#import <Cocoa/Cocoa.h>
#import "../Sources/UI/TGDownloadProgressWindowController.h"
#import "../Sources/Services/TGDownloadManager.h"

// Presentation/geometry tests do not initialize NSApplication or contact TDLib.
NSString * const TGDownloadManagerDidChangeNotification = @"TGDownloadManagerDidChangeNotification";
NSString *TGLoc(NSString *key) { return key; }
NSColor *TGClassicPanelBottomColor(void) { return [NSColor whiteColor]; }
NSColor *TGClassicInkColor(void) { return [NSColor blackColor]; }
NSColor *TGClassicMutedInkColor(void) { return [NSColor grayColor]; }
static void TGAssert(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "Download progress probe failed: %s\n", message); exit(1); }
}
static NSDictionary *TGRecord(NSString *identifier, NSString *state, long long downloaded, long long total) {
    return [NSDictionary dictionaryWithObjectsAndKeys:identifier, @"identifier", state, @"state",
            @"archive.zip", @"file_name", [NSNumber numberWithLongLong:downloaded], @"downloaded_bytes",
            [NSNumber numberWithLongLong:total], @"total_bytes", nil];
}
static void TGCheckFrame(NSRect frame, NSRect mainFrame, NSRect screen, const char *message) {
    TGAssert(!NSIsEmptyRect(frame) && NSContainsRect(screen, frame) && !NSIntersectsRect(frame, mainFrame), message);
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGDownloadProgressPresentation *presentation = [[[TGDownloadProgressPresentation alloc] init] autorelease];
    TGAssert([presentation hidden] && ![presentation updateWithRecords:[NSArray array]], "idle must remain silent");
    NSDictionary *first = TGRecord(@"one", @"downloading", 2500000000LL, 5000000000LL);
    TGAssert([presentation updateWithRecords:[NSArray arrayWithObject:first]] && ![presentation hidden] &&
             [presentation activeCount] == 1, "new active download automatically appears");
    TGAssert(fabs(TGDownloadProgressFraction([presentation displayedRecord]) - 0.5) < 0.000001,
             "5 GB progress retains full 64-bit precision");
    [presentation hide];
    NSDictionary *advanced = TGRecord(@"one", @"downloading", 4000000000LL, 5000000000LL);
    TGAssert(![presentation updateWithRecords:[NSArray arrayWithObject:advanced]] && [presentation hidden],
             "closing progress must not reopen it on updates of the same download");
    NSDictionary *second = TGRecord(@"two", @"queued", 0, 290000000LL);
    TGAssert([presentation updateWithRecords:[NSArray arrayWithObjects:second, advanced, nil]] &&
             ![presentation hidden] && [presentation activeCount] == 2 &&
             [[[presentation displayedRecord] objectForKey:@"identifier"] isEqualToString:@"two"],
             "a genuinely new job can reopen the panel and display queued work");
    [presentation hide];
    NSDictionary *done = TGRecord(@"two", @"completed", 290000000LL, 290000000LL);
    [presentation updateWithRecords:[NSArray arrayWithObject:done]];
    TGAssert([presentation hidden] && [presentation activeCount] == 0 && TGDownloadProgressFraction(done) == 1.0,
             "completion cannot reopen a dismissed panel or restart animation");
    [presentation show]; TGAssert(![presentation hidden], "explicit show is available after dismissal");
    [presentation updateWithRecords:[NSArray array]];
    TGAssert([presentation hidden] && ![presentation displayedRecord], "clearing history leaves no stale filename");
    TGAssert(TGDownloadProgressFraction(TGRecord(@"x", @"downloading", 12, 0)) == 0.0 &&
             TGDownloadProgressFraction(TGRecord(@"x", @"downloading", -1, 50)) == 0.0 &&
             TGDownloadProgressFraction(TGRecord(@"x", @"downloading", 100, 50)) == 1.0,
             "unknown and malformed totals cannot overflow a progress bar");

    NSRect screen = NSMakeRect(0, 23, 1280, 777);
    NSRect mainFrame = NSMakeRect(150, 100, 980, 620);
    NSRect expanded = TGDownloadProgressPanelFrame(mainFrame, screen, 170.0);
    NSRect collapsed = TGDownloadProgressPanelFrame(mainFrame, screen, 116.0);
    TGCheckFrame(expanded, mainFrame, screen, "1280 display has a narrow external right panel");
    TGCheckFrame(collapsed, mainFrame, screen, "collapsed panel remains outside the conversation");
    TGAssert(NSWidth(expanded) >= 128.0 && NSWidth(expanded) <= 142.0 &&
             NSMaxY(expanded) == NSMaxY(collapsed), "collapse retains top alignment and fits the actual side gap");
    mainFrame = NSMakeRect(300, 100, 970, 620);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen, "left-side free room is used when right side is full");
    mainFrame = NSMakeRect(0, 250, 1280, 550);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen, "bottom free room supports a full-width main window");
    mainFrame = NSMakeRect(0, 23, 1280, 777);
    TGAssert(NSIsEmptyRect(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0)), "no-room fullscreen must not cover the conversation");
    screen = NSMakeRect(-1920, 23, 1920, 1057); mainFrame = NSMakeRect(-1770, 100, 980, 800);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen, "positioning uses the actual negative-origin display");
    screen = NSMakeRect(0, 23, 1280, 777); mainFrame = NSMakeRect(-1200, 100, 980, 620);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen,
                 "an offscreen main-window edge cannot put the panel outside the visible display");
    TGAssert(NSIsEmptyRect(TGDownloadProgressPanelFrame(mainFrame, NSMakeRect(0, 0, 100, 100), 170.0)),
             "a tiny screen cannot produce clipped controls");
    fprintf(stdout, "Download progress presentation probe passed.\n");
    [pool drain]; return 0;
}
