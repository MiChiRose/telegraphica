#import "TGChatLifecycleWindowController.h"

#import "../Core/TGTDLibClient.h"
#import "TGConversationCreationPrompt.h"
#import "TGLocalization.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

static NSString *TGContactSubtitle(NSDictionary *contact) {
    NSString *username = [contact objectForKey:@"username"];
    NSString *phone = [contact objectForKey:@"phone_number"];
    NSMutableArray *parts = [NSMutableArray array];
    if ([username length] > 0) {
        [parts addObject:[NSString stringWithFormat:@"@%@", username]];
    } else if ([phone length] > 0) {
        [parts addObject:[NSString stringWithFormat:@"+%@", phone]];
    }
    if ([[contact objectForKey:@"is_bot"] boolValue]) {
        [parts addObject:TGLoc(@"contacts.bot")];
    } else if ([[contact objectForKey:@"is_online"] boolValue]) {
        [parts addObject:TGLoc(@"contacts.online")];
    }
    return [parts componentsJoinedByString:@" · "];
}

@interface TGChatLifecycleWindowController ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSSearchField *searchField;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *openButton;
@property (nonatomic, retain) NSButton *groupButton;
@property (nonatomic, retain) NSButton *secretButton;
@property (nonatomic, retain) NSButton *channelButton;
@property (nonatomic, retain) NSTextField *inviteField;
@property (nonatomic, retain) NSButton *joinButton;
@property (nonatomic, copy) NSArray *contacts;
@property (nonatomic, copy) NSArray *filteredContacts;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGChatLifecycleWindowController

@synthesize delegate = _delegate;
@synthesize client = _client;
@synthesize searchField = _searchField;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize refreshButton = _refreshButton;
@synthesize openButton = _openButton;
@synthesize groupButton = _groupButton;
@synthesize secretButton = _secretButton;
@synthesize channelButton = _channelButton;
@synthesize inviteField = _inviteField;
@synthesize joinButton = _joinButton;
@synthesize contacts = _contacts;
@synthesize filteredContacts = _filteredContacts;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 560)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.contacts = [NSArray array];
        self.filteredContacts = [NSArray array];
        [[self window] setTitle:TGLoc(@"contacts.title")];
        [[self window] setMinSize:NSMakeSize(540, 500)];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [_client release];
    [_searchField release];
    [_tableView release];
    [_statusField release];
    [_spinner release];
    [_refreshButton release];
    [_openButton release];
    [_groupButton release];
    [_secretButton release];
    [_channelButton release];
    [_inviteField release];
    [_joinButton release];
    [_contacts release];
    [_filteredContacts release];
    [super dealloc];
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setFont:font];
    [label setTextColor:color];
    [[label cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return label;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(20, 520, 350, 24)
                                         font:[NSFont boldSystemFontOfSize:18.0]
                                        color:TGClassicInkColor()];
    [title setStringValue:TGLoc(@"contacts.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    self.channelButton = [[[NSButton alloc] initWithFrame:NSMakeRect(376, 514, 114, 32)] autorelease];
    [self.channelButton setTitle:TGLoc(@"create.channel")];
    [self.channelButton setTarget:self];
    [self.channelButton setAction:@selector(createChannel:)];
    [self.channelButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.channelButton];

    self.searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(20, 482, 470, 28)] autorelease];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"contacts.search")];
    [self.searchField setDelegate:(id)self];
    [self.searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.searchField];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(500, 480, 80, 32)] autorelease];
    [self.refreshButton setTitle:TGLoc(@"contacts.refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshContactsAction:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 170, 560, 302)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setAllowsMultipleSelection:YES];
    [self.tableView setRowHeight:32.0];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(openSelectedContact:)];
    NSTableColumn *nameColumn = [[[NSTableColumn alloc] initWithIdentifier:@"name"] autorelease];
    [[nameColumn headerCell] setStringValue:TGLoc(@"contacts.name")];
    [nameColumn setWidth:255.0];
    [self.tableView addTableColumn:nameColumn];
    NSTableColumn *detailsColumn = [[[NSTableColumn alloc] initWithIdentifier:@"details"] autorelease];
    [[detailsColumn headerCell] setStringValue:TGLoc(@"contacts.details")];
    [detailsColumn setWidth:205.0];
    [self.tableView addTableColumn:detailsColumn];
    [scrollView setDocumentView:self.tableView];
    [root addSubview:scrollView];

    self.statusField = [self labelWithFrame:NSMakeRect(20, 142, 190, 20)
                                       font:[NSFont systemFontOfSize:12.0]
                                      color:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"contacts.loading")];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(196, 143, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];

    self.groupButton = [[[NSButton alloc] initWithFrame:NSMakeRect(220, 136, 110, 30)] autorelease];
    [self.groupButton setTitle:TGLoc(@"create.group")];
    [self.groupButton setTarget:self];
    [self.groupButton setAction:@selector(createGroup:)];
    [self.groupButton setEnabled:NO];
    [self.groupButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.groupButton];

    self.secretButton = [[[NSButton alloc] initWithFrame:NSMakeRect(340, 136, 110, 30)] autorelease];
    [self.secretButton setTitle:TGLoc(@"create.secret")];
    [self.secretButton setTarget:self];
    [self.secretButton setAction:@selector(createSecretChat:)];
    [self.secretButton setEnabled:NO];
    [self.secretButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.secretButton];

    self.openButton = [[[NSButton alloc] initWithFrame:NSMakeRect(460, 136, 120, 30)] autorelease];
    [self.openButton setTitle:TGLoc(@"contacts.open")];
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openSelectedContact:)];
    [self.openButton setEnabled:NO];
    [self.openButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.openButton];

    NSBox *separator = [[[NSBox alloc] initWithFrame:NSMakeRect(20, 126, 560, 1)] autorelease];
    [separator setBoxType:NSBoxSeparator];
    [separator setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:separator];

    NSTextField *inviteLabel = [self labelWithFrame:NSMakeRect(20, 96, 560, 20)
                                               font:[NSFont boldSystemFontOfSize:13.0]
                                              color:TGClassicInkColor()];
    [inviteLabel setStringValue:TGLoc(@"contacts.inviteTitle")];
    [inviteLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:inviteLabel];

    self.inviteField = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 54, 434, 30)] autorelease];
    [[self.inviteField cell] setPlaceholderString:TGLoc(@"contacts.invitePlaceholder")];
    [self.inviteField setDelegate:self];
    [self.inviteField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.inviteField];

    self.joinButton = [[[NSButton alloc] initWithFrame:NSMakeRect(460, 52, 120, 32)] autorelease];
    [self.joinButton setTitle:TGLoc(@"contacts.join")];
    [self.joinButton setTarget:self];
    [self.joinButton setAction:@selector(joinInviteLink:)];
    [self.joinButton setEnabled:NO];
    [self.joinButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.joinButton];
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    [self.refreshButton setEnabled:!loading];
    [self.searchField setEnabled:!loading];
    [self.tableView setEnabled:!loading];
    [self.channelButton setEnabled:!loading];
    [self updateSelectionActions];
    NSString *link = [[self.inviteField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.joinButton setEnabled:(!loading && [link length] > 0)];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
}

