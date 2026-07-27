#import "TGChatAdministrationWindowController.h"

#import "../Core/TGTDLibClient+Administration.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

@interface TGChatAdministrationWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, retain) NSTableView *linksTableView;
@property (nonatomic, retain) NSTableView *requestsTableView;
@property (nonatomic, retain) NSTableView *eventsTableView;
@property (nonatomic, retain) NSTextField *linkNameField;
@property (nonatomic, retain) NSTextField *memberLimitField;
@property (nonatomic, retain) NSPopUpButton *expirationPopUpButton;
@property (nonatomic, retain) NSButton *joinRequestButton;
@property (nonatomic, retain) NSButton *createLinkButton;
@property (nonatomic, retain) NSButton *copyLinkButton;
@property (nonatomic, retain) NSButton *revokeLinkButton;
@property (nonatomic, retain) NSButton *approveButton;
@property (nonatomic, retain) NSButton *declineButton;
@property (nonatomic, retain) NSPopUpButton *slowModePopUpButton;
@property (nonatomic, retain) NSButton *applySlowModeButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSArray *inviteLinks;
@property (nonatomic, copy) NSArray *joinRequests;
@property (nonatomic, copy) NSArray *events;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGChatAdministrationWindowController

@synthesize client = _client;
@synthesize chatID = _chatID;
@synthesize chatTitle = _chatTitle;
@synthesize linksTableView = _linksTableView;
@synthesize requestsTableView = _requestsTableView;
@synthesize eventsTableView = _eventsTableView;
@synthesize linkNameField = _linkNameField;
@synthesize memberLimitField = _memberLimitField;
@synthesize expirationPopUpButton = _expirationPopUpButton;
@synthesize joinRequestButton = _joinRequestButton;
@synthesize createLinkButton = _createLinkButton;
@synthesize copyLinkButton = _copyLinkButton;
@synthesize revokeLinkButton = _revokeLinkButton;
@synthesize approveButton = _approveButton;
@synthesize declineButton = _declineButton;
@synthesize slowModePopUpButton = _slowModePopUpButton;
@synthesize applySlowModeButton = _applySlowModeButton;
@synthesize refreshButton = _refreshButton;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize inviteLinks = _inviteLinks;
@synthesize joinRequests = _joinRequests;
@synthesize events = _events;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client chatID:(NSNumber *)chatID title:(NSString *)title {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 650)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.chatID = chatID;
        self.chatTitle = title;
        self.inviteLinks = [NSArray array];
        self.joinRequests = [NSArray array];
        self.events = [NSArray array];
        [[self window] setTitle:TGLoc(@"admin.title")];
        [[self window] setMinSize:NSMakeSize(820.0, 600.0)];
        [[self window] setMaxSize:NSMakeSize(1100.0, 820.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_chatID release];
    [_chatTitle release];
    [_linksTableView release];
    [_requestsTableView release];
    [_eventsTableView release];
    [_linkNameField release];
    [_memberLimitField release];
    [_expirationPopUpButton release];
    [_joinRequestButton release];
    [_createLinkButton release];
    [_copyLinkButton release];
    [_revokeLinkButton release];
    [_approveButton release];
    [_declineButton release];
    [_slowModePopUpButton release];
    [_applySlowModeButton release];
    [_refreshButton release];
    [_statusField release];
    [_spinner release];
    [_inviteLinks release];
    [_joinRequests release];
    [_events release];
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

- (NSTableView *)tableInScrollViewWithFrame:(NSRect)frame
                                  identifier:(NSString *)identifier
                                        root:(NSView *)root {
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSNoBorder];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    NSTableView *table = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setWidth:NSWidth(frame) - 12.0];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [table addTableColumn:column];
    [table setHeaderView:nil];
    [table setRowHeight:30.0];
    [table setAllowsEmptySelection:YES];
    [table setDelegate:self];
    [table setDataSource:self];
    [scroll setDocumentView:table];
    [root addSubview:scroll];
    return table;
}

