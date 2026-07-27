#import "TGTDLibClient.h"

@interface TGTDLibClient (ChatMembers)

- (NSDictionary *)chatDetailsSummaryForChatID:(NSNumber *)chatID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error;
- (BOOL)addUserID:(NSNumber *)userID
         toChatID:(NSNumber *)chatID
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error;
- (BOOL)setUserID:(NSNumber *)userID
         inChatID:(NSNumber *)chatID
             role:(NSString *)role
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error;

@end
