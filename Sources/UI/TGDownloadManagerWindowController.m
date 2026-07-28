#import "TGDownloadManagerWindowController.h"

#import "../Media/TGMediaFileActions.h"
#import "../Services/TGDownloadManager.h"
#import "TGIconAssets.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGDownloadListCell : TGRepresentedObjectCell
@end

@implementation TGDownloadListCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *item = [self.representedObject isKindOfClass:[NSDictionary class]]
        ? (NSDictionary *)self.representedObject : nil;
    if (!item) {
        return;
    }
    BOOL selected = [self isHighlighted];
    NSRect cardRect = NSInsetRect(cellFrame, 3.0, 3.0);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:10.0 yRadius:10.0];
    if (selected) {
        [TGClassicSelectedRowColor() set];
        [cardPath fill];
    } else {
        TGThemeDrawGroupedCardInPath(cardPath, cardRect, [controlView isFlipped]);
    }
    [TGClassicTableGridColor() set];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];

    NSColor *titleColor = selected ? TGClassicSelectedRowTextColor() : TGClassicCardInkColor();
    NSColor *detailColor = selected ? [TGClassicSelectedRowTextColor() colorWithAlphaComponent:0.76]
                                    : TGClassicCardMutedInkColor();
    NSRect iconRect = NSMakeRect(NSMinX(cardRect) + 10.0, NSMinY(cardRect) + 11.0, 28.0, 28.0);
    TGDrawTemplateIconAsset(@"document", iconRect, titleColor, 0.9, [controlView isFlipped]);

    CGFloat textX = NSMaxX(iconRect) + 10.0;
    CGFloat textWidth = MAX(0.0, NSMaxX(cardRect) - textX - 12.0);
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByTruncatingMiddle];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     titleColor, NSForegroundColorAttributeName,
                                     paragraph, NSParagraphStyleAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:10.0], NSFontAttributeName,
                                      detailColor, NSForegroundColorAttributeName,
                                      paragraph, NSParagraphStyleAttributeName,
                                      nil];
    [[item objectForKey:@"title"] drawInRect:NSMakeRect(textX, NSMinY(cardRect) + 8.0, textWidth, 16.0)
                              withAttributes:titleAttributes];
    [[item objectForKey:@"detail"] drawInRect:NSMakeRect(textX, NSMinY(cardRect) + 29.0, textWidth, 14.0)
                               withAttributes:detailAttributes];
}

@end

@interface TGDownloadManagerWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSButton *cancelButton;
@property (nonatomic, retain) NSButton *retryButton;
@property (nonatomic, retain) NSButton *revealButton;
@property (nonatomic, retain) NSButton *clearButton;
@property (nonatomic, copy) NSArray *downloads;
@end

@implementation TGDownloadManagerWindowController

@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize cancelButton = _cancelButton;
@synthesize retryButton = _retryButton;
@synthesize revealButton = _revealButton;
@synthesize clearButton = _clearButton;
@synthesize downloads = _downloads;

- (id)init {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 680, 500)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.downloads = [NSArray array];
        [[self window] setTitle:TGLoc(@"downloads.title")];
        [[self window] setMinSize:NSMakeSize(620.0, 440.0)];
        [[self window] setMaxSize:NSMakeSize(920.0, 720.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(downloadManagerChanged:)
                                                     name:TGDownloadManagerDidChangeNotification
                                                   object:[TGDownloadManager sharedManager]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_tableView release];
    [_statusField release];
    [_cancelButton release];
    [_retryButton release];
    [_revealButton release];
    [_clearButton release];
    [_downloads release];
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

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    TGUtilityPanelView *panel = [[[TGUtilityPanelView alloc] initWithFrame:NSMakeRect(12, 48, 656, 376)] autorelease];
    [panel setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:panel];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 452, 500, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"downloads.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24, 432, 610, 18)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderTextColor(0.82)];
    [subtitle setStringValue:TGLoc(@"downloads.help")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];

    TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 62, 640, 350)] autorelease];
    [card setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:card];
    TGScrollSurfaceView *tableSurface = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(28, 118, 624, 286)] autorelease];
    [tableSurface setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:tableSurface];
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(32, 122, 616, 278)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSNoBorder];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"download"] autorelease];
    [column setWidth:604.0];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [self.tableView addTableColumn:column];
    [column setDataCell:[[[TGDownloadListCell alloc] initTextCell:@""] autorelease]];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:58.0];
    [self.tableView setIntercellSpacing:NSMakeSize(0.0, 0.0)];
    [self.tableView setGridStyleMask:NSTableViewGridNone];
    [self.tableView setBackgroundColor:[NSColor clearColor]];
    [self.tableView setAllowsEmptySelection:YES];
    [self.tableView setDelegate:self];
    [self.tableView setDataSource:self];
    [scroll setDocumentView:self.tableView];
    [root addSubview:scroll];

    self.cancelButton = [self buttonWithFrame:NSMakeRect(32, 78, 112, 30)
                                        title:TGLoc(@"downloads.cancel")
                                       action:@selector(cancelPressed:)
                                      primary:NO];
    self.retryButton = [self buttonWithFrame:NSMakeRect(152, 78, 112, 30)
                                       title:TGLoc(@"downloads.retry")
                                      action:@selector(retryPressed:)
                                     primary:YES];
    self.revealButton = [self buttonWithFrame:NSMakeRect(272, 78, 132, 30)
                                        title:TGLoc(@"downloads.reveal")
                                       action:@selector(revealPressed:)
                                      primary:NO];
    self.clearButton = [self buttonWithFrame:NSMakeRect(500, 78, 148, 30)
                                       title:TGLoc(@"downloads.clear")
                                      action:@selector(clearPressed:)
                                     primary:NO];
    [self.clearButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.cancelButton];
    [root addSubview:self.retryButton];
    [root addSubview:self.revealButton];
    [root addSubview:self.clearButton];

    self.statusField = [self labelWithFrame:NSMakeRect(32, 42, 616, 16)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicCardMutedInkColor()];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    [self reloadDownloads];
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
    [self.cancelButton setEnabled:([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"])];
    [self.retryButton setEnabled:([state isEqualToString:@"failed"] || [state isEqualToString:@"cancelled"])];
    [self.revealButton setEnabled:[[item objectForKey:@"saved_path"] length] > 0];
    [self.clearButton setEnabled:[self.downloads count] > 0];
}

- (void)reloadDownloads {
    self.downloads = [[TGDownloadManager sharedManager] itemsSnapshot];
    [self.tableView reloadData];
    [self.statusField setStringValue:[self.downloads count] > 0
        ? [NSString stringWithFormat:TGLoc(@"downloads.count"), (unsigned long)[self.downloads count]]
        : TGLoc(@"downloads.empty")];
    [self updateControls];
}

- (void)downloadManagerChanged:(NSNotification *)notification {
    (void)notification;
    [self reloadDownloads];
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    [[TGDownloadManager sharedManager] cancelDownloadWithIdentifier:[[self selectedDownload] objectForKey:@"identifier"]];
}

- (void)retryPressed:(id)sender {
    (void)sender;
    [[TGDownloadManager sharedManager] retryDownloadWithIdentifier:[[self selectedDownload] objectForKey:@"identifier"]
                                                       completion:nil];
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