- (void)addPopupItem:(NSString *)title value:(NSNumber *)value toPopup:(NSPopUpButton *)popup {
    [popup addItemWithTitle:title];
    [[popup lastItem] setRepresentedObject:value];
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];
    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 602, 720, 28)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:[self.chatTitle length] > 0
        ? [NSString stringWithFormat:@"%@ — %@", TGLoc(@"admin.title"), self.chatTitle]
        : TGLoc(@"admin.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(788, 600, 88, 30)] autorelease];
    [self.refreshButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"refresh")] autorelease]];
    [self.refreshButton setTitle:TGLoc(@"refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshPressed:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *linksCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 336, 420, 248)] autorelease];
    [linksCard setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:linksCard];
    NSTextField *linksTitle = [self labelWithFrame:NSMakeRect(38, 554, 380, 18)
                                              font:[NSFont boldSystemFontOfSize:13.0]
                                             color:TGClassicCardInkColor()];
    [linksTitle setStringValue:TGLoc(@"admin.inviteLinks")];
    [linksTitle setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:linksTitle];
    self.linksTableView = [self tableInScrollViewWithFrame:NSMakeRect(34, 426, 392, 120)
                                                identifier:@"links"
                                                      root:root];
    self.linkNameField = [[[NSTextField alloc] initWithFrame:NSMakeRect(34, 394, 152, 24)] autorelease];
    [[self.linkNameField cell] setPlaceholderString:TGLoc(@"admin.linkName")];
    [self.linkNameField setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.linkNameField];
    self.expirationPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(190, 390, 112, 28) pullsDown:NO] autorelease];
    [self addPopupItem:TGLoc(@"admin.never") value:@0 toPopup:self.expirationPopUpButton];
    [self addPopupItem:TGLoc(@"privacy.time.day") value:@86400 toPopup:self.expirationPopUpButton];
    [self addPopupItem:TGLoc(@"privacy.time.week") value:@604800 toPopup:self.expirationPopUpButton];
    [self addPopupItem:TGLoc(@"privacy.time.month") value:@2678400 toPopup:self.expirationPopUpButton];
    [self.expirationPopUpButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.expirationPopUpButton];
    self.memberLimitField = [[[NSTextField alloc] initWithFrame:NSMakeRect(306, 394, 120, 24)] autorelease];
    [[self.memberLimitField cell] setPlaceholderString:TGLoc(@"admin.memberLimit")];
    [self.memberLimitField setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.memberLimitField];
    self.joinRequestButton = [[[NSButton alloc] initWithFrame:NSMakeRect(34, 362, 180, 22)] autorelease];
    [self.joinRequestButton setButtonType:NSSwitchButton];
    [self.joinRequestButton setTitle:TGLoc(@"admin.requiresApproval")];
    [self.joinRequestButton setFont:[NSFont systemFontOfSize:11.0]];
    [self.joinRequestButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.joinRequestButton];
    self.createLinkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(222, 358, 96, 28)] autorelease];
    [self.createLinkButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"admin.create")] autorelease]];
    [self.createLinkButton setTitle:TGLoc(@"admin.create")];
    [self.createLinkButton setTarget:self];
    [self.createLinkButton setAction:@selector(createLinkPressed:)];
    [self.createLinkButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.createLinkButton];
    self.copyLinkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(322, 358, 50, 28)] autorelease];
    [self.copyLinkButton setTitle:TGLoc(@"admin.copy")];
    [self.copyLinkButton setTarget:self];
    [self.copyLinkButton setAction:@selector(copyLinkPressed:)];
    [self.copyLinkButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.copyLinkButton];
    self.revokeLinkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(374, 358, 52, 28)] autorelease];
    [self.revokeLinkButton setTitle:TGLoc(@"admin.revoke")];
    [self.revokeLinkButton setTarget:self];
    [self.revokeLinkButton setAction:@selector(revokeLinkPressed:)];
    [self.revokeLinkButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.revokeLinkButton];

    TGGroupedCardView *requestsCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(452, 336, 428, 248)] autorelease];
    [requestsCard setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:requestsCard];
    NSTextField *requestsTitle = [self labelWithFrame:NSMakeRect(470, 554, 390, 18)
                                                 font:[NSFont boldSystemFontOfSize:13.0]
                                                color:TGClassicCardInkColor()];
    [requestsTitle setStringValue:TGLoc(@"admin.joinRequests")];
    [requestsTitle setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:requestsTitle];
    self.requestsTableView = [self tableInScrollViewWithFrame:NSMakeRect(466, 390, 400, 156)
                                                   identifier:@"requests"
                                                         root:root];
    self.declineButton = [[[NSButton alloc] initWithFrame:NSMakeRect(616, 354, 118, 30)] autorelease];
    [self.declineButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"admin.decline")] autorelease]];
    [self.declineButton setTitle:TGLoc(@"admin.decline")];
    [self.declineButton setTarget:self];
    [self.declineButton setAction:@selector(declinePressed:)];
    [self.declineButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.declineButton];
    self.approveButton = [[[NSButton alloc] initWithFrame:NSMakeRect(742, 354, 124, 30)] autorelease];
    [self.approveButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"admin.approve")] autorelease]];
    [self.approveButton setTitle:TGLoc(@"admin.approve")];
    [self.approveButton setTarget:self];
    [self.approveButton setAction:@selector(approvePressed:)];
    [self.approveButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.approveButton];

    TGGroupedCardView *eventsCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 54, 860, 266)] autorelease];
    [eventsCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:eventsCard];
    NSTextField *eventsTitle = [self labelWithFrame:NSMakeRect(38, 288, 300, 18)
                                               font:[NSFont boldSystemFontOfSize:13.0]
                                              color:TGClassicCardInkColor()];
    [eventsTitle setStringValue:TGLoc(@"admin.eventLog")];
    [eventsTitle setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:eventsTitle];
    self.eventsTableView = [self tableInScrollViewWithFrame:NSMakeRect(34, 104, 832, 176)
                                                 identifier:@"events"
                                                       root:root];
    NSTextField *slowLabel = [self labelWithFrame:NSMakeRect(38, 70, 110, 18)
                                             font:[NSFont systemFontOfSize:11.0]
                                            color:TGClassicCardInkColor()];
    [slowLabel setStringValue:TGLoc(@"admin.slowMode")];
    [slowLabel setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:slowLabel];
    self.slowModePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(148, 64, 166, 28) pullsDown:NO] autorelease];
    NSArray *delays = [NSArray arrayWithObjects:@0, @5, @10, @30, @60, @300, @900, @3600, nil];
    NSUInteger index = 0;
    for (index = 0; index < [delays count]; index++) {
        NSNumber *delay = [delays objectAtIndex:index];
        NSString *label = [delay integerValue] == 0
            ? TGLoc(@"privacy.time.off")
            : [NSString stringWithFormat:TGLoc(@"admin.seconds"), (long)[delay integerValue]];
        [self addPopupItem:label value:delay toPopup:self.slowModePopUpButton];
    }
    [self.slowModePopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.slowModePopUpButton];
    self.applySlowModeButton = [[[NSButton alloc] initWithFrame:NSMakeRect(322, 64, 138, 28)] autorelease];
    [self.applySlowModeButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applySlowModeButton setTitle:TGLoc(@"apply")];
    [self.applySlowModeButton setTarget:self];
    [self.applySlowModeButton setAction:@selector(applySlowModePressed:)];
    [self.applySlowModeButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.applySlowModeButton];
    self.statusField = [self labelWithFrame:NSMakeRect(474, 70, 360, 18)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicCardMutedInkColor()];
    [self.statusField setAlignment:NSRightTextAlignment];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(846, 70, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.linksTableView) {
        return (NSInteger)[self.inviteLinks count];
    }
    if (tableView == self.requestsTableView) {
        return (NSInteger)[self.joinRequests count];
    }
    return (NSInteger)[self.events count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)column;
    NSArray *source = tableView == self.linksTableView
        ? self.inviteLinks : (tableView == self.requestsTableView ? self.joinRequests : self.events);
    if (row < 0 || (NSUInteger)row >= [source count]) {
        return @"";
    }
    NSDictionary *item = [source objectAtIndex:(NSUInteger)row];
    if (tableView == self.linksTableView) {
        NSString *title = [item objectForKey:@"display_name"];
        return [[item objectForKey:@"revoked"] boolValue]
            ? [NSString stringWithFormat:@"%@ — %@", title, TGLoc(@"admin.revoked")]
            : title;
    }
    if (tableView == self.requestsTableView) {
        NSString *name = [item objectForKey:@"display_name"];
        NSString *bio = [item objectForKey:@"bio"];
        return [bio length] > 0 ? [NSString stringWithFormat:@"%@ — %@", name, bio] : name;
    }
    return [NSString stringWithFormat:@"%@ — %@", [item objectForKey:@"actor"], [item objectForKey:@"action"]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (NSDictionary *)selectedItemInTable:(NSTableView *)table source:(NSArray *)source {
    NSInteger row = [table selectedRow];
    return (row >= 0 && (NSUInteger)row < [source count]) ? [source objectAtIndex:(NSUInteger)row] : nil;
}

- (void)updateControls {
    BOOL enabled = !self.loading;
    NSDictionary *link = [self selectedItemInTable:self.linksTableView source:self.inviteLinks];
    NSDictionary *joinRequest = [self selectedItemInTable:self.requestsTableView source:self.joinRequests];
    [self.refreshButton setEnabled:enabled];
    [self.createLinkButton setEnabled:enabled];
    [self.copyLinkButton setEnabled:(enabled && [link objectForKey:@"invite_link"] != nil)];
    [self.revokeLinkButton setEnabled:(enabled && link && ![[link objectForKey:@"revoked"] boolValue])];
    [self.approveButton setEnabled:(enabled && joinRequest != nil)];
    [self.declineButton setEnabled:(enabled && joinRequest != nil)];
    [self.slowModePopUpButton setEnabled:enabled];
    [self.applySlowModeButton setEnabled:enabled];
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

- (void)selectSlowMode:(NSInteger)seconds {
    NSArray *items = [self.slowModePopUpButton itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        if ([[[items objectAtIndex:index] representedObject] integerValue] == seconds) {
            [self.slowModePopUpButton selectItemAtIndex:index];
            return;
        }
    }
}

- (void)reloadAdministration {
    if (self.loading || !self.chatID) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"admin.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client chatAdministrationSummaryForChatID:chatID timeout:14.0 error:&error] retain];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.inviteLinks = [[summary objectForKey:@"invite_links"] isKindOfClass:[NSArray class]]
                    ? [summary objectForKey:@"invite_links"] : [NSArray array];
                self.joinRequests = [[summary objectForKey:@"join_requests"] isKindOfClass:[NSArray class]]
                    ? [summary objectForKey:@"join_requests"] : [NSArray array];
                self.events = [[summary objectForKey:@"events"] isKindOfClass:[NSArray class]]
                    ? [summary objectForKey:@"events"] : [NSArray array];
                [self.linksTableView reloadData];
                [self.requestsTableView reloadData];
                [self.eventsTableView reloadData];
                [self selectSlowMode:[[summary objectForKey:@"slow_mode_delay"] integerValue]];
                [self setLoading:NO status:detail ? detail : TGLoc(@"admin.loaded")];
            }
            [detail release];
            [summary release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadAdministration];
}

- (void)runMutation:(BOOL (^)(NSError **error))mutation {
    if (self.loading || !mutation) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"admin.saving")];
    BOOL (^copied)(NSError **) = [mutation copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = copied(&error);
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"admin.saved") : (detail ? detail : TGLoc(@"admin.failed"))];
            [copied release];
            [detail release];
            if (success) {
                [self reloadAdministration];
            }
        });
        [pool drain];
    });
}

