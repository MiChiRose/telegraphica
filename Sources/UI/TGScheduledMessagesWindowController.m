#import "TGScheduledMessagesWindowController.h"

#import "../Core/TGTDLibClient+ScheduledMessages.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

@interface TGScheduledMessagesWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, retain) NSButton *sendNowButton;
@property (nonatomic, retain) NSButton *rescheduleButton;
@property (nonatomic, retain) NSButton *whenOnlineButton;
@property (nonatomic, retain) NSButton *deleteButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, copy) NSArray *messages;
@property (nonatomic, assign) BOOL loading;
@end

@implementation TGScheduledMessagesWindowController

@synthesize client = _client;
@synthesize chatID = _chatID;
@synthesize chatTitle = _chatTitle;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize sendNowButton = _sendNowButton;
@synthesize rescheduleButton = _rescheduleButton;
@synthesize whenOnlineButton = _whenOnlineButton;
@synthesize deleteButton = _deleteButton;
@synthesize refreshButton = _refreshButton;
@synthesize messages = _messages;
@synthesize loading = _loading;

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
               title:(NSString *)title {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 660, 500)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.chatID = chatID;
        self.chatTitle = title;
        self.messages = [NSArray array];
        [[self window] setTitle:TGLoc(@"scheduled.title")];
        [[self window] setMinSize:NSMakeSize(600.0, 440.0)];
        [[self window] setMaxSize:NSMakeSize(900.0, 720.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_chatID release];
    [_chatTitle release];
    [_tableView release];
    [_statusField release];
    [_spinner release];
    [_sendNowButton release];
    [_rescheduleButton release];
    [_whenOnlineButton release];
    [_deleteButton release];
    [_refreshButton release];
    [_messages release];
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

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action primary:(BOOL)primary {
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

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 452, 470, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"scheduled.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    NSTextField *subtitle = [self labelWithFrame:NSMakeRect(24, 432, 510, 18)
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicHeaderTextColor(0.82)];
    [subtitle setStringValue:[self.chatTitle length] > 0 ? self.chatTitle : TGLoc(@"chats")];
    [subtitle setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:subtitle];

    self.refreshButton = [self buttonWithFrame:NSMakeRect(548, 438, 88, 30)
                                         title:TGLoc(@"refresh")
                                        action:@selector(refreshPressed:)
                                       primary:NO];
    [self.refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:self.refreshButton];

    TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(20, 62, 620, 350)] autorelease];
    [card setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:card];
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(32, 122, 596, 278)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setBorderType:NSNoBorder];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"scheduled"] autorelease];
    [column setWidth:584.0];
    [column setResizingMask:NSTableColumnAutoresizingMask];
    [self.tableView addTableColumn:column];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:44.0];
    [self.tableView setAllowsEmptySelection:YES];
    [self.tableView setDelegate:self];
    [self.tableView setDataSource:self];
    [scroll setDocumentView:self.tableView];
    [root addSubview:scroll];

    self.sendNowButton = [self buttonWithFrame:NSMakeRect(32, 78, 112, 30)
                                         title:TGLoc(@"scheduled.sendNow")
                                        action:@selector(sendNowPressed:)
                                       primary:YES];
    self.rescheduleButton = [self buttonWithFrame:NSMakeRect(152, 78, 126, 30)
                                            title:TGLoc(@"scheduled.reschedule")
                                           action:@selector(reschedulePressed:)
                                          primary:NO];
    self.whenOnlineButton = [self buttonWithFrame:NSMakeRect(286, 78, 136, 30)
                                            title:TGLoc(@"scheduled.whenOnline")
                                           action:@selector(whenOnlinePressed:)
                                          primary:NO];
    self.deleteButton = [self buttonWithFrame:NSMakeRect(510, 78, 118, 30)
                                        title:TGLoc(@"delete")
                                       action:@selector(deletePressed:)
                                      primary:NO];
    [self.deleteButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.sendNowButton];
    [root addSubview:self.rescheduleButton];
    [root addSubview:self.whenOnlineButton];
    [root addSubview:self.deleteButton];

    self.statusField = [self labelWithFrame:NSMakeRect(32, 42, 574, 16)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicCardMutedInkColor()];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(612, 40, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.messages count];
}

- (NSString *)scheduleTextForMessage:(NSDictionary *)message {
    if ([[message objectForKey:@"send_when_online"] boolValue]) {
        return TGLoc(@"scheduled.whenOnline");
    }
    NSNumber *date = [message objectForKey:@"send_date"];
    if (![date respondsToSelector:@selector(integerValue)] || [date integerValue] <= 0) {
        return TGLoc(@"scheduled.unknownTime");
    }
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:[date integerValue]]];
}

- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
                           row:(NSInteger)row {
    (void)tableView;
    (void)tableColumn;
    if (row < 0 || (NSUInteger)row >= [self.messages count]) {
        return @"";
    }
    NSDictionary *message = [self.messages objectAtIndex:(NSUInteger)row];
    return [NSString stringWithFormat:@"%@\n%@", [message objectForKey:@"preview"], [self scheduleTextForMessage:message]];
}

- (NSDictionary *)selectedMessage {
    NSInteger row = [self.tableView selectedRow];
    return (row >= 0 && (NSUInteger)row < [self.messages count])
        ? [self.messages objectAtIndex:(NSUInteger)row]
        : nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (void)updateControls {
    BOOL selected = ([self selectedMessage] != nil && !self.loading);
    [self.refreshButton setEnabled:!self.loading];
    [self.sendNowButton setEnabled:selected];
    [self.rescheduleButton setEnabled:selected];
    [self.whenOnlineButton setEnabled:selected];
    [self.deleteButton setEnabled:selected];
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

- (void)reloadMessages {
    if (self.loading) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"scheduled.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSArray *messages = [[client scheduledMessageSummariesForChatID:chatID timeout:8.0 error:&error] retain];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.messages = messages ? messages : [NSArray array];
            [self.tableView reloadData];
            [self.tableView deselectAll:nil];
            NSString *status = detail ? detail : ([self.messages count] > 0
                ? [NSString stringWithFormat:TGLoc(@"scheduled.count"), (unsigned long)[self.messages count]]
                : TGLoc(@"scheduled.empty"));
            [self setLoading:NO status:status];
            [messages release];
            [detail release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self reloadMessages];
}

- (void)runScheduleMutationWithDate:(NSNumber *)date whenOnline:(BOOL)whenOnline {
    NSDictionary *message = [self selectedMessage];
    NSNumber *messageID = [message objectForKey:@"message_id"];
    if (!messageID || self.loading) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"scheduled.saving")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *safeMessageID = [messageID retain];
    NSNumber *safeDate = [date retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL ok = [client setScheduledMessageInChatID:chatID
                                           messageID:safeMessageID
                                            sendDate:safeDate
                                      sendWhenOnline:whenOnline
                                             timeout:8.0
                                               error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:ok ? TGLoc(@"scheduled.saved") : (detail ? detail : TGLoc(@"scheduled.failed"))];
            if (ok) {
                [self reloadMessages];
            }
            [detail release];
            [safeDate release];
            [safeMessageID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)sendNowPressed:(id)sender {
    (void)sender;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"scheduled.sendNowConfirm")];
    [alert addButtonWithTitle:TGLoc(@"scheduled.sendNow")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self runScheduleMutationWithDate:nil whenOnline:NO];
    }
}

- (void)whenOnlinePressed:(id)sender {
    (void)sender;
    [self runScheduleMutationWithDate:nil whenOnline:YES];
}

- (void)reschedulePressed:(id)sender {
    (void)sender;
    NSDatePicker *picker = [[[NSDatePicker alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)] autorelease];
    [picker setDatePickerStyle:NSClockAndCalendarDatePickerStyle];
    [picker setDatePickerElements:(NSYearMonthDayDatePickerElementFlag | NSHourMinuteDatePickerElementFlag)];
    [picker setMinDate:[NSDate dateWithTimeIntervalSinceNow:60.0]];
    [picker setDateValue:[NSDate dateWithTimeIntervalSinceNow:60.0 * 60.0]];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"scheduled.reschedule")];
    [alert setAccessoryView:picker];
    [alert addButtonWithTitle:TGLoc(@"apply")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [self runScheduleMutationWithDate:[NSNumber numberWithInteger:(NSInteger)[[picker dateValue] timeIntervalSince1970]]
                              whenOnline:NO];
    }
}

- (void)deletePressed:(id)sender {
    (void)sender;
    NSDictionary *message = [self selectedMessage];
    NSNumber *messageID = [message objectForKey:@"message_id"];
    if (!messageID || self.loading) {
        return;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"scheduled.deleteConfirm")];
    [alert addButtonWithTitle:TGLoc(@"delete")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"scheduled.saving")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *safeMessageID = [messageID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *result = [client deleteMessagesInChatID:chatID
                                               messageIDs:[NSArray arrayWithObject:safeMessageID]
                                                   revoke:YES
                                                  timeout:8.0
                                                    error:&error];
        NSString *detail = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:[result length] > 0 ? TGLoc(@"scheduled.saved") : (detail ? detail : TGLoc(@"scheduled.failed"))];
            if ([result length] > 0) {
                [self reloadMessages];
            }
            [detail release];
            [safeMessageID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

@end
