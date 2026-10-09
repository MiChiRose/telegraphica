#import "TGDownloadManagerWindowController.h"

#import "../Media/TGMediaFileActions.h"
#import "../Services/TGDownloadManager.h"
#import "TGDownloadManagerPresentation.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGDownloadManagerWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSButton *cancelButton;
@property (nonatomic, retain) NSButton *pauseButton;
@property (nonatomic, retain) NSButton *retryButton;
@property (nonatomic, retain) NSButton *revealButton;
@property (nonatomic, retain) NSButton *clearButton;
@property (nonatomic, copy) NSArray *downloads;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *subtitleField;
@property (nonatomic, retain) NSTextField *emptyField;
@property (nonatomic, retain) NSView *headerView;
@property (nonatomic, retain) NSView *listSurface;
@property (nonatomic, retain) NSView *footerView;
@property (nonatomic, retain) NSScrollView *scrollView;
@end

@implementation TGDownloadManagerWindowController

@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize cancelButton = _cancelButton;
@synthesize pauseButton = _pauseButton;
@synthesize retryButton = _retryButton;
@synthesize revealButton = _revealButton;
@synthesize clearButton = _clearButton;
@synthesize downloads = _downloads;
@synthesize titleField = _titleField, subtitleField = _subtitleField, emptyField = _emptyField;
@synthesize headerView = _headerView;
@synthesize listSurface = _listSurface, footerView = _footerView, scrollView = _scrollView;

- (id)init {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 740, 540)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.downloads = [NSArray array];
        [[self window] setTitle:TGLoc(@"downloads.title")];
        [[self window] setContentMinSize:NSMakeSize(620.0, 460.0)];
        [[self window] setContentMaxSize:NSMakeSize(1000.0, 760.0)];
        [[self window] setReleasedWhenClosed:NO];
        [[self window] setDelegate:self];
        [self buildViews];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadManagerChanged:)
                                                     name:TGDownloadManagerDidChangeNotification
                                                   object:[TGDownloadManager sharedManager]];
    }
    return self;
}

