#import <Cocoa/Cocoa.h>
#import "TGNotificationReadState.h"
#import "TGNotificationDeliverySupport.h"
#import "TGChatItem.h"

static void Require(BOOL value, NSString *message) {
    if (!value) { fprintf(stderr, "FAIL: %s\n", [message UTF8String]); exit(1); }
}
static NSDictionary *Info(long long chat, long long message, long long thread) {
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:chat], @"chat_id",
            [NSNumber numberWithLongLong:message], @"message_id", [NSNumber numberWithLongLong:thread], @"message_thread_id", nil];
}
static NSDictionary *Incoming(long long message, long long date) {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"new_message", @"kind", @"Incoming", @"direction",
            @-100, @"chat_id", [NSNumber numberWithLongLong:message], @"message_id",
            [NSNumber numberWithLongLong:date], @"date", nil];
}
@interface ProbeNotification : NSObject {
    NSDictionary *_info;
}
- (id)initWithInfo:(NSDictionary *)info;
- (NSDictionary *)userInfo;
@end
@implementation ProbeNotification
- (id)initWithInfo:(NSDictionary *)info { self=[super init]; if (self) { _info=[info copy]; } return self; }
- (NSDictionary *)userInfo { return _info; }
- (void)dealloc { [_info release]; [super dealloc]; }
@end
@interface ProbeCenter : NSObject {
    NSMutableArray *_delivered;
}
- (id)initWithInfos:(NSArray *)infos;
- (NSArray *)deliveredNotifications;
- (void)removeDeliveredNotification:(id)notification;
@end
@implementation ProbeCenter
- (id)initWithInfos:(NSArray *)infos {
    self=[super init]; if (self) { _delivered=[[NSMutableArray alloc] init];
        for (NSDictionary *info in infos) { [_delivered addObject:[[[ProbeNotification alloc] initWithInfo:info] autorelease]]; }
    } return self;
}
- (NSArray *)deliveredNotifications { return _delivered; }
- (void)removeDeliveredNotification:(id)notification { [_delivered removeObjectIdenticalTo:notification]; }
- (void)dealloc { [_delivered release]; [super dealloc]; }
@end
int main(void) {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    TGNotificationReadState *state=[[[TGNotificationReadState alloc] init] autorelease];
    NSDictionary *seen=Info(-100, 500, 10), *unseen=Info(-100, 501, 10), *otherTopic=Info(-100, 600, 20), *otherChat=Info(-200, 500, 10);
    NSArray *infos=[NSArray arrayWithObjects:seen, unseen, otherTopic, otherChat,
                   [NSDictionary dictionaryWithObject:@"update" forKey:@"kind"], nil];
    ProbeCenter *center=[[[ProbeCenter alloc] initWithInfos:infos] autorelease];
    [state recordReadMessageIDs:[NSArray arrayWithObject:@500] chatID:@-100];
    TGRemoveConfirmedReadNotifications(center, state);
    Require([[center deliveredNotifications] count]==4, @"exact successful read removes only matching message, preserves other thread/chat/update");
    Require([state isReadNotificationInfo:seen], @"late summary for read message is suppressed");
    Require(![state isReadNotificationInfo:unseen], @"newer unread message is not suppressed");
    [state recordReadInboxMessageID:@550 chatID:@-100];
    [state recordReadInboxMessageID:@450 chatID:@-100];
    TGRemoveConfirmedReadNotifications(center, state);
    Require([[center deliveredNotifications] count]==3, @"server watermark is monotonic and removes read range only");
    Require(![state isReadNotificationInfo:otherTopic] && ![state isReadNotificationInfo:otherChat], @"unread other topic and other chat preserved");
    [state reset];
    Require(![state isReadNotificationInfo:seen], @"new account/client resets old evidence");
    NSArray *restoredInfos = [NSArray arrayWithObjects:Info(-100, 400, 0), Info(-100, 450, 0),
        Info(-100, 500, 0), Info(-100, 600, 0), Info(-200, 500, 0), nil];
    ProbeCenter *restoredCenter = [[[ProbeCenter alloc] initWithInfos:restoredInfos] autorelease];
    TGChatItem *snapshot = [[[TGChatItem alloc] initWithChatID:@-100 title:@"test"
        typeSummary:@"Private" unreadCount:@0] autorelease];
    [snapshot setLastReadInboxMessageID:@550];
    TGChatItem *topic = [[[TGChatItem alloc] initWithChatID:@-100 title:@"topic"
        typeSummary:@"Forum" unreadCount:@0] autorelease];
    [topic setForumTopic:YES]; [topic setLastReadInboxMessageID:@9999];
    TGChatItem *noEvidence = [[[TGChatItem alloc] initWithChatID:@-200 title:@"test"
        typeSummary:@"Private" unreadCount:@0] autorelease];
    TGRecordConfirmedNotificationChatReads([NSArray arrayWithObjects:snapshot, topic, noEvidence, @"invalid", nil], state);
    TGRemoveConfirmedReadNotifications(restoredCenter, state);
    Require([[restoredCenter deliveredNotifications] count] == 2,
        @"authoritative already-phone-read chat snapshot removes three restored notifications without a new read RPC");
    Require(![state isReadNotificationInfo:Info(-100,600,0)] && ![state isReadNotificationInfo:Info(-200,500,0)],
        @"topic watermark and zero unread count alone never clear newer or unrelated notifications");
    [state reset];
    NSMutableArray *largeSnapshot = [NSMutableArray array];
    for (NSInteger i = 1; i <= 500; i++) {
        TGChatItem *chat = [[[TGChatItem alloc] initWithChatID:[NSNumber numberWithInteger:i]
            title:@"test" typeSummary:@"Private" unreadCount:@0] autorelease];
        [chat setLastReadInboxMessageID:@550]; [largeSnapshot addObject:chat];
    }
    ProbeCenter *largeCenter = [[[ProbeCenter alloc] initWithInfos:[NSArray arrayWithObject:Info(1,500,0)]] autorelease];
    TGRecordConfirmedNotificationChatReads(largeSnapshot, state);
    TGRemoveConfirmedReadNotifications(largeCenter, state);
    Require([[largeCenter deliveredNotifications] count] == 0,
        @"full 500-chat snapshot retains first-chat evidence until delivered notifications are purged");
    [state reset];
    for (NSInteger i = 1; i <= 512; i++) {
        [state recordReadInboxMessageID:@550 chatID:[NSNumber numberWithInteger:i]];
    }
    NSMutableArray *mixedSnapshot = [NSMutableArray array];
    for (NSInteger i = 0; i < 500; i++) {
        TGChatItem *chat = [[[TGChatItem alloc] initWithChatID:[NSNumber numberWithInteger:(i == 0 ? 1 : 1000+i)]
            title:@"test" typeSummary:@"Private" unreadCount:@0] autorelease];
        [chat setLastReadInboxMessageID:@550]; [mixedSnapshot addObject:chat];
    }
    TGRecordConfirmedNotificationChatReads(mixedSnapshot, state);
    Require([state isReadNotificationInfo:Info(1,500,0)],
        @"unchanged first-chat watermark remains recent when mixed snapshot displaces older history");
    [state reset];
    NSDictionary *valid=[NSDictionary dictionaryWithObjectsAndKeys:@"updateChatReadInbox", @"@type", @-100, @"chat_id", @550, @"last_read_inbox_message_id", @1, @"unread_count", nil];
    Require([[TGNotificationReadSummaryFromUpdate(valid) objectForKey:@"kind"] isEqual:@"chat_read_inbox"], @"server read evidence retained in safe update summary");
    Require(!TGNotificationReadSummaryFromUpdate([NSDictionary dictionaryWithObjectsAndKeys:@"updateChatReadInbox", @"@type", @-100, @"chat_id", @0, @"last_read_inbox_message_id", @0, @"unread_count", nil]), @"invalid watermark never treated as evidence");
    Require(![state isReadNotificationInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"-100", @"chat_id", @500, @"message_id", nil]], @"malformed info preserved");
    for (NSInteger i=1;i<=1100;i++) { [state recordReadMessageIDs:[NSArray arrayWithObject:[NSNumber numberWithInteger:i]] chatID:@-100]; }
    Require(![state isReadNotificationInfo:Info(-100,1,0)] && [state isReadNotificationInfo:Info(-100,1100,0)], @"exact read evidence bounded with newest retained");
    for (NSInteger i=1;i<=600;i++) { [state recordReadInboxMessageID:@10 chatID:[NSNumber numberWithInteger:i]]; }
    Require(![state isReadNotificationInfo:Info(1,1,0)] && [state isReadNotificationInfo:Info(600,1,0)], @"chat watermark evidence bounded");
    TGRemoveConfirmedReadNotifications(nil, state);
    [state resetAtUnixTime:1000000.5];
    NSUInteger replayAlerts = 0;
    for (NSInteger i=1; i<=100; i++) {
        if ([state consumeIncomingNotificationSummary:Incoming(i, 395200) atUnixTime:1000001]) replayAlerts++;
    }
    Require(replayAlerts == 0, @"week-old unread replay never creates hundred startup alerts");
    Require([state consumeIncomingNotificationSummary:Incoming(101,1000001) atUnixTime:1000001],
            @"real new incoming eligible immediately without startup quiet timer");
    Require(![state consumeIncomingNotificationSummary:Incoming(101,1000001) atUnixTime:1000002],
            @"duplicate live update alerts only once");
    NSArray *phoneReadBatch=[NSArray arrayWithObjects:Incoming(500,1000002),
        [NSDictionary dictionaryWithObjectsAndKeys:@"chat_read_inbox", @"kind", @-100, @"chat_id",
         @550, @"last_read_inbox_message_id", nil], nil];
    [state prepareForUpdateBatch:phoneReadBatch atUnixTime:1000002];
    Require(![state consumeIncomingNotificationSummary:[phoneReadBatch objectAtIndex:0] atUnixTime:1000002],
            @"phone read arriving later in same batch suppresses alert before delivery");
    Require([state consumeIncomingNotificationSummary:Incoming(600,1000002) atUnixTime:1000002],
            @"newer unread message remains eligible after phone watermark");
    [state recordReadMessageIDs:[NSArray arrayWithObject:@600] chatID:@-100];
    Require([state isReadNotificationInfo:Incoming(600,1000002)], @"late delivery still removed after read confirmation");
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1000010];
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1000020];
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1000030];
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1000040];
    Require(![state consumeIncomingNotificationSummary:Incoming(700,1000003) atUnixTime:1000040],
            @"old network catchup silent even while UI polls continuously");
    Require([state consumeIncomingNotificationSummary:Incoming(701,1000040) atUnixTime:1000040],
            @"live traffic after network catchup is never permanently muted");
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1600000];
    Require(![state consumeIncomingNotificationSummary:Incoming(702,1599990) atUnixTime:1600000],
            @"sleep resume advances cutoff before queued replay");
    Require([state consumeIncomingNotificationSummary:Incoming(703,1600000) atUnixTime:1600000],
            @"new incoming at resume second is allowed");
    Require([state isReadNotificationInfo:Incoming(500,1600000)], @"resume preserves phone read evidence");
    NSMutableDictionary *missingDate=[NSMutableDictionary dictionaryWithDictionary:Incoming(704,1600000)];
    [missingDate removeObjectForKey:@"date"];
    Require(![state consumeIncomingNotificationSummary:missingDate atUnixTime:1600000], @"unknown timestamp never interpreted as new");
    [state prepareForUpdateBatch:[NSArray array] atUnixTime:1599000];
    Require([state consumeIncomingNotificationSummary:Incoming(705,1599000) atUnixTime:1599000], @"clock rollback cannot leave cutoff in future");
    [state resetAtUnixTime:4600];
    NSDictionary *clock=[NSDictionary dictionaryWithObjectsAndKeys:@"notification_clock", @"kind", @1000, @"unix_time", @4600, @"local_time", nil];
    [state prepareForUpdateBatch:[NSArray arrayWithObject:clock] atUnixTime:4605];
    Require([state consumeIncomingNotificationSummary:Incoming(1,1005) atUnixTime:4605], @"server clock aligns timestamp cutoff on drifting old Mac");
    Require(![state consumeIncomingNotificationSummary:Incoming(2,990) atUnixTime:4605], @"aligned clock still suppresses prelaunch replay");
    [state resetAtUnixTime:1000];
    Require([state consumeIncomingNotificationSummary:Incoming(1,1000) atUnixTime:1000], @"new account resets presentation evidence");
    NSDictionary *clockUpdate=[NSDictionary dictionaryWithObjectsAndKeys:@"updateOption", @"@type", @"unix_time", @"name",
        [NSDictionary dictionaryWithObjectsAndKeys:@"optionValueInteger", @"@type", @"1000", @"value", nil], @"value", nil];
    Require([[TGNotificationClockSummaryFromUpdate(clockUpdate) objectForKey:@"unix_time"] isEqual:@1000], @"only safe TDLib clock metadata retained");
    Require(!TGNotificationClockSummaryFromUpdate([NSDictionary dictionaryWithObjectsAndKeys:@"updateOption", @"@type", @"my_id", @"name", nil]), @"unrelated options never become notification clock evidence");
    for (NSString *invalid in [NSArray arrayWithObjects:@"", @"oops", @"12abc", @" 1000", @"+1000", @"-1000", @"1.0", @"0", @"9223372036854775808", @"999999999999999999999999", nil]) {
        NSDictionary *bad=[NSDictionary dictionaryWithObjectsAndKeys:@"updateOption", @"@type", @"unix_time", @"name",
            [NSDictionary dictionaryWithObjectsAndKeys:@"optionValueInteger", @"@type", invalid, @"value", nil], @"value", nil];
        Require(!TGNotificationClockSummaryFromUpdate(bad), @"malformed/overflow decimal wire clock rejected");
    }
    [state resetAtUnixTime:2000];
    Require([state consumeIncomingNotificationSummary:Incoming(10,1997) atUnixTime:2000], @"small negative clock skew preserves genuine incoming");
    Require([state consumeIncomingNotificationSummary:Incoming(11,2003) atUnixTime:2000], @"small future clock skew preserves genuine incoming");
    Require(![state consumeIncomingNotificationSummary:Incoming(12,3000) atUnixTime:2000], @"unbounded future timestamp never bypasses replay filtering");
    puts("Notification read-state and delivery cleanup probe passed.");
    [pool drain]; return 0;
}
