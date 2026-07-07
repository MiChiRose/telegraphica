#import "TGStatusWindowController.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"

@interface TGStatusWindowController ()
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@end

@implementation TGStatusWindowController

@synthesize statusField = _statusField;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 560, 320);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [self buildContentView];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)buildContentView {
    NSView *contentView = [[self window] contentView];
    [contentView setAutoresizesSubviews:YES];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 268, 512, 28)
                                         text:@"Telegraphica core spike"
                                         font:[NSFont boldSystemFontOfSize:18.0]];
    [contentView addSubview:title];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 236, 512, 22)
                                       text:@"TDLib status: not checked"
                                       font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.statusField];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 78, 512, 142)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setString:@"Ready. Place libtdjson.dylib in Contents/Frameworks or set TELEGRAPHICA_TDJSON_PATH, then check the core.\n"];
    [scrollView setDocumentView:self.detailsView];
    [contentView addSubview:scrollView];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Check TDLib"];
    [self.checkButton setBezelStyle:NSRoundedBezelStyle];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    NSButton *quitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(176, 28, 96, 32)] autorelease];
    [quitButton setTitle:@"Quit"];
    [quitButton setBezelStyle:NSRoundedBezelStyle];
    [quitButton setTarget:NSApp];
    [quitButton setAction:@selector(terminate:)];
    [quitButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:quitButton];
}

- (void)appendDetail:(NSString *)detail {
    NSString *current = [self.detailsView string];
    NSString *line = [detail stringByAppendingString:@"\n"];
    [self.detailsView setString:[current stringByAppendingString:line]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    [self.checkButton setEnabled:NO];
    [self.statusField setStringValue:@"TDLib status: checking..."];
    [self appendDetail:@"Checking TDLib JSON interface..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        TGTDLibClient *client = [[[TGTDLibClient alloc] init] autorelease];
        NSError *error = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&error];
        NSString *authorizationState = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&error];
        }
        NSString *loadedPath = [client loadedLibraryPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (probeSummary) {
                [self.statusField setStringValue:@"TDLib status: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [error localizedDescription] ? [error localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
            } else {
                NSString *message = [error localizedDescription] ? [error localizedDescription] : @"Unknown TDLib error.";
                [self.statusField setStringValue:@"TDLib status: unavailable"];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
            [self.checkButton setEnabled:YES];
        });

        [pool drain];
    });
}

- (void)dealloc {
    [_statusField release];
    [_detailsView release];
    [_checkButton release];
    [super dealloc];
}

@end
