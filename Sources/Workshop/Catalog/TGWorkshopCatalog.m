#import "TGWorkshopCatalog.h"
#import "TGWorkshopCatalogEntry.h"
#import "../API/TGWorkshopModuleDefinitions.h"

static NSError *TGWorkshopCatalogError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSDate *TGWorkshopDateFromISO8601String(NSString *string) {
    if (![string isKindOfClass:[NSString class]] || [string length] == 0) {
        return nil;
    }
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    return [formatter dateFromString:string];
}

@implementation TGWorkshopCatalog

@synthesize catalogVersion = _catalogVersion;
@synthesize generatedAt = _generatedAt;
@synthesize expiresAt = _expiresAt;
@synthesize entries = _entries;

- (id)initWithPayloadDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    self = [super init];
    if (!self) {
        return nil;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) *error = TGWorkshopCatalogError(210, @"Workshop catalog payload is invalid.");
        [self release];
        return nil;
    }

    _catalogVersion = [[dictionary objectForKey:@"catalog_version"] unsignedIntegerValue];
    _generatedAt = [TGWorkshopDateFromISO8601String([dictionary objectForKey:@"generated_at"]) retain];
    _expiresAt = [TGWorkshopDateFromISO8601String([dictionary objectForKey:@"expires_at"]) retain];
    NSArray *rawModules = [[dictionary objectForKey:@"modules"] isKindOfClass:[NSArray class]] ? [dictionary objectForKey:@"modules"] : nil;
    if (_catalogVersion == 0 || !_generatedAt || !_expiresAt || !rawModules || [_generatedAt compare:_expiresAt] != NSOrderedAscending) {
        if (error) *error = TGWorkshopCatalogError(211, @"Workshop catalog metadata is incomplete.");
        [self release];
        return nil;
    }

    NSMutableArray *parsedEntries = [NSMutableArray arrayWithCapacity:[rawModules count]];
    NSMutableSet *identifiers = [NSMutableSet setWithCapacity:[rawModules count]];
    id rawEntry = nil;
    for (rawEntry in rawModules) {
        NSError *entryError = nil;
        TGWorkshopCatalogEntry *entry = [[[TGWorkshopCatalogEntry alloc] initWithDictionary:rawEntry error:&entryError] autorelease];
        if (!entry || [identifiers containsObject:[entry moduleIdentifier]]) {
            if (error) {
                *error = entryError ? entryError : TGWorkshopCatalogError(212, @"Workshop catalog contains duplicate module identifiers.");
            }
            [self release];
            return nil;
        }
        [identifiers addObject:[entry moduleIdentifier]];
        [parsedEntries addObject:entry];
    }
    _entries = [parsedEntries copy];
    return self;
}

- (TGWorkshopCatalogEntry *)entryForModuleIdentifier:(NSString *)identifier {
    TGWorkshopCatalogEntry *entry = nil;
    for (entry in _entries) {
        if ([[entry moduleIdentifier] isEqualToString:identifier]) {
            return entry;
        }
    }
    return nil;
}

- (BOOL)isExpiredAtDate:(NSDate *)date {
    NSDate *referenceDate = date ? date : [NSDate date];
    return ([_expiresAt compare:referenceDate] != NSOrderedDescending);
}

- (void)dealloc {
    [_generatedAt release];
    [_expiresAt release];
    [_entries release];
    [super dealloc];
}

@end
