#import <Foundation/Foundation.h>

@interface TGWorkshopRegistryStore : NSObject {
@private
    NSString *_registryPath;
    NSMutableDictionary *_records;
}

@property(nonatomic, copy, readonly) NSString *registryPath;

- (id)initWithRegistryPath:(NSString *)registryPath;
- (BOOL)load:(NSError **)error;
- (BOOL)save:(NSError **)error;
- (NSArray *)installedModuleIdentifiers;
- (NSDictionary *)recordForModuleIdentifier:(NSString *)identifier;
- (void)setRecord:(NSDictionary *)record forModuleIdentifier:(NSString *)identifier;
- (void)removeRecordForModuleIdentifier:(NSString *)identifier;
- (NSArray *)pendingRemovalModuleIdentifiers;

@end
