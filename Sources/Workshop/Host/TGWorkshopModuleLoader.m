#import "TGWorkshopModuleLoader.h"
#import "../API/TGWorkshopModule.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../Installation/TGWorkshopRegistryStore.h"
#import "TGWorkshopHostContextImpl.h"
#import "TGWorkshopPaths.h"

static NSError *TGWorkshopLoaderError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

@implementation TGWorkshopModuleLoader

- (void)quarantineFailedVersion:(NSString *)version identifier:(NSString *)identifier {
    NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
    if (!record) return;
    NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:record];
    NSString *previousVersion = [record objectForKey:@"previous_version"];
    if ([previousVersion length] > 0 && ![previousVersion isEqualToString:version]) {
        [updated setObject:previousVersion forKey:@"active_version"];
        [updated setObject:[NSNumber numberWithBool:NO] forKey:@"disabled"];
    } else {
        [updated setObject:[NSNumber numberWithBool:YES] forKey:@"disabled"];
    }
    if ([version length] > 0) {
        [updated setObject:version forKey:@"failed_version"];
    }
    [updated removeObjectForKey:@"launching_version"];
    [_registryStore setRecord:updated forModuleIdentifier:identifier];
    [_registryStore save:NULL];
}

- (id)initWithRegistryStore:(TGWorkshopRegistryStore *)registryStore
                 hostDelegate:(id<TGWorkshopHostContextDelegate>)hostDelegate {
    self = [super init];
    if (self) {
        _registryStore = [registryStore retain];
        _hostDelegate = hostDelegate;
        _loadedModules = [[NSMutableDictionary alloc] init];
        _hostContexts = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString *)bundlePathForIdentifier:(NSString *)identifier record:(NSDictionary *)record {
    NSString *version = [[record objectForKey:@"active_version"] isKindOfClass:[NSString class]] ?
                        [record objectForKey:@"active_version"] : nil;
    if ([version length] == 0) {
        return nil;
    }
    NSString *bundleName = [identifier stringByAppendingPathExtension:@"bundle"];
    return [[[[TGWorkshopModulesDirectory() stringByAppendingPathComponent:identifier]
              stringByAppendingPathComponent:@"Versions"]
             stringByAppendingPathComponent:version]
            stringByAppendingPathComponent:bundleName];
}

- (BOOL)setLaunchingVersion:(NSString *)version
                identifier:(NSString *)identifier
                     error:(NSError **)error {
    NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
    if (!record) return NO;
    NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:record];
    if ([version length] > 0) {
        [updated setObject:version forKey:@"launching_version"];
    } else {
        [updated removeObjectForKey:@"launching_version"];
    }
    [_registryStore setRecord:updated forModuleIdentifier:identifier];
    return [_registryStore save:error];
}

