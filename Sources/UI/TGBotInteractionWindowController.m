#import "TGBotInteractionWindowController.h"

#import "../Core/TGChatItem.h"
#import "../Core/TGTDLibClient+Bots.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGBotInteractionWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *userID;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSArray *commands;
@property (nonatomic, copy) NSArray *results;
@property (nonatomic, copy) NSArray *targetChats;
@property (nonatomic, retain) NSNumber *queryID;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *descriptionField;
@property (nonatomic, retain) NSTableView *commandTableView;
@property (nonatomic, retain) NSTableView *resultTableView;
@property (nonatomic, retain) NSTextField *queryField;
@property (nonatomic, retain) NSPopUpButton *targetPopUpButton;
@property (nonatomic, retain) NSButton *commandButton;
@property (nonatomic, retain) NSButton *searchButton;
@property (nonatomic, retain) NSButton *resultButton;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, assign) BOOL loading;
@end

@implementation TGBotInteractionWindowController

@synthesize client = _client;
@synthesize userID = _userID;
@synthesize chatID = _chatID;
@synthesize commands = _commands;
@synthesize results = _results;
@synthesize targetChats = _targetChats;
@synthesize queryID = _queryID;
@synthesize titleField = _titleField;
@synthesize descriptionField = _descriptionField;
@synthesize commandTableView = _commandTableView;
@synthesize resultTableView = _resultTableView;
@synthesize queryField = _queryField;
@synthesize targetPopUpButton = _targetPopUpButton;
@synthesize commandButton = _commandButton;
@synthesize searchButton = _searchButton;
@synthesize resultButton = _resultButton;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize loading = _loading;

- (id)initWithClient:(TGTDLibClient *)client
              userID:(NSNumber *)userID
              chatID:(NSNumber *)chatID {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 600)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.userID = userID;
        self.chatID = chatID;
        self.commands = [NSArray array];
        self.results = [NSArray array];
        self.targetChats = [NSArray array];
        [[self window] setTitle:TGLoc(@"bot.window.title")];
        [[self window] setMinSize:NSMakeSize(660.0, 540.0)];
        [[self window] setMaxSize:NSMakeSize(940.0, 780.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_userID release];
    [_chatID release];
    [_commands release];
    [_results release];
    [_targetChats release];
    [_queryID release];
    [_titleField release];
    [_descriptionField release];
    [_commandTableView release];
    [_resultTableView release];
    [_queryField release];
    [_targetPopUpButton release];
    [_commandButton release];
    [_searchButton release];
    [_resultButton release];
    [_statusField release];
    [_spinner release];
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

- (NSTableView *)tableWithFrame:(NSRect)frame identifier:(NSString *)identifier root:(NSView *)root {
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
    [scroll setBorderType:NSNoBorder];
    [scroll setHasVerticalScroller:YES];
    [scroll setDrawsBackground:NO];
    NSTableView *table = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setWidth:NSWidth(frame) - 18.0];
    [table addTableColumn:column];
    [table setHeaderView:nil];
    [table setRowHeight:36.0];
    [table setDataSource:self];
    [table setDelegate:self];
    [table setTarget:self];
    [table setDoubleAction:(identifier && [identifier isEqualToString:@"command"])
                           ? @selector(sendCommandPressed:) : @selector(sendResultPressed:)];
    [scroll setDocumentView:table];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:scroll];
    return table;
}

