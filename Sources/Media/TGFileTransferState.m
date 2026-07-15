#import "TGFileTransferState.h"

@implementation TGFileTransferState

@synthesize state = _state;
@synthesize progress = _progress;
@synthesize progressKnown = _progressKnown;
@synthesize message = _message;

+ (TGFileTransferState *)stateWithKind:(TGFileTransferStateKind)kind message:(NSString *)message {
    TGFileTransferState *state = [[[TGFileTransferState alloc] init] autorelease];
    state.state = kind;
    state.message = message;
    state.progress = 0.0;
    state.progressKnown = NO;
    return state;
}

+ (TGFileTransferState *)stateWithState:(TGFileTransferStateKind)stateKind progressKnown:(BOOL)progressKnown progress:(double)progress message:(NSString *)message {
    TGFileTransferState *state = [[[TGFileTransferState alloc] init] autorelease];
    state.state = stateKind;
    state.message = message;
    state.progress = progress;
    state.progressKnown = progressKnown;
    return state;
}

- (void)dealloc {
    [_message release];
    [super dealloc];
}

@end
