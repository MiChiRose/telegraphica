#import "TGChatInfoWindowController.h"

#import "../Core/TGTDLibClient+ChatMembers.h"
#import "../Core/TGTDLibClient+ChatHistory.h"
#import "../Core/TGTDLibClient+Privacy.h"
#import "../Core/TGTDLibClient+SecretChats.h"
#import "../Core/TGSecretChatKey.h"
#import "../Core/TGTDLibCapabilities.h"
#import "TGChatAdministrationWindowController.h"
#import "TGBotInteractionWindowController.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGChatInfoWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *descriptionField;
@property (nonatomic, retain) NSTextField *summaryField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextField *membersLabel;
@property (nonatomic, retain) NSScrollView *memberScrollView;
@property (nonatomic, retain) NSTableView *memberTableView;
@property (nonatomic, retain) NSPopUpButton *contactPopUpButton;
@property (nonatomic, retain) NSPopUpButton *rolePopUpButton;
@property (nonatomic, retain) NSButton *addButton;
@property (nonatomic, retain) NSButton *applyRoleButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *administrationButton;
@property (nonatomic, retain) TGChatAdministrationWindowController *administrationWindowController;
@property (nonatomic, retain) NSButton *botButton;
@property (nonatomic, retain) TGBotInteractionWindowController *botWindowController;
@property (nonatomic, retain) NSPopUpButton *autoDeletePopUpButton;
@property (nonatomic, retain) NSButton *applyAutoDeleteButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSImageView *secretKeyImageView;
@property (nonatomic, retain) NSTextField *secretStateField;
@property (nonatomic, retain) NSTextField *secretFingerprintField;
@property (nonatomic, retain) NSButton *closeSecretChatButton;
@property (nonatomic, retain) NSButton *deleteSecretHistoryButton;
@property (nonatomic, copy) NSDictionary *chatSummary;
@property (nonatomic, copy) NSArray *members;
@property (nonatomic, copy) NSArray *contacts;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
- (void)runMemberMutationForUserID:(NSNumber *)userID role:(NSString *)role;
@end

static NSColor *TGSecretChatKeyColor(NSUInteger index) {
    switch (index) {
        case 1: return [NSColor colorWithCalibratedRed:(213.0 / 255.0) green:(230.0 / 255.0) blue:(243.0 / 255.0) alpha:1.0];
        case 2: return [NSColor colorWithCalibratedRed:(45.0 / 255.0) green:(87.0 / 255.0) blue:(117.0 / 255.0) alpha:1.0];
        case 3: return [NSColor colorWithCalibratedRed:(47.0 / 255.0) green:(153.0 / 255.0) blue:(201.0 / 255.0) alpha:1.0];
        default: return [NSColor whiteColor];
    }
}

static NSImage *TGSecretChatKeyImage(NSData *keyHashData) {
    NSArray *indexes = [TGSecretChatKey colorIndexesForKeyHashData:keyHashData];
    if ([indexes count] != 144) {
        return nil;
    }
    CGFloat pixelSize = 10.0;
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(120.0, 120.0)] autorelease];
    [image lockFocus];
    NSUInteger index = 0;
    for (index = 0; index < [indexes count]; index++) {
        NSUInteger row = index / 12;
        NSUInteger column = index % 12;
        [TGSecretChatKeyColor([[indexes objectAtIndex:index] unsignedIntegerValue]) set];
        NSRectFill(NSMakeRect(column * pixelSize, (11 - row) * pixelSize, pixelSize, pixelSize));
    }
    [image unlockFocus];
    return image;
}

@implementation TGChatInfoWindowController

