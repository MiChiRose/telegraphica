#import "TGContactsViewController.h"

#import "../Core/TGTDLibClient.h"
#import "TGContactManagementDialogs.h"
#import "TGContactProfileView.h"
#import "TGIconAssets.h"
#import "TGLocalization.h"
#import "TGMessageLayoutSupport.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

static NSString *TGContactsSubtitle(NSDictionary *contact) {
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
    return [parts componentsJoinedByString:@"  "];
}

@interface TGContactRowCell : TGRepresentedObjectCell
@end

@implementation TGContactRowCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *contact = [[self representedObject] isKindOfClass:[NSDictionary class]]
        ? [self representedObject]
        : nil;
    if (!contact) {
        return;
    }

    BOOL highlighted = [self isHighlighted];
    BOOL flipped = [controlView isFlipped];
    NSColor *ink = highlighted ? [NSColor whiteColor] : TGClassicCardInkColor();
    NSColor *muted = highlighted ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.80] : TGClassicCardMutedInkColor();
    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 10.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 34.0) / 2.0),
                                   34.0,
                                   34.0);
    NSString *avatarPath = [contact objectForKey:@"avatar_local_path"];
    NSString *name = [contact objectForKey:@"display_name"];
    TGDrawAvatarInRect(avatarPath, name, avatarRect, highlighted, flipped);

    if ([[contact objectForKey:@"is_online"] boolValue]) {
        NSRect onlineRect = NSMakeRect(NSMaxX(avatarRect) - 9.0, NSMinY(avatarRect) + 1.0, 8.0, 8.0);
        [[NSColor colorWithCalibratedRed:0.20 green:0.66 blue:0.31 alpha:1.0] set];
        [[NSBezierPath bezierPathWithOvalInRect:onlineRect] fill];
    }

    CGFloat textX = NSMaxX(avatarRect) + 11.0;
    CGFloat textWidth = MAX(20.0, NSMaxX(cellFrame) - textX - 10.0);
    NSDictionary *nameAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                                    ink, NSForegroundColorAttributeName,
                                    nil];
    NSDictionary *subtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                        muted, NSForegroundColorAttributeName,
                                        nil];
    [name drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 7.0, textWidth, 18.0)
      withAttributes:nameAttributes];
    NSString *subtitle = TGContactsSubtitle(contact);
    [subtitle drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 26.0, textWidth, 16.0)
          withAttributes:subtitleAttributes];
}

@end

@interface TGContactsViewController ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSSearchField *searchField;
@property (nonatomic, retain) TGGroupedCardView *listCardView;
@property (nonatomic, retain) NSScrollView *scrollView;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *createChatButton;
@property (nonatomic, retain) NSButton *openButton;
@property (nonatomic, retain) NSButton *actionButton;
@property (nonatomic, retain) TGContactProfileView *profileView;
@property (nonatomic, copy) NSArray *contacts;
@property (nonatomic, copy) NSArray *filteredContacts;
@property (nonatomic, retain) NSMutableDictionary *profilesByUserID;
@property (nonatomic, retain) NSNumber *profileLoadingUserID;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) NSUInteger requestGeneration;
@property (nonatomic, assign) NSUInteger profileRequestGeneration;
- (void)layoutContent;
- (void)loadSelectedContactProfile;
@end

@implementation TGContactsViewController

@synthesize delegate = _delegate;
@synthesize client = _client;
@synthesize titleField = _titleField;
@synthesize searchField = _searchField;
@synthesize listCardView = _listCardView;
@synthesize scrollView = _scrollView;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize refreshButton = _refreshButton;
@synthesize createChatButton = _createChatButton;
@synthesize openButton = _openButton;
@synthesize actionButton = _actionButton;
@synthesize profileView = _profileView;
@synthesize contacts = _contacts;
@synthesize filteredContacts = _filteredContacts;
@synthesize profilesByUserID = _profilesByUserID;
@synthesize profileLoadingUserID = _profileLoadingUserID;
@synthesize loading = _loading;
@synthesize loaded = _loaded;
@synthesize requestGeneration = _requestGeneration;
@synthesize profileRequestGeneration = _profileRequestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.client = client;
        self.contacts = [NSArray array];
        self.filteredContacts = [NSArray array];
        self.profilesByUserID = [NSMutableDictionary dictionary];
        [self buildView];
    }
    return self;
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

