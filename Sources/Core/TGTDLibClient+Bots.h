#import "TGTDLibClient.h"

@interface TGTDLibClient (Bots)

- (NSDictionary *)botInteractionSummaryForUserID:(NSNumber *)userID
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError **)error;
- (NSDictionary *)inlineQueryResultsForBotUserID:(NSNumber *)userID
                                          chatID:(NSNumber *)chatID
                                           query:(NSString *)query
                                          offset:(NSString *)offset
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError **)error;
- (BOOL)sendInlineQueryResultID:(NSString *)resultID
                       queryID:(NSNumber *)queryID
                      toChatID:(NSNumber *)chatID
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error;
- (NSDictionary *)callbackQueryAnswerForChatID:(NSNumber *)chatID
                                      messageID:(NSNumber *)messageID
                                    buttonType:(NSDictionary *)buttonType
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error;
- (NSDictionary *)loginURLInfoForChatID:(NSNumber *)chatID
                               messageID:(NSNumber *)messageID
                                buttonID:(NSNumber *)buttonID
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error;
- (NSString *)resolvedLoginURLForChatID:(NSNumber *)chatID
                               messageID:(NSNumber *)messageID
                                buttonID:(NSNumber *)buttonID
                        allowWriteAccess:(BOOL)allowWriteAccess
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error;

@end
