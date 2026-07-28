#import "TGPrivacyWindowController.h"

#import "../Core/TGTDLibClient+ChatMembers.h"
#import "../Core/TGTDLibClient+Privacy.h"
#import "TGLocalization.h"
#import "TGMessageLayoutSupport.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGBlockedSenderCell : TGRepresentedObjectCell
@end

@implementation TGBlockedSenderCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *summary = [[self representedObject] isKindOfClass:[NSDictionary class]]
        ? [self representedObject]
        : nil;
    if (!summary) {
        return;
    }

    BOOL selected = [self isHighlighted];
    BOOL flipped = [controlView isFlipped];
    NSString *title = [summary objectForKey:@"title"];
    if ([title length] == 0) {
        title = TGLoc(@"chat.untitled");
    }
    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 10.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 36.0) / 2.0),
                                   36.0,
                                   36.0);
    TGDrawAvatarInRect([summary objectForKey:@"avatar_local_path"], title, avatarRect, selected, flipped);

    CGFloat textX = NSMaxX(avatarRect) + 11.0;
    CGFloat textWidth = MAX(40.0, NSMaxX(cellFrame) - textX - 12.0);
    NSColor *ink = selected ? TGClassicHeaderTextColor(1.0) : TGClassicCardInkColor();
    NSColor *muted = selected ? TGClassicHeaderDetailTextColor(0.94) : TGClassicCardMutedInkColor();
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.5], NSFontAttributeName,
                                     ink, NSForegroundColorAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:10.5], NSFontAttributeName,
                                      muted, NSForegroundColorAttributeName,
                                      nil];
    [title drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 7.0, textWidth, 17.0)
       withAttributes:titleAttributes];
    NSString *username = [summary objectForKey:@"username"];
    NSString *detail = [username length] > 0
        ? [NSString stringWithFormat:@"@%@", username]
        : @"";
    if ([detail length] > 0) {
        [detail drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 25.0, textWidth, 15.0)
            withAttributes:detailAttributes];
    }
}

@end

@interface TGPrivacyWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSPopUpButton *settingPopUpButton;
@property (nonatomic, retain) NSPopUpButton *rulePopUpButton;
@property (nonatomic, retain) NSButton *applyRuleButton;
@property (nonatomic, retain) NSPopUpButton *accountTTLPopUpButton;
@property (nonatomic, retain) NSPopUpButton *autoDeletePopUpButton;
@property (nonatomic, retain) NSButton *applyRetentionButton;
@property (nonatomic, retain) NSTableView *blockedTableView;
@property (nonatomic, retain) NSPopUpButton *contactPopUpButton;
@property (nonatomic, retain) NSButton *blockButton;
@property (nonatomic, retain) NSButton *unblockButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextField *ruleHintField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSArray *privacySettings;
@property (nonatomic, copy) NSArray *blockedSenders;
@property (nonatomic, copy) NSArray *contacts;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGPrivacyWindowController

