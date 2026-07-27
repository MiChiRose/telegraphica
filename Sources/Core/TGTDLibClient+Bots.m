#import "TGTDLibClient+Bots.h"

@interface TGTDLibClient (BotsPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

static NSString *TGBotString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static NSNumber *TGBotNumber(id value) {
    return [value respondsToSelector:@selector(longLongValue)]
        ? [NSNumber numberWithLongLong:[value longLongValue]]
        : nil;
}

static BOOL TGBotObjectContainsPaidContent(id object) {
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = (NSDictionary *)object;
        NSEnumerator *keyEnumerator = [dictionary keyEnumerator];
        id key = nil;
        while ((key = [keyEnumerator nextObject])) {
            NSString *normalizedKey = [[TGBotString(key) lowercaseString]
                stringByReplacingOccurrencesOfString:@"_" withString:@""];
            if ([normalizedKey rangeOfString:@"invoice"].location != NSNotFound ||
                [normalizedKey rangeOfString:@"paidmedia"].location != NSNotFound ||
                [normalizedKey rangeOfString:@"starcount"].location != NSNotFound ||
                [normalizedKey rangeOfString:@"subscription"].location != NSNotFound) {
                return YES;
            }
            if (TGBotObjectContainsPaidContent([dictionary objectForKey:key])) {
                return YES;
            }
        }
        return NO;
    }
    if ([object isKindOfClass:[NSArray class]]) {
        NSUInteger index = 0;
        for (index = 0; index < [(NSArray *)object count]; index++) {
            if (TGBotObjectContainsPaidContent([(NSArray *)object objectAtIndex:index])) {
                return YES;
            }
        }
        return NO;
    }
    if ([object isKindOfClass:[NSString class]]) {
        NSString *type = [(NSString *)object lowercaseString];
        return ([type hasPrefix:@"inputmessageinvoice"] ||
                [type hasPrefix:@"messageinvoice"] ||
                [type rangeOfString:@"paidmedia"].location != NSNotFound);
    }
    return NO;
}

@implementation TGTDLibClient (Bots)

- (NSDictionary *)tg_botRequest:(NSDictionary *)request
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

