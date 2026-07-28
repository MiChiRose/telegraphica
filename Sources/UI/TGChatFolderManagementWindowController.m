#import "TGChatFolderManagementWindowController.h"

#import "../Core/TGChatItem.h"
#import "../Core/TGTDLibClient+ChatFolders.h"
#import "TGIconAssets.h"
#import "TGLocalization.h"
#import "TGMessageLayoutSupport.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGChatFolderListCell : TGRepresentedObjectCell
@end

@implementation TGChatFolderListCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSDictionary *folder = [[self representedObject] isKindOfClass:[NSDictionary class]]
        ? [self representedObject]
        : nil;
    if (!folder) {
        return;
    }

    BOOL highlighted = [self isHighlighted];
    NSColor *titleColor = highlighted ? [NSColor whiteColor] : TGClassicCardInkColor();
    NSColor *detailColor = highlighted
        ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.78]
        : TGClassicCardMutedInkColor();
    NSRect iconRect = NSMakeRect(NSMinX(cellFrame) + 8.0,
                                 NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 18.0) / 2.0),
                                 18.0,
                                 18.0);
    TGDrawTemplateIconAsset(@"folder", iconRect, titleColor, 0.92, [controlView isFlipped]);

    CGFloat textX = NSMaxX(iconRect) + 8.0;
    CGFloat textWidth = MAX(36.0, NSMaxX(cellFrame) - textX - 8.0);
    BOOL shared = [[folder objectForKey:@"is_shareable"] boolValue];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     titleColor, NSForegroundColorAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:10.0], NSFontAttributeName,
                                      detailColor, NSForegroundColorAttributeName,
                                      nil];
    NSString *title = [[folder objectForKey:@"title"] isKindOfClass:[NSString class]]
        ? [folder objectForKey:@"title"]
        : @"";
    CGFloat titleY = shared ? NSMinY(cellFrame) + 5.0 : NSMinY(cellFrame) + 12.0;
    [title drawInRect:NSMakeRect(textX, titleY, textWidth, 16.0)
       withAttributes:titleAttributes];
    if (shared) {
        [TGLoc(@"folders.shared") drawInRect:NSMakeRect(textX,
                                                        NSMinY(cellFrame) + 21.0,
                                                        textWidth,
                                                        13.0)
                              withAttributes:detailAttributes];
    }
}

@end

@interface TGChatFolderChatCell : TGRepresentedObjectCell
@end

@implementation TGChatFolderChatCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGChatItem *item = [[self representedObject] isKindOfClass:[TGChatItem class]]
        ? [self representedObject]
        : nil;
    if (!item) {
        return;
    }
    BOOL highlighted = [self isHighlighted];
    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 5.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 28.0) / 2.0),
                                   28.0,
                                   28.0);
    TGDrawAvatarInRect([item avatarLocalPath],
                       [item title],
                       avatarRect,
                       highlighted,
                       [controlView isFlipped]);

    CGFloat textX = NSMaxX(avatarRect) + 9.0;
    CGFloat width = MAX(40.0, NSMaxX(cellFrame) - textX - 8.0);
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     highlighted ? [NSColor whiteColor] : TGClassicCardInkColor(), NSForegroundColorAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:10.0], NSFontAttributeName,
                                      highlighted ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.78] : TGClassicCardMutedInkColor(), NSForegroundColorAttributeName,
                                      nil];
    [[item title] drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 4.0, width, 16.0)
              withAttributes:titleAttributes];
    [[item typeSummary] drawInRect:NSMakeRect(textX, NSMinY(cellFrame) + 20.0, width, 14.0)
                    withAttributes:detailAttributes];
}

@end

