#import "TGStatusWindowController.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"

static NSUInteger const TGStatusChatPreviewInitialLimit = 40;
static NSUInteger const TGStatusChatPreviewStep = 40;
static NSUInteger const TGStatusChatPreviewMaximumLimit = 500;
static NSUInteger const TGMessagePreviewInitialLimit = 20;
static NSUInteger const TGMessagePrefillMinimumRows = 20;
static NSUInteger const TGMessagePrefillMaxAttempts = 3;
static CGFloat const TGPanelCornerRadius = 8.0;
static CGFloat const TGPanelHeaderHeight = 32.0;
static CGFloat const TGMessageBubbleMaximumWidth = 420.0;
static NSString * const TGSectionChats = @"chats";
static NSString * const TGSectionProfile = @"profile";
static NSString * const TGSectionSettings = @"settings";
static NSString * const TGSectionAbout = @"about";
static NSString * const TGSectionLogs = @"logs";

static NSColor *TGClassicWindowBottomColor(void) {
    return [NSColor colorWithCalibratedRed:0.17 green:0.145 blue:0.115 alpha:1.0];
}

static NSColor *TGClassicPanelBottomColor(void) {
    return [NSColor colorWithCalibratedRed:0.90 green:0.86 blue:0.76 alpha:1.0];
}

static NSColor *TGClassicHeaderBottomColor(void) {
    return [NSColor colorWithCalibratedRed:0.39 green:0.315 blue:0.22 alpha:1.0];
}

static NSColor *TGClassicTablePaperColor(void) {
    return [NSColor colorWithCalibratedRed:0.95 green:0.91 blue:0.80 alpha:1.0];
}

static NSColor *TGClassicInkColor(void) {
    return [NSColor colorWithCalibratedRed:0.12 green:0.075 blue:0.045 alpha:1.0];
}

static NSColor *TGClassicMutedInkColor(void) {
    return [NSColor colorWithCalibratedRed:0.36 green:0.26 blue:0.16 alpha:1.0];
}

static NSColor *TGClassicOutgoingBubbleBottomColor(void) {
    return [NSColor colorWithCalibratedRed:0.82 green:0.66 blue:0.38 alpha:1.0];
}

static NSColor *TGClassicIncomingBubbleBottomColor(void) {
    return [NSColor colorWithCalibratedRed:0.985 green:0.955 blue:0.875 alpha:1.0];
}

static NSString *TGCurrentYearString(void) {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSYearCalendarUnit fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"%ld", (long)[components year]];
}

static NSString *TGShortTimeStringFromDateValue(NSNumber *dateValue) {
    if (![dateValue respondsToSelector:@selector(integerValue)] || [dateValue integerValue] <= 0) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[dateValue integerValue]];
    return [NSDateFormatter localizedStringFromDate:date
                                          dateStyle:NSDateFormatterNoStyle
                                          timeStyle:NSDateFormatterShortStyle];
}

static CGFloat TGMessageBubbleHeightForItem(TGMessageItem *item, CGFloat availableWidth) {
    if (!item) {
        return 48.0;
    }
    CGFloat maximumTextWidth = availableWidth * 0.68;
    if (maximumTextWidth > TGMessageBubbleMaximumWidth) {
        maximumTextWidth = TGMessageBubbleMaximumWidth;
    }
    if (maximumTextWidth < 180.0) {
        maximumTextWidth = 180.0;
    }

    NSString *text = ([item.preview length] > 0) ? item.preview : @"[Message]";
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                paragraph, NSParagraphStyleAttributeName,
                                nil];
    NSRect textRect = [text boundingRectWithSize:NSMakeSize(maximumTextWidth - 24.0, 1000.0)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:attributes];
    CGFloat height = ceil(NSHeight(textRect)) + 26.0;
    if (height < 42.0) {
        height = 42.0;
    }
    return height + 10.0;
}

static long long TGMessageSortValue(id value) {
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [value longLongValue];
    }
    return 0;
}

static NSInteger TGCompareMessageItemsAscending(id left, id right, void *context) {
    (void)context;
    long long leftDate = 0;
    long long rightDate = 0;
    long long leftMessageID = 0;
    long long rightMessageID = 0;

    if ([left isKindOfClass:[TGMessageItem class]]) {
        leftDate = TGMessageSortValue([(TGMessageItem *)left date]);
        leftMessageID = TGMessageSortValue([(TGMessageItem *)left messageID]);
    }
    if ([right isKindOfClass:[TGMessageItem class]]) {
        rightDate = TGMessageSortValue([(TGMessageItem *)right date]);
        rightMessageID = TGMessageSortValue([(TGMessageItem *)right messageID]);
    }

    if (leftDate < rightDate) {
        return NSOrderedAscending;
    }
    if (leftDate > rightDate) {
        return NSOrderedDescending;
    }
    if (leftMessageID < rightMessageID) {
        return NSOrderedAscending;
    }
    if (leftMessageID > rightMessageID) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

@interface TGChromeView : NSView
@end

@implementation TGChromeView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [TGClassicWindowBottomColor() set];
    NSRectFill(bounds);
}

@end

@interface TGRailView : NSView
@end

@implementation TGRailView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSBezierPath *railPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 1.0, 1.0)
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];
    [TGClassicWindowBottomColor() set];
    [railPath fill];

    [[NSColor colorWithCalibratedRed:0.48 green:0.36 blue:0.20 alpha:1.0] set];
    [railPath setLineWidth:1.0];
    [railPath stroke];
}

@end

@interface TGPanelView : NSView
@end

@implementation TGPanelView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect panelBounds = NSInsetRect(bounds, 1.0, 1.0);
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelBounds
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];

    [TGClassicPanelBottomColor() set];
    [panelPath fill];

    [NSGraphicsContext saveGraphicsState];
    [panelPath addClip];
    NSRect headerRect = NSMakeRect(NSMinX(panelBounds),
                                   NSMaxY(panelBounds) - TGPanelHeaderHeight,
                                   NSWidth(panelBounds),
                                   TGPanelHeaderHeight);
    [TGClassicHeaderBottomColor() set];
    NSRectFill(headerRect);
    [[NSColor colorWithCalibratedRed:0.23 green:0.18 blue:0.12 alpha:1.0] set];
    NSRectFill(NSMakeRect(NSMinX(headerRect), NSMinY(headerRect), NSWidth(headerRect), 1.0));
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(panelBounds, 1.0, 1.0)
                                                               xRadius:(TGPanelCornerRadius - 1.0)
                                                               yRadius:(TGPanelCornerRadius - 1.0)];
    [[NSColor colorWithCalibratedRed:0.31 green:0.24 blue:0.16 alpha:1.0] set];
    [innerPath setLineWidth:1.0];
    [innerPath stroke];
}

@end

@interface TGNavigationButtonCell : NSButtonCell
@end

@implementation TGNavigationButtonCell

- (id)copyWithZone:(NSZone *)zone {
    TGNavigationButtonCell *cell = [super copyWithZone:zone];
    return cell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL selected = ([self state] == NSOnState);
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.46;
    NSRect buttonRect = NSInsetRect(cellFrame, 1.0, 2.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:6.0 yRadius:6.0];

    NSColor *fillColor = nil;
    if (selected) {
        fillColor = [NSColor colorWithCalibratedRed:0.79 green:0.62 blue:0.34 alpha:alpha];
    } else if (highlighted) {
        fillColor = [NSColor colorWithCalibratedRed:0.25 green:0.20 blue:0.15 alpha:alpha];
    } else {
        fillColor = [NSColor colorWithCalibratedRed:0.16 green:0.13 blue:0.10 alpha:alpha];
    }

    [fillColor set];
    [path fill];

    NSColor *strokeColor = selected ? [NSColor colorWithCalibratedRed:0.30 green:0.18 blue:0.07 alpha:0.95]
                                    : [NSColor colorWithCalibratedRed:0.46 green:0.36 blue:0.23 alpha:0.75];
    [strokeColor set];
    [path setLineWidth:1.0];
    [path stroke];

    NSString *title = [self title] ? [self title] : @"";
    NSFont *font = selected ? [NSFont boldSystemFontOfSize:11.0] : [NSFont systemFontOfSize:11.0];
    NSColor *textColor = selected ? TGClassicInkColor() : [NSColor colorWithCalibratedRed:0.95 green:0.88 blue:0.72 alpha:alpha];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                textColor, NSForegroundColorAttributeName,
                                nil];
    NSSize titleSize = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMinX(cellFrame) + floor((NSWidth(cellFrame) - titleSize.width) / 2.0),
                                  NSMinY(cellFrame) + floor((NSHeight(cellFrame) - titleSize.height) / 2.0),
                                  titleSize.width,
                                  titleSize.height);
    [title drawInRect:titleRect withAttributes:attributes];
}

@end

@interface TGMessageBubbleCell : NSTextFieldCell {
    TGMessageItem *_messageItem;
}
@property (nonatomic, retain) TGMessageItem *messageItem;
@end

@implementation TGMessageBubbleCell

@synthesize messageItem = _messageItem;

- (id)copyWithZone:(NSZone *)zone {
    TGMessageBubbleCell *cell = [super copyWithZone:zone];
    [cell setMessageItem:self.messageItem];
    return cell;
}