- (void)buildView {
    TGPanelView *root = [[[TGPanelView alloc] initWithFrame:NSMakeRect(0, 0, 720, 560)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self setView:root];

    self.titleField = [self labelWithFrame:NSMakeRect(72, 520, 576, 24)
                                      font:[NSFont boldSystemFontOfSize:15.0]
                                     color:TGClassicNavigationTextColor(1.0)];
    [self.titleField setAlignment:NSCenterTextAlignment];
    [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.titleField];

    self.createChatButton = [[[NSButton alloc] initWithFrame:NSMakeRect(634, 514, 30, 30)] autorelease];
    [self.createChatButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"+"] autorelease]];
    [self.createChatButton setTitle:@"+"];
    [self.createChatButton setTarget:self];
    [self.createChatButton setAction:@selector(showCreateMenu:)];
    [self.createChatButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.createChatButton];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(672, 514, 30, 30)] autorelease];
    [self.refreshButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"↻"] autorelease]];
    [self.refreshButton setTitle:@"↻"];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshContacts:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    self.searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(18, 478, 684, 28)] autorelease];
    [self.searchField setDelegate:(id)self];
    [self.searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.searchField];

    self.listCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 52, 684, 416)] autorelease];
    [root addSubview:self.listCardView];

    self.scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 58, 672, 404)] autorelease];
    [self.scrollView setHasVerticalScroller:YES];
    [self.scrollView setBorderType:NSNoBorder];
    [self.scrollView setDrawsBackground:NO];
    [self.scrollView setAutohidesScrollers:YES];
    [self.scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[self.scrollView contentView] bounds]] autorelease];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:50.0];
    [self.tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.tableView setBackgroundColor:[NSColor clearColor]];
    [self.tableView setAllowsMultipleSelection:NO];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(openSelectedContact:)];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"contact"] autorelease];
    [column setWidth:660.0];
    [column setDataCell:[[[TGContactRowCell alloc] initTextCell:@""] autorelease]];
    [self.tableView addTableColumn:column];
    [self.scrollView setDocumentView:self.tableView];
    [root addSubview:self.scrollView];

    self.profileView = [[[TGContactProfileView alloc] initWithFrame:NSMakeRect(470, 52, 232, 416)] autorelease];
    [root addSubview:self.profileView];

    self.statusField = [self labelWithFrame:NSMakeRect(18, 18, 450, 22)
                                      font:[NSFont systemFontOfSize:12.0]
                                     color:TGClassicMutedInkColor()];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(474, 20, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];

    self.openButton = [[[NSButton alloc] initWithFrame:NSMakeRect(520, 12, 182, 30)] autorelease];
    TGPrimaryTextButtonCell *openCell = [[[TGPrimaryTextButtonCell alloc] initTextCell:@""] autorelease];
    [openCell setButtonType:NSMomentaryPushInButton];
    [self.openButton setCell:openCell];
    [self.openButton setBordered:NO];
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openSelectedContact:)];
    [self.openButton setEnabled:NO];
    [self.openButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.openButton];

    self.actionButton = [[[NSButton alloc] initWithFrame:NSMakeRect(520, 12, 182, 30)] autorelease];
    TGSecondaryTextButtonCell *actionCell = [[[TGSecondaryTextButtonCell alloc] initTextCell:@""] autorelease];
    [actionCell setButtonType:NSMomentaryPushInButton];
    [self.actionButton setCell:actionCell];
    [self.actionButton setBordered:NO];
    [self.actionButton setTarget:self];
    [self.actionButton setAction:@selector(showSelectedContactActions:)];
    [self.actionButton setEnabled:NO];
    [self.actionButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.actionButton];

    [self refreshLocalizedText];
    [self refreshThemeAppearance];
    [self layoutContent];
}

