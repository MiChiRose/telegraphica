#import "TGLocalDataReset.h"

#import "TGKeychainHelper.h"
#import "TGLogger.h"
#import "../Core/TGTDLibClient.h"
#import "../Media/TGMediaImageLoader.h"

NSString * const TGLocalDataResetRemovedCountKey = @"removedCount";
NSString * const TGLocalDataResetErrorMessagesKey = @"errorMessages";
NSString * const TGLocalDataResetOfflineNoteKey = @"offlineNote";

static NSString * const TGLocalDataResetTDLibKeychainAccount = @"tdlib_database_encryption_key";

static NSString *TGLocalDataResetBaseDirectory(NSSearchPathDirectory directory, NSString *fallbackPath) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:fallbackPath];
    return [basePath stringByAppendingPathComponent:@"Telegraphica"];
}

static void TGLocalDataResetAppendError(NSMutableArray *errors, NSString *label, NSError *error) {
    NSString *message = [error localizedDescription];
    if ([message length] == 0) {
        message = @"unknown error";
    }
    [errors addObject:[NSString stringWithFormat:@"%@: %@", label, message]];
}

static NSString *TGLocalDataResetSafeLabelForPath(NSString *path) {
    NSString *home = NSHomeDirectory();
    if ([home length] > 0 && [path hasPrefix:home]) {
        return [path stringByReplacingCharactersInRange:NSMakeRange(0, [home length]) withString:@"~"];
    }
    return path;
}

static BOOL TGLocalDataResetRemovePath(NSString *path, NSMutableArray *errors, NSUInteger *removedCount) {
    if ([path length] == 0) {
        return YES;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return YES;
    }

    NSError *removeError = nil;
    if (![fileManager removeItemAtPath:path error:&removeError]) {
        TGLocalDataResetAppendError(errors, [NSString stringWithFormat:@"delete failed %@", TGLocalDataResetSafeLabelForPath(path)], removeError);
        return NO;
    }

    if ([fileManager fileExistsAtPath:path]) {
        [errors addObject:[NSString stringWithFormat:@"delete verification failed %@", TGLocalDataResetSafeLabelForPath(path)]];
        return NO;
    }

    if (removedCount) {
        (*removedCount)++;
    }
    return YES;
}

static void TGLocalDataResetClearDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dictionary = [defaults dictionaryRepresentation];
    NSArray *keys = [dictionary allKeys];
    NSUInteger index = 0;
    for (index = 0; index < [keys count]; index++) {
        NSString *key = [keys objectAtIndex:index];
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        if ([key hasPrefix:@"TelegraphicaDraft."] ||
            [key hasPrefix:@"TelegraphicaSelected"] ||
            [key hasPrefix:@"TelegraphicaChat"] ||
            [key hasPrefix:@"TelegraphicaUpdate"] ||
            [key isEqualToString:@"TelegraphicaAvailableUpdateVersion"] ||
            [key isEqualToString:@"TelegraphicaAvailableUpdateURL"] ||
            [key isEqualToString:@"TelegraphicaAvailableUpdateSHA256"]) {
            [defaults removeObjectForKey:key];
        }
    }
    [defaults synchronize];
}

@implementation TGLocalDataReset

+ (NSDictionary *)resetLocalDataWithClient:(TGTDLibClient *)client
                                   timeout:(NSTimeInterval)timeout {
    NSMutableArray *errors = [NSMutableArray array];
    NSUInteger removedCount = 0;

    if (client) {
        [client shutdownWithTimeout:timeout];
    }

    NSString *supportPath = TGLocalDataResetBaseDirectory(NSApplicationSupportDirectory, @"Library/Application Support");
    NSString *cachePath = TGLocalDataResetBaseDirectory(NSCachesDirectory, @"Library/Caches");
    NSString *logsPath = [supportPath stringByAppendingPathComponent:@"Logs"];

    NSArray *ownedPaths = [NSArray arrayWithObjects:
                           [supportPath stringByAppendingPathComponent:@"tdlib"],
                           [supportPath stringByAppendingPathComponent:@"tdlib-config.plist"],
                           [supportPath stringByAppendingPathComponent:@"remote-tdlib-config-url.txt"],
                           logsPath,
                           cachePath,
                           nil];

    NSUInteger pathIndex = 0;
    for (pathIndex = 0; pathIndex < [ownedPaths count]; pathIndex++) {
        TGLocalDataResetRemovePath([ownedPaths objectAtIndex:pathIndex], errors, &removedCount);
    }

    TGMediaImageLoaderClearCache();
    TGLocalDataResetClearDefaults();
    [[TGLogger sharedLogger] clearLog];
    [[TGLogger sharedLogger] clearDiagnosticFile];

    TGKeychainHelper *keychain = [TGKeychainHelper sharedHelper];
    if (![keychain deleteForAccount:TGLocalDataResetTDLibKeychainAccount]) {
        [errors addObject:[NSString stringWithFormat:@"Could not delete the local TDLib database encryption key from Keychain (OSStatus %ld).",
                           (long)[keychain lastStatus]]];
    }

    NSString *offlineNote = @"Local Telegraphica data was removed from this Mac. Telegram cloud data remains online; if the app was offline, terminate server sessions from another Telegram client if needed.";
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:removedCount], TGLocalDataResetRemovedCountKey,
            [NSArray arrayWithArray:errors], TGLocalDataResetErrorMessagesKey,
            offlineNote, TGLocalDataResetOfflineNoteKey,
            nil];
}

@end
