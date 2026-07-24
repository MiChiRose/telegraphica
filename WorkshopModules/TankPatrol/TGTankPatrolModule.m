#import "TGTankPatrolModule.h"
#import "TGTankPatrolEngine.h"
#import "TGTankPatrolViewController.h"
#import "../Common/TGGameSaveStore.h"

static NSString * const TGTankPatrolModuleIdentifier =
    @"com.michirose.telegraphica.workshop.tankpatrol";

@implementation TGTankPatrolModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _engine = [[TGTankPatrolEngine alloc] init];
        _saveStore = [[TGGameSaveStore alloc]
                      initWithDataDirectoryURL:[context moduleDataDirectoryURL]
                      fileName:@"state.plist"];
        _viewController = [[TGTankPatrolViewController alloc]
                           initWithEngine:_engine
                           hostContext:context];
    }
    return self;
}

- (NSString *)moduleIdentifier { return TGTankPatrolModuleIdentifier; }
- (NSString *)moduleDisplayName {
    return [_hostContext localizedStringForKey:@"tankpatrol.title" fallback:@"Tank Patrol"];
}
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.1"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes {
    return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil];
}

- (BOOL)startWithError:(NSError **)error {
    NSDictionary *dictionary = [_saveStore loadDictionaryQuarantiningCorruptFile:error];
    if (dictionary && ![_engine restoreState:dictionary]) {
        [_saveStore quarantineCurrentSave];
        [_engine newGame];
    }
    [_viewController refreshFromEngine];
    return YES;
}

- (void)stop {
    [_viewController stopSimulation];
}

- (BOOL)saveStateWithError:(NSError **)error {
    return [_saveStore saveDictionary:[_engine saveState] error:error];
}

- (BOOL)clearUserDataWithError:(NSError **)error {
    [_engine newGame];
    return [_saveStore clearData:error];
}

- (void)dealloc {
    [_hostContext release];
    [_engine release];
    [_viewController release];
    [_saveStore release];
    [super dealloc];
}

@end
