#import "TGChatLifecycleWindowController.h"

#import "../Core/TGTDLibClient.h"
#import "TGConversationCreationPrompt.h"
#import "TGLocalization.h"
#import "TGMessageLayoutSupport.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewCells.h"
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

@interface TGChatLifecycleContactCell : TGRepresentedObjectCell
@end

@implementation TGChatLifecycleContactCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *contact = [[self representedObject] isKindOfClass:[NSDictionary class]]
        ? [self representedObject]
        : nil;
    if (!contact) {
        return;
    }
    BOOL highlighted = [self isHighlighted];
    NSString *name = [contact objectForKey:@"display_name"];
    NSString *subtitle = TGContactSubtitle(contact);
    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 10.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 36.0) / 2.0),
                                   36.0,
                                   36.0);
    NSString *avatarPath = [contact objectForKey:@"avatar_local_path"];
    TGDrawAvatarInRect(avatarPath, name, avatarRect, highlighted, [controlView isFlipped]);

    if ([[contact objectForKey:@"is_online"] boolValue]) {
        NSRect dotRect = NSMakeRect(NSMaxX(avatarRect) - 9.0, NSMinY(avatarRect) + 1.0, 8.0, 8.0);
        [[NSColor colorWithCalibratedRed:0.20 green:0.66 blue:0.31 alpha:1.0] set];
        [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];
    }

    CGFloat textX = NSMaxX(avatarRect) + 11.0;
    CGFloat textWidth = MAX(40.0, NSMaxX(cellFrame) - textX - 12.0);
    NSDictionary *nameAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                                    highlighted ? [NSColor whiteColor] : TGClassicCardInkColor(), NSForegroundColorAttributeName,
                                    nil];
    NSDictionary *subtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                        highlighted ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.80] : TGClassicCardMutedInkColor(), NSForegroundColorAttributeName,
                                        nil];
    [name drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 7.0, textWidth, 17.0) withAttributes:nameAttributes];
    [subtitle drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 25.0, textWidth, 15.0) withAttributes:subtitleAttributes];
}

@end

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
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 620)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.contacts = [NSArray array];
        self.filteredContacts = [NSArray array];
        [[self window] setTitle:TGLoc(@"contacts.title")];
        [[self window] setMinSize:NSMakeSize(560, 540)];
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

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 578, 420, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"contacts.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    self.searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(24, 536, 544, 30)] autorelease];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"contacts.search")];
    [self.searchField setDelegate:(id)self];
    [self.searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.searchField];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(580, 535, 36, 32)] autorelease];
    [self.refreshButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"↻"] autorelease]];
    [self.refreshButton setTitle:@"↻"];
    [self.refreshButton setToolTip:TGLoc(@"contacts.refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshContactsAction:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *contactsCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 190, 600, 332)] autorelease];
    [contactsCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:contactsCard];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(28, 198, 584, 316)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDrawsBackground:YES];
    [scrollView setBackgroundColor:TGClassicTablePaperColor()];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setAllowsMultipleSelection:YES];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:50.0];
    [self.tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.tableView setBackgroundColor:TGClassicTablePaperColor()];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(openSelectedContact:)];
    NSTableColumn *contactColumn = [[[NSTableColumn alloc] initWithIdentifier:@"contact"] autorelease];
    [contactColumn setWidth:560.0];
    [contactColumn setDataCell:[[[TGChatLifecycleContactCell alloc] initTextCell:@""] autorelease]];
    [self.tableView addTableColumn:contactColumn];
    [scrollView setDocumentView:self.tableView];
    [root addSubview:scrollView];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 164, 210, 18)
                                       font:[NSFont systemFontOfSize:12.0]
                                      color:TGClassicHeaderDetailTextColor(0.92)];
    [self.statusField setStringValue:TGLoc(@"contacts.loading")];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(236, 164, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.spinner];

    self.channelButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 124, 126, 32)] autorelease];
    [self.channelButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"create.channel")] autorelease]];
    [self.channelButton setTitle:TGLoc(@"create.channel")];
    [self.channelButton setTarget:self];
    [self.channelButton setAction:@selector(createChannel:)];
    [self.channelButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.channelButton];

    self.groupButton = [[[NSButton alloc] initWithFrame:NSMakeRect(158, 124, 126, 32)] autorelease];
    [self.groupButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"create.group")] autorelease]];
    [self.groupButton setTitle:TGLoc(@"create.group")];
    [self.groupButton setTarget:self];
    [self.groupButton setAction:@selector(createGroup:)];
    [self.groupButton setEnabled:NO];
    [self.groupButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.groupButton];

    self.secretButton = [[[NSButton alloc] initWithFrame:NSMakeRect(292, 124, 126, 32)] autorelease];
    [self.secretButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"create.secret")] autorelease]];
    [self.secretButton setTitle:TGLoc(@"create.secret")];
    [self.secretButton setTarget:self];
    [self.secretButton setAction:@selector(createSecretChat:)];
    [self.secretButton setEnabled:NO];
    [self.secretButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.secretButton];

    self.openButton = [[[NSButton alloc] initWithFrame:NSMakeRect(440, 124, 176, 32)] autorelease];
    [self.openButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"contacts.open")] autorelease]];
    [self.openButton setTitle:TGLoc(@"contacts.open")];
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openSelectedContact:)];
    [self.openButton setEnabled:NO];
    [self.openButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.openButton];

    TGGroupedCardView *inviteCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 18, 600, 94)] autorelease];
    [inviteCard setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:inviteCard];
    NSTextField *inviteLabel = [self labelWithFrame:NSMakeRect(34, 78, 560, 18)
                                               font:[NSFont boldSystemFontOfSize:13.0]
                                              color:TGClassicCardInkColor()];
    [inviteLabel setStringValue:TGLoc(@"contacts.inviteTitle")];
    [inviteLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:inviteLabel];

    self.inviteField = [[[NSTextField alloc] initWithFrame:NSMakeRect(34, 36, 438, 30)] autorelease];
    [[self.inviteField cell] setPlaceholderString:TGLoc(@"contacts.invitePlaceholder")];
    [self.inviteField setDelegate:self];
    [self.inviteField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.inviteField];

    self.joinButton = [[[NSButton alloc] initWithFrame:NSMakeRect(484, 34, 122, 32)] autorelease];
    [self.joinButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"contacts.join")] autorelease]];
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
    (void)column;
    if (row < 0 || (NSUInteger)row >= [self.filteredContacts count]) {
        return nil;
    }
    return [self.filteredContacts objectAtIndex:(NSUInteger)row];
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
