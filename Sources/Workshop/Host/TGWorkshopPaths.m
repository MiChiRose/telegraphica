#import "TGWorkshopPaths.h"
#import "../API/TGWorkshopModuleDefinitions.h"

static NSString *TGWorkshopBaseDirectory(NSSearchPathDirectory directory, NSString *fallback) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:fallback];
    return [[basePath stringByAppendingPathComponent:@"Telegraphica"] stringByAppendingPathComponent:@"Workshop"];
}

NSString *TGWorkshopApplicationSupportDirectory(void) {
    return TGWorkshopBaseDirectory(NSApplicationSupportDirectory, @"Library/Application Support");
}

NSString *TGWorkshopModulesDirectory(void) {
    return [TGWorkshopApplicationSupportDirectory() stringByAppendingPathComponent:@"Modules"];
}

NSString *TGWorkshopModuleDataDirectory(void) {
    return [TGWorkshopApplicationSupportDirectory() stringByAppendingPathComponent:@"Module Data"];
}

NSString *TGWorkshopDataDirectoryForModuleIdentifier(NSString *identifier) {
    if (!TGWorkshopIdentifierIsSafePathComponent(identifier)) {
        return nil;
    }
    return [TGWorkshopModuleDataDirectory() stringByAppendingPathComponent:identifier];
}

NSString *TGWorkshopCacheDirectory(void) {
    return TGWorkshopBaseDirectory(NSCachesDirectory, @"Library/Caches");
}

NSString *TGWorkshopCatalogCacheDirectory(void) {
    return [TGWorkshopCacheDirectory() stringByAppendingPathComponent:@"Catalog"];
}

NSString *TGWorkshopDownloadsDirectory(void) {
    return [TGWorkshopCacheDirectory() stringByAppendingPathComponent:@"Downloads"];
}

NSString *TGWorkshopStagingDirectory(void) {
    return [TGWorkshopApplicationSupportDirectory() stringByAppendingPathComponent:@".Staging"];
}

NSString *TGWorkshopTransactionsDirectory(void) {
    return [TGWorkshopApplicationSupportDirectory() stringByAppendingPathComponent:@".Transactions"];
}

NSString *TGWorkshopRegistryPath(void) {
    return [TGWorkshopApplicationSupportDirectory() stringByAppendingPathComponent:TGWorkshopInstalledRegistryFileName];
}

BOOL TGWorkshopEnsureDirectory(NSString *path, NSError **error) {
    if ([path length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:TGWorkshopErrorDomain
                                         code:100
                                     userInfo:[NSDictionary dictionaryWithObject:@"Workshop directory path is empty."
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }

    BOOL isDirectory = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (isDirectory) {
            return YES;
        }
        if (error) {
            *error = [NSError errorWithDomain:TGWorkshopErrorDomain
                                         code:101
                                     userInfo:[NSDictionary dictionaryWithObject:@"A file blocks a required Workshop directory."
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    return [fileManager createDirectoryAtPath:path
                   withIntermediateDirectories:YES
                                    attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0700]
                                                                           forKey:NSFilePosixPermissions]
                                         error:error];
}

BOOL TGWorkshopEnsureBaseDirectories(NSError **error) {
    NSArray *paths = [NSArray arrayWithObjects:
                      TGWorkshopApplicationSupportDirectory(),
                      TGWorkshopModulesDirectory(),
                      TGWorkshopModuleDataDirectory(),
                      TGWorkshopStagingDirectory(),
                      TGWorkshopTransactionsDirectory(),
                      TGWorkshopCacheDirectory(),
                      TGWorkshopCatalogCacheDirectory(),
                      TGWorkshopDownloadsDirectory(),
                      nil];
    NSUInteger index = 0;
    for (index = 0; index < [paths count]; index++) {
        if (!TGWorkshopEnsureDirectory([paths objectAtIndex:index], error)) {
            return NO;
        }
    }
    return YES;
}

BOOL TGWorkshopIdentifierIsSafePathComponent(NSString *identifier) {
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0 || [identifier length] > 160) {
        return NO;
    }
    if ([identifier isEqualToString:@"."] || [identifier isEqualToString:@".."] ||
        [identifier rangeOfString:@"/"].location != NSNotFound ||
        [identifier rangeOfString:@"\\"].location != NSNotFound ||
        [identifier rangeOfString:@":"].location != NSNotFound) {
        return NO;
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_"];
    return [identifier rangeOfCharacterFromSet:[allowed invertedSet]].location == NSNotFound;
}
