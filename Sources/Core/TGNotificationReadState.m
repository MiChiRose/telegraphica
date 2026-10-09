#import "TGNotificationReadState.h"
#import <math.h>
#import <errno.h>
#import <stdlib.h>

static const NSTimeInterval TGNotificationLiveWindow = 30.0;
static const NSTimeInterval TGNotificationClockTolerance = 5.0;

static NSNumber *TGNotificationID(id value, BOOL positive) {
    if (![value isKindOfClass:[NSNumber class]]) { return nil; }
    long long number = [value longLongValue];
    return (positive ? number > 0 : number != 0) ? [NSNumber numberWithLongLong:number] : nil;
}

static NSString *TGReadMessageKey(NSNumber *chatID, NSNumber *messageID) {
    return [NSString stringWithFormat:@"%lld:%lld", [chatID longLongValue], [messageID longLongValue]];
}

/* TDLib encodes int64 option values as decimal JSON strings. This conversion
   is deliberately local to clock options; normalized notification IDs stay numeric. */
static NSNumber *TGNotificationClockTimestamp(id value) {
    if ([value isKindOfClass:[NSNumber class]]) { return TGNotificationID(value, YES); }
    if (![value isKindOfClass:[NSString class]] || [value length] == 0 || [value length] > 19) { return nil; }
    for (NSUInteger index = 0; index < [value length]; index++) {
        unichar digit = [value characterAtIndex:index];
        if (digit < '0' || digit > '9') { return nil; }
    }
    errno = 0;
    char *end = NULL;
    long long number = strtoll([value UTF8String], &end, 10);
    if (errno == ERANGE || !end || *end != '\0' || number <= 0) { return nil; }
    return [NSNumber numberWithLongLong:number];
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

NSDictionary *TGNotificationClockSummaryFromUpdate(NSDictionary *update) {
    if (![update isKindOfClass:[NSDictionary class]] ||
        ![[update objectForKey:@"@type"] isEqual:@"updateOption"] ||
        ![[update objectForKey:@"name"] isEqual:@"unix_time"]) { return nil; }
    id value = [update objectForKey:@"value"];
    if (![value isKindOfClass:[NSDictionary class]] ||
        ![[value objectForKey:@"@type"] isEqual:@"optionValueInteger"]) { return nil; }
    NSNumber *timestamp = TGNotificationClockTimestamp([value objectForKey:@"value"]);
    return timestamp ? [NSDictionary dictionaryWithObjectsAndKeys:@"notification_clock", @"kind",
                        timestamp, @"unix_time", [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]],
                        @"local_time", nil] : nil;
}

@implementation TGNotificationReadState
- (id)init {
    self = [super init];
    if (self) {
        _watermarks = [[NSMutableDictionary alloc] init];
        _chatOrder = [[NSMutableArray alloc] init];
        _readMessages = [[NSMutableSet alloc] init];
        _messageOrder = [[NSMutableArray alloc] init];
        _presentedMessages = [[NSMutableSet alloc] init];
        _presentationOrder = [[NSMutableArray alloc] init];
        [self reset];
    }
    return self;
}
- (void)reset {
    [self resetAtUnixTime:[[NSDate date] timeIntervalSince1970]];
}
- (void)resetAtUnixTime:(NSTimeInterval)now {
    [_watermarks removeAllObjects]; [_chatOrder removeAllObjects];
    [_readMessages removeAllObjects]; [_messageOrder removeAllObjects];
    [_presentedMessages removeAllObjects]; [_presentationOrder removeAllObjects];
    _serverTimeOffset = 0;
    _presentationCutoff = floor(now);
    _lastPollTime = now;
}
- (void)prepareForUpdateBatch:(NSArray *)updates atUnixTime:(NSTimeInterval)now {
    if (!isfinite(now) || now <= 0) { return; }
    if ([updates isKindOfClass:[NSArray class]]) {
        for (id summary in updates) {
            if (![summary isKindOfClass:[NSDictionary class]]) { continue; }
            if ([[summary objectForKey:@"kind"] isEqual:@"notification_clock"]) {
                NSNumber *timestamp = TGNotificationID([summary objectForKey:@"unix_time"], YES);
                if (timestamp) {
                    id received = [summary objectForKey:@"local_time"];
                    NSTimeInterval receivedTime = [received isKindOfClass:[NSNumber class]] ? [received doubleValue] : now;
                    if (!isfinite(receivedTime) || receivedTime <= 0) { receivedTime = now; }
                    NSTimeInterval offset = [timestamp doubleValue] - receivedTime;
                    _presentationCutoff += offset - _serverTimeOffset;
                    _serverTimeOffset = offset;
                }
            }
        }
    }
    /* Timer suspension is a resume boundary, without resetting confirmed reads. */
    if (now < _lastPollTime || now - _lastPollTime > TGNotificationLiveWindow) {
        _presentationCutoff = floor(now + _serverTimeOffset);
    }
    _lastPollTime = now;
    if (![updates isKindOfClass:[NSArray class]]) { return; }
    for (id summary in updates) {
        if ([summary isKindOfClass:[NSDictionary class]] &&
            [[summary objectForKey:@"kind"] isEqual:@"chat_read_inbox"]) {
            [self recordReadInboxMessageID:[summary objectForKey:@"last_read_inbox_message_id"]
                                   chatID:[summary objectForKey:@"chat_id"]];
        }
    }
}
- (BOOL)consumeIncomingNotificationSummary:(NSDictionary *)summary atUnixTime:(NSTimeInterval)now {
    if (![summary isKindOfClass:[NSDictionary class]] ||
        ![[summary objectForKey:@"direction"] isEqual:@"Incoming"]) { return NO; }
    NSNumber *chatID = TGNotificationID([summary objectForKey:@"chat_id"], NO);
    NSNumber *messageID = TGNotificationID([summary objectForKey:@"message_id"], YES);
    NSNumber *date = TGNotificationID([summary objectForKey:@"date"], YES);
    if (!chatID || !messageID || !date || !isfinite(now) || now <= 0 ||
        [date doubleValue] < _presentationCutoff - TGNotificationClockTolerance ||
        now + _serverTimeOffset - [date doubleValue] > TGNotificationLiveWindow ||
        [date doubleValue] > now + _serverTimeOffset + TGNotificationClockTolerance ||
        [self isReadNotificationInfo:summary]) { return NO; }
    NSString *key = TGReadMessageKey(chatID, messageID);
    if ([_presentedMessages containsObject:key]) { return NO; }
    [_presentedMessages addObject:key]; [_presentationOrder addObject:key];
    while ([_presentationOrder count] > 1024) {
        [_presentedMessages removeObject:[_presentationOrder objectAtIndex:0]];
        [_presentationOrder removeObjectAtIndex:0];
    }
    return YES;
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
    [_watermarks release]; [_chatOrder release]; [_readMessages release]; [_messageOrder release];
    [_presentedMessages release]; [_presentationOrder release]; [super dealloc];
}
@end
