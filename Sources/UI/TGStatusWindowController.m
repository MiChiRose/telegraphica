#import "TGStatusWindowController.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"

static NSUInteger const TGStatusChatPreviewInitialLimit = 40;
static NSUInteger const TGStatusChatPreviewStep = 40;
static NSUInteger const TGStatusChatPreviewMaximumLimit = 500;
static NSUInteger const TGMessagePreviewInitialLimit = 20;
static NSUInteger const TGMessagePrefillMinimumRows = 20;
static NSUInteger const TGMessagePrefillMaxAttempts = 3;
static CGFloat const TGPanelCornerRadius = 10.0;

static long long TGMessageSortValue(id value) {
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [value longLongValue];
    }
    return 0;
}

static NSInteger TGCompareMessageItemsAscending(id left, id right, void *context) {
    (void)context;
    long long leftDate = 0;
    long long rightDate = 0;
    long long leftMessageID = 0;
    long long rightMessageID = 0;

    if ([left isKindOfClass:[TGMessageItem class]]) {
        leftDate = TGMessageSortValue([(TGMessageItem *)left date]);
        leftMessageID = TGMessageSortValue([(TGMessageItem *)left messageID]);
    }
    if ([right isKindOfClass:[TGMessageItem class]]) {
        rightDate = TGMessageSortValue([(TGMessageItem *)right date]);
        rightMessageID = TGMessageSortValue([(TGMessageItem *)right messageID]);
    }

    if (leftDate < rightDate) {
        return NSOrderedAscending;
    }
    if (leftDate > rightDate) {
        return NSOrderedDescending;
    }
    if (leftMessageID < rightMessageID) {
        return NSOrderedAscending;
    }
    if (leftMessageID > rightMessageID) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

@interface TGChromeView : NSView
@end

@implementation TGChromeView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSGradient *topGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.88 green:0.87 blue:0.84 alpha:1.0]
                                                             endingColor:[NSColor colorWithCalibratedRed:0.80 green:0.80 blue:0.74 alpha:1.0]] autorelease];
    [topGradient drawInRect:bounds angle:90.0];

    NSRect lowerHalf = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), NSHeight(bounds) * 0.55);
    NSGradient *bottomGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.80 green:0.80 blue:0.74 alpha:1.0]
                                                                endingColor:[NSColor colorWithCalibratedRed:0.70 green:0.70 blue:0.65 alpha:1.0]] autorelease];
    [bottomGradient drawInRect:lowerHalf angle:90.0];

    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] set];
    NSRectFill(NSMakeRect(0.0, NSHeight(bounds) - 1.0, NSWidth(bounds), 1.0));
}

@end

@interface TGPanelView : NSView
@end

@implementation TGPanelView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect panelBounds = NSInsetRect(bounds, 2.5, 2.5);
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelBounds
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];

    [NSGraphicsContext saveGraphicsState];
    NSShadow *outerShadow = [[[NSShadow alloc] init] autorelease];
    [outerShadow setShadowColor:[[NSColor colorWithCalibratedWhite:0.0 alpha:0.30] colorWithAlphaComponent:0.35]];
    [outerShadow setShadowOffset:NSMakeSize(0.0, -1.2)];
    [outerShadow setShadowBlurRadius:3.0];
    [outerShadow set];
    [panelPath fill];
    [NSGraphicsContext restoreGraphicsState];

    NSGradient *panelGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:0.96 alpha:1.0]
                                                              endingColor:[NSColor colorWithCalibratedRed:0.84 green:0.82 blue:0.76 alpha:1.0]] autorelease];
    [panelGradient drawInBezierPath:panelPath angle:90.0];

    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(panelBounds, 1.0, 1.0)
                                                               xRadius:(TGPanelCornerRadius - 1.0)
                                                               yRadius:(TGPanelCornerRadius - 1.0)];
    [[NSColor colorWithCalibratedWhite:0.35 alpha:0.45] set];
    [innerPath setLineWidth:0.9];
    [innerPath stroke];

    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.55] set];
    NSBezierPath *highlight = [NSBezierPath bezierPath];
    [highlight moveToPoint:NSMakePoint(NSMinX(panelBounds) + 8.0, NSMaxY(panelBounds) - 1.5)];
    [highlight lineToPoint:NSMakePoint(NSMaxX(panelBounds) - 8.0, NSMaxY(panelBounds) - 1.5)];
    [highlight stroke];

    [[NSColor colorWithCalibratedWhite:0.46 alpha:0.35] set];
    NSBezierPath *lowerStroke = [NSBezierPath bezierPath];
    [lowerStroke moveToPoint:NSMakePoint(NSMinX(panelBounds) + 9.0, NSMinY(panelBounds) + 1.0)];
    [lowerStroke lineToPoint:NSMakePoint(NSMaxX(panelBounds) - 9.0, NSMinY(panelBounds) + 1.0)];
    [lowerStroke stroke];
}

@end

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
@property (nonatomic, retain) NSView *topPanelView;
@property (nonatomic, retain) NSView *sidebarPanelView;
@property (nonatomic, retain) NSView *conversationPanelView;
@property (nonatomic, retain) NSView *diagnosticsPanelView;
@property (nonatomic, retain) NSTextField *diagnosticsLabel;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSScrollView *detailsScrollView;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSButton *loadMoreChatsButton;
@property (nonatomic, retain) NSButton *loadMessagesButton;
@property (nonatomic, retain) NSButton *loadOlderMessagesButton;
@property (nonatomic, retain) NSButton *quitButton;
@property (nonatomic, retain) NSTextField *sendLabel;
@property (nonatomic, retain) NSTextField *sendTextField;
@property (nonatomic, retain) NSButton *sendMessageButton;
@property (nonatomic, retain) NSTextField *authLabel;
@property (nonatomic, retain) NSTextField *authStateField;
@property (nonatomic, retain) NSTextField *authTextField;
@property (nonatomic, retain) NSSecureTextField *authSecureField;
@property (nonatomic, retain) NSButton *authButton;
@property (nonatomic, retain) NSTextField *chatsLabel;
@property (nonatomic, retain) NSTextField *messagesLabel;
@property (nonatomic, retain) NSTextField *selectedChatField;
@property (nonatomic, retain) NSScrollView *chatScrollView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) NSScrollView *messageScrollView;
@property (nonatomic, retain) NSTableView *messageTableView;
@property (nonatomic, retain) NSMutableArray *messageItems;
@property (nonatomic, retain) NSNumber *selectedChatID;
@property (nonatomic, copy) NSString *selectedChatTitle;
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState;
@property (nonatomic, retain) NSTimer *liveUpdateTimer;
@property (nonatomic, assign) BOOL controlsBusy;
@property (nonatomic, assign) BOOL backgroundChatRefreshInFlight;
@property (nonatomic, assign) BOOL backgroundMessageRefreshInFlight;
@property (nonatomic, assign) BOOL pendingLiveChatRefresh;
@property (nonatomic, assign) BOOL pendingLiveMessageRefresh;
@property (nonatomic, assign) NSUInteger chatPreviewLimit;
@property (nonatomic, assign) BOOL chatsExhausted;
@property (nonatomic, assign) BOOL olderMessagesExhausted;
@property (nonatomic, assign) BOOL autoOlderMessagesLoadArmed;
@property (nonatomic, assign) BOOL autoChatListLoadArmed;
@property (nonatomic, assign) BOOL forceMessageScrollToNewest;
@end