- (void)createLinkPressed:(id)sender {
    (void)sender;
    NSString *name = [[self.linkNameField stringValue] copy];
    NSInteger expiration = [[[self.expirationPopUpButton selectedItem] representedObject] integerValue];
    NSInteger limit = [[self.memberLimitField stringValue] integerValue];
    BOOL requiresApproval = [self.joinRequestButton state] == NSOnState;
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    [self runMutation:^BOOL(NSError **error) {
        NSDictionary *link = [client createInviteLinkForChatID:chatID
                                                         name:name
                                             expirationPeriod:expiration
                                                  memberLimit:limit
                                           createsJoinRequest:requiresApproval
                                                      timeout:10.0
                                                        error:error];
        [client release];
        [chatID release];
        [name release];
        return link != nil;
    }];
}

- (void)copyLinkPressed:(id)sender {
    (void)sender;
    NSString *link = [[self selectedItemInTable:self.linksTableView source:self.inviteLinks] objectForKey:@"invite_link"];
    if ([link length] == 0) {
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteboard setString:link forType:NSStringPboardType];
    [self.statusField setStringValue:TGLoc(@"admin.copied")];
}

- (void)revokeLinkPressed:(id)sender {
    (void)sender;
    NSString *link = [[[self selectedItemInTable:self.linksTableView source:self.inviteLinks] objectForKey:@"invite_link"] copy];
    if ([link length] == 0) {
        [link release];
        return;
    }
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL success = [client revokeInviteLink:link forChatID:chatID timeout:10.0 error:error];
        [client release];
        [chatID release];
        [link release];
        return success;
    }];
}

- (void)processSelectedJoinRequestApprove:(BOOL)approve {
    NSDictionary *request = [self selectedItemInTable:self.requestsTableView source:self.joinRequests];
    NSNumber *userID = [[request objectForKey:@"user_id"] retain];
    if (!userID) {
        return;
    }
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL success = [client processJoinRequestForUserID:userID
                                                   chatID:chatID
                                                  approve:approve
                                                  timeout:10.0
                                                    error:error];
        [client release];
        [chatID release];
        [userID release];
        return success;
    }];
}

- (void)approvePressed:(id)sender {
    (void)sender;
    [self processSelectedJoinRequestApprove:YES];
}

- (void)declinePressed:(id)sender {
    (void)sender;
    [self processSelectedJoinRequestApprove:NO];
}

- (void)applySlowModePressed:(id)sender {
    (void)sender;
    NSInteger seconds = [[[self.slowModePopUpButton selectedItem] representedObject] integerValue];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL success = [client setSlowModeDelay:seconds forChatID:chatID timeout:10.0 error:error];
        [client release];
        [chatID release];
        return success;
    }];
}

@end
