#import "TGWorkshopCoordinator.h"
#import "TGWorkshopModuleLoader.h"
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
    TGWorkshopCatalogEntry *entry = nil;
    for (entry in [_catalog entries]) {
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
        }
        [blockSelf->_delegate workshopCoordinatorDidReload];
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
