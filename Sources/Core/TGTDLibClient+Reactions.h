#import "TGTDLibClient.h"

@interface TGTDLibClient (Reactions)

- (NSArray *)availableStandardReactionEmojisForChatID:(NSNumber *)chatID
                                             messageID:(NSNumber *)messageID
                                               rowSize:(NSUInteger)rowSize
                                               timeout:(NSTimeInterval)timeout
                                                 error:(NSError **)error;

@end
