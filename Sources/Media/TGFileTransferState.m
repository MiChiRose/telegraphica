#import "TGFileTransferState.h"
#import "TGAttachmentDescriptor.h"

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

@implementation TGAttachmentQueueItem

@synthesize descriptor = _descriptor;
@synthesize transferState = _transferState;
@synthesize index = _index;

+ (TGAttachmentQueueItem *)itemWithDescriptor:(TGAttachmentDescriptor *)descriptor index:(NSUInteger)index state:(TGFileTransferStateKind)state message:(NSString *)message {
    TGAttachmentQueueItem *item = [[[TGAttachmentQueueItem alloc] init] autorelease];
    item.descriptor = descriptor;
    item.index = index;
    item.transferState = [TGFileTransferState stateWithState:state
                                               progressKnown:NO
                                                    progress:0.0
                                                     message:message];
    return item;
}

- (BOOL)isFailed {
    return self.transferState.state == TGFileTransferStateFailed;
}

- (BOOL)isTerminal {
    TGFileTransferStateKind state = self.transferState.state;
    return state == TGFileTransferStateSucceeded || state == TGFileTransferStateFailed || state == TGFileTransferStateCancelled;
}

- (void)dealloc {
    [_descriptor release];
    [_transferState release];
    [super dealloc];
}

@end
