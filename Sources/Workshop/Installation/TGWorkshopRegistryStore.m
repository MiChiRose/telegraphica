#import "TGWorkshopRegistryStore.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../Host/TGWorkshopPaths.h"

static NSError *TGWorkshopRegistryError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

@implementation TGWorkshopRegistryStore

@synthesize registryPath = _registryPath;

- (id)initWithRegistryPath:(NSString *)registryPath {
    self = [super init];
    if (self) {
        _registryPath = [registryPath copy];
        _records = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL)load:(NSError **)error {
    [_records removeAllObjects];
    if (![[NSFileManager defaultManager] fileExistsAtPath:_registryPath]) {
        return YES;
    }
    NSDictionary *root = [NSDictionary dictionaryWithContentsOfFile:_registryPath];
    NSDictionary *modules = [[root objectForKey:@"modules"] isKindOfClass:[NSDictionary class]] ? [root objectForKey:@"modules"] : nil;
    if (!modules) {
        if (error) *error = TGWorkshopRegistryError(400, @"Installed Workshop module registry is damaged.");
        return NO;
    }

    NSString *identifier = nil;
    for (identifier in modules) {
        NSDictionary *record = [[modules objectForKey:identifier] isKindOfClass:[NSDictionary class]] ? [modules objectForKey:identifier] : nil;
        if (record && TGWorkshopIdentifierIsSafePathComponent(identifier)) {
            [_records setObject:record forKey:identifier];
        }
    }
    return YES;
}

- (BOOL)save:(NSError **)error {
    NSString *directory = [_registryPath stringByDeletingLastPathComponent];
    if (!TGWorkshopEnsureDirectory(directory, error)) {
        return NO;
    }
    NSDictionary *root = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithUnsignedInteger:1], @"schema_version",
                          _records, @"modules",
                          nil];
    NSString *temporaryPath = [_registryPath stringByAppendingFormat:@".%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]];
    if (![root writeToFile:temporaryPath atomically:NO]) {
        if (error) *error = TGWorkshopRegistryError(401, @"Could not write Workshop module registry.");
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:_registryPath] && ![fileManager removeItemAtPath:_registryPath error:error]) {
        [fileManager removeItemAtPath:temporaryPath error:NULL];
        return NO;
    }
    if (![fileManager moveItemAtPath:temporaryPath toPath:_registryPath error:error]) {
        [fileManager removeItemAtPath:temporaryPath error:NULL];
        return NO;
    }
    return YES;
}

- (NSArray *)installedModuleIdentifiers {
    return [[_records allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSDictionary *)recordForModuleIdentifier:(NSString *)identifier {
    return [_records objectForKey:identifier];
}

- (void)setRecord:(NSDictionary *)record forModuleIdentifier:(NSString *)identifier {
    if (record && TGWorkshopIdentifierIsSafePathComponent(identifier)) {
        [_records setObject:record forKey:identifier];
    }
}

- (void)removeRecordForModuleIdentifier:(NSString *)identifier {
    [_records removeObjectForKey:identifier];
}

- (NSArray *)pendingRemovalModuleIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray array];
    NSString *identifier = nil;
    for (identifier in _records) {
        if ([[[_records objectForKey:identifier] objectForKey:@"pending_removal"] boolValue]) {
            [identifiers addObject:identifier];
        }
    }
    return [identifiers sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)dealloc {
    [_registryPath release];
    [_records release];
    [super dealloc];
}

@end