@interface TGChatFolderManagementWindowController ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTableView *folderTableView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSSearchField *chatSearchField;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *addButton;
@property (nonatomic, retain) NSButton *deleteButton;
@property (nonatomic, retain) NSButton *shareButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *saveButton;
@property (nonatomic, retain) NSButton *includeContactsButton;
@property (nonatomic, retain) NSButton *includeNonContactsButton;
@property (nonatomic, retain) NSButton *includeBotsButton;
@property (nonatomic, retain) NSButton *includeGroupsButton;
@property (nonatomic, retain) NSButton *includeChannelsButton;
@property (nonatomic, retain) NSButton *excludeMutedButton;
@property (nonatomic, retain) NSButton *excludeReadButton;
@property (nonatomic, retain) NSButton *excludeArchivedButton;
@property (nonatomic, copy) NSArray *folderDefinitions;
@property (nonatomic, copy) NSArray *chatItems;
@property (nonatomic, copy) NSArray *filteredChatItems;
@property (nonatomic, retain) NSMutableSet *selectedChatIDs;
@property (nonatomic, retain) NSDictionary *editingDefinition;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGChatFolderManagementWindowController

@synthesize delegate = _delegate;
@synthesize client = _client;
@synthesize folderTableView = _folderTableView;
@synthesize chatTableView = _chatTableView;
@synthesize chatSearchField = _chatSearchField;
@synthesize titleField = _titleField;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize addButton = _addButton;
@synthesize deleteButton = _deleteButton;
@synthesize shareButton = _shareButton;
@synthesize refreshButton = _refreshButton;
@synthesize saveButton = _saveButton;
@synthesize includeContactsButton = _includeContactsButton;
@synthesize includeNonContactsButton = _includeNonContactsButton;
@synthesize includeBotsButton = _includeBotsButton;
@synthesize includeGroupsButton = _includeGroupsButton;
@synthesize includeChannelsButton = _includeChannelsButton;
@synthesize excludeMutedButton = _excludeMutedButton;
@synthesize excludeReadButton = _excludeReadButton;
@synthesize excludeArchivedButton = _excludeArchivedButton;
@synthesize folderDefinitions = _folderDefinitions;
@synthesize chatItems = _chatItems;
@synthesize filteredChatItems = _filteredChatItems;
@synthesize selectedChatIDs = _selectedChatIDs;
@synthesize editingDefinition = _editingDefinition;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 780, 640)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.folderDefinitions = [NSArray array];
        self.chatItems = [NSArray array];
        self.filteredChatItems = [NSArray array];
        self.selectedChatIDs = [NSMutableSet set];
        [[self window] setTitle:TGLoc(@"folders.manage.title")];
        [[self window] setMinSize:NSMakeSize(720.0, 600.0)];
        [[self window] setMaxSize:NSMakeSize(980.0, 760.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [_client release];
    [_folderTableView release];
    [_chatTableView release];
    [_chatSearchField release];
    [_titleField release];
    [_statusField release];
    [_spinner release];
    [_addButton release];
    [_deleteButton release];
    [_shareButton release];
    [_refreshButton release];
    [_saveButton release];
    [_includeContactsButton release];
    [_includeNonContactsButton release];
    [_includeBotsButton release];
    [_includeGroupsButton release];
    [_includeChannelsButton release];
    [_excludeMutedButton release];
    [_excludeReadButton release];
    [_excludeArchivedButton release];
    [_folderDefinitions release];
    [_chatItems release];
    [_filteredChatItems release];
    [_selectedChatIDs release];
    [_editingDefinition release];
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

- (NSButton *)iconButtonWithFrame:(NSRect)frame assetName:(NSString *)assetName toolTip:(NSString *)toolTip action:(SEL)action {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@""] autorelease]];
    [button setTitle:@""];
    [button setImage:TGTemplateIconAssetImage(assetName, NSMakeSize(18.0, 18.0), TGClassicHeaderTextColor(1.0), 1.0)];
    [button setToolTip:toolTip];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (NSButton *)checkButtonWithFrame:(NSRect)frame title:(NSString *)title {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setButtonType:NSSwitchButton];
    [button setTitle:title];
    [button setFont:[NSFont systemFontOfSize:11.0]];
    return button;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    TGUtilityPanelView *panel = [[[TGUtilityPanelView alloc] initWithFrame:NSMakeRect(12, 44, 756, 530)] autorelease];
    [panel setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:panel];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 594, 430, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"folders.manage.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];

    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24, 574, 500, 17)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderDetailTextColor(0.92)];
    [subtitle setStringValue:TGLoc(@"folders.manage.subtitle")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];

    self.addButton = [self iconButtonWithFrame:NSMakeRect(604, 584, 34, 32)
                                    assetName:@"folder-add"
                                       toolTip:TGLoc(@"folders.add")
                                        action:@selector(addFolder:)];
    [self.addButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.addButton];

    self.deleteButton = [self iconButtonWithFrame:NSMakeRect(642, 584, 34, 32)
                                       assetName:@"folder-remove"
                                          toolTip:TGLoc(@"folders.delete")
                                           action:@selector(deleteFolder:)];
    [self.deleteButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.deleteButton];

    self.shareButton = [self iconButtonWithFrame:NSMakeRect(680, 584, 34, 32)
                                      assetName:@"folder-share"
                                         toolTip:TGLoc(@"folders.share")
                                          action:@selector(shareFolder:)];
    [self.shareButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.shareButton];

    self.refreshButton = [self iconButtonWithFrame:NSMakeRect(718, 584, 34, 32)
                                        assetName:@"refresh"
                                           toolTip:TGLoc(@"folders.refresh")
                                            action:@selector(refreshAction:)];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *folderCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 54, 210, 510)] autorelease];
    [folderCard setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:folderCard];

    NSTextField *folderLabel = [self labelWithFrame:NSMakeRect(32, 536, 180, 18)
                                               font:[NSFont boldSystemFontOfSize:12.0]
                                              color:TGClassicCardInkColor()];
    [folderLabel setStringValue:TGLoc(@"folders.list")];
    [folderLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:folderLabel];

    TGScrollSurfaceView *folderSurface = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(24, 60, 202, 470)] autorelease];
    [folderSurface setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:folderSurface];
    NSScrollView *folderScroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(28, 64, 194, 462)] autorelease];
    [folderScroll setHasVerticalScroller:YES];
    [folderScroll setAutohidesScrollers:YES];
    [folderScroll setBorderType:NSNoBorder];
    [folderScroll setDrawsBackground:NO];
    [folderScroll setAutoresizingMask:NSViewHeightSizable];
    self.folderTableView = [[[NSTableView alloc] initWithFrame:[[folderScroll contentView] bounds]] autorelease];
    [self.folderTableView setDataSource:self];
    [self.folderTableView setDelegate:self];
    [self.folderTableView setHeaderView:nil];
    [self.folderTableView setRowHeight:42.0];
    [self.folderTableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.folderTableView setBackgroundColor:[NSColor clearColor]];
    [self.folderTableView setAllowsEmptySelection:NO];
    [self.folderTableView setAllowsMultipleSelection:NO];
    [self.folderTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
    [self.folderTableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
    NSTableColumn *folderColumn = [[[NSTableColumn alloc] initWithIdentifier:@"folder"] autorelease];
    [folderColumn setWidth:190.0];
    [folderColumn setMinWidth:120.0];
    [folderColumn setDataCell:[[[TGChatFolderListCell alloc] initTextCell:@""] autorelease]];
    [self.folderTableView addTableColumn:folderColumn];
    [folderScroll setDocumentView:self.folderTableView];
    [root addSubview:folderScroll];

    TGGroupedCardView *editorCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(240, 54, 520, 510)] autorelease];
    [editorCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:editorCard];

    NSTextField *nameLabel = [self labelWithFrame:NSMakeRect(256, 526, 130, 18)
                                             font:[NSFont boldSystemFontOfSize:12.0]
                                            color:TGClassicCardInkColor()];
    [nameLabel setStringValue:TGLoc(@"folders.name")];
    [nameLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:nameLabel];

    self.titleField = [[[NSTextField alloc] initWithFrame:NSMakeRect(256, 494, 484, 26)] autorelease];
    [[self.titleField cell] setPlaceholderString:TGLoc(@"folders.name.placeholder")];
    [self.titleField setDelegate:self];
    [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.titleField];

    NSTextField *includeLabel = [self labelWithFrame:NSMakeRect(256, 468, 220, 18)
                                                font:[NSFont boldSystemFontOfSize:11.0]
                                               color:TGClassicCardInkColor()];
    [includeLabel setStringValue:TGLoc(@"folders.include")];
    [includeLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:includeLabel];

    self.includeContactsButton = [self checkButtonWithFrame:NSMakeRect(256, 444, 150, 20) title:TGLoc(@"folders.contacts")];
    self.includeNonContactsButton = [self checkButtonWithFrame:NSMakeRect(408, 444, 150, 20) title:TGLoc(@"folders.nonContacts")];
    self.includeBotsButton = [self checkButtonWithFrame:NSMakeRect(560, 444, 100, 20) title:TGLoc(@"folders.bots")];
    self.includeGroupsButton = [self checkButtonWithFrame:NSMakeRect(256, 422, 150, 20) title:TGLoc(@"folders.groups")];
    self.includeChannelsButton = [self checkButtonWithFrame:NSMakeRect(408, 422, 150, 20) title:TGLoc(@"folders.channels")];
    NSArray *includeButtons = [NSArray arrayWithObjects:
                               self.includeContactsButton,
                               self.includeNonContactsButton,
                               self.includeBotsButton,
                               self.includeGroupsButton,
                               self.includeChannelsButton,
                               nil];
    NSUInteger includeIndex = 0;
    for (includeIndex = 0; includeIndex < [includeButtons count]; includeIndex++) {
        NSButton *button = [includeButtons objectAtIndex:includeIndex];
        [button setAutoresizingMask:NSViewMinYMargin];
        [root addSubview:button];
    }

    NSTextField *excludeLabel = [self labelWithFrame:NSMakeRect(256, 396, 220, 18)
                                                font:[NSFont boldSystemFontOfSize:11.0]
                                               color:TGClassicCardInkColor()];
    [excludeLabel setStringValue:TGLoc(@"folders.exclude")];
    [excludeLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:excludeLabel];

    self.excludeMutedButton = [self checkButtonWithFrame:NSMakeRect(256, 372, 150, 20) title:TGLoc(@"folders.muted")];
    self.excludeReadButton = [self checkButtonWithFrame:NSMakeRect(408, 372, 150, 20) title:TGLoc(@"folders.read")];
    self.excludeArchivedButton = [self checkButtonWithFrame:NSMakeRect(560, 372, 170, 20) title:TGLoc(@"folders.archived")];
    NSArray *excludeButtons = [NSArray arrayWithObjects:self.excludeMutedButton, self.excludeReadButton, self.excludeArchivedButton, nil];
    NSUInteger excludeIndex = 0;
    for (excludeIndex = 0; excludeIndex < [excludeButtons count]; excludeIndex++) {
        NSButton *button = [excludeButtons objectAtIndex:excludeIndex];
        [button setAutoresizingMask:NSViewMinYMargin];
        [root addSubview:button];
    }

    NSTextField *chatLabel = [self labelWithFrame:NSMakeRect(256, 342, 230, 18)
                                             font:[NSFont boldSystemFontOfSize:11.0]
                                            color:TGClassicCardInkColor()];
    [chatLabel setStringValue:TGLoc(@"folders.alwaysInclude")];
    [chatLabel setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:chatLabel];

    self.chatSearchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(500, 336, 240, 26)] autorelease];
    [[self.chatSearchField cell] setPlaceholderString:TGLoc(@"folders.searchChats")];
    [self.chatSearchField setDelegate:self];
    [self.chatSearchField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:self.chatSearchField];

    TGScrollSurfaceView *chatSurface = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(248, 100, 504, 232)] autorelease];
    [chatSurface setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:chatSurface];
    NSScrollView *chatScroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(252, 104, 496, 224)] autorelease];
    [chatScroll setHasVerticalScroller:YES];
    [chatScroll setAutohidesScrollers:YES];
    [chatScroll setBorderType:NSNoBorder];
    [chatScroll setDrawsBackground:NO];
    [chatScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[chatScroll contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setHeaderView:nil];
    [self.chatTableView setRowHeight:38.0];
    [self.chatTableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [self.chatTableView setBackgroundColor:[NSColor clearColor]];
    [self.chatTableView setAllowsMultipleSelection:NO];
    NSTableColumn *includeColumn = [[[NSTableColumn alloc] initWithIdentifier:@"included"] autorelease];
    [includeColumn setWidth:30.0];
    [includeColumn setEditable:YES];
    NSButtonCell *checkCell = [[[NSButtonCell alloc] init] autorelease];
    [checkCell setButtonType:NSSwitchButton];
    [checkCell setTitle:@""];
    [includeColumn setDataCell:checkCell];
    [self.chatTableView addTableColumn:includeColumn];
    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"chat"] autorelease];
    [chatColumn setWidth:450.0];
    [chatColumn setDataCell:[[[TGChatFolderChatCell alloc] initTextCell:@""] autorelease]];
    [self.chatTableView addTableColumn:chatColumn];
    [chatScroll setDocumentView:self.chatTableView];
    [root addSubview:chatScroll];

    self.statusField = [self labelWithFrame:NSMakeRect(256, 76, 330, 18)
                                       font:[NSFont systemFontOfSize:11.0]
                                      color:TGClassicHeaderDetailTextColor(0.92)];
    [self.statusField setStringValue:@""];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];

    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(590, 76, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setControlSize:NSSmallControlSize];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:NSViewMaxYMargin];
    [root addSubview:self.spinner];

    self.saveButton = [[[NSButton alloc] initWithFrame:NSMakeRect(620, 68, 120, 30)] autorelease];
    [self.saveButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"folders.save")] autorelease]];
    [self.saveButton setTitle:TGLoc(@"folders.save")];
    [self.saveButton setTarget:self];
    [self.saveButton setAction:@selector(saveFolder:)];
    [self.saveButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.saveButton];

    [self updateControlStates];
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
    BOOL hasFolder = self.editingDefinition != nil;
    BOOL supportsSharing = hasFolder &&
        [self.client chatFolderAPIKindSupportsSharing:[self.editingDefinition objectForKey:@"api_kind"]];
    [self.addButton setEnabled:!self.loading];
    [self.deleteButton setEnabled:(!self.loading && hasFolder)];
    [self.shareButton setEnabled:(!self.loading && hasFolder && supportsSharing)];
    [self.refreshButton setEnabled:!self.loading];
    [self.saveButton setEnabled:!self.loading];
    [self.folderTableView setEnabled:!self.loading];
    [self.chatTableView setEnabled:!self.loading];
    [self.titleField setEnabled:!self.loading];
    [self.shareButton setToolTip:(supportsSharing
                                  ? TGLoc(@"folders.share")
                                  : TGLoc(@"folders.share.unsupported"))];
}

