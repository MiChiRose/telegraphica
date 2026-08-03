#import "TGTDLibClient+Account.h"

@interface TGTDLibClient (AccountPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSString *)cachedAuthorizationStateSummary;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSString *)summaryForAuthorizationStateObject:(id)object;
- (NSString *)textFromFormattedTextObject:(id)object;
- (NSDictionary *)photoInfoFromChatPhotoObject:(id)photoObject
                               downloadMissing:(BOOL)downloadMissing
                                       timeout:(NSTimeInterval)timeout
                            didRequestDownload:(BOOL *)didRequestDownload;
@end

static BOOL TGAccountObjectIsBoolean(id object) {
    return object && CFGetTypeID((CFTypeRef)object) == CFBooleanGetTypeID();
}

@implementation TGTDLibClient (Account)

- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load profile. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:48];
        }
        return nil;
    }

    NSMutableDictionary *getMeRequest = [NSMutableDictionary dictionary];
    [getMeRequest setObject:@"getMe" forKey:@"@type"];
    NSDictionary *userResponse = [self sendTDLibRequestAndWaitForExtra:getMeRequest
                                                           extraPrefix:@"telegraphica-profile-get-me"
                                                               timeout:timeout
                                                             errorCode:49
                                                                 error:error];
    if (!userResponse) {
        return nil;
    }

    id userType = [userResponse objectForKey:@"@type"];
    if (![userType isKindOfClass:[NSString class]] || ![(NSString *)userType isEqualToString:@"user"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getMe returned an unexpected profile response." code:49];
        }
        return nil;
    }

    id firstName = [userResponse objectForKey:@"first_name"];
    id lastName = [userResponse objectForKey:@"last_name"];
    id username = [userResponse objectForKey:@"username"];
    if (![username isKindOfClass:[NSString class]] || [(NSString *)username length] == 0) {
        id usernames = [userResponse objectForKey:@"usernames"];
        if ([usernames isKindOfClass:[NSDictionary class]]) {
            id activeUsernames = [(NSDictionary *)usernames objectForKey:@"active_usernames"];
            if ([activeUsernames isKindOfClass:[NSArray class]] && [(NSArray *)activeUsernames count] > 0) {
                id firstUsername = [(NSArray *)activeUsernames objectAtIndex:0];
                if ([firstUsername isKindOfClass:[NSString class]]) {
                    username = firstUsername;
                }
            }
        }
    }

    NSMutableArray *nameParts = [NSMutableArray array];
    if ([firstName isKindOfClass:[NSString class]] && [(NSString *)firstName length] > 0) {
        [nameParts addObject:firstName];
    }
    if ([lastName isKindOfClass:[NSString class]] && [(NSString *)lastName length] > 0) {
        [nameParts addObject:lastName];
    }
    NSString *displayName = ([nameParts count] > 0) ? [nameParts componentsJoinedByString:@" "] : @"Telegram account";

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:displayName forKey:@"display_name"];
    if ([firstName isKindOfClass:[NSString class]] && [(NSString *)firstName length] > 0) {
        [summary setObject:firstName forKey:@"first_name"];
    }
    if ([lastName isKindOfClass:[NSString class]] && [(NSString *)lastName length] > 0) {
        [summary setObject:lastName forKey:@"last_name"];
    }
    if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
        [summary setObject:username forKey:@"username"];
    }
    id phoneNumber = [userResponse objectForKey:@"phone_number"];
    if ([phoneNumber isKindOfClass:[NSString class]] && [(NSString *)phoneNumber length] > 0) {
        [summary setObject:phoneNumber forKey:@"phone_number"];
    }
    id userID = [userResponse objectForKey:@"id"];
    if ([userID respondsToSelector:@selector(longLongValue)]) {
        NSNumber *safeUserID = [NSNumber numberWithLongLong:[userID longLongValue]];
        [summary setObject:safeUserID forKey:@"id"];

        NSMutableDictionary *fullInfoRequest = [NSMutableDictionary dictionary];
        [fullInfoRequest setObject:@"getUserFullInfo" forKey:@"@type"];
        [fullInfoRequest setObject:safeUserID forKey:@"user_id"];
        NSDictionary *fullInfoResponse = [self sendTDLibRequestAndWaitForExtra:fullInfoRequest
                                                                    extraPrefix:@"telegraphica-profile-full-info"
                                                                        timeout:2.0
                                                                      errorCode:61
                                                                          error:NULL];
        id fullInfoType = [fullInfoResponse objectForKey:@"@type"];
        if ([fullInfoType isKindOfClass:[NSString class]] && [(NSString *)fullInfoType isEqualToString:@"userFullInfo"]) {
            NSString *bio = [self textFromFormattedTextObject:[fullInfoResponse objectForKey:@"bio"]];
            if ([bio length] > 0) {
                [summary setObject:bio forKey:@"bio"];
            }
        }
    }
    BOOL didRequestAvatarDownload = NO;
    NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[userResponse objectForKey:@"profile_photo"]
                                                  downloadMissing:YES
                                                          timeout:1.5
                                               didRequestDownload:&didRequestAvatarDownload];
    NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
    if ([avatarPath length] > 0) {
        [summary setObject:avatarPath forKey:@"avatar_path"];
    }
    return summary;
}

