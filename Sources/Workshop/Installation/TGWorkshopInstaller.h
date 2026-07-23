#import <Foundation/Foundation.h>

@class TGWorkshopArchiveExtractor;
@class TGWorkshopBundleValidator;
@class TGWorkshopCatalogEntry;
@class TGWorkshopRegistryStore;

@interface TGWorkshopInstaller : NSObject {
@private
    TGWorkshopArchiveExtractor *_archiveExtractor;
    TGWorkshopBundleValidator *_bundleValidator;
    TGWorkshopRegistryStore *_registryStore;
    NSDictionary *_packageCertificatePathsByKeyIdentifier;
}

- (id)initWithRegistryStore:(TGWorkshopRegistryStore *)registryStore
 packageCertificatePathsByKeyIdentifier:(NSDictionary *)certificatePaths;
- (BOOL)installPackageAtPath:(NSString *)packagePath
               catalogEntry:(TGWorkshopCatalogEntry *)entry
         applicationVersion:(NSString *)applicationVersion
                      error:(NSError **)error;
- (BOOL)markModuleForRemoval:(NSString *)identifier
                  removeData:(BOOL)removeData
                       error:(NSError **)error;
- (BOOL)processPendingRemovals:(NSError **)error;

@end
