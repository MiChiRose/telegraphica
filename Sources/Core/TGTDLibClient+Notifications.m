#import "TGTDLibClient+Notifications.h"
#include <limits.h>

@interface TGTDLibClient (NotificationsPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSDictionary *)tg_notificationChatObjectForChatID:(NSNumber *)chatID
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error;
- (BOOL)tg_setNotificationSettings:(NSDictionary *)settings
                         forChatID:(NSNumber *)chatID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error;
@end

static NSNumber *TGNotificationSafeChatID(id value) {
    if (![value respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    long long chatID = [value longLongValue];
    return chatID != 0 ? [NSNumber numberWithLongLong:chatID] : nil;
}

static NSString *TGNotificationSafeString(id value) {
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : @"";
}

static NSDictionary *TGNotificationSettingsFromChatObject(NSDictionary *chat) {
    id settings = [chat objectForKey:@"notification_settings"];
    return [settings isKindOfClass:[NSDictionary class]] ? (NSDictionary *)settings : nil;
}

static NSMutableDictionary *TGMutableNotificationSettings(NSDictionary *chat) {
    NSDictionary *existing = TGNotificationSettingsFromChatObject(chat);
    NSMutableDictionary *settings = existing
        ? [NSMutableDictionary dictionaryWithDictionary:existing]
        : [NSMutableDictionary dictionary];
    [settings setObject:@"chatNotificationSettings" forKey:@"@type"];
    return settings;
}

static BOOL TGNotificationSettingsMuted(NSDictionary *settings) {
    id muteFor = [settings objectForKey:@"mute_for"];
    return [muteFor respondsToSelector:@selector(integerValue)] && [muteFor integerValue] > 0;
}

@implementation TGTDLibClient (Notifications)

- (NSDictionary *)tg_notificationChatObjectForChatID:(NSNumber *)chatID
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error {
    NSNumber *safeChatID = TGNotificationSafeChatID(chatID);
    if (!safeChatID) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:350];
        }
        return nil;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getChat", @"@type",
                             safeChatID, @"chat_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-chat-notification-settings"
                                                            timeout:timeout
                                                          errorCode:351
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"chat"]) {
        return response;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib returned an unexpected chat notification response." code:352];
    }
    return nil;
}

- (NSDictionary *)chatNotificationSettingsSummaryForChatID:(NSNumber *)chatID
                                                    timeout:(NSTimeInterval)timeout
                                                      error:(NSError **)error {
    NSDictionary *chat = [self tg_notificationChatObjectForChatID:chatID timeout:timeout error:error];
    if (!chat) {
        return nil;
    }
    NSDictionary *settings = TGNotificationSettingsFromChatObject(chat);
    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    NSNumber *safeChatID = TGNotificationSafeChatID([chat objectForKey:@"id"]);
    if (safeChatID) {
        [summary setObject:safeChatID forKey:@"chat_id"];
    }
    [summary setObject:TGNotificationSafeString([chat objectForKey:@"title"]) forKey:@"title"];
    if (settings) {
        [summary setObject:settings forKey:@"settings"];
        [summary setObject:[NSNumber numberWithBool:TGNotificationSettingsMuted(settings)] forKey:@"muted"];
        [summary setObject:[NSNumber numberWithBool:[[settings objectForKey:@"show_preview"] boolValue]]
                    forKey:@"show_preview"];
        [summary setObject:[NSNumber numberWithBool:[[settings objectForKey:@"use_default_mute_for"] boolValue]]
                    forKey:@"use_default_mute_for"];
        [summary setObject:[NSNumber numberWithBool:[[settings objectForKey:@"use_default_show_preview"] boolValue]]
                    forKey:@"use_default_show_preview"];
    } else {
        [summary setObject:[NSNumber numberWithBool:NO] forKey:@"muted"];
        [summary setObject:[NSNumber numberWithBool:YES] forKey:@"show_preview"];
        [summary setObject:[NSNumber numberWithBool:YES] forKey:@"use_default_mute_for"];
        [summary setObject:[NSNumber numberWithBool:YES] forKey:@"use_default_show_preview"];
    }
    return summary;
}

