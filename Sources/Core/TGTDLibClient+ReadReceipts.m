#import "TGTDLibClient.h"

@interface TGTDLibClient (ReadReceiptsPrivate)
- (NSNumber *)userOpenedChatSelectionGenerationForChatID:(NSNumber *)chatID;
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)extraPrefix
    timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (BOOL)sendReadReceiptForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID
    messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs
    selectionGeneration:(NSNumber *)generation forceRead:(BOOL)forceRead
    timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end

@implementation TGTDLibClient (ReadReceipts)
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self markMessagesAsReadForChatID:chatID messageThreadID:nil messageIDs:messageIDs timeout:timeout error:error];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self markMessagesAsReadForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil messageIDs:messageIDs timeout:timeout error:error];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendReadReceiptForChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind
        messageIDs:messageIDs selectionGeneration:nil forceRead:YES timeout:timeout error:error];
}

- (BOOL)markVisibleMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (error) *error = nil;
    NSNumber *generation = [self userOpenedChatSelectionGenerationForChatID:chatID];
    if (!generation) return NO;
    return [self sendReadReceiptForChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind
        messageIDs:messageIDs selectionGeneration:generation forceRead:NO timeout:timeout error:error];
}

- (BOOL)sendReadReceiptForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID
              messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs
           selectionGeneration:(NSNumber *)generation forceRead:(BOOL)forceRead
                       timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)messageTopicKind;
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:57];
        }
        return NO;
    }
    if (![messageIDs isKindOfClass:[NSArray class]] || [messageIDs count] == 0) {
        return YES;
    }

    NSMutableArray *safeMessageIDs = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [messageIDs count]; index++) {
        id messageID = [messageIDs objectAtIndex:index];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            [safeMessageIDs addObject:[NSNumber numberWithLongLong:[messageID longLongValue]]];
        }
    }
    if ([safeMessageIDs count] == 0) {
        return YES;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to mark messages read. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:58];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"viewMessages" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:safeMessageIDs forKey:@"message_ids"];
    [request setObject:[NSDictionary dictionaryWithObject:@"messageSourceChatHistory" forKey:@"@type"] forKey:@"source"];
    [request setObject:[NSNumber numberWithBool:forceRead] forKey:@"force_read"];

    if (!forceRead && ![[self userOpenedChatSelectionGenerationForChatID:chatID] isEqualToNumber:generation]) return NO;
    NSError *currentSchemaError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-view-messages"
                                                           timeout:timeout
                                                         errorCode:59
                                                             error:&currentSchemaError];
    if (!response) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest removeObjectForKey:@"source"];
        NSNumber *safeThreadID = [NSNumber numberWithLongLong:0];
        if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
            safeThreadID = [NSNumber numberWithLongLong:[messageThreadID longLongValue]];
        }
        [legacyRequest setObject:safeThreadID forKey:@"message_thread_id"];
        if (!forceRead && ![[self userOpenedChatSelectionGenerationForChatID:chatID] isEqualToNumber:generation]) return NO;
        NSError *legacySchemaError = nil;
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:@"telegraphica-view-messages-legacy"
                                                 timeout:timeout
                                               errorCode:59
                                                   error:&legacySchemaError];
        if (!response) {
            if (error && *error == nil) {
                *error = legacySchemaError ? legacySchemaError : currentSchemaError;
            }
            return NO;
        }
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib viewMessages returned an unexpected response." code:60];
        }
        return NO;
    }
    return YES;
}

@end
