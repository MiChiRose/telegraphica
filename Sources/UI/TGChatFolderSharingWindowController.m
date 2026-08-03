#import "TGChatFolderSharingWindowController.h"

#import "../Core/TGTDLibClient+ChatFolders.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

@interface TGChatFolderSharingWindowController ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSDictionary *folderDefinition;
@property (nonatomic, copy) NSArray *inviteLinks;
@property (nonatomic, copy) NSArray *recommendedFolders;
@property (nonatomic, copy) NSArray *pendingChatIDs;
@property (nonatomic, retain) NSDictionary *limits;
@property (nonatomic, retain) NSTableView *linkTableView;
@property (nonatomic, retain) NSTableView *recommendedTableView;
@property (nonatomic, retain) NSTextField *limitsField;
@property (nonatomic, retain) NSTextField *pendingChatsField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *linkCopyButton;
@property (nonatomic, retain) NSButton *renameButton;
@property (nonatomic, retain) NSButton *deleteButton;
@property (nonatomic, retain) NSButton *createButton;
@property (nonatomic, retain) NSButton *addNewChatsButton;
@property (nonatomic, retain) NSButton *dismissNewChatsButton;
@property (nonatomic, retain) NSButton *addRecommendedButton;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGChatFolderSharingWindowController

@synthesize client = _client;
@synthesize folderDefinition = _folderDefinition;
@synthesize inviteLinks = _inviteLinks;
@synthesize recommendedFolders = _recommendedFolders;
@synthesize pendingChatIDs = _pendingChatIDs;
@synthesize limits = _limits;
@synthesize linkTableView = _linkTableView;
@synthesize recommendedTableView = _recommendedTableView;
@synthesize limitsField = _limitsField;
@synthesize pendingChatsField = _pendingChatsField;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize linkCopyButton = _linkCopyButton;
@synthesize renameButton = _renameButton;
@synthesize deleteButton = _deleteButton;
@synthesize createButton = _createButton;
@synthesize addNewChatsButton = _addNewChatsButton;
@synthesize dismissNewChatsButton = _dismissNewChatsButton;
@synthesize addRecommendedButton = _addRecommendedButton;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 760.0, 560.0)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.inviteLinks = [NSArray array];
        self.recommendedFolders = [NSArray array];
        self.pendingChatIDs = [NSArray array];
        self.limits = [NSDictionary dictionary];
        [[self window] setTitle:TGLoc(@"folders.links.title")];
        [[self window] setMinSize:NSMakeSize(680.0, 520.0)];
        [[self window] setMaxSize:NSMakeSize(980.0, 760.0)];
        [[self window] setReleasedWhenClosed:NO];
        [[self window] setDelegate:self];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [[self window] setDelegate:nil];
    [_client release];
    [_folderDefinition release];
    [_inviteLinks release];
    [_recommendedFolders release];
    [_pendingChatIDs release];
    [_limits release];
    [_linkTableView release];
    [_recommendedTableView release];
    [_limitsField release];
    [_pendingChatsField release];
    [_statusField release];
    [_spinner release];
    [_linkCopyButton release];
    [_renameButton release];
    [_deleteButton release];
    [_createButton release];
    [_addNewChatsButton release];
    [_dismissNewChatsButton release];
    [_addRecommendedButton release];
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

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title primary:(BOOL)primary action:(SEL)action {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    NSButtonCell *cell = primary
        ? [[[TGPrimaryTextButtonCell alloc] initTextCell:title] autorelease]
        : [[[TGSecondaryTextButtonCell alloc] initTextCell:title] autorelease];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (NSTableView *)tableInFrame:(NSRect)frame parent:(NSView *)parent identifier:(NSString *)identifier {
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:frame] autorelease];
    [scroll setBorderType:NSNoBorder];
    [scroll setHasVerticalScroller:YES];
    [scroll setAutohidesScrollers:YES];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    NSTableView *table = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    [table setDataSource:self];
    [table setDelegate:self];
    [table setHeaderView:nil];
    [table setRowHeight:42.0];
    [table setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [table setBackgroundColor:[NSColor clearColor]];
    [table setAllowsMultipleSelection:NO];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
    [column setWidth:NSWidth(frame) - 8.0];
    [table addTableColumn:column];
    [scroll setDocumentView:table];
    [parent addSubview:scroll];
    return table;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24.0, 520.0, 460.0, 26.0)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"folders.links.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24.0, 500.0, 620.0, 17.0)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderDetailTextColor(0.92)];
    [subtitle setStringValue:TGLoc(@"folders.links.subtitle")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];
    NSButton *refresh = [self buttonWithFrame:NSMakeRect(650.0, 510.0, 86.0, 30.0)
                                         title:TGLoc(@"refresh") primary:NO action:@selector(refreshAction:)];
    [refresh setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:refresh];

    TGUtilityPanelView *panel = [[[TGUtilityPanelView alloc] initWithFrame:NSMakeRect(14.0, 42.0, 732.0, 448.0)] autorelease];
    [panel setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:panel];

    NSTextField *linksLabel = [self labelWithFrame:NSMakeRect(30.0, 454.0, 250.0, 18.0)
                                               font:[NSFont boldSystemFontOfSize:12.0]
                                              color:TGClassicCardInkColor()];
    [linksLabel setStringValue:TGLoc(@"folders.links.list")];
    [linksLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:linksLabel];
    self.linkTableView = [self tableInFrame:NSMakeRect(28.0, 230.0, 338.0, 220.0)
                                     parent:root identifier:@"link"];
    [self.linkTableView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];

    NSTextField *recommendedLabel = [self labelWithFrame:NSMakeRect(390.0, 454.0, 250.0, 18.0)
                                                     font:[NSFont boldSystemFontOfSize:12.0]
                                                    color:TGClassicCardInkColor()];
    [recommendedLabel setStringValue:TGLoc(@"folders.recommended")];
    [recommendedLabel setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:recommendedLabel];
    self.recommendedTableView = [self tableInFrame:NSMakeRect(388.0, 230.0, 344.0, 220.0)
                                            parent:root identifier:@"recommended"];
    [self.recommendedTableView setAutoresizingMask:(NSViewMinXMargin | NSViewHeightSizable)];

    self.linkCopyButton = [self buttonWithFrame:NSMakeRect(28.0, 194.0, 76.0, 28.0) title:TGLoc(@"edit.copy") primary:NO action:@selector(copyLink:)];
    self.createButton = [self buttonWithFrame:NSMakeRect(108.0, 194.0, 76.0, 28.0) title:TGLoc(@"folders.links.create") primary:YES action:@selector(createLink:)];
    self.renameButton = [self buttonWithFrame:NSMakeRect(188.0, 194.0, 80.0, 28.0) title:TGLoc(@"folders.links.rename") primary:NO action:@selector(renameLink:)];
    self.deleteButton = [self buttonWithFrame:NSMakeRect(272.0, 194.0, 94.0, 28.0) title:TGLoc(@"delete") primary:NO action:@selector(deleteLink:)];
    NSArray *linkButtons = [NSArray arrayWithObjects:self.linkCopyButton, self.createButton, self.renameButton, self.deleteButton, nil];
    NSUInteger buttonIndex = 0;
    for (buttonIndex = 0; buttonIndex < [linkButtons count]; buttonIndex++) {
        NSButton *button = [linkButtons objectAtIndex:buttonIndex];
        [button setAutoresizingMask:NSViewMaxYMargin];
        [root addSubview:button];
    }

    self.addRecommendedButton = [self buttonWithFrame:NSMakeRect(610.0, 194.0, 122.0, 28.0)
                                                 title:TGLoc(@"folders.recommended.add") primary:NO action:@selector(addRecommended:)];
    [self.addRecommendedButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.addRecommendedButton];

    self.pendingChatsField = [self labelWithFrame:NSMakeRect(28.0, 152.0, 450.0, 18.0)
                                          font:[NSFont boldSystemFontOfSize:12.0]
                                         color:TGClassicCardInkColor()];
    [root addSubview:self.pendingChatsField];
    self.addNewChatsButton = [self buttonWithFrame:NSMakeRect(492.0, 146.0, 116.0, 28.0)
                                              title:TGLoc(@"folders.newChats.add") primary:NO action:@selector(addNewChats:)];
    self.dismissNewChatsButton = [self buttonWithFrame:NSMakeRect(612.0, 146.0, 120.0, 28.0)
                                                  title:TGLoc(@"folders.newChats.dismiss") primary:NO action:@selector(dismissNewChats:)];
    [root addSubview:self.addNewChatsButton];
    [root addSubview:self.dismissNewChatsButton];

    self.limitsField = [self labelWithFrame:NSMakeRect(28.0, 112.0, 704.0, 32.0)
                                        font:[NSFont systemFontOfSize:11.0]
                                       color:TGClassicCardMutedInkColor()];
    [[self.limitsField cell] setWraps:YES];
    [[self.limitsField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [root addSubview:self.limitsField];
    self.statusField = [self labelWithFrame:NSMakeRect(28.0, 70.0, 650.0, 20.0)
                                        font:[NSFont systemFontOfSize:11.0]
                                       color:TGClassicHeaderDetailTextColor(0.92)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(694.0, 72.0, 16.0, 16.0)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [root addSubview:self.spinner];
    [self updateControlStates];
}

- (void)configureWithFolderDefinition:(NSDictionary *)definition {
    self.folderDefinition = definition;
    [[self window] setTitle:[NSString stringWithFormat:TGLoc(@"folders.links.windowFormat"), [definition objectForKey:@"title"]]];
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
    [self updateControlStates];
}

- (void)updateControlStates {
    BOOL hasLink = [self.linkTableView selectedRow] >= 0 && (NSUInteger)[self.linkTableView selectedRow] < [self.inviteLinks count];
    BOOL hasRecommendation = [self.recommendedTableView selectedRow] >= 0 && (NSUInteger)[self.recommendedTableView selectedRow] < [self.recommendedFolders count];
    BOOL hasNewChats = [self.pendingChatIDs count] > 0;
    [self.linkCopyButton setEnabled:(!self.loading && hasLink)];
    [self.renameButton setEnabled:(!self.loading && hasLink)];
    [self.deleteButton setEnabled:(!self.loading && hasLink)];
    [self.createButton setEnabled:!self.loading];
    [self.addRecommendedButton setEnabled:(!self.loading && hasRecommendation)];
    [self.addNewChatsButton setEnabled:(!self.loading && hasNewChats)];
    [self.dismissNewChatsButton setEnabled:(!self.loading && hasNewChats)];
}

- (void)reloadData {
    if (!self.folderDefinition) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    self.loading = YES;
    [self.statusField setStringValue:TGLoc(@"folders.links.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *folderID = [[self.folderDefinition objectForKey:@"id"] retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *linkError = nil;
        NSArray *links = [[client chatFolderInviteLinksForFolderID:folderID timeout:4.0 error:&linkError] retain];
        NSError *newChatError = nil;
        NSArray *newChats = [[client newChatIDsForChatFolderID:folderID timeout:3.0 error:&newChatError] retain];
        NSError *recommendedError = nil;
        NSArray *recommended = [[client recommendedChatFolderDefinitionsWithTimeout:3.0 error:&recommendedError] retain];
        NSError *limitError = nil;
        NSDictionary *limits = [[client chatFolderServerLimitsWithTimeout:1.0 error:&limitError] retain];
        NSError *resultError = [linkError ? linkError : (newChatError ? newChatError : (recommendedError ? recommendedError : limitError)) retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration && self.client == client) {
                self.inviteLinks = links ? links : [NSArray array];
                self.pendingChatIDs = newChats ? newChats : [NSArray array];
                self.recommendedFolders = recommended ? recommended : [NSArray array];
                self.limits = limits ? limits : [NSDictionary dictionary];
                [self.linkTableView reloadData];
                [self.recommendedTableView reloadData];
                [self updateSummaryFields];
                [self.statusField setStringValue:(resultError ? [resultError localizedDescription] : TGLoc(@"folders.links.loaded"))];
                self.loading = NO;
            }
            [links release];
            [newChats release];
            [recommended release];
            [limits release];
            [resultError release];
            [folderID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)updateSummaryFields {
    [self.pendingChatsField setStringValue:[NSString stringWithFormat:TGLoc(@"folders.newChats.count"), (unsigned long)[self.pendingChatIDs count]]];
    NSNumber *folderLimit = [self.limits objectForKey:@"chat_folder_count_max"];
    NSNumber *chatLimit = [self.limits objectForKey:@"chat_folder_chosen_chat_count_max"];
    NSNumber *linkLimit = [self.limits objectForKey:@"chat_folder_invite_link_count_max"];
    if (folderLimit || chatLimit || linkLimit) {
        [self.limitsField setStringValue:[NSString stringWithFormat:TGLoc(@"folders.limits.format"),
                                          folderLimit ? folderLimit : @"—",
                                          chatLimit ? chatLimit : @"—",
                                          linkLimit ? linkLimit : @"—"]];
    } else {
        [self.limitsField setStringValue:TGLoc(@"folders.limits.unavailable")];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)[(tableView == self.linkTableView ? self.inviteLinks : self.recommendedFolders) count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)column;
    NSArray *source = tableView == self.linkTableView ? self.inviteLinks : self.recommendedFolders;
    if (row < 0 || (NSUInteger)row >= [source count]) {
        return nil;
    }
    NSDictionary *item = [source objectAtIndex:(NSUInteger)row];
    if (tableView == self.linkTableView) {
        NSString *name = [[item objectForKey:@"name"] length] > 0 ? [item objectForKey:@"name"] : TGLoc(@"folders.links.untitled");
        return [NSString stringWithFormat:@"%@  ·  %lu", name, (unsigned long)[[item objectForKey:@"chat_ids"] count]];
    }
    NSString *description = [item objectForKey:@"description"];
    return [description length] > 0
        ? [NSString stringWithFormat:@"%@ — %@", [item objectForKey:@"title"], description]
        : [item objectForKey:@"title"];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControlStates];
}

- (NSDictionary *)selectedLink {
    NSInteger row = [self.linkTableView selectedRow];
    return row >= 0 && (NSUInteger)row < [self.inviteLinks count] ? [self.inviteLinks objectAtIndex:(NSUInteger)row] : nil;
}

- (NSString *)promptForNameWithTitle:(NSString *)title value:(NSString *)value {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title];
    [alert addButtonWithTitle:TGLoc(@"save")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 0.0, 360.0, 24.0)] autorelease];
    [field setStringValue:value ? value : @""];
    [[field cell] setPlaceholderString:TGLoc(@"folders.links.name.placeholder")];
    [alert setAccessoryView:field];
    [[alert window] makeFirstResponder:field];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    return [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)performMutationWithStatus:(NSString *)status block:(BOOL (^)(NSError **error))block {
    self.loading = YES;
    [self.statusField setStringValue:status];
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.requestGeneration;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = block(&error);
        NSError *resultError = [error retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration && self.client == client) {
                self.loading = NO;
                if (success) {
                    [self reloadData];
                } else {
                    [self.statusField setStringValue:(resultError ? [resultError localizedDescription] : TGLoc(@"folders.links.error"))];
                    NSBeep();
                }
            }
            [resultError release];
            [client release];
        });
        [pool drain];
    });
}