- (NSButton *)buttonWithFrame:(NSRect)frame titleKey:(NSString *)key action:(SEL)action primary:(BOOL)primary {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    if (primary) {
        [button setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(key)] autorelease]];
    } else {
        [button setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(key)] autorelease]];
    }
    [button setTitle:TGLoc(key)];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 552, 672, 26)
                                      font:[NSFont boldSystemFontOfSize:20.0]
                                     color:TGClassicHeaderTextColor(1.0)];
    [self.titleField setStringValue:TGLoc(@"bot.window.title")];
    [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.titleField];

    self.descriptionField = [self labelWithFrame:NSMakeRect(26, 510, 666, 38)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderTextColor(0.82)];
    [[self.descriptionField cell] setWraps:YES];
    [[self.descriptionField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.descriptionField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.descriptionField];

    TGGroupedCardView *commandCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 294, 684, 204)] autorelease];
    [commandCard setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:commandCard];
    NSTextField *commandLabel = [self labelWithFrame:NSMakeRect(34, 462, 350, 18)
                                                font:[NSFont boldSystemFontOfSize:12.0]
                                               color:TGClassicCardInkColor()];
    [commandLabel setStringValue:TGLoc(@"bot.commands.title")];
    [commandLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:commandLabel];
    self.commandTableView = [self tableWithFrame:NSMakeRect(34, 336, 652, 120)
                                      identifier:@"command" root:root];
    [self.commandTableView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    self.commandButton = [self buttonWithFrame:NSMakeRect(520, 302, 166, 28)
                                     titleKey:@"bot.command.send" action:@selector(sendCommandPressed:) primary:YES];
    [self.commandButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.commandButton];

    TGGroupedCardView *inlineCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 50, 684, 232)] autorelease];
    [inlineCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:inlineCard];
    NSTextField *inlineLabel = [self labelWithFrame:NSMakeRect(34, 252, 280, 18)
                                               font:[NSFont boldSystemFontOfSize:12.0]
                                              color:TGClassicCardInkColor()];
    [inlineLabel setStringValue:TGLoc(@"bot.inline.title")];
    [inlineLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:inlineLabel];
    self.targetPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(334, 246, 220, 28) pullsDown:NO] autorelease];
    [self.targetPopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.targetPopUpButton];
    self.queryField = [[[NSTextField alloc] initWithFrame:NSMakeRect(34, 210, 520, 28)] autorelease];
    [[self.queryField cell] setPlaceholderString:TGLoc(@"bot.inline.placeholder")];
    [self.queryField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.queryField];
    self.searchButton = [self buttonWithFrame:NSMakeRect(564, 210, 122, 28)
                                     titleKey:@"search" action:@selector(searchPressed:) primary:NO];
    [self.searchButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.searchButton];
    self.resultTableView = [self tableWithFrame:NSMakeRect(34, 88, 652, 116)
                                     identifier:@"result" root:root];
    self.resultButton = [self buttonWithFrame:NSMakeRect(520, 56, 166, 28)
                                    titleKey:@"bot.inline.send" action:@selector(sendResultPressed:) primary:YES];
    [self.resultButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.resultButton];

    self.statusField = [self labelWithFrame:NSMakeRect(26, 24, 610, 18)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicHeaderTextColor(0.82)];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(666, 24, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)[(tableView == self.commandTableView ? self.commands : self.results) count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)column;
    NSArray *source = (tableView == self.commandTableView) ? self.commands : self.results;
    if (row < 0 || (NSUInteger)row >= [source count]) {
        return @"";
    }
    NSDictionary *item = [source objectAtIndex:(NSUInteger)row];
    if (tableView == self.commandTableView) {
        return [NSString stringWithFormat:@"/%@ — %@", [item objectForKey:@"command"],
                [[item objectForKey:@"description"] length] > 0 ? [item objectForKey:@"description"] : TGLoc(@"bot.command.noDescription")];
    }
    NSString *description = [item objectForKey:@"description"];
    return [description length] > 0
        ? [NSString stringWithFormat:@"%@ — %@", [item objectForKey:@"title"], description]
        : [item objectForKey:@"title"];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (void)setLoading:(BOOL)loading status:(NSString *)status {
    self.loading = loading;
    [self.statusField setStringValue:status ? status : @""];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
    [self updateControls];
}

- (NSNumber *)selectedTargetChatID {
    id represented = [[self.targetPopUpButton selectedItem] representedObject];
    return [represented isKindOfClass:[NSNumber class]] ? represented : self.chatID;
}

- (void)updateControls {
    [self.commandButton setEnabled:(!self.loading && [self.commandTableView selectedRow] >= 0)];
    [self.searchButton setEnabled:!self.loading];
    [self.resultButton setEnabled:(!self.loading && [self.resultTableView selectedRow] >= 0 &&
                                   [self.queryID longLongValue] != 0)];
    [self.targetPopUpButton setEnabled:!self.loading];
}