- (void)reloadFolders {
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    self.loading = YES;
    [self.statusField setStringValue:TGLoc(@"folders.loading")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *folderError = nil;
        NSArray *folders = [[client chatFolderDefinitionsWithTimeout:2.0 error:&folderError] retain];
        NSError *chatError = nil;
        NSArray *chats = [[client mainChatPreviewItemsWithLimit:100 timeout:2.0 error:&chatError] retain];
        NSError *resultError = folderError ? [folderError retain] : [chatError retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration && self.client == client) {
                self.folderDefinitions = folders ? folders : [NSArray array];
                self.chatItems = chats ? chats : [NSArray array];
                [self applyChatSearch];
                [self.folderTableView reloadData];
                if ([self.folderDefinitions count] > 0) {
                    [self.folderTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                    [self editFolderAtIndex:0];
                } else {
                    [self beginNewFolder];
                }
                NSString *status = resultError
                    ? [resultError localizedDescription]
                    : [NSString stringWithFormat:TGLoc(@"folders.loaded"), (unsigned long)[self.folderDefinitions count]];
                [self.statusField setStringValue:status];
                self.loading = NO;
            }
            [folders release];
            [chats release];
            [resultError release];
            [client release];
        });
        [pool drain];
    });
}

- (void)beginNewFolder {
    self.editingDefinition = nil;
    [self.folderTableView deselectAll:nil];
    [self.titleField setStringValue:@""];
    [self.includeContactsButton setState:NSOffState];
    [self.includeNonContactsButton setState:NSOffState];
    [self.includeBotsButton setState:NSOffState];
    [self.includeGroupsButton setState:NSOffState];
    [self.includeChannelsButton setState:NSOffState];
    [self.excludeMutedButton setState:NSOffState];
    [self.excludeReadButton setState:NSOffState];
    [self.excludeArchivedButton setState:NSOffState];
    [self.selectedChatIDs removeAllObjects];
    [self.chatTableView reloadData];
    [self.statusField setStringValue:TGLoc(@"folders.new.help")];
    [self updateControlStates];
    [[self window] makeFirstResponder:self.titleField];
}

