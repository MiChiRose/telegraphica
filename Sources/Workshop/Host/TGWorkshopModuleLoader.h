#import <Cocoa/Cocoa.h>
#import "TGWorkshopHostContextImpl.h"

@class TGWorkshopRegistryStore;

@interface TGWorkshopModuleLoader : NSObject {
@private
    TGWorkshopRegistryStore *_registryStore;
    id<TGWorkshopHostContextDelegate> _hostDelegate;
    NSMutableDictionary *_loadedModules;
    NSMutableDictionary *_hostContexts;
}

- (id)initWithRegistryStore:(TGWorkshopRegistryStore *)registryStore
                 hostDelegate:(id<TGWorkshopHostContextDelegate>)hostDelegate;
- (id)loadModuleWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (NSViewController *)viewControllerForLoadedModuleIdentifier:(NSString *)identifier;
- (BOOL)saveAndStopModuleWithIdentifier:(NSString *)identifier error:(NSError **)error;
- (void)saveAndStopAllModules;
- (BOOL)recoverInterruptedModuleLaunches:(NSError **)error;

@end
