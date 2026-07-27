#import "TGTDLibClient.h"

@interface TGTDLibClient (SavedMessages)

- (NSArray *)savedMessagesTopicSummariesWithLimit:(NSUInteger)limit
                                           timeout:(NSTimeInterval)timeout
                                             error:(NSError **)error;
- (NSArray *)savedMessagesHistoryForTopicID:(NSNumber *)topicID
                                       limit:(NSUInteger)limit
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error;
- (NSArray *)savedMessagesTagSummariesForTopicID:(NSNumber *)topicID
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError **)error;
- (BOOL)setSavedMessagesTopicID:(NSNumber *)topicID
                         pinned:(BOOL)pinned
                        timeout:(NSTimeInterval)timeout
                          error:(NSError **)error;

@end
