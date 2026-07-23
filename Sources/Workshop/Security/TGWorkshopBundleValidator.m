#import "TGWorkshopBundleValidator.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../API/TGWorkshopModuleDefinitions.h"

static NSError *TGWorkshopBundleError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSString *TGWorkshopBundleString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

@implementation TGWorkshopBundleValidator

- (BOOL)validateBundleAtPath:(NSString *)bundlePath
             catalogEntry:(TGWorkshopCatalogEntry *)entry
                  manifest:(NSDictionary **)manifest
                     error:(NSError **)error {
    BOOL isDirectory = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:bundlePath isDirectory:&isDirectory] || !isDirectory ||
        ![[bundlePath pathExtension] isEqualToString:@"bundle"]) {
        if (error) *error = TGWorkshopBundleError(340, @"Workshop package does not contain a Cocoa bundle.");
        return NO;
    }

    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSString *manifestPath = [bundlePath stringByAppendingPathComponent:
                              [@"Contents/Resources" stringByAppendingPathComponent:TGWorkshopModuleManifestFileName]];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
    NSDictionary *moduleManifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
    if (![info isKindOfClass:[NSDictionary class]] || ![moduleManifest isKindOfClass:[NSDictionary class]]) {
        if (error) *error = TGWorkshopBundleError(341, @"Workshop bundle metadata is missing.");
        return NO;
    }

    NSString *expectedIdentifier = [entry moduleIdentifier];
    NSString *bundleIdentifier = TGWorkshopBundleString([info objectForKey:@"CFBundleIdentifier"]);
    NSString *manifestIdentifier = TGWorkshopBundleString([moduleManifest objectForKey:@"identifier"]);
    NSString *bundleVersion = TGWorkshopBundleString([info objectForKey:@"CFBundleShortVersionString"]);
    NSString *manifestVersion = TGWorkshopBundleString([moduleManifest objectForKey:@"version"]);
    NSString *principalClass = TGWorkshopBundleString([info objectForKey:@"NSPrincipalClass"]);
    NSString *manifestPrincipalClass = TGWorkshopBundleString([moduleManifest objectForKey:@"principal_class"]);
    if (![bundleIdentifier isEqualToString:expectedIdentifier] ||
        ![manifestIdentifier isEqualToString:expectedIdentifier] ||
        ![bundleVersion isEqualToString:[entry version]] ||
        ![manifestVersion isEqualToString:[entry version]] ||
        [principalClass length] == 0 ||
        ![principalClass isEqualToString:manifestPrincipalClass] ||
        [[moduleManifest objectForKey:@"api_version"] unsignedIntegerValue] != [entry apiVersion]) {
        if (error) *error = TGWorkshopBundleError(342, @"Workshop bundle metadata does not match the signed catalog.");
        return NO;
    }

    NSString *executableName = TGWorkshopBundleString([info objectForKey:@"CFBundleExecutable"]);
    NSString *executablePath = [bundlePath stringByAppendingPathComponent:
                                [@"Contents/MacOS" stringByAppendingPathComponent:executableName ? executableName : @""]];
    if ([executableName length] == 0 || ![fileManager isExecutableFileAtPath:executablePath]) {
        if (error) *error = TGWorkshopBundleError(343, @"Workshop bundle executable is missing or not executable.");
        return NO;
    }

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:bundlePath];
    NSString *relativePath = nil;
    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [bundlePath stringByAppendingPathComponent:relativePath];
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:error];
        NSString *fileType = [attributes objectForKey:NSFileType];
        NSString *extension = [[relativePath pathExtension] lowercaseString];
        if ([fileType isEqualToString:NSFileTypeSymbolicLink] ||
            [extension isEqualToString:@"framework"] ||
            [extension isEqualToString:@"dylib"] ||
            [extension isEqualToString:@"bundle"]) {
            if (error && !*error) *error = TGWorkshopBundleError(344, @"Workshop bundle contains a forbidden nested executable component.");
            return NO;
        }
    }

    if (manifest) {
        *manifest = moduleManifest;
    }
    return YES;
}

@end