- (void)copyLink:(id)sender {
    (void)sender;
    NSString *link = [[self selectedLink] objectForKey:@"invite_link"];
    if ([link length] == 0) {
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteboard setString:link forType:NSStringPboardType];
    [self.statusField setStringValue:TGLoc(@"folders.share.copied")];
}

- (void)createLink:(id)sender {
    (void)sender;
    NSString *name = [self promptForNameWithTitle:TGLoc(@"folders.links.create.title") value:@""];
    if (!name) {
        return;
    }
    TGTDLibClient *client = self.client;
    NSNumber *folderID = [self.folderDefinition objectForKey:@"id"];
    [self performMutationWithStatus:TGLoc(@"folders.links.creating") block:^BOOL(NSError **error) {
        NSArray *chatIDs = [client shareableChatIDsForFolderID:folderID timeout:4.0 error:error];
        return [chatIDs count] > 0 && [client createChatFolderInviteLinkForFolderID:folderID name:name chatIDs:chatIDs timeout:5.0 error:error] != nil;
    }];
}

- (void)renameLink:(id)sender {
    (void)sender;
    NSDictionary *selected = [self selectedLink];
    NSString *name = [self promptForNameWithTitle:TGLoc(@"folders.links.rename.title") value:[selected objectForKey:@"name"]];
    if (!name) {
        return;
    }
    TGTDLibClient *client = self.client;
    NSNumber *folderID = [self.folderDefinition objectForKey:@"id"];
    [self performMutationWithStatus:TGLoc(@"folders.links.renaming") block:^BOOL(NSError **error) {
        return [client editChatFolderInviteLinkForFolderID:folderID
                                                inviteLink:[selected objectForKey:@"invite_link"]
                                                      name:name
                                                   chatIDs:[selected objectForKey:@"chat_ids"]
                                                   timeout:5.0
                                                     error:error] != nil;
    }];
}