@implementation TGStatusWindowController

@synthesize topPanelView = _topPanelView;
@synthesize sidebarPanelView = _sidebarPanelView;
@synthesize conversationPanelView = _conversationPanelView;
@synthesize diagnosticsPanelView = _diagnosticsPanelView;
@synthesize diagnosticsLabel = _diagnosticsLabel;
@synthesize statusField = _statusField;
@synthesize titleField = _titleField;
@synthesize detailsScrollView = _detailsScrollView;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize loadMoreChatsButton = _loadMoreChatsButton;
@synthesize loadMessagesButton = _loadMessagesButton;
@synthesize loadOlderMessagesButton = _loadOlderMessagesButton;
@synthesize quitButton = _quitButton;
@synthesize sendLabel = _sendLabel;
@synthesize sendTextField = _sendTextField;
@synthesize sendMessageButton = _sendMessageButton;
@synthesize authLabel = _authLabel;
@synthesize authStateField = _authStateField;
@synthesize authTextField = _authTextField;
@synthesize authSecureField = _authSecureField;
@synthesize authButton = _authButton;
@synthesize chatsLabel = _chatsLabel;
@synthesize messagesLabel = _messagesLabel;
@synthesize selectedChatField = _selectedChatField;
@synthesize chatScrollView = _chatScrollView;
@synthesize chatTableView = _chatTableView;
@synthesize chatItems = _chatItems;
@synthesize messageScrollView = _messageScrollView;
@synthesize messageTableView = _messageTableView;
@synthesize messageItems = _messageItems;
@synthesize selectedChatID = _selectedChatID;
@synthesize selectedChatTitle = _selectedChatTitle;
@synthesize client = _client;
@synthesize currentAuthState = _currentAuthState;
@synthesize liveUpdateTimer = _liveUpdateTimer;
@synthesize controlsBusy = _controlsBusy;
@synthesize backgroundChatRefreshInFlight = _backgroundChatRefreshInFlight;
@synthesize backgroundMessageRefreshInFlight = _backgroundMessageRefreshInFlight;
@synthesize pendingLiveChatRefresh = _pendingLiveChatRefresh;
@synthesize pendingLiveMessageRefresh = _pendingLiveMessageRefresh;
@synthesize chatPreviewLimit = _chatPreviewLimit;
@synthesize chatsExhausted = _chatsExhausted;
@synthesize olderMessagesExhausted = _olderMessagesExhausted;
@synthesize autoOlderMessagesLoadArmed = _autoOlderMessagesLoadArmed;
@synthesize autoChatListLoadArmed = _autoChatListLoadArmed;
@synthesize forceMessageScrollToNewest = _forceMessageScrollToNewest;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 980, 700);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window setMinSize:NSMakeSize(760, 620)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [[self window] setDelegate:self];
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
        self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self buildContentView];
        [self startLiveUpdateTimerIfNeeded];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setTextColor:[NSColor colorWithCalibratedRed:0.19 green:0.18 blue:0.15 alpha:1.0]];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)applySkeuomorphicButtonStyle:(NSButton *)button isPrimary:(BOOL)isPrimary {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSTexturedRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    if (isPrimary) {
        [button setFont:[NSFont boldSystemFontOfSize:12.0]];
    } else {
        [button setFont:[NSFont systemFontOfSize:11.0]];
    }
}

- (void)applySkeuomorphicTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:YES];
    [textField setBordered:YES];
    [textField setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:0.96 alpha:1.0]];
    [textField setTextColor:[NSColor colorWithCalibratedRed:0.12 green:0.11 blue:0.09 alpha:1.0]];
    [textField setDrawsBackground:YES];
    [textField setFocusRingType:NSFocusRingTypeExterior];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applySkeuomorphicScrollStyle:(NSScrollView *)scrollView {
    [scrollView setBorderType:NSNoBorder];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:0.96 alpha:1.0]];
    [scrollView setHasVerticalScroller:YES];
}

