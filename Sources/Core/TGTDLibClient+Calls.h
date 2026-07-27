#import "TGTDLibClient.h"

@interface TGTDLibClient (Calls)

- (NSNumber *)createAudioCallToUserID:(NSNumber *)userID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error;
- (BOOL)acceptAudioCallWithID:(NSNumber *)callID
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error;
- (BOOL)discardAudioCallWithID:(NSNumber *)callID
                  disconnected:(BOOL)disconnected
                      duration:(NSUInteger)duration
                  connectionID:(NSNumber *)connectionID
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error;

@end