- (void)dealloc {
    [[self window] setDelegate:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_tableView release];
    [_statusField release];
    [_cancelButton release];
    [_pauseButton release];
    [_retryButton release];
    [_revealButton release];
    [_clearButton release];
    [_downloads release];
    [_titleField release]; [_subtitleField release]; [_emptyField release];
    [_headerView release]; [_listSurface release]; [_footerView release]; [_scrollView release];
    [super dealloc];
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
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

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    NSButtonCell *cell = primary
        ? (NSButtonCell *)[[[TGPrimaryTextButtonCell alloc] initTextCell:title] autorelease]
        : (NSButtonCell *)[[[TGSecondaryTextButtonCell alloc] initTextCell:title] autorelease];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)layoutDownloadViews {
    TGDownloadManagerLayout f = TGDownloadManagerLayoutForSize([[[self window] contentView] bounds].size);
    [self.headerView setFrame:f.header];
    [self.titleField setFrame:f.title]; [self.subtitleField setFrame:f.subtitle];
    [self.listSurface setFrame:f.surface]; [self.scrollView setFrame:f.list];
    [self.footerView setFrame:f.footer]; [self.emptyField setFrame:f.empty];
    [self.pauseButton setFrame:f.pause]; [self.cancelButton setFrame:f.cancel];
    [self.retryButton setFrame:f.retry]; [self.revealButton setFrame:f.reveal];
    [self.clearButton setFrame:f.clear]; [self.statusField setFrame:f.summary];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutDownloadViews];
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];
    self.headerView = [[[TGDownloadManagerSurfaceView alloc] initWithFrame:NSZeroRect] autorelease];
    [root addSubview:self.headerView];
    self.titleField = [self labelWithFrame:NSZeroRect font:[NSFont boldSystemFontOfSize:20] color:TGClassicHeaderTextColor(1)];
    [self.titleField setStringValue:TGLoc(@"downloads.title")];
    self.subtitleField = [self labelWithFrame:NSZeroRect font:[NSFont systemFontOfSize:11] color:TGClassicHeaderTextColor(1)];
    [self.subtitleField setStringValue:TGLoc(@"downloads.help")];
    [root addSubview:self.titleField]; [root addSubview:self.subtitleField];
    self.listSurface = [[[TGScrollSurfaceView alloc] initWithFrame:NSZeroRect] autorelease];
    self.footerView = [[[TGDownloadManagerSurfaceView alloc] initWithFrame:NSZeroRect] autorelease];
    [root addSubview:self.listSurface]; [root addSubview:self.footerView];
    self.scrollView = [[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
    [self.scrollView setHasVerticalScroller:YES]; [self.scrollView setAutohidesScrollers:YES];
    [self.scrollView setBorderType:NSNoBorder]; [self.scrollView setDrawsBackground:NO];
    self.tableView = [[[NSTableView alloc] initWithFrame:NSZeroRect] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"download"] autorelease];
    [column setWidth:660]; [column setResizingMask:NSTableColumnAutoresizingMask];
    [column setDataCell:[[[TGDownloadListCell alloc] initTextCell:@""] autorelease]];
    [self.tableView addTableColumn:column]; [self.tableView setColumnAutoresizingStyle:NSTableViewUniformColumnAutoresizingStyle];
    [self.tableView setHeaderView:nil]; [self.tableView setRowHeight:72];
    [self.tableView setIntercellSpacing:NSMakeSize(0, 0)]; [self.tableView setGridStyleMask:NSTableViewGridNone];
    [self.tableView setBackgroundColor:TGClassicTablePaperColor()];
    [self.tableView setAllowsEmptySelection:YES]; [self.tableView setAllowsMultipleSelection:NO];
    [self.tableView setDelegate:self]; [self.tableView setDataSource:self];
    [self.scrollView setDocumentView:self.tableView]; [root addSubview:self.scrollView];
    self.emptyField = [self labelWithFrame:NSZeroRect font:[NSFont systemFontOfSize:13]
        color:TGDownloadManagerReadableInk(TGClassicCardMutedInkColor(), TGClassicTablePaperColor())];
    [self.emptyField setAlignment:NSCenterTextAlignment]; [self.emptyField setStringValue:TGLoc(@"downloads.empty")];
    [root addSubview:self.emptyField];
    self.pauseButton = [self buttonWithFrame:NSZeroRect title:TGLoc(@"downloads.pause") action:@selector(pauseResumePressed:) primary:YES];
    self.cancelButton = [self buttonWithFrame:NSZeroRect title:TGLoc(@"downloads.cancel") action:@selector(cancelPressed:) primary:NO];
    self.retryButton = [self buttonWithFrame:NSZeroRect title:TGLoc(@"downloads.retry") action:@selector(retryPressed:) primary:NO];
    self.revealButton = [self buttonWithFrame:NSZeroRect title:TGLoc(@"downloads.reveal") action:@selector(revealPressed:) primary:NO];
    self.clearButton = [self buttonWithFrame:NSZeroRect title:TGLoc(@"downloads.clear") action:@selector(clearPressed:) primary:NO];
    for (NSButton *button in [NSArray arrayWithObjects:self.pauseButton, self.cancelButton, self.retryButton, self.revealButton, self.clearButton, nil]) {
        [button setToolTip:[button title]]; [root addSubview:button];
    }
    self.statusField = [self labelWithFrame:NSZeroRect font:[NSFont systemFontOfSize:11] color:TGClassicCardInkColor()];
    [root addSubview:self.statusField];
    [self.tableView setNextKeyView:self.pauseButton]; [self.pauseButton setNextKeyView:self.cancelButton];
    [self.cancelButton setNextKeyView:self.retryButton]; [self.retryButton setNextKeyView:self.revealButton];
    [self.revealButton setNextKeyView:self.clearButton]; [self.clearButton setNextKeyView:self.tableView];
    [[self window] setInitialFirstResponder:self.tableView];
    [self refreshPresentation]; [self reloadDownloads];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.downloads count];
}

- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    (void)tableView;
    (void)tableColumn;
    if (row < 0 || (NSUInteger)row >= [self.downloads count]) {
        return @"";
    }
    NSDictionary *item = [self.downloads objectAtIndex:(NSUInteger)row];
    NSString *state = [item objectForKey:@"state"];
    NSString *safeState = [state length] > 0 ? state : @"failed";
    NSString *stateText = TGLoc([@"downloads.state." stringByAppendingString:safeState]);
    if ([safeState isEqualToString:@"downloading"] || [safeState isEqualToString:@"paused"]) {
        if ([safeState isEqualToString:@"downloading"] && [[item objectForKey:@"reconnecting"] boolValue]) {
            stateText = TGLoc(@"downloads.waitingNetwork");
        }
        long long downloaded = MAX(0LL, [[item objectForKey:@"downloaded_bytes"] longLongValue]);
        long long total = MAX(0LL, [[item objectForKey:@"total_bytes"] longLongValue]);
        NSString *bytes = TGDownloadManagerByteCount(downloaded);
        if (total > 0) {
            stateText = [NSString stringWithFormat:@"%@ · %@ / %@", stateText, bytes,
                         TGDownloadManagerByteCount(total)];
        } else if (downloaded > 0) {
            stateText = [NSString stringWithFormat:@"%@ · %@", stateText, bytes];
        }
    }
    NSString *detail = [item objectForKey:@"error"];
    if ([detail length] == 0) {
        detail = [item objectForKey:@"saved_path"];
    }
    if ([detail length] == 0) {
        detail = stateText;
    } else {
        detail = [NSString stringWithFormat:@"%@ · %@", stateText, detail];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            ([item objectForKey:@"file_name"] ? [item objectForKey:@"file_name"] : @""), @"title",
            (detail ? detail : @""), @"detail",
            [NSNumber numberWithBool:[safeState isEqualToString:@"downloading"] || [safeState isEqualToString:@"paused"]], @"show_progress",
            [NSNumber numberWithDouble:([[item objectForKey:@"total_bytes"] longLongValue] > 0
                ? (double)[[item objectForKey:@"downloaded_bytes"] longLongValue] / (double)[[item objectForKey:@"total_bytes"] longLongValue] : 0)], @"progress",
            nil];
}

- (void)tableView:(NSTableView *)tableView
   willDisplayCell:(id)cell
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
    (void)tableColumn;
    if (tableView == self.tableView && [cell isKindOfClass:[TGDownloadListCell class]]) {
        [(TGDownloadListCell *)cell setHighlighted:[tableView isRowSelected:row]];
    }
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect
             tableColumn:(NSTableColumn *)column row:(NSInteger)row mouseLocation:(NSPoint)point {
    (void)cell; (void)rect; (void)point;
    NSDictionary *value = [self tableView:tableView objectValueForTableColumn:column row:row];
    return [value isKindOfClass:[NSDictionary class]] ? [NSString stringWithFormat:@"%@\n%@", [value objectForKey:@"title"], [value objectForKey:@"detail"]] : nil;
}

