#import "TGWorkshopCompatibility.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../../UI/TGStatusSupport.h"

static NSError *TGWorkshopCompatibilityError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static BOOL TGWorkshopVersionIsAtLeast(NSString *candidate, NSString *minimum) {
    return [candidate isEqualToString:minimum] || TGVersionStringIsNewer(candidate, minimum);
}

@implementation TGWorkshopCompatibility

+ (BOOL)catalogEntryIsCompatible:(TGWorkshopCatalogEntry *)entry
              applicationVersion:(NSString *)applicationVersion
                   systemVersion:(NSString *)systemVersion
                     architecture:(NSString *)architecture
                            error:(NSError **)error {
    if ([entry apiVersion] != TGWorkshopModuleAPIVersion) {
        if (error) *error = TGWorkshopCompatibilityError(350, @"This Workshop module uses an unsupported API version.");
        return NO;
    }
    if (!TGWorkshopVersionIsAtLeast(applicationVersion, [entry minimumApplicationVersion])) {
        if (error) *error = TGWorkshopCompatibilityError(351, @"This Workshop module requires a newer Telegraphica version.");
        return NO;
    }
    if (!TGWorkshopVersionIsAtLeast(systemVersion, [entry minimumOSVersion])) {
        if (error) *error = TGWorkshopCompatibilityError(352, @"This Workshop module requires a newer OS X version.");
        return NO;
    }
    if (![[entry architectures] containsObject:architecture]) {
        if (error) *error = TGWorkshopCompatibilityError(353, @"This Workshop module does not support this Mac architecture.");
        return NO;
    }
    return YES;
}

+ (NSString *)currentSystemVersion {
    NSString *versionString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    NSScanner *scanner = [NSScanner scannerWithString:versionString ? versionString : @""];
    [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:NULL];
    NSString *version = nil;
    [scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789."] intoString:&version];
    return ([version length] > 0) ? version : @"10.9";
}

+ (NSString *)currentArchitecture {
#if defined(__x86_64__)
    return @"x86_64";
#elif defined(__arm64__)
    return @"arm64";
#else
    return @"unknown";
#endif
}

@end