- (void)editFolderAtIndex:(NSInteger)index {
    if (index < 0 || (NSUInteger)index >= [self.folderDefinitions count]) {
        return;
    }
    NSDictionary *definition = [self.folderDefinitions objectAtIndex:(NSUInteger)index];
    self.editingDefinition = definition;
    [self.titleField setStringValue:[definition objectForKey:@"title"]];
    [self.includeContactsButton setState:[[definition objectForKey:@"include_contacts"] boolValue] ? NSOnState : NSOffState];
    [self.includeNonContactsButton setState:[[definition objectForKey:@"include_non_contacts"] boolValue] ? NSOnState : NSOffState];
    [self.includeBotsButton setState:[[definition objectForKey:@"include_bots"] boolValue] ? NSOnState : NSOffState];
    [self.includeGroupsButton setState:[[definition objectForKey:@"include_groups"] boolValue] ? NSOnState : NSOffState];
    [self.includeChannelsButton setState:[[definition objectForKey:@"include_channels"] boolValue] ? NSOnState : NSOffState];
    [self.excludeMutedButton setState:[[definition objectForKey:@"exclude_muted"] boolValue] ? NSOnState : NSOffState];
    [self.excludeReadButton setState:[[definition objectForKey:@"exclude_read"] boolValue] ? NSOnState : NSOffState];
    [self.excludeArchivedButton setState:[[definition objectForKey:@"exclude_archived"] boolValue] ? NSOnState : NSOffState];
    [self.selectedChatIDs removeAllObjects];
    [self.selectedChatIDs addObjectsFromArray:[definition objectForKey:@"included_chat_ids"]];
    [self.selectedChatIDs addObjectsFromArray:[definition objectForKey:@"pinned_chat_ids"]];
    [self.chatTableView reloadData];
    [self updateControlStates];
}