- (void)setObjectValue:(id)value {
    if ([value isKindOfClass:[TGMessageItem class]]) {
        self.messageItem = (TGMessageItem *)value;
        [super setObjectValue:@""];
        return;
    }
    self.messageItem = nil;
    [super setObjectValue:(value ? value : @"")];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGMessageItem *item = self.messageItem;
    if (!item) {
        id value = [self objectValue];
        if ([value isKindOfClass:[TGMessageItem class]]) {
            item = (TGMessageItem *)value;
        }
    }
    if (!item) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    CGFloat maximumBubbleWidth = NSWidth(cellFrame) * 0.68;
    if (maximumBubbleWidth > TGMessageBubbleMaximumWidth) {
        maximumBubbleWidth = TGMessageBubbleMaximumWidth;
    }
    if (maximumBubbleWidth < 180.0) {
        maximumBubbleWidth = 180.0;
    }

    NSString *messageText = ([item.preview length] > 0) ? item.preview : @"[Message]";
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSRect measuredRect = [messageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                    options:NSStringDrawingUsesLineFragmentOrigin
                                                 attributes:textAttributes];
    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0;
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:13.0 yRadius:13.0];

    NSColor *bubbleFillColor = outgoing ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor();
    [bubbleFillColor set];
    [bubblePath fill];

    NSColor *strokeColor = outgoing ? [NSColor colorWithCalibratedRed:0.36 green:0.22 blue:0.09 alpha:0.85]
                                    : [NSColor colorWithCalibratedRed:0.55 green:0.45 blue:0.30 alpha:0.70];
    [strokeColor set];
    [bubblePath setLineWidth:1.0];
    [bubblePath stroke];

    NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                 NSMinY(bubbleRect) + 13.0,
                                 NSWidth(bubbleRect) - 24.0,
                                 NSHeight(bubbleRect) - 20.0);
    [messageText drawWithRect:textRect
                      options:NSStringDrawingUsesLineFragmentOrigin
                   attributes:textAttributes];

    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    if ([timeString length] > 0) {
        NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                        [NSColor colorWithCalibratedRed:0.31 green:0.22 blue:0.13 alpha:0.72], NSForegroundColorAttributeName,
                                        nil];
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        NSRect timeRect = NSMakeRect(NSMaxX(bubbleRect) - timeSize.width - 12.0,
                                     NSMinY(bubbleRect) + 4.0,
                                     timeSize.width,
                                     10.0);
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
    }
}

- (void)dealloc {
    [_messageItem release];
    [super dealloc];
}

@end

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
@property (nonatomic, retain) NSView *topPanelView;
@property (nonatomic, retain) NSView *sidebarPanelView;
@property (nonatomic, retain) NSView *conversationPanelView;
@property (nonatomic, retain) NSView *diagnosticsPanelView;
@property (nonatomic, retain) NSView *loginPanelView;
@property (nonatomic, retain) NSView *profilePanelView;
@property (nonatomic, retain) NSView *settingsPanelView;
@property (nonatomic, retain) NSView *aboutPanelView;
@property (nonatomic, retain) NSArray *navigationButtons;
@property (nonatomic, retain) NSTextField *diagnosticsLabel;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSScrollView *detailsScrollView;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSButton *loadMoreChatsButton;
@property (nonatomic, retain) NSButton *loadMessagesButton;
@property (nonatomic, retain) NSButton *loadOlderMessagesButton;
@property (nonatomic, retain) NSButton *quitButton;
@property (nonatomic, retain) NSTextField *sendLabel;
@property (nonatomic, retain) NSTextField *sendTextField;
@property (nonatomic, retain) NSButton *sendMessageButton;
@property (nonatomic, retain) NSTextField *authLabel;
@property (nonatomic, retain) NSTextField *authStateField;
@property (nonatomic, retain) NSTextField *loginTitleField;
@property (nonatomic, retain) NSTextField *loginHintField;
@property (nonatomic, retain) NSTextField *authTextField;
@property (nonatomic, retain) NSSecureTextField *authSecureField;
@property (nonatomic, retain) NSButton *authButton;
@property (nonatomic, retain) NSTextField *chatsLabel;
@property (nonatomic, retain) NSTextField *messagesLabel;
@property (nonatomic, retain) NSTextField *selectedChatField;
@property (nonatomic, retain) NSScrollView *chatScrollView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) NSScrollView *messageScrollView;
@property (nonatomic, retain) NSTableView *messageTableView;
@property (nonatomic, retain) NSMutableArray *messageItems;
@property (nonatomic, retain) NSTextField *profileTitleField;
@property (nonatomic, retain) NSTextField *profileNameField;
@property (nonatomic, retain) NSTextField *profileUsernameField;
@property (nonatomic, retain) NSTextField *profileIDField;
@property (nonatomic, retain) NSTextField *profileStateField;
@property (nonatomic, retain) NSTextField *settingsTitleField;
@property (nonatomic, retain) NSTextField *settingsStateField;
@property (nonatomic, retain) NSTextField *settingsLibraryField;
@property (nonatomic, retain) NSTextField *settingsStorageField;
@property (nonatomic, retain) NSImageView *aboutIconView;
@property (nonatomic, retain) NSTextField *aboutTitleField;
@property (nonatomic, retain) NSTextField *aboutVersionField;
@property (nonatomic, retain) NSTextField *aboutCopyrightField;
@property (nonatomic, retain) NSTextField *aboutLinkField;
@property (nonatomic, retain) NSNumber *selectedChatID;
@property (nonatomic, copy) NSString *selectedChatTitle;
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState;
@property (nonatomic, copy) NSString *activeSection;
@property (nonatomic, retain) NSTimer *liveUpdateTimer;
@property (nonatomic, assign) BOOL controlsBusy;
@property (nonatomic, assign) BOOL backgroundChatRefreshInFlight;
@property (nonatomic, assign) BOOL backgroundMessageRefreshInFlight;
@property (nonatomic, assign) BOOL pendingLiveChatRefresh;
@property (nonatomic, assign) BOOL pendingLiveMessageRefresh;
@property (nonatomic, assign) NSUInteger chatPreviewLimit;
@property (nonatomic, assign) BOOL chatsExhausted;
@property (nonatomic, assign) BOOL olderMessagesExhausted;
@property (nonatomic, assign) BOOL autoOlderMessagesLoadArmed;
@property (nonatomic, assign) BOOL autoChatListLoadArmed;
@property (nonatomic, assign) BOOL forceMessageScrollToNewest;
@property (nonatomic, assign) BOOL initialConnectStarted;
@property (nonatomic, assign) BOOL profileSummaryLoaded;
@end

@implementation TGStatusWindowController

@synthesize topPanelView = _topPanelView;
@synthesize sidebarPanelView = _sidebarPanelView;
@synthesize conversationPanelView = _conversationPanelView;
@synthesize diagnosticsPanelView = _diagnosticsPanelView;
@synthesize loginPanelView = _loginPanelView;
@synthesize profilePanelView = _profilePanelView;
@synthesize settingsPanelView = _settingsPanelView;
@synthesize aboutPanelView = _aboutPanelView;
@synthesize navigationButtons = _navigationButtons;
@synthesize diagnosticsLabel = _diagnosticsLabel;
@synthesize statusField = _statusField;
@synthesize titleField = _titleField;
@synthesize detailsScrollView = _detailsScrollView;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize loadMoreChatsButton = _loadMoreChatsButton;
@synthesize loadMessagesButton = _loadMessagesButton;
@synthesize loadOlderMessagesButton = _loadOlderMessagesButton;
@synthesize quitButton = _quitButton;
@synthesize sendLabel = _sendLabel;
@synthesize sendTextField = _sendTextField;
@synthesize sendMessageButton = _sendMessageButton;
@synthesize authLabel = _authLabel;
@synthesize authStateField = _authStateField;
@synthesize loginTitleField = _loginTitleField;
@synthesize loginHintField = _loginHintField;
@synthesize authTextField = _authTextField;
@synthesize authSecureField = _authSecureField;
@synthesize authButton = _authButton;
@synthesize chatsLabel = _chatsLabel;
@synthesize messagesLabel = _messagesLabel;
@synthesize selectedChatField = _selectedChatField;
@synthesize chatScrollView = _chatScrollView;
@synthesize chatTableView = _chatTableView;
@synthesize chatItems = _chatItems;
@synthesize messageScrollView = _messageScrollView;
@synthesize messageTableView = _messageTableView;
@synthesize messageItems = _messageItems;
@synthesize profileTitleField = _profileTitleField;
@synthesize profileNameField = _profileNameField;
@synthesize profileUsernameField = _profileUsernameField;
@synthesize profileIDField = _profileIDField;
@synthesize profileStateField = _profileStateField;
@synthesize settingsTitleField = _settingsTitleField;
@synthesize settingsStateField = _settingsStateField;
@synthesize settingsLibraryField = _settingsLibraryField;
@synthesize settingsStorageField = _settingsStorageField;
@synthesize aboutIconView = _aboutIconView;
@synthesize aboutTitleField = _aboutTitleField;
@synthesize aboutVersionField = _aboutVersionField;
@synthesize aboutCopyrightField = _aboutCopyrightField;
@synthesize aboutLinkField = _aboutLinkField;
@synthesize selectedChatID = _selectedChatID;
@synthesize selectedChatTitle = _selectedChatTitle;
@synthesize client = _client;
@synthesize currentAuthState = _currentAuthState;
@synthesize activeSection = _activeSection;
@synthesize liveUpdateTimer = _liveUpdateTimer;
@synthesize controlsBusy = _controlsBusy;
@synthesize backgroundChatRefreshInFlight = _backgroundChatRefreshInFlight;
@synthesize backgroundMessageRefreshInFlight = _backgroundMessageRefreshInFlight;
@synthesize pendingLiveChatRefresh = _pendingLiveChatRefresh;
@synthesize pendingLiveMessageRefresh = _pendingLiveMessageRefresh;
@synthesize chatPreviewLimit = _chatPreviewLimit;
@synthesize chatsExhausted = _chatsExhausted;
@synthesize olderMessagesExhausted = _olderMessagesExhausted;
@synthesize autoOlderMessagesLoadArmed = _autoOlderMessagesLoadArmed;
@synthesize autoChatListLoadArmed = _autoChatListLoadArmed;
@synthesize forceMessageScrollToNewest = _forceMessageScrollToNewest;
@synthesize initialConnectStarted = _initialConnectStarted;
@synthesize profileSummaryLoaded = _profileSummaryLoaded;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 980, 700);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window setMinSize:NSMakeSize(760, 620)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [[self window] setDelegate:self];
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
        self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
        self.activeSection = TGSectionChats;
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self buildContentView];
        [self startLiveUpdateTimerIfNeeded];
        [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setTextColor:TGClassicInkColor()];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)applyPanelHeaderLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
    [field setFont:[NSFont boldSystemFontOfSize:12.0]];
}

- (void)applyPanelHeaderDetailStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];
    [field setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applyMutedLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicMutedInkColor()];
}

