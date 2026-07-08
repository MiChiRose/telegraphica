#import "TGStatusWindowController.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSScrollView *detailsScrollView;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSButton *loadMessagesButton;
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
@end

@implementation TGStatusWindowController

@synthesize statusField = _statusField;
@synthesize titleField = _titleField;
@synthesize detailsScrollView = _detailsScrollView;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize loadMessagesButton = _loadMessagesButton;
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

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 760, 720);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window setMinSize:NSMakeSize(700, 720)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [[self window] setDelegate:self];
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
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

    self.titleField = [self labelWithFrame:NSMakeRect(24, 668, 712, 28)
                                      text:@"Telegraphica core spike"
                                      font:[NSFont boldSystemFontOfSize:18.0]];
    [contentView addSubview:self.titleField];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 636, 712, 22)
                                       text:@"TDLib status: not checked"
                                       font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.statusField];

    self.detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.detailsScrollView setBorderType:NSBezelBorder];
    [self.detailsScrollView setHasVerticalScroller:YES];
    [self.detailsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[self.detailsScrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setString:@"Ready. Place libtdjson.dylib in Contents/Frameworks or set TELEGRAPHICA_TDJSON_PATH, then check the core.\n"];
    [self.detailsScrollView setDocumentView:self.detailsView];
    [contentView addSubview:self.detailsScrollView];

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
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 366, 116, 32)] autorelease];
    [self.authButton setTitle:@"Send"];
    [self.authButton setBezelStyle:NSRoundedBezelStyle];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    self.chatsLabel = [self labelWithFrame:NSMakeRect(24, 338, 76, 22)
                                      text:@"Chats:"
                                      font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 332, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"Load Chats"];
    [self.loadChatsButton setBezelStyle:NSRoundedBezelStyle];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    self.chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollView setBorderType:NSBezelBorder];
    [self.chatScrollView setHasVerticalScroller:YES];
    [self.chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[self.chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Chat"];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    NSTableColumn *typeColumn = [[[NSTableColumn alloc] initWithIdentifier:@"type"] autorelease];
    [[typeColumn headerCell] setStringValue:@"Type"];
    [typeColumn setWidth:130.0];
    [self.chatTableView addTableColumn:typeColumn];

    NSTableColumn *unreadColumn = [[[NSTableColumn alloc] initWithIdentifier:@"unread_count"] autorelease];
    [[unreadColumn headerCell] setStringValue:@"Unread"];
    [unreadColumn setWidth:80.0];
    [self.chatTableView addTableColumn:unreadColumn];

    [self.chatScrollView setDocumentView:self.chatTableView];
    [contentView addSubview:self.chatScrollView];

    self.messagesLabel = [self labelWithFrame:NSMakeRect(24, 198, 86, 22)
                                         text:@"Messages:"
                                         font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.messagesLabel];

    self.loadMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(116, 192, 136, 32)] autorelease];
    [self.loadMessagesButton setTitle:@"Load Messages"];
    [self.loadMessagesButton setBezelStyle:NSRoundedBezelStyle];
    [self.loadMessagesButton setTarget:self];
    [self.loadMessagesButton setAction:@selector(loadMessages:)];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMessagesButton];

    self.selectedChatField = [self labelWithFrame:NSMakeRect(264, 198, 472, 22)
                                             text:@"select a chat"
                                             font:[NSFont systemFontOfSize:13.0]];
    [[self.selectedChatField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.selectedChatField];

    self.messageScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollView setBorderType:NSBezelBorder];
    [self.messageScrollView setHasVerticalScroller:YES];
    [self.messageScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    self.messageTableView = [[[NSTableView alloc] initWithFrame:[[self.messageScrollView contentView] bounds]] autorelease];
    [self.messageTableView setDataSource:self];
    [self.messageTableView setDelegate:self];
    [self.messageTableView setAllowsColumnReordering:NO];
    [self.messageTableView setAllowsMultipleSelection:NO];

    NSTableColumn *dateColumn = [[[NSTableColumn alloc] initWithIdentifier:@"date"] autorelease];
    [[dateColumn headerCell] setStringValue:@"Time"];
    [dateColumn setWidth:120.0];
    [self.messageTableView addTableColumn:dateColumn];

    NSTableColumn *directionColumn = [[[NSTableColumn alloc] initWithIdentifier:@"direction"] autorelease];
    [[directionColumn headerCell] setStringValue:@"Dir"];
    [directionColumn setWidth:54.0];
    [self.messageTableView addTableColumn:directionColumn];

    NSTableColumn *previewColumn = [[[NSTableColumn alloc] initWithIdentifier:@"preview"] autorelease];
    [[previewColumn headerCell] setStringValue:@"Message"];
    [previewColumn setWidth:500.0];
    [self.messageTableView addTableColumn:previewColumn];

    [self.messageScrollView setDocumentView:self.messageTableView];
    [contentView addSubview:self.messageScrollView];

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

    [self layoutContentView];
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 24.0;
    CGFloat contentWidth = width - (margin * 2.0);
    CGFloat top = height - 52.0;

    [self.titleField setFrame:NSMakeRect(margin, top, contentWidth, 28.0)];
    [self.statusField setFrame:NSMakeRect(margin, top - 32.0, contentWidth, 22.0)];
    [self.detailsScrollView setFrame:NSMakeRect(margin, top - 250.0, contentWidth, 202.0)];

    CGFloat authY = top - 286.0;
    [self.authLabel setFrame:NSMakeRect(margin, authY, 76.0, 22.0)];
    [self.authStateField setFrame:NSMakeRect(margin + 80.0, authY, contentWidth - 120.0, 22.0)];
    [self.authTextField setFrame:NSMakeRect(margin + 80.0, authY - 4.0, 240.0, 24.0)];
    [self.authSecureField setFrame:NSMakeRect(margin + 80.0, authY - 4.0, 240.0, 24.0)];
    [self.authButton setFrame:NSMakeRect(margin + 332.0, authY - 8.0, 116.0, 32.0)];

    CGFloat chatsY = authY - 36.0;
    [self.chatsLabel setFrame:NSMakeRect(margin, chatsY, 76.0, 22.0)];
    [self.loadChatsButton setFrame:NSMakeRect(margin + 80.0, chatsY - 6.0, 112.0, 32.0)];
    [self.chatScrollView setFrame:NSMakeRect(margin, chatsY - 106.0, contentWidth, 96.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"title"];
    if (chatColumn) {
        CGFloat chatWidth = contentWidth - 230.0;
        if (chatWidth < 240.0) {
            chatWidth = 240.0;
        }
        [chatColumn setWidth:chatWidth];
    }

    CGFloat messagesY = chatsY - 142.0;
    [self.messagesLabel setFrame:NSMakeRect(margin, messagesY, 86.0, 22.0)];
    [self.loadMessagesButton setFrame:NSMakeRect(margin + 92.0, messagesY - 6.0, 136.0, 32.0)];
    [self.selectedChatField setFrame:NSMakeRect(margin + 240.0, messagesY, contentWidth - 240.0, 22.0)];

    CGFloat bottomButtonsTop = 64.0;
    CGFloat messageHeight = messagesY - bottomButtonsTop - 10.0;
    if (messageHeight < 110.0) {
        messageHeight = 110.0;
    }
    [self.messageScrollView setFrame:NSMakeRect(margin, bottomButtonsTop, contentWidth, messageHeight)];
    NSTableColumn *previewColumn = [self.messageTableView tableColumnWithIdentifier:@"preview"];
    if (previewColumn) {
        CGFloat previewWidth = contentWidth - 200.0;
        if (previewWidth < 320.0) {
            previewWidth = 320.0;
        }
        [previewColumn setWidth:previewWidth];
    }

    [self.checkButton setFrame:NSMakeRect(margin, 20.0, 140.0, 32.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutContentView];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (void)updateAuthControlsForState:(NSString *)state {
    self.currentAuthState = state;
    [self.authTextField setStringValue:@""];
    [self.authSecureField setStringValue:@""];
    [self.loadChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        [self.selectedChatField setStringValue:@"select a chat"];
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
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && self.selectedChatID != nil)];
}

- (void)setControlsBusy:(BOOL)busy {
    [self.checkButton setEnabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil)];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
    } else {
        [self updateAuthControlsForState:self.currentAuthState];
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

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    NSDictionary *item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = [item objectForKey:identifier];
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

    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        [self.selectedChatField setStringValue:@"select a chat"];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self updateAuthControlsForState:self.currentAuthState];
        return;
    }

    NSDictionary *item = [self.chatItems objectAtIndex:(NSUInteger)row];
    id chatID = [item objectForKey:@"chat_id"];
    id title = [item objectForKey:@"title"];
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        self.selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    } else {
        self.selectedChatID = nil;
    }
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"selected chat";
    [self.selectedChatField setStringValue:self.selectedChatTitle ? self.selectedChatTitle : @"selected chat"];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self updateAuthControlsForState:self.currentAuthState];
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
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Chats are available only after TDLib auth state is ready."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib chats: loading..."];
    [self appendDetail:@"Loading main chat previews from TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSArray *items = [client mainChatPreviewItemsWithLimit:10 timeout:5.0 error:&chatError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (itemsCopy) {
                [self.chatItems removeAllObjects];
                [self.chatItems addObjectsFromArray:itemsCopy];
                [self.chatTableView deselectAll:nil];
                [self.chatTableView reloadData];
                self.selectedChatID = nil;
                self.selectedChatTitle = nil;
                [self.selectedChatField setStringValue:@"select a chat"];
                [self.messageItems removeAllObjects];
                [self.messageTableView reloadData];
                [self.statusField setStringValue:@"TDLib chats: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu chat previews", (unsigned long)[itemsCopy count]]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
            } else {
                NSString *message = chatErrorMessage ? @"Chat preview request failed. Check TDLib state and try again." : @"Chat list did not return a result.";
                [self.statusField setStringValue:@"TDLib chats: unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
        });

        [client release];
        [pool drain];
    });
}

- (void)loadMessages:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after TDLib auth state is ready."];
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib messages: loading..."];
    [self appendDetail:@"Loading recent message previews from TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatID limit:20 timeout:8.0 error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
            } else if (itemsCopy) {
                [self.messageItems removeAllObjects];
                [self.messageItems addObjectsFromArray:itemsCopy];
                [self.messageTableView reloadData];
                [self.statusField setStringValue:@"TDLib messages: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
            } else {
                NSString *message = messageErrorMessage ? @"Message preview request failed. Check TDLib state and try again." : @"Message history did not return a result.";
                [self.statusField setStringValue:@"TDLib messages: unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [chatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)dealloc {
    [[self window] setDelegate:nil];
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_messageTableView setDataSource:nil];
    [_messageTableView setDelegate:nil];
    [_titleField release];
    [_statusField release];
    [_detailsScrollView release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_loadMessagesButton release];
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
    [super dealloc];
}

@end
