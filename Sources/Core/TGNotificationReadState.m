#import "TGNotificationReadState.h"

static NSNumber *TGNotificationID(id value, BOOL positive) {
    if (![value isKindOfClass:[NSNumber class]]) { return nil; }
    long long number = [value longLongValue];
    return (positive ? number > 0 : number != 0) ? [NSNumber numberWithLongLong:number] : nil;
}

static NSString *TGReadMessageKey(NSNumber *chatID, NSNumber *messageID) {
    return [NSString stringWithFormat:@"%lld:%lld", [chatID longLongValue], [messageID longLongValue]];
}

BOOL TGNotificationInfoBelongsToChat(NSDictionary *info, NSNumber *chatID) {
    NSNumber *wanted = TGNotificationID(chatID, NO);
    NSNumber *actual = [info isKindOfClass:[NSDictionary class]] ? TGNotificationID([info objectForKey:@"chat_id"], NO) : nil;
    return wanted && actual && [actual isEqual:wanted];
}

NSDictionary *TGNotificationReadSummaryFromUpdate(NSDictionary *update) {
    if (![update isKindOfClass:[NSDictionary class]] ||
        ![[update objectForKey:@"@type"] isEqual:@"updateChatReadInbox"]) { return nil; }
    NSNumber *chatID = TGNotificationID([update objectForKey:@"chat_id"], NO);
    NSNumber *messageID = TGNotificationID([update objectForKey:@"last_read_inbox_message_id"], YES);
    id unread = [update objectForKey:@"unread_count"];
    if (!chatID || !messageID || ![unread isKindOfClass:[NSNumber class]] || [unread longLongValue] < 0) { return nil; }
    return [NSDictionary dictionaryWithObjectsAndKeys:@"chat_read_inbox", @"kind",
            @"updateChatReadInbox", @"type", chatID, @"chat_id", messageID, @"last_read_inbox_message_id",
            unread, @"unread_count", nil];
}

@implementation TGNotificationReadState
- (id)init {
    self = [super init];
    if (self) {
        _watermarks = [[NSMutableDictionary alloc] init];
        _chatOrder = [[NSMutableArray alloc] init];
        _readMessages = [[NSMutableSet alloc] init];
        _messageOrder = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)reset {
    [_watermarks removeAllObjects]; [_chatOrder removeAllObjects];
    [_readMessages removeAllObjects]; [_messageOrder removeAllObjects];
}
- (void)recordReadInboxMessageID:(NSNumber *)messageID chatID:(NSNumber *)chatID {
    chatID = TGNotificationID(chatID, NO); messageID = TGNotificationID(messageID, YES);
    if (!chatID || !messageID) { return; }
    NSNumber *previous = [_watermarks objectForKey:chatID];
    if (previous && [previous longLongValue] >= [messageID longLongValue]) { return; }
    if (!previous) { [_chatOrder addObject:chatID]; }
    [_watermarks setObject:messageID forKey:chatID];
    while ([_chatOrder count] > 256) {
        [_watermarks removeObjectForKey:[_chatOrder objectAtIndex:0]];
        [_chatOrder removeObjectAtIndex:0];
    }
}
- (void)recordReadMessageIDs:(NSArray *)messageIDs chatID:(NSNumber *)chatID {
    chatID = TGNotificationID(chatID, NO);
    if (!chatID || ![messageIDs isKindOfClass:[NSArray class]]) { return; }
    for (id value in messageIDs) {
        NSNumber *messageID = TGNotificationID(value, YES);
        if (!messageID) { continue; }
        NSString *key = TGReadMessageKey(chatID, messageID);
        if (![_readMessages containsObject:key]) { [_readMessages addObject:key]; [_messageOrder addObject:key]; }
    }
    while ([_messageOrder count] > 1024) {
        [_readMessages removeObject:[_messageOrder objectAtIndex:0]];
        [_messageOrder removeObjectAtIndex:0];
    }
}
- (BOOL)isReadNotificationInfo:(NSDictionary *)info {
    if (![info isKindOfClass:[NSDictionary class]]) { return NO; }
    NSNumber *chatID = TGNotificationID([info objectForKey:@"chat_id"], NO);
    NSNumber *messageID = TGNotificationID([info objectForKey:@"message_id"], YES);
    if (!chatID || !messageID) { return NO; }
    NSNumber *watermark = [_watermarks objectForKey:chatID];
    return (watermark && [messageID longLongValue] <= [watermark longLongValue]) ||
           [_readMessages containsObject:TGReadMessageKey(chatID, messageID)];
}
- (void)dealloc {
    [_watermarks release]; [_chatOrder release]; [_readMessages release]; [_messageOrder release]; [super dealloc];
}
@end
