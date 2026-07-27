#import "TGTDLibClient+Calls.h"

@interface TGTDLibClient (CallsPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

static NSDictionary *TGCallProtocolDescriptor(void) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"callProtocol", @"@type",
            [NSNumber numberWithBool:YES], @"udp_p2p",
            [NSNumber numberWithBool:YES], @"udp_reflector",
            [NSNumber numberWithInteger:65], @"min_layer",
            [NSNumber numberWithInteger:65], @"max_layer",
            [NSArray arrayWithObject:@"2.4.4"], @"library_versions",
            nil];
}

static NSNumber *TGPositiveCallIdentifier(id value) {
    if (![value respondsToSelector:@selector(integerValue)]) {
        return nil;
    }
    NSInteger identifier = [value integerValue];
    return identifier > 0 ? [NSNumber numberWithInteger:identifier] : nil;
}

@implementation TGTDLibClient (Calls)

- (NSNumber *)createAudioCallToUserID:(NSNumber *)userID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    if (![userID respondsToSelector:@selector(longLongValue)] || [userID longLongValue] <= 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"A Telegram user is required for an audio call." code:430];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"createCall", @"@type",
                             [NSNumber numberWithLongLong:[userID longLongValue]], @"user_id",
                             TGCallProtocolDescriptor(), @"protocol",
                             [NSNumber numberWithBool:NO], @"is_video",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-create-audio-call"
                                                            timeout:timeout
                                                          errorCode:431
                                                              error:error];
    NSNumber *callID = TGPositiveCallIdentifier([response objectForKey:@"id"]);
    if ([[response objectForKey:@"@type"] isEqualToString:@"callId"] && callID) {
        return callID;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not create the audio call." code:432];
    }
    return nil;
}

- (BOOL)acceptAudioCallWithID:(NSNumber *)callID
                      timeout:(NSTimeInterval)timeout
                        error:(NSError **)error {
    NSNumber *safeCallID = TGPositiveCallIdentifier(callID);
    if (!safeCallID) {
        if (error) {
            *error = [self errorWithDescription:@"Call identifier is missing." code:433];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"acceptCall", @"@type",
                             safeCallID, @"call_id",
                             TGCallProtocolDescriptor(), @"protocol",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-accept-audio-call"
                                                            timeout:timeout
                                                          errorCode:434
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not accept the audio call." code:435];
    }
    return NO;
}

- (BOOL)discardAudioCallWithID:(NSNumber *)callID
                  disconnected:(BOOL)disconnected
                      duration:(NSUInteger)duration
                  connectionID:(NSNumber *)connectionID
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error {
    NSNumber *safeCallID = TGPositiveCallIdentifier(callID);
    if (!safeCallID) {
        if (error) {
            *error = [self errorWithDescription:@"Call identifier is missing." code:436];
        }
        return NO;
    }
    long long relayID = [connectionID respondsToSelector:@selector(longLongValue)]
        ? [connectionID longLongValue] : 0LL;
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"discardCall", @"@type",
                             safeCallID, @"call_id",
                             [NSNumber numberWithBool:disconnected], @"is_disconnected",
                             [NSNumber numberWithUnsignedInteger:duration], @"duration",
                             [NSNumber numberWithBool:NO], @"is_video",
                             [NSNumber numberWithLongLong:relayID], @"connection_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-discard-audio-call"
                                                            timeout:timeout
                                                          errorCode:437
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not discard the audio call." code:438];
    }
    return NO;
}

@end
