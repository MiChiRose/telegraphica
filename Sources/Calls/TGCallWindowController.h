#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, TGCallPresentationState) {
    TGCallPresentationStateCalling = 0,
    TGCallPresentationStateIncoming = 1,
    TGCallPresentationStateConnecting = 2,
    TGCallPresentationStateConnected = 3,
    TGCallPresentationStateReconnecting = 4,
    TGCallPresentationStateEnded = 5,
    TGCallPresentationStateFailed = 6
};

@class TGCallWindowController;

@protocol TGCallWindowControllerDelegate <NSObject>
- (void)callWindowControllerDidRequestAnswer:(TGCallWindowController *)controller;
- (void)callWindowController:(TGCallWindowController *)controller didRequestMicrophoneMuted:(BOOL)muted;
- (void)callWindowController:(TGCallWindowController *)controller didRequestSpeakerMuted:(BOOL)muted;
- (void)callWindowController:(TGCallWindowController *)controller didRequestCameraEnabled:(BOOL)enabled;
- (void)callWindowControllerDidRequestHangUp:(TGCallWindowController *)controller;
@end

@interface TGCallWindowController : NSWindowController <NSWindowDelegate>

@property (nonatomic, assign) id<TGCallWindowControllerDelegate> delegate;
@property (nonatomic, readonly, getter=isMicrophoneMuted) BOOL microphoneMuted;
@property (nonatomic, readonly, getter=isSpeakerMuted) BOOL speakerMuted;

- (id)initWithProfile:(NSDictionary *)profile outgoing:(BOOL)outgoing video:(BOOL)video;
- (void)updateProfile:(NSDictionary *)profile;
- (void)updateSignalBars:(NSUInteger)signalBars;
- (void)updateVideoImage:(NSImage *)image local:(BOOL)local;
- (void)updateRemoteVideoState:(NSInteger)state;
- (void)setPresentationState:(TGCallPresentationState)state detail:(NSString *)detail;
- (NSTimeInterval)connectedDuration;
- (void)closeAfterDelay:(NSTimeInterval)delay;

@end