- (void)applySkeuomorphicTableStyle:(NSTableView *)tableView {
    [tableView setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:0.96 alpha:1.0]];
    [tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [tableView setGridColor:[NSColor colorWithCalibratedRed:0.78 green:0.76 blue:0.70 alpha:1.0]];
    [tableView setUsesAlternatingRowBackgroundColors:NO];
    [tableView setIntercellSpacing:NSMakeSize(8.0, 2.0)];
    [tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
}

- (void)applySkeuomorphicHeaderCellStyle:(NSTextFieldCell *)headerCell {
    if (!headerCell) {
        return;
    }
    [headerCell setFont:[NSFont boldSystemFontOfSize:11.0]];
    [headerCell setTextColor:[NSColor colorWithCalibratedRed:0.25 green:0.24 blue:0.20 alpha:1.0]];
    [headerCell setAlignment:NSLeftTextAlignment];
    [headerCell setDrawsBackground:YES];
    [headerCell setBackgroundColor:[NSColor colorWithCalibratedRed:0.89 green:0.87 blue:0.82 alpha:1.0]];
}

- (void)buildContentView {
    TGChromeView *contentView = [[[TGChromeView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:contentView];
    [contentView setAutoresizesSubviews:YES];

    self.topPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 628, 948, 56)] autorelease];
    [self.topPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.topPanelView];

    self.sidebarPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 286, 480)] autorelease];
    [self.sidebarPanelView setAutoresizingMask:(NSViewHeightSizable | NSViewMaxXMargin)];
    [contentView addSubview:self.sidebarPanelView];

    self.conversationPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(314, 132, 650, 480)] autorelease];
    [self.conversationPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.conversationPanelView];

    self.diagnosticsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 16, 948, 104)] autorelease];
    [self.diagnosticsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.diagnosticsPanelView];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 668, 712, 28)
                                      text:@"Telegraphica"
                                      font:[NSFont boldSystemFontOfSize:20.0]];
    [contentView addSubview:self.titleField];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 636, 712, 22)
                                     text:@"TDLib status: not checked"
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.statusField];

    self.detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.detailsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[self.detailsScrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setTextColor:[NSColor colorWithCalibratedRed:0.12 green:0.11 blue:0.09 alpha:1.0]];
    [self.detailsView setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:0.96 alpha:1.0]];
    [self.detailsView setString:@"Ready. Place libtdjson.dylib in Contents/Frameworks or set TELEGRAPHICA_TDJSON_PATH, then check the core.\n"];
    [self.detailsScrollView setDocumentView:self.detailsView];
    [contentView addSubview:self.detailsScrollView];

    self.diagnosticsLabel = [self labelWithFrame:NSMakeRect(24, 104, 112, 18)
                                            text:@"Diagnostics"
                                            font:[NSFont boldSystemFontOfSize:11.0]];
    [contentView addSubview:self.diagnosticsLabel];

    self.authLabel = [self labelWithFrame:NSMakeRect(24, 374, 76, 22)
                                     text:@"Auth:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.authLabel];

    self.authStateField = [self labelWithFrame:NSMakeRect(104, 374, 560, 22)
                                          text:@"not checked"
                                          font:[NSFont systemFontOfSize:13.0]];
    [[self.authStateField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.authStateField];

    self.authTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authTextField setEnabled:NO];
    [self.authTextField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authTextField];
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authSecureField];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 366, 116, 32)] autorelease];
    [self.authButton setTitle:@"Send"];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self applySkeuomorphicButtonStyle:self.authButton isPrimary:NO];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    self.chatsLabel = [self labelWithFrame:NSMakeRect(24, 338, 76, 22)
                                      text:@"Chats:"
                                      font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 332, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"Load Chats"];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadChatsButton isPrimary:YES];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    self.loadMoreChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(224, 332, 80, 32)] autorelease];
    [self.loadMoreChatsButton setTitle:@"More"];
    [self.loadMoreChatsButton setTarget:self];
    [self.loadMoreChatsButton setAction:@selector(loadMoreChats:)];
    [self.loadMoreChatsButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadMoreChatsButton isPrimary:NO];
    [self.loadMoreChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMoreChatsButton];

    self.chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[self.chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];
    [self.chatTableView setRowHeight:24.0];
    [self applySkeuomorphicTableStyle:self.chatTableView];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Chat"];
    [self applySkeuomorphicHeaderCellStyle:[chatColumn headerCell]];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    NSTableColumn *typeColumn = [[[NSTableColumn alloc] initWithIdentifier:@"type"] autorelease];
    [[typeColumn headerCell] setStringValue:@"Type"];
    [self applySkeuomorphicHeaderCellStyle:[typeColumn headerCell]];
    [typeColumn setWidth:130.0];
    [self.chatTableView addTableColumn:typeColumn];

    NSTableColumn *unreadColumn = [[[NSTableColumn alloc] initWithIdentifier:@"unread_count"] autorelease];
    [[unreadColumn headerCell] setStringValue:@"Unread"];
    [self applySkeuomorphicHeaderCellStyle:[unreadColumn headerCell]];
    [unreadColumn setWidth:80.0];
    [self.chatTableView addTableColumn:unreadColumn];

    [self.chatScrollView setDocumentView:self.chatTableView];
    [[self.chatScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chatScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.chatScrollView contentView]];
    [contentView addSubview:self.chatScrollView];

    self.messagesLabel = [self labelWithFrame:NSMakeRect(24, 198, 86, 22)
                                         text:@"Messages:"
                                         font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.messagesLabel];

    self.loadMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(116, 192, 136, 32)] autorelease];
    [self.loadMessagesButton setTitle:@"Load Messages"];
    [self.loadMessagesButton setTarget:self];
    [self.loadMessagesButton setAction:@selector(loadMessages:)];
    [self.loadMessagesButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadMessagesButton isPrimary:YES];
    [self.loadMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMessagesButton];

    self.loadOlderMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(264, 192, 112, 32)] autorelease];
    [self.loadOlderMessagesButton setTitle:@"Older"];
    [self.loadOlderMessagesButton setTarget:self];
    [self.loadOlderMessagesButton setAction:@selector(loadOlderMessages:)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadOlderMessagesButton isPrimary:NO];
    [self.loadOlderMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadOlderMessagesButton];

    self.selectedChatField = [self labelWithFrame:NSMakeRect(264, 198, 472, 22)
                                             text:@"select a chat"
                                             font:[NSFont systemFontOfSize:13.0]];
    [[self.selectedChatField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.selectedChatField];

    self.messageScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];

    self.messageTableView = [[[NSTableView alloc] initWithFrame:[[self.messageScrollView contentView] bounds]] autorelease];
    [self.messageTableView setDataSource:self];
    [self.messageTableView setDelegate:self];
    [self.messageTableView setAllowsColumnReordering:NO];
    [self.messageTableView setAllowsMultipleSelection:NO];
    [self.messageTableView setRowHeight:26.0];
    [self applySkeuomorphicTableStyle:self.messageTableView];

    NSTableColumn *dateColumn = [[[NSTableColumn alloc] initWithIdentifier:@"date"] autorelease];
    [[dateColumn headerCell] setStringValue:@"Time"];
    [self applySkeuomorphicHeaderCellStyle:[dateColumn headerCell]];
    [dateColumn setWidth:120.0];
    [self.messageTableView addTableColumn:dateColumn];

    NSTableColumn *directionColumn = [[[NSTableColumn alloc] initWithIdentifier:@"direction"] autorelease];
    [[directionColumn headerCell] setStringValue:@"Dir"];
    [self applySkeuomorphicHeaderCellStyle:[directionColumn headerCell]];
    [directionColumn setWidth:54.0];
    [self.messageTableView addTableColumn:directionColumn];

    NSTableColumn *previewColumn = [[[NSTableColumn alloc] initWithIdentifier:@"preview"] autorelease];
    [[previewColumn headerCell] setStringValue:@"Message"];
    [self applySkeuomorphicHeaderCellStyle:[previewColumn headerCell]];
    [previewColumn setWidth:500.0];
    [self.messageTableView addTableColumn:previewColumn];

    [self.messageScrollView setDocumentView:self.messageTableView];
    [[self.messageScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.messageScrollView contentView]];
    [contentView addSubview:self.messageScrollView];

    self.sendLabel = [self labelWithFrame:NSMakeRect(24, 58, 48, 22)
                                     text:@"Send:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.sendLabel];

    self.sendTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextField setEnabled:NO];
    [self applySkeuomorphicTextFieldStyle:self.sendTextField];
    [self.sendTextField setDelegate:(id)self];
    [self.sendTextField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextField];

    self.sendMessageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(588, 50, 148, 32)] autorelease];
    [self.sendMessageButton setTitle:@"Send Message"];
    [self.sendMessageButton setTarget:self];
    [self.sendMessageButton setAction:@selector(sendMessage:)];
    [self.sendMessageButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.sendMessageButton isPrimary:YES];
    [self.sendMessageButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.sendMessageButton];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Check TDLib"];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self applySkeuomorphicButtonStyle:self.checkButton isPrimary:YES];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    self.quitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(176, 28, 96, 32)] autorelease];
    [self.quitButton setTitle:@"Quit"];
    [self.quitButton setTarget:NSApp];
    [self.quitButton setAction:@selector(terminate:)];
    [self applySkeuomorphicButtonStyle:self.quitButton isPrimary:NO];
    [self.quitButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.quitButton];

    [self layoutContentView];
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 16.0;
    CGFloat gutter = 12.0;
    CGFloat topPanelHeight = 56.0;
    CGFloat authHeight = 34.0;
    CGFloat diagnosticsHeight = 104.0;
    CGFloat lowerY = margin;
    CGFloat diagnosticsY = lowerY;
    CGFloat bodyY = diagnosticsY + diagnosticsHeight + gutter;
    CGFloat topPanelY = height - margin - topPanelHeight;
    CGFloat authY = topPanelY - authHeight - 8.0;
    CGFloat bodyTop = authY - gutter;
    CGFloat bodyHeight = bodyTop - bodyY;
    CGFloat sidebarWidth = 286.0;
    CGFloat contentWidth = width - (margin * 2.0);
    CGFloat conversationX = margin + sidebarWidth + gutter;
    CGFloat conversationWidth = width - conversationX - margin;

    if (bodyHeight < 320.0) {
        bodyHeight = 320.0;
    }

    [self.topPanelView setFrame:NSMakeRect(margin, topPanelY, contentWidth, topPanelHeight)];
    [self.sidebarPanelView setFrame:NSMakeRect(margin, bodyY, sidebarWidth, bodyHeight)];
    [self.conversationPanelView setFrame:NSMakeRect(conversationX, bodyY, conversationWidth, bodyHeight)];
    [self.diagnosticsPanelView setFrame:NSMakeRect(margin, diagnosticsY, contentWidth, diagnosticsHeight)];

    CGFloat topActionGap = 9.0;
    CGFloat topQuitWidth = 86.0;
    CGFloat topCheckWidth = 146.0;
    CGFloat topActionBaseY = topPanelY + 12.0;
    CGFloat topActionRight = width - margin - topActionGap;
    CGFloat topCheckX = topActionRight - topCheckWidth;
    CGFloat topQuitX = topCheckX - topActionGap - topQuitWidth;
    CGFloat topTextStart = margin + 18.0;
    CGFloat topAvailableTextWidth = (topCheckX - topTextStart - 4.0);
    if (topAvailableTextWidth < 240.0) {
        topAvailableTextWidth = 240.0;
    }
    [self.titleField setFrame:NSMakeRect(topTextStart, topPanelY + 24.0, topAvailableTextWidth, 24.0)];
    [self.statusField setFrame:NSMakeRect(topTextStart, topPanelY + 8.0, topAvailableTextWidth, 18.0)];
    [self.checkButton setFrame:NSMakeRect(topCheckX, topActionBaseY, topCheckWidth, 32.0)];
    [self.quitButton setFrame:NSMakeRect(topQuitX, topActionBaseY, topQuitWidth, 32.0)];

    CGFloat authInputWidth = contentWidth - 420.0;
    if (authInputWidth < 170.0) {
        authInputWidth = 170.0;
    }
    CGFloat authButtonX = width - margin - 122.0;
    if (authButtonX < (margin + 220.0)) {
        authButtonX = margin + 220.0;
    }
    [self.authLabel setFrame:NSMakeRect(margin + 10.0, authY + 8.0, 62.0, 20.0)];
    [self.authStateField setFrame:NSMakeRect(margin + 78.0, authY + 8.0, authInputWidth, 20.0)];
    [self.authTextField setFrame:NSMakeRect(margin + 78.0, authY + 4.0, 240.0, 24.0)];
    [self.authSecureField setFrame:NSMakeRect(margin + 78.0, authY + 4.0, 240.0, 24.0)];
    [self.authButton setFrame:NSMakeRect(authButtonX, authY, 116.0, 32.0)];

    [self.chatsLabel setFrame:NSMakeRect(margin + 14.0, bodyTop - 30.0, 90.0, 22.0)];
    [self.loadChatsButton setFrame:NSMakeRect(margin + sidebarWidth - 184.0, bodyTop - 36.0, 112.0, 30.0)];
    [self.loadMoreChatsButton setFrame:NSMakeRect(margin + sidebarWidth - 66.0, bodyTop - 36.0, 50.0, 30.0)];
    [self.chatScrollView setFrame:NSMakeRect(margin + 12.0, bodyY + 12.0, sidebarWidth - 24.0, bodyHeight - 56.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"title"];
    if (chatColumn) {
        CGFloat chatWidth = sidebarWidth - 154.0;
        if (chatWidth < 132.0) {
            chatWidth = 132.0;
        }
        [chatColumn setWidth:chatWidth];
    }

    [self.messagesLabel setFrame:NSMakeRect(conversationX + 14.0, bodyTop - 30.0, 94.0, 22.0)];
    [self.loadMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 236.0, bodyTop - 36.0, 136.0, 30.0)];
    [self.loadOlderMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 94.0, bodyTop - 36.0, 78.0, 30.0)];
    [self.selectedChatField setFrame:NSMakeRect(conversationX + 112.0, bodyTop - 30.0, conversationWidth - 360.0, 22.0)];

    CGFloat composerHeight = 38.0;
    CGFloat composerY = bodyY + 14.0;
    CGFloat messageBottom = composerY + composerHeight + 10.0;
    CGFloat messageTop = bodyTop - 46.0;
    CGFloat messageHeight = messageTop - messageBottom;
    if (messageHeight < 160.0) {
        messageHeight = 160.0;
    }
    [self.messageScrollView setFrame:NSMakeRect(conversationX + 12.0, messageBottom, conversationWidth - 24.0, messageHeight)];
    NSTableColumn *previewColumn = [self.messageTableView tableColumnWithIdentifier:@"preview"];
    if (previewColumn) {
        CGFloat previewWidth = conversationWidth - 214.0;
        if (previewWidth < 260.0) {
            previewWidth = 260.0;
        }
        [previewColumn setWidth:previewWidth];
    }

    CGFloat sendButtonWidth = (conversationWidth < 470.0) ? 112.0 : 132.0;
    CGFloat sendFieldX = conversationX + 62.0;
    CGFloat sendButtonX = conversationX + conversationWidth - sendButtonWidth - 12.0;
    CGFloat sendFieldWidth = sendButtonX - sendFieldX - 10.0;
    if (sendFieldWidth < 160.0) {
        sendFieldWidth = 160.0;
    }
    [self.sendLabel setFrame:NSMakeRect(conversationX + 14.0, composerY + 8.0, 46.0, 22.0)];
    [self.sendTextField setFrame:NSMakeRect(sendFieldX, composerY + 4.0, sendFieldWidth, 24.0)];
    [self.sendMessageButton setFrame:NSMakeRect(sendButtonX, composerY, sendButtonWidth, 32.0)];

    [self.diagnosticsLabel setFrame:NSMakeRect(margin + 14.0, diagnosticsY + diagnosticsHeight - 26.0, 120.0, 18.0)];
    [self.detailsScrollView setFrame:NSMakeRect(margin + 12.0, diagnosticsY + 12.0, contentWidth - 24.0, diagnosticsHeight - 42.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutContentView];
}

