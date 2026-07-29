#import "TGCallsPlaceholderView.h"

#import "../Calls/TGCallCoordinator.h"
#import "../Calls/TGCallAudioEngine.h"
#import "../Core/TGTDLibClient.h"
#import "../Core/TGTDLibClient+Calls.h"
#import "TGIconAssets.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

@interface TGCallHistoryCell : NSTextFieldCell
@property (nonatomic, retain) NSDictionary *callSummary;
@end

@interface TGCallHistoryTableView : NSTableView
@end

@implementation TGCallHistoryTableView

- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:localPoint];
    if (row < 0) {
        return nil;
    }
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
      byExtendingSelection:NO];
    return [super menuForEvent:event];
}

@end

@implementation TGCallHistoryCell

@synthesize callSummary = _callSummary;

- (id)copyWithZone:(NSZone *)zone {
    TGCallHistoryCell *cell = [super copyWithZone:zone];
    /*
     * NSCell's legacy copy path bit-copies subclass ivars.  Using the
     * synthesized setter here would release that unowned copied pointer
     * before retaining it, leaving multiple cells sharing one ownership.
     */
    cell->_callSummary = [_callSummary retain];
    return cell;
}

- (void)setObjectValue:(id)value {
    self.callSummary = [value isKindOfClass:[NSDictionary class]] ? value : nil;
    [super setObjectValue:@""];
}

- (NSString *)detailText {
    BOOL outgoing = [[self.callSummary objectForKey:@"is_outgoing"] boolValue];
    NSUInteger duration = [[self.callSummary objectForKey:@"duration"] unsignedIntegerValue];
    NSString *discardReason = [self.callSummary objectForKey:@"discard_reason"];
    if ([discardReason isEqualToString:@"callDiscardReasonMissed"] ||
        [discardReason isEqualToString:@"callDiscardReasonDeclined"]) {
        return outgoing ? TGLoc(@"calls.cancelled") : TGLoc(@"calls.missed");
    }
    NSString *direction = outgoing ? TGLoc(@"calls.outgoing") : TGLoc(@"calls.incoming");
    if (duration == 0U) {
        return direction;
    }
    return [NSString stringWithFormat:@"%@ · %lu:%02lu",
            direction,
            (unsigned long)(duration / 60U),
            (unsigned long)(duration % 60U)];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect cardRect = NSInsetRect(cellFrame, 3.0, 3.0);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:10.0 yRadius:10.0];
    TGThemeDrawGroupedCardInPath(cardPath, cardRect, [controlView isFlipped]);
    [TGClassicTableGridColor() set];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];

    NSRect avatarRect = NSMakeRect(NSMinX(cardRect) + 10.0, NSMinY(cardRect) + 8.0, 40.0, 40.0);
    NSString *avatarPath = [self.callSummary objectForKey:@"avatar_local_path"];
    NSImage *avatar = [avatarPath length] > 0
        ? [[[NSImage alloc] initWithContentsOfFile:avatarPath] autorelease] : nil;
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithOvalInRect:avatarRect] addClip];
    if (avatar) {
        [avatar drawInRect:avatarRect
                  fromRect:NSZeroRect
                 operation:NSCompositeSourceOver
                  fraction:1.0
            respectFlipped:[controlView isFlipped]
                     hints:nil];
    } else {
        [TGClassicNavigationNormalColor(1.0) set];
        NSRectFill(avatarRect);
        TGDrawTemplateIconAsset(@"user", NSInsetRect(avatarRect, 9.0, 9.0),
                                TGClassicCardMutedInkColor(), 0.9, [controlView isFlipped]);
    }
    [NSGraphicsContext restoreGraphicsState];

    NSString *title = [self.callSummary objectForKey:@"display_name"];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.5], NSFontAttributeName,
                                     TGClassicCardInkColor(), NSForegroundColorAttributeName,
                                     nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:10.5], NSFontAttributeName,
                                      TGClassicCardMutedInkColor(), NSForegroundColorAttributeName,
                                      nil];
    CGFloat textX = NSMaxX(avatarRect) + 10.0;
    CGFloat textWidth = MAX(60.0, NSMaxX(cardRect) - textX - 92.0);
    [title drawInRect:NSMakeRect(textX, NSMinY(cardRect) + 27.0, textWidth, 18.0)
       withAttributes:titleAttributes];
    BOOL outgoing = [[self.callSummary objectForKey:@"is_outgoing"] boolValue];
    NSString *discardReason = [self.callSummary objectForKey:@"discard_reason"];
    BOOL missed = ([discardReason isEqualToString:@"callDiscardReasonMissed"] ||
                   [discardReason isEqualToString:@"callDiscardReasonDeclined"]);
    NSString *directionIcon = missed ? @"call-miss" : (outgoing ? @"call-out" : @"call-in");
    NSColor *directionColor = missed
        ? [NSColor colorWithCalibratedRed:0.84 green:0.18 blue:0.18 alpha:1.0]
        : TGClassicCardMutedInkColor();
    TGDrawTemplateIconAsset(directionIcon,
                            NSMakeRect(textX, NSMinY(cardRect) + 11.0, 13.0, 13.0),
                            directionColor,
                            1.0,
                            [controlView isFlipped]);
    [[self detailText] drawInRect:NSMakeRect(textX + 18.0, NSMinY(cardRect) + 10.0, textWidth - 18.0, 16.0)
                    withAttributes:detailAttributes];

    NSNumber *dateValue = [self.callSummary objectForKey:@"date"];
    if ([dateValue respondsToSelector:@selector(doubleValue)] && [dateValue doubleValue] > 0.0) {
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        NSString *dateText = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[dateValue doubleValue]]];
        NSSize size = [dateText sizeWithAttributes:detailAttributes];
        [dateText drawInRect:NSMakeRect(NSMaxX(cardRect) - size.width - 10.0,
                                        NSMinY(cardRect) + 20.0,
                                        size.width,
                                        16.0)
              withAttributes:detailAttributes];
    }
}

