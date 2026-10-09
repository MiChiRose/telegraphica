#import <Cocoa/Cocoa.h>
#import "TGNotificationReadState.h"
#import "TGNotificationDeliverySupport.h"

static void Require(BOOL value, NSString *message) {
    if (!value) { fprintf(stderr, "FAIL: %s\n", [message UTF8String]); exit(1); }
}
static NSDictionary *Info(long long chat, long long message, long long thread) {
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithLongLong:chat], @"chat_id",
            [NSNumber numberWithLongLong:message], @"message_id", [NSNumber numberWithLongLong:thread], @"message_thread_id", nil];
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
    NSDictionary *valid=[NSDictionary dictionaryWithObjectsAndKeys:@"updateChatReadInbox", @"@type", @-100, @"chat_id", @550, @"last_read_inbox_message_id", @1, @"unread_count", nil];
    Require([[TGNotificationReadSummaryFromUpdate(valid) objectForKey:@"kind"] isEqual:@"chat_read_inbox"], @"server read evidence retained in safe update summary");
    Require(!TGNotificationReadSummaryFromUpdate([NSDictionary dictionaryWithObjectsAndKeys:@"updateChatReadInbox", @"@type", @-100, @"chat_id", @0, @"last_read_inbox_message_id", @0, @"unread_count", nil]), @"invalid watermark never treated as evidence");
    Require(![state isReadNotificationInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"-100", @"chat_id", @500, @"message_id", nil]], @"malformed info preserved");
    for (NSInteger i=1;i<=1100;i++) { [state recordReadMessageIDs:[NSArray arrayWithObject:[NSNumber numberWithInteger:i]] chatID:@-100]; }
    Require(![state isReadNotificationInfo:Info(-100,1,0)] && [state isReadNotificationInfo:Info(-100,1100,0)], @"exact read evidence bounded with newest retained");
    for (NSInteger i=1;i<=300;i++) { [state recordReadInboxMessageID:@10 chatID:[NSNumber numberWithInteger:i]]; }
    Require(![state isReadNotificationInfo:Info(1,1,0)] && [state isReadNotificationInfo:Info(300,1,0)], @"chat watermark evidence bounded");
    TGRemoveConfirmedReadNotifications(nil, state);
    puts("Notification read-state and delivery cleanup probe passed.");
    [pool drain]; return 0;
}