@synthesize client = _client;
@synthesize settingPopUpButton = _settingPopUpButton;
@synthesize rulePopUpButton = _rulePopUpButton;
@synthesize applyRuleButton = _applyRuleButton;
@synthesize accountTTLPopUpButton = _accountTTLPopUpButton;
@synthesize autoDeletePopUpButton = _autoDeletePopUpButton;
@synthesize applyRetentionButton = _applyRetentionButton;
@synthesize blockedTableView = _blockedTableView;
@synthesize contactPopUpButton = _contactPopUpButton;
@synthesize blockButton = _blockButton;
@synthesize unblockButton = _unblockButton;
@synthesize refreshButton = _refreshButton;
@synthesize statusField = _statusField;
@synthesize ruleHintField = _ruleHintField;
@synthesize spinner = _spinner;
@synthesize privacySettings = _privacySettings;
@synthesize blockedSenders = _blockedSenders;
@synthesize contacts = _contacts;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 760, 620)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.privacySettings = [NSArray array];
        self.blockedSenders = [NSArray array];
        self.contacts = [NSArray array];
        [[self window] setTitle:TGLoc(@"privacy.title")];
        [[self window] setMinSize:NSMakeSize(700.0, 560.0)];
        [[self window] setMaxSize:NSMakeSize(960.0, 800.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_settingPopUpButton release];
    [_rulePopUpButton release];
    [_applyRuleButton release];
    [_accountTTLPopUpButton release];
    [_autoDeletePopUpButton release];
    [_applyRetentionButton release];
    [_blockedTableView release];
    [_contactPopUpButton release];
    [_blockButton release];
    [_unblockButton release];
    [_refreshButton release];
    [_statusField release];
    [_ruleHintField release];
    [_spinner release];
    [_privacySettings release];
    [_blockedSenders release];
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

- (void)addPopupItem:(NSString *)title value:(id)value toPopup:(NSPopUpButton *)popup {
    [popup addItemWithTitle:title];
    [[popup lastItem] setRepresentedObject:value];
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 570, 560, 28)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"privacy.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(648, 568, 88, 30)] autorelease];
    [self.refreshButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"refresh")] autorelease]];
    [self.refreshButton setTitle:TGLoc(@"refresh")];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshPressed:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *rulesCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 406, 350, 146)] autorelease];
    [rulesCard setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:rulesCard];
    NSTextField *rulesTitle = [self labelWithFrame:NSMakeRect(38, 520, 310, 18)
                                              font:[NSFont boldSystemFontOfSize:13.0]
                                             color:TGClassicCardInkColor()];
    [rulesTitle setStringValue:TGLoc(@"privacy.rules")];
    [rulesTitle setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:rulesTitle];

    self.settingPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(36, 480, 206, 28) pullsDown:NO] autorelease];
    NSArray *settingTypes = [NSArray arrayWithObjects:
                             @"userPrivacySettingShowStatus",
                             @"userPrivacySettingShowProfilePhoto",
                             @"userPrivacySettingShowPhoneNumber",
                             @"userPrivacySettingAllowFindingByPhoneNumber",
                             @"userPrivacySettingAllowCalls",
                             @"userPrivacySettingAllowPeerToPeerCalls",
                             @"userPrivacySettingAllowChatInvites",
                             @"userPrivacySettingShowBio", nil];
    NSUInteger index = 0;
    for (index = 0; index < [settingTypes count]; index++) {
        NSString *type = [settingTypes objectAtIndex:index];
        [self addPopupItem:TGLoc([@"privacy.setting." stringByAppendingString:type])
                     value:type
                   toPopup:self.settingPopUpButton];
    }
    [self.settingPopUpButton setTarget:self];
    [self.settingPopUpButton setAction:@selector(settingChanged:)];
    [self.settingPopUpButton setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:self.settingPopUpButton];

    self.rulePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(246, 480, 106, 28) pullsDown:NO] autorelease];
    [self addPopupItem:TGLoc(@"privacy.rule.everybody") value:@"everybody" toPopup:self.rulePopUpButton];
    [self addPopupItem:TGLoc(@"privacy.rule.contacts") value:@"contacts" toPopup:self.rulePopUpButton];
    [self addPopupItem:TGLoc(@"privacy.rule.nobody") value:@"nobody" toPopup:self.rulePopUpButton];
    [self.rulePopUpButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.rulePopUpButton];

    self.ruleHintField = [self labelWithFrame:NSMakeRect(38, 442, 314, 30)
                                         font:[NSFont systemFontOfSize:10.0]
                                        color:TGClassicCardMutedInkColor()];
    [[self.ruleHintField cell] setWraps:YES];
    [[self.ruleHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.ruleHintField setStringValue:TGLoc(@"privacy.rules.help")];
    [self.ruleHintField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.ruleHintField];

    self.applyRuleButton = [[[NSButton alloc] initWithFrame:NSMakeRect(218, 414, 134, 26)] autorelease];
    [self.applyRuleButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applyRuleButton setTitle:TGLoc(@"apply")];
    [self.applyRuleButton setTarget:self];
    [self.applyRuleButton setAction:@selector(applyRulePressed:)];
    [self.applyRuleButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.applyRuleButton];

    TGGroupedCardView *retentionCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(382, 406, 358, 146)] autorelease];
    [retentionCard setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:retentionCard];
    NSTextField *retentionTitle = [self labelWithFrame:NSMakeRect(400, 520, 320, 18)
                                                  font:[NSFont boldSystemFontOfSize:13.0]
                                                 color:TGClassicCardInkColor()];
    [retentionTitle setStringValue:TGLoc(@"privacy.retention")];
    [retentionTitle setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:retentionTitle];
    NSTextField *ttlLabel = [self labelWithFrame:NSMakeRect(400, 486, 148, 18)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicCardInkColor()];
    [ttlLabel setStringValue:TGLoc(@"privacy.accountTTL")];
    [ttlLabel setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:ttlLabel];
    self.accountTTLPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(552, 480, 166, 28) pullsDown:NO] autorelease];
    NSArray *ttlDays = [NSArray arrayWithObjects:@30, @90, @180, @365, @548, @730, nil];
    for (index = 0; index < [ttlDays count]; index++) {
        NSNumber *days = [ttlDays objectAtIndex:index];
        [self addPopupItem:[NSString stringWithFormat:TGLoc(@"privacy.days"), (long)[days integerValue]]
                     value:days
                   toPopup:self.accountTTLPopUpButton];
    }
    [self.accountTTLPopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.accountTTLPopUpButton];
    NSTextField *autoLabel = [self labelWithFrame:NSMakeRect(400, 454, 148, 18)
                                             font:[NSFont systemFontOfSize:11.0]
                                            color:TGClassicCardInkColor()];
    [autoLabel setStringValue:TGLoc(@"privacy.defaultAutoDelete")];
    [autoLabel setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:autoLabel];
    self.autoDeletePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(552, 448, 166, 28) pullsDown:NO] autorelease];
    NSArray *seconds = [NSArray arrayWithObjects:@0, @86400, @604800, @2678400, @7776000, @31536000, nil];
    NSArray *timeKeys = [NSArray arrayWithObjects:@"off", @"day", @"week", @"month", @"threeMonths", @"year", nil];
    for (index = 0; index < [seconds count]; index++) {
        [self addPopupItem:TGLoc([@"privacy.time." stringByAppendingString:[timeKeys objectAtIndex:index]])
                     value:[seconds objectAtIndex:index]
                   toPopup:self.autoDeletePopUpButton];
    }
    [self.autoDeletePopUpButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.autoDeletePopUpButton];
    self.applyRetentionButton = [[[NSButton alloc] initWithFrame:NSMakeRect(584, 414, 134, 26)] autorelease];
    [self.applyRetentionButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"apply")] autorelease]];
    [self.applyRetentionButton setTitle:TGLoc(@"apply")];
    [self.applyRetentionButton setTarget:self];
    [self.applyRetentionButton setAction:@selector(applyRetentionPressed:)];
    [self.applyRetentionButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.applyRetentionButton];

    TGGroupedCardView *blockedCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 54, 720, 338)] autorelease];
    [blockedCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:blockedCard];
    NSTextField *blockedTitle = [self labelWithFrame:NSMakeRect(38, 360, 300, 18)
                                                font:[NSFont boldSystemFontOfSize:13.0]
                                               color:TGClassicCardInkColor()];
    [blockedTitle setStringValue:TGLoc(@"privacy.blocked")];
    [blockedTitle setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:blockedTitle];

    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(34, 116, 692, 234)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSNoBorder];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.blockedTableView = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"sender"] autorelease];
    [column setWidth:680.0];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [column setDataCell:[[[TGBlockedSenderCell alloc] initTextCell:@""] autorelease]];
    [self.blockedTableView addTableColumn:column];
    [self.blockedTableView setHeaderView:nil];
    [self.blockedTableView setRowHeight:48.0];
    [self.blockedTableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.blockedTableView setBackgroundColor:[NSColor clearColor]];
    [self.blockedTableView setAllowsEmptySelection:YES];
    [self.blockedTableView setDelegate:self];
    [self.blockedTableView setDataSource:self];
    [scroll setDocumentView:self.blockedTableView];
    [root addSubview:scroll];

    self.contactPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(34, 76, 350, 28) pullsDown:NO] autorelease];
    [self.contactPopUpButton setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.contactPopUpButton];
    self.blockButton = [[[NSButton alloc] initWithFrame:NSMakeRect(394, 76, 146, 28)] autorelease];
    [self.blockButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"privacy.block")] autorelease]];
    [self.blockButton setTitle:TGLoc(@"privacy.block")];
    [self.blockButton setTarget:self];
    [self.blockButton setAction:@selector(blockPressed:)];
    [self.blockButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.blockButton];
    self.unblockButton = [[[NSButton alloc] initWithFrame:NSMakeRect(550, 76, 176, 28)] autorelease];
    [self.unblockButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"privacy.unblock")] autorelease]];
    [self.unblockButton setTitle:TGLoc(@"privacy.unblock")];
    [self.unblockButton setTarget:self];
    [self.unblockButton setAction:@selector(unblockPressed:)];
    [self.unblockButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.unblockButton];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 25, 674, 18)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicHeaderTextColor(0.86)];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(716, 25, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.blockedSenders count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;
    (void)column;
    if (row < 0 || (NSUInteger)row >= [self.blockedSenders count]) {
        return nil;
    }
    return [self.blockedSenders objectAtIndex:(NSUInteger)row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (NSDictionary *)selectedBlockedSummary {
    NSInteger row = [self.blockedTableView selectedRow];
    return (row >= 0 && (NSUInteger)row < [self.blockedSenders count])
        ? [self.blockedSenders objectAtIndex:(NSUInteger)row]
        : nil;
}

- (NSDictionary *)privacySummaryForSelectedSetting {
    NSString *type = [[self.settingPopUpButton selectedItem] representedObject];
    NSUInteger index = 0;
    for (index = 0; index < [self.privacySettings count]; index++) {
        NSDictionary *summary = [self.privacySettings objectAtIndex:index];
        if ([[summary objectForKey:@"type"] isEqualToString:type]) {
            return summary;
        }
    }
    return nil;
}

- (void)selectPopup:(NSPopUpButton *)popup representedInteger:(NSInteger)value {
    NSArray *items = [popup itemArray];
    NSInteger nearest = 0;
    NSInteger nearestDistance = NSIntegerMax;
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSInteger itemValue = [[[items objectAtIndex:index] representedObject] integerValue];
        NSInteger distance = labs(itemValue - value);
        if (distance < nearestDistance) {
            nearest = (NSInteger)index;
            nearestDistance = distance;
        }
    }
    [popup selectItemAtIndex:nearest];
}

- (void)settingChanged:(id)sender {
    (void)sender;
    NSDictionary *summary = [self privacySummaryForSelectedSetting];
    NSString *rule = [summary objectForKey:@"rule"];
    if ([rule isEqualToString:@"custom"]) {
        [self.ruleHintField setStringValue:TGLoc(@"privacy.rules.custom")];
        [self.rulePopUpButton selectItemAtIndex:-1];
    } else {
        [self.ruleHintField setStringValue:TGLoc(@"privacy.rules.help")];
        NSArray *items = [self.rulePopUpButton itemArray];
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            if ([[[items objectAtIndex:index] representedObject] isEqualToString:rule]) {
                [self.rulePopUpButton selectItemAtIndex:index];
                break;
            }
        }
    }
    [self updateControls];
}

