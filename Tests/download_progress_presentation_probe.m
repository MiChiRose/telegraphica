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

    NSDictionary *pausedRecord = TGRecord(@"pause", @"paused", 2500000000LL, 5000000000LL);
    [presentation updateWithRecords:[NSArray arrayWithObject:pausedRecord]];
    TGAssert([presentation hidden] && [presentation activeCount] == 0, "persisted paused work must not auto-start or auto-show");
    [presentation show]; [presentation updateWithRecords:[NSArray arrayWithObject:pausedRecord]];
    TGAssert(![presentation hidden] && [[[presentation displayedRecord] objectForKey:@"state"] isEqualToString:@"paused"],
             "pausing keeps the current job visible for explicit resume");
    NSMutableDictionary *controls = [NSMutableDictionary dictionaryWithDictionary:pausedRecord];
    TGAssert(!TGDownloadProgressCanPerformAction(controls, @"resume"), "paused work without a ready client cannot resume");
    [controls setObject:[NSNumber numberWithBool:YES] forKey:@"can_resume"];
    [controls setObject:[NSNumber numberWithBool:YES] forKey:@"can_cancel"];
    TGAssert(TGDownloadProgressCanPerformAction(controls, @"resume") && TGDownloadProgressCanPerformAction(controls, @"cancel") &&
             !TGDownloadProgressCanPerformAction(controls, @"pause"), "paused controls reflect manager readiness rather than guessing auth");
    [controls setObject:@"downloading" forKey:@"state"]; [controls setObject:[NSNumber numberWithBool:YES] forKey:@"can_pause"];
    TGAssert(TGDownloadProgressCanPerformAction(controls, @"pause") && !TGDownloadProgressCanPerformAction(controls, @"resume"),
             "an active download offers pause and cancellation");
    [controls setObject:@"completed" forKey:@"state"];
    TGAssert(!TGDownloadProgressCanPerformAction(controls, @"pause") && !TGDownloadProgressCanPerformAction(controls, @"resume") &&
             !TGDownloadProgressCanPerformAction(controls, @"cancel"), "terminal work disables even stale capability flags");

    NSRect screen = NSMakeRect(0, 23, 1280, 777);
    NSSize minimumMainSize = NSMakeSize(760, 620);
    NSRect original = NSMakeRect(150, 100, 980, 620);
    TGAssert(NSIsEmptyRect(TGDownloadProgressPanelFrame(original, screen, 170.0)), "the old 134-point gap cannot squeeze the wider panel");
    NSRect mainFrame = TGDownloadProgressReservedMainFrame(original, screen, minimumMainSize, 170.0);
    NSRect expanded = TGDownloadProgressPanelFrame(mainFrame, screen, 170.0);
    NSRect collapsed = TGDownloadProgressPanelFrame(mainFrame, screen, 116.0);
    TGCheckFrame(expanded, mainFrame, screen, "1280 display reserves a readable external right panel");
    TGCheckFrame(collapsed, mainFrame, screen, "collapsed panel remains outside the conversation");
    TGAssert(NSWidth(expanded) == 340.0 && NSWidth(mainFrame) == 916.0 && NSWidth(mainFrame) >= minimumMainSize.width &&
             NSContainsRect(screen, mainFrame) && NSMaxY(expanded) == NSMaxY(collapsed),
             "reservation respects chat minimum, preferred width and collapse alignment");
    TGAssert(NSEqualRects(TGDownloadProgressReservedMainFrame(mainFrame, screen, minimumMainSize, 170.0), mainFrame),
             "repeated placement never repeatedly shrinks the main window");
    TGAssert(NSEqualRects(TGDownloadProgressRestoredMainFrame(original, mainFrame, mainFrame, screen, minimumMainSize), original),
             "closing restores the original frame while the reservation is owned");
    NSRect edited = mainFrame; edited.origin.x += 20.0;
    TGAssert(NSIsEmptyRect(TGDownloadProgressRestoredMainFrame(original, mainFrame, edited, screen, minimumMainSize)),
             "a user move must never be undone when closing");
    edited = mainFrame; edited.size.width -= 10.0;
    TGAssert(NSIsEmptyRect(TGDownloadProgressRestoredMainFrame(original, mainFrame, edited, screen, minimumMainSize)),
             "a user resize must never be undone when closing");
    NSRect relocatedScreen = NSMakeRect(-1920, 23, 1920, 1057);
    TGAssert(NSContainsRect(relocatedScreen, TGDownloadProgressRestoredMainFrame(original, mainFrame, mainFrame, relocatedScreen, minimumMainSize)),
             "restoration clamps onto the actual current display after a screen change");
    mainFrame = NSMakeRect(400, 100, 870, 620);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen, "left-side free room is used when right side is full");
    TGAssert(NSEqualRects(TGDownloadProgressReservedMainFrame(mainFrame, screen, minimumMainSize, 170.0), mainFrame),
             "existing room preserves the user's main frame");
    mainFrame = NSMakeRect(0, 250, 1280, 550);
    TGCheckFrame(TGDownloadProgressPanelFrame(mainFrame, screen, 170.0), mainFrame, screen, "bottom free room supports a full-width main window");
    mainFrame = NSMakeRect(0, 23, 1280, 777);
    NSRect reserved = TGDownloadProgressReservedMainFrame(mainFrame, screen, minimumMainSize, 170.0);
    TGCheckFrame(TGDownloadProgressPanelFrame(reserved, screen, 170.0), reserved, screen, "a maximized main window gets an external lane");
    screen = NSMakeRect(0, 23, 1100, 777); mainFrame = NSMakeRect(60, 100, 980, 620);
    reserved = TGDownloadProgressReservedMainFrame(mainFrame, screen, minimumMainSize, 170.0);
    TGAssert(NSWidth(TGDownloadProgressPanelFrame(reserved, screen, 170.0)) == 300.0 && NSWidth(reserved) >= 760.0,
             "smaller displays use 300-point minimum without violating the chat minimum");
    TGAssert(NSIsEmptyRect(TGDownloadProgressReservedMainFrame(mainFrame, NSMakeRect(0, 23, 1000, 777), minimumMainSize, 170.0)),
             "physically insufficient width cannot violate the chat minimum or overlap it");
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
