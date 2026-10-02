#import "TGTDLibClient+MessageThreads.h"
#import "TGMessageThreadSupport.h"

@interface TGTDLibClient (MessageThreadInternals)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)prefix timeout:(NSTimeInterval)timeout errorCode:(NSInteger)code error:(NSError **)error;
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind fromMessageID:(NSNumber *)fromMessageID offset:(NSInteger)offset limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end

@implementation TGTDLibClient (MessageThreads)

- (NSDictionary *)resolveMessageThreadForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || [chatID longLongValue] == 0 ||
        ![messageID respondsToSelector:@selector(longLongValue)] || [messageID longLongValue] <= 0) {
        if (error) { *error = [self errorWithDescription:@"Message thread target is missing." code:84]; }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
        @"getMessageThread", @"@type", chatID, @"chat_id", messageID, @"message_id", nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request extraPrefix:@"telegraphica-resolve-message-thread" timeout:timeout errorCode:84 error:error];
    if (!response) { return nil; }
    NSDictionary *destination = TGMessageThreadDestinationFromInfo(response);
    if (!destination && error) {
        *error = [self errorWithDescription:@"TDLib returned an invalid message thread destination." code:84];
    }
    return destination;
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self recentMessagePreviewItemsForChatID:chatID messageThreadID:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:nil fromMessageID:fromMessageID limit:limit timeout:timeout error:error];
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self recentMessagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind fromMessageID:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil fromMessageID:fromMessageID limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID
                             messageThreadID:messageThreadID
                            messageTopicKind:messageTopicKind
                               fromMessageID:fromMessageID
                                      offset:0
                                       limit:limit
                                     timeout:timeout
                                       error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind aroundMessageID:(NSNumber *)messageID newerMessageCount:(NSUInteger)newerMessageCount limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSInteger safeNewerCount = (NSInteger)MIN((NSUInteger)40, newerMessageCount);
    return [self messagePreviewItemsForChatID:chatID
                             messageThreadID:messageThreadID
                            messageTopicKind:messageTopicKind
                               fromMessageID:messageID
                                      offset:-safeNewerCount
                                       limit:MAX(limit, (NSUInteger)safeNewerCount)
                                     timeout:timeout
                                       error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID
                          messageThreadID:(NSNumber *)messageThreadID
                         messageTopicKind:(NSString *)messageTopicKind
                            fromMessageID:(NSNumber *)fromMessageID
                                   offset:(NSInteger)historyOffset
                                    limit:(NSUInteger)limit
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:38];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:39];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 20;
    } else if (safeLimit > 50) {
        safeLimit = 50;
    }

    long long anchorMessageID = 0;
    if ([fromMessageID respondsToSelector:@selector(longLongValue)]) {
        anchorMessageID = [fromMessageID longLongValue];
    }

    BOOL threadHistory = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    NSString *safeTopicKind = [messageTopicKind isKindOfClass:[NSString class]] ? messageTopicKind : nil;
    BOOL knownFreshForumTopic = [safeTopicKind isEqualToString:@"forum"];
    BOOL knownLegacyForumTopic = [safeTopicKind isEqualToString:@"forum_legacy"];
    BOOL knownThreadTopic = [safeTopicKind isEqualToString:@"thread"];
    BOOL allowForumSchema = threadHistory && !knownThreadTopic;
    BOOL allowThreadSchema = threadHistory && !knownFreshForumTopic && !knownLegacyForumTopic;
    BOOL allowLegacyThreadSchema = threadHistory && !knownFreshForumTopic;

    NSError *primaryHistoryError = nil;
    NSDictionary *response = nil;
    if (threadHistory && allowForumSchema) {
        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        [request setObject:@"getForumTopicHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"forum_topic_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInteger:historyOffset] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        response = [self sendTDLibRequestAndWaitForExtra:request
                                             extraPrefix:@"telegraphica-forum-topic-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!threadHistory) {
        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        [request setObject:@"getChatHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInteger:historyOffset] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [request setObject:[NSNumber numberWithBool:NO] forKey:@"only_local"];
        response = [self sendTDLibRequestAndWaitForExtra:request
                                             extraPrefix:@"telegraphica-chat-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }

    if (!response && threadHistory && allowThreadSchema) {
        NSMutableDictionary *legacyThreadRequest = [NSMutableDictionary dictionary];
        [legacyThreadRequest setObject:@"getMessageThreadHistory" forKey:@"@type"];
        [legacyThreadRequest setObject:chatID forKey:@"chat_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithInteger:historyOffset] forKey:@"offset"];
        [legacyThreadRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        response = [self sendTDLibRequestAndWaitForExtra:legacyThreadRequest
                                             extraPrefix:@"telegraphica-message-thread-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!response && threadHistory && allowForumSchema) {
        NSMutableDictionary *searchRequest = [NSMutableDictionary dictionary];
        [searchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [searchRequest setObject:chatID forKey:@"chat_id"];
        [searchRequest setObject:@"" forKey:@"query"];
        [searchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [searchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [searchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [searchRequest setObject:[NSNull null] forKey:@"filter"];
        NSDictionary *forumTopic = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"messageTopicForum", @"@type",
                                    [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"forum_topic_id",
                                    nil];
        [searchRequest setObject:forumTopic forKey:@"topic_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:searchRequest
                                               extraPrefix:@"telegraphica-thread-search-history"
                                                   timeout:timeout
                                                 errorCode:40
                                                     error:&primaryHistoryError];
        if (response && !TGMessageThreadHistoryResponseIsScoped(response, chatID, messageThreadID, safeTopicKind)) {
            response = nil;
            primaryHistoryError = [self errorWithDescription:@"TDLib search returned messages outside the requested discussion." code:41];
        }
    }
    if (!response && threadHistory && allowThreadSchema) {
        NSMutableDictionary *searchRequest = [NSMutableDictionary dictionary];
        [searchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [searchRequest setObject:chatID forKey:@"chat_id"];
        [searchRequest setObject:@"" forKey:@"query"];
        [searchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [searchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [searchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [searchRequest setObject:[NSNull null] forKey:@"filter"];
        NSDictionary *messageThread = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"messageTopicThread", @"@type",
                                       [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"message_thread_id",
                                       nil];
        [searchRequest setObject:messageThread forKey:@"topic_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:searchRequest
                                             extraPrefix:@"telegraphica-message-thread-search-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
        if (response && !TGMessageThreadHistoryResponseIsScoped(response, chatID, messageThreadID, safeTopicKind)) {
            response = nil;
            primaryHistoryError = [self errorWithDescription:@"TDLib search returned messages outside the requested discussion." code:41];
        }
    }
    if (!response && threadHistory && allowLegacyThreadSchema) {
        NSMutableDictionary *legacySearchRequest = [NSMutableDictionary dictionary];
        [legacySearchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [legacySearchRequest setObject:chatID forKey:@"chat_id"];
        [legacySearchRequest setObject:@"" forKey:@"query"];
        [legacySearchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [legacySearchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [legacySearchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [legacySearchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [legacySearchRequest setObject:[NSNull null] forKey:@"filter"];
        [legacySearchRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:legacySearchRequest
                                             extraPrefix:@"telegraphica-thread-search-history-legacy"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
        if (response && !TGMessageThreadHistoryResponseIsScoped(response, chatID, messageThreadID, safeTopicKind)) {
            response = nil;
            primaryHistoryError = [self errorWithDescription:@"TDLib search returned messages outside the requested discussion." code:41];
        }
    }
    if (!response) {
        if (error) {
            *error = primaryHistoryError;
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id messages = [response objectForKey:@"messages"];
    BOOL expectedMessagesResponse = ([responseType isKindOfClass:[NSString class]] &&
                                     ([(NSString *)responseType isEqualToString:@"messages"] ||
                                      [(NSString *)responseType isEqualToString:@"foundChatMessages"]));
    if (!expectedMessagesResponse || ![messages isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChatHistory returned an unexpected response." code:41];
        }
        return nil;
    }

    return [self messagePreviewItemsFromMessages:(NSArray *)messages chatID:chatID];
}


@end