@synthesize client = _client;
@synthesize chatID = _chatID;
@synthesize chatTitle = _chatTitle;
@synthesize titleField = _titleField;
@synthesize descriptionField = _descriptionField;
@synthesize summaryField = _summaryField;
@synthesize statusField = _statusField;
@synthesize membersLabel = _membersLabel;
@synthesize memberScrollView = _memberScrollView;
@synthesize memberTableView = _memberTableView;
@synthesize contactPopUpButton = _contactPopUpButton;
@synthesize rolePopUpButton = _rolePopUpButton;
@synthesize addButton = _addButton;
@synthesize applyRoleButton = _applyRoleButton;
@synthesize refreshButton = _refreshButton;
@synthesize administrationButton = _administrationButton;
@synthesize administrationWindowController = _administrationWindowController;
@synthesize botButton = _botButton;
@synthesize botWindowController = _botWindowController;
@synthesize autoDeletePopUpButton = _autoDeletePopUpButton;
@synthesize applyAutoDeleteButton = _applyAutoDeleteButton;
@synthesize spinner = _spinner;
@synthesize secretKeyImageView = _secretKeyImageView;
@synthesize secretStateField = _secretStateField;
@synthesize secretFingerprintField = _secretFingerprintField;
@synthesize closeSecretChatButton = _closeSecretChatButton;
@synthesize deleteSecretHistoryButton = _deleteSecretHistoryButton;
@synthesize chatSummary = _chatSummary;
@synthesize members = _members;
@synthesize contacts = _contacts;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
               title:(NSString *)title {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 720, 580)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.chatID = chatID;
        self.chatTitle = title;
        self.members = [NSArray array];
        self.contacts = [NSArray array];
        [[self window] setTitle:TGLoc(@"chat.info.title")];
        [[self window] setMinSize:NSMakeSize(660.0, 520.0)];
        [[self window] setMaxSize:NSMakeSize(940.0, 760.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_chatID release];
    [_chatTitle release];
    [_titleField release];
    [_descriptionField release];
    [_summaryField release];
    [_statusField release];
    [_membersLabel release];
    [_memberScrollView release];
    [_memberTableView release];
    [_contactPopUpButton release];
    [_rolePopUpButton release];
    [_addButton release];
    [_applyRoleButton release];
    [_refreshButton release];
    [_administrationButton release];
    [[_administrationWindowController window] close];
    [_administrationWindowController release];
    [_botButton release];
    [[_botWindowController window] close];
    [_botWindowController release];
    [_autoDeletePopUpButton release];
    [_applyAutoDeleteButton release];
    [_spinner release];
    [_secretKeyImageView release];
    [_secretStateField release];
    [_secretFingerprintField release];
    [_closeSecretChatButton release];
    [_deleteSecretHistoryButton release];
    [_chatSummary release];
    [_members release];
    [_contacts release];
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

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 530, 530, 28)
                                      font:[NSFont boldSystemFontOfSize:20.0]
                                     color:TGClassicHeaderTextColor(1.0)];
    [self.titleField setStringValue:[self.chatTitle length] > 0 ? self.chatTitle : TGLoc(@"chat.info.title")];
    [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.titleField];

    self.administrationButton = [[[NSButton alloc] initWithFrame:NSMakeRect(486, 530, 114, 30)] autorelease];
    [self.administrationButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"admin.open")] autorelease]];
    [self.administrationButton setTitle:TGLoc(@"admin.open")];
    [self.administrationButton setTarget:self];
    [self.administrationButton setAction:@selector(administrationPressed:)];
    [self.administrationButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.administrationButton];

    self.botButton = [[[NSButton alloc] initWithFrame:NSMakeRect(486, 530, 114, 30)] autorelease];
    [self.botButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"bot.open")] autorelease]];
    [self.botButton setTitle:TGLoc(@"bot.open")];
    [self.botButton setTarget:self];
    [self.botButton setAction:@selector(botPressed:)];
    [self.botButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [self.botButton setHidden:YES];
    [root addSubview:self.botButton];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(608, 530, 88, 30)] autorelease];
    [self.refreshButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"refresh")] autorelease]];
    [self.refreshButton setTitle:TGLoc(@"refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshPressed:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *overviewCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 410, 680, 104)] autorelease];
    [overviewCard setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:overviewCard];

    self.summaryField = [self labelWithFrame:NSMakeRect(38, 478, 644, 18)
                                        font:[NSFont boldSystemFontOfSize:12.0]
                                       color:TGClassicCardInkColor()];
    [self.summaryField setStringValue:TGLoc(@"chat.info.loading")];
    [self.summaryField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.summaryField];

    self.descriptionField = [self labelWithFrame:NSMakeRect(38, 430, 644, 42)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicCardMutedInkColor()];
    [[self.descriptionField cell] setWraps:YES];
    [[self.descriptionField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.descriptionField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.descriptionField];

    TGGroupedCardView *membersCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 76, 680, 318)] autorelease];
    [membersCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:membersCard];

    self.membersLabel = [self labelWithFrame:NSMakeRect(38, 362, 300, 18)
                                         font:[NSFont boldSystemFontOfSize:12.0]
                                        color:TGClassicCardInkColor()];
    [self.membersLabel setStringValue:TGLoc(@"chat.info.members")];
    [self.membersLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.membersLabel];

    NSTextField *autoDeleteLabel = [self labelWithFrame:NSMakeRect(268, 362, 104, 18)
                                                   font:[NSFont systemFontOfSize:11.0]
                                                  color:TGClassicCardMutedInkColor()];
    [autoDeleteLabel setStringValue:TGLoc(@"privacy.chatAutoDelete")];
    [autoDeleteLabel setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:autoDeleteLabel];

    self.autoDeletePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(368, 356, 152, 28) pullsDown:NO] autorelease];
    NSArray *seconds = [NSArray arrayWithObjects:@0, @86400, @604800, @2678400, @7776000, @31536000, nil];
    NSArray *timeKeys = [NSArray arrayWithObjects:@"off", @"day", @"week", @"month", @"threeMonths", @"year", nil];
    NSUInteger timeIndex = 0;
    for (timeIndex = 0; timeIndex < [seconds count]; timeIndex++) {
        [self.autoDeletePopUpButton addItemWithTitle:TGLoc([@"privacy.time." stringByAppendingString:[timeKeys objectAtIndex:timeIndex]])];
        [[self.autoDeletePopUpButton lastItem] setRepresentedObject:[seconds objectAtIndex:timeIndex]];
    }
    [self.autoDeletePopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.autoDeletePopUpButton];

    self.applyAutoDeleteButton = [[[NSButton alloc] initWithFrame:NSMakeRect(528, 356, 158, 28)] autorelease];
    [self.applyAutoDeleteButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applyAutoDeleteButton setTitle:TGLoc(@"apply")];
    [self.applyAutoDeleteButton setTarget:self];
    [self.applyAutoDeleteButton setAction:@selector(applyAutoDeletePressed:)];
    [self.applyAutoDeleteButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.applyAutoDeleteButton];

    self.memberScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(34, 156, 652, 198)] autorelease];
    [self.memberScrollView setHasVerticalScroller:YES];
    [self.memberScrollView setBorderType:NSNoBorder];
    [self.memberScrollView setDrawsBackground:NO];
    [self.memberScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.memberTableView = [[[NSTableView alloc] initWithFrame:[[self.memberScrollView contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"member"] autorelease];
    [column setWidth:640.0];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [self.memberTableView addTableColumn:column];
    [self.memberTableView setHeaderView:nil];
    [self.memberTableView setRowHeight:30.0];
    [self.memberTableView setAllowsEmptySelection:YES];
    [self.memberTableView setDelegate:self];
    [self.memberTableView setDataSource:self];
    [self.memberScrollView setDocumentView:self.memberTableView];
    [root addSubview:self.memberScrollView];

    self.secretKeyImageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(42, 190, 128, 128)] autorelease];
    [self.secretKeyImageView setImageFrameStyle:NSImageFrameNone];
    [self.secretKeyImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [self.secretKeyImageView setHidden:YES];
    [root addSubview:self.secretKeyImageView];

    self.secretStateField = [self labelWithFrame:NSMakeRect(190, 288, 474, 22)
                                             font:[NSFont boldSystemFontOfSize:13.0]
                                            color:TGClassicCardInkColor()];
    [self.secretStateField setHidden:YES];
    [root addSubview:self.secretStateField];

    self.secretFingerprintField = [self labelWithFrame:NSMakeRect(190, 218, 474, 62)
                                                   font:[NSFont userFixedPitchFontOfSize:11.0]
                                                  color:TGClassicCardMutedInkColor()];
    [self.secretFingerprintField setSelectable:YES];
    [[self.secretFingerprintField cell] setWraps:YES];
    [[self.secretFingerprintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.secretFingerprintField setHidden:YES];
    [root addSubview:self.secretFingerprintField];

    self.closeSecretChatButton = [[[NSButton alloc] initWithFrame:NSMakeRect(190, 170, 196, 30)] autorelease];
    [self.closeSecretChatButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"secretChat.close")] autorelease]];
    [self.closeSecretChatButton setTitle:TGLoc(@"secretChat.close")];
    [self.closeSecretChatButton setTarget:self];
    [self.closeSecretChatButton setAction:@selector(closeSecretChatPressed:)];
    [self.closeSecretChatButton setHidden:YES];
    [root addSubview:self.closeSecretChatButton];

    self.deleteSecretHistoryButton = [[[NSButton alloc] initWithFrame:NSMakeRect(398, 170, 266, 30)] autorelease];
    [self.deleteSecretHistoryButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"secretChat.deleteHistory")] autorelease]];
    [self.deleteSecretHistoryButton setTitle:TGLoc(@"secretChat.deleteHistory")];
    [self.deleteSecretHistoryButton setTarget:self];
    [self.deleteSecretHistoryButton setAction:@selector(deleteSecretHistoryPressed:)];
    [self.deleteSecretHistoryButton setHidden:YES];
    [root addSubview:self.deleteSecretHistoryButton];

    self.contactPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(34, 112, 248, 28) pullsDown:NO] autorelease];
    [self.contactPopUpButton addItemWithTitle:TGLoc(@"chat.info.selectContact")];
    [self.contactPopUpButton setTarget:self];
    [self.contactPopUpButton setAction:@selector(contactSelectionChanged:)];
    [self.contactPopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.contactPopUpButton];

    self.addButton = [[[NSButton alloc] initWithFrame:NSMakeRect(290, 112, 104, 28)] autorelease];
    [self.addButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"chat.info.add")] autorelease]];
    [self.addButton setTitle:TGLoc(@"chat.info.add")];
    [self.addButton setTarget:self];
    [self.addButton setAction:@selector(addPressed:)];
    [self.addButton setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.addButton];

    self.rolePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(408, 112, 154, 28) pullsDown:NO] autorelease];
    NSArray *roles = [NSArray arrayWithObjects:@"member", @"administrator", @"restricted", @"banned", nil];
    NSUInteger roleIndex = 0;
    for (roleIndex = 0; roleIndex < [roles count]; roleIndex++) {
        NSString *role = [roles objectAtIndex:roleIndex];
        [self.rolePopUpButton addItemWithTitle:TGLoc([@"chat.role." stringByAppendingString:role])];
        [[self.rolePopUpButton lastItem] setRepresentedObject:role];
    }
    [self.rolePopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.rolePopUpButton];

    self.applyRoleButton = [[[NSButton alloc] initWithFrame:NSMakeRect(570, 112, 116, 28)] autorelease];
    [self.applyRoleButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applyRoleButton setTitle:TGLoc(@"apply")];
    [self.applyRoleButton setTarget:self];
    [self.applyRoleButton setAction:@selector(applyRolePressed:)];
    [self.applyRoleButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.applyRoleButton];

    self.statusField = [self labelWithFrame:NSMakeRect(34, 88, 620, 16)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicCardMutedInkColor()];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(670, 87, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.members count];
}

- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    (void)tableView;
    (void)tableColumn;
    if (row < 0 || (NSUInteger)row >= [self.members count]) {
        return @"";
    }
    NSDictionary *member = [self.members objectAtIndex:(NSUInteger)row];
    NSString *name = [member objectForKey:@"display_name"];
    NSString *role = [member objectForKey:@"role"];
    NSString *safeRole = [role length] > 0 ? role : @"member";
    return [NSString stringWithFormat:@"%@ — %@", [name length] > 0 ? name : TGLoc(@"chat.untitled"),
            TGLoc([@"chat.role." stringByAppendingString:safeRole])];
}

- (NSDictionary *)selectedMember {
    NSInteger row = [self.memberTableView selectedRow];
    return (row >= 0 && (NSUInteger)row < [self.members count])
        ? [self.members objectAtIndex:(NSUInteger)row]
        : nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    NSDictionary *member = [self selectedMember];
    NSString *role = [member objectForKey:@"role"];
    NSArray *items = [self.rolePopUpButton itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        if ([[[items objectAtIndex:index] representedObject] isEqualToString:role]) {
            [self.rolePopUpButton selectItemAtIndex:index];
            break;
        }
    }
    [self updateControls];
}

- (void)updateControls {
    BOOL group = ([[self.chatSummary objectForKey:@"kind"] isEqualToString:@"basic_group"] ||
                  [[self.chatSummary objectForKey:@"kind"] isEqualToString:@"supergroup"]);
    BOOL bot = (!group && [[self.chatSummary objectForKey:@"kind"] isEqualToString:@"private"] &&
                [[[self.chatSummary objectForKey:@"profile"] objectForKey:@"is_bot"] boolValue]);
    BOOL secret = [[self.chatSummary objectForKey:@"kind"] isEqualToString:@"secret"];
    NSString *secretState = [[[self.chatSummary objectForKey:@"secret_chat"] objectForKey:@"state"] isKindOfClass:[NSString class]]
        ? [[self.chatSummary objectForKey:@"secret_chat"] objectForKey:@"state"] : @"";
    BOOL secretClosed = [secretState isEqualToString:@"secretChatStateClosed"];
    BOOL canInvite = [[self.chatSummary objectForKey:@"can_invite_members"] boolValue];
    BOOL canManage = [[self.chatSummary objectForKey:@"can_manage_members"] boolValue];
    BOOL selected = ([self selectedMember] != nil);
    [self.refreshButton setEnabled:!self.loading];
    [self.contactPopUpButton setEnabled:(!self.loading && group && canInvite && [self.contacts count] > 0)];
    [self.addButton setEnabled:(!self.loading && group && canInvite && [self.contactPopUpButton indexOfSelectedItem] > 0)];
    [self.rolePopUpButton setEnabled:(!self.loading && group && canManage && selected)];
    [self.applyRoleButton setEnabled:(!self.loading && group && canManage && selected &&
                                      ![[[self selectedMember] objectForKey:@"role"] isEqualToString:@"creator"])];
    TGTDLibCapabilityState secretTTLState = [[self.client capabilities] supportStateForCapability:TGTDLibCapabilitySecretChatTTL];
    BOOL secretTTLUnavailable = (secret && (secretTTLState == TGTDLibCapabilityStateUnsupported ||
                                             secretTTLState == TGTDLibCapabilityStateForbidden));
    [self.autoDeletePopUpButton setEnabled:(!self.loading && !secretTTLUnavailable && !secretClosed)];
    [self.applyAutoDeleteButton setEnabled:(!self.loading && !secretTTLUnavailable && !secretClosed)];
    NSString *ttlReason = secretTTLUnavailable ? [[self.client capabilities] reasonForCapability:TGTDLibCapabilitySecretChatTTL] : nil;
    [self.autoDeletePopUpButton setToolTip:ttlReason];
    [self.applyAutoDeleteButton setToolTip:ttlReason];
    [self.administrationButton setEnabled:(!self.loading && group && (canInvite || canManage))];
    [self.administrationButton setHidden:(bot || secret)];
    [self.botButton setHidden:!bot];
    [self.botButton setEnabled:(!self.loading && bot)];
    [self.closeSecretChatButton setEnabled:(!self.loading && secret && !secretClosed)];
    [self.deleteSecretHistoryButton setEnabled:(!self.loading && secret)];
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

- (void)renderSummary {
    NSString *title = [self.chatSummary objectForKey:@"title"];
    if ([title length] > 0) {
        [self.titleField setStringValue:title];
        [[self window] setTitle:title];
    }
    NSString *kind = [self.chatSummary objectForKey:@"kind"];
    BOOL secret = [kind isEqualToString:@"secret"];
    NSNumber *memberCount = [self.chatSummary objectForKey:@"member_count"];
    NSString *safeKind = [kind length] > 0 ? kind : @"unknown";
    NSString *kindText = TGLoc([@"chat.kind." stringByAppendingString:safeKind]);
    [self.summaryField setStringValue:[memberCount integerValue] > 0
        ? [NSString stringWithFormat:TGLoc(@"chat.info.summaryWithMembers"), kindText, (long)[memberCount integerValue]]
        : kindText];
    NSString *description = [self.chatSummary objectForKey:@"description"];
    if ([description length] == 0) {
        NSDictionary *profile = [self.chatSummary objectForKey:@"profile"];
        description = [profile objectForKey:@"bio"];
    }
    [self.descriptionField setStringValue:[description length] > 0 ? description : TGLoc(@"chat.info.noDescription")];
    [self.membersLabel setStringValue:secret ? TGLoc(@"secretChat.encryptionKey") : TGLoc(@"chat.info.members")];
    [self.memberScrollView setHidden:secret];
    [self.contactPopUpButton setHidden:secret];
    [self.addButton setHidden:secret];
    [self.rolePopUpButton setHidden:secret];
    [self.applyRoleButton setHidden:secret];
    [self.secretKeyImageView setHidden:!secret];
    [self.secretStateField setHidden:!secret];
    [self.secretFingerprintField setHidden:!secret];
    [self.closeSecretChatButton setHidden:!secret];
    [self.deleteSecretHistoryButton setHidden:!secret];

    [self.autoDeletePopUpButton removeAllItems];
    NSArray *seconds = secret
        ? [NSArray arrayWithObjects:@0, @1, @5, @10, @30, @60, @300, @3600, @86400, nil]
        : [NSArray arrayWithObjects:@0, @86400, @604800, @2678400, @7776000, @31536000, nil];
    NSArray *timeKeys = secret
        ? [NSArray arrayWithObjects:@"off", @"second", @"fiveSeconds", @"tenSeconds", @"thirtySeconds", @"minute", @"fiveMinutes", @"hour", @"day", nil]
        : [NSArray arrayWithObjects:@"off", @"day", @"week", @"month", @"threeMonths", @"year", nil];
    NSUInteger timeIndex = 0;
    for (timeIndex = 0; timeIndex < [seconds count]; timeIndex++) {
        NSString *key = [@"privacy.time." stringByAppendingString:[timeKeys objectAtIndex:timeIndex]];
        [self.autoDeletePopUpButton addItemWithTitle:TGLoc(key)];
        [[self.autoDeletePopUpButton lastItem] setRepresentedObject:[seconds objectAtIndex:timeIndex]];
    }
    if (secret) {
        NSDictionary *secretSummary = [[self.chatSummary objectForKey:@"secret_chat"] isKindOfClass:[NSDictionary class]]
            ? [self.chatSummary objectForKey:@"secret_chat"] : [NSDictionary dictionary];
        NSString *state = [secretSummary objectForKey:@"state"];
        NSString *stateKey = [@"secretChat.state." stringByAppendingString:([state length] > 0 ? state : @"unknown")];
        NSString *direction = [[secretSummary objectForKey:@"is_outbound"] boolValue]
            ? TGLoc(@"secretChat.outbound") : TGLoc(@"secretChat.inbound");
        [self.secretStateField setStringValue:[NSString stringWithFormat:TGLoc(@"secretChat.stateSummary"),
                                                TGLoc(stateKey),
                                                direction,
                                                (long)[[secretSummary objectForKey:@"layer"] integerValue]]];
        NSString *fingerprint = [secretSummary objectForKey:@"key_fingerprint"];
        [self.secretFingerprintField setStringValue:[fingerprint length] > 0
            ? [NSString stringWithFormat:TGLoc(@"secretChat.fingerprint"), fingerprint]
            : TGLoc(@"secretChat.keyUnavailable")];
        [self.secretKeyImageView setImage:TGSecretChatKeyImage([secretSummary objectForKey:@"key_hash_data"])];
    }
    NSInteger autoDeleteTime = [[self.chatSummary objectForKey:@"message_auto_delete_time"] integerValue];
    NSArray *autoDeleteItems = [self.autoDeletePopUpButton itemArray];
    NSInteger selectedAutoDeleteIndex = 0;
    NSInteger nearestDistance = NSIntegerMax;
    NSUInteger autoDeleteIndex = 0;
    for (autoDeleteIndex = 0; autoDeleteIndex < [autoDeleteItems count]; autoDeleteIndex++) {
        NSInteger value = [[[autoDeleteItems objectAtIndex:autoDeleteIndex] representedObject] integerValue];
        NSInteger distance = labs(value - autoDeleteTime);
        if (distance < nearestDistance) {
            nearestDistance = distance;
            selectedAutoDeleteIndex = (NSInteger)autoDeleteIndex;
        }
    }
    [self.autoDeletePopUpButton selectItemAtIndex:selectedAutoDeleteIndex];
    [self.memberTableView reloadData];
    [self.memberTableView deselectAll:nil];
    [self.contactPopUpButton removeAllItems];
    [self.contactPopUpButton addItemWithTitle:TGLoc(@"chat.info.selectContact")];
    NSUInteger contactIndex = 0;
    for (contactIndex = 0; contactIndex < [self.contacts count]; contactIndex++) {
        NSDictionary *contact = [self.contacts objectAtIndex:contactIndex];
        NSString *name = [contact objectForKey:@"display_name"];
        [self.contactPopUpButton addItemWithTitle:[name length] > 0 ? name : TGLoc(@"chat.untitled")];
        [[self.contactPopUpButton lastItem] setRepresentedObject:[contact objectForKey:@"user_id"]];
    }
    [self updateControls];
}

- (void)reloadChatInfo {
    if (self.loading || !self.chatID) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"chat.info.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client chatDetailsSummaryForChatID:chatID timeout:10.0 error:&error] retain];
        NSArray *contacts = [[client contactSummariesWithTimeout:6.0 error:NULL] retain];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.chatSummary = summary;
                self.members = [[summary objectForKey:@"members"] isKindOfClass:[NSArray class]]
                    ? [summary objectForKey:@"members"]
                    : [NSArray array];
                self.contacts = contacts ? contacts : [NSArray array];
                [self renderSummary];
                [self setLoading:NO status:detail ? detail : [NSString stringWithFormat:TGLoc(@"chat.info.loadedMembers"), (unsigned long)[self.members count]]];
            }
            [summary release];
            [contacts release];
            [detail release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)botPressed:(id)sender {
    (void)sender;
    NSNumber *userID = [self.chatSummary objectForKey:@"user_id"];
    if (![userID respondsToSelector:@selector(longLongValue)] || [userID longLongValue] == 0) {
        [self.statusField setStringValue:TGLoc(@"bot.unavailable")];
        return;
    }
    [[self.botWindowController window] close];
    self.botWindowController = [[[TGBotInteractionWindowController alloc] initWithClient:self.client
                                                                                  userID:userID
                                                                                  chatID:self.chatID] autorelease];
    [self.botWindowController showWindow:self];
    [[self.botWindowController window] center];
    [[self.botWindowController window] makeKeyAndOrderFront:self];
    [self.botWindowController reloadBot];
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadChatInfo];
}

