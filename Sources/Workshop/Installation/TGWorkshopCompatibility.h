#import <Foundation/Foundation.h>

@class TGWorkshopCatalogEntry;

@interface TGWorkshopCompatibility : NSObject

+ (BOOL)catalogEntryIsCompatible:(TGWorkshopCatalogEntry *)entry
              applicationVersion:(NSString *)applicationVersion
                     systemVersion:(NSString *)systemVersion
                       architecture:(NSString *)architecture
                              error:(NSError **)error;
+ (NSString *)currentSystemVersion;
+ (NSString *)currentArchitecture;

@end