- (void)dealloc {
    [_callSummary release];
    [super dealloc];
}

@end

@interface TGCallsPlaceholderView ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) TGCallCoordinator *coordinator;
@property (nonatomic, retain) NSArray *contacts;
@property (nonatomic, retain) NSArray *recentCalls;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL deletingCall;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) TGGroupedCardView *cardView;
@property (nonatomic, retain) NSPopUpButton *contactPopUpButton;
@property (nonatomic, retain) NSButton *startCallButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSButton *mockOutgoingButton;
@property (nonatomic, retain) NSButton *mockIncomingButton;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSScrollView *historyScrollView;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSTextField *unavailableTitleField;
@property (nonatomic, retain) NSTextField *unavailableDetailField;
@end

@implementation TGCallsPlaceholderView

@synthesize client = _client;
@synthesize coordinator = _coordinator;
@synthesize contacts = _contacts;
@synthesize recentCalls = _recentCalls;
@synthesize loading = _loading;
@synthesize deletingCall = _deletingCall;
@synthesize titleField = _titleField;
@synthesize cardView = _cardView;
@synthesize contactPopUpButton = _contactPopUpButton;
@synthesize startCallButton = _startCallButton;
@synthesize refreshButton = _refreshButton;
@synthesize mockOutgoingButton = _mockOutgoingButton;
@synthesize mockIncomingButton = _mockIncomingButton;
@synthesize statusField = _statusField;
@synthesize tableView = _tableView;
@synthesize historyScrollView = _historyScrollView;
@synthesize spinner = _spinner;
@synthesize unavailableTitleField = _unavailableTitleField;
@synthesize unavailableDetailField = _unavailableDetailField;

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:TGClassicCardInkColor()];
    [field setStringValue:text ? text : @""];
    return field;
}

