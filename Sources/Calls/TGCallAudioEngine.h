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
@end

@interface TGCallAudioEngine : NSObject {
@private
    id<TGCallAudioEngineDelegate> _delegate;
    void *_voip;
    BOOL _running;
    NSNumber *_preferredRelayID;
}

@property (nonatomic, assign) id<TGCallAudioEngineDelegate> delegate;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSNumber *preferredRelayID;

+ (BOOL)isTransportAvailable;
+ (NSString *)transportVersion;

- (BOOL)startWithCall:(NSDictionary *)call error:(NSError **)error;
- (void)setMicrophoneMuted:(BOOL)muted;
- (void)stop;

@end
