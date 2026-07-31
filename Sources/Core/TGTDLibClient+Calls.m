#import "TGTDLibClient+Calls.h"
#import "../Calls/TGCallAudioEngine.h"
#import "../Services/TGBase64Compatibility.h"

@interface TGTDLibClient (CallsPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

static NSDictionary *TGCallProtocolDescriptor(void) {
    NSArray *versions = [TGCallAudioEngine protocolVersions];
    NSInteger maximumLayer = [TGCallAudioEngine maximumProtocolLayer];
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"callProtocol", @"@type",
            [NSNumber numberWithBool:YES], @"udp_p2p",
            [NSNumber numberWithBool:YES], @"udp_reflector",
            [NSNumber numberWithInteger:65], @"min_layer",
            [NSNumber numberWithInteger:MAX(65, maximumLayer)], @"max_layer",
            versions ? versions : [NSArray array], @"library_versions",
            nil];
}

static NSNumber *TGPositiveCallIdentifier(id value) {
    if (![value respondsToSelector:@selector(integerValue)]) {
        return nil;
    }
    NSInteger identifier = [value integerValue];
    return identifier > 0 ? [NSNumber numberWithInteger:identifier] : nil;
}

static NSNumber *TGUserIdentifierFromSender(id sender) {
    if (![sender isKindOfClass:[NSDictionary class]] ||
        ![[sender objectForKey:@"@type"] isEqualToString:@"messageSenderUser"]) {
        return nil;
    }
    id userID = [sender objectForKey:@"user_id"];
    return [userID respondsToSelector:@selector(longLongValue)]
        ? [NSNumber numberWithLongLong:[userID longLongValue]] : nil;
}

@implementation TGTDLibClient (Calls)

- (NSNumber *)createAudioCallToUserID:(NSNumber *)userID
                               timeout:(NSTimeInterval)timeout
                                 error:(NSError **)error {
    return [self createCallToUserID:userID isVideo:NO timeout:timeout error:error];
}

- (NSNumber *)createCallToUserID:(NSNumber *)userID
                         isVideo:(BOOL)isVideo
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error {
    if (![userID respondsToSelector:@selector(longLongValue)] || [userID longLongValue] <= 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"A Telegram user is required for a call." code:430];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"createCall", @"@type",
                             [NSNumber numberWithLongLong:[userID longLongValue]], @"user_id",
                             TGCallProtocolDescriptor(), @"protocol",
                             [NSNumber numberWithBool:isVideo], @"is_video",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:(isVideo
                                                            ? @"telegraphica-create-video-call"
                                                            : @"telegraphica-create-audio-call")
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
    return [self discardCallWithID:callID
                      disconnected:disconnected
                          duration:duration
                           isVideo:NO
                      connectionID:connectionID
                           timeout:timeout
                             error:error];
}

- (BOOL)discardCallWithID:(NSNumber *)callID
              disconnected:(BOOL)disconnected
                  duration:(NSUInteger)duration
                   isVideo:(BOOL)isVideo
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
                             [NSNumber numberWithBool:isVideo], @"is_video",
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

