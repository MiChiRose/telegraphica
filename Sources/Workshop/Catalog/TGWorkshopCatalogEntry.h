#import <Foundation/Foundation.h>

@interface TGWorkshopCatalogEntry : NSObject {
@private
    NSString *_moduleIdentifier;
    NSString *_name;
    NSDictionary *_localizedNames;
    NSDictionary *_localizedDescriptions;
    NSString *_version;
    NSUInteger _apiVersion;
    NSString *_minimumApplicationVersion;
    NSString *_minimumOSVersion;
    NSArray *_architectures;
    NSString *_category;
    unsigned long long _archiveSize;
    unsigned long long _unpackedSize;
    NSUInteger _entryCount;
    NSString *_SHA256;
    NSDictionary *_signature;
    NSURL *_downloadURL;
    NSURL *_iconURL;
    NSDictionary *_localizedChangelog;
    NSArray *_permissions;
}

@property(nonatomic, copy, readonly) NSString *moduleIdentifier;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, retain, readonly) NSDictionary *localizedNames;
@property(nonatomic, retain, readonly) NSDictionary *localizedDescriptions;
@property(nonatomic, copy, readonly) NSString *version;
@property(nonatomic, assign, readonly) NSUInteger apiVersion;
@property(nonatomic, copy, readonly) NSString *minimumApplicationVersion;
@property(nonatomic, copy, readonly) NSString *minimumOSVersion;
@property(nonatomic, retain, readonly) NSArray *architectures;
@property(nonatomic, copy, readonly) NSString *category;
@property(nonatomic, assign, readonly) unsigned long long archiveSize;
@property(nonatomic, assign, readonly) unsigned long long unpackedSize;
@property(nonatomic, assign, readonly) NSUInteger entryCount;
@property(nonatomic, copy, readonly) NSString *SHA256;
@property(nonatomic, retain, readonly) NSDictionary *signature;
@property(nonatomic, retain, readonly) NSURL *downloadURL;
@property(nonatomic, retain, readonly) NSURL *iconURL;
@property(nonatomic, retain, readonly) NSDictionary *localizedChangelog;
@property(nonatomic, retain, readonly) NSArray *permissions;

- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
- (NSString *)localizedNameForLanguageCode:(NSString *)languageCode;
- (NSString *)localizedDescriptionForLanguageCode:(NSString *)languageCode;
- (NSString *)localizedChangelogForLanguageCode:(NSString *)languageCode;

@end
