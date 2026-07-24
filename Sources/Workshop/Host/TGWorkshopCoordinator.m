#import "TGWorkshopCoordinator.h"
#import "TGWorkshopModuleLoader.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../Catalog/TGWorkshopCatalog.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../Catalog/TGWorkshopCatalogParser.h"
#import "../Catalog/TGWorkshopCatalogClient.h"
#import "../Catalog/TGWorkshopConfiguration.h"
#import "../Installation/TGWorkshopInstaller.h"
#import "../Installation/TGWorkshopPackageDownloader.h"
#import "../Installation/TGWorkshopRegistryStore.h"
#import "../Host/TGWorkshopPaths.h"
#import "../../UI/TGStatusSupport.h"
#import "../../UI/TGUpdateSupport.h"

static NSString * const TGWorkshopModeAvailable = @"available";
static NSString * const TGWorkshopModeInstalled = @"installed";
static NSString * const TGWorkshopModeUpdates = @"updates";

static NSString *TGWorkshopInstalledCategory(NSString *identifier, NSDictionary *record) {
    NSString *category = [record objectForKey:@"category"];
    if (![category isKindOfClass:[NSString class]] || [category length] == 0) {
        NSDictionary *manifest = [record objectForKey:@"manifest"];
        category = [manifest isKindOfClass:[NSDictionary class]]
            ? [manifest objectForKey:@"category"]
            : nil;
    }
    if ([identifier hasSuffix:@".diagnosticcenter"] ||
        [identifier hasSuffix:@".mediaworkbench"]) {
        return TGWorkshopModuleCategoryUtilities;
    }
    return ([category isKindOfClass:[NSString class]] && [category length] > 0)
        ? category
        : TGWorkshopModuleCategoryGames;
}

static TGWorkshopCatalogEntry *TGWorkshopInstalledFallbackEntry(NSString *identifier,
                                                                 NSDictionary *record) {
    if ([identifier length] == 0 || ![record isKindOfClass:[NSDictionary class]]) return nil;
    NSString *version = [record objectForKey:@"active_version"];
    if ([version length] == 0) return nil;
    NSString *name = [identifier hasSuffix:@".pacman"] ? @"Pac-Man" : [identifier lastPathComponent];
    if ([identifier hasSuffix:@".diagnosticcenter"]) name = @"Diagnostic Center";
    if ([identifier hasSuffix:@".mediaworkbench"]) name = @"Media Center";
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                identifier, @"id",
                                name, @"name",
                                [NSDictionary dictionaryWithObjectsAndKeys:name, @"en", name, @"ru", nil], @"localized_name",
                                [NSDictionary dictionaryWithObjectsAndKeys:@"Installed Workshop module.", @"en",
                                 @"Установленный модуль Мастерской.", @"ru", nil], @"description",
                                version, @"version",
                                @1, @"api_version",
                                @"0.5.1", @"minimum_app_version",
                                @"10.9", @"minimum_os_version",
                                [NSArray arrayWithObject:@"x86_64"], @"architectures",
                                TGWorkshopInstalledCategory(identifier, record), @"category",
                                @1, @"archive_size",
                                @1, @"unpacked_size",
                                @1, @"entry_count",
                                @"0000000000000000000000000000000000000000000000000000000000000000", @"sha256",
                                [NSDictionary dictionaryWithObjectsAndKeys:@"local-installed", @"key_id",
                                 @"rsa-pkcs1-sha256", @"algorithm", @"local", @"value", nil], @"signature",
                                @"https://localhost/installed-workshop-module.zip", @"download_url",
                                @"https://localhost/installed-workshop-module.png", @"icon_url",
                                [NSDictionary dictionaryWithObjectsAndKeys:@"Installed locally.", @"en",
                                 @"Установлено локально.", @"ru", nil], @"changelog",
                                [NSArray arrayWithObjects:@"module-data", @"host-notifications", nil], @"permissions",
                                nil];
    return [[[TGWorkshopCatalogEntry alloc] initWithDictionary:dictionary error:NULL] autorelease];
}

@implementation TGWorkshopCoordinator

@synthesize delegate = _delegate;
@synthesize catalog = _catalog;
@synthesize activeModuleIdentifier = _activeModuleIdentifier;