- (void)reloadBot {
    if (self.loading) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"bot.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *userID = [self.userID retain];
    NSNumber *defaultChatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client botInteractionSummaryForUserID:userID timeout:8.0 error:&error] retain];
        NSArray *chats = [[client mainChatPreviewItemsWithLimit:120 timeout:8.0 error:NULL] retain];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (summary) {
                [self.titleField setStringValue:[summary objectForKey:@"display_name"]];
                [self.descriptionField setStringValue:[[summary objectForKey:@"description"] length] > 0
                    ? [summary objectForKey:@"description"] : TGLoc(@"bot.noDescription")];
                self.commands = [summary objectForKey:@"commands"];
                self.targetChats = chats ? chats : [NSArray array];
                [self.targetPopUpButton removeAllItems];
                NSUInteger index = 0;
                NSInteger selectedIndex = -1;
                for (index = 0; index < [self.targetChats count]; index++) {
                    TGChatItem *chat = [self.targetChats objectAtIndex:index];
                    [self.targetPopUpButton addItemWithTitle:[[chat title] length] > 0 ? [chat title] : TGLoc(@"chat.untitled")];
                    [[self.targetPopUpButton lastItem] setRepresentedObject:[chat chatID]];
                    if ([[chat chatID] isEqualToNumber:defaultChatID]) {
                        selectedIndex = (NSInteger)index;
                    }
                }
                if (selectedIndex >= 0) {
                    [self.targetPopUpButton selectItemAtIndex:selectedIndex];
                }
                [self.commandTableView reloadData];
                [self setLoading:NO status:TGLoc(@"bot.ready")];
            } else {
                [self setLoading:NO status:([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable"))];
            }
            [summary release];
            [chats release];
            [errorMessage release];
            [client release];
            [userID release];
            [defaultChatID release];
        });
        [pool drain];
    });
}

- (void)sendCommandPressed:(id)sender {
    (void)sender;
    NSInteger row = [self.commandTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.commands count] || self.loading) {
        return;
    }
    NSString *command = [@"/" stringByAppendingString:[[self.commands objectAtIndex:(NSUInteger)row] objectForKey:@"command"]];
    [self setLoading:YES status:TGLoc(@"bot.command.sending")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSString *text = [command copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *result = [[client sendTextMessageToChatID:chatID text:text timeout:8.0 error:&error] copy];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:([result length] > 0 ? TGLoc(@"bot.command.sent") :
                                         ([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable")))];
            [result release];
            [errorMessage release];
            [client release];
            [chatID release];
            [text release];
        });
        [pool drain];
    });
}

- (void)searchPressed:(id)sender {
    (void)sender;
    NSString *query = [[self.queryField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0 || self.loading) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"bot.inline.searching")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *userID = [self.userID retain];
    NSNumber *chatID = [[self selectedTargetChatID] retain];
    NSString *queryCopy = [query copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *response = [[client inlineQueryResultsForBotUserID:userID chatID:chatID
                                                                   query:queryCopy offset:@"" timeout:10.0 error:&error] retain];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (response) {
                self.results = [response objectForKey:@"results"];
                self.queryID = [response objectForKey:@"query_id"];
                [self.resultTableView reloadData];
                [self setLoading:NO status:[NSString stringWithFormat:TGLoc(@"bot.inline.found"), (long)[self.results count]]];
            } else {
                self.results = [NSArray array];
                self.queryID = nil;
                [self.resultTableView reloadData];
                [self setLoading:NO status:([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable"))];
            }
            [response release];
            [errorMessage release];
            [client release];
            [userID release];
            [chatID release];
            [queryCopy release];
        });
        [pool drain];
    });
}

- (void)sendResultPressed:(id)sender {
    (void)sender;
    NSInteger row = [self.resultTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.results count] || self.loading) {
        return;
    }
    NSString *resultID = [[[self.results objectAtIndex:(NSUInteger)row] objectForKey:@"result_id"] copy];
    NSNumber *queryID = [self.queryID retain];
    NSNumber *chatID = [[self selectedTargetChatID] retain];
    TGTDLibClient *client = [self.client retain];
    [self setLoading:YES status:TGLoc(@"bot.inline.sending")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [client sendInlineQueryResultID:resultID queryID:queryID toChatID:chatID timeout:10.0 error:&error];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:(success ? TGLoc(@"bot.inline.sent") :
                                         ([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable")))];
            [errorMessage release];
            [resultID release];
            [queryID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

@end
