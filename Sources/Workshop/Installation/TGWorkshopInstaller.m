#import "TGWorkshopInstaller.h"
#import "TGWorkshopCompatibility.h"
#import "TGWorkshopRegistryStore.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../Security/TGWorkshopArchiveExtractor.h"
#import "../Security/TGWorkshopBundleValidator.h"
#import "../Security/TGWorkshopIntegrity.h"
#import "../Host/TGWorkshopPaths.h"
#import "../API/TGWorkshopModuleDefinitions.h"

static NSError *TGWorkshopInstallerError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

@implementation TGWorkshopInstaller

- (id)initWithRegistryStore:(TGWorkshopRegistryStore *)registryStore
 packageCertificatePathsByKeyIdentifier:(NSDictionary *)certificatePaths {
    self = [super init];
    if (self) {
        _registryStore = [registryStore retain];
        _archiveExtractor = [[TGWorkshopArchiveExtractor alloc] init];
        _bundleValidator = [[TGWorkshopBundleValidator alloc] init];
        _packageCertificatePathsByKeyIdentifier = [certificatePaths copy];
    }
    return self;
}

- (BOOL)verifyPackageAtPath:(NSString *)packagePath
               catalogEntry:(TGWorkshopCatalogEntry *)entry
                      error:(NSError **)error {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:packagePath error:error];
    if (!attributes || [[attributes objectForKey:NSFileSize] unsignedLongLongValue] != [entry archiveSize]) {
        if (error && !*error) *error = TGWorkshopInstallerError(360, @"Workshop package size does not match the catalog.");
        return NO;
    }
    if (![TGWorkshopIntegrity fileAtPath:packagePath matchesSHA256:[entry SHA256] error:error]) {
        return NO;
    }

    NSDictionary *signatureInfo = [entry signature];
    NSString *keyIdentifier = [[signatureInfo objectForKey:@"key_id"] isKindOfClass:[NSString class]] ? [signatureInfo objectForKey:@"key_id"] : nil;
    NSString *algorithm = [[signatureInfo objectForKey:@"algorithm"] isKindOfClass:[NSString class]] ? [signatureInfo objectForKey:@"algorithm"] : nil;
    NSString *signatureBase64 = [[signatureInfo objectForKey:@"value"] isKindOfClass:[NSString class]] ? [signatureInfo objectForKey:@"value"] : nil;
    NSString *certificatePath = [_packageCertificatePathsByKeyIdentifier objectForKey:keyIdentifier];
    NSData *signature = [[[NSData alloc] initWithBase64EncodedString:signatureBase64 options:0] autorelease];
    NSString *signedDescription = [NSString stringWithFormat:@"%@\n%@\n%@",
                                   [entry moduleIdentifier], [entry version], [entry SHA256]];
    NSData *signedData = [signedDescription dataUsingEncoding:NSUTF8StringEncoding];
    if (![algorithm isEqualToString:@"rsa-pkcs1-sha256"] || [certificatePath length] == 0 || [signature length] == 0 ||
        ![TGWorkshopIntegrity verifySignature:signature
                                     overData:signedData
                                       domain:TGWorkshopPackageSignatureDomain
                        certificateDERAtPath:certificatePath
                                        error:error]) {
        if (error && !*error) *error = TGWorkshopInstallerError(361, @"Workshop package signature is invalid.");
        return NO;
    }
    return YES;
}

