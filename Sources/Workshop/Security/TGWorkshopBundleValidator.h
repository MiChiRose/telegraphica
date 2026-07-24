#import <Foundation/Foundation.h>

@class TGWorkshopCatalogEntry;

@interface TGWorkshopBundleValidator : NSObject

- (BOOL)validateBundleAtPath:(NSString *)bundlePath
             catalogEntry:(TGWorkshopCatalogEntry *)entry
                  manifest:(NSDictionary **)manifest
                     error:(NSError **)error;

@end
