#import "TGChatDisplayPreferences.h"

NSString * const TGChatDisplayPreferencesDidChangeNotification = @"TGChatDisplayPreferencesDidChangeNotification";

static NSString * const TGChatMessagesAsBlocksDefaultsKey = @"TelegraphicaChatMessagesAsBlocks";
static NSString * const TGChatMessageTextSizeDefaultsKey = @"TelegraphicaChatMessageTextSizeLevel";
static NSString * const TGChatMessagesAsBlocksOverridesDefaultsKey = @"TelegraphicaChatMessagesAsBlocksOverrides";
static NSString * const TGChatMessageTextSizeOverridesDefaultsKey = @"TelegraphicaChatMessageTextSizeLevelOverrides";

static NSInteger TGClampedChatMessageTextSizeLevel(NSInteger level) {
    if (level < TGChatMessageTextSizeSmall) {
        return TGChatMessageTextSizeSmall;
    }
    if (level > TGChatMessageTextSizeVeryLarge) {
        return TGChatMessageTextSizeVeryLarge;
    }
    return level;
}

static void TGPostChatDisplayPreferencesDidChange(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TGChatDisplayPreferencesDidChangeNotification object:nil];
}

static NSString *TGChatDisplayPreferencesTargetKey(NSNumber *chatID, NSNumber *messageThreadID) {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    long long threadID = ([messageThreadID respondsToSelector:@selector(longLongValue)] ? [messageThreadID longLongValue] : 0LL);
    return [NSString stringWithFormat:@"%lld:%lld", [chatID longLongValue], threadID];
}

static NSMutableDictionary *TGMutableOverridesDictionaryForKey(NSString *defaultsKey) {
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:defaultsKey];
    if ([stored isKindOfClass:[NSDictionary class]]) {
        return [NSMutableDictionary dictionaryWithDictionary:stored];
    }
    return [NSMutableDictionary dictionary];
}

BOOL TGChatMessagesAsBlocksEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:TGChatMessagesAsBlocksDefaultsKey];
}

void TGSetChatMessagesAsBlocksEnabled(BOOL enabled) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL current = [defaults boolForKey:TGChatMessagesAsBlocksDefaultsKey];
    if (current == enabled) {
        return;
    }
    [defaults setBool:enabled forKey:TGChatMessagesAsBlocksDefaultsKey];
    [defaults synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

BOOL TGChatMessagesAsBlocksEnabledForTarget(NSNumber *chatID, NSNumber *messageThreadID) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    NSDictionary *overrides = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TGChatMessagesAsBlocksOverridesDefaultsKey];
    id value = [overrides objectForKey:targetKey];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return TGChatMessagesAsBlocksEnabled();
}

