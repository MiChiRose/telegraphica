#import "TGTDLibClient.h"

@interface TGTDLibClient (Privacy)

- (NSDictionary *)privacyAndRetentionSummaryWithTimeout:(NSTimeInterval)timeout
                                                   error:(NSError **)error;
- (BOOL)setPrivacySettingType:(NSString *)settingType
                          rule:(NSString *)rule
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error;
- (BOOL)setBlockedSender:(NSDictionary *)sender
                 blocked:(BOOL)blocked
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error;
- (BOOL)setAccountTTLInDays:(NSInteger)days
                    timeout:(NSTimeInterval)timeout
                      error:(NSError **)error;
- (BOOL)setDefaultMessageAutoDeleteTime:(NSInteger)seconds
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error;
- (BOOL)setMessageAutoDeleteTime:(NSInteger)seconds
                       forChatID:(NSNumber *)chatID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;

@end
