#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TGCallAudioEngineState) {
    TGCallAudioEngineStateWaiting = 0,
    TGCallAudioEngineStateConnecting = 1,
    TGCallAudioEngineStateEstablished = 2,
    TGCallAudioEngineStateReconnecting = 3,
    TGCallAudioEngineStateFailed = 4,
    TGCallAudioEngineStateStopped = 5
};

@class TGCallAudioEngine;

@protocol TGCallAudioEngineDelegate <NSObject>
- (void)callAudioEngine:(TGCallAudioEngine *)engine didChangeState:(TGCallAudioEngineState)state;
- (void)callAudioEngine:(TGCallAudioEngine *)engine didChangeSignalBars:(NSUInteger)signalBars;
@optional
- (void)callAudioEngine:(TGCallAudioEngine *)engine didEmitSignalingData:(NSData *)data;
@end

@interface TGCallAudioEngine : NSObject {
@private
    id<TGCallAudioEngineDelegate> _delegate;
    void *_transport;
    BOOL _running;
    NSNumber *_preferredRelayID;
}

@property (nonatomic, assign) id<TGCallAudioEngineDelegate> delegate;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSNumber *preferredRelayID;

+ (BOOL)isTransportAvailable;
+ (NSString *)transportVersion;
+ (NSArray *)protocolVersions;
+ (NSInteger)maximumProtocolLayer;
+ (BOOL)isOperatingSystemSupported;

- (BOOL)startWithCall:(NSDictionary *)call error:(NSError **)error;
- (void)receiveSignalingData:(NSData *)data;
- (void)setMicrophoneMuted:(BOOL)muted;
- (void)setSpeakerMuted:(BOOL)muted;
- (void)stop;

@end
