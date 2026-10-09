#import <Foundation/Foundation.h>
#import "TGTDLibClient.h"
#import "TGChatOpenState.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TGTDLibClient
@end
#pragma clang diagnostic pop

@interface AutomaticReadProbeClient : TGTDLibClient {
    TGChatOpenState *_state;
    NSMutableArray *_requests;
    BOOL _useLegacy;
    BOOL _closeDuringAuthorization;
    BOOL _reselectDuringAuthorization;
    BOOL _closeBeforeFallback;
    BOOL _ready;
    BOOL _acknowledgeOpen;
    BOOL _resetDuringAuthorization;
    NSUInteger _authorizationCalls;
}
@property (nonatomic, assign) BOOL useLegacy;
@property (nonatomic, assign) BOOL closeDuringAuthorization;
@property (nonatomic, assign) BOOL reselectDuringAuthorization;
@property (nonatomic, assign) BOOL closeBeforeFallback;
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, assign) BOOL acknowledgeOpen;
@property (nonatomic, assign) BOOL resetDuringAuthorization;
- (NSArray *)requests;
- (NSUInteger)authorizationCalls;
@end

@implementation AutomaticReadProbeClient
@synthesize useLegacy = _useLegacy, closeDuringAuthorization = _closeDuringAuthorization;
@synthesize reselectDuringAuthorization = _reselectDuringAuthorization;
@synthesize closeBeforeFallback = _closeBeforeFallback, ready = _ready;
@synthesize acknowledgeOpen = _acknowledgeOpen, resetDuringAuthorization = _resetDuringAuthorization;
- (id)init {
    if ((self = [super init])) {
        _state = [[TGChatOpenState alloc] init];
        _requests = [[NSMutableArray alloc] init];
        _ready = YES; _acknowledgeOpen = YES;
    }
    return self;
}
- (void)dealloc { [_state release]; [_requests release]; [super dealloc]; }
- (NSArray *)requests { return _requests; }
- (NSUInteger)authorizationCalls { return _authorizationCalls; }
- (void)setUserOpenedChatID:(NSNumber *)chatID {
    [_state setDesiredChatID:chatID];
    if (_acknowledgeOpen) {
        for (NSDictionary *request in [_state requestsForCurrentSelection]) {
            if ([[request objectForKey:@"@type"] isEqual:@"openChat"]) {
                [_state handleOpenResponse:[NSDictionary dictionaryWithObjectsAndKeys:
                    @"ok", @"@type", [request objectForKey:@"@extra"], @"@extra", nil]];
            }
        }
    }
}
- (NSNumber *)userOpenedChatSelectionGenerationForChatID:(NSNumber *)chatID {
    return [_state selectionGenerationForDesiredChatID:chatID];
}
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)timeout; (void)error; _authorizationCalls++;
    if (_closeDuringAuthorization) [_state setDesiredChatID:nil];
    if (_reselectDuringAuthorization) {
        [self setUserOpenedChatID:@2]; [self setUserOpenedChatID:@1];
    }
    if (_resetDuringAuthorization) { [_state resetTransport]; [self setUserOpenedChatID:@1]; }
    return _ready ? @"ready" : @"waitCode";
}
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)prefix
    timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    (void)prefix; (void)timeout; (void)errorCode;
    [_requests addObject:[[request copy] autorelease]];
    if (_useLegacy && [request objectForKey:@"source"]) {
        if (_closeBeforeFallback) [_state setDesiredChatID:nil];
        if (error) *error = [self errorWithDescription:@"synthetic schema error" code:400];
        return nil;
    }
    return [NSDictionary dictionaryWithObject:@"ok" forKey:@"@type"];
}
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    return [NSError errorWithDomain:@"AutomaticReadProbe" code:code userInfo:
        [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey]];
}
@end

