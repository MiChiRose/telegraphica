#import "TGSavedMessagesWindowController.h"

#import "../Core/TGMessageItem.h"
#import "../Core/TGTDLibClient+SavedMessages.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGSavedMessagesWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTableView *topicsTableView;
@property (nonatomic, retain) NSTableView *historyTableView;
@property (nonatomic, retain) NSTableView *tagsTableView;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *pinButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, copy) NSArray *topics;
@property (nonatomic, copy) NSArray *history;
@property (nonatomic, copy) NSArray *tags;
@property (nonatomic, retain) NSNumber *selectedTopicID;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) NSUInteger requestGeneration;
@end

@implementation TGSavedMessagesWindowController

@synthesize client = _client;
@synthesize topicsTableView = _topicsTableView;
@synthesize historyTableView = _historyTableView;
@synthesize tagsTableView = _tagsTableView;
@synthesize refreshButton = _refreshButton;
@synthesize pinButton = _pinButton;
@synthesize spinner = _spinner;
@synthesize statusField = _statusField;
@synthesize topics = _topics;
@synthesize history = _history;
@synthesize tags = _tags;
@synthesize selectedTopicID = _selectedTopicID;
@synthesize loading = _loading;
@synthesize requestGeneration = _requestGeneration;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 860, 580)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.topics = [NSArray array];
        self.history = [NSArray array];
        self.tags = [NSArray array];
        [[self window] setTitle:TGLoc(@"saved.title")];
        [[self window] setMinSize:NSMakeSize(760.0, 520.0)];
        [[self window] setMaxSize:NSMakeSize(1100.0, 780.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_topicsTableView release];
    [_historyTableView release];
    [_tagsTableView release];
    [_refreshButton release];
    [_pinButton release];
    [_spinner release];
    [_statusField release];
    [_topics release];
    [_history release];
    [_tags release];
    [_selectedTopicID release];
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
                                   rowHeight:(CGFloat)rowHeight
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
    [table setRowHeight:rowHeight];
    [table setAllowsEmptySelection:YES];
    [table setDelegate:self];
    [table setDataSource:self];
    [scroll setDocumentView:table];
    [root addSubview:scroll];
    return table;
}

