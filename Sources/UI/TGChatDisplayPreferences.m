#import "TGChatDisplayPreferences.h"

NSString * const TGChatDisplayPreferencesDidChangeNotification = @"TGChatDisplayPreferencesDidChangeNotification";

static NSString * const TGChatMessagesAsBlocksDefaultsKey = @"TelegraphicaChatMessagesAsBlocks";
static NSString * const TGChatMessageTextSizeDefaultsKey = @"TelegraphicaChatMessageTextSizeLevel";

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