- (BOOL)updateCurrentUserFirstName:(NSString *)firstName
                         lastName:(NSString *)lastName
                         username:(NSString *)username
                              bio:(NSString *)bio
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib is not ready to update the profile." code:105];
        }
        return NO;
    }

    NSString *safeFirstName = [firstName isKindOfClass:[NSString class]] ? firstName : @"";
    NSString *safeLastName = [lastName isKindOfClass:[NSString class]] ? lastName : @"";
    NSString *safeUsername = [username isKindOfClass:[NSString class]] ? username : @"";
    NSString *safeBio = [bio isKindOfClass:[NSString class]] ? bio : @"";
    if ([safeFirstName length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"First name is required." code:105];
        }
        return NO;
    }

    NSMutableDictionary *setNameRequest = [NSMutableDictionary dictionary];
    [setNameRequest setObject:@"setName" forKey:@"@type"];
    [setNameRequest setObject:safeFirstName forKey:@"first_name"];
    [setNameRequest setObject:safeLastName forKey:@"last_name"];

    NSMutableDictionary *setUsernameRequest = [NSMutableDictionary dictionary];
    [setUsernameRequest setObject:@"setUsername" forKey:@"@type"];
    [setUsernameRequest setObject:safeUsername forKey:@"username"];

    NSMutableDictionary *setBioRequest = [NSMutableDictionary dictionary];
    [setBioRequest setObject:@"setBio" forKey:@"@type"];
    [setBioRequest setObject:safeBio forKey:@"bio"];

    NSArray *requests = [NSArray arrayWithObjects:setNameRequest, setUsernameRequest, setBioRequest, nil];
    NSArray *prefixes = [NSArray arrayWithObjects:@"telegraphica-profile-set-name",
                                                  @"telegraphica-profile-set-username",
                                                  @"telegraphica-profile-set-bio", nil];
    NSUInteger requestIndex = 0;
    for (requestIndex = 0; requestIndex < [requests count]; requestIndex++) {
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:[requests objectAtIndex:requestIndex]
                                                            extraPrefix:[prefixes objectAtIndex:requestIndex]
                                                                timeout:timeout
                                                              errorCode:(105 + (NSInteger)requestIndex)
                                                                  error:error];
        if (!response) {
            return NO;
        }
        id responseType = [response objectForKey:@"@type"];
        if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
            if (error) {
                *error = [self errorWithDescription:@"TDLib returned an unexpected profile update response."
                                               code:(105 + (NSInteger)requestIndex)];
            }
            return NO;
        }
    }
    return YES;
}

- (BOOL)setCurrentUserProfilePhotoAtPath:(NSString *)localPath
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib is not ready to update the profile photo." code:108];
        }
        return NO;
    }

    BOOL isDirectory = NO;
    if (![localPath isKindOfClass:[NSString class]] ||
        [localPath length] == 0 ||
        ![[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory] ||
        isDirectory) {
        if (error) {
            *error = [self errorWithDescription:@"The prepared profile photo file is unavailable." code:108];
        }
        return NO;
    }

    NSDictionary *inputFile = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"inputFileLocal", @"@type",
                               localPath, @"path",
                               nil];
    NSDictionary *photo = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"inputChatPhotoStatic", @"@type",
                           inputFile, @"photo",
                           nil];
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setProfilePhoto" forKey:@"@type"];
    [request setObject:photo forKey:@"photo"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"is_public"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-profile-set-photo"
                                                            timeout:timeout
                                                          errorCode:108
                                                              error:error];
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] ||
        ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (response && error) {
            NSString *summary = [self summaryForAuthorizationStateObject:response];
            *error = [self errorWithDescription:([summary length] > 0
                                                    ? summary
                                                    : @"TDLib returned an unexpected profile photo response.")
                                           code:108];
        }
        return NO;
    }
    return YES;
}