- (void)applyChatSearch {
    NSString *query = [[[self.chatSearchField stringValue] lowercaseString]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        self.filteredChatItems = self.chatItems;
    } else {
        NSMutableArray *matches = [NSMutableArray array];
        NSUInteger index = 0;
        for (index = 0; index < [self.chatItems count]; index++) {
            TGChatItem *item = [self.chatItems objectAtIndex:index];
            NSString *haystack = [NSString stringWithFormat:@"%@ %@", [item title], [item typeSummary]];
            if ([[haystack lowercaseString] rangeOfString:query].location != NSNotFound) {
                [matches addObject:item];
            }
        }
        self.filteredChatItems = matches;
    }
    [self.chatTableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.folderTableView) {
        return (NSInteger)[self.folderDefinitions count];
    }
    return (NSInteger)[self.filteredChatItems count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.folderTableView) {
        if (row < 0 || (NSUInteger)row >= [self.folderDefinitions count]) {
            return nil;
        }
        return [self.folderDefinitions objectAtIndex:(NSUInteger)row];
    }
    if (row < 0 || (NSUInteger)row >= [self.filteredChatItems count]) {
        return nil;
    }
    TGChatItem *item = [self.filteredChatItems objectAtIndex:(NSUInteger)row];
    if ([[tableColumn identifier] isEqualToString:@"included"]) {
        return [NSNumber numberWithBool:[self.selectedChatIDs containsObject:[item chatID]]];
    }
    return item;
}