- (NSButton *)textButtonWithFrame:(NSRect)frame
                            title:(NSString *)title
                           action:(SEL)action
                          primary:(BOOL)primary {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    NSButtonCell *cell = primary
        ? (NSButtonCell *)[[[TGPrimaryTextButtonCell alloc] initTextCell:title] autorelease]
        : (NSButtonCell *)[[[TGSecondaryTextButtonCell alloc] initTextCell:title] autorelease];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 536, 680, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"saved.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24, 516, 730, 18)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderTextColor(0.82)];
    [subtitle setStringValue:TGLoc(@"saved.help")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(808, 526, 30, 30)] autorelease];
    [self.refreshButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"↻"] autorelease]];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshPressed:)];
    [self.refreshButton setToolTip:TGLoc(@"refresh")];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *topicsCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 72, 256, 424)] autorelease];
    [topicsCard setAutoresizingMask:NSViewHeightSizable];
    [root addSubview:topicsCard];
    NSTextField *topicsTitle = [self labelWithFrame:NSMakeRect(34, 462, 220, 20)
                                               font:[NSFont boldSystemFontOfSize:13.0]
                                              color:TGClassicCardInkColor()];
    [topicsTitle setStringValue:TGLoc(@"saved.topics")];
    [topicsTitle setAutoresizingMask:NSViewMinYMargin];
    [root addSubview:topicsTitle];
    self.topicsTableView = [self tableInScrollViewWithFrame:NSMakeRect(32, 118, 232, 334)
                                                identifier:@"topics"
                                                 rowHeight:40.0
                                                      root:root];
    [self.topicsTableView setAutoresizingMask:NSViewHeightSizable];
    self.pinButton = [self textButtonWithFrame:NSMakeRect(32, 82, 232, 30)
                                         title:TGLoc(@"saved.pin")
                                        action:@selector(pinPressed:)
                                       primary:NO];
    [root addSubview:self.pinButton];

    TGGroupedCardView *detailCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(288, 72, 552, 424)] autorelease];
    [detailCard setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:detailCard];
    NSTextField *messagesTitle = [self labelWithFrame:NSMakeRect(306, 462, 320, 20)
                                                 font:[NSFont boldSystemFontOfSize:13.0]
                                                color:TGClassicCardInkColor()];
    [messagesTitle setStringValue:TGLoc(@"saved.messages")];
    [messagesTitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:messagesTitle];
    self.historyTableView = [self tableInScrollViewWithFrame:NSMakeRect(304, 230, 520, 222)
                                                 identifier:@"history"
                                                  rowHeight:42.0
                                                       root:root];
    NSTextField *tagsTitle = [self labelWithFrame:NSMakeRect(306, 202, 320, 20)
                                             font:[NSFont boldSystemFontOfSize:13.0]
                                            color:TGClassicCardInkColor()];
    [tagsTitle setStringValue:TGLoc(@"saved.tags")];
    [root addSubview:tagsTitle];
    self.tagsTableView = [self tableInScrollViewWithFrame:NSMakeRect(304, 118, 520, 78)
                                              identifier:@"tags"
                                               rowHeight:28.0
                                                    root:root];
    NSTextField *premiumNote = [self labelWithFrame:NSMakeRect(306, 82, 510, 28)
                                               font:[NSFont systemFontOfSize:10.0]
                                              color:TGClassicCardMutedInkColor()];
    [premiumNote setStringValue:TGLoc(@"saved.premiumNote")];
    [[premiumNote cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [[premiumNote cell] setUsesSingleLineMode:NO];
    [premiumNote setAutoresizingMask:NSViewWidthSizable];
    [root addSubview:premiumNote];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 42, 760, 18)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicHeaderDetailTextColor(0.9)];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(812, 40, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.topicsTableView) {
        return (NSInteger)[self.topics count];
    }
    if (tableView == self.historyTableView) {
        return (NSInteger)[self.history count];
    }
    return (NSInteger)[self.tags count];
}

- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    (void)tableColumn;
    if (row < 0) {
        return @"";
    }
    if (tableView == self.topicsTableView && (NSUInteger)row < [self.topics count]) {
        NSDictionary *topic = [self.topics objectAtIndex:(NSUInteger)row];
        NSString *suffix = [[topic objectForKey:@"is_pinned"] boolValue]
            ? [NSString stringWithFormat:@" · %@", TGLoc(@"saved.pinned")] : @"";
        return [NSString stringWithFormat:@"%@%@\n%@", [topic objectForKey:@"title"], suffix,
                [[topic objectForKey:@"preview"] length] > 0 ? [topic objectForKey:@"preview"] : TGLoc(@"saved.noMessages")];
    }
    if (tableView == self.historyTableView && (NSUInteger)row < [self.history count]) {
        TGMessageItem *item = [self.history objectAtIndex:(NSUInteger)row];
        NSString *sender = [item.senderDisplayName length] > 0 ? item.senderDisplayName : TGLoc(@"saved.message");
        return [NSString stringWithFormat:@"%@\n%@", sender, [item.preview length] > 0 ? item.preview : TGLoc(@"saved.message")];
    }
    if (tableView == self.tagsTableView && (NSUInteger)row < [self.tags count]) {
        NSDictionary *tag = [self.tags objectAtIndex:(NSUInteger)row];
        return [NSString stringWithFormat:@"%@  %@ · %ld",
                [tag objectForKey:@"symbol"], [tag objectForKey:@"label"],
                (long)[[tag objectForKey:@"count"] integerValue]];
    }
    return @"";
}

- (NSDictionary *)selectedTopic {
    NSInteger row = [self.topicsTableView selectedRow];
    return row >= 0 && (NSUInteger)row < [self.topics count]
        ? [self.topics objectAtIndex:(NSUInteger)row] : nil;
}

