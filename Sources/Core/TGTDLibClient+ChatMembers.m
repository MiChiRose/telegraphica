#import "TGTDLibClient+ChatMembers.h"

@interface TGTDLibClient (ChatMembersPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSDictionary *)contactSummaryFromUserObject:(NSDictionary *)userObject timeout:(NSTimeInterval)timeout;
@end

static NSNumber *TGMemberSafeID(id value) {
    if (![value respondsToSelector:@selector(longLongValue)] || [value longLongValue] == 0LL) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[value longLongValue]];
}

static NSString *TGMemberSafeString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGMemberUserIDFromMember(NSDictionary *member) {
    NSNumber *legacy = TGMemberSafeID([member objectForKey:@"user_id"]);
    if (legacy) {
        return legacy;
    }
    NSDictionary *memberID = [[member objectForKey:@"member_id"] isKindOfClass:[NSDictionary class]]
        ? [member objectForKey:@"member_id"]
        : nil;
    if ([[memberID objectForKey:@"@type"] isEqualToString:@"messageSenderUser"]) {
        return TGMemberSafeID([memberID objectForKey:@"user_id"]);
    }
    return nil;
}

static NSString *TGMemberRoleFromStatus(NSDictionary *status) {
    NSString *type = TGMemberSafeString([status objectForKey:@"@type"]);
    if ([type isEqualToString:@"chatMemberStatusCreator"]) {
        return @"creator";
    }
    if ([type isEqualToString:@"chatMemberStatusAdministrator"]) {
        return @"administrator";
    }
    if ([type isEqualToString:@"chatMemberStatusRestricted"]) {
        return @"restricted";
    }
    if ([type isEqualToString:@"chatMemberStatusBanned"]) {
        return @"banned";
    }
    if ([type isEqualToString:@"chatMemberStatusLeft"]) {
        return @"left";
    }
    return @"member";
}

static void TGMemberApplySelfCapabilities(NSMutableDictionary *summary, NSDictionary *status) {
    NSString *type = TGMemberSafeString([status objectForKey:@"@type"]);
    BOOL creator = [type isEqualToString:@"chatMemberStatusCreator"];
    BOOL administrator = [type isEqualToString:@"chatMemberStatusAdministrator"];
    NSDictionary *rights = [[status objectForKey:@"rights"] isKindOfClass:[NSDictionary class]]
        ? [status objectForKey:@"rights"]
        : nil;
    BOOL canInvite = creator || (administrator && [[rights objectForKey:@"can_invite_users"] boolValue]);
    BOOL canManage = creator || (administrator &&
                                 ([[rights objectForKey:@"can_restrict_members"] boolValue] ||
                                  [[rights objectForKey:@"can_promote_members"] boolValue]));
    [summary setObject:[NSNumber numberWithBool:canInvite] forKey:@"can_invite_members"];
    [summary setObject:[NSNumber numberWithBool:canManage] forKey:@"can_manage_members"];
}

static NSDictionary *TGMemberSenderObject(NSNumber *userID) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"messageSenderUser", @"@type",
            userID, @"user_id",
            nil];
}

@implementation TGTDLibClient (ChatMembers)

- (NSDictionary *)tg_memberRequest:(NSDictionary *)request
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

- (NSDictionary *)tg_userSummaryForMember:(NSDictionary *)member
                                  timeout:(NSTimeInterval)timeout {
    NSNumber *userID = TGMemberUserIDFromMember(member);
    if (!userID) {
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getUser", @"@type",
                             userID, @"user_id",
                             nil];
    NSDictionary *user = [self tg_memberRequest:request
                                         prefix:@"telegraphica-chat-member-user"
                                        timeout:MIN(timeout, 0.8)
                                           code:365
                                          error:NULL];
    NSMutableDictionary *summary = [[[self contactSummaryFromUserObject:user timeout:timeout] mutableCopy] autorelease];
    if (!summary) {
        summary = [NSMutableDictionary dictionary];
        [summary setObject:userID forKey:@"user_id"];
        [summary setObject:[NSString stringWithFormat:@"User %@", userID] forKey:@"display_name"];
    }
    NSDictionary *status = [[member objectForKey:@"status"] isKindOfClass:[NSDictionary class]]
        ? [member objectForKey:@"status"]
        : [NSDictionary dictionary];
    [summary setObject:TGMemberRoleFromStatus(status) forKey:@"role"];
    [summary setObject:[NSNumber numberWithBool:[[status objectForKey:@"can_be_edited"] boolValue]]
                forKey:@"can_be_edited"];
    if ([member objectForKey:@"joined_chat_date"]) {
        [summary setObject:[member objectForKey:@"joined_chat_date"] forKey:@"joined_date"];
    } else if ([member objectForKey:@"joined_date"]) {
        [summary setObject:[member objectForKey:@"joined_date"] forKey:@"joined_date"];
    }
    return summary;
}