- (void)applySkeuomorphicButtonStyle:(NSButton *)button isPrimary:(BOOL)isPrimary {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSTexturedRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    if (isPrimary) {
        [button setFont:[NSFont boldSystemFontOfSize:12.0]];
    } else {
        [button setFont:[NSFont systemFontOfSize:11.0]];
    }
}

- (void)applySkeuomorphicTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:YES];
    [textField setBordered:YES];
    [textField setBackgroundColor:TGClassicTablePaperColor()];
    [textField setTextColor:TGClassicInkColor()];
    [textField setDrawsBackground:YES];
    [textField setFocusRingType:NSFocusRingTypeExterior];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applySkeuomorphicScrollStyle:(NSScrollView *)scrollView {
    [scrollView setBorderType:NSNoBorder];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];
    [scrollView setHasVerticalScroller:YES];
}

- (void)applySkeuomorphicTableStyle:(NSTableView *)tableView {
    [tableView setBackgroundColor:TGClassicTablePaperColor()];
    [tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [tableView setGridColor:[NSColor colorWithCalibratedRed:0.72 green:0.62 blue:0.45 alpha:1.0]];
    [tableView setUsesAlternatingRowBackgroundColors:NO];
    [tableView setIntercellSpacing:NSMakeSize(8.0, 1.0)];
    [tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
}

- (void)applySkeuomorphicHeaderCellStyle:(NSTextFieldCell *)headerCell {
    if (!headerCell) {
        return;
    }
    [headerCell setFont:[NSFont boldSystemFontOfSize:11.0]];
    [headerCell setTextColor:TGClassicMutedInkColor()];
    [headerCell setAlignment:NSLeftTextAlignment];
    [headerCell setDrawsBackground:YES];
    [headerCell setBackgroundColor:[NSColor colorWithCalibratedRed:0.78 green:0.66 blue:0.46 alpha:1.0]];
}

- (void)buildContentView {
    TGChromeView *contentView = [[[TGChromeView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:contentView];
    [contentView setAutoresizesSubviews:YES];

    self.topPanelView = [[[TGRailView alloc] initWithFrame:NSMakeRect(16, 628, 948, 56)] autorelease];
    [self.topPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.topPanelView];

    self.sidebarPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 286, 480)] autorelease];
    [self.sidebarPanelView setAutoresizingMask:(NSViewHeightSizable | NSViewMaxXMargin)];
    [contentView addSubview:self.sidebarPanelView];

    self.conversationPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(314, 132, 650, 480)] autorelease];
    [self.conversationPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.conversationPanelView];

    self.diagnosticsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 16, 948, 104)] autorelease];
    [self.diagnosticsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.diagnosticsPanelView];

    self.loginPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(180, 150, 620, 360)] autorelease];
    [self.loginPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.loginPanelView];

    self.profilePanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.profilePanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.profilePanelView];

    self.settingsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.settingsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.settingsPanelView];

    self.aboutPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.aboutPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.aboutPanelView];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 668, 712, 28)
                                      text:@"Telegraphica"
                                      font:[NSFont boldSystemFontOfSize:20.0]];
    [self.titleField setTextColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
    [contentView addSubview:self.titleField];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 636, 712, 22)
                                     text:@"Connecting..."
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [contentView addSubview:self.statusField];

    NSArray *navigationTitles = [NSArray arrayWithObjects:@"Chats", @"Profile", @"Settings", @"About", @"Logs", nil];
    NSMutableArray *navigationButtons = [NSMutableArray arrayWithCapacity:[navigationTitles count]];
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [navigationTitles count]; navigationIndex++) {
        NSString *buttonTitle = [navigationTitles objectAtIndex:navigationIndex];
        NSButton *navigationButton = [[[NSButton alloc] initWithFrame:NSMakeRect(260 + (navigationIndex * 82), 636, 78, 28)] autorelease];
        TGNavigationButtonCell *navigationCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [navigationCell setButtonType:NSToggleButton];
        [navigationButton setCell:navigationCell];
        [navigationButton setTitle:buttonTitle];
        [navigationButton setButtonType:NSToggleButton];
        [navigationButton setBordered:NO];
        [navigationButton setTag:(NSInteger)navigationIndex];
        [navigationButton setTarget:self];
        [navigationButton setAction:@selector(navigationChanged:)];
        [navigationButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
        [contentView addSubview:navigationButton];
        [navigationButtons addObject:navigationButton];
    }
    self.navigationButtons = navigationButtons;

    self.detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.detailsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[self.detailsScrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];
    [self.detailsView setString:@"Diagnostics are separated from the main chat view. Connection events will appear here.\n"];
    [self.detailsScrollView setDocumentView:self.detailsView];
    [contentView addSubview:self.detailsScrollView];

    self.diagnosticsLabel = [self labelWithFrame:NSMakeRect(24, 104, 112, 18)
                                            text:@"Activity"
                                            font:[NSFont boldSystemFontOfSize:11.0]];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [contentView addSubview:self.diagnosticsLabel];

    self.loginTitleField = [self labelWithFrame:NSMakeRect(230, 430, 520, 26)
                                           text:@"Sign in to Telegram"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.loginTitleField setAlignment:NSCenterTextAlignment];
    [self.loginTitleField setTextColor:TGClassicInkColor()];
    [contentView addSubview:self.loginTitleField];

    self.loginHintField = [self labelWithFrame:NSMakeRect(250, 392, 480, 44)
                                          text:@"Telegraphica will connect automatically. If this Mac is not signed in yet, continue with your phone number, login code, and password."
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.loginHintField setAlignment:NSCenterTextAlignment];
    [[self.loginHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.loginHintField];
    [contentView addSubview:self.loginHintField];

    self.authLabel = [self labelWithFrame:NSMakeRect(24, 374, 76, 22)
                                     text:@"Auth:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authLabel];
    [contentView addSubview:self.authLabel];

    self.authStateField = [self labelWithFrame:NSMakeRect(104, 374, 560, 22)
                                          text:@"not checked"
                                          font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authStateField];
    [[self.authStateField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.authStateField];

    self.authTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authTextField setEnabled:NO];
    [self.authTextField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authTextField];
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self applySkeuomorphicTextFieldStyle:self.authSecureField];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 366, 116, 32)] autorelease];
    [self.authButton setTitle:@"Send"];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self applySkeuomorphicButtonStyle:self.authButton isPrimary:NO];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    self.chatsLabel = [self labelWithFrame:NSMakeRect(24, 338, 76, 22)
                                      text:@"Chats"
                                      font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [contentView addSubview:self.chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 332, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"Refresh"];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadChatsButton isPrimary:YES];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    self.loadMoreChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(224, 332, 80, 32)] autorelease];
    [self.loadMoreChatsButton setTitle:@"More"];
    [self.loadMoreChatsButton setTarget:self];
    [self.loadMoreChatsButton setAction:@selector(loadMoreChats:)];
    [self.loadMoreChatsButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadMoreChatsButton isPrimary:NO];
    [self.loadMoreChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMoreChatsButton];

    self.chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[self.chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];
    [self.chatTableView setRowHeight:34.0];
    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self.chatTableView setHeaderView:nil];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Name"];
    [self applySkeuomorphicHeaderCellStyle:[chatColumn headerCell]];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    NSTableColumn *unreadColumn = [[[NSTableColumn alloc] initWithIdentifier:@"unread_count"] autorelease];
    [[unreadColumn headerCell] setStringValue:@"New"];
    [self applySkeuomorphicHeaderCellStyle:[unreadColumn headerCell]];
    [unreadColumn setWidth:48.0];
    [self.chatTableView addTableColumn:unreadColumn];

    [self.chatScrollView setDocumentView:self.chatTableView];
    [[self.chatScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chatScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.chatScrollView contentView]];
    [contentView addSubview:self.chatScrollView];

    self.messagesLabel = [self labelWithFrame:NSMakeRect(24, 198, 86, 22)
                                         text:@"Conversation"
                                         font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [contentView addSubview:self.messagesLabel];

    self.loadMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(116, 192, 136, 32)] autorelease];
    [self.loadMessagesButton setTitle:@"Reload"];
    [self.loadMessagesButton setTarget:self];
    [self.loadMessagesButton setAction:@selector(loadMessages:)];
    [self.loadMessagesButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadMessagesButton isPrimary:YES];
    [self.loadMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMessagesButton];

    self.loadOlderMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(264, 192, 112, 32)] autorelease];
    [self.loadOlderMessagesButton setTitle:@"Older"];
    [self.loadOlderMessagesButton setTarget:self];
    [self.loadOlderMessagesButton setAction:@selector(loadOlderMessages:)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.loadOlderMessagesButton isPrimary:NO];
    [self.loadOlderMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadOlderMessagesButton];

    self.selectedChatField = [self labelWithFrame:NSMakeRect(264, 198, 472, 22)
                                             text:@"Select a chat"
                                             font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];
    [[self.selectedChatField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.selectedChatField];

    self.messageScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];

    self.messageTableView = [[[NSTableView alloc] initWithFrame:[[self.messageScrollView contentView] bounds]] autorelease];
    [self.messageTableView setDataSource:self];
    [self.messageTableView setDelegate:self];
    [self.messageTableView setAllowsColumnReordering:NO];
    [self.messageTableView setAllowsMultipleSelection:NO];
    [self.messageTableView setRowHeight:52.0];
    [self applySkeuomorphicTableStyle:self.messageTableView];
    [self.messageTableView setGridStyleMask:0];
    [self.messageTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [self.messageTableView setHeaderView:nil];

    NSTableColumn *bubbleColumn = [[[NSTableColumn alloc] initWithIdentifier:@"bubble"] autorelease];
    [[bubbleColumn headerCell] setStringValue:@"Conversation"];
    TGMessageBubbleCell *bubbleCell = [[[TGMessageBubbleCell alloc] initTextCell:@""] autorelease];
    [bubbleCell setEditable:NO];
    [bubbleCell setSelectable:NO];
    [bubbleColumn setDataCell:bubbleCell];
    [bubbleColumn setWidth:500.0];
    [self.messageTableView addTableColumn:bubbleColumn];

    [self.messageScrollView setDocumentView:self.messageTableView];
    [[self.messageScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.messageScrollView contentView]];
    [contentView addSubview:self.messageScrollView];

    self.sendLabel = [self labelWithFrame:NSMakeRect(24, 58, 48, 22)
                                     text:@"Send:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.sendLabel];

    self.sendTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextField setEnabled:NO];
    [self applySkeuomorphicTextFieldStyle:self.sendTextField];
    [self.sendTextField setDelegate:(id)self];
    [self.sendTextField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextField];

    self.sendMessageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(588, 50, 148, 32)] autorelease];
    [self.sendMessageButton setTitle:@"Send"];
    [self.sendMessageButton setTarget:self];
    [self.sendMessageButton setAction:@selector(sendMessage:)];
    [self.sendMessageButton setEnabled:NO];
    [self applySkeuomorphicButtonStyle:self.sendMessageButton isPrimary:YES];
    [self.sendMessageButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.sendMessageButton];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Reconnect"];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self applySkeuomorphicButtonStyle:self.checkButton isPrimary:YES];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    self.quitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(176, 28, 96, 32)] autorelease];
    [self.quitButton setTitle:@"Quit"];
    [self.quitButton setTarget:NSApp];
    [self.quitButton setAction:@selector(terminate:)];
    [self applySkeuomorphicButtonStyle:self.quitButton isPrimary:NO];
    [self.quitButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.quitButton];

    self.profileTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                             text:@"My Profile"
                                             font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [contentView addSubview:self.profileTitleField];

    self.profileNameField = [self labelWithFrame:NSMakeRect(64, 458, 620, 24)
                                            text:@"Name: not loaded yet"
                                            font:[NSFont systemFontOfSize:14.0]];
    [contentView addSubview:self.profileNameField];

    self.profileUsernameField = [self labelWithFrame:NSMakeRect(64, 424, 620, 24)
                                                text:@"Username: not loaded yet"
                                                font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.profileUsernameField];
    [contentView addSubview:self.profileUsernameField];

    self.profileIDField = [self labelWithFrame:NSMakeRect(64, 392, 620, 24)
                                           text:@"Telegram ID: not loaded yet"
                                           font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.profileIDField];
    [contentView addSubview:self.profileIDField];

    self.profileStateField = [self labelWithFrame:NSMakeRect(64, 348, 720, 38)
                                             text:@"Profile data is loaded from Telegram after authorization. Sensitive values are not written to diagnostics."
                                             font:[NSFont systemFontOfSize:12.0]];
    [[self.profileStateField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.profileStateField];
    [contentView addSubview:self.profileStateField];

    self.settingsTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                              text:@"Settings"
                                              font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [contentView addSubview:self.settingsTitleField];

    self.settingsStateField = [self labelWithFrame:NSMakeRect(64, 458, 760, 24)
                                              text:@"Session: waiting for connection"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsStateField];

    self.settingsLibraryField = [self labelWithFrame:NSMakeRect(64, 424, 760, 24)
                                                text:@"Engine: not loaded"
                                                font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [[self.settingsLibraryField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.settingsLibraryField];

    self.settingsStorageField = [self labelWithFrame:NSMakeRect(64, 380, 760, 44)
                                                text:@"Local session data stays under this Mac user account. Diagnostic logs are available in the Logs tab."
                                                font:[NSFont systemFontOfSize:12.0]];
    [[self.settingsStorageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [contentView addSubview:self.settingsStorageField];

    self.aboutIconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(430, 396, 120, 120)] autorelease];
    NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
    if (!appIcon) {
        appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
    }
    [self.aboutIconView setImage:appIcon];
    [self.aboutIconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [contentView addSubview:self.aboutIconView];

    self.aboutTitleField = [self labelWithFrame:NSMakeRect(240, 352, 500, 30)
                                           text:@"Telegraphica"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.aboutTitleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:self.aboutTitleField];

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [info objectForKey:@"CFBundleVersion"];
    NSString *versionText = [NSString stringWithFormat:@"Version %@ (%@)", version ? version : @"0.1.0", build ? build : @"0.1.0"];
    self.aboutVersionField = [self labelWithFrame:NSMakeRect(240, 324, 500, 22)
                                             text:versionText
                                             font:[NSFont systemFontOfSize:12.0]];
    [self.aboutVersionField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutVersionField];
    [contentView addSubview:self.aboutVersionField];

    NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@ Yura Menschikov. All rights reserved.", TGCurrentYearString()];
    self.aboutCopyrightField = [self labelWithFrame:NSMakeRect(240, 292, 500, 22)
                                               text:copyrightText
                                               font:[NSFont systemFontOfSize:12.0]];
    [self.aboutCopyrightField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutCopyrightField];
    [contentView addSubview:self.aboutCopyrightField];

    self.aboutLinkField = [self labelWithFrame:NSMakeRect(240, 260, 500, 22)
                                          text:@"Project page: coming soon"
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.aboutLinkField setAlignment:NSCenterTextAlignment];
    [self.aboutLinkField setSelectable:YES];
    [self.aboutLinkField setTextColor:[NSColor colorWithCalibratedRed:0.42 green:0.26 blue:0.10 alpha:1.0]];
    [contentView addSubview:self.aboutLinkField];

    [self layoutContentView];
    [self updateVisibleSection];
}

- (NSString *)sectionIdentifierForNavigationTag:(NSInteger)navigationTag {
    if (navigationTag == 1) {
        return TGSectionProfile;
    }
    if (navigationTag == 2) {
        return TGSectionSettings;
    }
    if (navigationTag == 3) {
        return TGSectionAbout;
    }
    if (navigationTag == 4) {
        return TGSectionLogs;
    }
    return TGSectionChats;
}

- (NSInteger)navigationTagForSectionIdentifier:(NSString *)section {
    if ([section isEqualToString:TGSectionProfile]) {
        return 1;
    }
    if ([section isEqualToString:TGSectionSettings]) {
        return 2;
    }
    if ([section isEqualToString:TGSectionAbout]) {
        return 3;
    }
    if ([section isEqualToString:TGSectionLogs]) {
        return 4;
    }
    return 0;
}

- (void)updateNavigationButtonsForSection:(NSString *)section enabled:(BOOL)enabled {
    NSInteger selectedTag = [self navigationTagForSectionIdentifier:section];
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        NSButton *button = [self.navigationButtons objectAtIndex:index];
        [button setEnabled:(enabled && ready)];
        [button setHidden:!ready];
        [button setState:([button tag] == selectedTag) ? NSOnState : NSOffState];
    }
}

- (void)navigationChanged:(id)sender {
    if ([sender respondsToSelector:@selector(tag)]) {
        NSInteger navigationTag = [sender tag];
        if (![self.currentAuthState isEqualToString:@"ready"]) {
            navigationTag = 0;
        }
        self.activeSection = [self sectionIdentifierForNavigationTag:navigationTag];
    }
    [self updateVisibleSection];
}

- (void)showView:(NSView *)view visible:(BOOL)visible {
    [view setHidden:!visible];
}

- (void)updateVisibleSection {
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSString *section = self.activeSection ? self.activeSection : TGSectionChats;
    if (!ready && ![section isEqualToString:TGSectionChats]) {
        section = TGSectionChats;
        self.activeSection = TGSectionChats;
    }
    BOOL showLogs = (ready && [section isEqualToString:TGSectionLogs]);
    BOOL showLogin = !ready;

    [self updateNavigationButtonsForSection:section enabled:!self.controlsBusy];

    [self showView:self.loginPanelView visible:showLogin];
    [self showView:self.loginTitleField visible:showLogin];
    [self showView:self.loginHintField visible:showLogin];

    [self showView:self.authLabel visible:showLogin];
    [self showView:self.authStateField visible:(showLogin && ![self isAuthInputState:self.currentAuthState])];
    [self showView:self.authTextField visible:(showLogin && ([self.currentAuthState isEqualToString:@"waitPhoneNumber"] || [self.currentAuthState isEqualToString:@"waitCode"]))];
    [self showView:self.authSecureField visible:(showLogin && [self.currentAuthState isEqualToString:@"waitPassword"])];
    [self showView:self.authButton visible:(showLogin && [self isAuthInputState:self.currentAuthState])];

    BOOL showChats = (ready && [section isEqualToString:TGSectionChats]);
    [self showView:self.sidebarPanelView visible:showChats];
    [self showView:self.conversationPanelView visible:showChats];
    [self showView:self.chatsLabel visible:showChats];
    [self showView:self.loadChatsButton visible:showChats];
    [self showView:self.loadMoreChatsButton visible:showChats];
    [self showView:self.chatScrollView visible:showChats];
    [self showView:self.messagesLabel visible:showChats];
    [self showView:self.loadMessagesButton visible:showChats];
    [self showView:self.loadOlderMessagesButton visible:showChats];
    [self showView:self.selectedChatField visible:showChats];
    [self showView:self.messageScrollView visible:showChats];
    [self showView:self.sendLabel visible:showChats];
    [self showView:self.sendTextField visible:showChats];
    [self showView:self.sendMessageButton visible:showChats];

    BOOL showProfile = (ready && [section isEqualToString:TGSectionProfile]);
    [self showView:self.profilePanelView visible:showProfile];
    [self showView:self.profileTitleField visible:showProfile];
    [self showView:self.profileNameField visible:showProfile];
    [self showView:self.profileUsernameField visible:showProfile];
    [self showView:self.profileIDField visible:showProfile];
    [self showView:self.profileStateField visible:showProfile];

    BOOL showSettings = (ready && [section isEqualToString:TGSectionSettings]);
    [self showView:self.settingsPanelView visible:showSettings];
    [self showView:self.settingsTitleField visible:showSettings];
    [self showView:self.settingsStateField visible:showSettings];
    [self showView:self.settingsLibraryField visible:showSettings];
    [self showView:self.settingsStorageField visible:showSettings];

    BOOL showAbout = (ready && [section isEqualToString:TGSectionAbout]);
    [self showView:self.aboutPanelView visible:showAbout];
    [self showView:self.aboutIconView visible:showAbout];
    [self showView:self.aboutTitleField visible:showAbout];
    [self showView:self.aboutVersionField visible:showAbout];
    [self showView:self.aboutCopyrightField visible:showAbout];
    [self showView:self.aboutLinkField visible:showAbout];

    [self showView:self.diagnosticsPanelView visible:showLogs];
    [self showView:self.diagnosticsLabel visible:showLogs];
    [self showView:self.detailsScrollView visible:showLogs];
    [self showView:self.checkButton visible:showLogs];
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 10.0;
    CGFloat gutter = 10.0;
    CGFloat railWidth = 88.0;
    CGFloat railX = margin;
    CGFloat railY = margin;
    CGFloat railHeight = height - (margin * 2.0);
    CGFloat railTop = railY + railHeight;
    CGFloat mainX = railX + railWidth + gutter;
    CGFloat mainY = margin;
    CGFloat mainWidth = width - mainX - margin;
    CGFloat mainHeight = railHeight;
    CGFloat mainTop = mainY + mainHeight;
    CGFloat sidebarWidth = 292.0;

    if (railHeight < 520.0) {
        railHeight = 520.0;
        railTop = railY + railHeight;
        mainHeight = railHeight;
        mainTop = mainY + mainHeight;
    }
    if (width < 900.0) {
        sidebarWidth = 248.0;
    } else if (width < 1040.0) {
        sidebarWidth = 272.0;
    }

    CGFloat conversationX = mainX + sidebarWidth + gutter;
    CGFloat conversationWidth = width - conversationX - margin;
    if (conversationWidth < 320.0) {
        CGFloat reduction = 320.0 - conversationWidth;
        sidebarWidth -= reduction;
        if (sidebarWidth < 220.0) {
            sidebarWidth = 220.0;
        }
        conversationX = mainX + sidebarWidth + gutter;
        conversationWidth = width - conversationX - margin;
    }
    if (mainWidth < 420.0) {
        mainWidth = 420.0;
    }

    [self.topPanelView setFrame:NSMakeRect(railX, railY, railWidth, railHeight)];
    [self.sidebarPanelView setFrame:NSMakeRect(mainX, mainY, sidebarWidth, mainHeight)];
    [self.conversationPanelView setFrame:NSMakeRect(conversationX, mainY, conversationWidth, mainHeight)];
    [self.diagnosticsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.profilePanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.settingsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.aboutPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];

    [self.titleField setFont:[NSFont boldSystemFontOfSize:13.0]];
    [[self.titleField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.titleField setFrame:NSMakeRect(railX + 9.0, railTop - 48.0, railWidth - 18.0, 18.0)];
    [self.statusField setFont:[NSFont systemFontOfSize:9.0]];
    [[self.statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.statusField setFrame:NSMakeRect(railX + 9.0, railTop - 66.0, railWidth - 18.0, 14.0)];

    CGFloat navigationButtonY = railTop - 116.0;
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [self.navigationButtons count]; navigationIndex++) {
        NSButton *navigationButton = [self.navigationButtons objectAtIndex:navigationIndex];
        [navigationButton setFrame:NSMakeRect(railX + 8.0, navigationButtonY, railWidth - 16.0, 30.0)];
        navigationButtonY -= 38.0;
    }
    [self.quitButton setFrame:NSMakeRect(railX + 8.0, railY + 12.0, railWidth - 16.0, 30.0)];

    CGFloat loginWidth = mainWidth - 96.0;
    if (loginWidth > 580.0) {
        loginWidth = 580.0;
    }
    if (loginWidth < 390.0) {
        loginWidth = mainWidth - 24.0;
    }
    CGFloat loginHeight = 300.0;
    CGFloat loginX = mainX + ((mainWidth - loginWidth) / 2.0);
    CGFloat loginY = mainY + ((mainHeight - loginHeight) / 2.0);
    if (loginY < mainY + 18.0) {
        loginY = mainY + 18.0;
    }
    [self.loginPanelView setFrame:NSMakeRect(loginX, loginY, loginWidth, loginHeight)];
    [self.loginTitleField setFrame:NSMakeRect(loginX + 36.0, loginY + loginHeight - 70.0, loginWidth - 72.0, 28.0)];
    [self.loginHintField setFrame:NSMakeRect(loginX + 42.0, loginY + loginHeight - 132.0, loginWidth - 84.0, 52.0)];
    [self.authLabel setFrame:NSMakeRect(loginX + 52.0, loginY + 128.0, loginWidth - 104.0, 18.0)];
    [self.authStateField setFrame:NSMakeRect(loginX + 52.0, loginY + 82.0, loginWidth - 104.0, 48.0)];
    CGFloat loginButtonWidth = 92.0;
    CGFloat loginInputX = loginX + 52.0;
    CGFloat loginButtonX = loginX + loginWidth - 52.0 - loginButtonWidth;
    CGFloat loginInputWidth = loginButtonX - loginInputX - 10.0;
    if (loginInputWidth < 180.0) {
        loginInputWidth = 180.0;
    }
    [self.authTextField setFrame:NSMakeRect(loginInputX, loginY + 92.0, loginInputWidth, 26.0)];
    [self.authSecureField setFrame:NSMakeRect(loginInputX, loginY + 92.0, loginInputWidth, 26.0)];
    [self.authButton setFrame:NSMakeRect(loginButtonX, loginY + 89.0, loginButtonWidth, 32.0)];

    [self.chatsLabel setFrame:NSMakeRect(mainX + 14.0, mainTop - 30.0, 88.0, 22.0)];
    [self.loadChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 144.0, mainTop - 36.0, 82.0, 30.0)];
    [self.loadMoreChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 56.0, mainTop - 36.0, 44.0, 30.0)];
    [self.chatScrollView setFrame:NSMakeRect(mainX + 1.0, mainY + 1.0, sidebarWidth - 2.0, mainHeight - 38.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"title"];
    if (chatColumn) {
        CGFloat chatWidth = sidebarWidth - 66.0;
        if (chatWidth < 132.0) {
            chatWidth = 132.0;
        }
        [chatColumn setWidth:chatWidth];
    }
    NSTableColumn *newColumn = [self.chatTableView tableColumnWithIdentifier:@"unread_count"];
    if (newColumn) {
        [newColumn setWidth:46.0];
    }

    [self.messagesLabel setFrame:NSMakeRect(conversationX + 14.0, mainTop - 30.0, 96.0, 22.0)];
    [self.loadMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 184.0, mainTop - 36.0, 90.0, 30.0)];
    [self.loadOlderMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 88.0, mainTop - 36.0, 76.0, 30.0)];
    [self.selectedChatField setFrame:NSMakeRect(conversationX + 112.0, mainTop - 30.0, conversationWidth - 310.0, 22.0)];

    CGFloat composerHeight = 42.0;
    CGFloat composerY = mainY + 12.0;
    CGFloat messageBottom = composerY + composerHeight + 10.0;
    CGFloat messageTop = mainTop - 42.0;
    CGFloat messageHeight = messageTop - messageBottom;
    if (messageHeight < 160.0) {
        messageHeight = 160.0;
    }
    [self.messageScrollView setFrame:NSMakeRect(conversationX + 1.0, messageBottom, conversationWidth - 2.0, messageHeight)];
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (bubbleColumn) {
        CGFloat bubbleWidth = conversationWidth - 2.0;
        if (bubbleWidth < 260.0) {
            bubbleWidth = 260.0;
        }
        [bubbleColumn setWidth:bubbleWidth];
    }

    CGFloat sendButtonWidth = (conversationWidth < 470.0) ? 78.0 : 88.0;
    CGFloat sendFieldX = conversationX + 62.0;
    CGFloat sendButtonX = conversationX + conversationWidth - sendButtonWidth - 12.0;
    CGFloat sendFieldWidth = sendButtonX - sendFieldX - 10.0;
    if (sendFieldWidth < 160.0) {
        sendFieldWidth = 160.0;
    }
    [self.sendLabel setFrame:NSMakeRect(conversationX + 14.0, composerY + 8.0, 46.0, 22.0)];
    [self.sendTextField setFrame:NSMakeRect(sendFieldX, composerY + 6.0, sendFieldWidth, 26.0)];
    [self.sendMessageButton setFrame:NSMakeRect(sendButtonX, composerY + 3.0, sendButtonWidth, 30.0)];

    CGFloat panelTitleY = mainTop - 30.0;
    [self.profileTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];
    [self.profileNameField setFrame:NSMakeRect(mainX + 48.0, mainTop - 96.0, mainWidth - 96.0, 24.0)];
    [self.profileUsernameField setFrame:NSMakeRect(mainX + 48.0, mainTop - 132.0, mainWidth - 96.0, 24.0)];
    [self.profileIDField setFrame:NSMakeRect(mainX + 48.0, mainTop - 168.0, mainWidth - 96.0, 24.0)];
    [self.profileStateField setFrame:NSMakeRect(mainX + 48.0, mainTop - 226.0, mainWidth - 96.0, 46.0)];

    [self.settingsTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];
    [self.settingsStateField setFrame:NSMakeRect(mainX + 48.0, mainTop - 96.0, mainWidth - 96.0, 24.0)];
    [self.settingsLibraryField setFrame:NSMakeRect(mainX + 48.0, mainTop - 132.0, mainWidth - 96.0, 24.0)];
    [self.settingsStorageField setFrame:NSMakeRect(mainX + 48.0, mainTop - 190.0, mainWidth - 96.0, 46.0)];

    CGFloat aboutIconSize = 118.0;
    CGFloat aboutCenterX = mainX + (mainWidth / 2.0);
    [self.aboutIconView setFrame:NSMakeRect(aboutCenterX - (aboutIconSize / 2.0), mainTop - 174.0, aboutIconSize, aboutIconSize)];
    [self.aboutTitleField setFrame:NSMakeRect(mainX + 90.0, mainTop - 220.0, mainWidth - 180.0, 30.0)];
    [self.aboutVersionField setFrame:NSMakeRect(mainX + 90.0, mainTop - 252.0, mainWidth - 180.0, 22.0)];
    [self.aboutCopyrightField setFrame:NSMakeRect(mainX + 90.0, mainTop - 286.0, mainWidth - 180.0, 22.0)];
    [self.aboutLinkField setFrame:NSMakeRect(mainX + 90.0, mainTop - 320.0, mainWidth - 180.0, 22.0)];

    [self.diagnosticsLabel setFrame:NSMakeRect(mainX + 14.0, mainTop - 30.0, 120.0, 18.0)];
    [self.checkButton setFrame:NSMakeRect(mainX + mainWidth - 132.0, mainTop - 36.0, 116.0, 30.0)];
    [self.detailsScrollView setFrame:NSMakeRect(mainX + 12.0, mainY + 12.0, mainWidth - 24.0, mainHeight - 56.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
    (void)notification;
    [self layoutContentView];
    [self.messageTableView reloadData];
    [self updateVisibleSection];
}

- (void)startLiveUpdateTimerIfNeeded {
    if (self.liveUpdateTimer) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(pollLiveUpdates:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.liveUpdateTimer = timer;
}

- (void)stopLiveUpdateTimer {
    if (!self.liveUpdateTimer) {
        return;
    }

    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)prepareForApplicationTermination {
    [self stopLiveUpdateTimer];
    [self setControlsBusy:YES];
    [self.client shutdownWithTimeout:3.0];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (void)updateSendControls {
    BOOL canTargetChat = [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil;
    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.sendTextField setEnabled:canTargetChat];
    [self.sendMessageButton setEnabled:(canTargetChat && [trimmedText length] > 0 && [text length] <= 4096)];
}

- (BOOL)canLoadMoreChats {
    return (!self.controlsBusy &&
            [self.currentAuthState isEqualToString:@"ready"] &&
            [self.chatItems count] > 0 &&
            !self.chatsExhausted &&
            [self.chatItems count] < TGStatusChatPreviewMaximumLimit);
}

- (void)updateAuthControlsForState:(NSString *)state {
    NSString *previousState = [self.currentAuthState copy];
    self.currentAuthState = state;
    [self.authTextField setStringValue:@""];
    [self.authSecureField setStringValue:@""];
    [self.loadChatsButton setEnabled:NO];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.sendMessageButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.autoChatListLoadArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self.selectedChatField setStringValue:@"Select a chat"];
        [self.sendTextField setStringValue:@""];
        self.activeSection = TGSectionChats;
    }

    if (![state isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        self.chatsExhausted = NO;
        self.profileSummaryLoaded = NO;
        [self.client invalidateMainChatListExhaustion];
        self.pendingLiveChatRefresh = NO;
        self.pendingLiveMessageRefresh = NO;
    } else if (![previousState isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        if ([self.chatItems count] == 0) {
            self.pendingLiveChatRefresh = YES;
            [self handlePendingLiveRefreshesIfPossible];
        }
    }

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.statusField setStringValue:@"Sign in required"];
        [self.loginTitleField setStringValue:@"Sign in to Telegram"];
        [self.loginHintField setStringValue:@"Enter the phone number connected to your Telegram account."];
        [self.authLabel setStringValue:@"Phone number"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Continue"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.statusField setStringValue:@"Login code required"];
        [self.loginTitleField setStringValue:@"Enter login code"];
        [self.loginHintField setStringValue:@"Telegram sent a login code to your account. Enter it here to continue."];
        [self.authLabel setStringValue:@"Login code"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Verify"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.statusField setStringValue:@"Password required"];
        [self.loginTitleField setStringValue:@"Two-step password"];
        [self.loginHintField setStringValue:@"Enter your Telegram cloud password. It is sent only to TDLib and is not logged."];
        [self.authLabel setStringValue:@"Password:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Unlock"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    [self.authLabel setStringValue:@"Status"];
    if ([state isEqualToString:@"ready"]) {
        [self.statusField setStringValue:@"Connected"];
        [self.authStateField setStringValue:@"ready"];
    } else if ([state length] > 0) {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:state];
    } else {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@"Preparing connection..."];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [self.authButton setTitle:@"Send"];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.loadOlderMessagesButton setEnabled:([state isEqualToString:@"ready"] && self.selectedChatID != nil && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self updateSendControls];
    [self.settingsStateField setStringValue:[NSString stringWithFormat:@"Session: %@", [state isEqualToString:@"ready"] ? @"signed in" : (([state length] > 0) ? state : @"connecting")]];
    NSString *loadedLibrary = [self.client loadedLibraryPath];
    [self.settingsLibraryField setStringValue:[NSString stringWithFormat:@"Engine: %@", ([loadedLibrary length] > 0) ? loadedLibrary : @"not loaded"]];
    [self updateVisibleSection];
    if ([state isEqualToString:@"ready"] && !self.profileSummaryLoaded && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }

    [previousState release];
}

- (void)setControlsBusy:(BOOL)busy {
    _controlsBusy = busy;
    [self.checkButton setEnabled:!busy];
    [self updateNavigationButtonsForSection:(self.activeSection ? self.activeSection : TGSectionChats) enabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMoreChatsButton setEnabled:[self canLoadMoreChats]];
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.loadOlderMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil && [self.messageItems count] > 0 && !self.olderMessagesExhausted)];
    [self.sendTextField setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID != nil)];
    [self.sendMessageButton setEnabled:NO];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMoreChatsButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
        [self.loadOlderMessagesButton setEnabled:NO];
        [self.chatTableView setEnabled:NO];
        [self.messageTableView setEnabled:NO];
        [self.sendTextField setEnabled:NO];
        [self.sendMessageButton setEnabled:NO];
    } else {
        [self.chatTableView setEnabled:YES];
        [self.messageTableView setEnabled:YES];
        [self updateAuthControlsForState:self.currentAuthState];
        [self handlePendingLiveRefreshesIfPossible];
    }
    [self updateVisibleSection];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.sendTextField) {
        [self updateSendControls];
    }
}

