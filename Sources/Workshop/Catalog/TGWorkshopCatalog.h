#import <Foundation/Foundation.h>

@class TGWorkshopCatalogEntry;

@interface TGWorkshopCatalog : NSObject {
@private
    NSUInteger _catalogVersion;
    NSDate *_generatedAt;
    NSDate *_expiresAt;
    NSArray *_entries;
}

@property(nonatomic, assign, readonly) NSUInteger catalogVersion;
@property(nonatomic, retain, readonly) NSDate *generatedAt;
@property(nonatomic, retain, readonly) NSDate *expiresAt;
@property(nonatomic, retain, readonly) NSArray *entries;

- (id)initWithPayloadDictionary:(NSDictionary *)dictionary error:(NSError **)error;
- (TGWorkshopCatalogEntry *)entryForModuleIdentifier:(NSString *)identifier;
- (BOOL)isExpiredAtDate:(NSDate *)date;

@end
