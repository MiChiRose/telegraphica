#import "TGTDLibClient+SavedMessages.h"

@interface TGTDLibClient (SavedMessagesPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSArray *)savedMessagesTopicObjectsSnapshot;
- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID;
- (NSInteger)tdlibErrorCodeFromError:(NSError *)error;
@end

static NSString *TGSavedString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGSavedID(id value) {
    return [value respondsToSelector:@selector(longLongValue)]
        ? [NSNumber numberWithLongLong:[value longLongValue]] : nil;
}

@implementation TGTDLibClient (SavedMessages)

- (NSDictionary *)tg_savedRequest:(NSDictionary *)request
                            prefix:(NSString *)prefix
                           timeout:(NSTimeInterval)timeout
                              code:(NSInteger)code
                             error:(NSError **)error {
    return [self sendTDLibRequestAndWaitForExtra:request
                                     extraPrefix:prefix
                                         timeout:timeout
                                       errorCode:code
                                           error:error];
}

- (NSString *)tg_savedTopicTitle:(NSDictionary *)topic timeout:(NSTimeInterval)timeout {
    NSDictionary *type = [[topic objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [topic objectForKey:@"type"] : [NSDictionary dictionary];
    NSString *kind = TGSavedString([type objectForKey:@"@type"]);
    if ([kind isEqualToString:@"savedMessagesTopicTypeMyNotes"]) {
        return @"Мои заметки";
    }
    if ([kind isEqualToString:@"savedMessagesTopicTypeAuthorHidden"]) {
        return @"Скрытый автор";
    }
    if ([kind isEqualToString:@"savedMessagesTopicTypeSavedFromChat"]) {
        NSNumber *chatID = TGSavedID([type objectForKey:@"chat_id"]);
        NSDictionary *chat = chatID
            ? [self chatSummaryForChatID:chatID downloadAvatar:NO timeout:MIN(timeout, 1.2) error:NULL]
            : nil;
        NSString *title = TGSavedString([chat objectForKey:@"title"]);
        if ([title length] > 0) {
            return title;
        }
        return chatID ? [NSString stringWithFormat:@"Чат %@", chatID] : @"Пересланное";
    }
    return @"Избранное";
}

- (NSArray *)savedMessagesTopicSummariesWithLimit:(NSUInteger)limit
                                           timeout:(NSTimeInterval)timeout
                                             error:(NSError **)error {
    NSUInteger boundedLimit = MIN(MAX((NSUInteger)1, limit), (NSUInteger)100);
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"loadSavedMessagesTopics", @"@type",
                             [NSNumber numberWithUnsignedInteger:boundedLimit], @"limit",
                             nil];
    NSError *requestError = nil;
    [self tg_savedRequest:request
                   prefix:@"telegraphica-saved-topics"
                  timeout:timeout
                     code:440
                    error:&requestError];
    if (requestError && [self tdlibErrorCodeFromError:requestError] != 404) {
        if (error) {
            *error = requestError;
        }
        return nil;
    }

    NSArray *topics = [self savedMessagesTopicObjectsSnapshot];
    NSMutableArray *summaries = [NSMutableArray arrayWithCapacity:[topics count]];
    NSUInteger index = 0;
    for (index = 0; index < [topics count]; index++) {
        NSDictionary *topic = [topics objectAtIndex:index];
        NSNumber *topicID = TGSavedID([topic objectForKey:@"id"]);
        if (!topicID) {
            continue;
        }
        NSDictionary *lastMessage = [[topic objectForKey:@"last_message"] isKindOfClass:[NSDictionary class]]
            ? [topic objectForKey:@"last_message"] : nil;
        NSArray *previewItems = lastMessage
            ? [self messagePreviewItemsFromMessages:[NSArray arrayWithObject:lastMessage] chatID:nil]
            : [NSArray array];
        NSString *preview = @"";
        if ([previewItems count] > 0) {
            id candidate = [[previewItems objectAtIndex:0] valueForKey:@"preview"];
            preview = [candidate isKindOfClass:[NSString class]] ? candidate : @"";
        }
        [summaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              topicID, @"topic_id",
                              [self tg_savedTopicTitle:topic timeout:timeout], @"title",
                              [NSNumber numberWithBool:[[topic objectForKey:@"is_pinned"] boolValue]], @"is_pinned",
                              TGSavedID([topic objectForKey:@"order"]) ?: [NSNumber numberWithLongLong:0LL], @"order",
                              preview ?: @"", @"preview",
                              topic, @"raw_topic",
                              nil]];
    }
    return summaries;
}