static void Check(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static AutomaticReadProbeClient *Client(void) {
    return [[[AutomaticReadProbeClient alloc] init] autorelease];
}
static BOOL Automatic(TGTDLibClient *client, NSError **error) {
    return [client markVisibleMessagesAsReadForChatID:@1 messageThreadID:@7 messageTopicKind:@"forum"
        messageIDs:[NSArray arrayWithObjects:@501, @502, @503, nil] timeout:4.0 error:error];
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGChatOpenState *state = [[[TGChatOpenState alloc] init] autorelease];
    [state setDesiredChatID:@1];
    NSDictionary *open = [[state requestsForCurrentSelection] lastObject];
    Check(![state selectionGenerationForDesiredChatID:@1], "pending real openChat acknowledgement is ineligible");
    [state handleOpenResponse:[NSDictionary dictionaryWithObjectsAndKeys:
        @"error", @"@type", @400, @"code", [open objectForKey:@"@extra"], @"@extra", nil]];
    Check(![state selectionGenerationForDesiredChatID:@1], "failed real openChat is ineligible");
    [state resetTransport]; open = [[state requestsForCurrentSelection] lastObject];
    [state handleOpenResponse:[NSDictionary dictionaryWithObjectsAndKeys:
        @"ok", @"@type", [open objectForKey:@"@extra"], @"@extra", nil]];
    NSNumber *confirmedGeneration = [state selectionGenerationForDesiredChatID:@1];
    Check(confirmedGeneration != nil, "real acknowledged openChat supplies lease");
    [state resetTransport];
    Check(![state selectionGenerationForDesiredChatID:@1], "transport reset removes confirmed visibility");
    open = [[state requestsForCurrentSelection] lastObject];
    [state handleOpenResponse:[NSDictionary dictionaryWithObjectsAndKeys:
        @"ok", @"@type", [open objectForKey:@"@extra"], @"@extra", nil]];
    Check(![[state selectionGenerationForDesiredChatID:@1] isEqualToNumber:confirmedGeneration],
          "same-chat replacement transport has a distinct read lease");
    AutomaticReadProbeClient *client = Client();
    NSError *error = [NSError errorWithDomain:@"stale" code:1 userInfo:nil];
    Check(!Automatic(client, &error) && !error && [[client requests] count] == 0 && [client authorizationCalls] == 0,
          "unopened automatic receipt does not authorize, send or leave a stale error");
    [client setUserOpenedChatID:@2];
    Check(!Automatic(client, &error) && [[client requests] count] == 0, "another chat cannot permit a receipt");
    [client setUserOpenedChatID:@1];
    Check(Automatic(client, &error) && [[client requests] count] == 1, "visible chat permits current receipt");
    NSDictionary *request = [[client requests] lastObject];
    Check([[request objectForKey:@"@type"] isEqual:@"viewMessages"] &&
          ![[request objectForKey:@"force_read"] boolValue] && [request objectForKey:@"source"] &&
          [[request objectForKey:@"message_ids"] count] == 3, "automatic current-schema request never forces a closed read");

    client = Client(); client.acknowledgeOpen = NO; [client setUserOpenedChatID:@1];
    Check(!Automatic(client, &error) && [[client requests] count] == 0 && [client authorizationCalls] == 0,
          "unacknowledged chat cannot trigger automatic receipt");
    client.acknowledgeOpen = YES; [client setUserOpenedChatID:@1];
    Check(Automatic(client, &error), "acknowledged same desired chat becomes eligible");

    client = Client(); [client setUserOpenedChatID:@1]; client.useLegacy = YES;
    Check(Automatic(client, &error) && [[client requests] count] == 2, "legacy schema receives automatic fallback");
    request = [[client requests] lastObject];
    Check(![[request objectForKey:@"force_read"] boolValue] && ![request objectForKey:@"source"] &&
          [[request objectForKey:@"message_thread_id"] isEqual:@7], "legacy automatic request preserves thread and force_read false");

    client = Client(); [client setUserOpenedChatID:@1]; client.closeDuringAuthorization = YES;
    Check(!Automatic(client, &error) && [[client requests] count] == 0, "focus loss during authorization suppresses dispatch");
    client = Client(); [client setUserOpenedChatID:@1]; client.reselectDuringAuthorization = YES;
    Check(!Automatic(client, &error) && [[client requests] count] == 0, "A/B/A invalidates the original automatic read lease");
    client = Client(); [client setUserOpenedChatID:@1]; client.resetDuringAuthorization = YES;
    Check(!Automatic(client, &error) && [[client requests] count] == 0,
          "transport reset and acknowledged reopen invalidate the original lease");
    client = Client(); [client setUserOpenedChatID:@1]; client.useLegacy = YES; client.closeBeforeFallback = YES;
    Check(!Automatic(client, &error) && [[client requests] count] == 1, "focus loss after current request suppresses legacy fallback");
    client = Client(); [client setUserOpenedChatID:@1]; client.ready = NO;
    Check(!Automatic(client, &error) && error && [[client requests] count] == 0, "not-ready authorization cannot send a receipt");

    client = Client(); error = nil;
    Check([client markMessagesAsReadForChatID:@1 messageIDs:[NSArray arrayWithObject:@501] timeout:4.0 error:&error],
          "explicit user mark-read remains independent of visible selection");
    Check([[[[client requests] lastObject] objectForKey:@"force_read"] boolValue], "explicit current receipt retains force_read true");
    client = Client(); client.useLegacy = YES; error = nil;
    Check([client markMessagesAsReadForChatID:@1 messageThreadID:@7 messageTopicKind:@"forum"
        messageIDs:[NSArray arrayWithObject:@501] timeout:4.0 error:&error] && [[client requests] count] == 2,
        "explicit legacy user action continues to work");
    Check([[[[client requests] lastObject] objectForKey:@"force_read"] boolValue], "explicit legacy receipt retains force_read true");
    puts("PASS: production automatic receipts require current chat lease, never force reads, preserve explicit user actions and guard legacy fallback");
    [pool drain]; return 0;
}
