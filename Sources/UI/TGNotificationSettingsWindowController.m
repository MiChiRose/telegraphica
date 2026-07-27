#import "TGNotificationSettingsWindowController.h"

#import "../Core/TGTDLibClient+Notifications.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGNotificationSettingsWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextField *selectionField;
@property (nonatomic, retain) NSPopUpButton *mutePopUpButton;
@property (nonatomic, retain) NSButton *previewButton;
@property (nonatomic, retain) NSButton *applyButton;
@property (nonatomic, retain) NSButton *resetButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSArray *exceptions;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGNotificationSettingsWindowController

@synthesize client = _client;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize selectionField = _selectionField;
@synthesize mutePopUpButton = _mutePopUpButton;
@synthesize previewButton = _previewButton;
@synthesize applyButton = _applyButton;
@synthesize resetButton = _resetButton;
@synthesize refreshButton = _refreshButton;
@synthesize spinner = _spinner;
@synthesize exceptions = _exceptions;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 660, 500)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.exceptions = [NSArray array];
        [[self window] setTitle:TGLoc(@"notifications.exceptions.title")];
        [[self window] setMinSize:NSMakeSize(600.0, 460.0)];
        [[self window] setMaxSize:NSMakeSize(860.0, 680.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_tableView release];
    [_statusField release];
    [_selectionField release];
    [_mutePopUpButton release];
    [_previewButton release];
    [_applyButton release];
    [_resetButton release];
    [_refreshButton release];
    [_spinner release];
    [_exceptions release];
    [super dealloc];
}

- (NSTextField *)labelWithFrame:(NSRect)frame
                           font:(NSFont *)font
                          color:(NSColor *)color {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:color];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return field;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 452, 470, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"notifications.exceptions.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24, 432, 560, 18)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderTextColor(0.82)];
    [subtitle setStringValue:TGLoc(@"notifications.exceptions.help")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(548, 438, 88, 30)] autorelease];
    [self.refreshButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"refresh")] autorelease]];
    [self.refreshButton setTitle:TGLoc(@"refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshPressed:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *listCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 58, 270, 354)] autorelease];
    [listCard setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:listCard];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 88, 250, 312)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDrawsBackground:NO];
    [scrollView setAutoresizingMask:NSViewHeightSizable];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [column setWidth:240.0];
    [[column headerCell] setStringValue:TGLoc(@"notifications.exceptions.chats")];
    [self.tableView addTableColumn:column];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:32.0];
    [self.tableView setAllowsEmptySelection:YES];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [scrollView setDocumentView:self.tableView];
    [root addSubview:scrollView];

    self.statusField = [self labelWithFrame:NSMakeRect(32, 68, 246, 16)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicCardMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"notifications.exceptions.loading")];
    [self.statusField setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(260, 66, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.spinner];

    TGGroupedCardView *editorCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(302, 58, 338, 354)] autorelease];
    [editorCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:editorCard];

    self.selectionField = [self labelWithFrame:NSMakeRect(324, 362, 294, 30)
                                          font:[NSFont boldSystemFontOfSize:14.0]
                                         color:TGClassicCardInkColor()];
    [self.selectionField setStringValue:TGLoc(@"notifications.exceptions.select")];
    [self.selectionField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.selectionField];

    NSTextField *muteLabel = [self labelWithFrame:NSMakeRect(324, 314, 130, 20)
                                             font:[NSFont systemFontOfSize:12.0]
                                            color:TGClassicCardInkColor()];
    [muteLabel setStringValue:TGLoc(@"notifications.exceptions.mute")];
    [muteLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:muteLabel];

    self.mutePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(452, 308, 164, 28) pullsDown:NO] autorelease];
    [self.mutePopUpButton addItemWithTitle:TGLoc(@"notifications.exceptions.on")];
    [self.mutePopUpButton addItemWithTitle:TGLoc(@"notifications.mute.hour")];
    [self.mutePopUpButton addItemWithTitle:TGLoc(@"notifications.mute.eightHours")];
    [self.mutePopUpButton addItemWithTitle:TGLoc(@"notifications.mute.day")];
    [self.mutePopUpButton addItemWithTitle:TGLoc(@"notifications.mute.forever")];
    [self.mutePopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.mutePopUpButton];

    self.previewButton = [[[NSButton alloc] initWithFrame:NSMakeRect(324, 270, 280, 22)] autorelease];
    [self.previewButton setButtonType:NSSwitchButton];
    [self.previewButton setTitle:TGLoc(@"notifications.exceptions.preview")];
    [self.previewButton setFont:[NSFont systemFontOfSize:12.0]];
    [self.previewButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.previewButton];

    NSTextField *hint = [self labelWithFrame:NSMakeRect(324, 172, 292, 78)
                                        font:[NSFont systemFontOfSize:11.0]
                                       color:TGClassicCardMutedInkColor()];
    [hint setStringValue:TGLoc(@"notifications.exceptions.editorHelp")];
    [[hint cell] setWraps:YES];
    [[hint cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [hint setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:hint];

    self.resetButton = [[[NSButton alloc] initWithFrame:NSMakeRect(324, 84, 132, 30)] autorelease];
    [self.resetButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"notifications.exceptions.reset")] autorelease]];
    [self.resetButton setTitle:TGLoc(@"notifications.exceptions.reset")];
    [self.resetButton setTarget:self];
    [self.resetButton setAction:@selector(resetPressed:)];
    [self.resetButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.resetButton];

    self.applyButton = [[[NSButton alloc] initWithFrame:NSMakeRect(468, 84, 148, 30)] autorelease];
    [self.applyButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applyButton setTitle:TGLoc(@"apply")];
    [self.applyButton setTarget:self];
    [self.applyButton setAction:@selector(applyPressed:)];
    [self.applyButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.applyButton];

    [self updateEditorAvailability];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.exceptions count];
}

- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    (void)tableView;
    (void)tableColumn;
    if (row < 0 || (NSUInteger)row >= [self.exceptions count]) {
        return @"";
    }
    NSDictionary *summary = [self.exceptions objectAtIndex:(NSUInteger)row];
    NSString *title = [[summary objectForKey:@"title"] isKindOfClass:[NSString class]]
        ? [summary objectForKey:@"title"]
        : @"";
    return [title length] > 0 ? title : TGLoc(@"chat.untitled");
}

- (NSDictionary *)selectedSummary {
    NSInteger row = [self.tableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.exceptions count]) {
        return nil;
    }
    return [self.exceptions objectAtIndex:(NSUInteger)row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    NSDictionary *summary = [self selectedSummary];
    if (summary) {
        NSString *title = [summary objectForKey:@"title"];
        [self.selectionField setStringValue:[title length] > 0 ? title : TGLoc(@"chat.untitled")];
        [self.mutePopUpButton selectItemAtIndex:[[summary objectForKey:@"muted"] boolValue] ? 4 : 0];
        [self.previewButton setState:[[summary objectForKey:@"show_preview"] boolValue] ? NSOnState : NSOffState];
    } else {
        [self.selectionField setStringValue:TGLoc(@"notifications.exceptions.select")];
    }
    [self updateEditorAvailability];
}

- (void)updateEditorAvailability {
    BOOL enabled = (!self.loading && [self selectedSummary] != nil);
    [self.mutePopUpButton setEnabled:enabled];
    [self.previewButton setEnabled:enabled];
    [self.applyButton setEnabled:enabled];
    [self.resetButton setEnabled:enabled];
    [self.refreshButton setEnabled:!self.loading];
}

- (void)setLoading:(BOOL)loading status:(NSString *)status {
    self.loading = loading;
    [self.statusField setStringValue:status ? status : @""];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
    [self updateEditorAvailability];
}

- (void)reloadExceptions {
    if (self.loading) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"notifications.exceptions.loading")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSArray *values = [self.client chatNotificationExceptionSummariesWithTimeout:8.0 error:&error];
        NSArray *result = values ? [[NSArray alloc] initWithArray:values] : nil;
        NSString *detail = error ? [[error localizedDescription] copy] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.exceptions = result ? result : [NSArray array];
                [self.tableView reloadData];
                [self.tableView deselectAll:nil];
                NSString *status = detail;
                if (!status) {
                    status = [self.exceptions count] > 0
                        ? [NSString stringWithFormat:TGLoc(@"notifications.exceptions.count"), (unsigned long)[self.exceptions count]]
                        : TGLoc(@"notifications.exceptions.empty");
                }
                [self setLoading:NO status:status];
                [self tableViewSelectionDidChange:nil];
            }
            [result release];
            [detail release];
        });
        [pool drain];
    });
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadExceptions];
}

- (NSTimeInterval)selectedMuteDuration {
    switch ([self.mutePopUpButton indexOfSelectedItem]) {
        case 1: return 60.0 * 60.0;
        case 2: return 8.0 * 60.0 * 60.0;
        case 3: return 24.0 * 60.0 * 60.0;
        case 4: return -1.0;
        default: return 0.0;
    }
}

- (void)applyPressed:(id)sender {
    (void)sender;
    NSDictionary *summary = [self selectedSummary];
    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    if (!chatID || self.loading) {
        return;
    }
    NSTimeInterval muteFor = [self selectedMuteDuration];
    BOOL preview = ([self.previewButton state] == NSOnState);
    [self setLoading:YES status:TGLoc(@"notifications.exceptions.saving")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [self.client setChatNotificationMuteForChatID:chatID muteFor:muteFor timeout:8.0 error:&error];
        if (success) {
            success = [self.client setChatNotificationPreviewForChatID:chatID showPreview:preview timeout:8.0 error:&error];
        }
        NSString *detail = error ? [[error localizedDescription] copy] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"notifications.exceptions.saved") : (detail ? detail : TGLoc(@"notifications.exceptions.failed"))];
            if (success) {
                [self reloadExceptions];
            }
            [detail release];
        });
        [pool drain];
    });
}

- (void)resetPressed:(id)sender {
    (void)sender;
    NSDictionary *summary = [self selectedSummary];
    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    if (!chatID || self.loading) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"notifications.exceptions.saving")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [self.client resetChatNotificationSettingsForChatID:chatID timeout:8.0 error:&error];
        NSString *detail = error ? [[error localizedDescription] copy] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"notifications.exceptions.saved") : (detail ? detail : TGLoc(@"notifications.exceptions.failed"))];
            if (success) {
                [self reloadExceptions];
            }
            [detail release];
        });
        [pool drain];
    });
}

@end
