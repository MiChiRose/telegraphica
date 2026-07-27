#import "TGTDLibClient+Privacy.h"

@interface TGTDLibClient (PrivacyPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSDictionary *)contactSummaryFromUserObject:(NSDictionary *)userObject timeout:(NSTimeInterval)timeout;
@end

static NSDictionary *TGPrivacySettingObject(NSString *type) {
    return [NSDictionary dictionaryWithObject:type forKey:@"@type"];
}

static NSString *TGPrivacySimpleRule(NSArray *rules) {
    if (![rules isKindOfClass:[NSArray class]] || [rules count] == 0) {
        return @"custom";
    }
    BOOL hasExceptions = NO;
    NSUInteger index = 0;
    for (index = 0; index < [rules count]; index++) {
        NSString *type = [[[rules objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [rules objectAtIndex:index]
            : nil objectForKey:@"@type"];
        if ([type isEqualToString:@"userPrivacySettingRuleAllowAll"]) {
            return hasExceptions ? @"custom" : @"everybody";
        }
        if ([type isEqualToString:@"userPrivacySettingRuleAllowContacts"]) {
            return hasExceptions ? @"custom" : @"contacts";
        }
        if ([type isEqualToString:@"userPrivacySettingRuleRestrictAll"]) {
            return hasExceptions ? @"custom" : @"nobody";
        }
        hasExceptions = YES;
    }
    return @"custom";
}

@implementation TGTDLibClient (Privacy)

- (NSDictionary *)tg_privacyRequest:(NSDictionary *)request
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

- (NSArray *)tg_blockedSenderSummariesWithTimeout:(NSTimeInterval)timeout {
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getBlockedMessageSenders", @"@type",
                             TGPrivacySettingObject(@"blockListMain"), @"block_list",
                             [NSNumber numberWithInt:0], @"offset",
                             [NSNumber numberWithInt:100], @"limit",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-blocked-senders"
                                             timeout:timeout
                                                code:380
                                               error:NULL];
    NSArray *senders = [[response objectForKey:@"senders"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"senders"]
        : [NSArray array];
    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [senders count]; index++) {
        NSDictionary *sender = [[senders objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [senders objectAtIndex:index]
            : nil;
        NSString *senderType = [sender objectForKey:@"@type"];
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:sender forKey:@"sender"];
        if ([senderType isEqualToString:@"messageSenderUser"]) {
            NSNumber *userID = [sender objectForKey:@"user_id"];
            NSDictionary *userRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"getUser", @"@type", userID, @"user_id", nil];
            NSDictionary *user = [self tg_privacyRequest:userRequest
                                                  prefix:@"telegraphica-blocked-user"
                                                 timeout:MIN(timeout, 0.8)
                                                    code:381
                                                   error:NULL];
            NSDictionary *contact = [self contactSummaryFromUserObject:user timeout:timeout];
            NSString *displayName = [contact objectForKey:@"display_name"];
            [summary setObject:([displayName length] > 0
                                ? displayName
                                : [NSString stringWithFormat:@"User %@", userID])
                        forKey:@"title"];
        } else if ([senderType isEqualToString:@"messageSenderChat"]) {
            NSNumber *chatID = [sender objectForKey:@"chat_id"];
            NSDictionary *chatRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"getChat", @"@type", chatID, @"chat_id", nil];
            NSDictionary *chat = [self tg_privacyRequest:chatRequest
                                                  prefix:@"telegraphica-blocked-chat"
                                                 timeout:MIN(timeout, 0.8)
                                                    code:382
                                                   error:NULL];
            [summary setObject:([[chat objectForKey:@"title"] length] > 0
                                ? [chat objectForKey:@"title"]
                                : [NSString stringWithFormat:@"Chat %@", chatID])
                        forKey:@"title"];
        }
        [summaries addObject:summary];
    }
    return summaries;
}