- (NSArray *)tg_memberSummariesFromMembers:(NSArray *)members
                                   timeout:(NSTimeInterval)timeout {
    NSMutableArray *summaries = [NSMutableArray array];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:MAX(1.0, timeout)];
    NSUInteger index = 0;
    NSUInteger count = MIN((NSUInteger)[members count], (NSUInteger)200);
    for (index = 0; index < count; index++) {
        NSTimeInterval remaining = [deadline timeIntervalSinceNow];
        if (remaining <= 0.0) {
            break;
        }
        NSDictionary *member = [[members objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [members objectAtIndex:index]
            : nil;
        NSDictionary *summary = member
            ? [self tg_userSummaryForMember:member timeout:remaining]
            : nil;
        if (summary) {
            [summaries addObject:summary];
        }
    }
    return summaries;
}

- (NSDictionary *)chatDetailsSummaryForChatID:(NSNumber *)chatID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error {
    NSNumber *safeChatID = TGMemberSafeID(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:360];
        }
        return nil;
    }
    NSDictionary *chatRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"getChat", @"@type",
                                 safeChatID, @"chat_id",
                                 nil];
    NSDictionary *chat = [self tg_memberRequest:chatRequest
                                         prefix:@"telegraphica-chat-details"
                                        timeout:timeout
                                           code:361
                                          error:error];
    if (![[chat objectForKey:@"@type"] isEqualToString:@"chat"]) {
        return nil;
    }

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:safeChatID forKey:@"chat_id"];
    [summary setObject:TGMemberSafeString([chat objectForKey:@"title"]) forKey:@"title"];
    if ([chat objectForKey:@"message_auto_delete_time"]) {
        [summary setObject:[chat objectForKey:@"message_auto_delete_time"] forKey:@"message_auto_delete_time"];
    }
    if ([chat objectForKey:@"pending_join_requests"]) {
        [summary setObject:[chat objectForKey:@"pending_join_requests"] forKey:@"pending_join_requests"];
    }

    NSDictionary *type = [[chat objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [chat objectForKey:@"type"]
        : nil;
    NSString *typeName = TGMemberSafeString([type objectForKey:@"@type"]);
    if ([typeName isEqualToString:@"chatTypePrivate"] ||
        [typeName isEqualToString:@"chatTypeSecret"]) {
        NSNumber *userID = TGMemberSafeID([type objectForKey:@"user_id"]);
        if (userID) {
            NSDictionary *profile = [self userProfileSummaryForUserID:userID timeout:timeout error:NULL];
            if (profile) {
                [summary setObject:profile forKey:@"profile"];
            }
            [summary setObject:userID forKey:@"user_id"];
        }
        [summary setObject:[typeName isEqualToString:@"chatTypeSecret"] ? @"secret" : @"private"
                    forKey:@"kind"];
        return summary;
    }

    NSArray *rawMembers = nil;
    if ([typeName isEqualToString:@"chatTypeBasicGroup"]) {
        NSNumber *groupID = TGMemberSafeID([type objectForKey:@"basic_group_id"]);
        [summary setObject:@"basic_group" forKey:@"kind"];
        if (groupID) {
            NSDictionary *groupRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"getBasicGroup", @"@type",
                                          groupID, @"basic_group_id",
                                          nil];
            NSDictionary *group = [self tg_memberRequest:groupRequest
                                                  prefix:@"telegraphica-basic-group"
                                                 timeout:MIN(timeout, 2.0)
                                                    code:362
                                                   error:NULL];
            if ([group objectForKey:@"member_count"]) {
                [summary setObject:[group objectForKey:@"member_count"] forKey:@"member_count"];
            }
            if ([group objectForKey:@"status"]) {
                [summary setObject:[group objectForKey:@"status"] forKey:@"self_status"];
                TGMemberApplySelfCapabilities(summary, [group objectForKey:@"status"]);
            }
            NSDictionary *fullRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"getBasicGroupFullInfo", @"@type",
                                         groupID, @"basic_group_id",
                                         nil];
            NSDictionary *full = [self tg_memberRequest:fullRequest
                                                 prefix:@"telegraphica-basic-group-info"
                                                timeout:MIN(timeout, 3.0)
                                                   code:363
                                                  error:NULL];
            if ([[full objectForKey:@"@type"] isEqualToString:@"basicGroupFullInfo"]) {
                rawMembers = [[full objectForKey:@"members"] isKindOfClass:[NSArray class]]
                    ? [full objectForKey:@"members"]
                    : nil;
                NSString *description = TGMemberSafeString([full objectForKey:@"description"]);
                if ([description length] > 0) {
                    [summary setObject:description forKey:@"description"];
                }
                if ([full objectForKey:@"invite_link"]) {
                    [summary setObject:[full objectForKey:@"invite_link"] forKey:@"invite_link"];
                }
            }
        }
    } else if ([typeName isEqualToString:@"chatTypeSupergroup"]) {
        NSNumber *supergroupID = TGMemberSafeID([type objectForKey:@"supergroup_id"]);
        BOOL isChannel = [[type objectForKey:@"is_channel"] boolValue];
        [summary setObject:isChannel ? @"channel" : @"supergroup" forKey:@"kind"];
        if (supergroupID) {
            NSDictionary *groupRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"getSupergroup", @"@type",
                                          supergroupID, @"supergroup_id",
                                          nil];
            NSDictionary *group = [self tg_memberRequest:groupRequest
                                                  prefix:@"telegraphica-supergroup"
                                                 timeout:MIN(timeout, 2.0)
                                                    code:364
                                                   error:NULL];
            if ([group objectForKey:@"member_count"]) {
                [summary setObject:[group objectForKey:@"member_count"] forKey:@"member_count"];
            }
            if ([group objectForKey:@"status"]) {
                [summary setObject:[group objectForKey:@"status"] forKey:@"self_status"];
                TGMemberApplySelfCapabilities(summary, [group objectForKey:@"status"]);
            }
            if ([group objectForKey:@"usernames"]) {
                [summary setObject:[group objectForKey:@"usernames"] forKey:@"usernames"];
            }
            NSDictionary *fullRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"getSupergroupFullInfo", @"@type",
                                         supergroupID, @"supergroup_id",
                                         nil];
            NSDictionary *full = [self tg_memberRequest:fullRequest
                                                 prefix:@"telegraphica-supergroup-info"
                                                timeout:MIN(timeout, 3.0)
                                                   code:366
                                                  error:NULL];
            BOOL canGetMembers = [[full objectForKey:@"can_get_members"] boolValue];
            [summary setObject:[NSNumber numberWithBool:canGetMembers] forKey:@"can_get_members"];
            NSString *description = TGMemberSafeString([full objectForKey:@"description"]);
            if ([description length] > 0) {
                [summary setObject:description forKey:@"description"];
            }
            NSArray *copyKeys = [NSArray arrayWithObjects:@"member_count", @"administrator_count",
                                 @"restricted_count", @"banned_count", @"invite_link", nil];
            NSUInteger copyIndex = 0;
            for (copyIndex = 0; copyIndex < [copyKeys count]; copyIndex++) {
                NSString *key = [copyKeys objectAtIndex:copyIndex];
                if ([full objectForKey:key]) {
                    [summary setObject:[full objectForKey:key] forKey:key];
                }
            }
            if (canGetMembers) {
                NSDictionary *membersRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                                @"getSupergroupMembers", @"@type",
                                                supergroupID, @"supergroup_id",
                                                [NSDictionary dictionaryWithObject:@"supergroupMembersFilterRecent" forKey:@"@type"], @"filter",
                                                [NSNumber numberWithInt:0], @"offset",
                                                [NSNumber numberWithInt:200], @"limit",
                                                nil];
                NSDictionary *membersResponse = [self tg_memberRequest:membersRequest
                                                                prefix:@"telegraphica-supergroup-members"
                                                               timeout:MIN(timeout, 4.0)
                                                                  code:367
                                                                 error:NULL];
                rawMembers = [[membersResponse objectForKey:@"members"] isKindOfClass:[NSArray class]]
                    ? [membersResponse objectForKey:@"members"]
                    : nil;
            }
        }
    } else {
        [summary setObject:@"unknown" forKey:@"kind"];
    }

    NSArray *members = rawMembers
        ? [self tg_memberSummariesFromMembers:rawMembers timeout:timeout]
        : [NSArray array];
    [summary setObject:members forKey:@"members"];
    return summary;
}

