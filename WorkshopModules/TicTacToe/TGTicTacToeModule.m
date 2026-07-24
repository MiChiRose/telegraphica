#import "TGTicTacToeModule.h"
#import "TGTicTacToeEngine.h"
#import "TGTicTacToeViewController.h"
#import "../Common/TGGameSaveStore.h"

static NSString * const TGTicTacToeModuleIdentifier = @"com.michirose.telegraphica.workshop.tictactoe";

@implementation TGTicTacToeModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _engine = [[TGTicTacToeEngine alloc] init];
        _saveStore = [[TGGameSaveStore alloc] initWithDataDirectoryURL:[context moduleDataDirectoryURL]
                                                              fileName:@"state.plist"];
        _viewController = [[TGTicTacToeViewController alloc] initWithEngine:_engine hostContext:context];
    }
    return self;
}

- (NSString *)moduleIdentifier { return TGTicTacToeModuleIdentifier; }
- (NSString *)moduleDisplayName {
    return [_hostContext localizedStringForKey:@"tictactoe.title" fallback:@"Tic-Tac-Toe"];
}
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.1"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes { return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil]; }

- (BOOL)startWithError:(NSError **)error {
    NSDictionary *dictionary = [_saveStore loadDictionaryQuarantiningCorruptFile:error];
    if (dictionary && ![_engine restoreFromDictionary:dictionary]) {
        [_saveStore quarantineCurrentSave];
        [_engine newRound];
        [_hostContext showNotificationWithTitle:[self moduleDisplayName]
                                        message:[_hostContext localizedStringForKey:@"game.save_recovered"
                                                                           fallback:@"The saved game was damaged. A new game was started and the old file was kept for diagnostics."]];
    }
    [_viewController refreshFromEngine];
    return YES;
}

- (void)stop {
}

- (BOOL)saveStateWithError:(NSError **)error {
    return [_saveStore saveDictionary:[_engine dictionaryRepresentation] error:error];
}

- (BOOL)clearUserDataWithError:(NSError **)error {
    [_engine newRound];
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