- (void)appendDetail:(NSString *)detail {
    NSString *current = [self.detailsView string];
    NSString *line = [detail stringByAppendingString:@"\n"];
    [self.detailsView setString:[current stringByAppendingString:line]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.messageTableView) {
        return (NSInteger)[self.messageItems count];
    }
    return (NSInteger)[self.chatItems count];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != self.messageTableView) {
        return [tableView rowHeight];
    }
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return [tableView rowHeight];
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return [tableView rowHeight];
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    CGFloat availableWidth = bubbleColumn ? [bubbleColumn width] : NSWidth([self.messageScrollView frame]);
    return TGMessageBubbleHeightForItem((TGMessageItem *)item, availableWidth);
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    id identifier = [tableColumn identifier];
    if (tableView == self.messageTableView && [identifier isEqual:@"bubble"] && [cell isKindOfClass:[TGMessageBubbleCell class]]) {
        TGMessageItem *messageItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.messageItems count]) {
            id item = [self.messageItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGMessageItem class]]) {
                messageItem = (TGMessageItem *)item;
            }
        }
        [(TGMessageBubbleCell *)cell setMessageItem:messageItem];
        return;
    }
    [textCell setAlignment:NSLeftTextAlignment];
    [textCell setFont:[NSFont systemFontOfSize:12.0]];
    [textCell setTextColor:TGClassicInkColor()];
    [textCell setDrawsBackground:NO];
    [textCell setLineBreakMode:NSLineBreakByTruncatingTail];

    if (tableView == self.chatTableView) {
        BOOL selected = [tableView isRowSelected:row];
        if (selected) {
            [textCell setDrawsBackground:YES];
            [textCell setBackgroundColor:[NSColor colorWithCalibratedRed:0.72 green:0.55 blue:0.29 alpha:1.0]];
            [textCell setTextColor:[NSColor colorWithCalibratedRed:0.12 green:0.07 blue:0.035 alpha:1.0]];
        }
        if ([identifier isEqual:@"title"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:12.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicInkColor()];
            }
        } else if ([identifier isEqual:@"unread_count"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:[NSColor colorWithCalibratedRed:0.52 green:0.32 blue:0.10 alpha:1.0]];
            }
            [textCell setAlignment:NSCenterTextAlignment];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicMutedInkColor()];
            }
        }
    } else if (tableView == self.messageTableView) {
        if ([identifier isEqual:@"date"] || [identifier isEqual:@"direction"]) {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            [textCell setTextColor:TGClassicMutedInkColor()];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:12.0]];
            [textCell setTextColor:TGClassicInkColor()];
        }
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    id item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = nil;
    if (tableView == self.messageTableView && [item isKindOfClass:[TGMessageItem class]]) {
        if ([identifier isEqual:@"bubble"]) {
            value = [(TGMessageItem *)item preview];
        } else {
            value = [(TGMessageItem *)item valueForTableColumnIdentifier:identifier];
        }
    } else if (tableView == self.chatTableView && [item isKindOfClass:[TGChatItem class]]) {
        value = [(TGChatItem *)item valueForTableColumnIdentifier:identifier];
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"date"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger timestamp = [value integerValue];
        if (timestamp <= 0) {
            return @"";
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
        return [NSDateFormatter localizedStringFromDate:date
                                              dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
    }
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger unreadCount = [value integerValue];
        if (unreadCount <= 0) {
            return @"";
        }
        if (unreadCount > 999) {
            return @"999+";
        }
        return [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }
    return value ? value : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] != self.chatTableView) {
        return;
    }

    NSNumber *previousChatID = [self.selectedChatID retain];
    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        [self.selectedChatField setStringValue:@"Select a chat"];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateAuthControlsForState:self.currentAuthState];
        [previousChatID release];
        return;
    }

    TGChatItem *item = [self.chatItems objectAtIndex:(NSUInteger)row];
    id chatID = [item chatID];
    id title = [item title];
    NSNumber *newChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        newChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        self.selectedChatID = newChatID;
    } else {
        self.selectedChatID = nil;
    }
    BOOL selectionChanged = !((previousChatID && newChatID) && ([previousChatID longLongValue] == [newChatID longLongValue]));
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"Selected chat";
    [self.selectedChatField setStringValue:self.selectedChatTitle ? self.selectedChatTitle : @"Selected chat"];
    if (selectionChanged) {
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self.sendTextField setStringValue:@""];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
    }
    [self updateAuthControlsForState:self.currentAuthState];
    if (newChatID && (selectionChanged || [self.messageItems count] == 0)) {
        [self reloadMessagesForChatID:newChatID interactive:NO];
    }
    [previousChatID release];
}

