#import "TGContactsViewController.h"

#import "../Core/TGTDLibClient.h"
#import "TGLocalization.h"
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

static NSString *TGContactsInitials(NSString *displayName) {
    NSArray *parts = [displayName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableString *initials = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < [parts count] && [initials length] < 2; index++) {
        NSString *part = [parts objectAtIndex:index];
        if ([part length] > 0) {
            [initials appendString:[[part substringToIndex:1] uppercaseString]];
        }
    }
    return [initials length] > 0 ? initials : @"?";
}

@interface TGContactRowCell : NSCell
@end

@implementation TGContactRowCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *contact = [[self objectValue] isKindOfClass:[NSDictionary class]] ? [self objectValue] : nil;
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
    NSImage *avatar = ([avatarPath length] > 0) ? [[[NSImage alloc] initWithContentsOfFile:avatarPath] autorelease] : nil;
    NSBezierPath *avatarPathShape = [NSBezierPath bezierPathWithOvalInRect:avatarRect];
    [NSGraphicsContext saveGraphicsState];
    [avatarPathShape addClip];
    if (avatar) {
        [avatar drawInRect:avatarRect
                  fromRect:NSZeroRect
                 operation:NSCompositeSourceOver
                  fraction:1.0
            respectFlipped:flipped
                     hints:nil];
    } else {
        NSColor *fill = highlighted ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.18] :
            [NSColor colorWithCalibratedRed:0.29 green:0.53 blue:0.73 alpha:0.22];
        [fill set];
        NSRectFill(avatarRect);
        NSString *initials = TGContactsInitials([contact objectForKey:@"display_name"]);
        NSDictionary *initialAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                           ink, NSForegroundColorAttributeName,
                                           nil];
        NSSize initialsSize = [initials sizeWithAttributes:initialAttributes];
        [initials drawAtPoint:NSMakePoint(NSMidX(avatarRect) - floor(initialsSize.width / 2.0),
                                          NSMidY(avatarRect) - floor(initialsSize.height / 2.0))
               withAttributes:initialAttributes];
    }
    [NSGraphicsContext restoreGraphicsState];

    if ([[contact objectForKey:@"is_online"] boolValue]) {
        NSRect onlineRect = NSMakeRect(NSMaxX(avatarRect) - 9.0, NSMinY(avatarRect) + 1.0, 8.0, 8.0);
        [[NSColor colorWithCalibratedRed:0.20 green:0.66 blue:0.31 alpha:1.0] set];
        [[NSBezierPath bezierPathWithOvalInRect:onlineRect] fill];
    }

    CGFloat textX = NSMaxX(avatarRect) + 11.0;
    CGFloat textWidth = MAX(20.0, NSMaxX(cellFrame) - textX - 10.0);
    NSString *name = [contact objectForKey:@"display_name"];
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
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *createChatButton;
@property (nonatomic, retain) NSButton *openButton;
@property (nonatomic, copy) NSArray *contacts;
@property (nonatomic, copy) NSArray *filteredContacts;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGContactsViewController

@synthesize delegate = _delegate;
@synthesize client = _client;
@synthesize titleField = _titleField;
@synthesize searchField = _searchField;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize refreshButton = _refreshButton;
@synthesize createChatButton = _createChatButton;
@synthesize openButton = _openButton;
@synthesize contacts = _contacts;
@synthesize filteredContacts = _filteredContacts;
@synthesize loading = _loading;
@synthesize loaded = _loaded;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.client = client;
        self.contacts = [NSArray array];
        self.filteredContacts = [NSArray array];
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

    self.titleField = [self labelWithFrame:NSMakeRect(18, 520, 280, 24)
                                      font:[NSFont boldSystemFontOfSize:18.0]
                                     color:TGClassicInkColor()];
    [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.titleField];

    self.createChatButton = [[[NSButton alloc] initWithFrame:NSMakeRect(478, 514, 108, 30)] autorelease];
    [self.createChatButton setTarget:self];
    [self.createChatButton setAction:@selector(requestNewConversation:)];
    [self.createChatButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.createChatButton];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(594, 514, 108, 30)] autorelease];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshContacts:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    self.searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(18, 478, 684, 28)] autorelease];
    [self.searchField setDelegate:(id)self];
    [self.searchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.searchField];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(18, 52, 684, 416)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:50.0];
    [self.tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.tableView setAllowsMultipleSelection:NO];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(openSelectedContact:)];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"contact"] autorelease];
    [column setWidth:660.0];
    [column setDataCell:[[[TGContactRowCell alloc] initTextCell:@""] autorelease]];
    [self.tableView addTableColumn:column];
    [scrollView setDocumentView:self.tableView];
    [root addSubview:scrollView];

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
    [self.openButton setTarget:self];
    [self.openButton setAction:@selector(openSelectedContact:)];
    [self.openButton setEnabled:NO];
    [self.openButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.openButton];

    [self refreshLocalizedText];
    [self refreshThemeAppearance];
}

- (void)dealloc {
    _delegate = nil;
    [_client release];
    [_titleField release];
    [_searchField release];
    [_tableView release];
    [_statusField release];
    [_spinner release];
    [_refreshButton release];
    [_createChatButton release];
    [_openButton release];
    [_contacts release];
    [_filteredContacts release];
    [super dealloc];
}

- (void)refreshLocalizedText {
    [self.titleField setStringValue:TGLoc(@"contacts.section.title")];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"contacts.search")];
    [self.refreshButton setTitle:TGLoc(@"contacts.refresh")];
    [self.createChatButton setTitle:TGLoc(@"contacts.newChat")];
    [self.openButton setTitle:TGLoc(@"contacts.open")];
    if (!self.loaded && !self.loading) {
        [self.statusField setStringValue:TGLoc(@"contacts.section.hint")];
    }
    [self.tableView reloadData];
}

- (void)refreshThemeAppearance {
    [self.titleField setTextColor:TGClassicInkColor()];
    [self.statusField setTextColor:TGClassicMutedInkColor()];
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
}

- (void)updateSelection {
    [self.openButton setEnabled:(!self.loading && [self.tableView selectedRow] >= 0)];
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
