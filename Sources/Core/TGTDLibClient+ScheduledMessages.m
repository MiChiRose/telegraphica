#import "TGTDLibClient+ScheduledMessages.h"

@interface TGTDLibClient (ScheduledMessagesPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSString *)messageContentPreviewForObject:(id)contentObject;
@end

@implementation TGTDLibClient (ScheduledMessages)

- (NSArray *)scheduledMessageSummariesForChatID:(NSNumber *)chatID
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || [chatID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:373];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatScheduledMessages", @"@type",
                             [NSNumber numberWithLongLong:[chatID longLongValue]], @"chat_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-scheduled-messages"
                                                            timeout:timeout
                                                          errorCode:374
                                                              error:error];
    NSArray *messages = [[response objectForKey:@"messages"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"messages"]
        : nil;
    if (![[response objectForKey:@"@type"] isEqualToString:@"messages"] || !messages) {
        if (error && response && !*error) {
            *error = [self errorWithDescription:@"TDLib did not return scheduled messages." code:375];
        }
        return nil;
    }
    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [messages count]; index++) {
        NSDictionary *message = [[messages objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [messages objectAtIndex:index]
            : nil;
        id messageID = [message objectForKey:@"id"];
        if (![messageID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
        NSString *preview = [self messageContentPreviewForObject:[message objectForKey:@"content"]];
        [summary setObject:[preview length] > 0 ? preview : @"[Message]" forKey:@"preview"];
        NSDictionary *state = [[message objectForKey:@"scheduling_state"] isKindOfClass:[NSDictionary class]]
            ? [message objectForKey:@"scheduling_state"]
            : nil;
        NSString *stateType = [state objectForKey:@"@type"];
        if ([stateType isEqualToString:@"messageSchedulingStateSendAtDate"] &&
            [[state objectForKey:@"send_date"] respondsToSelector:@selector(integerValue)]) {
            [summary setObject:[NSNumber numberWithInteger:[[state objectForKey:@"send_date"] integerValue]]
                        forKey:@"send_date"];
        } else if ([stateType isEqualToString:@"messageSchedulingStateSendWhenOnline"]) {
            [summary setObject:[NSNumber numberWithBool:YES] forKey:@"send_when_online"];
        }
        [summaries addObject:summary];
    }
    return summaries;
}

- (BOOL)setScheduledMessageInChatID:(NSNumber *)chatID
                          messageID:(NSNumber *)messageID
                           sendDate:(NSNumber *)sendDate
                     sendWhenOnline:(BOOL)sendWhenOnline
                            timeout:(NSTimeInterval)timeout
                              error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat and message identifiers are required." code:376];
        }
        return NO;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"editMessageSchedulingState" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
    if (sendWhenOnline) {
        [request setObject:[NSDictionary dictionaryWithObject:@"messageSchedulingStateSendWhenOnline"
                                                       forKey:@"@type"]
                    forKey:@"scheduling_state"];
    } else if ([sendDate respondsToSelector:@selector(integerValue)] && [sendDate integerValue] > 0) {
        NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"messageSchedulingStateSendAtDate", @"@type",
                               [NSNumber numberWithInteger:[sendDate integerValue]], @"send_date",
                               nil];
        [request setObject:state forKey:@"scheduling_state"];
    } else {
        [request setObject:[NSNull null] forKey:@"scheduling_state"];
    }
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-edit-scheduled-message"
                                                            timeout:timeout
                                                          errorCode:377
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not update the scheduled message." code:378];
    }
    return NO;
}

@end