- (void)layoutContent {
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 14.0;
    CGFloat headerHeight = 40.0;
    CGFloat buttonSize = 30.0;
    CGFloat buttonY = height - headerHeight + floor((headerHeight - buttonSize) / 2.0) - 2.0;
    CGFloat refreshX = width - margin - buttonSize;
    CGFloat createX = refreshX - 8.0 - buttonSize;
    CGFloat titleX = 58.0;
    CGFloat titleRight = createX - 8.0;
    [self.titleField setFrame:NSMakeRect(titleX,
                                         height - headerHeight + floor((headerHeight - 20.0) / 2.0) - 2.0,
                                         MAX(80.0, titleRight - titleX),
                                         20.0)];
    [self.createChatButton setFrame:NSMakeRect(createX, buttonY, buttonSize, buttonSize)];
    [self.refreshButton setFrame:NSMakeRect(refreshX, buttonY, buttonSize, buttonSize)];

    CGFloat searchY = height - headerHeight - 40.0;
    [self.searchField setFrame:NSMakeRect(margin, searchY, MAX(120.0, width - (margin * 2.0)), 28.0)];
    CGFloat tableTop = searchY - 8.0;
    BOOL showsProfile = (width >= 720.0);
    CGFloat footerHeight = showsProfile ? 48.0 : 78.0;
    CGFloat profileWidth = showsProfile ? MIN(320.0, MAX(250.0, floor(width * 0.34))) : 0.0;
    CGFloat listWidth = showsProfile ? (width - (margin * 3.0) - profileWidth) : (width - (margin * 2.0));
    [self.searchField setFrame:NSMakeRect(margin, searchY, MAX(120.0, listWidth), 28.0)];
    [self.profileView setHidden:!showsProfile];
    NSRect listCardFrame = NSMakeRect(margin,
                                      footerHeight,
                                      MAX(120.0, listWidth),
                                      MAX(80.0, tableTop - footerHeight));
    [self.listCardView setFrame:listCardFrame];
    [self.scrollView setFrame:NSInsetRect(listCardFrame, 7.0, 7.0)];
    if (showsProfile) {
        [self.profileView setFrame:NSMakeRect(margin * 2.0 + listWidth,
                                              footerHeight,
                                              profileWidth,
                                              MAX(80.0, tableTop - footerHeight))];
    }
    [self.scrollView tile];
    NSTableColumn *contactColumn = [self.tableView tableColumnWithIdentifier:@"contact"];
    if (contactColumn) {
        [contactColumn setWidth:MAX(100.0, NSWidth([[self.scrollView contentView] bounds]))];
    }
    if (showsProfile) {
        CGFloat profileX = margin * 2.0 + listWidth;
        [self.statusField setFrame:NSMakeRect(margin, 15.0, MAX(80.0, listWidth - 24.0), 22.0)];
        [self.spinner setFrame:NSMakeRect(margin + listWidth - 18.0, 18.0, 16.0, 16.0)];
        CGFloat actionGap = 8.0;
        CGFloat actionWidth = floor((profileWidth - actionGap) / 2.0);
        [self.openButton setFrame:NSMakeRect(profileX, 9.0, actionWidth, 32.0)];
        [self.actionButton setFrame:NSMakeRect(profileX + actionWidth + actionGap,
                                               9.0,
                                               profileWidth - actionWidth - actionGap,
                                               32.0)];
    } else {
        [self.statusField setFrame:NSMakeRect(margin, 48.0, MAX(80.0, width - margin * 2.0 - 24.0), 22.0)];
        [self.spinner setFrame:NSMakeRect(width - margin - 18.0, 51.0, 16.0, 16.0)];
        CGFloat actionGap = 8.0;
        CGFloat availableActionWidth = MAX(120.0, width - margin * 2.0);
        CGFloat actionWidth = floor((availableActionWidth - actionGap) / 2.0);
        [self.openButton setFrame:NSMakeRect(margin, 8.0, actionWidth, 32.0)];
        [self.actionButton setFrame:NSMakeRect(margin + actionWidth + actionGap,
                                               8.0,
                                               availableActionWidth - actionWidth - actionGap,
                                               32.0)];
    }
}