- (void)applyChatItems:(NSArray *)items preserveSelection:(BOOL)preserveSelection preferredChatID:(NSNumber *)preferredChatID {
    NSUInteger selectedIndex = NSNotFound;

    if (preserveSelection && preferredChatID) {
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            TGChatItem *item = [items objectAtIndex:index];
            id chatID = [item chatID];
            if ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [preferredChatID longLongValue]) {
                selectedIndex = index;
                break;
            }
        }
    }

    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:items];
    [self.chatTableView reloadData];
    self.autoChatListLoadArmed = YES;

    if (selectedIndex != NSNotFound) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:selectedIndex];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        return;
    }

    if ([items count] > 0 && [self.currentAuthState isEqualToString:@"ready"]) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:0];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:0];
        return;
    }

    [self.chatTableView deselectAll:nil];
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    [self.selectedChatField setStringValue:@"Select a chat"];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self.sendTextField setStringValue:@""];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self updateAuthControlsForState:self.currentAuthState];
}

- (NSNumber *)oldestLoadedMessageID {
    long long minimumMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            long long value = [messageID longLongValue];
            if (minimumMessageID == 0 || value < minimumMessageID) {
                minimumMessageID = value;
            }
        }
    }
    if (minimumMessageID > 0) {
        return [NSNumber numberWithLongLong:minimumMessageID];
    }
    return nil;
}