- (void)renderSummary:(NSDictionary *)summary {
    self.privacySettings = [[summary objectForKey:@"settings"] isKindOfClass:[NSArray class]]
        ? [summary objectForKey:@"settings"] : [NSArray array];
    self.blockedSenders = [[summary objectForKey:@"blocked"] isKindOfClass:[NSArray class]]
        ? [summary objectForKey:@"blocked"] : [NSArray array];
    [self.blockedTableView reloadData];
    [self.blockedTableView deselectAll:nil];
    [self.contactPopUpButton removeAllItems];
    [self addPopupItem:TGLoc(@"privacy.selectContact") value:nil toPopup:self.contactPopUpButton];
    NSUInteger index = 0;
    for (index = 0; index < [self.contacts count]; index++) {
        NSDictionary *contact = [self.contacts objectAtIndex:index];
        NSString *name = [contact objectForKey:@"display_name"];
        NSNumber *userID = [contact objectForKey:@"user_id"];
        if (userID) {
            [self addPopupItem:([name length] > 0 ? name : TGLoc(@"chat.untitled"))
                         value:userID
                       toPopup:self.contactPopUpButton];
        }
    }
    [self settingChanged:nil];
    [self selectPopup:self.accountTTLPopUpButton representedInteger:[[summary objectForKey:@"account_ttl_days"] integerValue]];
    [self selectPopup:self.autoDeletePopUpButton representedInteger:[[summary objectForKey:@"default_auto_delete_time"] integerValue]];
    [self updateControls];
}