- (void)setView:(NSView *)view {
    [super setView:view];
    [view setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(viewFrameDidChange:)
                                                 name:NSViewFrameDidChangeNotification
                                               object:view];
}

- (void)viewFrameDidChange:(NSNotification *)notification {
    (void)notification;
    [self layoutContent];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil;
    [_client release];
    [_titleField release];
    [_searchField release];
    [_listCardView release];
    [_scrollView release];
    [_tableView release];
    [_statusField release];
    [_spinner release];
    [_refreshButton release];
    [_createChatButton release];
    [_openButton release];
    [_actionButton release];
    [_profileView release];
    [_contacts release];
    [_filteredContacts release];
    [_profilesByUserID release];
    [_profileLoadingUserID release];
    [super dealloc];
}

- (void)refreshLocalizedText {
    [self.titleField setStringValue:TGLoc(@"contacts.section.title")];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"contacts.search")];
    [self.refreshButton setTitle:@"↻"];
    [self.refreshButton setToolTip:TGLoc(@"contacts.refresh")];
    [self.createChatButton setTitle:@"+"];
    [self.createChatButton setToolTip:TGLoc(@"contacts.actions")];
    [self.openButton setTitle:TGLoc(@"contacts.open")];
    [self.actionButton setTitle:TGLoc(@"contacts.actions")];
    if (!self.loaded && !self.loading) {
        [self.statusField setStringValue:TGLoc(@"contacts.section.hint")];
    }
    [self.tableView reloadData];
}

- (void)refreshThemeAppearance {
    [self.titleField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.profileView refreshThemeAppearance];
    [self.listCardView setNeedsDisplay:YES];
    [self.openButton setNeedsDisplay:YES];
    [self.actionButton setNeedsDisplay:YES];
    [[self view] setNeedsDisplay:YES];
    [self.tableView setNeedsDisplay:YES];
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    [self.refreshButton setEnabled:!loading];
    [self.createChatButton setEnabled:!loading];
    [self.searchField setEnabled:!loading];
    [self.tableView setEnabled:!loading];
    [self.openButton setEnabled:(!loading && [self.tableView selectedRow] >= 0)];
    [self.actionButton setEnabled:(!loading && [self.tableView selectedRow] >= 0)];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
}

- (void)refreshContactsIfNeeded {
    if (!self.loaded && !self.loading) {
        [self refreshContacts:nil];
    }
}

- (void)refreshContacts:(id)sender {
    (void)sender;
    if (self.loading) {
        return;
    }
    self.requestGeneration++;
    self.profileRequestGeneration++;
    self.profileLoadingUserID = nil;
    [self.profilesByUserID removeAllObjects];
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
    [self.statusField setStringValue:TGLoc(@"contacts.loading")];
    TGTDLibClient *client = [self.client retain];
    TGContactsViewController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *contactsError = nil;
        NSArray *contacts = [[client contactSummariesWithTimeout:12.0 error:&contactsError] copy];
        NSString *errorMessage = [[contactsError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == controller.requestGeneration) {
                [controller setLoading:NO];
                controller.loaded = (contacts != nil);
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
    [self updateSelection];
    [self loadSelectedContactProfile];
    if ([self.filteredContacts count] == 0) {
        [self.statusField setStringValue:([self.contacts count] == 0 ? TGLoc(@"contacts.empty") : TGLoc(@"contacts.noResults"))];
    } else {
        [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"contacts.count"),
                                          (unsigned long)[self.filteredContacts count]]];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.filteredContacts count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;
    (void)column;
    return (row >= 0 && (NSUInteger)row < [self.filteredContacts count]) ?
        [self.filteredContacts objectAtIndex:(NSUInteger)row] : nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateSelection];
    [self loadSelectedContactProfile];
}