- (BOOL)addUserID:(NSNumber *)userID
         toChatID:(NSNumber *)chatID
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error {
    NSNumber *safeUserID = TGMemberSafeID(userID);
    NSNumber *safeChatID = TGMemberSafeID(chatID);
    if (!safeUserID || !safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat and user identifiers are required." code:368];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"addChatMember", @"@type",
                             safeChatID, @"chat_id",
                             safeUserID, @"user_id",
                             [NSNumber numberWithInt:0], @"forward_limit",
                             nil];
    NSDictionary *response = [self tg_memberRequest:request
                                             prefix:@"telegraphica-add-chat-member"
                                            timeout:timeout
                                               code:369
                                              error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (NSDictionary *)tg_statusForRole:(NSString *)role {
    if ([role isEqualToString:@"administrator"]) {
        NSDictionary *rights = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"chatAdministratorRights", @"@type",
                                [NSNumber numberWithBool:YES], @"can_manage_chat",
                                [NSNumber numberWithBool:YES], @"can_change_info",
                                [NSNumber numberWithBool:YES], @"can_post_messages",
                                [NSNumber numberWithBool:YES], @"can_edit_messages",
                                [NSNumber numberWithBool:YES], @"can_delete_messages",
                                [NSNumber numberWithBool:YES], @"can_invite_users",
                                [NSNumber numberWithBool:YES], @"can_restrict_members",
                                [NSNumber numberWithBool:YES], @"can_pin_messages",
                                [NSNumber numberWithBool:YES], @"can_manage_topics",
                                [NSNumber numberWithBool:NO], @"can_promote_members",
                                [NSNumber numberWithBool:YES], @"can_manage_video_chats",
                                [NSNumber numberWithBool:NO], @"is_anonymous",
                                nil];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"chatMemberStatusAdministrator", @"@type",
                @"", @"custom_title",
                [NSNumber numberWithBool:YES], @"can_be_edited",
                rights, @"rights",
                nil];
    }
    if ([role isEqualToString:@"restricted"]) {
        NSDictionary *permissions = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"chatPermissions", @"@type",
                                     [NSNumber numberWithBool:NO], @"can_send_basic_messages",
                                     [NSNumber numberWithBool:NO], @"can_send_audios",
                                     [NSNumber numberWithBool:NO], @"can_send_documents",
                                     [NSNumber numberWithBool:NO], @"can_send_photos",
                                     [NSNumber numberWithBool:NO], @"can_send_videos",
                                     [NSNumber numberWithBool:NO], @"can_send_video_notes",
                                     [NSNumber numberWithBool:NO], @"can_send_voice_notes",
                                     [NSNumber numberWithBool:NO], @"can_send_polls",
                                     [NSNumber numberWithBool:NO], @"can_send_other_messages",
                                     [NSNumber numberWithBool:NO], @"can_add_link_previews",
                                     [NSNumber numberWithBool:NO], @"can_change_info",
                                     [NSNumber numberWithBool:NO], @"can_invite_users",
                                     [NSNumber numberWithBool:NO], @"can_pin_messages",
                                     [NSNumber numberWithBool:NO], @"can_create_topics",
                                     nil];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"chatMemberStatusRestricted", @"@type",
                [NSNumber numberWithBool:YES], @"is_member",
                [NSNumber numberWithInt:0], @"restricted_until_date",
                permissions, @"permissions",
                nil];
    }
    if ([role isEqualToString:@"banned"]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"chatMemberStatusBanned", @"@type",
                [NSNumber numberWithInt:0], @"banned_until_date",
                nil];
    }
    return [NSDictionary dictionaryWithObject:@"chatMemberStatusMember" forKey:@"@type"];
}

