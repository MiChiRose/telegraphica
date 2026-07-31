#import <Foundation/Foundation.h>

@class TGTDLibClient;

extern NSString * const TGCallCoordinatorDidFinishCallNotification;

@interface TGCallCoordinator : NSObject

@property (nonatomic, readonly) BOOL transportAvailable;

- (id)initWithClient:(TGTDLibClient *)client;
- (void)startAudioCallToProfile:(NSDictionary *)profile;
- (void)startVideoCallToProfile:(NSDictionary *)profile;
- (void)startMockOutgoingCall;
- (void)startMockIncomingCall;

@end
