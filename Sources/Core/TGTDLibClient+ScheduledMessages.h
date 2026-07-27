#import "TGTDLibClient.h"

@interface TGTDLibClient (ScheduledMessages)

- (NSArray *)scheduledMessageSummariesForChatID:(NSNumber *)chatID
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError **)error;
- (BOOL)setScheduledMessageInChatID:(NSNumber *)chatID
                          messageID:(NSNumber *)messageID
                           sendDate:(NSNumber *)sendDate
                     sendWhenOnline:(BOOL)sendWhenOnline
                            timeout:(NSTimeInterval)timeout
                              error:(NSError **)error;

@end
