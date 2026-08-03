#import "TGTDLibClient.h"

@interface TGTDLibClient (Account)

- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)updateCurrentUserFirstName:(NSString *)firstName
                         lastName:(NSString *)lastName
                         username:(NSString *)username
                              bio:(NSString *)bio
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error;
- (BOOL)setCurrentUserProfilePhotoAtPath:(NSString *)localPath
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error;
- (NSDictionary *)activeSessionsSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)terminateActiveSessionWithID:(NSNumber *)sessionID
                             timeout:(NSTimeInterval)timeout
                               error:(NSError **)error;

@end

