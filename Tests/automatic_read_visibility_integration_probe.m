#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import "../Sources/UI/TGConversationVisibility.h"

static void Check(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Automatic read integration failure: %s\n", message); exit(1); }
}
static void Pump(NSTimeInterval duration) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:duration];
    while ([end timeIntervalSinceNow] > 0) {
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
}

@interface ReadProbeApplication : NSObject
@property (nonatomic, assign, getter=isActive) BOOL active;
@end
@implementation ReadProbeApplication
@synthesize active = _active;
@end
static ReadProbeApplication *ProbeApplication;
static NSMutableArray *ProbeControllers;

@interface ReadProbeWindow : NSObject
@property (nonatomic, assign, getter=isVisible) BOOL visible;
@property (nonatomic, assign, getter=isKeyWindow) BOOL keyWindow;
@property (nonatomic, assign, getter=isMiniaturized) BOOL miniaturized;
@property (nonatomic, retain) NSView *contentView;
@end
@implementation ReadProbeWindow
@synthesize visible = _visible, keyWindow = _keyWindow, miniaturized = _miniaturized, contentView = _contentView;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [super methodSignatureForSelector:selector] ?: [NSWindow instanceMethodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    NSUInteger length = [[invocation methodSignature] methodReturnLength];
    if (length) { void *bytes = calloc(1, length); [invocation setReturnValue:bytes]; free(bytes); }
}
- (void)dealloc { [_contentView release]; [super dealloc]; }
@end
@interface ReadProbeTranscript : NSView
@property (nonatomic, assign) ReadProbeWindow *probeWindow;
@property (nonatomic, retain) NSClipView *contentView;
@end
@implementation ReadProbeTranscript
@synthesize probeWindow = _probeWindow, contentView = _contentView;
- (NSWindow *)window { return (NSWindow *)_probeWindow; }
- (void)dealloc { [_contentView release]; [super dealloc]; }
@end
@interface ReadProbeTable : NSObject
@property (nonatomic, assign) NSRange visibleRows;
@end
@implementation ReadProbeTable
@synthesize visibleRows = _visibleRows;
- (NSRange)rowsInRect:(NSRect)rect { (void)rect; return _visibleRows; }
@end
@interface TGMessageItem : NSObject
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, assign) BOOL outgoing;
@end
@implementation TGMessageItem
@synthesize messageID = _messageID, chatID = _chatID, outgoing = _outgoing;
- (void)dealloc { [_messageID release]; [_chatID release]; [super dealloc]; }
@end

@interface TGTDLibClient : NSObject {
    NSMutableArray *_calls;
    NSNumber *_openedChat;
    BOOL _hold, _fail;
}
@property (nonatomic, assign) BOOL hold, fail;
- (void)setUserOpenedChatID:(NSNumber *)chatID;
- (NSNumber *)openedChat;
- (NSArray *)calls;
- (BOOL)markVisibleMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)threadID
                        messageTopicKind:(NSString *)topicKind messageIDs:(NSArray *)ids
                                 timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end
@implementation TGTDLibClient
- (id)init { if ((self = [super init])) _calls = [[NSMutableArray alloc] init]; return self; }
- (void)dealloc { [_calls release]; [_openedChat release]; [super dealloc]; }
- (BOOL)hold { @synchronized(self) { return _hold; } }
- (void)setHold:(BOOL)value { @synchronized(self) { _hold = value; } }
- (BOOL)fail { @synchronized(self) { return _fail; } }
- (void)setFail:(BOOL)value { @synchronized(self) { _fail = value; } }
- (void)setUserOpenedChatID:(NSNumber *)chatID {
    Check([NSThread isMainThread], "openChat visibility is synchronized on main thread");
    [_openedChat release]; _openedChat = [chatID retain];
}
- (NSNumber *)openedChat { return _openedChat; }
- (NSArray *)calls { @synchronized(self) { return [NSArray arrayWithArray:_calls]; } }
- (BOOL)markVisibleMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)threadID
                        messageTopicKind:(NSString *)topicKind messageIDs:(NSArray *)ids
                                 timeout:(NSTimeInterval)timeout error:(NSError **)error {
    Check(![NSThread isMainThread], "read RPC never blocks main thread");
    Check(timeout == 4.0, "automatic receipt retains bounded RPC timeout");
    NSDictionary *call = [NSDictionary dictionaryWithObjectsAndKeys:chatID, @"chat", ids, @"ids",
                          threadID ?: @0, @"thread", topicKind ?: @"", @"topic", nil];
    @synchronized(self) { [_calls addObject:call]; }
    while (self.hold) [NSThread sleepForTimeInterval:0.005];
    if (self.fail && error) *error = [NSError errorWithDomain:@"read-probe" code:1
        userInfo:[NSDictionary dictionaryWithObject:@"fixture failure" forKey:NSLocalizedDescriptionKey]];
    return !self.fail;
}
@end

