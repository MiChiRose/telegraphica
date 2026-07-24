#import "TGPacManModule.h"
#import "TGPacManEngine.h"
#import "TGPacManViewController.h"
#import "../Common/TGGameSaveStore.h"

static NSString * const TGPacManModuleIdentifier = @"com.michirose.telegraphica.workshop.pacman";

@implementation TGPacManModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _engine = [[TGPacManEngine alloc] init];
        _saveStore = [[TGGameSaveStore alloc] initWithDataDirectoryURL:[context moduleDataDirectoryURL]
                                                              fileName:@"state.plist"];
        _viewController = [[TGPacManViewController alloc] initWithEngine:_engine hostContext:context];
    }
    return self;
}

- (NSString *)moduleIdentifier { return TGPacManModuleIdentifier; }
- (NSString *)moduleDisplayName { return @"Pac-Man"; }
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.1"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes { return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil]; }

- (BOOL)startWithError:(NSError **)error {
    NSDictionary *dictionary = [_saveStore loadDictionaryQuarantiningCorruptFile:error];
    if (dictionary && ![_engine restoreFromDictionary:dictionary]) {
        [_saveStore quarantineCurrentSave];
        [_engine newGame];
    }
    [_viewController refreshFromEngine];
    [_viewController startAnimation];
    return YES;
}

- (void)stop {
    [_viewController stopAnimation];
}

- (BOOL)saveStateWithError:(NSError **)error {
    return [_saveStore saveDictionary:[_engine dictionaryRepresentation] error:error];
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