- (id)loadModuleWithIdentifier:(NSString *)identifier error:(NSError **)error {
    id<TGWorkshopModule> alreadyLoaded = [_loadedModules objectForKey:identifier];
    if (alreadyLoaded) {
        return alreadyLoaded;
    }
    NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
    if (!record || [[record objectForKey:@"disabled"] boolValue]) {
        if (error) *error = TGWorkshopLoaderError(380, @"Workshop module is not available.");
        return nil;
    }
    NSString *version = [record objectForKey:@"active_version"];
    NSString *bundlePath = [self bundlePathForIdentifier:identifier record:record];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    if (!bundle) {
        [self quarantineFailedVersion:version identifier:identifier];
        if (error) *error = TGWorkshopLoaderError(381, @"Workshop module bundle could not be opened.");
        return nil;
    }
    if (![self setLaunchingVersion:version identifier:identifier error:error]) {
        if (error && !*error) *error = TGWorkshopLoaderError(381, @"Workshop module launch state could not be saved.");
        return nil;
    }

    NSError *loadError = nil;
    if (![bundle loadAndReturnError:&loadError]) {
        [self quarantineFailedVersion:version identifier:identifier];
        if (error) *error = loadError ? loadError : TGWorkshopLoaderError(382, @"Workshop module executable could not be loaded.");
        return nil;
    }

    id<TGWorkshopModule> module = nil;
    @try {
        Class principalClass = [bundle principalClass];
        if (!principalClass || ![principalClass conformsToProtocol:@protocol(TGWorkshopModule)]) {
            if (error) *error = TGWorkshopLoaderError(383, @"Workshop module principal class does not implement the host API.");
        } else {
            TGWorkshopHostContextImpl *context = [[[TGWorkshopHostContextImpl alloc] initWithModuleIdentifier:identifier
                                                                                                    delegate:_hostDelegate] autorelease];
            module = [[[principalClass alloc] initWithHostContext:context] autorelease];
            if (![[module moduleIdentifier] isEqualToString:identifier] ||
                ![[module moduleVersion] isEqualToString:version] ||
                [module moduleAPIVersion] != TGWorkshopModuleAPIVersion ||
                ![module startWithError:error] ||
                ![module mainViewController]) {
                module = nil;
            } else {
                [_hostContexts setObject:context forKey:identifier];
                [_loadedModules setObject:module forKey:identifier];
            }
        }
    }
    @catch (NSException *exception) {
        module = nil;
        if (error) {
            *error = TGWorkshopLoaderError(384,
                                           [NSString stringWithFormat:@"Workshop module failed to start: %@.",
                                            [exception reason] ? [exception reason] : [exception name]]);
        }
    }
    if (module) {
        [self setLaunchingVersion:nil identifier:identifier error:NULL];
    } else {
        [self quarantineFailedVersion:version identifier:identifier];
    }
    return module;
}

- (NSViewController *)viewControllerForLoadedModuleIdentifier:(NSString *)identifier {
    id<TGWorkshopModule> module = [_loadedModules objectForKey:identifier];
    return [module mainViewController];
}

- (BOOL)saveAndStopModuleWithIdentifier:(NSString *)identifier error:(NSError **)error {
    id<TGWorkshopModule> module = [_loadedModules objectForKey:identifier];
    if (!module) return YES;
    BOOL saved = YES;
    @try {
        saved = [module saveStateWithError:error];
        [module stop];
    }
    @catch (NSException *exception) {
        saved = NO;
        if (error) *error = TGWorkshopLoaderError(385, @"Workshop module failed while closing.");
    }
    [_loadedModules removeObjectForKey:identifier];
    [_hostContexts removeObjectForKey:identifier];
    return saved;
}

- (void)saveAndStopAllModules {
    NSArray *identifiers = [[_loadedModules allKeys] copy];
    NSString *identifier = nil;
    for (identifier in identifiers) {
        [self saveAndStopModuleWithIdentifier:identifier error:NULL];
    }
    [identifiers release];
}

- (BOOL)recoverInterruptedModuleLaunches:(NSError **)error {
    NSArray *identifiers = [_registryStore installedModuleIdentifiers];
    NSString *identifier = nil;
    BOOL changed = NO;
    for (identifier in identifiers) {
        NSDictionary *record = [_registryStore recordForModuleIdentifier:identifier];
        NSString *launchingVersion = [record objectForKey:@"launching_version"];
        if ([launchingVersion length] == 0) continue;
        NSMutableDictionary *updated = [NSMutableDictionary dictionaryWithDictionary:record];
        NSString *previousVersion = [record objectForKey:@"previous_version"];
        if ([previousVersion length] > 0) {
            [updated setObject:previousVersion forKey:@"active_version"];
        } else {
            [updated setObject:[NSNumber numberWithBool:YES] forKey:@"disabled"];
        }
        [updated setObject:launchingVersion forKey:@"failed_version"];
        [updated removeObjectForKey:@"launching_version"];
        [_registryStore setRecord:updated forModuleIdentifier:identifier];
        changed = YES;
    }
    return !changed || [_registryStore save:error];
}

- (void)dealloc {
    [self saveAndStopAllModules];
    [_registryStore release];
    [_loadedModules release];
    [_hostContexts release];
    [super dealloc];
}

@end