- (NSDictionary *)botInteractionSummaryForUserID:(NSNumber *)userID
                                          timeout:(NSTimeInterval)timeout
                                            error:(NSError **)error {
    NSNumber *safeUserID = TGBotNumber(userID);
    if (!safeUserID) {
        if (error) {
            *error = [self errorWithDescription:@"Bot identifier is missing." code:540];
        }
        return nil;
    }
    NSDictionary *user = [self tg_botRequest:[NSDictionary dictionaryWithObjectsAndKeys:
                                              @"getUser", @"@type",
                                              safeUserID, @"user_id", nil]
                                      prefix:@"telegraphica-bot-user"
                                     timeout:MIN(timeout, 3.0)
                                        code:541
                                       error:error];
    if (!user) {
        return nil;
    }
    NSDictionary *fullInfo = [self tg_botRequest:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  @"getUserFullInfo", @"@type",
                                                  safeUserID, @"user_id", nil]
                                          prefix:@"telegraphica-bot-full-info"
                                         timeout:timeout
                                            code:542
                                           error:error];
    if (!fullInfo) {
        return nil;
    }
    NSDictionary *botInfo = [[fullInfo objectForKey:@"bot_info"] isKindOfClass:[NSDictionary class]]
        ? [fullInfo objectForKey:@"bot_info"] : [NSDictionary dictionary];
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:safeUserID forKey:@"user_id"];
    NSString *firstName = TGBotString([user objectForKey:@"first_name"]);
    NSString *lastName = TGBotString([user objectForKey:@"last_name"]);
    NSString *displayName = [[[NSArray arrayWithObjects:firstName, lastName, nil]
        componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [summary setObject:([displayName length] > 0 ? displayName : @"Bot") forKey:@"display_name"];
    NSString *description = TGBotString([botInfo objectForKey:@"description"]);
    if ([description length] == 0) {
        description = TGBotString([botInfo objectForKey:@"short_description"]);
    }
    [summary setObject:description forKey:@"description"];
    NSArray *rawCommands = [[botInfo objectForKey:@"commands"] isKindOfClass:[NSArray class]]
        ? [botInfo objectForKey:@"commands"] : [NSArray array];
    NSMutableArray *commands = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [rawCommands count]; index++) {
        NSDictionary *raw = [[rawCommands objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [rawCommands objectAtIndex:index] : nil;
        NSString *command = TGBotString([raw objectForKey:@"command"]);
        if ([command length] == 0) {
            continue;
        }
        [commands addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                             command, @"command",
                             TGBotString([raw objectForKey:@"description"]), @"description", nil]];
    }
    [summary setObject:commands forKey:@"commands"];
    return summary;
}

- (NSDictionary *)inlineQueryResultsForBotUserID:(NSNumber *)userID
                                          chatID:(NSNumber *)chatID
                                           query:(NSString *)query
                                          offset:(NSString *)offset
                                         timeout:(NSTimeInterval)timeout
                                           error:(NSError **)error {
    NSNumber *safeUserID = TGBotNumber(userID);
    NSNumber *safeChatID = TGBotNumber(chatID);
    if (!safeUserID || !safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Bot or target chat is missing." code:543];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getInlineQueryResults", @"@type",
                             safeUserID, @"bot_user_id",
                             safeChatID, @"chat_id",
                             [NSNull null], @"user_location",
                             query ? query : @"", @"query",
                             offset ? offset : @"", @"offset", nil];
    NSDictionary *response = [self tg_botRequest:request
                                          prefix:@"telegraphica-inline-query"
                                         timeout:timeout
                                            code:544
                                           error:error];
    if (!response) {
        return nil;
    }
    NSNumber *queryID = TGBotNumber([response objectForKey:@"inline_query_id"]);
    if (!queryID) {
        queryID = TGBotNumber([response objectForKey:@"query_id"]);
    }
    NSArray *rawResults = [[response objectForKey:@"results"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"results"] : [NSArray array];
    NSMutableArray *results = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [rawResults count]; index++) {
        NSDictionary *raw = [[rawResults objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [rawResults objectAtIndex:index] : nil;
        if (!raw || TGBotObjectContainsPaidContent(raw)) {
            continue;
        }
        NSString *resultID = TGBotString([raw objectForKey:@"id"]);
        if ([resultID length] == 0) {
            continue;
        }
        NSString *title = TGBotString([raw objectForKey:@"title"]);
        NSString *description = TGBotString([raw objectForKey:@"description"]);
        NSString *type = TGBotString([raw objectForKey:@"@type"]);
        if ([title length] == 0) {
            title = ([type hasPrefix:@"inlineQueryResult"] && [type length] > 17)
                ? [type substringFromIndex:17] : @"Result";
        }
        [results addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            resultID, @"result_id",
                            title, @"title",
                            description, @"description", nil]];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            (queryID ? queryID : @0), @"query_id",
            TGBotString([response objectForKey:@"next_offset"]), @"next_offset",
            results, @"results", nil];
}

- (BOOL)sendInlineQueryResultID:(NSString *)resultID
                       queryID:(NSNumber *)queryID
                      toChatID:(NSNumber *)chatID
                       timeout:(NSTimeInterval)timeout
                         error:(NSError **)error {
    NSNumber *safeChatID = TGBotNumber(chatID);
    NSNumber *safeQueryID = TGBotNumber(queryID);
    if (!safeChatID || !safeQueryID || [resultID length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Inline result is incomplete." code:545];
        }
        return NO;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                    @"sendInlineQueryResultMessage", @"@type",
                                    safeChatID, @"chat_id",
                                    [NSNull null], @"topic_id",
                                    [NSNull null], @"reply_to",
                                    [NSNull null], @"options",
                                    safeQueryID, @"query_id",
                                    resultID, @"result_id",
                                    @NO, @"hide_via_bot", nil];
    NSDictionary *response = [self tg_botRequest:request
                                          prefix:@"telegraphica-inline-send"
                                         timeout:timeout
                                            code:546
                                           error:error];
    if (response) {
        return YES;
    }
    [request removeObjectForKey:@"topic_id"];
    [request removeObjectForKey:@"reply_to"];
    [request setObject:@0 forKey:@"message_thread_id"];
    [request setObject:@0 forKey:@"reply_to_message_id"];
    return ([self tg_botRequest:request
                         prefix:@"telegraphica-inline-send-legacy"
                        timeout:timeout
                           code:546
                          error:error] != nil);
}

- (NSDictionary *)callbackQueryAnswerForChatID:(NSNumber *)chatID
                                      messageID:(NSNumber *)messageID
                                    buttonType:(NSDictionary *)buttonType
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error {
    NSNumber *safeChatID = TGBotNumber(chatID);
    NSNumber *safeMessageID = TGBotNumber(messageID);
    if (!safeChatID || !safeMessageID) {
        if (error) {
            *error = [self errorWithDescription:@"Callback message is missing." code:547];
        }
        return nil;
    }
    NSString *type = TGBotString([buttonType objectForKey:@"@type"]);
    NSDictionary *payload = nil;
    if ([type isEqualToString:@"inlineKeyboardButtonTypeCallback"]) {
        payload = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"callbackQueryPayloadData", @"@type",
                   TGBotString([buttonType objectForKey:@"data"]), @"data", nil];
    } else if ([type isEqualToString:@"inlineKeyboardButtonTypeCallbackGame"]) {
        payload = [NSDictionary dictionaryWithObject:@"callbackQueryPayloadGame" forKey:@"@type"];
    } else {
        if (error) {
            *error = [self errorWithDescription:@"This callback type needs the official Telegram client." code:547];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getCallbackQueryAnswer", @"@type",
                             safeChatID, @"chat_id",
                             safeMessageID, @"message_id",
                             payload, @"payload", nil];
    return [self tg_botRequest:request
                        prefix:@"telegraphica-bot-callback"
                       timeout:timeout
                          code:548
                         error:error];
}

- (NSDictionary *)loginURLInfoForChatID:(NSNumber *)chatID
                               messageID:(NSNumber *)messageID
                                buttonID:(NSNumber *)buttonID
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error {
    NSNumber *safeChatID = TGBotNumber(chatID);
    NSNumber *safeMessageID = TGBotNumber(messageID);
    NSNumber *safeButtonID = TGBotNumber(buttonID);
    if (!safeChatID || !safeMessageID || !safeButtonID) {
        if (error) {
            *error = [self errorWithDescription:@"Sign-in button is incomplete." code:549];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getLoginUrlInfo", @"@type",
                             safeChatID, @"chat_id",
                             safeMessageID, @"message_id",
                             safeButtonID, @"button_id", nil];
    return [self tg_botRequest:request prefix:@"telegraphica-login-url-info"
                       timeout:timeout code:549 error:error];
}

- (NSString *)resolvedLoginURLForChatID:(NSNumber *)chatID
                               messageID:(NSNumber *)messageID
                                buttonID:(NSNumber *)buttonID
                        allowWriteAccess:(BOOL)allowWriteAccess
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error {
    NSNumber *safeChatID = TGBotNumber(chatID);
    NSNumber *safeMessageID = TGBotNumber(messageID);
    NSNumber *safeButtonID = TGBotNumber(buttonID);
    if (!safeChatID || !safeMessageID || !safeButtonID) {
        if (error) {
            *error = [self errorWithDescription:@"Sign-in button is incomplete." code:550];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getLoginUrl", @"@type",
                             safeChatID, @"chat_id",
                             safeMessageID, @"message_id",
                             safeButtonID, @"button_id",
                             [NSNumber numberWithBool:allowWriteAccess], @"allow_write_access", nil];
    NSDictionary *response = [self tg_botRequest:request prefix:@"telegraphica-login-url"
                                          timeout:timeout code:550 error:error];
    return TGBotString([response objectForKey:@"url"]);
}

@end
