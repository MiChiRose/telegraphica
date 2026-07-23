#import <Cocoa/Cocoa.h>
#import "TGWorkshopHostContextImpl.h"

@class TGWorkshopCatalog;
@class TGWorkshopCatalogEntry;
@class TGWorkshopModuleLoader;
@class TGWorkshopRegistryStore;

@protocol TGWorkshopCoordinatorDelegate <NSObject>
- (void)workshopCoordinatorDidReload;
- (void)workshopCoordinatorDidUpdateProgress:(double)progress moduleIdentifier:(NSString *)identifier;
- (void)workshopCoordinatorDidFailWithError:(NSError *)error moduleIdentifier:(NSString *)identifier;
- (void)workshopCoordinatorDidOpenModuleViewController:(NSViewController *)viewController
                                      moduleIdentifier:(NSString *)identifier;
@end

@interface TGWorkshopCoordinator : NSObject {
@private
    id<TGWorkshopCoordinatorDelegate> _delegate;
    TGWorkshopRegistryStore *_registryStore;
    id _catalogParser;
    id _catalogClient;
    id _packageDownloader;
    id _installer;
    TGWorkshopModuleLoader *_moduleLoader;
    TGWorkshopCatalog *_catalog;
    NSMutableSet *_busyModuleIdentifiers;
    NSString *_activeModuleIdentifier;
}

@property(nonatomic, assign) id<TGWorkshopCoordinatorDelegate> delegate;
@property(nonatomic, retain, readonly) TGWorkshopCatalog *catalog;
@property(nonatomic, copy, readonly) NSString *activeModuleIdentifier;

- (id)initWithHostDelegate:(id<TGWorkshopHostContextDelegate>)hostDelegate;
- (void)start;
- (void)refreshCatalog;
- (NSArray *)entriesForMode:(NSString *)mode;
- (NSDictionary *)installedRecordForModuleIdentifier:(NSString *)identifier;
- (BOOL)isModuleBusy:(NSString *)identifier;
- (void)installOrUpdateEntry:(TGWorkshopCatalogEntry *)entry;
- (void)openEntry:(TGWorkshopCatalogEntry *)entry;
- (void)closeActiveModule;
- (void)removeEntry:(TGWorkshopCatalogEntry *)entry removeData:(BOOL)removeData;

@end
