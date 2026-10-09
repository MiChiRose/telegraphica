#import <Cocoa/Cocoa.h>
#import "TGDownloadManagerPresentation.h"
#import "TGDownloadManagerWindowController.h"
#import "TGDownloadManager.h"
#import "TGMediaFileActions.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGStatusViewComponents.h"
#include <math.h>
#include <stdio.h>

// Only the base represented-object storage and window containers are adapters.
// Layout, row rendering, themes/localization, buttons and controller are real.
@implementation TGRepresentedObjectCell
@synthesize representedObject = _representedObject;
- (void)dealloc { [_representedObject release]; [super dealloc]; }
@end
@implementation TGUtilityWindowView
@end
@implementation TGScrollSurfaceView
@synthesize drawsInterior = _drawsInterior;
@end
@implementation TGGroupedCardView
@synthesize drawsInterior = _drawsInterior;
@end

NSString * const TGDownloadManagerDidChangeNotification = @"TGDownloadManagerDidChangeNotification";
static NSArray *TGRecords;
static NSString *TGRetrySource;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TGDownloadManager
+ (TGDownloadManager *)sharedManager { static TGDownloadManager *value; if (!value) { value = [[self alloc] init]; } return value; }
- (NSArray *)itemsSnapshot { return TGRecords ? TGRecords : [NSArray array]; }
- (NSString *)enqueueRetryDownloadWithIdentifier:(NSString *)identifier completion:(TGDownloadCompletionBlock)completion {
    (void)completion; [TGRetrySource release]; TGRetrySource = [identifier copy];
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithDictionary:[TGRecords objectAtIndex:0]];
    [record setObject:@"new-retry" forKey:@"identifier"]; [record setObject:@"queued" forKey:@"state"];
    [record setObject:@YES forKey:@"can_cancel"];
    NSArray *next = [[NSArray alloc] initWithObjects:record, [TGRecords objectAtIndex:0], nil];
    [TGRecords release]; TGRecords = next; return @"new-retry";
}
- (void)pauseDownloadWithIdentifier:(NSString *)identifier { (void)identifier; }
- (void)resumeDownloadWithIdentifier:(NSString *)identifier completion:(TGDownloadCompletionBlock)completion { (void)identifier; (void)completion; }
- (void)cancelDownloadWithIdentifier:(NSString *)identifier { (void)identifier; }
- (void)clearFinishedDownloads { }
@end
@implementation TGMediaFileActions
+ (BOOL)revealFileAtPath:(NSString *)path { (void)path; return NO; }
@end
#pragma clang diagnostic pop
@interface TGDownloadManagerWindowController (Probe)
- (void)reloadDownloads;
- (void)retryPressed:(id)sender;
- (void)layoutDownloadViews;
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row;
@end
@interface TGFlippedDownloadProbeView : NSView
@end
@implementation TGFlippedDownloadProbeView
- (BOOL)isFlipped { return YES; }
@end
static void Require(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Download manager presentation probe failed: %s\n", message); exit(1); }
}
static double Luminance(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    double c[] = {[rgb redComponent], [rgb greenComponent], [rgb blueComponent]};
    for (NSUInteger i = 0; i < 3; i++) { c[i] = c[i] <= 0.04045 ? c[i] / 12.92 : pow((c[i] + 0.055) / 1.055, 2.4); }
    return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2];
}
static double Contrast(NSColor *a, NSColor *b) { double x=Luminance(a), y=Luminance(b); return (MAX(x,y)+0.05)/(MIN(x,y)+0.05); }
static NSColor *RenderedPixel(NSSize size, void (^draw)(void)) {
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, (size_t)ceil(size.width), (size_t)ceil(size.height), 8, 0, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    Require(bitmap != NULL, "sRGB pixel context exists");
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmap flipped:NO]];
    CGContextClearRect(bitmap, CGRectMake(0,0,size.width,size.height));
    draw(); [NSGraphicsContext restoreGraphicsState];
    CGImageRef image = CGBitmapContextCreateImage(bitmap);
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
    NSColor *pixel = [rep colorAtX:[rep pixelsWide]/2 y:[rep pixelsHigh]/2];
    CGImageRelease(image); CGContextRelease(bitmap); CGColorSpaceRelease(space);
    return pixel;
}
static NSColor *RenderedSurfacePaper(NSView *surface) {
    NSSize size = [surface bounds].size;
    NSColor *pixel = RenderedPixel(size, ^{
        [surface drawRect:[surface bounds]];
    });
    Require([pixel alphaComponent]>=0.99, "actual header/footer center is opaque over window material");
    return pixel;
}
static void SetRecords(NSArray *records) { [TGRecords release]; TGRecords = [records copy]; }
static NSDictionary *Record(NSString *state) {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"old-record", @"identifier", state, @"state",
        @"Очень длинное имя архива — вельмі доўгі файл — very-long-download-name.zip", @"file_name",
        @5368709120LL, @"total_bytes", @2684354560LL, @"downloaded_bytes",
        @YES, @"can_pause", @YES, @"can_resume", @YES, @"can_cancel", nil];
}
static void CheckLayout(NSSize size) {
    TGDownloadManagerLayout f = TGDownloadManagerLayoutForSize(size);
    NSRect bounds = NSMakeRect(0,0,size.width,size.height);
    NSRect regions[] = {f.header,f.surface,f.footer};
    for (NSUInteger i=0;i<3;i++) {
        Require(NSContainsRect(bounds,regions[i]), "major region must fit window content");
        for (NSUInteger j=i+1;j<3;j++) { Require(!NSIntersectsRect(regions[i],regions[j]), "header/list/footer must not overlap"); }
    }
    Require(NSContainsRect(f.header,f.title) && NSContainsRect(f.header,f.subtitle) && !NSIntersectsRect(f.title,f.subtitle),
        "header labels stay wholly inside their readable backing surface");
    Require(NSContainsRect(f.surface,f.list) && NSContainsRect(f.list,f.empty), "list and empty message stay inside surface");
    NSRect controls[] = {f.pause,f.cancel,f.retry,f.reveal,f.clear,f.summary};
    for (NSUInteger i=0;i<6;i++) {
        Require(NSWidth(controls[i])>0 && NSContainsRect(f.footer,controls[i]), "footer control has positive width and fits");
        for (NSUInteger j=i+1;j<6;j++) { Require(!NSIntersectsRect(controls[i],controls[j]), "footer actions and status must not overlap"); }
    }
    NSString *keys[] = {@"downloads.pause",@"downloads.cancel",@"downloads.retry",@"downloads.reveal",@"downloads.clear"};
    for (NSUInteger i=0;i<5;i++) {
        NSFont *font = [NSFont boldSystemFontOfSize:i==0 ? 13 : 12];
        CGFloat measured = [TGLoc(keys[i]) sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
        Require(NSWidth(controls[i]) >= measured + (i==0 ? 24 : 20), "actual rendered button font plus padding must fit");
    }
    Require(NSWidth(f.pause) >= [TGLoc(@"downloads.resume") sizeWithAttributes:
        [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:13] forKey:NSFontAttributeName]].width + 24,
        "Resume title fits Pause button geometry");
    Require(NSWidth(f.title) >= [TGLoc(@"downloads.title") sizeWithAttributes:
        [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:20] forKey:NSFontAttributeName]].width + 4 &&
        NSWidth(f.subtitle) >= [TGLoc(@"downloads.help") sizeWithAttributes:
        [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName]].width + 4 &&
        NSWidth(f.empty) >= [TGLoc(@"downloads.empty") sizeWithAttributes:
        [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:13] forKey:NSFontAttributeName]].width + 4,
        "localized header/help/empty text fits actual font metrics");
    Require(NSWidth(f.summary) >= [[NSString stringWithFormat:TGLoc(@"downloads.count"), (unsigned long)100] sizeWithAttributes:
        [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName]].width + 4,
        "localized maximum persisted queue count fits footer summary");
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; [NSApplication sharedApplication];
    SetRecords([NSArray array]);
    TGDownloadManagerWindowController *controller = [[[TGDownloadManagerWindowController alloc] init] autorelease];
    for (NSString *language in [NSArray arrayWithObjects:@"ru",@"be",@"en",nil]) {
        TGSetLanguageCode(language);
        CheckLayout(NSMakeSize(620,460)); CheckLayout(NSMakeSize(740,540)); CheckLayout(NSMakeSize(1000,760));
        [controller refreshPresentation];
        Require([[[controller valueForKey:@"titleField"] stringValue] isEqual:TGLoc(@"downloads.title")] &&
            [[[controller valueForKey:@"subtitleField"] stringValue] isEqual:TGLoc(@"downloads.help")] &&
            [[[controller valueForKey:@"statusField"] stringValue] isEqual:TGLoc(@"downloads.empty")],
            "existing controller refreshes all empty-state labels after language change");
        SetRecords([NSArray arrayWithObject:Record(@"paused")]); [controller refreshPresentation];
        Require([[[controller valueForKey:@"statusField"] stringValue] isEqual:
            [NSString stringWithFormat:TGLoc(@"downloads.count"), (unsigned long)1]] &&
            [[[controller valueForKey:@"pauseButton"] title] isEqual:TGLoc(@"downloads.resume")],
            "language refresh reloads queue summary and Pause/Resume strings");
        for (NSNumber *width in [NSArray arrayWithObjects:@620,@740,@1000,nil]) {
            NSSize size = NSMakeSize([width doubleValue],460);
            [[controller window] setContentSize:size]; [controller layoutDownloadViews];
            TGDownloadManagerLayout f=TGDownloadManagerLayoutForSize(size);
            Require(NSEqualRects([[controller valueForKey:@"headerView"] frame],f.header) &&
                NSEqualRects([[controller valueForKey:@"titleField"] frame],f.title) &&
                NSEqualRects([[controller valueForKey:@"pauseButton"] frame],f.pause) &&
                NSEqualRects([[controller valueForKey:@"clearButton"] frame],f.clear),
                "actual controller applies measured geometry at every supported width");
        }
        SetRecords([NSArray array]);
    }
    Require([TGDownloadManagerByteCount(5368709120LL) isEqual:[NSByteCountFormatter stringFromByteCount:5368709120LL
        countStyle:NSByteCountFormatterCountStyleBinary]], "5GB uses complete 64-bit binary units");
    Require([TGDownloadManagerByteCount(-1) isEqual:TGDownloadManagerByteCount(0)], "negative byte counts clamp safely");
    NSArray *themes = TGThemeIdentifiers(); Require([themes count]==29, "all 29 approved themes exercised");
    TGDownloadListCell *cell = [[[TGDownloadListCell alloc] initTextCell:@""] autorelease];
    cell.representedObject = [NSDictionary dictionaryWithObjectsAndKeys:
        [Record(@"paused") objectForKey:@"file_name"], @"title", @"Paused · 2.5 GB / 5 GB · Long failure detail", @"detail",
        @YES,@"show_progress",@0.5,@"progress",nil];
    for (NSString *theme in themes) {
        TGSetActiveThemeIdentifier(theme);
        [controller refreshPresentation];
        NSColor *headerPaper = RenderedSurfacePaper([controller valueForKey:@"headerView"]);
        NSColor *footerPaper = RenderedSurfacePaper([controller valueForKey:@"footerView"]);
        Require([headerPaper alphaComponent]>=0.99 && [footerPaper alphaComponent]>=0.99,
            "real surfaces replace transparent pixels with opaque theme paper");
        // Ink contrast uses source sRGB colors; the bitmap independently proves
        // backing opacity. Device/TIFF color profiles aren't text-render proofs.
        NSColor *labelPaper = TGClassicTablePaperColor();
        double titleContrast = Contrast([[controller valueForKey:@"titleField"] textColor],labelPaper);
        double subtitleContrast = Contrast([[controller valueForKey:@"subtitleField"] textColor],labelPaper);
        double summaryContrast = Contrast([[controller valueForKey:@"statusField"] textColor],labelPaper);
        if (MIN(titleContrast,MIN(subtitleContrast,summaryContrast)) < 4.49) {
            fprintf(stderr,"Theme %s: title=%.3f subtitle=%.3f summary=%.3f\n", [theme UTF8String],titleContrast,subtitleContrast,summaryContrast);
        }
        Require(titleContrast>=4.5-0.01 && subtitleContrast>=4.5-0.01 && summaryContrast>=4.5-0.01,
            "actual refreshed label colors contrast with opaque theme paper in all29themes");
        for (NSUInteger selected=0;selected<2;selected++) {
            NSColor *paper = selected ? TGClassicSelectedRowColor() : TGClassicTablePaperColor();
            NSColor *preferred = selected ? TGClassicSelectedRowTextColor() : TGClassicCardInkColor();
            Require(Contrast(TGDownloadManagerReadableInk(preferred,paper),paper)>=4.5-0.001, "title ink contrast passes every theme/selection");
            Require(Contrast(TGDownloadManagerReadableInk(selected ? preferred : TGClassicCardMutedInkColor(),paper),paper)>=4.5-0.001,
                "detail ink contrast passes every theme/selection");
            [cell setHighlighted:selected != 0];
            for (NSUInteger flipped=0;flipped<2;flipped++) {
                NSView *view = flipped ? [[[TGFlippedDownloadProbeView alloc] initWithFrame:NSMakeRect(0,0,548,72)] autorelease] :
                    [[[NSView alloc] initWithFrame:NSMakeRect(0,0,548,72)] autorelease];
                NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(548,72)] autorelease];
                [image lockFocus]; [cell drawWithFrame:NSMakeRect(0,0,548,72) inView:view]; [image unlockFocus];
                Require([image TIFFRepresentation]!=nil, "actual row renderer draws long name/progress in every theme and orientation");
            }
        }
    }
    TGSetActiveThemeIdentifier([themes objectAtIndex:0]); TGSetLanguageCode(@"ru");
    SetRecords([NSArray array]);
    NSTextField *empty = [controller valueForKey:@"emptyField"];
    Require(![empty isHidden], "empty manager displays clear empty state");
    NSTableView *table = [controller valueForKey:@"tableView"];
    SetRecords([NSArray arrayWithObject:Record(@"paused")]); [controller reloadDownloads];
    NSDictionary *value = [controller tableView:table objectValueForTableColumn:nil row:0];
    Require([empty isHidden] && [[value objectForKey:@"show_progress"] boolValue] &&
        fabs([[value objectForKey:@"progress"] doubleValue]-0.5)<0.00001, "real controller presents paused5GB progress");
    Require([[[controller valueForKey:@"pauseButton"] title] isEqual:TGLoc(@"downloads.resume")], "paused row offers Resume");
    NSMutableDictionary *failed = [NSMutableDictionary dictionaryWithDictionary:Record(@"failed")];
    [failed setObject:@"Long synthetic error message" forKey:@"error"];
    SetRecords([NSArray arrayWithObject:failed]); [controller reloadDownloads];
    value = [controller tableView:table objectValueForTableColumn:nil row:0];
    Require(![[value objectForKey:@"show_progress"] boolValue] && [[value objectForKey:@"detail"] rangeOfString:@"synthetic error"].location!=NSNotFound,
        "failed row keeps error and stops progress drawing");
    [controller retryPressed:nil];
    Require([TGRetrySource isEqual:@"old-record"] && [table selectedRow]==0 &&
        [[[[controller valueForKey:@"downloads"] objectAtIndex:0] objectForKey:@"identifier"] isEqual:@"new-retry"],
        "actual controller retry preserves stable-identity API and selects returned record");
    [controller reloadDownloads]; Require([table selectedRow]==0, "later updates preserve retry selection");
    [TGRecords release]; TGRecords=nil; [TGRetrySource release]; TGRetrySource=nil;
    puts("Download manager presentation probe passed."); [pool drain]; return 0;
}