- (void)refreshContactsAction:(id)sender {
    (void)sender;
    [self refreshContacts];
}

- (void)refreshContacts {
    if (self.loading) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"contacts.loading")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *contactsError = nil;
        NSArray *contacts = [[client contactSummariesWithTimeout:10.0 error:&contactsError] copy];
        NSString *errorMessage = [[contactsError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == controller.requestGeneration) {
                [controller setLoading:NO];
                if (contacts) {
                    controller.contacts = contacts;
                    [controller applySearchFilter];
                } else {
                    controller.contacts = [NSArray array];
                    controller.filteredContacts = [NSArray array];
                    [controller.tableView reloadData];
                    [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                    [controller.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"contacts.error"))];
                }
            }
            [contacts release];
            [errorMessage release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
}

- (void)applySearchFilter {
    NSString *query = [[[self.searchField stringValue] stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([query length] == 0) {
        self.filteredContacts = self.contacts;
    } else {
        NSMutableArray *matches = [NSMutableArray array];
        NSUInteger index = 0;
        for (index = 0; index < [self.contacts count]; index++) {
            NSDictionary *contact = [self.contacts objectAtIndex:index];
            NSString *haystack = [[NSString stringWithFormat:@"%@ %@ %@",
                                    [contact objectForKey:@"display_name"] ? [contact objectForKey:@"display_name"] : @"",
                                    [contact objectForKey:@"username"] ? [contact objectForKey:@"username"] : @"",
                                    [contact objectForKey:@"phone_number"] ? [contact objectForKey:@"phone_number"] : @""]
                                   lowercaseString];
            if ([haystack rangeOfString:query].location != NSNotFound) {
                [matches addObject:contact];
            }
        }
        self.filteredContacts = matches;
    }
    [self.tableView reloadData];
    [self updateSelectionActions];
    NSString *status = nil;
    if ([self.filteredContacts count] == 0) {
        status = ([self.contacts count] == 0) ? TGLoc(@"contacts.empty") : TGLoc(@"contacts.noResults");
    } else {
        status = [NSString stringWithFormat:TGLoc(@"contacts.count"), (unsigned long)[self.filteredContacts count]];
    }
    [self.statusField setStringValue:status];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.filteredContacts count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;
    if (row < 0 || (NSUInteger)row >= [self.filteredContacts count]) {
        return @"";
    }
    NSDictionary *contact = [self.filteredContacts objectAtIndex:(NSUInteger)row];
    return [[column identifier] isEqualToString:@"name"] ? [contact objectForKey:@"display_name"] : TGContactSubtitle(contact);
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateSelectionActions];
}

- (NSArray *)selectedContacts {
    NSMutableArray *selected = [NSMutableArray array];
    NSIndexSet *indexes = [self.tableView selectedRowIndexes];
    NSUInteger index = [indexes firstIndex];
    while (index != NSNotFound) {
        if (index < [self.filteredContacts count]) {
            [selected addObject:[self.filteredContacts objectAtIndex:index]];
        }
        index = [indexes indexGreaterThanIndex:index];
    }
    return selected;
}

- (void)updateSelectionActions {
    NSArray *selected = [self selectedContacts];
    BOOL oneSelected = ([selected count] == 1);
    BOOL isBot = oneSelected && [[[selected objectAtIndex:0] objectForKey:@"is_bot"] boolValue];
    [self.openButton setEnabled:(!self.loading && oneSelected)];
    [self.secretButton setEnabled:(!self.loading && oneSelected && !isBot)];
    [self.groupButton setEnabled:(!self.loading && [selected count] > 0)];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.searchField) {
        [self applySearchFilter];
    } else if ([notification object] == self.inviteField) {
        NSString *link = [[self.inviteField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self.joinButton setEnabled:(!self.loading && [link length] > 0)];
    }
}

- (void)openSelectedContact:(id)sender {
    (void)sender;
    NSInteger row = [self.tableView selectedRow];
    if (self.loading || row < 0 || (NSUInteger)row >= [self.filteredContacts count]) {
        return;
    }
    NSDictionary *contact = [[self.filteredContacts objectAtIndex:(NSUInteger)row] retain];
    NSNumber *userID = [[contact objectForKey:@"user_id"] retain];
    NSString *title = [[contact objectForKey:@"display_name"] copy];
    [self setLoading:YES];
    [self.statusField setStringValue:TGLoc(@"contacts.opening")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSNumber *chatID = [[client privateChatIDForUserID:userID timeout:8.0 error:&chatError] retain];
        NSString *errorMessage = [[chatError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller setLoading:NO];
            if (chatID) {
                [controller.statusField setStringValue:TGLoc(@"contacts.opened")];
                [controller.delegate chatLifecycleWindowController:controller didOpenChatID:chatID title:title];
            } else {
                [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                [controller.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"contacts.error"))];
            }
            [chatID release];
            [errorMessage release];
            [client release];
            [controller release];
            [userID release];
            [title release];
            [contact release];
        });
        [pool drain];
    });
}