- (void)tableView:(NSTableView *)tableView
    setObjectValue:(id)object
    forTableColumn:(NSTableColumn *)tableColumn
               row:(NSInteger)row {
    if (tableView != self.chatTableView ||
        ![[tableColumn identifier] isEqualToString:@"included"] ||
        row < 0 ||
        (NSUInteger)row >= [self.filteredChatItems count]) {
        return;
    }
    TGChatItem *item = [self.filteredChatItems objectAtIndex:(NSUInteger)row];
    if ([object boolValue]) {
        [self.selectedChatIDs addObject:[item chatID]];
    } else {
        [self.selectedChatIDs removeObject:[item chatID]];
    }
    [self.chatTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] == self.folderTableView) {
        [self editFolderAtIndex:[self.folderTableView selectedRow]];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.chatSearchField) {
        [self applyChatSearch];
    }
}

- (void)addFolder:(id)sender {
    (void)sender;
    [self beginNewFolder];
}

- (void)refreshAction:(id)sender {
    (void)sender;
    [self reloadFolders];
}

- (NSDictionary *)definitionFromControls {
    NSMutableDictionary *definition = self.editingDefinition
        ? [NSMutableDictionary dictionaryWithDictionary:self.editingDefinition]
        : [NSMutableDictionary dictionary];
    [definition setObject:[self.titleField stringValue] forKey:@"title"];
    if (![definition objectForKey:@"icon_name"]) {
        [definition setObject:@"Custom" forKey:@"icon_name"];
    }
    if (![definition objectForKey:@"pinned_chat_ids"]) {
        [definition setObject:[NSArray array] forKey:@"pinned_chat_ids"];
    }
    if (![definition objectForKey:@"excluded_chat_ids"]) {
        [definition setObject:[NSArray array] forKey:@"excluded_chat_ids"];
    }
    NSMutableArray *includedIDs = [NSMutableArray arrayWithArray:[self.selectedChatIDs allObjects]];
    NSArray *pinnedIDs = [definition objectForKey:@"pinned_chat_ids"];
    [includedIDs removeObjectsInArray:pinnedIDs];
    [definition setObject:includedIDs forKey:@"included_chat_ids"];
    [definition setObject:[NSNumber numberWithBool:[self.includeContactsButton state] == NSOnState] forKey:@"include_contacts"];
    [definition setObject:[NSNumber numberWithBool:[self.includeNonContactsButton state] == NSOnState] forKey:@"include_non_contacts"];
    [definition setObject:[NSNumber numberWithBool:[self.includeBotsButton state] == NSOnState] forKey:@"include_bots"];
    [definition setObject:[NSNumber numberWithBool:[self.includeGroupsButton state] == NSOnState] forKey:@"include_groups"];
    [definition setObject:[NSNumber numberWithBool:[self.includeChannelsButton state] == NSOnState] forKey:@"include_channels"];
    [definition setObject:[NSNumber numberWithBool:[self.excludeMutedButton state] == NSOnState] forKey:@"exclude_muted"];
    [definition setObject:[NSNumber numberWithBool:[self.excludeReadButton state] == NSOnState] forKey:@"exclude_read"];
    [definition setObject:[NSNumber numberWithBool:[self.excludeArchivedButton state] == NSOnState] forKey:@"exclude_archived"];
    return definition;
}