- (NSArray *)savedMessagesHistoryForTopicID:(NSNumber *)topicID
                                       limit:(NSUInteger)limit
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error {
    if (!topicID) {
        return [NSArray array];
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getSavedMessagesTopicHistory", @"@type",
                             topicID, @"saved_messages_topic_id",
                             [NSNumber numberWithLongLong:0LL], @"from_message_id",
                             [NSNumber numberWithInt:0], @"offset",
                             [NSNumber numberWithUnsignedInteger:MIN(MAX((NSUInteger)1, limit), (NSUInteger)100)], @"limit",
                             nil];
    NSDictionary *response = [self tg_savedRequest:request
                                            prefix:@"telegraphica-saved-history"
                                           timeout:timeout
                                              code:441
                                             error:error];
    NSArray *messages = [[response objectForKey:@"messages"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"messages"] : [NSArray array];
    return [self messagePreviewItemsFromMessages:messages chatID:nil];
}

- (NSArray *)savedMessagesTagSummariesForTopicID:(NSNumber *)topicID
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError **)error {
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getSavedMessagesTags", @"@type",
                             topicID ?: [NSNumber numberWithLongLong:0LL], @"saved_messages_topic_id",
                             nil];
    NSDictionary *response = [self tg_savedRequest:request
                                            prefix:@"telegraphica-saved-tags"
                                           timeout:timeout
                                              code:442
                                             error:error];
    NSArray *tags = [[response objectForKey:@"tags"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"tags"] : [NSArray array];
    NSMutableArray *summaries = [NSMutableArray arrayWithCapacity:[tags count]];
    NSUInteger index = 0;
    for (index = 0; index < [tags count]; index++) {
        NSDictionary *entry = [[tags objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [tags objectAtIndex:index] : nil;
        NSDictionary *reaction = [[entry objectForKey:@"tag"] isKindOfClass:[NSDictionary class]]
            ? [entry objectForKey:@"tag"] : [NSDictionary dictionary];
        NSString *reactionType = TGSavedString([reaction objectForKey:@"@type"]);
        NSString *symbol = [reactionType isEqualToString:@"reactionTypeEmoji"]
            ? TGSavedString([reaction objectForKey:@"emoji"]) : @"◇";
        NSString *label = TGSavedString([entry objectForKey:@"label"]);
        if ([label length] == 0) {
            label = symbol;
        }
        [summaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              symbol, @"symbol",
                              label, @"label",
                              [NSNumber numberWithInteger:[[entry objectForKey:@"count"] integerValue]], @"count",
                              reaction, @"reaction",
                              nil]];
    }
    return summaries;
}

- (BOOL)setSavedMessagesTopicID:(NSNumber *)topicID
                         pinned:(BOOL)pinned
                        timeout:(NSTimeInterval)timeout
                          error:(NSError **)error {
    if (!topicID) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"toggleSavedMessagesTopicIsPinned", @"@type",
                             topicID, @"saved_messages_topic_id",
                             [NSNumber numberWithBool:pinned], @"is_pinned",
                             nil];
    NSDictionary *response = [self tg_savedRequest:request
                                            prefix:@"telegraphica-saved-pin"
                                           timeout:timeout
                                              code:443
                                             error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

@end
