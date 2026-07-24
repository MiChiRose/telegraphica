#import "TGWorkshopCatalogEntry.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../Host/TGWorkshopPaths.h"

static NSString *TGWorkshopStringValue(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSDictionary *TGWorkshopDictionaryValue(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *TGWorkshopStringArrayValue(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return nil;
    }
    id item = nil;
    for (item in value) {
        if (![item isKindOfClass:[NSString class]]) {
            return nil;
        }
    }
    return value;
}

static BOOL TGWorkshopCategoryIsValid(NSString *category) {
    if (![category isKindOfClass:[NSString class]] ||
        [category length] == 0 ||
        [category length] > 32) {
        return NO;
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                               @"abcdefghijklmnopqrstuvwxyz0123456789-"];
    return ([category rangeOfCharacterFromSet:[allowed invertedSet]].location == NSNotFound);
}

static NSError *TGWorkshopCatalogEntryError(NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:200
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

@implementation TGWorkshopCatalogEntry

@synthesize moduleIdentifier = _moduleIdentifier;
@synthesize name = _name;
@synthesize localizedNames = _localizedNames;
@synthesize localizedDescriptions = _localizedDescriptions;
@synthesize version = _version;
@synthesize apiVersion = _apiVersion;
@synthesize minimumApplicationVersion = _minimumApplicationVersion;
@synthesize minimumOSVersion = _minimumOSVersion;
@synthesize architectures = _architectures;
@synthesize category = _category;
@synthesize archiveSize = _archiveSize;
@synthesize unpackedSize = _unpackedSize;
@synthesize entryCount = _entryCount;
@synthesize SHA256 = _SHA256;
@synthesize signature = _signature;
@synthesize downloadURL = _downloadURL;
@synthesize iconURL = _iconURL;
@synthesize localizedChangelog = _localizedChangelog;
@synthesize permissions = _permissions;

- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    self = [super init];
    if (!self) {
        return nil;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) *error = TGWorkshopCatalogEntryError(@"Workshop module entry is not a dictionary.");
        [self release];
        return nil;
    }

    _moduleIdentifier = [TGWorkshopStringValue([dictionary objectForKey:@"id"]) copy];
    _name = [TGWorkshopStringValue([dictionary objectForKey:@"name"]) copy];
    _localizedNames = [TGWorkshopDictionaryValue([dictionary objectForKey:@"localized_name"]) retain];
    _localizedDescriptions = [TGWorkshopDictionaryValue([dictionary objectForKey:@"description"]) retain];
    _version = [TGWorkshopStringValue([dictionary objectForKey:@"version"]) copy];
    _apiVersion = [[dictionary objectForKey:@"api_version"] unsignedIntegerValue];
    _minimumApplicationVersion = [TGWorkshopStringValue([dictionary objectForKey:@"minimum_app_version"]) copy];
    _minimumOSVersion = [TGWorkshopStringValue([dictionary objectForKey:@"minimum_os_version"]) copy];
    _architectures = [TGWorkshopStringArrayValue([dictionary objectForKey:@"architectures"]) retain];
    _category = [TGWorkshopStringValue([dictionary objectForKey:@"category"]) copy];
    _archiveSize = [[dictionary objectForKey:@"archive_size"] unsignedLongLongValue];
    _unpackedSize = [[dictionary objectForKey:@"unpacked_size"] unsignedLongLongValue];
    _entryCount = [[dictionary objectForKey:@"entry_count"] unsignedIntegerValue];
    _SHA256 = [[TGWorkshopStringValue([dictionary objectForKey:@"sha256"]) lowercaseString] copy];
    _signature = [TGWorkshopDictionaryValue([dictionary objectForKey:@"signature"]) retain];

    NSString *downloadURLString = TGWorkshopStringValue([dictionary objectForKey:@"download_url"]);
    NSString *iconURLString = TGWorkshopStringValue([dictionary objectForKey:@"icon_url"]);
    _downloadURL = [[NSURL URLWithString:downloadURLString] retain];
    _iconURL = [[NSURL URLWithString:iconURLString] retain];
    _localizedChangelog = [TGWorkshopDictionaryValue([dictionary objectForKey:@"changelog"]) retain];
    _permissions = [TGWorkshopStringArrayValue([dictionary objectForKey:@"permissions"]) retain];

    BOOL valid = TGWorkshopIdentifierIsSafePathComponent(_moduleIdentifier) &&
                 [_name length] > 0 &&
                 [_version length] > 0 &&
                 _apiVersion > 0 &&
                 [_minimumApplicationVersion length] > 0 &&
                 [_minimumOSVersion length] > 0 &&
                 [_architectures count] > 0 &&
                 TGWorkshopCategoryIsValid(_category) &&
                 _archiveSize > 0 &&
                 _unpackedSize > 0 &&
                 _entryCount > 0 &&
                 [_SHA256 length] == 64 &&
                 _signature != nil &&
                 [[_downloadURL scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame &&
                 [_permissions count] > 0;
    if (!valid) {
        if (error) *error = TGWorkshopCatalogEntryError(@"Workshop module entry is incomplete or invalid.");
        [self release];
        return nil;
    }
    return self;
}

- (NSString *)localizedValueFromDictionary:(NSDictionary *)dictionary
                              languageCode:(NSString *)languageCode
                                  fallback:(NSString *)fallback {
    NSString *value = TGWorkshopStringValue([dictionary objectForKey:languageCode]);
    if ([value length] == 0) {
        value = TGWorkshopStringValue([dictionary objectForKey:@"en"]);
    }
    return ([value length] > 0) ? value : fallback;
}

- (NSString *)localizedNameForLanguageCode:(NSString *)languageCode {
    return [self localizedValueFromDictionary:_localizedNames languageCode:languageCode fallback:_name];
}

- (NSString *)localizedDescriptionForLanguageCode:(NSString *)languageCode {
    return [self localizedValueFromDictionary:_localizedDescriptions languageCode:languageCode fallback:@""];
}

- (NSString *)localizedChangelogForLanguageCode:(NSString *)languageCode {
    return [self localizedValueFromDictionary:_localizedChangelog languageCode:languageCode fallback:@""];
}

- (void)dealloc {
    [_moduleIdentifier release];
    [_name release];
    [_localizedNames release];
    [_localizedDescriptions release];
    [_version release];
    [_minimumApplicationVersion release];
    [_minimumOSVersion release];
    [_architectures release];
    [_category release];
    [_SHA256 release];
    [_signature release];
    [_downloadURL release];
    [_iconURL release];
    [_localizedChangelog release];
    [_permissions release];
    [super dealloc];
}

@end