- (BOOL)setUserID:(NSNumber *)userID
         inChatID:(NSNumber *)chatID
             role:(NSString *)role
          timeout:(NSTimeInterval)timeout
            error:(NSError **)error {
    NSNumber *safeUserID = TGMemberSafeID(userID);
    NSNumber *safeChatID = TGMemberSafeID(chatID);
    if (!safeUserID || !safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat and user identifiers are required." code:370];
        }
        return NO;
    }
    NSDictionary *status = [self tg_statusForRole:role];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setChatMemberStatus", @"@type",
                             safeChatID, @"chat_id",
                             TGMemberSenderObject(safeUserID), @"member_id",
                             status, @"status",
                             nil];
    NSError *currentError = nil;
    NSDictionary *response = [self tg_memberRequest:request
                                             prefix:@"telegraphica-set-chat-member-status"
                                            timeout:timeout
                                               code:371
                                              error:&currentError];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }

    NSDictionary *legacyRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"setChatMemberStatus", @"@type",
                                   safeChatID, @"chat_id",
                                   safeUserID, @"user_id",
                                   status, @"status",
                                   nil];
    NSDictionary *legacyResponse = [self tg_memberRequest:legacyRequest
                                                   prefix:@"telegraphica-set-chat-member-status-legacy"
                                                  timeout:timeout
                                                     code:372
                                                    error:error];
    if ([[legacyResponse objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && !*error) {
        *error = currentError;
    }
    return NO;
}

@end