- (void)startLiveUpdateTimerIfNeeded {
    if (self.liveUpdateTimer) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(pollLiveUpdates:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.liveUpdateTimer = timer;
}

- (void)stopLiveUpdateTimer {
    if (!self.liveUpdateTimer) {
        return;
    }

    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)prepareForApplicationTermination {
    [self stopLiveUpdateTimer];
    [self setControlsBusy:YES];
    [self.client shutdownWithTimeout:3.0];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (void)updateSendControls {
    BOOL canTargetChat = [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil;
    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.sendTextField setEnabled:canTargetChat];
    [self.sendMessageButton setEnabled:(canTargetChat && [trimmedText length] > 0 && [text length] <= 4096)];
}

- (BOOL)canLoadMoreChats {
    return (!self.controlsBusy &&
            [self.currentAuthState isEqualToString:@"ready"] &&
            [self.chatItems count] > 0 &&
            !self.chatsExhausted &&
            [self.chatItems count] < TGStatusChatPreviewMaximumLimit);
}

- (void)updateAuthControlsForState:(NSString *)state {
    NSString *previousState = [self.currentAuthState copy];
    self.currentAuthState = state;
    [self.authTextField setStringValue:@""];
    [self.authSecureField setStringValue:@""];
    [self.loadChatsButton setEnabled:NO];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.sendMessageButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self.selectedChatField setStringValue:@"select a chat"];
        [self.sendTextField setStringValue:@""];
    }

    if (![state isEqualToString:@"ready"]) {
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.pendingLiveChatRefresh = NO;
        self.pendingLiveMessageRefresh = NO;
    } else if (![previousState isEqualToString:@"ready"] && [self.chatItems count] == 0) {
        self.pendingLiveChatRefresh = YES;
        [self handlePendingLiveRefreshesIfPossible];
    }

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.authLabel setStringValue:@"Phone:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Send Phone"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.authLabel setStringValue:@"Code:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Verify"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.authLabel setStringValue:@"Password:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Unlock"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [previousState release];
        return;
    }

    [self.authLabel setStringValue:@"Auth:"];
    if ([state isEqualToString:@"ready"]) {
        [self.authStateField setStringValue:@"ready"];
    } else if ([state length] > 0) {
        [self.authStateField setStringValue:state];
    } else {
        [self.authStateField setStringValue:@"not checked"];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [self.authButton setTitle:@"Send"];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.loadOlderMessagesButton setEnabled:([state isEqualToString:@"ready"] && self.selectedChatID != nil && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self updateSendControls];

    [previousState release];
}

