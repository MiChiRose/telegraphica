#import "TGDiagnosticCenterModule.h"
#import "TGDiagnosticCenterViewController.h"

static NSString * const TGDiagnosticCenterModuleIdentifier =
    @"com.michirose.telegraphica.workshop.diagnosticcenter";

@implementation TGDiagnosticCenterModule

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super init];
    if (self) {
        _hostContext = [context retain];
        _viewController = [[TGDiagnosticCenterViewController alloc] initWithHostContext:context];
    }
    return self;
}

- (NSString *)moduleIdentifier { return TGDiagnosticCenterModuleIdentifier; }
- (NSString *)moduleDisplayName {
    return [_hostContext localizedStringForKey:@"diagnosticCenter.title"
                                      fallback:@"Diagnostic Center"];
}
- (NSString *)moduleVersion { return @"1.0.0"; }
- (NSString *)minimumHostVersion { return @"0.5.1"; }
- (NSUInteger)moduleAPIVersion { return TGWorkshopModuleAPIVersion; }
- (NSViewController *)mainViewController { return _viewController; }
- (NSArray *)supportedLocalizationCodes {
    return [NSArray arrayWithObjects:@"ru", @"be", @"en", nil];
}
- (BOOL)startWithError:(NSError **)error {
    (void)error;
    return YES;
}
- (void)stop {}
- (BOOL)saveStateWithError:(NSError **)error {
    (void)error;
    return YES;
}
- (BOOL)clearUserDataWithError:(NSError **)error {
    (void)error;
    return YES;
}

- (void)dealloc {
    [_hostContext release];
    [_viewController release];
    [super dealloc];
}

@end