- (void)updateControls {
    BOOL enabled = !self.loading;
    [self.refreshButton setEnabled:enabled];
    [self.settingPopUpButton setEnabled:enabled];
    [self.rulePopUpButton setEnabled:enabled];
    [self.applyRuleButton setEnabled:(enabled && [self.rulePopUpButton selectedItem] != nil)];
    [self.accountTTLPopUpButton setEnabled:enabled];
    [self.autoDeletePopUpButton setEnabled:enabled];
    [self.applyRetentionButton setEnabled:enabled];
    [self.contactPopUpButton setEnabled:(enabled && [self.contacts count] > 0)];
    [self.blockButton setEnabled:(enabled && [[[self.contactPopUpButton selectedItem] representedObject] respondsToSelector:@selector(longLongValue)])];
    [self.unblockButton setEnabled:(enabled && [self selectedBlockedSummary] != nil)];
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

- (void)reloadPrivacy {
    if (self.loading) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"privacy.loading")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client privacyAndRetentionSummaryWithTimeout:12.0 error:&error] retain];
        NSArray *contacts = [[client contactSummariesWithTimeout:6.0 error:NULL] retain];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.contacts = contacts ? contacts : [NSArray array];
                [self renderSummary:summary ? summary : [NSDictionary dictionary]];
                [self setLoading:NO status:detail ? detail : TGLoc(@"privacy.loaded")];
            }
            [detail release];
            [contacts release];
            [summary release];
            [client release];
        });
        [pool drain];
    });
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadPrivacy];
}