- (void)updateSelection {
    BOOL hasSelection = (!self.loading && [self.tableView selectedRow] >= 0);
    [self.openButton setEnabled:hasSelection];
    [self.actionButton setEnabled:hasSelection];
}

- (void)loadSelectedContactProfile {
    NSInteger row = [self.tableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.filteredContacts count]) {
        self.profileRequestGeneration++;
        self.profileLoadingUserID = nil;
        [self.profileView showPlaceholder];
        return;
    }
    NSDictionary *contact = [[self.filteredContacts objectAtIndex:(NSUInteger)row] retain];
    NSNumber *userID = [[contact objectForKey:@"user_id"] retain];
    NSDictionary *cachedProfile = [self.profilesByUserID objectForKey:userID];
    if (cachedProfile) {
        self.profileRequestGeneration++;
        self.profileLoadingUserID = nil;
        [self.profileView showContact:cachedProfile];
        [userID release];
        [contact release];
        return;
    }
    if ([self.profileLoadingUserID isEqualToNumber:userID]) {
        [self.profileView showLoadingForContact:contact];
        [userID release];
        [contact release];
        return;
    }
    self.profileRequestGeneration++;
    NSUInteger generation = self.profileRequestGeneration;
    self.profileLoadingUserID = userID;
    [self.profileView showLoadingForContact:contact];
    TGTDLibClient *client = [self.client retain];
    TGContactsViewController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *profileError = nil;
        NSDictionary *profile = [[client userProfileSummaryForUserID:userID timeout:6.0 error:&profileError] copy];
        NSString *errorMessage = [[profileError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger selectedRow = [controller.tableView selectedRow];
            NSNumber *selectedUserID = nil;
            if (selectedRow >= 0 && (NSUInteger)selectedRow < [controller.filteredContacts count]) {
                selectedUserID = [[controller.filteredContacts objectAtIndex:(NSUInteger)selectedRow] objectForKey:@"user_id"];
            }
            BOOL sameSelection = (selectedUserID &&
                                  [selectedUserID respondsToSelector:@selector(longLongValue)] &&
                                  [selectedUserID longLongValue] == [userID longLongValue]);
            if ([controller.profileLoadingUserID isEqualToNumber:userID]) {
                controller.profileLoadingUserID = nil;
            }
            if (profile) {
                [controller.profilesByUserID setObject:profile forKey:userID];
            }
            if (generation == controller.profileRequestGeneration && sameSelection) {
                if (profile) {
                    [controller.profileView showContact:profile];
                } else {
                    [controller.profileView showError:errorMessage contact:contact];
                }
            }
            [profile release];
            [errorMessage release];
            [client release];
            [controller release];
            [userID release];
            [contact release];
        });
        [pool drain];
    });
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.searchField) {
        [self applySearchFilter];
    }
}

- (void)requestNewConversation:(id)sender {
    (void)sender;
    [self.delegate contactsViewControllerDidRequestNewConversation:self];
}

- (NSDictionary *)selectedContact {
    NSInteger row = [self.tableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.filteredContacts count]) {
        return nil;
    }
    id contact = [self.filteredContacts objectAtIndex:(NSUInteger)row];
    return [contact isKindOfClass:[NSDictionary class]] ? contact : nil;
}

- (NSMenuItem *)menuItemWithTitle:(NSString *)title action:(SEL)action {
    NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""] autorelease];
    [item setTarget:self];
    return item;
}

