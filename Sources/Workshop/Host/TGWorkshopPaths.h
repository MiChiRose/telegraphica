#import <Foundation/Foundation.h>

NSString *TGWorkshopApplicationSupportDirectory(void);
NSString *TGWorkshopModulesDirectory(void);
NSString *TGWorkshopModuleDataDirectory(void);
NSString *TGWorkshopDataDirectoryForModuleIdentifier(NSString *identifier);
NSString *TGWorkshopCacheDirectory(void);
NSString *TGWorkshopCatalogCacheDirectory(void);
NSString *TGWorkshopDownloadsDirectory(void);
NSString *TGWorkshopStagingDirectory(void);
NSString *TGWorkshopTransactionsDirectory(void);
NSString *TGWorkshopRegistryPath(void);

BOOL TGWorkshopEnsureDirectory(NSString *path, NSError **error);
BOOL TGWorkshopEnsureBaseDirectories(NSError **error);
BOOL TGWorkshopIdentifierIsSafePathComponent(NSString *identifier);