- (void)runMutation:(BOOL (^)(NSError **error))mutation {
    if (self.loading || !mutation) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"privacy.saving")];
    BOOL (^copiedMutation)(NSError **) = [mutation copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = copiedMutation(&error);
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"privacy.saved") : (detail ? detail : TGLoc(@"privacy.failed"))];
            [copiedMutation release];
            [detail release];
            if (success) {
                [self reloadPrivacy];
            }
        });
        [pool drain];
    });
}

- (void)applyRulePressed:(id)sender {
    (void)sender;
    NSString *setting = [[[self.settingPopUpButton selectedItem] representedObject] copy];
    NSString *rule = [[[self.rulePopUpButton selectedItem] representedObject] copy];
    TGTDLibClient *client = [self.client retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL result = [client setPrivacySettingType:setting rule:rule timeout:10.0 error:error];
        [client release];
        [setting release];
        [rule release];
        return result;
    }];
}

- (void)applyRetentionPressed:(id)sender {
    (void)sender;
    NSInteger days = [[[self.accountTTLPopUpButton selectedItem] representedObject] integerValue];
    NSInteger seconds = [[[self.autoDeletePopUpButton selectedItem] representedObject] integerValue];
    TGTDLibClient *client = [self.client retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL ttlSaved = [client setAccountTTLInDays:days timeout:10.0 error:error];
        BOOL autoSaved = ttlSaved && [client setDefaultMessageAutoDeleteTime:seconds timeout:10.0 error:error];
        [client release];
        return autoSaved;
    }];
}

- (void)blockPressed:(id)sender {
    (void)sender;
    NSNumber *userID = [[[[self.contactPopUpButton selectedItem] representedObject] retain] autorelease];
    if (!userID) {
        return;
    }
    NSDictionary *senderObject = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  @"messageSenderUser", @"@type", userID, @"user_id", nil];
    TGTDLibClient *client = [self.client retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL result = [client setBlockedSender:senderObject blocked:YES timeout:10.0 error:error];
        [client release];
        [senderObject release];
        return result;
    }];
}

- (void)unblockPressed:(id)sender {
    (void)sender;
    NSDictionary *senderObject = [[[[self selectedBlockedSummary] objectForKey:@"sender"] retain] autorelease];
    if (!senderObject) {
        return;
    }
    NSDictionary *safeSender = [senderObject retain];
    TGTDLibClient *client = [self.client retain];
    [self runMutation:^BOOL(NSError **error) {
        BOOL result = [client setBlockedSender:safeSender blocked:NO timeout:10.0 error:error];
        [client release];
        [safeSender release];
        return result;
    }];
}

@end