- (void)completeCreationWithChatID:(NSNumber *)chatID title:(NSString *)title errorMessage:(NSString *)errorMessage {
    [self setLoading:NO];
    if (chatID) {
        [self.statusField setTextColor:TGClassicMutedInkColor()];
        [self.statusField setStringValue:TGLoc(@"create.created")];
        [self.delegate chatLifecycleWindowController:self didOpenChatID:chatID title:title];
    } else {
        [self.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
        [self.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"create.error"))];
    }
}

- (void)createGroup:(id)sender {
    (void)sender;
    NSArray *selected = [[self selectedContacts] retain];
    if (self.loading || [selected count] == 0) {
        [selected release];
        return;
    }
    NSString *title = nil;
    if (![TGConversationCreationPrompt runGroupPromptWithMemberCount:[selected count] title:&title]) {
        [selected release];
        return;
    }
    NSMutableArray *userIDs = [NSMutableArray array];
    NSDictionary *contact = nil;
    for (contact in selected) {
        id userID = [contact objectForKey:@"user_id"];
        if (userID) {
            [userIDs addObject:userID];
        }
    }
    NSArray *safeUserIDs = [userIDs copy];
    NSString *safeTitle = [title copy];
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"create.creatingGroup")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *creationError = nil;
        NSNumber *chatID = [[client basicGroupChatIDWithUserIDs:safeUserIDs title:safeTitle timeout:12.0 error:&creationError] retain];
        NSString *errorMessage = [[creationError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller completeCreationWithChatID:chatID title:safeTitle errorMessage:errorMessage];
            [chatID release];
            [errorMessage release];
            [safeUserIDs release];
            [safeTitle release];
            [selected release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
}

- (void)createSecretChat:(id)sender {
    (void)sender;
    NSArray *selected = [self selectedContacts];
    if (self.loading || [selected count] != 1) {
        return;
    }
    NSDictionary *contact = [selected objectAtIndex:0];
    NSNumber *userID = [[contact objectForKey:@"user_id"] retain];
    NSString *title = [[contact objectForKey:@"display_name"] copy];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[NSString stringWithFormat:TGLoc(@"create.secretConfirm"), title]];
    [alert setInformativeText:TGLoc(@"create.secretInfo")];
    [alert addButtonWithTitle:TGLoc(@"create.confirm")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        [userID release];
        [title release];
        return;
    }
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"create.creatingSecret")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *creationError = nil;
        NSNumber *chatID = [[client secretChatIDForUserID:userID timeout:12.0 error:&creationError] retain];
        NSString *errorMessage = [[creationError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller completeCreationWithChatID:chatID title:title errorMessage:errorMessage];
            [chatID release];
            [errorMessage release];
            [userID release];
            [title release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
}

- (void)createChannel:(id)sender {
    (void)sender;
    if (self.loading) {
        return;
    }
    NSString *title = nil;
    NSString *description = nil;
    if (![TGConversationCreationPrompt runChannelPromptWithTitle:&title description:&description]) {
        return;
    }
    NSString *safeTitle = [title copy];
    NSString *safeDescription = [description copy];
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"create.creatingChannel")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *creationError = nil;
        NSNumber *chatID = [[client supergroupChatIDWithTitle:safeTitle
                                                 description:safeDescription
                                                     channel:YES
                                                     timeout:12.0
                                                       error:&creationError] retain];
        NSString *errorMessage = [[creationError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller completeCreationWithChatID:chatID title:safeTitle errorMessage:errorMessage];
            [chatID release];
            [errorMessage release];
            [safeTitle release];
            [safeDescription release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
}

- (void)joinInviteLink:(id)sender {
    (void)sender;
    NSString *link = [[[self.inviteField stringValue] stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
    if (self.loading || [link length] == 0) {
        [link release];
        return;
    }
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"contacts.checkingInvite")];
    TGTDLibClient *client = [self.client retain];
    TGChatLifecycleWindowController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *checkError = nil;
        NSDictionary *summary = [[client chatInviteLinkSummary:link timeout:8.0 error:&checkError] retain];
        NSString *errorMessage = [[checkError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!summary) {
                [controller setLoading:NO];
                [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                [controller.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"contacts.invalidInvite"))];
                [summary release];
                [errorMessage release];
                [client release];
                [controller release];
                [link release];
                return;
            }
            NSString *title = [summary objectForKey:@"title"];
            NSNumber *memberCount = [summary objectForKey:@"member_count"];
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:[NSString stringWithFormat:TGLoc(@"contacts.joinConfirmTitle"), title]];
            [alert setInformativeText:([memberCount integerValue] > 0
                ? [NSString stringWithFormat:TGLoc(@"contacts.joinConfirmMembers"), (long)[memberCount integerValue]]
                : TGLoc(@"contacts.joinConfirm"))];
            [alert addButtonWithTitle:TGLoc(@"contacts.join")];
            [alert addButtonWithTitle:TGLoc(@"cancel")];
            if ([alert runModal] != NSAlertFirstButtonReturn) {
                [controller setLoading:NO];
                [controller.statusField setStringValue:TGLoc(@"contacts.joinCancelled")];
                [summary release];
                [errorMessage release];
                [client release];
                [controller release];
                [link release];
                return;
            }
            NSNumber *existingChatID = [summary objectForKey:@"chat_id"];
            if ([existingChatID respondsToSelector:@selector(longLongValue)] && [existingChatID longLongValue] != 0LL) {
                [controller setLoading:NO];
                [controller.statusField setStringValue:TGLoc(@"contacts.opened")];
                [controller.delegate chatLifecycleWindowController:controller didOpenChatID:existingChatID title:title];
                [summary release];
                [errorMessage release];
                [client release];
                [controller release];
                [link release];
                return;
            }
            [controller.statusField setStringValue:TGLoc(@"contacts.joining")];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSAutoreleasePool *joinPool = [[NSAutoreleasePool alloc] init];
                NSError *joinError = nil;
                NSNumber *chatID = [[client joinChatWithInviteLink:link timeout:10.0 error:&joinError] retain];
                NSString *joinErrorMessage = [[joinError localizedDescription] copy];
                NSString *chatTitle = [title copy];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [controller setLoading:NO];
                    if (chatID) {
                        [controller.statusField setStringValue:TGLoc(@"contacts.joined")];
                        [controller.delegate chatLifecycleWindowController:controller didOpenChatID:chatID title:chatTitle];
                    } else {
                        [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                        [controller.statusField setStringValue:([joinErrorMessage length] > 0 ? joinErrorMessage : TGLoc(@"contacts.error"))];
                    }
                    [chatID release];
                    [joinErrorMessage release];
                    [chatTitle release];
                    [summary release];
                    [errorMessage release];
                    [client release];
                    [controller release];
                    [link release];
                });
                [joinPool drain];
            });
        });
        [pool drain];
    });
}

- (void)focusInviteLink {
    [[self window] makeFirstResponder:self.inviteField];
}

@end