- (NSButton *)textButtonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action primary:(BOOL)primary {
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

- (id)initWithFrame:(NSRect)frame client:(TGTDLibClient *)client coordinator:(TGCallCoordinator *)coordinator {
    self = [super initWithFrame:frame];
    if (self) {
        self.client = client;
        self.coordinator = coordinator;
        self.contacts = [NSArray array];
        self.recentCalls = [NSArray array];
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        self.titleField = [self labelWithFrame:NSMakeRect(58.0, NSHeight(frame) - 32.0, MAX(120.0, NSWidth(frame) - 116.0), 20.0)
                                         text:@""
                                         font:[NSFont boldSystemFontOfSize:15.0]];
        [self.titleField setAlignment:NSCenterTextAlignment];
        [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [self addSubview:self.titleField];

        self.cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(14.0, 14.0, NSWidth(frame) - 28.0, NSHeight(frame) - 68.0)] autorelease];
        [self.cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self addSubview:self.cardView];

        self.unavailableTitleField = [self labelWithFrame:NSMakeRect(80.0,
                                                                     NSHeight(frame) / 2.0 + 18.0,
                                                                     MAX(220.0, NSWidth(frame) - 160.0),
                                                                     28.0)
                                                     text:@""
                                                     font:[NSFont boldSystemFontOfSize:18.0]];
        [self.unavailableTitleField setAlignment:NSCenterTextAlignment];
        [self.unavailableTitleField setAutoresizingMask:
            (NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.unavailableTitleField];
        self.unavailableDetailField = [self labelWithFrame:NSMakeRect(80.0,
                                                                      NSHeight(frame) / 2.0 - 50.0,
                                                                      MAX(220.0, NSWidth(frame) - 160.0),
                                                                      64.0)
                                                      text:@""
                                                      font:[NSFont systemFontOfSize:12.0]];
        [self.unavailableDetailField setAlignment:NSCenterTextAlignment];
        [[self.unavailableDetailField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [[self.unavailableDetailField cell] setUsesSingleLineMode:NO];
        [[self.unavailableDetailField cell] setWraps:YES];
        [self.unavailableDetailField setAutoresizingMask:
            (NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.unavailableDetailField];

        NSTextField *newCallLabel = [self labelWithFrame:NSMakeRect(30.0, NSHeight(frame) - 63.0, 180.0, 20.0)
                                                    text:@""
                                                    font:[NSFont boldSystemFontOfSize:12.0]];
        [newCallLabel setTag:601];
        [newCallLabel setAutoresizingMask:NSViewMinYMargin];
        [self addSubview:newCallLabel];

        self.contactPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(30.0, NSHeight(frame) - 98.0, MAX(220.0, NSWidth(frame) - 292.0), 28.0)
                                                             pullsDown:NO] autorelease];
        [self.contactPopUpButton setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [self addSubview:self.contactPopUpButton];

        self.startCallButton = [self textButtonWithFrame:NSMakeRect(NSWidth(frame) - 248.0, NSHeight(frame) - 98.0, 128.0, 28.0)
                                                   title:@""
                                                  action:@selector(startCallPressed:)
                                                 primary:YES];
        [self.startCallButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
        [self addSubview:self.startCallButton];

        self.refreshButton = [self textButtonWithFrame:NSMakeRect(NSWidth(frame) - 112.0, NSHeight(frame) - 98.0, 82.0, 28.0)
                                                 title:@""
                                                action:@selector(refreshPressed:)
                                               primary:NO];
        [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
        [self addSubview:self.refreshButton];

        NSTextField *recentLabel = [self labelWithFrame:NSMakeRect(30.0, NSHeight(frame) - 130.0, 220.0, 20.0)
                                                   text:@""
                                                   font:[NSFont boldSystemFontOfSize:12.0]];
        [recentLabel setTag:602];
        [recentLabel setAutoresizingMask:NSViewMinYMargin];
        [self addSubview:recentLabel];

        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30.0, 86.0, NSWidth(frame) - 60.0, NSHeight(frame) - 222.0)] autorelease];
        [scrollView setBorderType:NSNoBorder];
        [scrollView setDrawsBackground:NO];
        [scrollView setHasVerticalScroller:YES];
        [scrollView setAutohidesScrollers:YES];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        self.historyScrollView = scrollView;
        self.tableView = [[[TGCallHistoryTableView alloc] initWithFrame:[scrollView bounds]] autorelease];
        NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"call"] autorelease];
        [column setWidth:NSWidth([scrollView bounds])];
        [column setDataCell:[[[TGCallHistoryCell alloc] initTextCell:@""] autorelease]];
        [self.tableView addTableColumn:column];
        [self.tableView setHeaderView:nil];
        [self.tableView setRowHeight:62.0];
        [self.tableView setIntercellSpacing:NSMakeSize(0.0, 0.0)];
        [self.tableView setBackgroundColor:[NSColor clearColor]];
        [self.tableView setDelegate:self];
        [self.tableView setDataSource:self];
        NSMenu *historyMenu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
        NSMenuItem *deleteItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"delete")
                                                             action:@selector(deleteRecentCallPressed:)
                                                      keyEquivalent:@""] autorelease];
        [deleteItem setTarget:self];
        [deleteItem setTag:603];
        [historyMenu addItem:deleteItem];
        [self.tableView setMenu:historyMenu];
        [scrollView setDocumentView:self.tableView];
        [self addSubview:scrollView];

        self.mockOutgoingButton = [self textButtonWithFrame:NSMakeRect(30.0, 40.0, 158.0, 30.0)
                                                       title:@""
                                                      action:@selector(mockOutgoingPressed:)
                                                     primary:NO];
        [self.mockOutgoingButton setAutoresizingMask:NSViewMaxXMargin];
        [self addSubview:self.mockOutgoingButton];
        self.mockIncomingButton = [self textButtonWithFrame:NSMakeRect(196.0, 40.0, 158.0, 30.0)
                                                       title:@""
                                                      action:@selector(mockIncomingPressed:)
                                                     primary:NO];
        [self.mockIncomingButton setAutoresizingMask:NSViewMaxXMargin];
        [self addSubview:self.mockIncomingButton];

        self.statusField = [self labelWithFrame:NSMakeRect(370.0, 45.0, MAX(180.0, NSWidth(frame) - 400.0), 18.0)
                                           text:@""
                                           font:[NSFont systemFontOfSize:10.5]];
        [self.statusField setTextColor:TGClassicCardMutedInkColor()];
        [self.statusField setAlignment:NSRightTextAlignment];
        [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxXMargin)];
        [self addSubview:self.statusField];
        self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(NSWidth(frame) - 34.0, 45.0, 16.0, 16.0)] autorelease];
        [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
        [self.spinner setDisplayedWhenStopped:NO];
        [self.spinner setAutoresizingMask:NSViewMinXMargin];
        [self addSubview:self.spinner];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callFinished:)
                                                     name:TGCallCoordinatorDidFinishCallNotification
                                                   object:coordinator];
        [self refreshLocalizedText];
        [self refreshThemeAppearance];
        [self applyTransportAvailability];
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.recentCalls count];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    (void)oldSize;
    NSRect bounds = [self bounds];
    [self.titleField setFrame:NSMakeRect(58.0,
                                         NSHeight(bounds) - 32.0,
                                         MAX(120.0, NSWidth(bounds) - 116.0),
                                         20.0)];
    [self.cardView setFrame:NSMakeRect(14.0,
                                       14.0,
                                       MAX(280.0, NSWidth(bounds) - 28.0),
                                       MAX(150.0, NSHeight(bounds) - 68.0))];
    NSTextField *newCallLabel = (NSTextField *)[self viewWithTag:601];
    NSTextField *recentLabel = (NSTextField *)[self viewWithTag:602];
    [newCallLabel setFrame:NSMakeRect(30.0, NSHeight(bounds) - 63.0, 180.0, 20.0)];
    [self.contactPopUpButton setFrame:NSMakeRect(30.0,
                                                 NSHeight(bounds) - 98.0,
                                                 MAX(220.0, NSWidth(bounds) - 292.0),
                                                 28.0)];
    [self.startCallButton setFrame:NSMakeRect(NSWidth(bounds) - 248.0,
                                              NSHeight(bounds) - 98.0,
                                              128.0,
                                              28.0)];
    [self.refreshButton setFrame:NSMakeRect(NSWidth(bounds) - 112.0,
                                            NSHeight(bounds) - 98.0,
                                            82.0,
                                            28.0)];
    [recentLabel setFrame:NSMakeRect(30.0, NSHeight(bounds) - 130.0, 220.0, 20.0)];
    [self.historyScrollView setFrame:NSMakeRect(30.0,
                                                86.0,
                                                MAX(220.0, NSWidth(bounds) - 60.0),
                                                MAX(80.0, NSHeight(bounds) - 222.0))];
    [self.unavailableTitleField setFrame:NSMakeRect(80.0,
                                                     NSHeight(bounds) / 2.0 + 18.0,
                                                     MAX(220.0, NSWidth(bounds) - 160.0),
                                                     28.0)];
    [self.unavailableDetailField setFrame:NSMakeRect(80.0,
                                                      NSHeight(bounds) / 2.0 - 50.0,
                                                      MAX(220.0, NSWidth(bounds) - 160.0),
                                                      64.0)];
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row {
    (void)tableView;
    (void)tableColumn;
    return (row >= 0 && (NSUInteger)row < [self.recentCalls count])
        ? [self.recentCalls objectAtIndex:(NSUInteger)row] : nil;
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self refreshData];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ([menuItem action] == @selector(deleteRecentCallPressed:)) {
        NSInteger row = [self.tableView selectedRow];
        if (self.loading || self.deletingCall ||
            row < 0 || (NSUInteger)row >= [self.recentCalls count]) {
            return NO;
        }
        NSDictionary *summary = [self.recentCalls objectAtIndex:(NSUInteger)row];
        return ([[summary objectForKey:@"chat_id"] longLongValue] != 0LL &&
                [[summary objectForKey:@"message_id"] longLongValue] > 0LL);
    }
    return YES;
}