- (void)setControlsBusy:(BOOL)busy {
    _controlsBusy = busy;
    [self.checkButton setEnabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.loadOlderMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self.sendTextField setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.sendMessageButton setEnabled:NO];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMoreChatsButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
        [self.loadOlderMessagesButton setEnabled:NO];
        [self.chatTableView setEnabled:NO];
        [self.messageTableView setEnabled:NO];
        [self.sendTextField setEnabled:NO];
        [self.sendMessageButton setEnabled:NO];
    } else {
        [self.chatTableView setEnabled:YES];
        [self.messageTableView setEnabled:YES];
        [self updateAuthControlsForState:self.currentAuthState];
        [self handlePendingLiveRefreshesIfPossible];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.sendTextField) {
        [self updateSendControls];
    }
}

- (void)appendDetail:(NSString *)detail {
    NSString *current = [self.detailsView string];
    NSString *line = [detail stringByAppendingString:@"\n"];
    [self.detailsView setString:[current stringByAppendingString:line]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.messageTableView) {
        return (NSInteger)[self.messageItems count];
    }
    return (NSInteger)[self.chatItems count];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableColumn;
    (void)row;
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    [textCell setFont:[NSFont systemFontOfSize:12.0]];
    [textCell setTextColor:[NSColor colorWithCalibratedRed:0.15 green:0.14 blue:0.12 alpha:1.0]];
    [textCell setDrawsBackground:NO];
    [textCell setLineBreakMode:NSLineBreakByTruncatingTail];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    id item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = nil;
    if (tableView == self.messageTableView && [item isKindOfClass:[TGMessageItem class]]) {
        value = [(TGMessageItem *)item valueForTableColumnIdentifier:identifier];
    } else if (tableView == self.chatTableView && [item isKindOfClass:[TGChatItem class]]) {
        value = [(TGChatItem *)item valueForTableColumnIdentifier:identifier];
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"date"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger timestamp = [value integerValue];
        if (timestamp <= 0) {
            return @"";
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
        return [NSDateFormatter localizedStringFromDate:date
                                              dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
    }
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)] && [value integerValue] == 0) {
        return @"";
    }
    return value ? value : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] != self.chatTableView) {
        return;
    }

    NSNumber *previousChatID = [self.selectedChatID retain];
    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        [self.selectedChatField setStringValue:@"select a chat"];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateAuthControlsForState:self.currentAuthState];
        [previousChatID release];
        return;
    }

    TGChatItem *item = [self.chatItems objectAtIndex:(NSUInteger)row];
    id chatID = [item chatID];
    id title = [item title];
    NSNumber *newChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        newChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        self.selectedChatID = newChatID;
    } else {
        self.selectedChatID = nil;
    }
    BOOL selectionChanged = !((previousChatID && newChatID) && ([previousChatID longLongValue] == [newChatID longLongValue]));
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"selected chat";
    [self.selectedChatField setStringValue:self.selectedChatTitle ? self.selectedChatTitle : @"selected chat"];
    if (selectionChanged) {
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
    }
    [self updateAuthControlsForState:self.currentAuthState];
    if (newChatID && (selectionChanged || [self.messageItems count] == 0)) {
        [self reloadMessagesForChatID:newChatID interactive:NO];
    }
    [previousChatID release];
}

