#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

static void Require(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Logout completion failure: %s\n", message); exit(1); }
}

@interface TGTDLibClient : NSObject @end
@implementation TGTDLibClient @end
@interface TGLogger : NSObject
+ (id)sharedLogger;
- (void)log:(NSString *)message;
@end
@implementation TGLogger
+ (id)sharedLogger { return [[[self alloc] init] autorelease]; }
- (void)log:(NSString *)message { (void)message; }
@end
@interface LogoutProbeStatus : NSObject
@property (nonatomic, copy) NSString *text;
- (void)setStringValue:(NSString *)value;
@end
@implementation LogoutProbeStatus
@synthesize text = _text;
- (void)dealloc { [_text release]; [super dealloc]; }
- (void)setStringValue:(NSString *)value { self.text = value; }
@end
@interface LogoutProbeTable : NSObject
- (void)deselectAll:(id)sender;
- (void)reloadData;
@end
@implementation LogoutProbeTable
- (void)deselectAll:(id)sender { (void)sender; }
- (void)reloadData {}
@end

#define OBJECT_PROPERTY(name) @property (nonatomic, retain) id name;
#define FLAG_PROPERTY(name) @property (nonatomic, assign) BOOL name;
@interface LogoutProbeController : NSObject
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) LogoutProbeStatus *statusField;
OBJECT_PROPERTY(chatItems) OBJECT_PROPERTY(messageItems) OBJECT_PROPERTY(composerDraftsByTargetKey)
OBJECT_PROPERTY(chatTableView) OBJECT_PROPERTY(messageTableView)
OBJECT_PROPERTY(selectedChatID) OBJECT_PROPERTY(selectedChatTitle) OBJECT_PROPERTY(selectedChatTypeSummary)
OBJECT_PROPERTY(selectedChatAvatarLocalPath) OBJECT_PROPERTY(selectedChatLastReadOutboxMessageID)
OBJECT_PROPERTY(selectedMessageThreadID) OBJECT_PROPERTY(selectedMessageTopicKind)
FLAG_PROPERTY(initialConnectStarted) FLAG_PROPERTY(authClientRecoveryInFlight) FLAG_PROPERTY(profileSummaryLoaded)
FLAG_PROPERTY(pendingLiveChatRefresh) FLAG_PROPERTY(pendingLiveMessageRefresh) FLAG_PROPERTY(chatsExhausted)
FLAG_PROPERTY(olderMessagesExhausted) FLAG_PROPERTY(autoChatListLoadArmed) FLAG_PROPERTY(autoChatListRefreshArmed)
FLAG_PROPERTY(autoOlderMessagesLoadArmed) FLAG_PROPERTY(controlsBusy)
@property (nonatomic, assign) NSUInteger authClientRecoveryAttemptCount, cleanupCount, reconnectCount, detailCount, badgeCount;
@property (nonatomic, copy) NSString *authState;
- (void)resetNotificationDeliveryAfterLogout;
- (void)appendDetail:(NSString *)detail;
- (void)refreshSelectedChatHeaderDisplay;
- (void)setComposerTextWithoutSavingDraft:(NSString *)text;
- (void)updateApplicationBadge;
- (void)updateAuthControlsForState:(NSString *)state;
- (void)checkTDLib:(id)sender;
- (void)applyLogoutSummary:(NSString *)summary errorMessage:(NSString *)error owner:(TGTDLibClient *)client;
@end
#define SYNTHESIZE_PROPERTY(name) @synthesize name = _##name;
#define RELEASE_PROPERTY(name) [_##name release];
@implementation LogoutProbeController
SYNTHESIZE_PROPERTY(client) SYNTHESIZE_PROPERTY(statusField)
SYNTHESIZE_PROPERTY(chatItems) SYNTHESIZE_PROPERTY(messageItems) SYNTHESIZE_PROPERTY(composerDraftsByTargetKey)
SYNTHESIZE_PROPERTY(chatTableView) SYNTHESIZE_PROPERTY(messageTableView)
SYNTHESIZE_PROPERTY(selectedChatID) SYNTHESIZE_PROPERTY(selectedChatTitle) SYNTHESIZE_PROPERTY(selectedChatTypeSummary)
SYNTHESIZE_PROPERTY(selectedChatAvatarLocalPath) SYNTHESIZE_PROPERTY(selectedChatLastReadOutboxMessageID)
SYNTHESIZE_PROPERTY(selectedMessageThreadID) SYNTHESIZE_PROPERTY(selectedMessageTopicKind)
SYNTHESIZE_PROPERTY(initialConnectStarted) SYNTHESIZE_PROPERTY(authClientRecoveryInFlight) SYNTHESIZE_PROPERTY(profileSummaryLoaded)
SYNTHESIZE_PROPERTY(pendingLiveChatRefresh) SYNTHESIZE_PROPERTY(pendingLiveMessageRefresh) SYNTHESIZE_PROPERTY(chatsExhausted)
SYNTHESIZE_PROPERTY(olderMessagesExhausted) SYNTHESIZE_PROPERTY(autoChatListLoadArmed) SYNTHESIZE_PROPERTY(autoChatListRefreshArmed)
SYNTHESIZE_PROPERTY(autoOlderMessagesLoadArmed) SYNTHESIZE_PROPERTY(controlsBusy)
SYNTHESIZE_PROPERTY(authClientRecoveryAttemptCount) SYNTHESIZE_PROPERTY(cleanupCount) SYNTHESIZE_PROPERTY(reconnectCount)
SYNTHESIZE_PROPERTY(detailCount) SYNTHESIZE_PROPERTY(badgeCount) SYNTHESIZE_PROPERTY(authState)
- (id)init {
    if ((self = [super init])) {
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        self.statusField = [[[LogoutProbeStatus alloc] init] autorelease];
        self.chatTableView = [[[LogoutProbeTable alloc] init] autorelease];
        self.messageTableView = [[[LogoutProbeTable alloc] init] autorelease];
        self.chatItems = [NSMutableArray arrayWithObject:@"synthetic chat"];
        self.messageItems = [NSMutableArray arrayWithObject:@"synthetic message"];
        self.composerDraftsByTargetKey = [NSMutableDictionary dictionaryWithObject:@"synthetic draft" forKey:@"fixture"];
        self.selectedChatID = @-100; self.controlsBusy = YES; self.authState = @"ready";
    }
    return self;
}
- (void)dealloc {
    RELEASE_PROPERTY(client) RELEASE_PROPERTY(statusField) RELEASE_PROPERTY(chatItems) RELEASE_PROPERTY(messageItems)
    RELEASE_PROPERTY(composerDraftsByTargetKey) RELEASE_PROPERTY(chatTableView) RELEASE_PROPERTY(messageTableView)
    RELEASE_PROPERTY(selectedChatID) RELEASE_PROPERTY(selectedChatTitle) RELEASE_PROPERTY(selectedChatTypeSummary)
    RELEASE_PROPERTY(selectedChatAvatarLocalPath) RELEASE_PROPERTY(selectedChatLastReadOutboxMessageID)
    RELEASE_PROPERTY(selectedMessageThreadID) RELEASE_PROPERTY(selectedMessageTopicKind) RELEASE_PROPERTY(authState)
    [super dealloc];
}
- (void)resetNotificationDeliveryAfterLogout { self.cleanupCount++; }
- (void)appendDetail:(NSString *)detail { (void)detail; self.detailCount++; }
- (void)refreshSelectedChatHeaderDisplay {}
- (void)setComposerTextWithoutSavingDraft:(NSString *)text { (void)text; }
- (void)updateApplicationBadge { self.badgeCount++; }
- (void)updateAuthControlsForState:(NSString *)state { self.authState = state; }
- (void)checkTDLib:(id)sender { (void)sender; self.reconnectCount++; }
#include "../Sources/UI/TGStatusWindowController+LogoutCompletion.inc"
@end

