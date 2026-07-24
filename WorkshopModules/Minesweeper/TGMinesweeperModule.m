#import "TGMinesweeperModule.h"
#import "TGMinesweeperEngine.h"
#import "TGMinesweeperViewController.h"
#import "../Common/TGGameSaveStore.h"

@implementation TGMinesweeperModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _engine = [[TGMinesweeperEngine alloc] init];
        _saveStore = [[TGGameSaveStore alloc] initWithDataDirectoryURL:[context moduleDataDirectoryURL] fileName:@"state.plist"];
        _viewController = [[TGMinesweeperViewController alloc] initWithEngine:_engine hostContext:context];
    }
    return self;
}
- (NSString *)moduleIdentifier { return @"com.michirose.telegraphica.workshop.minesweeper"; }
- (NSString *)moduleDisplayName {
    return [_hostContext localizedStringForKey:@"minesweeper.title" fallback:@"Minesweeper"];
}
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.1"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes { return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil]; }
- (BOOL)startWithError:(NSError **)error {
    NSDictionary *saved = [_saveStore loadDictionaryQuarantiningCorruptFile:error];
    if (saved && ![_engine restoreFromDictionary:saved]) {
        [_saveStore quarantineCurrentSave];
        [_engine startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
        [_hostContext showNotificationWithTitle:[self moduleDisplayName]
                                        message:[_hostContext localizedStringForKey:@"game.save_recovered"
                                                                           fallback:@"The saved game was damaged. A new game was started and the old file was kept for diagnostics."]];
    }
    [_viewController refreshFromEngine];
    [_viewController startUpdating];
    return YES;
}
- (void)stop { [_viewController stopUpdating]; }
- (BOOL)saveStateWithError:(NSError **)error {
    return [_saveStore saveDictionary:[_engine dictionaryRepresentation] error:error];
}
- (BOOL)clearUserDataWithError:(NSError **)error {
    [_engine startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
    return [_saveStore clearData:error];
}
- (void)dealloc {
    [_viewController stopUpdating];
    [_hostContext release]; [_engine release]; [_viewController release]; [_saveStore release];
    [super dealloc];
}
@end
