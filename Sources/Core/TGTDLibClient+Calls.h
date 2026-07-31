#import "TGTDLibClient.h"

@interface TGTDLibClient (Calls)

- (NSNumber *)createAudioCallToUserID:(NSNumber *)userID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error;
- (NSNumber *)createCallToUserID:(NSNumber *)userID
                         isVideo:(BOOL)isVideo
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
- (BOOL)discardCallWithID:(NSNumber *)callID
              disconnected:(BOOL)disconnected
                  duration:(NSUInteger)duration
                  isVideo:(BOOL)isVideo
              connectionID:(NSNumber *)connectionID
                   timeout:(NSTimeInterval)timeout
                     error:(NSError **)error;
- (BOOL)sendAudioCallSignalingData:(NSData *)data
                            callID:(NSNumber *)callID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error;
- (NSArray *)recentAudioCallSummariesWithLimit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error;

@end