- (BOOL)installPackageAtPath:(NSString *)packagePath
               catalogEntry:(TGWorkshopCatalogEntry *)entry
         applicationVersion:(NSString *)applicationVersion
                      error:(NSError **)error {
    if (![TGWorkshopCompatibility catalogEntryIsCompatible:entry
                                        applicationVersion:applicationVersion
                                             systemVersion:[TGWorkshopCompatibility currentSystemVersion]
                                               architecture:[TGWorkshopCompatibility currentArchitecture]
                                                      error:error] ||
        ![self verifyPackageAtPath:packagePath catalogEntry:entry error:error] ||
        !TGWorkshopEnsureBaseDirectories(error)) {
        return NO;
    }

    NSString *transactionIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *stagingPath = [TGWorkshopStagingDirectory() stringByAppendingPathComponent:transactionIdentifier];
    if (!TGWorkshopEnsureDirectory(stagingPath, error)) {
        return NO;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = [_archiveExtractor extractArchiveAtPath:packagePath toEmptyDirectoryPath:stagingPath error:error];
    NSString *bundleName = [[entry moduleIdentifier] stringByAppendingPathExtension:@"bundle"];
    NSString *stagedBundlePath = [stagingPath stringByAppendingPathComponent:bundleName];
    NSDictionary *manifest = nil;
    if (success) {
        NSArray *topLevelItems = [fileManager contentsOfDirectoryAtPath:stagingPath error:error];
        success = ([topLevelItems count] == 1 &&
                   [[topLevelItems objectAtIndex:0] isEqualToString:bundleName] &&
                   [_bundleValidator validateBundleAtPath:stagedBundlePath catalogEntry:entry manifest:&manifest error:error]);
        if (!success && error && !*error) {
            *error = TGWorkshopInstallerError(362, @"Workshop package must contain exactly one matching module bundle.");
        }
    }

    NSString *moduleRoot = [TGWorkshopModulesDirectory() stringByAppendingPathComponent:[entry moduleIdentifier]];
    NSString *versionsRoot = [moduleRoot stringByAppendingPathComponent:@"Versions"];
    NSString *versionRoot = [versionsRoot stringByAppendingPathComponent:[entry version]];
    NSString *installedBundlePath = [versionRoot stringByAppendingPathComponent:bundleName];
    if (success && [fileManager fileExistsAtPath:versionRoot]) {
        success = NO;
        if (error) *error = TGWorkshopInstallerError(363, @"This Workshop module version is already installed.");
    }
    if (success) {
        success = TGWorkshopEnsureDirectory(versionsRoot, error) &&
                  TGWorkshopEnsureDirectory(versionRoot, error) &&
                  [fileManager moveItemAtPath:stagedBundlePath toPath:installedBundlePath error:error];
    }

    NSDictionary *oldRecord = [[_registryStore recordForModuleIdentifier:[entry moduleIdentifier]] retain];
    if (success) {
        NSString *previousVersion = [[oldRecord objectForKey:@"active_version"] isKindOfClass:[NSString class]] ?
                                    [oldRecord objectForKey:@"active_version"] : @"";
        NSDictionary *newRecord = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [entry version], @"active_version",
                                   previousVersion, @"previous_version",
                                   [NSNumber numberWithBool:NO], @"disabled",
                                   [NSNumber numberWithBool:NO], @"pending_removal",
                                   [NSNumber numberWithBool:NO], @"remove_data",
                                   [NSDate date], @"installed_at",
                                   manifest ? manifest : [NSDictionary dictionary], @"manifest",
                                   nil];
        [_registryStore setRecord:newRecord forModuleIdentifier:[entry moduleIdentifier]];
        success = [_registryStore save:error];
        if (!success) {
            if (oldRecord) {
                [_registryStore setRecord:oldRecord forModuleIdentifier:[entry moduleIdentifier]];
            } else {
                [_registryStore removeRecordForModuleIdentifier:[entry moduleIdentifier]];
            }
            [fileManager removeItemAtPath:versionRoot error:NULL];
        }
    }
    [oldRecord release];
    [fileManager removeItemAtPath:stagingPath error:NULL];
    return success;
}

- (BOOL)markModuleForRemoval:(NSString *)identifier
                  removeData:(BOOL)removeData
                       error:(NSError **)error {
    NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
    if (!record) {
        if (error) *error = TGWorkshopInstallerError(364, @"Workshop module is not installed.");
        return NO;
    }
    NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:record];
    [updated setObject:[NSNumber numberWithBool:YES] forKey:@"disabled"];
    [updated setObject:[NSNumber numberWithBool:YES] forKey:@"pending_removal"];
    [updated setObject:[NSNumber numberWithBool:removeData] forKey:@"remove_data"];
    [_registryStore setRecord:updated forModuleIdentifier:identifier];
    return [_registryStore save:error];
}

- (BOOL)processPendingRemovals:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *identifiers = [_registryStore pendingRemovalModuleIdentifiers];
    NSString *identifier = nil;
    for (identifier in identifiers) {
        NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
        NSString *modulePath = [TGWorkshopModulesDirectory() stringByAppendingPathComponent:identifier];
        if ([fileManager fileExistsAtPath:modulePath] && ![fileManager removeItemAtPath:modulePath error:error]) {
            return NO;
        }
        if ([[record objectForKey:@"remove_data"] boolValue]) {
            NSString *dataPath = TGWorkshopDataDirectoryForModuleIdentifier(identifier);
            if ([fileManager fileExistsAtPath:dataPath] && ![fileManager removeItemAtPath:dataPath error:error]) {
                return NO;
            }
        }
        [_registryStore removeRecordForModuleIdentifier:identifier];
    }
    return [_registryStore save:error];
}

- (void)dealloc {
    [_archiveExtractor release];
    [_bundleValidator release];
    [_registryStore release];
    [_packageCertificatePathsByKeyIdentifier release];
    [super dealloc];
}

@end
