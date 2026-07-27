#import "TGTDLibClient+Administration.h"

@interface TGTDLibClient (AdministrationPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSDictionary *)contactSummaryFromUserObject:(NSDictionary *)userObject timeout:(NSTimeInterval)timeout;
@end

static NSNumber *TGAdministrationID(id value) {
    return ([value respondsToSelector:@selector(longLongValue)] && [value longLongValue] != 0LL)
        ? [NSNumber numberWithLongLong:[value longLongValue]]
        : nil;
}

static NSString *TGAdministrationString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation TGTDLibClient (Administration)

- (NSDictionary *)tg_administrationRequest:(NSDictionary *)request
                                     prefix:(NSString *)prefix
                                    timeout:(NSTimeInterval)timeout
                                       code:(NSInteger)code
                                      error:(NSError **)error {
    return [self sendTDLibRequestAndWaitForExtra:request
                                     extraPrefix:prefix
                                         timeout:timeout
                                       errorCode:code
                                           error:error];
}

- (NSDictionary *)tg_administrationUserSummary:(NSNumber *)userID timeout:(NSTimeInterval)timeout {
    if (!userID) {
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getUser", @"@type", userID, @"user_id", nil];
    NSDictionary *user = [self tg_administrationRequest:request
                                                 prefix:@"telegraphica-admin-user"
                                                timeout:MIN(timeout, 1.0)
                                                   code:400
                                                  error:NULL];
    NSDictionary *summary = [self contactSummaryFromUserObject:user timeout:timeout];
    if (summary) {
        return summary;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            userID, @"user_id",
            [NSString stringWithFormat:@"User %@", userID], @"display_name",
            nil];
}

- (NSArray *)tg_inviteLinkSummariesForChatID:(NSNumber *)chatID
                                currentUserID:(NSNumber *)currentUserID
                                     revoked:(BOOL)revoked
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error {
    if (!currentUserID) {
        return [NSArray array];
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatInviteLinks", @"@type",
                             chatID, @"chat_id",
                             currentUserID, @"creator_user_id",
                             [NSNumber numberWithBool:revoked], @"is_revoked",
                             [NSNumber numberWithInt:0], @"offset_date",
                             @"", @"offset_invite_link",
                             [NSNumber numberWithInt:100], @"limit",
                             nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-invite-links"
                                                    timeout:timeout
                                                       code:401
                                                      error:error];
    NSArray *links = [[response objectForKey:@"invite_links"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"invite_links"]
        : [NSArray array];
    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [links count]; index++) {
        NSDictionary *link = [[links objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [links objectAtIndex:index] : nil;
        if (!link) {
            continue;
        }
        NSString *name = TGAdministrationString([link objectForKey:@"name"]);
        NSString *url = TGAdministrationString([link objectForKey:@"invite_link"]);
        NSMutableDictionary *summary = [NSMutableDictionary dictionaryWithDictionary:link];
        [summary setObject:([name length] > 0 ? name : url) forKey:@"display_name"];
        [summary setObject:[NSNumber numberWithBool:revoked] forKey:@"revoked"];
        [summaries addObject:summary];
    }
    return summaries;
}

- (NSArray *)tg_joinRequestSummariesForChatID:(NSNumber *)chatID
                                       timeout:(NSTimeInterval)timeout {
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatJoinRequests", @"@type",
                             chatID, @"chat_id",
                             @"", @"invite_link",
                             @"", @"query",
                             [NSNull null], @"offset_request",
                             [NSNumber numberWithInt:100], @"limit",
                             nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-join-requests"
                                                    timeout:timeout
                                                       code:402
                                                      error:NULL];
    NSArray *requests = [[response objectForKey:@"requests"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"requests"] : [NSArray array];
    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [requests count]; index++) {
        NSDictionary *joinRequest = [[requests objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [requests objectAtIndex:index] : nil;
        NSNumber *userID = TGAdministrationID([joinRequest objectForKey:@"user_id"]);
        if (!userID) {
            continue;
        }
        NSMutableDictionary *summary = [NSMutableDictionary dictionaryWithDictionary:
                                        [self tg_administrationUserSummary:userID timeout:timeout]];
        [summary setObject:joinRequest forKey:@"request"];
        NSString *bio = TGAdministrationString([joinRequest objectForKey:@"bio"]);
        if ([bio length] > 0) {
            [summary setObject:bio forKey:@"bio"];
        }
        [summaries addObject:summary];
    }
    return summaries;
}

- (NSArray *)tg_eventSummariesForChatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout {
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChatEventLog", @"@type",
                             chatID, @"chat_id",
                             @"", @"query",
                             [NSNumber numberWithLongLong:0LL], @"from_event_id",
                             [NSNumber numberWithInt:50], @"limit",
                             [NSNull null], @"filters",
                             [NSArray array], @"user_ids",
                             nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-event-log"
                                                    timeout:timeout
                                                       code:403
                                                      error:NULL];
    NSArray *events = [[response objectForKey:@"events"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"events"] : [NSArray array];
    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [events count]; index++) {
        NSDictionary *event = [[events objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [events objectAtIndex:index] : nil;
        NSDictionary *action = [[event objectForKey:@"action"] isKindOfClass:[NSDictionary class]]
            ? [event objectForKey:@"action"] : [NSDictionary dictionary];
        NSString *actionType = TGAdministrationString([action objectForKey:@"@type"]);
        if ([actionType hasPrefix:@"chatEvent"]) {
            actionType = [actionType substringFromIndex:[@"chatEvent" length]];
        }
        id memberID = [event objectForKey:@"member_id"];
        NSNumber *userID = TGAdministrationID(memberID);
        if ([memberID isKindOfClass:[NSDictionary class]] &&
            [[memberID objectForKey:@"@type"] isEqualToString:@"messageSenderUser"]) {
            userID = TGAdministrationID([memberID objectForKey:@"user_id"]);
        }
        if (!userID) {
            userID = TGAdministrationID([event objectForKey:@"user_id"]);
        }
        NSString *actor = @"";
        if (userID) {
            actor = [[self tg_administrationUserSummary:userID timeout:timeout] objectForKey:@"display_name"];
        }
        [summaries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              event, @"event",
                              ([actionType length] > 0 ? actionType : @"Event"), @"action",
                              ([actor length] > 0 ? actor : @"Telegram"), @"actor",
                              nil]];
    }
    return summaries;
}

- (NSDictionary *)chatAdministrationSummaryForChatID:(NSNumber *)chatID
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error {
    NSNumber *safeChatID = TGAdministrationID(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:404];
        }
        return nil;
    }
    NSDictionary *me = [self tg_administrationRequest:
                         [NSDictionary dictionaryWithObject:@"getMe" forKey:@"@type"]
                                               prefix:@"telegraphica-admin-me"
                                              timeout:MIN(timeout, 2.0)
                                                 code:405
                                                error:error];
    NSNumber *currentUserID = TGAdministrationID([me objectForKey:@"id"]);
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    NSArray *active = [self tg_inviteLinkSummariesForChatID:safeChatID
                                              currentUserID:currentUserID
                                                   revoked:NO
                                                   timeout:timeout
                                                     error:error];
    NSArray *revoked = [self tg_inviteLinkSummariesForChatID:safeChatID
                                               currentUserID:currentUserID
                                                    revoked:YES
                                                    timeout:timeout
                                                      error:NULL];
    [summary setObject:[active arrayByAddingObjectsFromArray:revoked] forKey:@"invite_links"];
    [summary setObject:[self tg_joinRequestSummariesForChatID:safeChatID timeout:timeout] forKey:@"join_requests"];
    [summary setObject:[self tg_eventSummariesForChatID:safeChatID timeout:timeout] forKey:@"events"];
    NSDictionary *chat = [self tg_administrationRequest:
                          [NSDictionary dictionaryWithObjectsAndKeys:@"getChat", @"@type",
                           safeChatID, @"chat_id", nil]
                                                prefix:@"telegraphica-admin-chat"
                                               timeout:MIN(timeout, 2.0)
                                                  code:406
                                                 error:NULL];
    if ([chat objectForKey:@"slow_mode_delay"]) {
        [summary setObject:[chat objectForKey:@"slow_mode_delay"] forKey:@"slow_mode_delay"];
    }
    return summary;
}

- (NSDictionary *)createInviteLinkForChatID:(NSNumber *)chatID
                                        name:(NSString *)name
                            expirationPeriod:(NSInteger)expirationPeriod
                                 memberLimit:(NSInteger)memberLimit
                          createsJoinRequest:(BOOL)createsJoinRequest
                                     timeout:(NSTimeInterval)timeout
                                       error:(NSError **)error {
    NSNumber *safeChatID = TGAdministrationID(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:407];
        }
        return nil;
    }
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSInteger expirationDate = expirationPeriod > 0 ? (NSInteger)now + expirationPeriod : 0;
    NSString *safeName = name ? name : @"";
    if ([safeName length] > 32) {
        safeName = [safeName substringToIndex:32];
    }
    NSInteger safeMemberLimit = createsJoinRequest ? 0 : MIN(99999, MAX(0, memberLimit));
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"createChatInviteLink", @"@type",
                             safeChatID, @"chat_id",
                             safeName, @"name",
                             [NSNumber numberWithInteger:expirationDate], @"expiration_date",
                             [NSNumber numberWithInteger:safeMemberLimit], @"member_limit",
                             [NSNumber numberWithBool:createsJoinRequest], @"creates_join_request",
                             nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-create-invite-link"
                                                    timeout:timeout
                                                       code:408
                                                      error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"chatInviteLink"] ? response : nil;
}

