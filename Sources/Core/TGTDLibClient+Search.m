#import "TGTDLibClient+Search.h"

@interface TGTDLibClient (SearchPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSArray *)messagesFromSearchResponse:(NSDictionary *)response error:(NSError **)error;
- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID;
@end

@implementation TGTDLibClient (Search)

- (NSDictionary *)searchMessagesFilterForName:(NSString *)filterName {
    if (![filterName isKindOfClass:[NSString class]] || [filterName length] == 0 || [filterName isEqualToString:@"all"]) {
        return (NSDictionary *)[NSNull null];
    }
    NSString *type = nil;
    if ([filterName isEqualToString:@"photos"]) {
        type = @"searchMessagesFilterPhoto";
    } else if ([filterName isEqualToString:@"videos"]) {
        type = @"searchMessagesFilterVideo";
    } else if ([filterName isEqualToString:@"documents"]) {
        type = @"searchMessagesFilterDocument";
    } else if ([filterName isEqualToString:@"links"]) {
        type = @"searchMessagesFilterUrl";
    } else if ([filterName isEqualToString:@"voice"]) {
        type = @"searchMessagesFilterVoiceNote";
    } else if ([filterName isEqualToString:@"audio"]) {
        type = @"searchMessagesFilterAudio";
    } else if ([filterName isEqualToString:@"animations"] || [filterName isEqualToString:@"gifs"]) {
        type = @"searchMessagesFilterAnimation";
    } else if ([filterName isEqualToString:@"videoNotes"]) {
        type = @"searchMessagesFilterVideoNote";
    } else if ([filterName isEqualToString:@"stickers"]) {
        type = @"searchMessagesFilterSticker";
    } else if ([filterName isEqualToString:@"polls"]) {
        type = @"searchMessagesFilterPoll";
    }
    if ([type length] == 0) {
        return (NSDictionary *)[NSNull null];
    }
    return [NSDictionary dictionaryWithObject:type forKey:@"@type"];
}

- (NSArray *)searchMessagePreviewItemsForChatID:(NSNumber *)chatID
                                messageThreadID:(NSNumber *)messageThreadID
                               messageTopicKind:(NSString *)messageTopicKind
                                          query:(NSString *)query
                                         filter:(NSString *)filter
                                  fromMessageID:(NSNumber *)fromMessageID
                                          limit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing for search." code:93];
        }
        return nil;
    }
    NSString *safeQuery = [query isKindOfClass:[NSString class]] ? query : @"";
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }

    NSMutableArray *requests = [NSMutableArray array];
    NSDictionary *filterObject = [self searchMessagesFilterForName:filter];
    long long anchorMessageID = ([fromMessageID respondsToSelector:@selector(longLongValue)] ? [fromMessageID longLongValue] : 0LL);

    NSMutableDictionary *baseRequest = [NSMutableDictionary dictionary];
    [baseRequest setObject:@"searchChatMessages" forKey:@"@type"];
    [baseRequest setObject:chatID forKey:@"chat_id"];
    [baseRequest setObject:safeQuery forKey:@"query"];
    [baseRequest setObject:[NSNull null] forKey:@"sender_id"];
    [baseRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
    [baseRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [baseRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [baseRequest setObject:filterObject forKey:@"filter"];

    if ([messageThreadID respondsToSelector:@selector(longLongValue)]) {
        if ([messageTopicKind isEqualToString:@"thread"]) {
            NSMutableDictionary *topicRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
            NSDictionary *messageThread = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"messageTopicThread", @"@type",
                                           [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"message_thread_id",
                                           nil];
            [topicRequest setObject:messageThread forKey:@"topic_id"];
            [requests addObject:topicRequest];
        }
        NSMutableDictionary *forumRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
        NSDictionary *forumTopic = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"messageTopicForum", @"@type",
                                    [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"forum_topic_id",
                                    nil];
        [forumRequest setObject:forumTopic forKey:@"topic_id"];
        [requests addObject:forumRequest];

        NSMutableDictionary *legacyThreadRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        [requests addObject:legacyThreadRequest];
    }
    [requests addObject:baseRequest];

    NSError *lastError = nil;
    NSUInteger index = 0;
    for (index = 0; index < [requests count]; index++) {
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:[requests objectAtIndex:index]
                                                            extraPrefix:@"telegraphica-search-chat-messages"
                                                                timeout:timeout
                                                              errorCode:93
                                                                  error:&lastError];
        NSArray *messages = response ? [self messagesFromSearchResponse:response error:&lastError] : nil;
        if (messages) {
            return [self messagePreviewItemsFromMessages:messages chatID:chatID];
        }
    }
    if (error) {
        *error = lastError;
    }
    return nil;
}

- (NSArray *)globalSearchMessagePreviewItemsWithQuery:(NSString *)query
                                               filter:(NSString *)filter
                                               offset:(NSString **)offset
                                                limit:(NSUInteger)limit
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error {
    NSString *safeQuery = [query isKindOfClass:[NSString class]] ? query : @"";
    if ([safeQuery length] == 0) {
        return [NSArray array];
    }
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchMessages" forKey:@"@type"];
    [request setObject:safeQuery forKey:@"query"];
    [request setObject:(offset && [*offset length] > 0 ? *offset : @"") forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [request setObject:[self searchMessagesFilterForName:filter] forKey:@"filter"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"min_date"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"max_date"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-search-global-messages"
                                                           timeout:timeout
                                                         errorCode:94
                                                             error:error];
    NSArray *messages = response ? [self messagesFromSearchResponse:response error:error] : nil;
    if (!messages) {
        return nil;
    }
    if (offset) {
        id nextOffset = [response objectForKey:@"next_offset"];
        if ([nextOffset isKindOfClass:[NSString class]]) {
            *offset = [(NSString *)nextOffset copy];
        } else {
            *offset = [@"" copy];
        }
    }
    return [self messagePreviewItemsFromMessages:messages chatID:nil];
}

@end