- (NSArray *)messageItemsInDisplayOrderFromItems:(NSArray *)items {
    return [items sortedArrayUsingFunction:TGCompareMessageItemsAscending context:NULL];
}

- (void)scrollMessagesToNewestIfAvailable {
    NSUInteger count = [self.messageItems count];
    if (count > 0) {
        [self.messageTableView scrollRowToVisible:(count - 1)];
    }
}

- (void)applyRecentMessageItems:(NSArray *)items preservingOlderItems:(BOOL)preserveOlder {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    BOOL forceScrollToNewest = self.forceMessageScrollToNewest;
    self.forceMessageScrollToNewest = NO;
    if (!preserveOlder || [self.messageItems count] == 0) {
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:orderedItems];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self.messageTableView reloadData];
        [self scrollMessagesToNewestIfAvailable];
        return;
    }

    BOOL shouldScrollToNewest = forceScrollToNewest || [self isMessageHistoryNearBottom];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:self.messageItems];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [mergedItems addObject:item];
    }

    [self.messageItems removeAllObjects];
    [self.messageItems addObjectsFromArray:[self messageItemsInDisplayOrderFromItems:mergedItems]];
    [self.messageTableView reloadData];
    if (shouldScrollToNewest) {
        [self scrollMessagesToNewestIfAvailable];
    }
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items preservingVisiblePosition:(BOOL)preserveVisiblePosition {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSInteger firstVisibleRow = 0;
    if (preserveVisiblePosition) {
        NSPoint visibleOrigin = [[self.messageScrollView contentView] bounds].origin;
        firstVisibleRow = [self.messageTableView rowAtPoint:visibleOrigin];
        if (firstVisibleRow < 0) {
            firstVisibleRow = 0;
        }
    }
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *existingItem = [self.messageItems objectAtIndex:index];
        id messageID = [existingItem messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    NSMutableArray *itemsToPrepend = [NSMutableArray array];
    NSUInteger added = 0;
    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [itemsToPrepend addObject:item];
        added++;
    }

    if (added > 0) {
        NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:itemsToPrepend];
        [mergedItems addObjectsFromArray:self.messageItems];
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:mergedItems];
    }

    [self.messageTableView reloadData];
    if (added > 0) {
        if (preserveVisiblePosition) {
            NSUInteger targetRow = (NSUInteger)firstVisibleRow + added;
            if (targetRow >= [self.messageItems count]) {
                targetRow = [self.messageItems count] - 1;
            }
            [self.messageTableView scrollRowToVisible:targetRow];
        } else {
            [self scrollMessagesToNewestIfAvailable];
        }
    }
    return added;
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items {
    return [self appendOlderMessageItems:items preservingVisiblePosition:YES];
}

