#import "TGResourcePolicy.h"

NSString * const TGResourcePolicyDidChangeNotification = @"TGResourcePolicyDidChangeNotification";

static NSString * const TGResourcePolicyInitializedKey = @"TelegraphicaResourcePolicyInitialized";
static NSString * const TGResourcePolicyEconomyModeKey = @"TelegraphicaEconomyModeEnabled";
static NSString * const TGResourcePolicyAutoPhotoKey = @"TelegraphicaAutoDownloadPhotos";
static NSString * const TGResourcePolicyAutoVideoKey = @"TelegraphicaAutoDownloadVideos";
static NSString * const TGResourcePolicyAutoDocumentKey = @"TelegraphicaAutoDownloadDocuments";
static NSString * const TGResourcePolicyMaxAutoDownloadBytesKey = @"TelegraphicaMaxAutoDownloadBytes";
static NSString * const TGResourcePolicyAutoplayAnimatedStickersKey = @"TelegraphicaAutoplayAnimatedStickers";
static NSString * const TGResourcePolicyMaximumActiveAnimationsKey = @"TelegraphicaMaximumActiveAnimations";
static NSString * const TGResourcePolicyStopAnimationsInactiveKey = @"TelegraphicaStopAnimationsWhenInactive";
static NSString * const TGResourcePolicyMediaCacheLimitBytesKey = @"TelegraphicaMediaCacheLimitBytes";

static long long TGResourceMB(long long value) {
    return value * 1024LL * 1024LL;
}

static void TGResourcePolicyPostChange(void) {
    [[NSNotificationCenter defaultCenter] postNotificationName:TGResourcePolicyDidChangeNotification object:nil];
}

static BOOL TGResourceBoolForKey(NSString *key, BOOL fallback) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return fallback;
}

static long long TGResourceLongLongForKey(NSString *key, long long fallback) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([value respondsToSelector:@selector(longLongValue)]) {
        long long numeric = [value longLongValue];
        return numeric > 0 ? numeric : fallback;
    }
    return fallback;
}

static void TGResourceSetBool(NSString *key, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
}

static void TGResourceSetLongLong(NSString *key, long long value) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithLongLong:value] forKey:key];
}

void TGResourcePolicyApplyDefaultsIfNeeded(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:TGResourcePolicyInitializedKey]) {
        return;
    }
    TGResourceSetBool(TGResourcePolicyEconomyModeKey, NO);
    TGResourceSetBool(TGResourcePolicyAutoPhotoKey, YES);
    TGResourceSetBool(TGResourcePolicyAutoVideoKey, YES);
    TGResourceSetBool(TGResourcePolicyAutoDocumentKey, YES);
    TGResourceSetLongLong(TGResourcePolicyMaxAutoDownloadBytesKey, TGResourceMB(20));
    TGResourceSetBool(TGResourcePolicyAutoplayAnimatedStickersKey, YES);
    TGResourceSetLongLong(TGResourcePolicyMaximumActiveAnimationsKey, 5);
    TGResourceSetBool(TGResourcePolicyStopAnimationsInactiveKey, YES);
    TGResourceSetLongLong(TGResourcePolicyMediaCacheLimitBytesKey, TGResourceMB(512));
    [defaults setBool:YES forKey:TGResourcePolicyInitializedKey];
    [defaults synchronize];
}

BOOL TGResourcePolicyEconomyModeEnabled(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    return TGResourceBoolForKey(TGResourcePolicyEconomyModeKey, NO);
}