- (void)showMenu:(NSMenu *)menu fromButton:(NSButton *)button {
    if (!menu || !button) {
        return;
    }
    [menu popUpMenuPositioningItem:nil
                       atLocation:NSMakePoint(0.0, NSHeight([button bounds]) + 2.0)
                           inView:button];
}

- (void)showCreateMenu:(id)sender {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    [menu addItem:[self menuItemWithTitle:TGLoc(@"contacts.newChat")
                                   action:@selector(requestNewConversation:)]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self menuItemWithTitle:TGLoc(@"contacts.add.action")
                                   action:@selector(addContact:)]];
    [menu addItem:[self menuItemWithTitle:TGLoc(@"contacts.invite.action")
                                   action:@selector(invitePerson:)]];
    [self showMenu:menu fromButton:[sender isKindOfClass:[NSButton class]] ? sender : self.createChatButton];
}

- (void)showSelectedContactActions:(id)sender {
    NSDictionary *contact = [self selectedContact];
    if (!contact) {
        return;
    }
    BOOL hasPhoneNumber = [[contact objectForKey:@"phone_number"] length] > 0;
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSMenuItem *sendItem = [self menuItemWithTitle:TGLoc(@"contacts.sendToCurrentChat")
                                            action:@selector(sendSelectedContact:)];
    [sendItem setEnabled:hasPhoneNumber];
    [menu addItem:sendItem];
    NSMenuItem *inviteItem = [self menuItemWithTitle:TGLoc(@"contacts.invite.selected")
                                              action:@selector(inviteSelectedContact:)];
    [inviteItem setEnabled:hasPhoneNumber];
    [menu addItem:inviteItem];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[self menuItemWithTitle:TGLoc(@"contacts.remove.action")
                                   action:@selector(removeSelectedContact:)]];
    [self showMenu:menu fromButton:[sender isKindOfClass:[NSButton class]] ? sender : self.actionButton];
}