- (BOOL)isChatListNearBottom {
    if ([self.chatItems count] == 0 || self.chatsExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (void)chatScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.chatScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        self.controlsBusy ||
        self.backgroundChatRefreshInFlight ||
        self.chatsExhausted ||
        [self.chatItems count] == 0) {
        return;
    }

    if (![self isChatListNearBottom]) {
        self.autoChatListLoadArmed = YES;
        return;
    }

    if (!self.autoChatListLoadArmed) {
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }

    if (nextLimit <= self.chatPreviewLimit) {
        self.autoChatListLoadArmed = NO;
        return;
    }

    self.autoChatListLoadArmed = NO;
    [self reloadChatsInteractive:NO preserveSelection:YES requestedLimit:nextLimit];
}

- (BOOL)isMessageHistoryNearBottom {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isMessageHistoryScrollable {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.messageTableView rowHeight] + [self.messageTableView intercellSpacing].height) * (CGFloat)[self.messageItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)messageHistoryNeedsPrefill {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }
    return ([self.messageItems count] < TGMessagePrefillMinimumRows || ![self isMessageHistoryScrollable]);
}

- (BOOL)isMessageHistoryNearTop {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    if (![self isMessageHistoryScrollable]) {
        return NO;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 48.0);
}

- (void)messageScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.messageScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        self.olderMessagesExhausted ||
        [self.messageItems count] == 0) {
        return;
    }

    if (![self isMessageHistoryNearTop]) {
        self.autoOlderMessagesLoadArmed = YES;
        return;
    }

    if (!self.autoOlderMessagesLoadArmed) {
        return;
    }

    self.autoOlderMessagesLoadArmed = NO;
    [self reloadOlderMessagesInteractive];
}

