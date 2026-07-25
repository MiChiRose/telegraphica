#import "TGChatLifecycleWindowController.h"

#import "../Core/TGTDLibClient.h"
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
@synthesize inviteField = _inviteField;
@synthesize joinButton = _joinButton;
@synthesize contacts = _contacts;
@synthesize filteredContacts = _filteredContacts;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 520)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.contacts = [NSArray array];
        self.filteredContacts = [NSArray array];
        [[self window] setTitle:TGLoc(@"contacts.title")];
        [[self window] setMinSize:NSMakeSize(440, 440)];
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

    NSTextField *title = [self labelWithFrame:NSMakeRect(20, 480, 340, 24)
                                         font:[NSFont boldSystemFontOfSize:18.0]
                                        color:TGClassicInkColor()];
    [title setStringValue:TGLoc(@"contacts.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    self.searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(20, 442, 390, 28)] autorelease];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"contacts.search")];
    [self.searchField setDelegate:(id)self];
    [self.searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.searchField];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(420, 440, 80, 32)] autorelease];
    [self.refreshButton setTitle:TGLoc(@"contacts.refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshContactsAction:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 170, 480, 262)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setAllowsMultipleSelection:NO];
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

    self.statusField = [self labelWithFrame:NSMakeRect(20, 142, 340, 20)
                                       font:[NSFont systemFontOfSize:12.0]
                                      color:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"contacts.loading")];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(354, 143, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];

    self.openButton = [[[NSButton alloc] initWithFrame:NSMakeRect(380, 136, 120, 30)] autorelease];
    [self.openButton setTitle:TGLoc(@"contacts.open")];
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openSelectedContact:)];
    [self.openButton setEnabled:NO];
    [self.openButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.openButton];

    NSBox *separator = [[[NSBox alloc] initWithFrame:NSMakeRect(20, 126, 480, 1)] autorelease];
    [separator setBoxType:NSBoxSeparator];
    [separator setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:separator];

    NSTextField *inviteLabel = [self labelWithFrame:NSMakeRect(20, 96, 480, 20)
                                               font:[NSFont boldSystemFontOfSize:13.0]
                                              color:TGClassicInkColor()];
    [inviteLabel setStringValue:TGLoc(@"contacts.inviteTitle")];
    [inviteLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:inviteLabel];

    self.inviteField = [[[NSTextField alloc] initWithFrame:NSMakeRect(20, 54, 354, 30)] autorelease];
    [[self.inviteField cell] setPlaceholderString:TGLoc(@"contacts.invitePlaceholder")];
    [self.inviteField setDelegate:self];
    [self.inviteField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.inviteField];

    self.joinButton = [[[NSButton alloc] initWithFrame:NSMakeRect(380, 52, 120, 32)] autorelease];
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
    [self.openButton setEnabled:(!loading && [self.tableView selectedRow] >= 0)];
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
    [self.openButton setEnabled:NO];
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
    [self.openButton setEnabled:(!self.loading && [self.tableView selectedRow] >= 0)];
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