- (void)addContact:(id)sender {
    (void)sender;
    if (self.loading) {
        return;
    }
    NSDictionary *contact = [TGContactManagementDialogs contactToAdd];
    if (!contact) {
        return;
    }
    NSDictionary *contactCopy = [contact copy];
    TGTDLibClient *client = [self.client retain];
    TGContactsViewController *controller = [self retain];
    [self setLoading:YES];
    [self.statusField setStringValue:TGLoc(@"contacts.add.saving")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *addError = nil;
        BOOL added = [client addContactWithPhoneNumber:[contactCopy objectForKey:@"phone_number"]
                                             firstName:[contactCopy objectForKey:@"first_name"]
                                              lastName:[contactCopy objectForKey:@"last_name"]
                                      sharePhoneNumber:[[contactCopy objectForKey:@"share_phone_number"] boolValue]
                                               timeout:8.0
                                                 error:&addError];
        NSString *errorMessage = [[addError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller setLoading:NO];
            if (added) {
                [controller.statusField setTextColor:TGClassicMutedInkColor()];
                [controller.statusField setStringValue:TGLoc(@"contacts.add.saved")];
                controller.loaded = NO;
                [controller refreshContacts:nil];
            } else {
                [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                [controller.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"contacts.add.failed"))];
            }
            [errorMessage release];
            [contactCopy release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
}

- (NSString *)normalizedInvitationPhoneNumber:(NSString *)phoneNumber {
    NSMutableString *normalized = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < [phoneNumber length]; index++) {
        unichar character = [phoneNumber characterAtIndex:index];
        if ((character >= '0' && character <= '9') ||
            (character == '+' && [normalized length] == 0)) {
            [normalized appendFormat:@"%C", character];
        }
    }
    return normalized;
}

- (void)openInvitationForPhoneNumber:(NSString *)phoneNumber {
    NSString *normalizedPhoneNumber = [self normalizedInvitationPhoneNumber:phoneNumber];
    if ([normalizedPhoneNumber length] == 0) {
        [self.statusField setStringValue:TGLoc(@"contacts.invite.failed")];
        return;
    }
    NSString *downloadLink = @"https://telegram.org/dl";
    NSString *invitationText = [NSString stringWithFormat:TGLoc(@"contacts.invite.message"), downloadLink];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteboard setString:invitationText forType:NSStringPboardType];

    NSString *escapedPhoneNumber = [normalizedPhoneNumber stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *messagesURL = [NSURL URLWithString:[NSString stringWithFormat:@"sms:%@", escapedPhoneNumber]];
    if ([[NSWorkspace sharedWorkspace] openURL:messagesURL]) {
        [self.statusField setStringValue:TGLoc(@"contacts.invite.opened")];
    } else {
        [self.statusField setStringValue:TGLoc(@"contacts.invite.copied")];
    }
}

- (void)invitePerson:(id)sender {
    (void)sender;
    NSString *phoneNumber = [TGContactManagementDialogs phoneNumberForInvitation];
    if ([phoneNumber length] > 0) {
        [self openInvitationForPhoneNumber:phoneNumber];
    }
}

- (void)inviteSelectedContact:(id)sender {
    (void)sender;
    NSDictionary *contact = [self selectedContact];
    [self openInvitationForPhoneNumber:[contact objectForKey:@"phone_number"]];
}

- (void)sendSelectedContact:(id)sender {
    (void)sender;
    NSDictionary *contact = [self selectedContact];
    if (!contact) {
        return;
    }
    if ([self.delegate contactsViewController:self didRequestSendContact:contact]) {
        [self.statusField setStringValue:TGLoc(@"contacts.sendRequested")];
    } else {
        [self.statusField setStringValue:TGLoc(@"contacts.sendNeedsChat")];
    }
}

- (void)removeSelectedContact:(id)sender {
    (void)sender;
    if (self.loading) {
        return;
    }
    NSDictionary *contact = [self selectedContact];
    NSNumber *userID = [contact objectForKey:@"user_id"];
    if (!contact || ![userID respondsToSelector:@selector(longLongValue)] ||
        ![TGContactManagementDialogs confirmRemovalOfContactNamed:[contact objectForKey:@"display_name"]]) {
        return;
    }

    NSNumber *userIDCopy = [userID retain];
    TGTDLibClient *client = [self.client retain];
    TGContactsViewController *controller = [self retain];
    [self setLoading:YES];
    [self.statusField setStringValue:TGLoc(@"contacts.remove.removing")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *removeError = nil;
        BOOL removed = [client removeContactWithUserID:userIDCopy timeout:8.0 error:&removeError];
        NSString *errorMessage = [[removeError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller setLoading:NO];
            if (removed) {
                [controller.statusField setTextColor:TGClassicMutedInkColor()];
                [controller.statusField setStringValue:TGLoc(@"contacts.remove.removed")];
                controller.loaded = NO;
                [controller refreshContacts:nil];
            } else {
                [controller.statusField setTextColor:[NSColor colorWithCalibratedRed:0.63 green:0.12 blue:0.10 alpha:1.0]];
                [controller.statusField setStringValue:([errorMessage length] > 0 ? errorMessage : TGLoc(@"contacts.remove.failed"))];
            }
            [errorMessage release];
            [userIDCopy release];
            [client release];
            [controller release];
        });
        [pool drain];
    });
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
    TGContactsViewController *controller = [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSNumber *chatID = [[client privateChatIDForUserID:userID timeout:8.0 error:&chatError] retain];
        NSString *errorMessage = [[chatError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller setLoading:NO];
            if (chatID) {
                [controller.statusField setStringValue:TGLoc(@"contacts.opened")];
                [controller.delegate contactsViewController:controller didOpenChatID:chatID title:title];
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

@end
