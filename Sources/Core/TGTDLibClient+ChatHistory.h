#import "TGTDLibClient.h"

@interface TGTDLibClient (ChatHistory)

- (BOOL)deleteChatHistoryForChatID:(NSNumber *)chatID
                removeFromChatList:(BOOL)removeFromChatList
                             revoke:(BOOL)revoke
                            timeout:(NSTimeInterval)timeout
                              error:(NSError **)error;

@end
