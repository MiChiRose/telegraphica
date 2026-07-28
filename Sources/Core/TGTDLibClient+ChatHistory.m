#import "TGTDLibClient+ChatHistory.h"

@interface TGTDLibClient (ChatHistoryPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

@implementation TGTDLibClient (ChatHistory)

- (BOOL)deleteChatHistoryForChatID:(NSNumber *)chatID
                removeFromChatList:(BOOL)removeFromChatList
                             revoke:(BOOL)revoke
                            timeout:(NSTimeInterval)timeout
                              error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || [chatID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:430];
        }
        return NO;
    }

    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"deleteChatHistory", @"@type",
                             [NSNumber numberWithLongLong:[chatID longLongValue]], @"chat_id",
                             [NSNumber numberWithBool:removeFromChatList], @"remove_from_chat_list",
                             [NSNumber numberWithBool:revoke], @"revoke",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-delete-chat-history"
                                                            timeout:timeout
                                                          errorCode:431
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not confirm deletion of the chat history."
                                        code:432];
    }
    return NO;
}

@end
