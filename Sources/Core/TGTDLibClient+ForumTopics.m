#import "TGTDLibClient+ForumTopics.h"

@interface TGTDLibClient (ForumTopicsPrivate)

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;

@end

@implementation TGTDLibClient (ForumTopics)

- (NSString *)tg_validForumTopicName:(NSString *)name error:(NSError **)error {
    if (![name isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Forum topic name is required." code:118];
        }
        return nil;
    }

    NSMutableString *singleLine = [NSMutableString stringWithString:name];
    [singleLine replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [singleLine length])];
    [singleLine replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [singleLine length])];
    NSString *trimmed = [singleLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] == 0 || [trimmed length] > 128) {
        if (error) {
            *error = [self errorWithDescription:@"Forum topic name must contain between 1 and 128 characters." code:118];
        }
        return nil;
    }
    return trimmed;
}

- (BOOL)tg_validateForumChatID:(NSNumber *)chatID topicID:(NSNumber *)topicID error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        (topicID && ![topicID respondsToSelector:@selector(longLongValue)])) {
        if (error) {
            *error = [self errorWithDescription:@"Forum topic action requires valid chat and topic identifiers." code:118];
        }
        return NO;
    }
    return YES;
}

- (BOOL)tg_forumTopicRequestSucceeded:(NSDictionary *)request
                           extraPrefix:(NSString *)extraPrefix
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:extraPrefix
                                                           timeout:timeout
                                                         errorCode:118
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *responseType = [response objectForKey:@"@type"];
    return ([responseType isEqualToString:@"ok"] || [responseType isEqualToString:@"forumTopicInfo"]);
}

- (BOOL)createForumTopicInChatID:(NSNumber *)chatID
                            name:(NSString *)name
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error {
    if (![self tg_validateForumChatID:chatID topicID:nil error:error]) {
        return NO;
    }
    NSString *validatedName = [self tg_validForumTopicName:name error:error];
    if (!validatedName) {
        return NO;
    }

    NSDictionary *icon = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"forumTopicIcon", @"@type",
                          [NSNumber numberWithUnsignedInt:0x6FB9F0], @"color",
                          [NSNumber numberWithLongLong:0], @"custom_emoji_id",
                          nil];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"createForumTopic", @"@type",
                             chatID, @"chat_id",
                             validatedName, @"name",
                             [NSNumber numberWithBool:NO], @"is_name_implicit",
                             icon, @"icon",
                             nil];
    return [self tg_forumTopicRequestSucceeded:request
                                   extraPrefix:@"telegraphica-create-forum-topic"
                                       timeout:timeout
                                         error:error];
}

- (BOOL)renameForumTopicInChatID:(NSNumber *)chatID
                         topicID:(NSNumber *)topicID
                            name:(NSString *)name
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error {
    if (![self tg_validateForumChatID:chatID topicID:topicID error:error]) {
        return NO;
    }
    NSString *validatedName = [self tg_validForumTopicName:name error:error];
    if (!validatedName) {
        return NO;
    }

    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"editForumTopic", @"@type",
                             chatID, @"chat_id",
                             topicID, @"forum_topic_id",
                             validatedName, @"name",
                             [NSNumber numberWithBool:NO], @"edit_icon_custom_emoji",
                             [NSNumber numberWithLongLong:0], @"icon_custom_emoji_id",
                             nil];
    return [self tg_forumTopicRequestSucceeded:request
                                   extraPrefix:@"telegraphica-edit-forum-topic"
                                       timeout:timeout
                                         error:error];
}

- (BOOL)setForumTopicInChatID:(NSNumber *)chatID
                      topicID:(NSNumber *)topicID
                       closed:(BOOL)closed
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error {
    if (![self tg_validateForumChatID:chatID topicID:topicID error:error]) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"toggleForumTopicIsClosed", @"@type",
                             chatID, @"chat_id",
                             topicID, @"forum_topic_id",
                             [NSNumber numberWithBool:closed], @"is_closed",
                             nil];
    return [self tg_forumTopicRequestSucceeded:request
                                   extraPrefix:@"telegraphica-toggle-forum-topic-closed"
                                       timeout:timeout
                                         error:error];
}

- (BOOL)setForumTopicInChatID:(NSNumber *)chatID
                      topicID:(NSNumber *)topicID
                       pinned:(BOOL)pinned
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error {
    if (![self tg_validateForumChatID:chatID topicID:topicID error:error]) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"toggleForumTopicIsPinned", @"@type",
                             chatID, @"chat_id",
                             topicID, @"forum_topic_id",
                             [NSNumber numberWithBool:pinned], @"is_pinned",
                             nil];
    return [self tg_forumTopicRequestSucceeded:request
                                   extraPrefix:@"telegraphica-toggle-forum-topic-pinned"
                                       timeout:timeout
                                         error:error];
}

- (BOOL)deleteForumTopicInChatID:(NSNumber *)chatID
                         topicID:(NSNumber *)topicID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error {
    if (![self tg_validateForumChatID:chatID topicID:topicID error:error]) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"deleteForumTopic", @"@type",
                             chatID, @"chat_id",
                             topicID, @"forum_topic_id",
                             nil];
    return [self tg_forumTopicRequestSucceeded:request
                                   extraPrefix:@"telegraphica-delete-forum-topic"
                                       timeout:timeout
                                         error:error];
}

@end
