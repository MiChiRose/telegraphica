#import <Foundation/Foundation.h>

/* Account-local, bounded read evidence. No persisted account/message content. */
@interface TGNotificationReadState : NSObject {
    NSMutableDictionary *_watermarks;
    NSMutableArray *_chatOrder;
    NSMutableSet *_readMessages;
    NSMutableArray *_messageOrder;
}
- (void)reset;
- (void)recordReadMessageIDs:(NSArray *)messageIDs chatID:(NSNumber *)chatID;
- (void)recordReadInboxMessageID:(NSNumber *)messageID chatID:(NSNumber *)chatID;
- (BOOL)isReadNotificationInfo:(NSDictionary *)info;
@end

NSDictionary *TGNotificationReadSummaryFromUpdate(NSDictionary *update);
BOOL TGNotificationInfoBelongsToChat(NSDictionary *info, NSNumber *chatID);