- (BOOL)sendAudioCallSignalingData:(NSData *)data
                            callID:(NSNumber *)callID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error {
    NSNumber *safeCallID = TGPositiveCallIdentifier(callID);
    NSString *encodedData = TGBase64EncodedString(data);
    if (!safeCallID || ![encodedData length]) {
        if (error) {
            *error = [self errorWithDescription:@"Call signaling data is missing." code:443];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"sendCallSignalingData", @"@type",
                             safeCallID, @"call_id",
                             encodedData, @"data",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-call-signaling"
                                                            timeout:timeout
                                                          errorCode:444
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib rejected call signaling data." code:445];
    }
    return NO;
}

- (NSArray *)recentAudioCallSummariesWithLimit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    NSUInteger safeLimit = MAX(1U, MIN(100U, limit));
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"searchCallMessages", @"@type",
                             @"", @"offset",
                             [NSNumber numberWithUnsignedInteger:safeLimit], @"limit",
                             [NSNumber numberWithBool:NO], @"only_missed",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-recent-audio-calls"
                                                            timeout:timeout
                                                          errorCode:439
                                                              error:error];
    NSArray *messages = [[response objectForKey:@"messages"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"messages"] : nil;
    if (!messages) {
        if (error && response && !*error) {
            *error = [self errorWithDescription:@"TDLib did not return recent calls." code:440];
        }
        return nil;
    }

    NSMutableArray *summaries = [NSMutableArray array];
    NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
    NSUInteger index = 0;
    for (index = 0; index < [messages count] && [summaries count] < safeLimit; index++) {
        NSDictionary *message = [[messages objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [messages objectAtIndex:index] : nil;
        NSDictionary *content = [[message objectForKey:@"content"] isKindOfClass:[NSDictionary class]]
            ? [message objectForKey:@"content"] : nil;
        if (!message || ![[content objectForKey:@"@type"] isEqualToString:@"messageCall"] ||
            [[content objectForKey:@"is_video"] boolValue]) {
            continue;
        }

        BOOL outgoing = [[message objectForKey:@"is_outgoing"] boolValue];
        NSNumber *userID = outgoing ? nil : TGUserIdentifierFromSender([message objectForKey:@"sender_id"]);
        if (!userID) {
            id chatID = [message objectForKey:@"chat_id"];
            if ([chatID respondsToSelector:@selector(longLongValue)]) {
                NSDictionary *chatRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"getChat", @"@type",
                                             [NSNumber numberWithLongLong:[chatID longLongValue]], @"chat_id",
                                             nil];
                NSDictionary *chat = [self sendTDLibRequestAndWaitForExtra:chatRequest
                                                                extraPrefix:@"telegraphica-call-chat"
                                                                    timeout:MIN(timeout, 1.0)
                                                                  errorCode:441
                                                                      error:NULL];
                NSDictionary *chatType = [[chat objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
                    ? [chat objectForKey:@"type"] : nil;
                id privateUserID = [chatType objectForKey:@"user_id"];
                if ([[chatType objectForKey:@"@type"] isEqualToString:@"chatTypePrivate"] &&
                    [privateUserID respondsToSelector:@selector(longLongValue)]) {
                    userID = [NSNumber numberWithLongLong:[privateUserID longLongValue]];
                }
            }
        }
        if (!userID) {
            continue;
        }

        NSDictionary *profile = [profiles objectForKey:userID];
        if (!profile) {
            profile = [self userProfileSummaryForUserID:userID timeout:MIN(timeout, 1.8) error:NULL];
            if (profile) {
                [profiles setObject:profile forKey:userID];
            }
        }
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        id chatID = [message objectForKey:@"chat_id"];
        id messageID = [message objectForKey:@"id"];
        if ([chatID respondsToSelector:@selector(longLongValue)] &&
            [chatID longLongValue] != 0LL) {
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]]
                        forKey:@"chat_id"];
        }
        if ([messageID respondsToSelector:@selector(longLongValue)] &&
            [messageID longLongValue] > 0LL) {
            [summary setObject:[NSNumber numberWithLongLong:[messageID longLongValue]]
                        forKey:@"message_id"];
        }
        [summary setObject:userID forKey:@"user_id"];
        [summary setObject:[profile objectForKey:@"display_name"] ?: [NSString stringWithFormat:@"User %@", userID]
                    forKey:@"display_name"];
        NSString *avatarPath = [profile objectForKey:@"avatar_local_path"];
        if ([avatarPath length] > 0) {
            [summary setObject:avatarPath forKey:@"avatar_local_path"];
        }
        [summary setObject:[NSNumber numberWithBool:outgoing] forKey:@"is_outgoing"];
        id date = [message objectForKey:@"date"];
        if ([date respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[date longLongValue]] forKey:@"date"];
        }
        id duration = [content objectForKey:@"duration"];
        if ([duration respondsToSelector:@selector(unsignedIntegerValue)]) {
            [summary setObject:[NSNumber numberWithUnsignedInteger:[duration unsignedIntegerValue]] forKey:@"duration"];
        }
        NSDictionary *discardReason = [[content objectForKey:@"discard_reason"] isKindOfClass:[NSDictionary class]]
            ? [content objectForKey:@"discard_reason"] : nil;
        NSString *discardType = [[discardReason objectForKey:@"@type"] description];
        if ([discardType length] > 0) {
            [summary setObject:discardType forKey:@"discard_reason"];
        }
        [summaries addObject:summary];
    }
    return summaries;
}

@end