- (BOOL)definitionHasInclusionRule:(NSDictionary *)definition {
    if ([[definition objectForKey:@"included_chat_ids"] count] > 0 ||
        [[definition objectForKey:@"pinned_chat_ids"] count] > 0) {
        return YES;
    }
    NSArray *keys = [NSArray arrayWithObjects:@"include_contacts", @"include_non_contacts", @"include_bots", @"include_groups", @"include_channels", nil];
    NSUInteger index = 0;
    for (index = 0; index < [keys count]; index++) {
        if ([[definition objectForKey:[keys objectAtIndex:index]] boolValue]) {
            return YES;
        }
    }
    return NO;
}

- (void)saveFolder:(id)sender {
    (void)sender;
    NSDictionary *definition = [self definitionFromControls];
    if (![self definitionHasInclusionRule:definition]) {
        [self.statusField setStringValue:TGLoc(@"folders.error.empty")];
        NSBeep();
        return;
    }
    self.loading = YES;
    [self.statusField setStringValue:TGLoc(@"folders.saving")];
    TGTDLibClient *client = [self.client retain];
    NSDictionary *savedDefinition = [definition retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSNumber *folderID = [[client saveChatFolderDefinition:savedDefinition timeout:4.0 error:&error] retain];
        NSError *resultError = [error retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client) {
                self.loading = NO;
                if (folderID) {
                    [self.statusField setStringValue:TGLoc(@"folders.saved")];
                    if ([self.delegate respondsToSelector:@selector(chatFolderManagementWindowControllerDidChangeFolders:)]) {
                        [self.delegate chatFolderManagementWindowControllerDidChangeFolders:self];
                    }
                    [self performSelector:@selector(reloadFolders) withObject:nil afterDelay:0.35];
                } else {
                    [self.statusField setStringValue:(resultError ? [resultError localizedDescription] : TGLoc(@"folders.error.save"))];
                    NSBeep();
                }
            }
            [folderID release];
            [resultError release];
            [savedDefinition release];
            [client release];
        });
        [pool drain];
    });
}