- (void)administrationPressed:(id)sender {
    (void)sender;
    if (!self.administrationWindowController) {
        self.administrationWindowController = [[[TGChatAdministrationWindowController alloc]
                                                initWithClient:self.client
                                                chatID:self.chatID
                                                title:[self.titleField stringValue]] autorelease];
    }
    [[self.administrationWindowController window] center];
    [self.administrationWindowController showWindow:self];
    [[self.administrationWindowController window] makeKeyAndOrderFront:self];
    [self.administrationWindowController reloadAdministration];
}

- (void)addPressed:(id)sender {
    (void)sender;
    NSNumber *userID = [[self.contactPopUpButton selectedItem] representedObject];
    if (![userID respondsToSelector:@selector(longLongValue)] || self.loading) {
        return;
    }
    [self runMemberMutationForUserID:userID role:nil];
}

- (void)contactSelectionChanged:(id)sender {
    (void)sender;
    [self updateControls];
}

- (void)applyRolePressed:(id)sender {
    (void)sender;
    NSDictionary *member = [self selectedMember];
    NSNumber *userID = [member objectForKey:@"user_id"];
    NSString *role = [[self.rolePopUpButton selectedItem] representedObject];
    if (!userID || !role || self.loading) {
        return;
    }
    if ([role isEqualToString:@"banned"]) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:TGLoc(@"chat.info.banConfirm")];
        [alert setInformativeText:[member objectForKey:@"display_name"]];
        [alert addButtonWithTitle:TGLoc(@"chat.role.banned")];
        [alert addButtonWithTitle:TGLoc(@"cancel")];
        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
    }
    [self runMemberMutationForUserID:userID role:role];
}