static NSString * const TGSectionChats = @"chats";
@interface ReadProbeController : NSObject
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState, *activeSection, *selectedMessageTopicKind;
@property (nonatomic, retain) NSNumber *selectedChatID, *selectedMessageThreadID, *selectedChatLastReadInboxMessageID;
@property (nonatomic, retain) ReadProbeTranscript *messageScrollView;
@property (nonatomic, retain) ReadProbeTable *messageTableView;
@property (nonatomic, retain) NSArray *messageItems;
@property (nonatomic, retain) NSMutableSet *visibleReadReceiptMessageIDs;
@property (nonatomic, assign) BOOL chatNavigationClosed, mediaCenterVisible, initialUnreadPositionPending;
@property (nonatomic, assign) NSUInteger automaticReadGeneration, confirmedReads, dismissals;
@property (nonatomic, retain) ReadProbeWindow *hostWindow;
- (NSArray *)readReceiptMessageIDsFromItems:(NSArray *)items;
- (void)recordReadNotificationMessageIDs:(NSArray *)ids chatID:(NSNumber *)chatID;
- (void)dismissCurrentUnreadSeparator;
- (void)appendDetail:(NSString *)detail;
- (BOOL)conversationAllowsAutomaticRead;
- (void)invalidateAutomaticReadRequests;
- (void)synchronizeUserOpenedChat;
- (void)conversationVisibilityDidChange:(NSNotification *)notification;
- (void)scheduleVisibleMessageItemsRead;
- (NSArray *)visibleUnreadMessageItemsAwaitingReceipt;
- (void)markVisibleMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)threadID
                         messageTopicKind:(NSString *)topicKind items:(NSArray *)items;
@end
@implementation ReadProbeController
@synthesize client = _client, currentAuthState = _currentAuthState, activeSection = _activeSection;
@synthesize selectedMessageTopicKind = _selectedMessageTopicKind, selectedChatID = _selectedChatID;
@synthesize selectedMessageThreadID = _selectedMessageThreadID, selectedChatLastReadInboxMessageID = _selectedChatLastReadInboxMessageID;
@synthesize messageScrollView = _messageScrollView, messageTableView = _messageTableView, messageItems = _messageItems;
@synthesize visibleReadReceiptMessageIDs = _visibleReadReceiptMessageIDs, hostWindow = _hostWindow;
@synthesize chatNavigationClosed = _chatNavigationClosed, mediaCenterVisible = _mediaCenterVisible;
@synthesize initialUnreadPositionPending = _initialUnreadPositionPending, automaticReadGeneration = _automaticReadGeneration;
@synthesize confirmedReads = _confirmedReads, dismissals = _dismissals;
- (NSWindow *)window { return (NSWindow *)self.hostWindow; }
- (NSArray *)readReceiptMessageIDsFromItems:(NSArray *)items {
    NSMutableArray *ids = [NSMutableArray array];
    for (TGMessageItem *item in items) if (![item outgoing]) [ids addObject:[item messageID]];
    return ids;
}
- (void)recordReadNotificationMessageIDs:(NSArray *)ids chatID:(NSNumber *)chatID {
    (void)ids; (void)chatID; Check([NSThread isMainThread], "read evidence delivered on main thread"); self.confirmedReads++;
}
- (void)dismissCurrentUnreadSeparator { self.dismissals++; }
- (void)appendDetail:(NSString *)detail { (void)detail; }
#undef NSApp
#define NSApp ProbeApplication
#include "../Sources/UI/TGStatusWindowController+AutomaticReadVisibility.inc"
#undef NSApp
- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_client release]; [_currentAuthState release]; [_activeSection release]; [_selectedMessageTopicKind release];
    [_selectedChatID release]; [_selectedMessageThreadID release]; [_selectedChatLastReadInboxMessageID release];
    [_messageScrollView release]; [_messageTableView release]; [_messageItems release];
    [_visibleReadReceiptMessageIDs release]; [_hostWindow release]; [super dealloc];
}
@end