- (id)initWithHostDelegate:(id<TGWorkshopHostContextDelegate>)hostDelegate {
    self = [super init];
    if (self) {
        _registryStore = [[TGWorkshopRegistryStore alloc] initWithRegistryPath:TGWorkshopRegistryPath()];
        _catalogParser = [[TGWorkshopCatalogParser alloc] initWithCertificatePathsByKeyIdentifier:TGWorkshopCatalogCertificatePaths()];
#if DEBUG
        [_catalogParser setAllowsUnsignedDevelopmentCatalogs:YES];
#endif
        _catalogClient = [[TGWorkshopCatalogClient alloc] initWithParser:_catalogParser];
        _packageDownloader = [[TGWorkshopPackageDownloader alloc] init];
        _installer = [[TGWorkshopInstaller alloc] initWithRegistryStore:_registryStore
                              packageCertificatePathsByKeyIdentifier:TGWorkshopPackageCertificatePaths()];
        _moduleLoader = [[TGWorkshopModuleLoader alloc] initWithRegistryStore:_registryStore hostDelegate:hostDelegate];
        _busyModuleIdentifiers = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)start {
    TGWorkshopEnsureBaseDirectories(NULL);
    NSError *error = nil;
    if (![_registryStore load:&error] ||
        ![_installer processPendingRemovals:&error] ||
        ![_moduleLoader recoverInterruptedModuleLaunches:&error]) {
        if ([_delegate respondsToSelector:@selector(workshopCoordinatorDidFailWithError:moduleIdentifier:)]) {
            [_delegate workshopCoordinatorDidFailWithError:error moduleIdentifier:nil];
        }
    }
    BOOL stale = NO;
    TGWorkshopCatalog *fallback = [_catalogClient cachedOrBundledCatalogAllowingExpired:YES stale:&stale error:NULL];
    if (fallback) {
        [_catalog release];
        _catalog = [fallback retain];
        [_delegate workshopCoordinatorDidReload];
    }
    [self refreshCatalog];
}

- (void)refreshCatalog {
    __block TGWorkshopCoordinator *blockSelf = self;
    [_catalogClient fetchCatalogWithCompletion:^(TGWorkshopCatalog *catalog, BOOL stale, NSError *error) {
        (void)stale;
        if (catalog) {
            [blockSelf->_catalog release];
            blockSelf->_catalog = [catalog retain];
            [blockSelf->_delegate workshopCoordinatorDidReload];
        } else if (error) {
            [blockSelf->_delegate workshopCoordinatorDidFailWithError:error moduleIdentifier:nil];
        }
    }];
}

- (NSDictionary *)installedRecordForModuleIdentifier:(NSString *)identifier {
    return [_registryStore recordForModuleIdentifier:identifier];
}

- (BOOL)isModuleBusy:(NSString *)identifier {
    return [_busyModuleIdentifiers containsObject:identifier];
}

- (NSArray *)entriesForMode:(NSString *)mode {
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *catalogIdentifiers = [NSMutableSet set];
    TGWorkshopCatalogEntry *entry = nil;
    for (entry in [_catalog entries]) {
        [catalogIdentifiers addObject:[entry moduleIdentifier]];
        NSDictionary *record = [_registryStore recordForModuleIdentifier:[entry moduleIdentifier]];
        NSString *installedVersion = [record objectForKey:@"active_version"];
        BOOL installed = ([installedVersion length] > 0 && ![[record objectForKey:@"pending_removal"] boolValue]);
        BOOL update = installed && TGVersionStringIsNewer([entry version], installedVersion);
        if (([mode isEqualToString:TGWorkshopModeAvailable] && !installed) ||
            ([mode isEqualToString:TGWorkshopModeInstalled] && installed) ||
            ([mode isEqualToString:TGWorkshopModeUpdates] && update)) {
            [result addObject:entry];
        }
    }
    if ([mode isEqualToString:TGWorkshopModeInstalled]) {
        NSString *identifier = nil;
        for (identifier in [_registryStore installedModuleIdentifiers]) {
            if ([catalogIdentifiers containsObject:identifier]) continue;
            NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
            BOOL installed = [[[record objectForKey:@"active_version"] description] length] > 0 &&
                             ![[record objectForKey:@"pending_removal"] boolValue];
            if (!installed) continue;
            TGWorkshopCatalogEntry *fallbackEntry = TGWorkshopInstalledFallbackEntry(identifier, record);
            if (fallbackEntry) [result addObject:fallbackEntry];
        }
    }
    return result;
}

- (void)installOrUpdateEntry:(TGWorkshopCatalogEntry *)entry {
    NSString *identifier = [entry moduleIdentifier];
    if ([self isModuleBusy:identifier]) return;
    [_busyModuleIdentifiers addObject:identifier];
    [_delegate workshopCoordinatorDidReload];

    __block TGWorkshopCoordinator *blockSelf = self;
    [_packageDownloader downloadCatalogEntry:entry
                                    progress:^(unsigned long long receivedBytes, unsigned long long expectedBytes) {
        double progress = (expectedBytes > 0) ? ((double)receivedBytes / (double)expectedBytes) : 0.0;
        [blockSelf->_delegate workshopCoordinatorDidUpdateProgress:progress moduleIdentifier:identifier];
    }
                                  completion:^(NSString *packagePath, NSError *downloadError) {
        NSError *installError = downloadError;
        BOOL installed = NO;
        if (packagePath) {
            installed = [blockSelf->_installer installPackageAtPath:packagePath
                                                        catalogEntry:entry
                                                  applicationVersion:TGCurrentApplicationVersionString()
                                                               error:&installError];
            [[NSFileManager defaultManager] removeItemAtPath:packagePath error:NULL];
        }
        [blockSelf->_busyModuleIdentifiers removeObject:identifier];
        if (!installed) {
            [blockSelf->_delegate workshopCoordinatorDidFailWithError:installError moduleIdentifier:identifier];
            [blockSelf->_delegate workshopCoordinatorDidReload];
        } else {
            [blockSelf->_delegate workshopCoordinatorDidUpdateProgress:1.0 moduleIdentifier:identifier];
            [blockSelf->_delegate workshopCoordinatorDidCompleteInstallationForModuleIdentifier:identifier];
        }
    }];
}

- (void)openEntry:(TGWorkshopCatalogEntry *)entry {
    NSError *error = nil;
    id module = [_moduleLoader loadModuleWithIdentifier:[entry moduleIdentifier] error:&error];
    NSViewController *viewController = module ? [_moduleLoader viewControllerForLoadedModuleIdentifier:[entry moduleIdentifier]] : nil;
    if (!viewController) {
        [_delegate workshopCoordinatorDidFailWithError:error moduleIdentifier:[entry moduleIdentifier]];
        return;
    }
    [_activeModuleIdentifier release];
    _activeModuleIdentifier = [[entry moduleIdentifier] copy];
    [_delegate workshopCoordinatorDidOpenModuleViewController:viewController moduleIdentifier:_activeModuleIdentifier];
}

- (void)closeActiveModule {
    if ([_activeModuleIdentifier length] == 0) return;
    [_moduleLoader saveAndStopModuleWithIdentifier:_activeModuleIdentifier error:NULL];
    [_activeModuleIdentifier release];
    _activeModuleIdentifier = nil;
    [_delegate workshopCoordinatorDidReload];
}

- (void)removeEntry:(TGWorkshopCatalogEntry *)entry removeData:(BOOL)removeData {
    NSString *identifier = [entry moduleIdentifier];
    if ([identifier isEqualToString:_activeModuleIdentifier]) {
        [self closeActiveModule];
    }
    NSError *error = nil;
    if (![_installer markModuleForRemoval:identifier removeData:removeData error:&error] ||
        ![_installer processPendingRemovals:&error]) {
        [_delegate workshopCoordinatorDidFailWithError:error moduleIdentifier:identifier];
    }
    [_delegate workshopCoordinatorDidReload];
}

- (void)dealloc {
    [_catalogClient cancel];
    [_packageDownloader cancel];
    [_moduleLoader saveAndStopAllModules];
    [_registryStore release];
    [_catalogParser release];
    [_catalogClient release];
    [_packageDownloader release];
    [_installer release];
    [_moduleLoader release];
    [_catalog release];
    [_busyModuleIdentifiers release];
    [_activeModuleIdentifier release];
    [super dealloc];
}

@end
