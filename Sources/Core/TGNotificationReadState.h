#import <Foundation/Foundation.h>

/* Account-local, bounded read evidence. No persisted account/message content. */
@interface TGNotificationReadState : NSObject {
    NSMutableDictionary *_watermarks;
    NSMutableArray *_chatOrder;
    NSMutableSet *_readMessages;
    NSMutableArray *_messageOrder;
    NSMutableSet *_presentedMessages;
    NSMutableArray *_presentationOrder;
    NSTimeInterval _presentationCutoff;
    NSTimeInterval _lastPollTime;
    NSTimeInterval _serverTimeOffset;
}
- (void)reset;
- (void)resetAtUnixTime:(NSTimeInterval)now;
/* Preflight read evidence before delivering any message from a drained batch. */
- (void)prepareForUpdateBatch:(NSArray *)updates atUnixTime:(NSTimeInterval)now;
/* Consume once after mute/settings checks; historical synchronization never alerts. */
- (BOOL)consumeIncomingNotificationSummary:(NSDictionary *)summary atUnixTime:(NSTimeInterval)now;
- (void)recordReadMessageIDs:(NSArray *)messageIDs chatID:(NSNumber *)chatID;
- (void)recordReadInboxMessageID:(NSNumber *)messageID chatID:(NSNumber *)chatID;
- (BOOL)isReadNotificationInfo:(NSDictionary *)info;
@end

NSDictionary *TGNotificationReadSummaryFromUpdate(NSDictionary *update);
NSDictionary *TGNotificationClockSummaryFromUpdate(NSDictionary *update);
BOOL TGNotificationInfoBelongsToChat(NSDictionary *info, NSNumber *chatID);
