#import "TGTDLibClient.h"

@interface TGTDLibClient (Administration)

- (NSDictionary *)chatAdministrationSummaryForChatID:(NSNumber *)chatID
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error;
- (NSDictionary *)createInviteLinkForChatID:(NSNumber *)chatID
                                        name:(NSString *)name
                            expirationPeriod:(NSInteger)expirationPeriod
                                 memberLimit:(NSInteger)memberLimit
                          createsJoinRequest:(BOOL)createsJoinRequest
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error;
- (BOOL)revokeInviteLink:(NSString *)inviteLink
               forChatID:(NSNumber *)chatID
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error;
- (BOOL)processJoinRequestForUserID:(NSNumber *)userID
                           chatID:(NSNumber *)chatID
                          approve:(BOOL)approve
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error;
- (BOOL)setSlowModeDelay:(NSInteger)seconds
               forChatID:(NSNumber *)chatID
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error;

@end
