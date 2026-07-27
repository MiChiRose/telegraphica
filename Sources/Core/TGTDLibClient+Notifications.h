#import "TGTDLibClient.h"

@interface TGTDLibClient (Notifications)

- (NSDictionary *)chatNotificationSettingsSummaryForChatID:(NSNumber *)chatID
                                                    timeout:(NSTimeInterval)timeout
                                                      error:(NSError **)error;
- (NSArray *)chatNotificationExceptionSummariesWithTimeout:(NSTimeInterval)timeout
                                                      error:(NSError **)error;
- (BOOL)setChatNotificationMuteForChatID:(NSNumber *)chatID
                                 muteFor:(NSTimeInterval)muteFor
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error;
- (BOOL)setChatNotificationPreviewForChatID:(NSNumber *)chatID
                                showPreview:(BOOL)showPreview
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError **)error;
- (BOOL)resetChatNotificationSettingsForChatID:(NSNumber *)chatID
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error;

@end