- (void)applyChatItems:(NSArray *)items preserveSelection:(BOOL)preserveSelection preferredChatID:(NSNumber *)preferredChatID {
    NSUInteger selectedIndex = NSNotFound;

    if (preserveSelection && preferredChatID) {
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            TGChatItem *item = [items objectAtIndex:index];
            id chatID = [item chatID];
            if ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [preferredChatID longLongValue]) {
                selectedIndex = index;
                break;
            }
        }
    }

    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:items];
    [self.chatTableView reloadData];
    self.autoChatListLoadArmed = YES;

    if (selectedIndex != NSNotFound) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:selectedIndex];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        return;
    }

    [self.chatTableView deselectAll:nil];
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    [self.selectedChatField setStringValue:@"select a chat"];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self.sendTextField setStringValue:@""];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self updateAuthControlsForState:self.currentAuthState];
}

- (NSNumber *)oldestLoadedMessageID {
    long long minimumMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            long long value = [messageID longLongValue];
            if (minimumMessageID == 0 || value < minimumMessageID) {
                minimumMessageID = value;
            }
        }
    }
    if (minimumMessageID > 0) {
        return [NSNumber numberWithLongLong:minimumMessageID];
    }
    return nil;
}

- (NSArray *)messageItemsInDisplayOrderFromItems:(NSArray *)items {
    return [items sortedArrayUsingFunction:TGCompareMessageItemsAscending context:NULL];
}

- (void)scrollMessagesToNewestIfAvailable {
    NSUInteger count = [self.messageItems count];
    if (count > 0) {
        [self.messageTableView scrollRowToVisible:(count - 1)];
    }
}

- (void)applyRecentMessageItems:(NSArray *)items preservingOlderItems:(BOOL)preserveOlder {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    BOOL forceScrollToNewest = self.forceMessageScrollToNewest;
    self.forceMessageScrollToNewest = NO;
    if (!preserveOlder || [self.messageItems count] == 0) {
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:orderedItems];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self.messageTableView reloadData];
        [self scrollMessagesToNewestIfAvailable];
        return;
    }

    BOOL shouldScrollToNewest = forceScrollToNewest || [self isMessageHistoryNearBottom];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:self.messageItems];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [mergedItems addObject:item];
    }

    [self.messageItems removeAllObjects];
    [self.messageItems addObjectsFromArray:[self messageItemsInDisplayOrderFromItems:mergedItems]];
    [self.messageTableView reloadData];
    if (shouldScrollToNewest) {
        [self scrollMessagesToNewestIfAvailable];
    }
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items preservingVisiblePosition:(BOOL)preserveVisiblePosition {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSInteger firstVisibleRow = 0;
    if (preserveVisiblePosition) {
        NSPoint visibleOrigin = [[self.messageScrollView contentView] bounds].origin;
        firstVisibleRow = [self.messageTableView rowAtPoint:visibleOrigin];
        if (firstVisibleRow < 0) {
            firstVisibleRow = 0;
        }
    }
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *existingItem = [self.messageItems objectAtIndex:index];
        id messageID = [existingItem messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    NSMutableArray *itemsToPrepend = [NSMutableArray array];
    NSUInteger added = 0;
    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [itemsToPrepend addObject:item];
        added++;
    }

    if (added > 0) {
        NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:itemsToPrepend];
        [mergedItems addObjectsFromArray:self.messageItems];
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:mergedItems];
    }

    [self.messageTableView reloadData];
    if (added > 0) {
        if (preserveVisiblePosition) {
            NSUInteger targetRow = (NSUInteger)firstVisibleRow + added;
            if (targetRow >= [self.messageItems count]) {
                targetRow = [self.messageItems count] - 1;
            }
            [self.messageTableView scrollRowToVisible:targetRow];
        } else {
            [self scrollMessagesToNewestIfAvailable];
        }
    }
    return added;
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items {
    return [self appendOlderMessageItems:items preservingVisiblePosition:YES];
}

- (BOOL)isChatListNearBottom {
    if ([self.chatItems count] == 0 || self.chatsExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (void)chatScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.chatScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        self.controlsBusy ||
        self.backgroundChatRefreshInFlight ||
        self.chatsExhausted ||
        [self.chatItems count] == 0) {
        return;
    }

    if (![self isChatListNearBottom]) {
        self.autoChatListLoadArmed = YES;
        return;
    }

    if (!self.autoChatListLoadArmed) {
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }

    if (nextLimit <= self.chatPreviewLimit) {
        self.autoChatListLoadArmed = NO;
        return;
    }

    self.autoChatListLoadArmed = NO;
    [self reloadChatsInteractive:NO preserveSelection:YES requestedLimit:nextLimit];
}

