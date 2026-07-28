#import "TGCallCoordinator.h"

#import "TGCallAudioEngine.h"
#import "TGCallWindowController.h"
#import "../Core/TGTDLibClient.h"
#import "../Core/TGTDLibClient+Calls.h"
#import "../UI/TGLocalization.h"
#include <math.h>

NSString * const TGCallCoordinatorDidFinishCallNotification = @"TGCallCoordinatorDidFinishCallNotification";

@interface TGCallCoordinator () <TGCallAudioEngineDelegate, TGCallWindowControllerDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) TGCallWindowController *callWindowController;
@property (nonatomic, retain) TGCallAudioEngine *audioEngine;
@property (nonatomic, retain) NSNumber *activeCallID;
@property (nonatomic, retain) NSDictionary *activeProfile;
@property (nonatomic, assign) BOOL mockCall;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL finishing;
@end

@implementation TGCallCoordinator

@synthesize client = _client;
@synthesize callWindowController = _callWindowController;
@synthesize audioEngine = _audioEngine;
@synthesize activeCallID = _activeCallID;
@synthesize activeProfile = _activeProfile;
@synthesize mockCall = _mockCall;
@synthesize outgoing = _outgoing;
@synthesize finishing = _finishing;

- (id)initWithClient:(TGTDLibClient *)client {
    self = [super init];
    if (self) {
        self.client = client;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callDidUpdate:)
                                                     name:TGTDLibCallDidUpdateNotification
                                                   object:client];
    }
    return self;
}

- (BOOL)transportAvailable {
    return [TGCallAudioEngine isTransportAvailable];
}

- (NSDictionary *)mockProfile {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            TGLoc(@"calls.demo.contact"), @"display_name",
            nil];
}

- (void)presentProfile:(NSDictionary *)profile outgoing:(BOOL)outgoing mock:(BOOL)mock {
    if (self.callWindowController) {
        [[self.callWindowController window] makeKeyAndOrderFront:nil];
        return;
    }
    self.activeProfile = profile;
    self.outgoing = outgoing;
    self.mockCall = mock;
    self.finishing = NO;
    self.callWindowController = [[[TGCallWindowController alloc] initWithProfile:profile outgoing:outgoing] autorelease];
    [self.callWindowController setDelegate:self];
    [self.callWindowController showWindow:nil];
    [[self.callWindowController window] makeKeyAndOrderFront:nil];
}

- (void)startAudioCallToProfile:(NSDictionary *)profile {
    if (self.callWindowController) {
        [[self.callWindowController window] makeKeyAndOrderFront:nil];
        return;
    }
    NSNumber *userID = [profile objectForKey:@"user_id"];
    if (![userID respondsToSelector:@selector(longLongValue)] || !self.transportAvailable) {
        NSBeep();
        return;
    }
    [self presentProfile:profile outgoing:YES mock:NO];
    TGTDLibClient *client = [self.client retain];
    NSDictionary *retainedProfile = [profile retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSNumber *callID = [[client createAudioCallToUserID:userID timeout:10.0 error:&error] retain];
        NSString *failure = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.activeProfile == retainedProfile && !self.finishing) {
                if (callID) {
                    self.activeCallID = callID;
                } else {
                    [self.callWindowController setPresentationState:TGCallPresentationStateFailed detail:failure];
                    [self finishCallAfterDelay:4.0];
                }
            }
            [callID release];
            [failure release];
            [retainedProfile release];
            [client release];
        });
        [pool drain];
    });
}

- (void)startMockOutgoingCall {
    if (self.callWindowController) {
        [[self.callWindowController window] makeKeyAndOrderFront:nil];
        return;
    }
    [self presentProfile:[self mockProfile] outgoing:YES mock:YES];
    [self performSelector:@selector(connectMockCall) withObject:nil afterDelay:2.2];
}

- (void)startMockIncomingCall {
    if (self.callWindowController) {
        [[self.callWindowController window] makeKeyAndOrderFront:nil];
        return;
    }
    [self presentProfile:[self mockProfile] outgoing:NO mock:YES];
}

- (void)connectMockCall {
    if (self.mockCall && !self.finishing && self.callWindowController) {
        [self.callWindowController setPresentationState:TGCallPresentationStateConnected detail:nil];
        [self.callWindowController updateSignalBars:5U];
    }
}

