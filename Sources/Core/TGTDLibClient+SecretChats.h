#import "TGTDLibClient.h"

@interface TGTDLibClient (SecretChats)

- (NSDictionary *)secretChatSummaryForChatID:(NSNumber *)chatID
                                      timeout:(NSTimeInterval)timeout
                                        error:(NSError **)error;
- (BOOL)closeSecretChatForChatID:(NSNumber *)chatID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;

@end