- (void)prefillOlderMessagesIfNeededWithAttemptsRemaining:(NSUInteger)attemptsRemaining {
    if (attemptsRemaining == 0 ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        ![self messageHistoryNeedsPrefill]) {
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    self.backgroundMessageRefreshInFlight = YES;

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        BOOL hadMessageError = (messageError != nil);
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            NSUInteger added = 0;
            if (selectionStillCurrent && itemsCopy) {
                added = [self appendOlderMessageItems:itemsCopy preservingVisiblePosition:NO];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: prefilled %lu older previews", (unsigned long)added]];
                }
            } else if (selectionStillCurrent && hadMessageError) {
                self.autoOlderMessagesLoadArmed = YES;
            }

            self.backgroundMessageRefreshInFlight = NO;
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            } else {
                [self updateAuthControlsForState:self.currentAuthState];
            }

            if (selectionStillCurrent &&
                added > 0 &&
                attemptsRemaining > 1 &&
                [self messageHistoryNeedsPrefill]) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:(attemptsRemaining - 1)];
            } else {
                [self handlePendingLiveRefreshesIfPossible];
            }

            [itemsCopy release];
            [authorizationState release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection {
    [self reloadChatsInteractive:interactive preserveSelection:preserveSelection requestedLimit:self.chatPreviewLimit];
}

- (void)reloadProfileSummaryIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy) {
        return;
    }

    [self.profileStateField setStringValue:@"Loading profile from Telegram..."];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *profileError = nil;
        NSDictionary *profile = [[client currentUserProfileSummaryWithTimeout:6.0 error:&profileError] retain];
        NSString *profileErrorMessage = [[profileError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (profile) {
                NSString *displayName = [profile objectForKey:@"display_name"];
                NSString *username = [profile objectForKey:@"username"];
                id userID = [profile objectForKey:@"id"];
                [self.profileNameField setStringValue:[NSString stringWithFormat:@"Name: %@", ([displayName length] > 0) ? displayName : @"Telegram account"]];
                if ([username length] > 0) {
                    [self.profileUsernameField setStringValue:[NSString stringWithFormat:@"Username: @%@", username]];
                } else {
                    [self.profileUsernameField setStringValue:@"Username: not set"];
                }
                if ([userID respondsToSelector:@selector(longLongValue)]) {
                    [self.profileIDField setStringValue:[NSString stringWithFormat:@"Telegram ID: %lld", [userID longLongValue]]];
                } else {
                    [self.profileIDField setStringValue:@"Telegram ID: not available"];
                }
                [self.profileStateField setStringValue:@"Profile loaded locally from Telegram. Phone number and raw profile JSON are not written to logs."];
                self.profileSummaryLoaded = YES;
            } else {
                [self.profileStateField setStringValue:@"Profile is unavailable right now. Chats and messages can still work."];
                if (profileErrorMessage) {
                    [self appendDetail:[NSString stringWithFormat:@"Profile: %@", profileErrorMessage]];
                }
            }
            [profile release];
            [profileErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection requestedLimit:(NSUInteger)requestedLimit {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        if (interactive) {
            [self appendDetail:@"Chats are available only after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = YES;
        return;
    }

    NSNumber *preferredChatID = preserveSelection ? [self.selectedChatID retain] : nil;
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading chats..."];
        [self appendDetail:@"Loading main chat previews from TDLib..."];
    } else {
        self.backgroundChatRefreshInFlight = YES;
    }

    if (requestedLimit == 0) {
        requestedLimit = TGStatusChatPreviewInitialLimit;
    } else if (requestedLimit > TGStatusChatPreviewMaximumLimit) {
        requestedLimit = TGStatusChatPreviewMaximumLimit;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSArray *items = [client mainChatPreviewItemsWithLimit:requestedLimit timeout:10.0 error:&chatError];
        BOOL chatsExhausted = [client mainChatListExhausted];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (itemsCopy) {
                self.chatPreviewLimit = [itemsCopy count];
                self.chatsExhausted = chatsExhausted;
                [self applyChatItems:itemsCopy preserveSelection:preserveSelection preferredChatID:preferredChatID];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu chat previews (limit %lu)", (unsigned long)[itemsCopy count], (unsigned long)requestedLimit]];
                    if (self.chatsExhausted) {
                        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
                    }
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = chatErrorMessage ? @"Chat preview request failed. Check connection state and try again." : @"Chat list did not return a result.";
                    [self.statusField setStringValue:@"Chats unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: chat preview refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundChatRefreshInFlight = NO;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
            [preferredChatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadMessagesForChatID:(NSNumber *)chatID interactive:(BOOL)interactive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !chatID) {
        if (interactive) {
            [self appendDetail:@"Select a chat after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading messages..."];
        [self appendDetail:@"Loading recent message previews from TDLib..."];
    } else {
        self.backgroundMessageRefreshInFlight = YES;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatIDCopy limit:TGMessagePreviewInitialLimit timeout:8.0 error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            if (!selectionStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
                }
            } else if (itemsCopy) {
                BOOL preserveOlder = (!interactive && [self.messageItems count] > 0);
                [self applyRecentMessageItems:itemsCopy preservingOlderItems:preserveOlder];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                if (interactive) {
                    NSString *message = messageErrorMessage ? @"Message preview request failed. Check connection state and try again." : @"Message history did not return a result.";
                    [self.statusField setStringValue:@"Messages unavailable"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                } else {
                    [self appendDetail:@"TDLib live refresh: selected chat refresh failed."];
                }
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            BOOL shouldPrefillOlderMessages = (selectionStillCurrent && itemsCopy && [self messageHistoryNeedsPrefill]);
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundMessageRefreshInFlight = NO;
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (shouldPrefillOlderMessages) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:TGMessagePrefillMaxAttempts];
            } else if (!interactive) {
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [chatIDCopy release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadOlderMessagesInteractive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after sign-in is ready."];
        return;
    }

    if (self.backgroundMessageRefreshInFlight) {
        [self appendDetail:@"TDLib messages: wait for the current message load to finish."];
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [self appendDetail:@"TDLib messages: load recent messages before requesting older history."];
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Loading older messages..."];
    [self appendDetail:@"Loading older message previews from TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale older-history result for previous chat selection."];
            } else if (itemsCopy) {
                NSUInteger added = [self appendOlderMessageItems:itemsCopy];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added == 0) {
                    self.autoOlderMessagesLoadArmed = NO;
                }
                [self.statusField setStringValue:(added > 0) ? @"Connected" : @"No older messages"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: appended %lu older previews", (unsigned long)added]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib older message previews appended: %lu", (unsigned long)added]];
            } else {
                [self.statusField setStringValue:@"Older messages unavailable"];
                NSString *message = messageErrorMessage ? messageErrorMessage : @"Older message history did not return a result.";
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib older message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [self handlePendingLiveRefreshesIfPossible];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)handlePendingLiveRefreshesIfPossible {
    if (self.controlsBusy || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    if (self.pendingLiveMessageRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && self.selectedChatID) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.pendingLiveMessageRefresh = NO;
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }

    if (self.pendingLiveChatRefresh && !self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = NO;
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)pollLiveUpdates:(NSTimer *)timer {
    (void)timer;
    if (!self.client) {
        return;
    }

    NSArray *updates = [self.client drainSafeUpdateSummaries];
    if ([updates count] == 0) {
        return;
    }

    NSNumber *selectedChatID = [self.selectedChatID retain];
    NSString *latestAuthorizationState = nil;
    BOOL needsChatRefresh = NO;
    BOOL needsMessageRefresh = NO;

    NSUInteger index = 0;
    for (index = 0; index < [updates count]; index++) {
        NSDictionary *summary = [updates objectAtIndex:index];
        if (![summary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *kind = [summary objectForKey:@"kind"];
        if ([kind isEqualToString:@"authorization"]) {
            NSString *state = [summary objectForKey:@"state"];
            if ([state length] > 0) {
                latestAuthorizationState = state;
            }
            continue;
        }

        if ([kind isEqualToString:@"new_message"] || [kind isEqualToString:@"chat_update"]) {
            needsChatRefresh = YES;
            self.chatsExhausted = NO;
            [self.client invalidateMainChatListExhaustion];
            id chatID = [summary objectForKey:@"chat_id"];
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsMessageRefresh = YES;
            }
        }
    }

    if ([latestAuthorizationState length] > 0 && ![latestAuthorizationState isEqualToString:self.currentAuthState]) {
        [self updateAuthControlsForState:latestAuthorizationState];
    }

    if (needsChatRefresh) {
        self.pendingLiveChatRefresh = YES;
    }
    if (needsMessageRefresh) {
        self.pendingLiveMessageRefresh = YES;
    }

    [selectedChatID release];
    [self handlePendingLiveRefreshesIfPossible];
}

- (void)connectOnLaunch:(id)sender {
    (void)sender;
    if (self.initialConnectStarted) {
        return;
    }
    self.initialConnectStarted = YES;
    [self checkTDLib:nil];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Connecting..."];
    [self appendDetail:@"Connecting to Telegram core..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *parametersError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:&parametersError];
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];
        NSString *receiverSummary = [[client receiverStatusSummary] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (probeSummary) {
                [self.statusField setStringValue:[finalAuthorizationState isEqualToString:@"ready"] ? @"Connected" : @"Login required"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (receiverSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib receiver: %@", receiverSummary]];
                }
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", [parametersError localizedDescription]]];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
                [self setControlsBusy:NO];
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self setControlsBusy:NO];
                [self.statusField setStringValue:@"Connection unavailable"];
                [self.authStateField setStringValue:@"Connection unavailable. Check local build files and try again."];
                [self updateVisibleSection];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
        });

        [client release];
        [receiverSummary release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Login input is not available for the current connection state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    NSString *input = [[inputField stringValue] copy];
    [inputField setStringValue:@""];
    if ([input length] == 0) {
        [input release];
        [state release];
        [self appendDetail:@"Login input is empty."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Signing in..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (authSummary) {
                [self.statusField setStringValue:@"Sign-in step submitted"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"Sign-in needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
            } else {
                [self updateAuthControlsForState:state];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    [self reloadChatsInteractive:YES preserveSelection:YES];
}

- (void)loadMoreChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    if (self.chatsExhausted) {
        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }
    if (nextLimit == self.chatPreviewLimit) {
        [self appendDetail:@"TDLib chats: maximum preview limit reached for this build."];
        return;
    }
    [self reloadChatsInteractive:YES preserveSelection:YES requestedLimit:nextLimit];
}

- (void)loadMessages:(id)sender {
    (void)sender;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self reloadMessagesForChatID:self.selectedChatID interactive:YES];
}

- (void)loadOlderMessages:(id)sender {
    (void)sender;
    [self reloadOlderMessagesInteractive];
}

- (void)sendMessage:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after sign-in is ready before sending."];
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] == 0) {
        [self appendDetail:@"Message text is empty."];
        [self updateSendControls];
        return;
    }
    if ([text length] > 4096) {
        [self appendDetail:@"Message text is too long for this spike."];
        [self updateSendControls];
        return;
    }

    NSString *chatTitle = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Selected chat";
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Send real Telegram message?"];
    [alert setInformativeText:[NSString stringWithFormat:@"This will send the current text field contents to \"%@\". This is not a dry run.", chatTitle]];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Send"];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSString *messageText = [text copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending..."];
    [self appendDetail:@"Submitting text message to TDLib..."];
    [[TGLogger sharedLogger] log:@"TDLib text message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSString *sendSummary = [client sendTextMessageToChatID:chatID text:messageText timeout:8.0 error:&sendError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        BOOL sendSucceeded = ([sendSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]);
            if (sendSucceeded) {
                [self.statusField setStringValue:@"Message sent"];
                [self appendDetail:@"TDLib send: text message accepted by TDLib."];
                [[TGLogger sharedLogger] log:@"TDLib text message send accepted."];
                if (selectionStillCurrent) {
                    [self.sendTextField setStringValue:@""];
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                [self.statusField setStringValue:@"Send not confirmed"];
                [self appendDetail:@"TDLib send: text message was not confirmed. Do not retry automatically; it may or may not have been sent."];
                [[TGLogger sharedLogger] log:@"TDLib text message send not confirmed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (sendSucceeded && selectionStillCurrent) {
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [authorizationState release];
            [chatID release];
            [messageText release];
        });

        [client release];
        [pool drain];
    });
}

- (void)dealloc {
    [self stopLiveUpdateTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_messageTableView setDataSource:nil];
    [_messageTableView setDelegate:nil];
    [_sendTextField setDelegate:nil];
    [_topPanelView release];
    [_sidebarPanelView release];
    [_conversationPanelView release];
    [_diagnosticsPanelView release];
    [_loginPanelView release];
    [_profilePanelView release];
    [_settingsPanelView release];
    [_aboutPanelView release];
    [_navigationButtons release];
    [_diagnosticsLabel release];
    [_titleField release];
    [_statusField release];
    [_detailsScrollView release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_loadMoreChatsButton release];
    [_loadMessagesButton release];
    [_loadOlderMessagesButton release];
    [_quitButton release];
    [_sendLabel release];
    [_sendTextField release];
    [_sendMessageButton release];
    [_authLabel release];
    [_authStateField release];
    [_loginTitleField release];
    [_loginHintField release];
    [_authTextField release];
    [_authSecureField release];
    [_authButton release];
    [_chatsLabel release];
    [_messagesLabel release];
    [_selectedChatField release];
    [_chatScrollView release];
    [_chatTableView release];
    [_chatItems release];
    [_messageScrollView release];
    [_messageTableView release];
    [_messageItems release];
    [_profileTitleField release];
    [_profileNameField release];
    [_profileUsernameField release];
    [_profileIDField release];
    [_profileStateField release];
    [_settingsTitleField release];
    [_settingsStateField release];
    [_settingsLibraryField release];
    [_settingsStorageField release];
    [_aboutIconView release];
    [_aboutTitleField release];
    [_aboutVersionField release];
    [_aboutCopyrightField release];
    [_aboutLinkField release];
    [_selectedChatID release];
    [_selectedChatTitle release];
    [_client release];
    [_currentAuthState release];
    [_activeSection release];
    [_liveUpdateTimer release];
    [super dealloc];
}

@end