void TGSetChatMessagesAsBlocksEnabledForTarget(NSNumber *chatID, NSNumber *messageThreadID, BOOL enabled) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    if ([targetKey length] == 0) {
        TGSetChatMessagesAsBlocksEnabled(enabled);
        return;
    }
    NSMutableDictionary *overrides = TGMutableOverridesDictionaryForKey(TGChatMessagesAsBlocksOverridesDefaultsKey);
    NSNumber *current = [overrides objectForKey:targetKey];
    if ([current respondsToSelector:@selector(boolValue)] && [current boolValue] == enabled) {
        return;
    }
    [overrides setObject:[NSNumber numberWithBool:enabled] forKey:targetKey];
    [[NSUserDefaults standardUserDefaults] setObject:overrides forKey:TGChatMessagesAsBlocksOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

void TGClearChatMessagesAsBlocksOverrideForTarget(NSNumber *chatID, NSNumber *messageThreadID) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    if ([targetKey length] == 0) {
        return;
    }
    NSMutableDictionary *overrides = TGMutableOverridesDictionaryForKey(TGChatMessagesAsBlocksOverridesDefaultsKey);
    if (![overrides objectForKey:targetKey]) {
        return;
    }
    [overrides removeObjectForKey:targetKey];
    [[NSUserDefaults standardUserDefaults] setObject:overrides forKey:TGChatMessagesAsBlocksOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

NSInteger TGChatMessageTextSizeLevel(void) {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGChatMessageTextSizeDefaultsKey];
    if (![stored respondsToSelector:@selector(integerValue)]) {
        return TGChatMessageTextSizeNormal;
    }
    return TGClampedChatMessageTextSizeLevel([stored integerValue]);
}

void TGSetChatMessageTextSizeLevel(NSInteger level) {
    NSInteger clamped = TGClampedChatMessageTextSizeLevel(level);
    if (TGChatMessageTextSizeLevel() == clamped) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:clamped forKey:TGChatMessageTextSizeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

NSInteger TGChatMessageTextSizeLevelForTarget(NSNumber *chatID, NSNumber *messageThreadID) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    NSDictionary *overrides = [[NSUserDefaults standardUserDefaults] dictionaryForKey:TGChatMessageTextSizeOverridesDefaultsKey];
    id value = [overrides objectForKey:targetKey];
    if ([value respondsToSelector:@selector(integerValue)]) {
        return TGClampedChatMessageTextSizeLevel([value integerValue]);
    }
    return TGChatMessageTextSizeLevel();
}

void TGSetChatMessageTextSizeLevelForTarget(NSNumber *chatID, NSNumber *messageThreadID, NSInteger level) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    if ([targetKey length] == 0) {
        TGSetChatMessageTextSizeLevel(level);
        return;
    }
    NSInteger clamped = TGClampedChatMessageTextSizeLevel(level);
    NSMutableDictionary *overrides = TGMutableOverridesDictionaryForKey(TGChatMessageTextSizeOverridesDefaultsKey);
    NSNumber *current = [overrides objectForKey:targetKey];
    if ([current respondsToSelector:@selector(integerValue)] && TGClampedChatMessageTextSizeLevel([current integerValue]) == clamped) {
        return;
    }
    [overrides setObject:[NSNumber numberWithInteger:clamped] forKey:targetKey];
    [[NSUserDefaults standardUserDefaults] setObject:overrides forKey:TGChatMessageTextSizeOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

void TGClearChatMessageTextSizeOverrideForTarget(NSNumber *chatID, NSNumber *messageThreadID) {
    NSString *targetKey = TGChatDisplayPreferencesTargetKey(chatID, messageThreadID);
    if ([targetKey length] == 0) {
        return;
    }
    NSMutableDictionary *overrides = TGMutableOverridesDictionaryForKey(TGChatMessageTextSizeOverridesDefaultsKey);
    if (![overrides objectForKey:targetKey]) {
        return;
    }
    [overrides removeObjectForKey:targetKey];
    [[NSUserDefaults standardUserDefaults] setObject:overrides forKey:TGChatMessageTextSizeOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGPostChatDisplayPreferencesDidChange();
}

NSString *TGChatMessageTextSizeLocalizationKeyForLevel(NSInteger level) {
    switch (TGClampedChatMessageTextSizeLevel(level)) {
        case TGChatMessageTextSizeSmall:
            return @"settings.chatText.small";
        case TGChatMessageTextSizeLarge:
            return @"settings.chatText.large";
        case TGChatMessageTextSizeVeryLarge:
            return @"settings.chatText.veryLarge";
        case TGChatMessageTextSizeNormal:
        default:
            return @"settings.chatText.normal";
    }
}

CGFloat TGChatMessageBodyFontSize(void) {
    switch (TGChatMessageTextSizeLevel()) {
        case TGChatMessageTextSizeSmall:
            return 11.0;
        case TGChatMessageTextSizeLarge:
            return 14.0;
        case TGChatMessageTextSizeVeryLarge:
            return 16.0;
        case TGChatMessageTextSizeNormal:
        default:
            return 12.0;
    }
}

CGFloat TGChatMessageSecondaryFontSize(void) {
    CGFloat size = TGChatMessageBodyFontSize() - 2.0;
    return (size < 9.0) ? 9.0 : size;
}

CGFloat TGChatMessageMetaFontSize(void) {
    CGFloat size = TGChatMessageBodyFontSize() - 3.0;
    return (size < 9.0) ? 9.0 : size;
}

NSFont *TGChatMessageBodyFont(void) {
    return [NSFont systemFontOfSize:TGChatMessageBodyFontSize()];
}

NSFont *TGChatMessageBoldBodyFont(void) {
    return [NSFont boldSystemFontOfSize:TGChatMessageBodyFontSize()];
}

NSFont *TGChatMessageSecondaryFont(void) {
    return [NSFont systemFontOfSize:TGChatMessageSecondaryFontSize()];
}

NSFont *TGChatMessageBoldSecondaryFont(void) {
    return [NSFont boldSystemFontOfSize:TGChatMessageSecondaryFontSize()];
}

NSFont *TGChatMessageMetaFont(void) {
    return [NSFont systemFontOfSize:TGChatMessageMetaFontSize()];
}