- (void)callDidUpdate:(NSNotification *)notification {
    NSDictionary *call = [[notification userInfo] objectForKey:@"call"];
    NSNumber *callID = [[call objectForKey:@"id"] respondsToSelector:@selector(integerValue)]
        ? [NSNumber numberWithInteger:[[call objectForKey:@"id"] integerValue]] : nil;
    NSNumber *userID = [[call objectForKey:@"user_id"] respondsToSelector:@selector(longLongValue)]
        ? [NSNumber numberWithLongLong:[[call objectForKey:@"user_id"] longLongValue]] : nil;
    BOOL outgoing = [[call objectForKey:@"is_outgoing"] boolValue];
    NSDictionary *state = [[call objectForKey:@"state"] isKindOfClass:[NSDictionary class]]
        ? [call objectForKey:@"state"] : nil;
    NSString *stateType = [state objectForKey:@"@type"];
    if (!self.callWindowController && !outgoing &&
        ([stateType isEqualToString:@"callStatePending"] ||
         [stateType isEqualToString:@"callStateExchangingKeys"])) {
        NSDictionary *fallbackProfile = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSString stringWithFormat:@"User %@", userID], @"display_name",
                                         userID, @"user_id",
                                         nil];
        [self presentProfile:fallbackProfile
                    outgoing:NO
                        mock:NO];
        self.activeCallID = callID;
        TGTDLibClient *client = [self.client retain];
        NSNumber *retainedUserID = [userID retain];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            NSDictionary *profile = [[client userProfileSummaryForUserID:retainedUserID
                                                                  timeout:3.0
                                                                    error:NULL] retain];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (profile && self.callWindowController &&
                    [self.activeCallID isEqualToNumber:callID]) {
                    self.activeProfile = profile;
                    [self.callWindowController updateProfile:profile];
                }
                [profile release];
                [retainedUserID release];
                [client release];
            });
            [pool drain];
        });
    }
    if (!self.callWindowController || self.mockCall ||
        (self.activeCallID && ![self.activeCallID isEqualToNumber:callID])) {
        return;
    }
    if (!self.activeCallID) {
        self.activeCallID = callID;
    }
    if ([stateType isEqualToString:@"callStateExchangingKeys"]) {
        [self.callWindowController setPresentationState:TGCallPresentationStateConnecting detail:nil];
    } else if ([stateType isEqualToString:@"callStateReady"]) {
        if (!self.audioEngine) {
            self.audioEngine = [[[TGCallAudioEngine alloc] init] autorelease];
            [self.audioEngine setDelegate:self];
            NSError *transportError = nil;
            if (![self.audioEngine startWithCall:call error:&transportError]) {
                [self.callWindowController setPresentationState:TGCallPresentationStateFailed
                                                          detail:[transportError localizedDescription]];
                [self finishRealCallDisconnected:YES];
            }
        }
    } else if ([stateType isEqualToString:@"callStateDiscarded"]) {
        [self.callWindowController setPresentationState:TGCallPresentationStateEnded detail:nil];
        [self finishCallAfterDelay:4.0];
    } else if ([stateType isEqualToString:@"callStateError"]) {
        NSString *message = [[[state objectForKey:@"error"] objectForKey:@"message"] description];
        [self.callWindowController setPresentationState:TGCallPresentationStateFailed detail:message];
        [self finishCallAfterDelay:4.0];
    }
}

- (void)callAudioEngine:(TGCallAudioEngine *)engine didChangeState:(TGCallAudioEngineState)state {
    (void)engine;
    if (state == TGCallAudioEngineStateEstablished) {
        [self.callWindowController setPresentationState:TGCallPresentationStateConnected detail:nil];
    } else if (state == TGCallAudioEngineStateReconnecting) {
        [self.callWindowController setPresentationState:TGCallPresentationStateReconnecting detail:nil];
    } else if (state == TGCallAudioEngineStateFailed) {
        [self.callWindowController setPresentationState:TGCallPresentationStateFailed detail:nil];
        [self finishRealCallDisconnected:YES];
    }
}

- (void)callAudioEngine:(TGCallAudioEngine *)engine didChangeSignalBars:(NSUInteger)signalBars {
    (void)engine;
    [self.callWindowController updateSignalBars:signalBars];
}

- (void)callWindowControllerDidRequestAnswer:(TGCallWindowController *)controller {
    if (self.mockCall) {
        [controller setPresentationState:TGCallPresentationStateConnected detail:nil];
        [controller updateSignalBars:5U];
        return;
    }
    NSNumber *callID = [self.activeCallID retain];
    TGTDLibClient *client = [self.client retain];
    [controller setPresentationState:TGCallPresentationStateConnecting detail:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        BOOL accepted = [client acceptAudioCallWithID:callID timeout:10.0 error:&error];
        NSString *failure = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!accepted && self.callWindowController == controller) {
                [controller setPresentationState:TGCallPresentationStateFailed detail:failure];
                [self finishCallAfterDelay:4.0];
            }
            [failure release];
            [client release];
            [callID release];
        });
        [pool drain];
    });
}

- (void)callWindowController:(TGCallWindowController *)controller
 didRequestMicrophoneMuted:(BOOL)muted {
    (void)controller;
    [self.audioEngine setMicrophoneMuted:muted];
}

- (void)callWindowControllerDidRequestHangUp:(TGCallWindowController *)controller {
    if (self.finishing) {
        return;
    }
    [controller setPresentationState:TGCallPresentationStateEnded detail:nil];
    if (self.mockCall) {
        [self finishCallAfterDelay:4.0];
    } else {
        [self finishRealCallDisconnected:NO];
    }
}

- (void)finishRealCallDisconnected:(BOOL)disconnected {
    [self.audioEngine stop];
    NSNumber *relayID = [self.audioEngine preferredRelayID];
    NSNumber *callID = [self.activeCallID retain];
    TGTDLibClient *client = [self.client retain];
    NSUInteger duration = (NSUInteger)floor([self.callWindowController connectedDuration]);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [client discardAudioCallWithID:callID
                          disconnected:disconnected
                              duration:duration
                          connectionID:relayID
                               timeout:8.0
                                 error:NULL];
        [callID release];
        [client release];
        [pool drain];
    });
    [self finishCallAfterDelay:4.0];
}

- (void)finishCallAfterDelay:(NSTimeInterval)delay {
    if (self.finishing) {
        return;
    }
    self.finishing = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connectMockCall) object:nil];
    [self.callWindowController closeAfterDelay:delay];
    [self performSelector:@selector(resetCall) withObject:nil afterDelay:(delay + 0.2)];
}

- (void)resetCall {
    [self.audioEngine stop];
    self.audioEngine = nil;
    self.callWindowController = nil;
    self.activeCallID = nil;
    self.activeProfile = nil;
    self.mockCall = NO;
    self.finishing = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:TGCallCoordinatorDidFinishCallNotification
                                                        object:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_audioEngine stop];
    [_client release];
    [_callWindowController release];
    [_audioEngine release];
    [_activeCallID release];
    [_activeProfile release];
    [super dealloc];
}

@end