- (NSDictionary *)activeSessionsSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self cachedAuthorizationStateSummary];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load active sessions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:92];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getActiveSessions" forKey:@"@type"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-active-sessions"
                                                            timeout:timeout
                                                          errorCode:93
                                                              error:error];
    if (!response) {
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id sessionsObject = [response objectForKey:@"sessions"];
    id inactiveSessionTTLDays = [response objectForKey:@"inactive_session_ttl_days"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"sessions"] ||
        ![sessionsObject isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getActiveSessions returned an unexpected response." code:93];
        }
        return nil;
    }

    NSArray *numberKeys = [NSArray arrayWithObjects:@"id", @"session_id", @"last_active_date", nil];
    NSArray *booleanKeys = [NSArray arrayWithObjects:@"is_current", nil];
    NSArray *stringKeys = [NSArray arrayWithObjects:@"application_name", @"application_version", @"device_model", @"platform", @"system_version", @"location", nil];
    NSMutableArray *safeSessions = [NSMutableArray arrayWithCapacity:[(NSArray *)sessionsObject count]];
    NSUInteger sessionIndex = 0;
    for (sessionIndex = 0; sessionIndex < [(NSArray *)sessionsObject count]; sessionIndex++) {
        id sessionObject = [(NSArray *)sessionsObject objectAtIndex:sessionIndex];
        if (![sessionObject isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib getActiveSessions returned a non-dictionary session at index %lu.", (unsigned long)sessionIndex];
                *error = [self errorWithDescription:message code:93];
            }
            return nil;
        }

        NSDictionary *session = (NSDictionary *)sessionObject;
        NSMutableDictionary *safeSession = [NSMutableDictionary dictionary];
        NSUInteger keyIndex = 0;
        for (keyIndex = 0; keyIndex < [numberKeys count]; keyIndex++) {
            NSString *key = [numberKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            long long numberValue = 0;
            BOOL hasNumberValue = NO;
            if ([value isKindOfClass:[NSNumber class]] && !TGAccountObjectIsBoolean(value)) {
                numberValue = [value longLongValue];
                hasNumberValue = YES;
            } else if ([value isKindOfClass:[NSString class]]) {
                NSString *stringValue = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([stringValue length] > 0) {
                    NSScanner *scanner = [NSScanner scannerWithString:stringValue];
                    long long scannedValue = 0;
                    if ([scanner scanLongLong:&scannedValue] && [scanner isAtEnd]) {
                        numberValue = scannedValue;
                        hasNumberValue = YES;
                    }
                }
            }
            if (!hasNumberValue) {
                continue;
            }
            [safeSession setObject:[NSNumber numberWithLongLong:numberValue] forKey:key];
        }
        for (keyIndex = 0; keyIndex < [booleanKeys count]; keyIndex++) {
            NSString *key = [booleanKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            if (!TGAccountObjectIsBoolean(value)) {
                continue;
            }
            [safeSession setObject:[NSNumber numberWithBool:[value boolValue]] forKey:key];
        }
        for (keyIndex = 0; keyIndex < [stringKeys count]; keyIndex++) {
            NSString *key = [stringKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            if (![value isKindOfClass:[NSString class]]) {
                continue;
            }
            [safeSession setObject:value forKey:key];
        }
        if (![[safeSession objectForKey:@"location"] length]) {
            NSMutableArray *locationParts = [NSMutableArray array];
            id region = [session objectForKey:@"region"];
            id country = [session objectForKey:@"country"];
            if ([region isKindOfClass:[NSString class]] && [(NSString *)region length] > 0) {
                [locationParts addObject:region];
            }
            if ([country isKindOfClass:[NSString class]] && [(NSString *)country length] > 0 &&
                ![country isEqual:region]) {
                [locationParts addObject:country];
            }
            if ([locationParts count] > 0) {
                [safeSession setObject:[locationParts componentsJoinedByString:@", "] forKey:@"location"];
            }
        }
        [safeSessions addObject:[NSDictionary dictionaryWithDictionary:safeSession]];
    }

    NSMutableDictionary *safeSummary = [NSMutableDictionary dictionaryWithObject:[NSArray arrayWithArray:safeSessions]
                                                                           forKey:@"sessions"];
    if ([inactiveSessionTTLDays isKindOfClass:[NSNumber class]] &&
        !TGAccountObjectIsBoolean(inactiveSessionTTLDays)) {
        [safeSummary setObject:[NSNumber numberWithInteger:[inactiveSessionTTLDays integerValue]]
                        forKey:@"inactive_session_ttl_days"];
    } else if ([inactiveSessionTTLDays isKindOfClass:[NSString class]]) {
        NSString *ttlString = [(NSString *)inactiveSessionTTLDays stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSScanner *ttlScanner = [NSScanner scannerWithString:ttlString];
        NSInteger ttlValue = 0;
        if ([ttlScanner scanInteger:&ttlValue] && [ttlScanner isAtEnd]) {
            [safeSummary setObject:[NSNumber numberWithInteger:ttlValue]
                            forKey:@"inactive_session_ttl_days"];
        }
    }
    return [NSDictionary dictionaryWithDictionary:safeSummary];
}

- (BOOL)terminateActiveSessionWithID:(NSNumber *)sessionID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self cachedAuthorizationStateSummary];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to terminate active sessions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:94];
        }
        return NO;
    }
    if (![sessionID respondsToSelector:@selector(longLongValue)] || [sessionID longLongValue] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib terminateSession requires a valid session id." code:94];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"terminateSession" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[sessionID longLongValue]] forKey:@"session_id"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-terminate-session"
                                                            timeout:timeout
                                                          errorCode:94
                                                              error:error];
    if (!response) {
        return NO;
    }

    id responseType = [response objectForKey:@"@type"];
    if ([responseType isKindOfClass:[NSString class]] && [(NSString *)responseType isEqualToString:@"ok"]) {
        return YES;
    }
    if (error) {
        *error = [self errorWithDescription:@"TDLib terminateSession returned an unexpected response." code:94];
    }
    return NO;
}

@end