- (void)updateControls {
    NSDictionary *topic = [self selectedTopic];
    BOOL hasTopic = topic != nil;
    [self.refreshButton setEnabled:!self.loading];
    [self.pinButton setEnabled:(hasTopic && !self.loading)];
    [self.pinButton setTitle:[[topic objectForKey:@"is_pinned"] boolValue]
        ? TGLoc(@"saved.unpin") : TGLoc(@"saved.pin")];
}

- (void)setLoading:(BOOL)loading status:(NSString *)status {
    self.loading = loading;
    [self.statusField setStringValue:status ?: @""];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
    [self updateControls];
}

- (void)reloadSavedMessages {
    if (self.loading) {
        return;
    }
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"saved.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *previousTopicID = [self.selectedTopicID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSArray *topics = [[client savedMessagesTopicSummariesWithLimit:100 timeout:14.0 error:&error] retain];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.topics = topics ?: [NSArray array];
                [self.topicsTableView reloadData];
                NSInteger selection = -1;
                NSUInteger index = 0;
                for (index = 0; index < [self.topics count]; index++) {
                    if (previousTopicID && [[[self.topics objectAtIndex:index] objectForKey:@"topic_id"] isEqual:previousTopicID]) {
                        selection = (NSInteger)index;
                        break;
                    }
                }
                if (selection < 0 && [self.topics count] > 0) {
                    selection = 0;
                }
                [self setLoading:NO status:detail ?: [NSString stringWithFormat:TGLoc(@"saved.loaded"), (unsigned long)[self.topics count]]];
                if (selection >= 0) {
                    [self.topicsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selection]
                                     byExtendingSelection:NO];
                    [self loadSelectedTopic];
                }
            }
            [detail release];
            [topics release];
            [previousTopicID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)loadSelectedTopic {
    NSDictionary *topic = [self selectedTopic];
    NSNumber *topicID = [[topic objectForKey:@"topic_id"] retain];
    if (!topicID || self.loading) {
        [topicID release];
        [self updateControls];
        return;
    }
    self.selectedTopicID = topicID;
    self.requestGeneration++;
    NSUInteger generation = self.requestGeneration;
    [self setLoading:YES status:TGLoc(@"saved.loadingTopic")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *historyError = nil;
        NSArray *history = [[client savedMessagesHistoryForTopicID:topicID limit:60 timeout:12.0 error:&historyError] retain];
        NSError *tagsError = nil;
        NSArray *tags = [[client savedMessagesTagSummariesForTopicID:topicID timeout:8.0 error:&tagsError] retain];
        NSString *detail = [[historyError localizedDescription] copy];
        if (!detail) {
            detail = [[tagsError localizedDescription] copy];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.requestGeneration) {
                self.history = history ?: [NSArray array];
                self.tags = tags ?: [NSArray array];
                [self.historyTableView reloadData];
                [self.tagsTableView reloadData];
                [self setLoading:NO status:detail ?: [NSString stringWithFormat:TGLoc(@"saved.topicLoaded"),
                                                       (unsigned long)[self.history count],
                                                       (unsigned long)[self.tags count]]];
            }
            [detail release];
            [history release];
            [tags release];
            [topicID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] == self.topicsTableView) {
        [self loadSelectedTopic];
    }
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadSavedMessages];
}

- (void)pinPressed:(id)sender {
    (void)sender;
    NSDictionary *topic = [self selectedTopic];
    NSNumber *topicID = [[topic objectForKey:@"topic_id"] retain];
    BOOL shouldPin = ![[topic objectForKey:@"is_pinned"] boolValue];
    if (!topicID || self.loading) {
        [topicID release];
        return;
    }
    [self setLoading:YES status:TGLoc(@"saved.saving")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL success = [client setSavedMessagesTopicID:topicID pinned:shouldPin timeout:10.0 error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:success ? TGLoc(@"saved.saved") : (detail ?: TGLoc(@"saved.failed"))];
            [detail release];
            [topicID release];
            [client release];
            if (success) {
                [self reloadSavedMessages];
            }
        });
        [pool drain];
    });
}

@end
