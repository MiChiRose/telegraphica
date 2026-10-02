#import "TGTDLibClient.h"

@interface TGTDLibClient (MessageThreads)
// Resolves a channel post to its discussion chat and root message. Call off
// the main thread; failures leave the caller's navigation state untouched.
- (NSDictionary *)resolveMessageThreadForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end