void TGResourcePolicySetEconomyModeEnabled(BOOL enabled) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGResourceSetBool(TGResourcePolicyEconomyModeKey, enabled);
    if (enabled) {
        TGResourceSetBool(TGResourcePolicyAutoPhotoKey, YES);
        TGResourceSetBool(TGResourcePolicyAutoVideoKey, NO);
        TGResourceSetBool(TGResourcePolicyAutoDocumentKey, NO);
        TGResourceSetLongLong(TGResourcePolicyMaxAutoDownloadBytesKey, TGResourceMB(2));
        TGResourceSetBool(TGResourcePolicyAutoplayAnimatedStickersKey, NO);
        TGResourceSetLongLong(TGResourcePolicyMaximumActiveAnimationsKey, 1);
        TGResourceSetBool(TGResourcePolicyStopAnimationsInactiveKey, YES);
        TGResourceSetLongLong(TGResourcePolicyMediaCacheLimitBytesKey, TGResourceMB(128));
    } else {
        TGResourceSetBool(TGResourcePolicyAutoPhotoKey, YES);
        TGResourceSetBool(TGResourcePolicyAutoVideoKey, YES);
        TGResourceSetBool(TGResourcePolicyAutoDocumentKey, YES);
        TGResourceSetLongLong(TGResourcePolicyMaxAutoDownloadBytesKey, TGResourceMB(20));
        TGResourceSetBool(TGResourcePolicyAutoplayAnimatedStickersKey, YES);
        TGResourceSetLongLong(TGResourcePolicyMaximumActiveAnimationsKey, 5);
        TGResourceSetBool(TGResourcePolicyStopAnimationsInactiveKey, YES);
        TGResourceSetLongLong(TGResourcePolicyMediaCacheLimitBytesKey, TGResourceMB(512));
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

BOOL TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadType type) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    if (type == TGResourceAutoDownloadVideo) {
        return TGResourceBoolForKey(TGResourcePolicyAutoVideoKey, YES);
    }
    if (type == TGResourceAutoDownloadDocument) {
        return TGResourceBoolForKey(TGResourcePolicyAutoDocumentKey, YES);
    }
    return TGResourceBoolForKey(TGResourcePolicyAutoPhotoKey, YES);
}

void TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadType type, BOOL enabled) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    NSString *key = TGResourcePolicyAutoPhotoKey;
    if (type == TGResourceAutoDownloadVideo) {
        key = TGResourcePolicyAutoVideoKey;
    } else if (type == TGResourceAutoDownloadDocument) {
        key = TGResourcePolicyAutoDocumentKey;
    }
    TGResourceSetBool(key, enabled);
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

long long TGResourcePolicyMaxAutoDownloadBytes(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    return TGResourceLongLongForKey(TGResourcePolicyMaxAutoDownloadBytesKey, TGResourceMB(20));
}

void TGResourcePolicySetMaxAutoDownloadBytes(long long bytes) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGResourceSetLongLong(TGResourcePolicyMaxAutoDownloadBytesKey, bytes > 0 ? bytes : TGResourceMB(20));
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

NSArray *TGResourcePolicyMaxAutoDownloadChoices(void) {
    return [NSArray arrayWithObjects:
            [NSNumber numberWithLongLong:TGResourceMB(1)],
            [NSNumber numberWithLongLong:TGResourceMB(2)],
            [NSNumber numberWithLongLong:TGResourceMB(5)],
            [NSNumber numberWithLongLong:TGResourceMB(10)],
            [NSNumber numberWithLongLong:TGResourceMB(20)],
            [NSNumber numberWithLongLong:TGResourceMB(50)],
            nil];
}

NSString *TGResourcePolicyReadableSize(long long bytes) {
    if (bytes <= 0) {
        return @"0 B";
    }
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%lld B", bytes];
    }
    double kb = ((double)bytes) / 1024.0;
    if (kb < 1024.0) {
        if (kb >= 100.0) {
            return [NSString stringWithFormat:@"%.0f KB", kb];
        }
        return [NSString stringWithFormat:@"%.1f KB", kb];
    }
    double mb = ((double)bytes) / (1024.0 * 1024.0);
    if (mb >= 1024.0) {
        return [NSString stringWithFormat:@"%.1f GB", mb / 1024.0];
    }
    if (mb >= 10.0) {
        return [NSString stringWithFormat:@"%.0f MB", mb];
    }
    return [NSString stringWithFormat:@"%.1f MB", mb];
}

