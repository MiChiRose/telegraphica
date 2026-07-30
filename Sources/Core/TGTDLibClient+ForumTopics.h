#import "TGTDLibClient.h"

@interface TGTDLibClient (ForumTopics)

- (BOOL)createForumTopicInChatID:(NSNumber *)chatID
                            name:(NSString *)name
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;
- (BOOL)renameForumTopicInChatID:(NSNumber *)chatID
                         topicID:(NSNumber *)topicID
                            name:(NSString *)name
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;
- (BOOL)setForumTopicInChatID:(NSNumber *)chatID
                      topicID:(NSNumber *)topicID
                       closed:(BOOL)closed
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error;
- (BOOL)setForumTopicInChatID:(NSNumber *)chatID
                      topicID:(NSNumber *)topicID
                       pinned:(BOOL)pinned
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error;
- (BOOL)deleteForumTopicInChatID:(NSNumber *)chatID
                         topicID:(NSNumber *)topicID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;

@end
