#import "TGStorageUsageWindowController.h"

#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"
#import "TGLocalization.h"
#import "TGTheme.h"

@interface TGStorageUsageWindowController ()

@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTextField *summaryField;
@property (nonatomic, retain) NSTextField *detailField;
@property (nonatomic, retain) NSButton *clearButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *closeButton;
@property (nonatomic, retain) NSProgressIndicator *progressIndicator;

@end

@implementation TGStorageUsageWindowController

@synthesize client = _client;
@synthesize summaryField = _summaryField;
@synthesize detailField = _detailField;
@synthesize clearButton = _clearButton;
@synthesize refreshButton = _refreshButton;
@synthesize closeButton = _closeButton;
@synthesize progressIndicator = _progressIndicator;

+ (NSString *)displayStringForBytes:(long long)bytes {
    double value = (double)bytes;
    NSArray *units = [NSArray arrayWithObjects:@"B", @"KB", @"MB", @"GB", nil];
    NSUInteger index = 0;
    while (value >= 1024.0 && index + 1 < [units count]) {
        value = value / 1024.0;
        index++;
    }
    if (index == 0) {
        return [NSString stringWithFormat:@"%lld %@", bytes, [units objectAtIndex:index]];
    }
    return [NSString stringWithFormat:@"%.1f %@", value, [units objectAtIndex:index]];
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setBordered:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setDrawsBackground:NO];
    [label setFont:font];
    [label setTextColor:TGClassicInkColor()];
    return label;
}

- (void)buildWindow {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 560, 360)
                                                   styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO] autorelease];
    [window setTitle:TGLoc(@"storage.title")];
    [window center];
    [self setWindow:window];

    NSView *contentView = [window contentView];
    [contentView setWantsLayer:YES];

    NSTextField *title = [self labelWithFrame:NSMakeRect(28, 302, 504, 30)
                                         font:[NSFont boldSystemFontOfSize:20.0]];
    [title setStringValue:TGLoc(@"storage.title")];
    [title setAlignment:NSCenterTextAlignment];
    [contentView addSubview:title];

    self.summaryField = [self labelWithFrame:NSMakeRect(44, 242, 472, 34)
                                        font:[NSFont boldSystemFontOfSize:22.0]];
    [self.summaryField setAlignment:NSCenterTextAlignment];
    [self.summaryField setStringValue:TGLoc(@"storage.loading")];
    [contentView addSubview:self.summaryField];

    self.detailField = [self labelWithFrame:NSMakeRect(54, 116, 452, 104)
                                       font:[NSFont systemFontOfSize:13.0]];
    [[self.detailField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.detailField setStringValue:@""];
    [contentView addSubview:self.detailField];

    self.progressIndicator = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(268, 226, 24, 24)] autorelease];
    [self.progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [self.progressIndicator setDisplayedWhenStopped:NO];
    [contentView addSubview:self.progressIndicator];

    self.clearButton = [[[NSButton alloc] initWithFrame:NSMakeRect(54, 46, 190, 32)] autorelease];
    [self.clearButton setTitle:TGLoc(@"storage.clear")];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearStorageCache:)];
    [contentView addSubview:self.clearButton];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(262, 46, 110, 32)] autorelease];
    [self.refreshButton setTitle:TGLoc(@"storage.refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshStorageUsage:)];
    [contentView addSubview:self.refreshButton];

    self.closeButton = [[[NSButton alloc] initWithFrame:NSMakeRect(392, 46, 110, 32)] autorelease];
    [self.closeButton setTitle:TGLoc(@"close")];
    [self.closeButton setTarget:self];
    [self.closeButton setAction:@selector(closeWindow:)];
    [contentView addSubview:self.closeButton];
}

- (id)initWithClient:(TGTDLibClient *)client {
    self = [super initWithWindow:nil];
    if (self) {
        _client = [client retain];
        [self buildWindow];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_summaryField release];
    [_detailField release];
    [_clearButton release];
    [_refreshButton release];
    [_closeButton release];
    [_progressIndicator release];
    [super dealloc];
}

- (void)setBusy:(BOOL)busy {
    [self.clearButton setEnabled:!busy];
    [self.refreshButton setEnabled:!busy];
    if (busy) {
        [self.progressIndicator startAnimation:nil];
    } else {
        [self.progressIndicator stopAnimation:nil];
    }
}

- (void)applyStorageSummary:(NSDictionary *)summary {
    long long total = [[summary objectForKey:@"total_size"] longLongValue];
    long long files = [[summary objectForKey:@"files_size"] longLongValue];
    long long database = [[summary objectForKey:@"database_size"] longLongValue];
    long long language = [[summary objectForKey:@"language_pack_database_size"] longLongValue];
    long long logs = [[summary objectForKey:@"log_size"] longLongValue];

    [self.summaryField setStringValue:[NSString stringWithFormat:TGLoc(@"storage.total"),
                                       [[self class] displayStringForBytes:total]]];
    NSString *details = [NSString stringWithFormat:@"%@: %@\n%@: %@\n%@: %@\n%@: %@\n\n%@",
                         TGLoc(@"storage.files"),
                         [[self class] displayStringForBytes:files],
                         TGLoc(@"storage.database"),
                         [[self class] displayStringForBytes:database],
                         TGLoc(@"storage.language"),
                         [[self class] displayStringForBytes:language],
                         TGLoc(@"storage.logs"),
                         [[self class] displayStringForBytes:logs],
                         TGLoc(@"storage.safeHint")];
    [self.detailField setStringValue:details];
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [[self window] makeKeyAndOrderFront:sender];
    [self refreshStorageUsage:sender];
}

- (void)refreshStorageUsage:(id)sender {
    (void)sender;
    [self setBusy:YES];
    [self.summaryField setStringValue:TGLoc(@"storage.loading")];
    [self.detailField setStringValue:@""];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client storageUsageSummaryWithTimeout:8.0 error:&error] retain];
        NSString *errorText = [[error localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if (summary) {
                [self applyStorageSummary:summary];
            } else {
                [self.summaryField setStringValue:TGLoc(@"storage.unavailable")];
                [self.detailField setStringValue:([errorText length] > 0 ? errorText : TGLoc(@"settings.sessions.unknownError"))];
            }
            [summary release];
            [errorText release];
            [client release];
        });
        [pool drain];
    });
}

- (void)clearStorageCache:(id)sender {
    (void)sender;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"storage.confirm.title")];
    [alert setInformativeText:TGLoc(@"storage.confirm.message")];
    [alert addButtonWithTitle:TGLoc(@"storage.clear")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        return;
    }

    [self setBusy:YES];
    [self.summaryField setStringValue:TGLoc(@"storage.clearing")];
    [self.detailField setStringValue:@""];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client clearDownloadedMediaCacheWithTimeout:15.0 error:&error] retain];
        NSString *errorText = [[error localizedDescription] copy];
        if (summary) {
            [[TGLogger sharedLogger] log:@"Storage cache cleanup completed."];
        } else {
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Storage cache cleanup failed: %@", errorText ? errorText : @"unknown error"]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if (summary) {
                [self applyStorageSummary:summary];
            } else {
                [self.summaryField setStringValue:TGLoc(@"storage.clearFailed")];
                [self.detailField setStringValue:([errorText length] > 0 ? errorText : TGLoc(@"settings.sessions.unknownError"))];
            }
            [summary release];
            [errorText release];
            [client release];
        });
        [pool drain];
    });
}

- (void)closeWindow:(id)sender {
    [[self window] orderOut:sender];
}

@end