BOOL TGResourcePolicyAutoplayAnimatedStickers(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    return TGResourceBoolForKey(TGResourcePolicyAutoplayAnimatedStickersKey, YES);
}

void TGResourcePolicySetAutoplayAnimatedStickers(BOOL enabled) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGResourceSetBool(TGResourcePolicyAutoplayAnimatedStickersKey, enabled);
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

BOOL TGResourcePolicyAutoplayAnimatedStickersEnabled(void) {
    return TGResourcePolicyAutoplayAnimatedStickers();
}

void TGResourcePolicySetAutoplayAnimatedStickersEnabled(BOOL enabled) {
    TGResourcePolicySetAutoplayAnimatedStickers(enabled);
}

NSUInteger TGResourcePolicyMaximumActiveAnimations(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    long long count = TGResourceLongLongForKey(TGResourcePolicyMaximumActiveAnimationsKey, 5);
    if (count < 1) {
        count = 1;
    }
    if (count > 8) {
        count = 8;
    }
    return (NSUInteger)count;
}

NSUInteger TGResourcePolicyMaxActiveAnimations(void) {
    return TGResourcePolicyMaximumActiveAnimations();
}

void TGResourcePolicySetMaximumActiveAnimations(NSUInteger count) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    if (count < 1) {
        count = 1;
    }
    if (count > 8) {
        count = 8;
    }
    TGResourceSetLongLong(TGResourcePolicyMaximumActiveAnimationsKey, (long long)count);
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

void TGResourcePolicySetMaxActiveAnimations(NSUInteger count) {
    TGResourcePolicySetMaximumActiveAnimations(count);
}

NSArray *TGResourcePolicyMaximumActiveAnimationChoices(void) {
    return [NSArray arrayWithObjects:
            [NSNumber numberWithUnsignedInteger:1],
            [NSNumber numberWithUnsignedInteger:2],
            [NSNumber numberWithUnsignedInteger:3],
            [NSNumber numberWithUnsignedInteger:5],
            [NSNumber numberWithUnsignedInteger:8],
            nil];
}

NSArray *TGResourcePolicyMaxActiveAnimationChoices(void) {
    return TGResourcePolicyMaximumActiveAnimationChoices();
}

BOOL TGResourcePolicyStopAnimationsWhenInactive(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    return TGResourceBoolForKey(TGResourcePolicyStopAnimationsInactiveKey, YES);
}

BOOL TGResourcePolicyStopAnimationsWhenInactiveEnabled(void) {
    return TGResourcePolicyStopAnimationsWhenInactive();
}

void TGResourcePolicySetStopAnimationsWhenInactive(BOOL enabled) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGResourceSetBool(TGResourcePolicyStopAnimationsInactiveKey, enabled);
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

void TGResourcePolicySetStopAnimationsWhenInactiveEnabled(BOOL enabled) {
    TGResourcePolicySetStopAnimationsWhenInactive(enabled);
}

long long TGResourcePolicyMediaCacheLimitBytes(void) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    return TGResourceLongLongForKey(TGResourcePolicyMediaCacheLimitBytesKey, TGResourceMB(512));
}

void TGResourcePolicySetMediaCacheLimitBytes(long long bytes) {
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGResourceSetLongLong(TGResourcePolicyMediaCacheLimitBytesKey, bytes > 0 ? bytes : TGResourceMB(512));
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGResourcePolicyPostChange();
}

NSArray *TGResourcePolicyMediaCacheLimitChoices(void) {
    return [NSArray arrayWithObjects:
            [NSNumber numberWithLongLong:TGResourceMB(128)],
            [NSNumber numberWithLongLong:TGResourceMB(256)],
            [NSNumber numberWithLongLong:TGResourceMB(512)],
            [NSNumber numberWithLongLong:TGResourceMB(1024)],
            [NSNumber numberWithLongLong:TGResourceMB(2048)],
            nil];
}

long long TGResourcePolicyLargeAttachmentWarningBytes(void) {
    return TGResourceMB(50);
}