- (void)deleteRecentCallPressed:(id)sender {
    (void)sender;
    NSInteger row = [self.tableView selectedRow];
    if (self.loading || self.deletingCall ||
        row < 0 || (NSUInteger)row >= [self.recentCalls count]) {
        return;
    }
    NSDictionary *summary = [self.recentCalls objectAtIndex:(NSUInteger)row];
    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    NSNumber *messageID = [summary objectForKey:@"message_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        [chatID longLongValue] == 0LL ||
        ![messageID respondsToSelector:@selector(longLongValue)] ||
        [messageID longLongValue] <= 0LL) {
        return;
    }

    self.deletingCall = YES;
    [self.tableView setEnabled:NO];
    [self.refreshButton setEnabled:NO];
    [self.spinner startAnimation:nil];
    [self.statusField setStringValue:TGLoc(@"calls.deleting")];

    TGTDLibClient *client = [self.client retain];
    NSNumber *retainedChatID = [chatID retain];
    NSNumber *retainedMessageID = [messageID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *deleteError = nil;
        NSString *result = [client deleteMessagesInChatID:retainedChatID
                                               messageIDs:[NSArray arrayWithObject:retainedMessageID]
                                                  revoke:NO
                                                 timeout:8.0
                                                   error:&deleteError];
        BOOL deleted = ([result length] > 0);
        NSString *failure = [[deleteError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (deleted) {
                NSMutableArray *remaining = [NSMutableArray array];
                for (NSDictionary *call in self.recentCalls) {
                    BOOL sameChat = [[call objectForKey:@"chat_id"]
                        isEqualToNumber:retainedChatID];
                    BOOL sameMessage = [[call objectForKey:@"message_id"]
                        isEqualToNumber:retainedMessageID];
                    if (!sameChat || !sameMessage) {
                        [remaining addObject:call];
                    }
                }
                self.recentCalls = remaining;
                [self.tableView reloadData];
                [self.statusField setStringValue:
                    [NSString stringWithFormat:TGLoc(@"calls.loaded"),
                                               (unsigned long)[self.recentCalls count]]];
            } else {
                [self.statusField setStringValue:
                    [failure length] > 0 ? failure : TGLoc(@"calls.deleteFailed")];
            }
            self.deletingCall = NO;
            [self.tableView setEnabled:YES];
            [self.refreshButton setEnabled:YES];
            [self.spinner stopAnimation:nil];
            [failure release];
            [retainedMessageID release];
            [retainedChatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)refreshData {
    if (!self.coordinator.transportAvailable) {
        self.contacts = [NSArray array];
        self.recentCalls = [NSArray array];
        [self.contactPopUpButton removeAllItems];
        [self.tableView reloadData];
        [self applyTransportAvailability];
        return;
    }
    if (self.loading || self.deletingCall) {
        return;
    }
    self.loading = YES;
    [self.spinner startAnimation:nil];
    [self.refreshButton setEnabled:NO];
    [self.statusField setStringValue:TGLoc(@"calls.loading")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *contactError = nil;
        NSArray *contacts = [[client contactSummariesWithTimeout:10.0 error:&contactError] copy];
        NSError *callError = nil;
        NSArray *calls = [[client recentAudioCallSummariesWithLimit:40 timeout:10.0 error:&callError] copy];
        NSError *failureError = callError ? callError : contactError;
        NSString *failure = [[failureError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.contacts = contacts ? contacts : [NSArray array];
            self.recentCalls = calls ? calls : [NSArray array];
            [self.contactPopUpButton removeAllItems];
            NSUInteger index = 0;
            for (index = 0; index < [self.contacts count]; index++) {
                NSDictionary *contact = [self.contacts objectAtIndex:index];
                [self.contactPopUpButton addItemWithTitle:[contact objectForKey:@"display_name"]];
                [[self.contactPopUpButton lastItem] setRepresentedObject:contact];
            }
            [self.tableView reloadData];
            self.loading = NO;
            [self.spinner stopAnimation:nil];
            [self.refreshButton setEnabled:YES];
            [self.startCallButton setEnabled:([self.contacts count] > 0 && self.coordinator.transportAvailable)];
            NSString *status = failure;
            if ([status length] == 0) {
                status = self.coordinator.transportAvailable
                    ? [NSString stringWithFormat:TGLoc(@"calls.loaded"), (unsigned long)[self.recentCalls count]]
                    : TGLoc(@"calls.transportUnavailable");
            }
            [self.statusField setStringValue:status];
            [failure release];
            [calls release];
            [contacts release];
            [client release];
        });
        [pool drain];
    });
}

- (void)applyTransportAvailability {
    BOOL available = self.coordinator.transportAvailable;
    NSArray *callControls = [NSArray arrayWithObjects:
                             [self viewWithTag:601],
                             self.contactPopUpButton,
                             self.startCallButton,
                             self.refreshButton,
                             [self viewWithTag:602],
                             self.historyScrollView,
                             self.mockOutgoingButton,
                             self.mockIncomingButton,
                             self.statusField,
                             self.spinner,
                             nil];
    for (NSView *view in callControls) {
        [view setHidden:!available];
    }
    [self.unavailableTitleField setHidden:available];
    [self.unavailableDetailField setHidden:available];
    if (!available) {
        [self.unavailableTitleField setStringValue:TGLoc(@"calls.unavailable.title")];
        [self.unavailableDetailField setStringValue:
            [TGCallAudioEngine isOperatingSystemSupported]
                ? TGLoc(@"calls.transportUnavailable")
                : TGLoc(@"calls.osUnsupported")];
    }
}

- (void)startCallPressed:(id)sender {
    (void)sender;
    NSDictionary *profile = [[self.contactPopUpButton selectedItem] representedObject];
    if (profile) {
        [self.coordinator startAudioCallToProfile:profile];
    }
}

- (void)mockOutgoingPressed:(id)sender {
    (void)sender;
    [self.coordinator startMockOutgoingCall];
}

- (void)mockIncomingPressed:(id)sender {
    (void)sender;
    [self.coordinator startMockIncomingCall];
}

- (void)callFinished:(NSNotification *)notification {
    (void)notification;
    [self refreshData];
}

- (void)refreshLocalizedText {
    [self.titleField setStringValue:TGLoc(@"calls.recent")];
    NSTextField *newLabel = (NSTextField *)[self viewWithTag:601];
    NSTextField *recentLabel = (NSTextField *)[self viewWithTag:602];
    [newLabel setStringValue:TGLoc(@"calls.new")];
    [recentLabel setStringValue:TGLoc(@"calls.recent")];
    [self.startCallButton setTitle:TGLoc(@"calls.start")];
    [self.refreshButton setTitle:TGLoc(@"refresh")];
    [self.mockOutgoingButton setTitle:TGLoc(@"calls.demo.outgoing")];
    [self.mockIncomingButton setTitle:TGLoc(@"calls.demo.incoming")];
    NSMenuItem *deleteItem = [[self.tableView menu] itemWithTag:603];
    [deleteItem setTitle:TGLoc(@"delete")];
    [self applyTransportAvailability];
}

- (void)refreshThemeAppearance {
    [self.titleField setTextColor:TGClassicNavigationTextColor(1.0)];
    [(NSTextField *)[self viewWithTag:601] setTextColor:TGClassicCardInkColor()];
    [(NSTextField *)[self viewWithTag:602] setTextColor:TGClassicCardInkColor()];
    [self.statusField setTextColor:TGClassicCardMutedInkColor()];
    [self.unavailableTitleField setTextColor:TGClassicCardInkColor()];
    [self.unavailableDetailField setTextColor:TGClassicCardMutedInkColor()];
    [self.cardView setNeedsDisplay:YES];
    [self.tableView setNeedsDisplay:YES];
    [self setNeedsDisplay:YES];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_client release];
    [_coordinator release];
    [_contacts release];
    [_recentCalls release];
    [_titleField release];
    [_cardView release];
    [_contactPopUpButton release];
    [_startCallButton release];
    [_refreshButton release];
    [_mockOutgoingButton release];
    [_mockIncomingButton release];
    [_statusField release];
    [_tableView release];
    [_historyScrollView release];
    [_spinner release];
    [_unavailableTitleField release];
    [_unavailableDetailField release];
    [super dealloc];
}

@end