- (BOOL)tg_setNotificationSettings:(NSDictionary *)settings
                         forChatID:(NSNumber *)chatID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error {
    NSNumber *safeChatID = TGNotificationSafeChatID(chatID);
    if (!safeChatID || ![settings isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat notification settings are missing." code:353];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"setChatNotificationSettings", @"@type",
                             safeChatID, @"chat_id",
                             settings, @"notification_settings",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-set-chat-notifications"
                                                            timeout:timeout
                                                          errorCode:354
                                                              error:error];
    if ([[response objectForKey:@"@type"] isEqualToString:@"ok"]) {
        return YES;
    }
    if (error && response && !*error) {
        *error = [self errorWithDescription:@"TDLib did not accept the chat notification settings." code:355];
    }
    return NO;
}

- (BOOL)setChatNotificationMuteForChatID:(NSNumber *)chatID
                                 muteFor:(NSTimeInterval)muteFor
                                 timeout:(NSTimeInterval)timeout
                                   error:(NSError **)error {
    NSDictionary *chat = [self tg_notificationChatObjectForChatID:chatID timeout:timeout error:error];
    if (!chat) {
        return NO;
    }
    NSMutableDictionary *settings = TGMutableNotificationSettings(chat);
    long long seconds = 0;
    if (muteFor < 0.0) {
        seconds = INT_MAX;
    } else if (muteFor > (NSTimeInterval)INT_MAX) {
        seconds = INT_MAX;
    } else if (muteFor > 0.0) {
        seconds = (long long)muteFor;
    }
    [settings setObject:[NSNumber numberWithBool:NO] forKey:@"use_default_mute_for"];
    [settings setObject:[NSNumber numberWithLongLong:seconds] forKey:@"mute_for"];
    return [self tg_setNotificationSettings:settings forChatID:chatID timeout:timeout error:error];
}

- (BOOL)setChatNotificationPreviewForChatID:(NSNumber *)chatID
                                showPreview:(BOOL)showPreview
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError **)error {
    NSDictionary *chat = [self tg_notificationChatObjectForChatID:chatID timeout:timeout error:error];
    if (!chat) {
        return NO;
    }
    NSMutableDictionary *settings = TGMutableNotificationSettings(chat);
    [settings setObject:[NSNumber numberWithBool:NO] forKey:@"use_default_show_preview"];
    [settings setObject:[NSNumber numberWithBool:showPreview] forKey:@"show_preview"];
    return [self tg_setNotificationSettings:settings forChatID:chatID timeout:timeout error:error];
}

- (BOOL)resetChatNotificationSettingsForChatID:(NSNumber *)chatID
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    NSDictionary *chat = [self tg_notificationChatObjectForChatID:chatID timeout:timeout error:error];
    if (!chat) {
        return NO;
    }
    NSMutableDictionary *settings = TGMutableNotificationSettings(chat);
    NSArray *keys = [[settings allKeys] copy];
    NSUInteger index = 0;
    for (index = 0; index < [keys count]; index++) {
        id key = [keys objectAtIndex:index];
        if ([key isKindOfClass:[NSString class]] && [(NSString *)key hasPrefix:@"use_default_"]) {
            [settings setObject:[NSNumber numberWithBool:YES] forKey:key];
        }
    }
    [keys release];
    [settings setObject:[NSNumber numberWithLongLong:0] forKey:@"mute_for"];
    return [self tg_setNotificationSettings:settings forChatID:chatID timeout:timeout error:error];
}

- (NSArray *)chatNotificationExceptionSummariesWithTimeout:(NSTimeInterval)timeout
                                                      error:(NSError **)error {
    NSDictionary *request = [NSDictionary dictionaryWithObject:@"getChatNotificationSettingsExceptions"
                                                        forKey:@"@type"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-notification-exceptions"
                                                            timeout:timeout
                                                          errorCode:356
                                                              error:error];
    id chatIDs = [response objectForKey:@"chat_ids"];
    if (![[response objectForKey:@"@type"] isEqualToString:@"chats"] ||
        ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error && response && !*error) {
            *error = [self errorWithDescription:@"TDLib did not return notification exceptions." code:357];
        }
        return nil;
    }

    NSMutableArray *summaries = [NSMutableArray array];
    NSUInteger count = MIN((NSUInteger)[(NSArray *)chatIDs count], (NSUInteger)200);
    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        NSNumber *chatID = TGNotificationSafeChatID([(NSArray *)chatIDs objectAtIndex:index]);
        if (!chatID) {
            continue;
        }
        NSDictionary *summary = [self chatNotificationSettingsSummaryForChatID:chatID
                                                                        timeout:MIN(timeout, 2.0)
                                                                          error:NULL];
        if (summary) {
            [summaries addObject:summary];
        }
    }
    return summaries;
}

@end
