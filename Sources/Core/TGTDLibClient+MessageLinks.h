#import "TGTDLibClient.h"

@interface TGTDLibClient (MessageLinks)

- (NSString *)messageLinkForChatID:(NSNumber *)chatID
                         messageID:(NSNumber *)messageID
                   inMessageThread:(BOOL)inMessageThread
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error;

@end