- (NSDictionary *)privacyAndRetentionSummaryWithTimeout:(NSTimeInterval)timeout
                                                   error:(NSError **)error {
    NSArray *settingTypes = [NSArray arrayWithObjects:
                             @"userPrivacySettingShowStatus",
                             @"userPrivacySettingShowProfilePhoto",
                             @"userPrivacySettingShowPhoneNumber",
                             @"userPrivacySettingAllowFindingByPhoneNumber",
                             @"userPrivacySettingAllowCalls",
                             @"userPrivacySettingAllowPeerToPeerCalls",
                             @"userPrivacySettingAllowChatInvites",
                             @"userPrivacySettingShowBio",
                             nil];
    NSMutableArray *settings = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [settingTypes count]; index++) {
        NSString *type = [settingTypes objectAtIndex:index];
        NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"getUserPrivacySettingRules", @"@type",
                                 TGPrivacySettingObject(type), @"setting",
                                 nil];
        NSDictionary *response = [self tg_privacyRequest:request
                                                  prefix:@"telegraphica-privacy-rule"
                                                 timeout:MIN(timeout, 1.5)
                                                    code:383
                                                   error:(index == 0 ? error : NULL)];
        NSArray *rules = [[response objectForKey:@"rules"] isKindOfClass:[NSArray class]]
            ? [response objectForKey:@"rules"]
            : nil;
        if (rules) {
            [settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                 type, @"type",
                                 TGPrivacySimpleRule(rules), @"rule",
                                 rules, @"rules",
                                 nil]];
        }
    }

    NSDictionary *ttlResponse = [self tg_privacyRequest:
                                 [NSDictionary dictionaryWithObject:@"getAccountTtl" forKey:@"@type"]
                                                   prefix:@"telegraphica-account-ttl"
                                                  timeout:MIN(timeout, 2.0)
                                                     code:384
                                                    error:NULL];
    NSDictionary *autoDeleteResponse = [self tg_privacyRequest:
                                        [NSDictionary dictionaryWithObject:@"getDefaultMessageAutoDeleteTime" forKey:@"@type"]
                                                          prefix:@"telegraphica-default-auto-delete"
                                                         timeout:MIN(timeout, 2.0)
                                                            code:385
                                                           error:NULL];
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:settings forKey:@"settings"];
    [summary setObject:[self tg_blockedSenderSummariesWithTimeout:timeout] forKey:@"blocked"];
    if ([[ttlResponse objectForKey:@"days"] respondsToSelector:@selector(integerValue)]) {
        [summary setObject:[NSNumber numberWithInteger:[[ttlResponse objectForKey:@"days"] integerValue]]
                    forKey:@"account_ttl_days"];
    }
    if ([[autoDeleteResponse objectForKey:@"time"] respondsToSelector:@selector(integerValue)]) {
        [summary setObject:[NSNumber numberWithInteger:[[autoDeleteResponse objectForKey:@"time"] integerValue]]
                    forKey:@"default_auto_delete_time"];
    }
    return summary;
}

- (BOOL)setPrivacySettingType:(NSString *)settingType
                          rule:(NSString *)rule
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error {
    NSDictionary *ruleObject = nil;
    if ([rule isEqualToString:@"everybody"]) {
        ruleObject = TGPrivacySettingObject(@"userPrivacySettingRuleAllowAll");
    } else if ([rule isEqualToString:@"contacts"]) {
        ruleObject = TGPrivacySettingObject(@"userPrivacySettingRuleAllowContacts");
    } else if ([rule isEqualToString:@"nobody"]) {
        ruleObject = TGPrivacySettingObject(@"userPrivacySettingRuleRestrictAll");
    }
    if ([settingType length] == 0 || !ruleObject) {
        if (error) {
            *error = [self errorWithDescription:@"Privacy setting and rule are required." code:386];
        }
        return NO;
    }
    NSDictionary *rules = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"userPrivacySettingRules", @"@type",
                           [NSArray arrayWithObject:ruleObject], @"rules",
                           nil];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setUserPrivacySettingRules", @"@type",
                             TGPrivacySettingObject(settingType), @"setting",
                             rules, @"rules",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-set-privacy-rule"
                                             timeout:timeout
                                                code:387
                                               error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)setBlockedSender:(NSDictionary *)sender
                 blocked:(BOOL)blocked
                 timeout:(NSTimeInterval)timeout
                   error:(NSError **)error {
    if (![sender isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Message sender is missing." code:388];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setMessageSenderBlockList", @"@type",
                             sender, @"sender_id",
                             blocked ? TGPrivacySettingObject(@"blockListMain") : (id)[NSNull null], @"block_list",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-set-block-list"
                                             timeout:timeout
                                                code:389
                                               error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)setAccountTTLInDays:(NSInteger)days
                    timeout:(NSTimeInterval)timeout
                      error:(NSError **)error {
    NSDictionary *ttl = [NSDictionary dictionaryWithObjectsAndKeys:
                         @"accountTtl", @"@type",
                         [NSNumber numberWithInteger:days], @"days",
                         nil];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setAccountTtl", @"@type",
                             ttl, @"ttl",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-set-account-ttl"
                                             timeout:timeout
                                                code:390
                                               error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)setDefaultMessageAutoDeleteTime:(NSInteger)seconds
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error {
    NSDictionary *value = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"messageAutoDeleteTime", @"@type",
                           [NSNumber numberWithInteger:seconds], @"time",
                           nil];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setDefaultMessageAutoDeleteTime", @"@type",
                             value, @"message_auto_delete_time",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-set-default-auto-delete"
                                             timeout:timeout
                                                code:391
                                               error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)setMessageAutoDeleteTime:(NSInteger)seconds
                       forChatID:(NSNumber *)chatID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:392];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setChatMessageAutoDeleteTime", @"@type",
                             [NSNumber numberWithLongLong:[chatID longLongValue]], @"chat_id",
                             [NSNumber numberWithInteger:seconds], @"message_auto_delete_time",
                             nil];
    NSDictionary *response = [self tg_privacyRequest:request
                                              prefix:@"telegraphica-set-chat-auto-delete"
                                             timeout:timeout
                                                code:393
                                               error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

@end