static LogoutProbeController *Controller(void) { return [[[LogoutProbeController alloc] init] autorelease]; }
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    LogoutProbeController *c = Controller();
    TGTDLibClient *owner = [[c.client retain] autorelease];
    [c applyLogoutSummary:@"synthetic acknowledged logout" errorMessage:nil owner:owner];
    Require(c.cleanupCount == 1 && c.client != owner && c.reconnectCount == 1 && c.badgeCount == 1 &&
        [c.chatItems count] == 0 && [c.messageItems count] == 0 && [c.composerDraftsByTargetKey count] == 0 &&
        !c.selectedChatID && !c.controlsBusy && [c.authState isEqual:@"closed"],
        "current-owner successful logout clears deliveries and UI exactly once, then reconnects");

    c = Controller(); owner = [[c.client retain] autorelease];
    [c applyLogoutSummary:nil errorMessage:@"synthetic rejection" owner:owner];
    Require(c.cleanupCount == 0 && c.client == owner && c.reconnectCount == 0 && c.badgeCount == 0 &&
        [c.chatItems count] == 1 && [c.messageItems count] == 1 && c.selectedChatID &&
        !c.controlsBusy && [c.authState isEqual:@"ready"] && [c.statusField.text isEqual:@"Logout failed"],
        "failed logout retains current session, unread UI and system deliveries");

    c = Controller(); owner = [[c.client retain] autorelease];
    c.client = [[[TGTDLibClient alloc] init] autorelease];
    TGTDLibClient *replacement = c.client;
    [c applyLogoutSummary:@"synthetic acknowledged old logout" errorMessage:nil owner:owner];
    [c applyLogoutSummary:nil errorMessage:@"synthetic old rejection" owner:owner];
    Require(c.cleanupCount == 0 && c.client == replacement && c.reconnectCount == 0 && c.badgeCount == 0 &&
        c.detailCount == 0 && [c.chatItems count] == 1 && [c.messageItems count] == 1 &&
        c.selectedChatID && c.controlsBusy && [c.authState isEqual:@"ready"] && !c.statusField.text,
        "both late success and failure from a replaced owner leave the new session and deliveries intact");
    puts("Notification logout production completion probe passed: current success, failure and stale-owner isolation.");
    [pool drain]; return 0;
}