- (void)deleteLink:(id)sender {
    (void)sender;
    NSDictionary *selected = [self selectedLink];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"folders.links.delete.title")];
    [alert setInformativeText:TGLoc(@"folders.links.delete.text")];
    [alert addButtonWithTitle:TGLoc(@"delete")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    TGTDLibClient *client = self.client;
    NSNumber *folderID = [self.folderDefinition objectForKey:@"id"];
    [self performMutationWithStatus:TGLoc(@"folders.links.deleting") block:^BOOL(NSError **error) {
        return [client deleteChatFolderInviteLinkForFolderID:folderID
                                                  inviteLink:[selected objectForKey:@"invite_link"]
                                                     timeout:5.0 error:error];
    }];
}

- (void)processSuggestedChats:(NSArray *)chatIDs {
    TGTDLibClient *client = self.client;
    NSNumber *folderID = [self.folderDefinition objectForKey:@"id"];
    [self performMutationWithStatus:TGLoc(@"folders.newChats.processing") block:^BOOL(NSError **error) {
        return [client processNewChatIDs:chatIDs forChatFolderID:folderID timeout:5.0 error:error];
    }];
}

- (void)addNewChats:(id)sender {
    (void)sender;
    [self processSuggestedChats:self.pendingChatIDs];
}

- (void)dismissNewChats:(id)sender {
    (void)sender;
    [self processSuggestedChats:[NSArray array]];
}

- (void)addRecommended:(id)sender {
    (void)sender;
    NSInteger row = [self.recommendedTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.recommendedFolders count]) {
        return;
    }
    NSDictionary *definition = [[self.recommendedFolders objectAtIndex:(NSUInteger)row] objectForKey:@"definition"];
    TGTDLibClient *client = self.client;
    [self performMutationWithStatus:TGLoc(@"folders.recommended.adding") block:^BOOL(NSError **error) {
        return [client saveChatFolderDefinition:definition timeout:5.0 error:error] != nil;
    }];
}

- (void)refreshAction:(id)sender {
    (void)sender;
    [self reloadData];
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    self.requestGeneration++;
    self.loading = NO;
}

@end
