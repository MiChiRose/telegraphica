#import "TGTDLibClient+SecretChats.h"

#import "../Services/TGBase64Compatibility.h"
#import "TGSecretChatKey.h"

@interface TGTDLibClient (SecretChatsPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

static NSNumber *TGSecretChatSafeIdentifier(id value) {
    if (![value respondsToSelector:@selector(longLongValue)] || [value longLongValue] == 0LL) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[value longLongValue]];
}

static NSString *TGSecretChatSafeString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

@implementation TGTDLibClient (SecretChats)

- (NSDictionary *)tg_secretChatObjectForChatID:(NSNumber *)chatID
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    NSNumber *safeChatID = TGSecretChatSafeIdentifier(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:440];
        }
        return nil;
    }
    NSDictionary *chatRequest = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"getChat", @"@type",
                                 safeChatID, @"chat_id",
                                 nil];
    NSDictionary *chat = [self sendTDLibRequestAndWaitForExtra:chatRequest
                                                    extraPrefix:@"telegraphica-secret-chat-source"
                                                        timeout:timeout
                                                      errorCode:441
                                                          error:error];
    NSDictionary *type = [[chat objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [chat objectForKey:@"type"] : nil;
    if (![[type objectForKey:@"@type"] isEqualToString:@"chatTypeSecret"]) {
        if (error) {
            *error = [self errorWithDescription:@"This conversation is not a secret chat." code:442];
        }
        return nil;
    }
    NSNumber *secretChatID = TGSecretChatSafeIdentifier([type objectForKey:@"secret_chat_id"]);
    if (!secretChatID) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not provide a secret chat identifier." code:443];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getSecretChat", @"@type",
                             secretChatID, @"secret_chat_id",
                             nil];
    NSDictionary *secretChat = [self sendTDLibRequestAndWaitForExtra:request
                                                          extraPrefix:@"telegraphica-secret-chat-details"
                                                              timeout:timeout
                                                            errorCode:444
                                                                error:error];
    return [[secretChat objectForKey:@"@type"] isEqualToString:@"secretChat"] ? secretChat : nil;
}

- (NSDictionary *)secretChatSummaryForChatID:(NSNumber *)chatID
                                      timeout:(NSTimeInterval)timeout
                                        error:(NSError **)error {
    NSDictionary *secretChat = [self tg_secretChatObjectForChatID:chatID timeout:timeout error:error];
    if (!secretChat) {
        return nil;
    }
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    NSArray *copiedKeys = [NSArray arrayWithObjects:@"id", @"user_id", @"is_outbound", @"layer", nil];
    for (NSString *key in copiedKeys) {
        id value = [secretChat objectForKey:key];
        if (value) {
            [summary setObject:value forKey:key];
        }
    }
    NSDictionary *state = [[secretChat objectForKey:@"state"] isKindOfClass:[NSDictionary class]]
        ? [secretChat objectForKey:@"state"] : nil;
    NSString *stateType = TGSecretChatSafeString([state objectForKey:@"@type"]);
    if ([stateType length] > 0) {
        [summary setObject:stateType forKey:@"state"];
    }
    NSString *encodedKeyHash = TGSecretChatSafeString([secretChat objectForKey:@"key_hash"]);
    NSData *keyHashData = TGDataFromBase64String(encodedKeyHash);
    if ([keyHashData length] >= 36) {
        [summary setObject:keyHashData forKey:@"key_hash_data"];
        [summary setObject:[TGSecretChatKey fingerprintForKeyHashData:keyHashData]
                    forKey:@"key_fingerprint"];
    }
    return summary;
}

- (BOOL)closeSecretChatForChatID:(NSNumber *)chatID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error {
    NSDictionary *secretChat = [self tg_secretChatObjectForChatID:chatID timeout:timeout error:error];
    NSNumber *secretChatID = TGSecretChatSafeIdentifier([secretChat objectForKey:@"id"]);
    if (!secretChatID) {
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"closeSecretChat", @"@type",
                             secretChatID, @"secret_chat_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-close-secret-chat"
                                                            timeout:timeout
                                                          errorCode:445
                                                              error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

@end
