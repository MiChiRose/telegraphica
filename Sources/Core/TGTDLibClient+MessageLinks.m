#import "TGTDLibClient+MessageLinks.h"

@interface TGTDLibClient (MessageLinksPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

@implementation TGTDLibClient (MessageLinks)

- (NSString *)messageLinkForChatID:(NSNumber *)chatID
                         messageID:(NSNumber *)messageID
                   inMessageThread:(BOOL)inMessageThread
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)] ||
        [chatID longLongValue] == 0LL ||
        [messageID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"Chat or message identifier is missing." code:433];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    @"getMessageLink", @"@type",
                                    [NSNumber numberWithLongLong:[chatID longLongValue]], @"chat_id",
                                    [NSNumber numberWithLongLong:[messageID longLongValue]], @"message_id",
                                    [NSNumber numberWithInteger:0], @"media_timestamp",
                                    [NSNumber numberWithBool:NO], @"for_album",
                                    [NSNumber numberWithBool:inMessageThread], @"in_message_thread",
                                    nil];
    NSError *currentSchemaError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-message-link"
                                                            timeout:timeout
                                                          errorCode:434
                                                              error:&currentSchemaError];

    if (!response) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest removeObjectForKey:@"in_message_thread"];
        [legacyRequest setObject:[NSNumber numberWithBool:inMessageThread] forKey:@"for_comment"];
        NSError *legacySchemaError = nil;
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:@"telegraphica-message-link-legacy"
                                                 timeout:timeout
                                               errorCode:435
                                                   error:&legacySchemaError];
        if (!response && error) {
            *error = legacySchemaError ? legacySchemaError : currentSchemaError;
        }
    }

    NSString *link = [[response objectForKey:@"link"] isKindOfClass:[NSString class]]
        ? [response objectForKey:@"link"]
        : nil;
    if (![[response objectForKey:@"@type"] isEqualToString:@"messageLink"] ||
        [link length] == 0) {
        if (error && !*error) {
            *error = [self errorWithDescription:@"TDLib did not provide a link for this message." code:436];
        }
        return nil;
    }
    return link;
}

@end
