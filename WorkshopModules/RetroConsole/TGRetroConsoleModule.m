#import "TGRetroConsoleModule.h"
#import "TGRetroConsoleViewController.h"

static NSString * const TGRetroConsoleModuleIdentifier =
    @"com.michirose.telegraphica.workshop.retroconsole";

@implementation TGRetroConsoleModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _viewController = [[TGRetroConsoleViewController alloc] initWithHostContext:context];
    }
    return self;
}

- (NSString *)moduleIdentifier { return TGRetroConsoleModuleIdentifier; }
- (NSString *)moduleDisplayName { return @"Retro Console"; }
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.2"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes {
    return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil];
}

- (BOOL)startWithError:(NSError **)error {
    (void)error;
    return YES;
}

- (void)stop {
    [_viewController stopRunning];
}

- (BOOL)saveStateWithError:(NSError **)error {
    NSData *state = [_viewController serializedState];
    if (!state) return YES;
    NSString *path = [[[_hostContext moduleDataDirectoryURL] path]
        stringByAppendingPathComponent:@"current-state.bin"];
    return [state writeToFile:path options:NSDataWritingAtomic error:error];
}

- (BOOL)clearUserDataWithError:(NSError **)error {
    NSString *path = [[[_hostContext moduleDataDirectoryURL] path]
        stringByAppendingPathComponent:@"current-state.bin"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    return [[NSFileManager defaultManager] removeItemAtPath:path error:error];
}

- (void)dealloc {
    [_hostContext release];
    [_viewController release];
    [super dealloc];
}

@end