- (NSDictionary *)selectedDownload {
    NSInteger row = [self.tableView selectedRow];
    return (row >= 0 && (NSUInteger)row < [self.downloads count])
        ? [self.downloads objectAtIndex:(NSUInteger)row]
        : nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (void)updateControls {
    NSDictionary *item = [self selectedDownload];
    NSString *state = [item objectForKey:@"state"];
    BOOL paused = [state isEqualToString:@"paused"];
    [self.pauseButton setTitle:TGLoc(paused ? @"downloads.resume" : @"downloads.pause")];
    [self.pauseButton setToolTip:[self.pauseButton title]];
    [self.pauseButton setEnabled:[[item objectForKey:(paused ? @"can_resume" : @"can_pause")] boolValue]];
    [self.cancelButton setEnabled:[[item objectForKey:@"can_cancel"] boolValue]];
    [self.retryButton setEnabled:([state isEqualToString:@"failed"] || [state isEqualToString:@"cancelled"])];
    [self.revealButton setEnabled:[[item objectForKey:@"saved_path"] length] > 0];
    BOOL hasFinished = NO;
    for (NSDictionary *record in self.downloads) {
        NSString *value = [record objectForKey:@"state"];
        if ([value isEqualToString:@"completed"] || [value isEqualToString:@"failed"] || [value isEqualToString:@"cancelled"]) { hasFinished = YES; break; }
    }
    [self.clearButton setEnabled:hasFinished];
}

- (void)refreshPresentation {
    NSColor *paper = TGClassicTablePaperColor();
    NSColor *ink = TGDownloadManagerReadableInk(TGClassicCardInkColor(), paper);
    NSColor *muted = TGDownloadManagerReadableInk(TGClassicCardMutedInkColor(), paper);
    [[self window] setTitle:TGLoc(@"downloads.title")];
    [self.titleField setStringValue:TGLoc(@"downloads.title")];
    [self.subtitleField setStringValue:TGLoc(@"downloads.help")];
    [self.emptyField setStringValue:TGLoc(@"downloads.empty")];
    [self.titleField setTextColor:ink]; [self.subtitleField setTextColor:muted];
    [self.statusField setTextColor:muted]; [self.emptyField setTextColor:muted];
    [self.tableView setBackgroundColor:paper];
    NSArray *buttons = [NSArray arrayWithObjects:self.cancelButton, self.retryButton, self.revealButton, self.clearButton, nil];
    NSArray *keys = [NSArray arrayWithObjects:@"downloads.cancel", @"downloads.retry", @"downloads.reveal", @"downloads.clear", nil];
    for (NSUInteger i = 0; i < [buttons count]; i++) {
        NSButton *button = [buttons objectAtIndex:i];
        [button setTitle:TGLoc([keys objectAtIndex:i])]; [button setToolTip:[button title]];
    }
    [self.headerView setNeedsDisplay:YES]; [self.footerView setNeedsDisplay:YES];
    [[self.window contentView] setNeedsDisplay:YES]; [self.tableView setNeedsDisplay:YES];
    [self reloadDownloads]; [self layoutDownloadViews];
}

- (void)showWindow:(id)sender {
    [self refreshPresentation];
    [super showWindow:sender];
}

- (void)reloadDownloads {
    NSString *selectedID = [[[self selectedDownload] objectForKey:@"identifier"] copy];
    self.downloads = [[TGDownloadManager sharedManager] itemsSnapshot];
    [self.tableView reloadData];
    [self.emptyField setHidden:[self.downloads count] > 0];
    NSInteger selection = -1, activeSelection = -1;
    for (NSUInteger index = 0; index < [self.downloads count]; index++) {
        NSDictionary *item = [self.downloads objectAtIndex:index];
        if ([[item objectForKey:@"identifier"] isEqualToString:selectedID]) { selection = (NSInteger)index; }
        if (activeSelection < 0 && [[item objectForKey:@"can_cancel"] boolValue]) { activeSelection = (NSInteger)index; }
    }
    if (selection < 0) { selection = activeSelection; }
    if (selection < 0 && [self.downloads count] > 0) { selection = 0; }
    if (selection >= 0) {
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selection] byExtendingSelection:NO];
    }
    [selectedID release];
    [self.statusField setStringValue:[self.downloads count] > 0
        ? [NSString stringWithFormat:TGLoc(@"downloads.count"), (unsigned long)[self.downloads count]]
        : TGLoc(@"downloads.empty")];
    [self updateControls];
}

- (void)downloadManagerChanged:(NSNotification *)notification {
    (void)notification;
    [self reloadDownloads];
}

- (void)pauseResumePressed:(id)sender {
    (void)sender;
    NSDictionary *item = [self selectedDownload];
    NSString *identifier = [item objectForKey:@"identifier"];
    if ([[item objectForKey:@"state"] isEqualToString:@"paused"]) {
        [[TGDownloadManager sharedManager] resumeDownloadWithIdentifier:identifier completion:nil];
    } else {
        [[TGDownloadManager sharedManager] pauseDownloadWithIdentifier:identifier];
    }
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    [[TGDownloadManager sharedManager] cancelDownloadWithIdentifier:[[self selectedDownload] objectForKey:@"identifier"]];
}

- (void)retryPressed:(id)sender {
    (void)sender;
    NSDictionary *item = [self selectedDownload];
    NSString *state = [item objectForKey:@"state"];
    if (![state isEqualToString:@"failed"] && ![state isEqualToString:@"cancelled"]) { return; }
    NSString *identifier = [[[TGDownloadManager sharedManager]
                            enqueueRetryDownloadWithIdentifier:[item objectForKey:@"identifier"]
                            completion:nil] copy];
    [self reloadDownloads];
    for (NSUInteger index = 0; index < [self.downloads count]; index++) {
        if ([[[self.downloads objectAtIndex:index] objectForKey:@"identifier"] isEqualToString:identifier]) {
            [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
            break;
        }
    }
    [identifier release];
    [self updateControls];
}

- (void)revealPressed:(id)sender {
    (void)sender;
    if (![TGMediaFileActions revealFileAtPath:[[self selectedDownload] objectForKey:@"saved_path"]]) {
        [self.statusField setStringValue:TGLoc(@"downloads.revealFailed")];
    }
}

- (void)clearPressed:(id)sender {
    (void)sender;
    [[TGDownloadManager sharedManager] clearFinishedDownloads];
}

@end