- (void)deleteFolder:(id)sender {
    (void)sender;
    if (!self.editingDefinition) {
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"folders.delete.confirm.title")];
    [alert setInformativeText:TGLoc(@"folders.delete.confirm.text")];
    [alert addButtonWithTitle:TGLoc(@"folders.delete")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    self.loading = YES;
    [self.statusField setStringValue:TGLoc(@"folders.deleting")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *folderID = [[self.editingDefinition objectForKey:@"id"] retain];
    NSString *apiKind = [[self.editingDefinition objectForKey:@"api_kind"] retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL deleted = [client deleteChatFolderWithID:folderID apiKind:apiKind timeout:4.0 error:&error];
        NSError *resultError = [error retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client) {
                self.loading = NO;
                if (deleted) {
                    [self.statusField setStringValue:TGLoc(@"folders.deleted")];
                    if ([self.delegate respondsToSelector:@selector(chatFolderManagementWindowControllerDidChangeFolders:)]) {
                        [self.delegate chatFolderManagementWindowControllerDidChangeFolders:self];
                    }
                    [self performSelector:@selector(reloadFolders) withObject:nil afterDelay:0.35];
                } else {
                    [self.statusField setStringValue:(resultError ? [resultError localizedDescription] : TGLoc(@"folders.error.delete"))];
                    NSBeep();
                }
            }
            [resultError release];
            [folderID release];
            [apiKind release];
            [client release];
        });
        [pool drain];
    });
}

- (void)shareFolder:(id)sender {
    (void)sender;
    if (!self.editingDefinition ||
        ![self.client chatFolderAPIKindSupportsSharing:[self.editingDefinition objectForKey:@"api_kind"]]) {
        NSBeep();
        return;
    }
    self.loading = YES;
    [self.statusField setStringValue:TGLoc(@"folders.sharing")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *folderID = [[self.editingDefinition objectForKey:@"id"] retain];
    NSString *title = [[self.editingDefinition objectForKey:@"title"] retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *link = [[client shareLinkForChatFolderID:folderID title:title timeout:5.0 error:&error] retain];
        NSError *resultError = [error retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client) {
                self.loading = NO;
                if ([link length] > 0) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
                    [pasteboard setString:link forType:NSStringPboardType];
                    [self.statusField setStringValue:TGLoc(@"folders.share.copied")];
                } else {
                    [self.statusField setStringValue:(resultError ? [resultError localizedDescription] : TGLoc(@"folders.error.share"))];
                    NSBeep();
                }
            }
            [link release];
            [resultError release];
            [folderID release];
            [title release];
            [client release];
        });
        [pool drain];
    });
}

@end