- (BOOL)isMessageHistoryNearBottom {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isMessageHistoryScrollable {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.messageTableView rowHeight] + [self.messageTableView intercellSpacing].height) * (CGFloat)[self.messageItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)messageHistoryNeedsPrefill {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }
    return ([self.messageItems count] < TGMessagePrefillMinimumRows || ![self isMessageHistoryScrollable]);
}

- (BOOL)isMessageHistoryNearTop {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    if (![self isMessageHistoryScrollable]) {
        return NO;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 48.0);
}

- (void)messageScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.messageScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        self.olderMessagesExhausted ||
        [self.messageItems count] == 0) {
        return;
    }

    if (![self isMessageHistoryNearTop]) {
        self.autoOlderMessagesLoadArmed = YES;
        return;
    }

    if (!self.autoOlderMessagesLoadArmed) {
        return;
    }

    self.autoOlderMessagesLoadArmed = NO;
    [self reloadOlderMessagesInteractive];
}

- (void)prefillOlderMessagesIfNeededWithAttemptsRemaining:(NSUInteger)attemptsRemaining {
    if (attemptsRemaining == 0 ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        ![self messageHistoryNeedsPrefill]) {
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    self.backgroundMessageRefreshInFlight = YES;

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        BOOL hadMessageError = (messageError != nil);
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            NSUInteger added = 0;
            if (selectionStillCurrent && itemsCopy) {
                added = [self appendOlderMessageItems:itemsCopy preservingVisiblePosition:NO];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: prefilled %lu older previews", (unsigned long)added]];
                }
            } else if (selectionStillCurrent && hadMessageError) {
                self.autoOlderMessagesLoadArmed = YES;
            }

            self.backgroundMessageRefreshInFlight = NO;
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            } else {
                [self updateAuthControlsForState:self.currentAuthState];
            }

            if (selectionStillCurrent &&
                added > 0 &&
                attemptsRemaining > 1 &&
                [self messageHistoryNeedsPrefill]) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:(attemptsRemaining - 1)];
            } else {
                [self handlePendingLiveRefreshesIfPossible];
            }

            [itemsCopy release];
            [authorizationState release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection {
    [self reloadChatsInteractive:interactive preserveSelection:preserveSelection requestedLimit:self.chatPreviewLimit];
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection requestedLimit:(NSUInteger)requestedLimit {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        if (interactive) {
            [self appendDetail:@"Chats are available only after TDLib auth state is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = YES;
        return;
    }

    NSNumber *preferredChatID = preserveSelection ? [self.selectedChatID retain] : nil;
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"TDLib chats: loading..."];
        [self appendDetail:@"Loading main chat previews from TDLib..."];
    } else {
        self.backgroundChatRefreshInFlight = YES;
    }

    if (requestedLimit == 0) {
        requestedLimit = TGStatusChatPreviewInitialLimit;
    } else if (requestedLimit > TGStatusChatPreviewMaximumLimit) {
        requestedLimit = TGStatusChatPreviewMaximumLimit;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSArray *items = [client mainChatPreviewItemsWithLimit:requestedLimit timeout:10.0 error:&chatError];
        BOOL chatsExhausted = [client mainChatListExhausted];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (itemsCopy) {
                self.chatPreviewLimit = [itemsCopy count];
                self.chatsExhausted = chatsExhausted;
                [self applyChatItems:itemsCopy preserveSelection:preserveSelection preferredChatID:preferredChatID];
                if (interactive) {
                    [self.statusField setStringValue:@"TDLib chats: loaded"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu chat previews (limit %lu)", (unsigned long)[itemsCopy count], (unsigned long)requestedLimit]];
                    if (self.chatsExhausted) {
                        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
                    }
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = chatErrorMessage ? @"Chat preview request failed. Check TDLib state and try again." : @"Chat list did not return a result.";
                    [self.statusField setStringValue:@"TDLib chats: unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: chat preview refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundChatRefreshInFlight = NO;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
            [preferredChatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadMessagesForChatID:(NSNumber *)chatID interactive:(BOOL)interactive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !chatID) {
        if (interactive) {
            [self appendDetail:@"Select a chat after TDLib auth state is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"TDLib messages: loading..."];
        [self appendDetail:@"Loading recent message previews from TDLib..."];
    } else {
        self.backgroundMessageRefreshInFlight = YES;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatIDCopy limit:TGMessagePreviewInitialLimit timeout:8.0 error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            if (!selectionStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
                }
            } else if (itemsCopy) {
                BOOL preserveOlder = (!interactive && [self.messageItems count] > 0);
                [self applyRecentMessageItems:itemsCopy preservingOlderItems:preserveOlder];
                if (interactive) {
                    [self.statusField setStringValue:@"TDLib messages: loaded"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = messageErrorMessage ? @"Message preview request failed. Check TDLib state and try again." : @"Message history did not return a result.";
                    [self.statusField setStringValue:@"TDLib messages: unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: selected chat refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            BOOL shouldPrefillOlderMessages = (selectionStillCurrent && itemsCopy && [self messageHistoryNeedsPrefill]);
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundMessageRefreshInFlight = NO;
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (shouldPrefillOlderMessages) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:TGMessagePrefillMaxAttempts];
            } else if (!interactive) {
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [chatIDCopy release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadOlderMessagesInteractive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after TDLib auth state is ready."];
        return;
    }

    if (self.backgroundMessageRefreshInFlight) {
        [self appendDetail:@"TDLib messages: wait for the current message load to finish."];
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [self appendDetail:@"TDLib messages: load recent messages before requesting older history."];
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib messages: loading older..."];
    [self appendDetail:@"Loading older message previews from TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale older-history result for previous chat selection."];
            } else if (itemsCopy) {
                NSUInteger added = [self appendOlderMessageItems:itemsCopy];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added == 0) {
                    self.autoOlderMessagesLoadArmed = NO;
                }
                [self.statusField setStringValue:(added > 0) ? @"TDLib messages: older loaded" : @"TDLib messages: no older items"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: appended %lu older previews", (unsigned long)added]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib older message previews appended: %lu", (unsigned long)added]];
            } else {
                [self.statusField setStringValue:@"TDLib messages: older unavailable"];
                NSString *message = messageErrorMessage ? messageErrorMessage : @"Older message history did not return a result.";
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib older message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [self handlePendingLiveRefreshesIfPossible];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)handlePendingLiveRefreshesIfPossible {
    if (self.controlsBusy || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    if (self.pendingLiveMessageRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && self.selectedChatID) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.pendingLiveMessageRefresh = NO;
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }

    if (self.pendingLiveChatRefresh && !self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = NO;
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)pollLiveUpdates:(NSTimer *)timer {
    (void)timer;
    if (!self.client) {
        return;
    }

    NSArray *updates = [self.client drainSafeUpdateSummaries];
    if ([updates count] == 0) {
        return;
    }

    NSNumber *selectedChatID = [self.selectedChatID retain];
    NSString *latestAuthorizationState = nil;
    BOOL needsChatRefresh = NO;
    BOOL needsMessageRefresh = NO;

    NSUInteger index = 0;
    for (index = 0; index < [updates count]; index++) {
        NSDictionary *summary = [updates objectAtIndex:index];
        if (![summary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *kind = [summary objectForKey:@"kind"];
        if ([kind isEqualToString:@"authorization"]) {
            NSString *state = [summary objectForKey:@"state"];
            if ([state length] > 0) {
                latestAuthorizationState = state;
            }
            continue;
        }

        if ([kind isEqualToString:@"new_message"] || [kind isEqualToString:@"chat_update"]) {
            needsChatRefresh = YES;
            self.chatsExhausted = NO;
            [self.client invalidateMainChatListExhaustion];
            id chatID = [summary objectForKey:@"chat_id"];
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsMessageRefresh = YES;
            }
        }
    }

    if ([latestAuthorizationState length] > 0 && ![latestAuthorizationState isEqualToString:self.currentAuthState]) {
        [self updateAuthControlsForState:latestAuthorizationState];
    }

    if (needsChatRefresh) {
        self.pendingLiveChatRefresh = YES;
    }
    if (needsMessageRefresh) {
        self.pendingLiveMessageRefresh = YES;
    }

    [selectedChatID release];
    [self handlePendingLiveRefreshesIfPossible];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib status: checking..."];
    [self appendDetail:@"Checking TDLib JSON interface..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *parametersError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:&parametersError];
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];
        NSString *receiverSummary = [[client receiverStatusSummary] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (probeSummary) {
                [self.statusField setStringValue:@"TDLib status: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (receiverSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib receiver: %@", receiverSummary]];
                }
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", [parametersError localizedDescription]]];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self.statusField setStringValue:@"TDLib status: unavailable"];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [receiverSummary release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Auth input is not available for the current TDLib state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPhoneNumber"] ? self.authTextField : self.authSecureField;
    NSString *input = [[inputField stringValue] copy];
    [inputField setStringValue:@""];
    if ([input length] == 0) {
        [input release];
        [state release];
        [self appendDetail:@"Auth input is empty."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib auth: submitting..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (authSummary) {
                [self.statusField setStringValue:@"TDLib auth: submitted"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"TDLib auth: needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
            } else {
                [self updateAuthControlsForState:state];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    [self reloadChatsInteractive:YES preserveSelection:YES];
}

- (void)loadMoreChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    if (self.chatsExhausted) {
        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }
    if (nextLimit == self.chatPreviewLimit) {
        [self appendDetail:@"TDLib chats: maximum preview limit reached for this build."];
        return;
    }
    [self reloadChatsInteractive:YES preserveSelection:YES requestedLimit:nextLimit];
}

- (void)loadMessages:(id)sender {
    (void)sender;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self reloadMessagesForChatID:self.selectedChatID interactive:YES];
}

- (void)loadOlderMessages:(id)sender {
    (void)sender;
    [self reloadOlderMessagesInteractive];
}

- (void)sendMessage:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after TDLib auth state is ready before sending."];
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] == 0) {
        [self appendDetail:@"Message text is empty."];
        [self updateSendControls];
        return;
    }
    if ([text length] > 4096) {
        [self appendDetail:@"Message text is too long for this spike."];
        [self updateSendControls];
        return;
    }

    NSString *chatTitle = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"selected chat";
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Send real Telegram message?"];
    [alert setInformativeText:[NSString stringWithFormat:@"This will send the current text field contents to \"%@\". This is not a dry run.", chatTitle]];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Send"];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSString *messageText = [text copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib send: sending..."];
    [self appendDetail:@"Submitting text message to TDLib..."];
    [[TGLogger sharedLogger] log:@"TDLib text message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSString *sendSummary = [client sendTextMessageToChatID:chatID text:messageText timeout:8.0 error:&sendError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        BOOL sendSucceeded = ([sendSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]);
            if (sendSucceeded) {
                [self.statusField setStringValue:@"TDLib send: accepted"];
                [self appendDetail:@"TDLib send: text message accepted by TDLib."];
                [[TGLogger sharedLogger] log:@"TDLib text message send accepted."];
                if (selectionStillCurrent) {
                    [self.sendTextField setStringValue:@""];
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                [self.statusField setStringValue:@"TDLib send: not confirmed"];
                [self appendDetail:@"TDLib send: text message was not confirmed. Do not retry automatically; it may or may not have been sent."];
                [[TGLogger sharedLogger] log:@"TDLib text message send not confirmed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (sendSucceeded && selectionStillCurrent) {
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [authorizationState release];
            [chatID release];
            [messageText release];
        });

        [client release];
        [pool drain];
    });
}

- (void)dealloc {
    [self stopLiveUpdateTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_messageTableView setDataSource:nil];
    [_messageTableView setDelegate:nil];
    [_sendTextField setDelegate:nil];
    [_topPanelView release];
    [_sidebarPanelView release];
    [_conversationPanelView release];
    [_diagnosticsPanelView release];
    [_diagnosticsLabel release];
    [_titleField release];
    [_statusField release];
    [_detailsScrollView release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_loadMoreChatsButton release];
    [_loadMessagesButton release];
    [_loadOlderMessagesButton release];
    [_quitButton release];
    [_sendLabel release];
    [_sendTextField release];
    [_sendMessageButton release];
    [_authLabel release];
    [_authStateField release];
    [_authTextField release];
    [_authSecureField release];
    [_authButton release];
    [_chatsLabel release];
    [_messagesLabel release];
    [_selectedChatField release];
    [_chatScrollView release];
    [_chatTableView release];
    [_chatItems release];
    [_messageScrollView release];
    [_messageTableView release];
    [_messageItems release];
    [_selectedChatID release];
    [_selectedChatTitle release];
    [_client release];
    [_currentAuthState release];
    [_liveUpdateTimer release];
    [super dealloc];
}

@end
