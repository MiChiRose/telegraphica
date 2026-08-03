#import "TGTDLibClient.h"

@interface TGTDLibClient (Search)

- (NSArray *)searchMessagePreviewItemsForChatID:(NSNumber *)chatID
                                messageThreadID:(NSNumber *)messageThreadID
                               messageTopicKind:(NSString *)messageTopicKind
                                          query:(NSString *)query
                                         filter:(NSString *)filter
                                  fromMessageID:(NSNumber *)fromMessageID
                                          limit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error;
- (NSArray *)globalSearchMessagePreviewItemsWithQuery:(NSString *)query
                                               filter:(NSString *)filter
                                               offset:(NSString **)offset
                                                limit:(NSUInteger)limit
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error;

@end
