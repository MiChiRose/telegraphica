#import "TGTDLibClient.h"

@interface TGTDLibClient (MessageTypes)

- (NSString *)sendVideoNoteMessageToChatID:(NSNumber *)chatID
                           messageThreadID:(NSNumber *)messageThreadID
                          messageTopicKind:(NSString *)messageTopicKind
                                 localPath:(NSString *)localPath
                          replyToMessageID:(NSNumber *)replyToMessageID
                                   timeout:(NSTimeInterval)timeout
                                     error:(NSError **)error;
- (NSString *)sendVenueMessageToChatID:(NSNumber *)chatID
                       messageThreadID:(NSNumber *)messageThreadID
                      messageTopicKind:(NSString *)messageTopicKind
                              latitude:(double)latitude
                             longitude:(double)longitude
                                 title:(NSString *)title
                               address:(NSString *)address
                      replyToMessageID:(NSNumber *)replyToMessageID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error;
- (NSString *)sendLiveLocationMessageToChatID:(NSNumber *)chatID
                              messageThreadID:(NSNumber *)messageThreadID
                             messageTopicKind:(NSString *)messageTopicKind
                                     latitude:(double)latitude
                                    longitude:(double)longitude
                                   livePeriod:(NSInteger)livePeriod
                             replyToMessageID:(NSNumber *)replyToMessageID
                                      timeout:(NSTimeInterval)timeout
                                        error:(NSError **)error;
- (NSString *)sendDiceMessageToChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                                emoji:(NSString *)emoji
                     replyToMessageID:(NSNumber *)replyToMessageID
                              timeout:(NSTimeInterval)timeout
                                error:(NSError **)error;
- (NSString *)sendQuizMessageToChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                             question:(NSString *)question
                              options:(NSArray *)options
                   correctOptionIndex:(NSInteger)correctOptionIndex
                          explanation:(NSString *)explanation
                            anonymous:(BOOL)anonymous
                              timeout:(NSTimeInterval)timeout
                                error:(NSError **)error;

@end