- (BOOL)revokeInviteLink:(NSString *)inviteLink
               forChatID:(NSNumber *)chatID
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error {
    NSNumber *safeChatID = TGAdministrationID(chatID);
    if (!safeChatID || [inviteLink length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Chat and invite link are required." code:409];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"revokeChatInviteLink", @"@type",
                             safeChatID, @"chat_id",
                             inviteLink, @"invite_link", nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-revoke-invite-link"
                                                    timeout:timeout
                                                       code:410
                                                      error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"chatInviteLinks"];
}

- (BOOL)processJoinRequestForUserID:(NSNumber *)userID
                           chatID:(NSNumber *)chatID
                          approve:(BOOL)approve
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error {
    NSNumber *safeChatID = TGAdministrationID(chatID);
    NSNumber *safeUserID = TGAdministrationID(userID);
    if (!safeChatID || !safeUserID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat and user identifiers are required." code:411];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"processChatJoinRequest", @"@type",
                             safeChatID, @"chat_id",
                             safeUserID, @"user_id",
                             [NSNumber numberWithBool:approve], @"approve", nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-process-join-request"
                                                    timeout:timeout
                                                       code:412
                                                      error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)setSlowModeDelay:(NSInteger)seconds
               forChatID:(NSNumber *)chatID
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error {
    NSNumber *safeChatID = TGAdministrationID(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:413];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setChatSlowModeDelay", @"@type",
                             safeChatID, @"chat_id",
                             [NSNumber numberWithInteger:seconds], @"slow_mode_delay", nil];
    NSDictionary *response = [self tg_administrationRequest:request
                                                     prefix:@"telegraphica-set-slow-mode"
                                                    timeout:timeout
                                                       code:414
                                                      error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

@end
