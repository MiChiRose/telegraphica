#import <Cocoa/Cocoa.h>
#import "TGWorkshopHostContext.h"
#import "TGWorkshopModuleDefinitions.h"

@protocol TGWorkshopModule <NSObject>

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context;
- (NSString *)moduleIdentifier;
- (NSString *)moduleVersion;
- (NSUInteger)moduleAPIVersion;
- (NSViewController *)mainViewController;
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (BOOL)saveStateWithError:(NSError **)error;
- (NSArray *)supportedLocalizationCodes;
- (BOOL)clearUserDataWithError:(NSError **)error;

@end