- (void)applyAutoDeletePressed:(id)sender {
    (void)sender;
    if (self.loading || !self.chatID) {
        return;
    }
    NSNumber *secondsNumber = [[self.autoDeletePopUpButton selectedItem] representedObject];
    NSInteger seconds = [secondsNumber integerValue];
    [self setLoading:YES status:TGLoc(@"privacy.saving")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [client setMessageAutoDeleteTime:seconds forChatID:chatID timeout:10.0 error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"privacy.saved") : (detail ? detail : TGLoc(@"privacy.failed"))];
            [detail release];
            [chatID release];
            [client release];
            if (success) {
                [self reloadChatInfo];
            }
        });
        [pool drain];
    });
}

- (void)closeSecretChatPressed:(id)sender {
    (void)sender;
    if (self.loading || ![[self.chatSummary objectForKey:@"kind"] isEqualToString:@"secret"]) {
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"secretChat.closeConfirmTitle")];
    [alert setInformativeText:TGLoc(@"secretChat.closeConfirmBody")];
    [alert addButtonWithTitle:TGLoc(@"secretChat.close")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"secretChat.closing")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [client closeSecretChatForChatID:chatID timeout:10.0 error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"secretChat.closed") : (detail ? detail : TGLoc(@"secretChat.failed"))];
            if (success) {
                [self reloadChatInfo];
            }
            [detail release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)deleteSecretHistoryPressed:(id)sender {
    (void)sender;
    if (self.loading || ![[self.chatSummary objectForKey:@"kind"] isEqualToString:@"secret"]) {
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"secretChat.deleteConfirmTitle")];
    [alert setInformativeText:TGLoc(@"secretChat.deleteConfirmBody")];
    [alert addButtonWithTitle:TGLoc(@"secretChat.deleteHistory")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"secretChat.deleting")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [client deleteChatHistoryForChatID:chatID
                                       removeFromChatList:YES
                                                    revoke:YES
                                                   timeout:10.0
                                                     error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"secretChat.deleted") : (detail ? detail : TGLoc(@"secretChat.failed"))];
            if (success) {
                [[self window] performClose:self];
            }
            [detail release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)runMemberMutationForUserID:(NSNumber *)userID role:(NSString *)role {
    [self setLoading:YES status:TGLoc(@"chat.info.saving")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *safeUserID = [userID retain];
    NSString *safeRole = [role copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = safeRole
            ? [client setUserID:safeUserID inChatID:chatID role:safeRole timeout:10.0 error:&error]
            : [client addUserID:safeUserID toChatID:chatID timeout:10.0 error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"chat.info.saved") : (detail ? detail : TGLoc(@"chat.info.failed"))];
            if (success) {
                [self reloadChatInfo];
            }
            [detail release];
            [safeRole release];
            [safeUserID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

@end