static TGMessageItem *Item(long long messageID, BOOL outgoing) {
    TGMessageItem *item = [[[TGMessageItem alloc] init] autorelease];
    item.messageID = [NSNumber numberWithLongLong:messageID]; item.chatID = @10; item.outgoing = outgoing; return item;
}
static ReadProbeController *Controller(void) {
    ReadProbeController *controller = [[[ReadProbeController alloc] init] autorelease];
    [ProbeControllers addObject:controller];
    controller.client = [[[TGTDLibClient alloc] init] autorelease]; controller.currentAuthState = @"ready";
    controller.activeSection = TGSectionChats; controller.selectedChatID = @10;
    controller.messageItems = [NSArray arrayWithObjects:Item(1, NO), Item(2, NO), Item(3, YES), Item(4, NO), nil];
    controller.selectedChatLastReadInboxMessageID = @1;
    controller.visibleReadReceiptMessageIDs = [NSMutableSet set];
    controller.hostWindow = [[[ReadProbeWindow alloc] init] autorelease];
    controller.hostWindow.visible = YES; controller.hostWindow.keyWindow = YES;
    controller.hostWindow.contentView = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,300,300)] autorelease];
    controller.messageScrollView = [[[ReadProbeTranscript alloc] initWithFrame:NSMakeRect(0,0,200,200)] autorelease];
    controller.messageScrollView.probeWindow = controller.hostWindow;
    controller.messageScrollView.contentView = [[[NSClipView alloc] initWithFrame:NSMakeRect(0,0,200,200)] autorelease];
    [controller.hostWindow.contentView addSubview:controller.messageScrollView];
    controller.messageTableView = [[[ReadProbeTable alloc] init] autorelease];
    controller.messageTableView.visibleRows = NSMakeRange(0,3); ProbeApplication.active = YES;
    return controller;
}
static void WaitCalls(TGTDLibClient *client, NSUInteger count) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while ([[client calls] count] < count && [deadline timeIntervalSinceNow] > 0) Pump(0.005);
    Check([[client calls] count] == count, "expected automatic receipt count"); Pump(0.03);
}
static void ExpectSuppressed(ReadProbeController *controller, const char *message) {
    [controller synchronizeUserOpenedChat];
    [controller scheduleVisibleMessageItemsRead]; Pump(0.08);
    Check([[controller.client calls] count] == 0 && [controller.client openedChat] == nil &&
          [controller.visibleReadReceiptMessageIDs count] == 0, message);
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    ProbeApplication = [[ReadProbeApplication alloc] init];
    ProbeControllers = [[NSMutableArray alloc] init];
    ReadProbeController *c = Controller(); ProbeApplication.active = NO;
    ExpectSuppressed(c, "background arrival cannot read selected conversation or openChat");
    c = Controller(); c.hostWindow.miniaturized = YES;
    ExpectSuppressed(c, "minimized window cannot read");
    c = Controller(); c.hostWindow.visible = NO;
    ExpectSuppressed(c, "closed/hidden window cannot read");
    c = Controller(); c.hostWindow.keyWindow = NO;
    ExpectSuppressed(c, "other key window cannot read conversation");
    c = Controller(); [c.hostWindow.contentView setHidden:YES];
    ExpectSuppressed(c, "hidden ancestor cannot read");
    c = Controller(); c.activeSection = @"settings";
    ExpectSuppressed(c, "settings section cannot read");
    c = Controller(); c.mediaCenterVisible = YES;
    ExpectSuppressed(c, "media center cannot read hidden transcript");
    c = Controller(); c.chatNavigationClosed = YES;
    ExpectSuppressed(c, "closed conversation cannot read");
    c = Controller(); c.currentAuthState = @"waitCode";
    ExpectSuppressed(c, "authentication cannot read");
    c = Controller(); c.initialUnreadPositionPending = YES;
    [c scheduleVisibleMessageItemsRead]; Pump(0.08);
    Check([[c.client calls] count] == 0, "initial unread scroll finishes before receipt");
    c = Controller(); c.selectedChatID = @11;
    [c scheduleVisibleMessageItemsRead]; Pump(0.08);
    Check([[c.client calls] count] == 0 && [c.visibleReadReceiptMessageIDs count] == 0,
          "pending selection cannot read old message array using new chat ID");

    c = Controller(); [c synchronizeUserOpenedChat]; [c scheduleVisibleMessageItemsRead]; WaitCalls(c.client,1);
    Check([[c.client openedChat] isEqual:@10] && [[[[c.client calls] objectAtIndex:0] objectForKey:@"ids"] isEqual:[NSArray arrayWithObject:@2]],
          "foreground reads only visible incoming IDs above server watermark");
    Check(c.confirmedReads == 0, "non-forced RPC OK is not synthetic authoritative notification-read evidence");
    [c scheduleVisibleMessageItemsRead]; Pump(0.05);
    Check([[c.client calls] count] == 1, "same visible message does not enqueue duplicate receipts");
    [c invalidateAutomaticReadRequests]; c.activeSection = @"settings"; Pump(1.3);
    Check(c.dismissals == 0, "navigation cancels delayed unread-separator dismissal from prior receipt");

    c = Controller(); [c scheduleVisibleMessageItemsRead]; [c invalidateAutomaticReadRequests]; Pump(0.1);
    Check([[c.client calls] count] == 0 && [c.visibleReadReceiptMessageIDs count] == 0,
          "generation cancellation defeats receipt queued before main-thread preflight");
    c = Controller(); [c markVisibleMessageItemsReadForChatID:@10 messageThreadID:nil messageTopicKind:nil items:c.messageItems];
    c.selectedChatID = @11; Pump(0.1);
    Check([[c.client calls] count] == 0, "delayed notification-open action never reads old chat after different selection");
    c = Controller(); c.selectedMessageThreadID = @100; c.selectedMessageTopicKind = @"forum";
    [c scheduleVisibleMessageItemsRead]; c.selectedMessageThreadID = @101; Pump(0.1);
    Check([[c.client calls] count] == 0, "queued old topic receipt is rejected after topic switch");
    c = Controller(); [c scheduleVisibleMessageItemsRead]; c.selectedMessageTopicKind = @"forum"; Pump(0.1);
    Check([[c.client calls] count] == 0, "queued topic-kind change is rejected");
    c = Controller(); TGTDLibClient *oldClient = [c.client retain]; [c scheduleVisibleMessageItemsRead];
    c.client = [[[TGTDLibClient alloc] init] autorelease]; Pump(0.1);
    Check([[oldClient calls] count] == 0 && [[c.client calls] count] == 0, "queued receipt cannot cross account/client switch"); [oldClient release];
    c = Controller(); [c scheduleVisibleMessageItemsRead];
    [c conversationVisibilityDidChange:[NSNotification notificationWithName:NSApplicationWillResignActiveNotification object:nil]];
    Pump(0.1); Check([[c.client calls] count] == 0 && [c.client openedChat] == nil,
          "will-resign cancels before app flag changes");
    c = Controller(); [c performSelector:@selector(scheduleVisibleMessageItemsRead) withObject:nil afterDelay:0.02];
    [c invalidateAutomaticReadRequests]; Pump(0.08);
    Check([[c.client calls] count] == 0, "navigation cancels scheduled receipt selector");
    c = Controller(); c.client.fail = YES; [c scheduleVisibleMessageItemsRead]; WaitCalls(c.client,1);
    Check(c.confirmedReads == 0 && [c.visibleReadReceiptMessageIDs count] == 0,
          "failed automatic receipt releases dedupe IDs without notification cleanup");
    c.client.fail = NO; [c scheduleVisibleMessageItemsRead]; WaitCalls(c.client,2);
    Check([[c.client calls] count] == 2 && c.confirmedReads == 0,
          "visible receipt can retry without inventing read evidence"); [NSObject cancelPreviousPerformRequestsWithTarget:c];

    c = Controller(); c.client.hold = YES; [c scheduleVisibleMessageItemsRead]; WaitCalls(c.client,1);
    [c invalidateAutomaticReadRequests]; c.activeSection = @"settings"; c.client.hold = NO; Pump(0.08);
    Check(c.confirmedReads == 0 && c.dismissals == 0,
          "late RPC OK cannot create notification evidence or dismiss separator in new context");
    c = Controller(); c.client.hold = YES; [c scheduleVisibleMessageItemsRead]; WaitCalls(c.client,1);
    oldClient = [c.client retain]; c.client = [[[TGTDLibClient alloc] init] autorelease];
    [c invalidateAutomaticReadRequests]; oldClient.hold = NO; Pump(0.08);
    Check(c.confirmedReads == 0, "old-account completion cannot clear new-account notifications"); [oldClient release];

    c = Controller(); c.hostWindow.miniaturized = YES; [c synchronizeUserOpenedChat];
    c.hostWindow.miniaturized = NO;
    [c conversationVisibilityDidChange:[NSNotification notificationWithName:NSWindowDidDeminiaturizeNotification object:nil]];
    WaitCalls(c.client,1);
    Check([[c.client openedChat] isEqual:@10], "visible foreground deminiaturization resumes automatic read");
    [NSObject cancelPreviousPerformRequestsWithTarget:c];
    Pump(0.05);
    for (ReadProbeController *controller in ProbeControllers) {
        [NSObject cancelPreviousPerformRequestsWithTarget:controller];
        controller.messageScrollView.probeWindow = nil;
    }
    [ProbeControllers release]; ProbeControllers = nil;
    [ProbeApplication release]; ProbeApplication = nil;
    puts("Automatic read visibility production integration probe passed."); [pool drain]; return 0;
}
