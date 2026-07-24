#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/Installation/TGWorkshopInstaller.h"
#import "../../Sources/Workshop/Installation/TGWorkshopRegistryStore.h"
#import "../../Sources/Workshop/Security/TGWorkshopArchiveExtractor.h"
#import "../../Sources/Workshop/Security/TGWorkshopBundleValidator.h"
#import "../../Sources/Workshop/Security/TGWorkshopIntegrity.h"
#import "../../Sources/Workshop/Installation/TGWorkshopCompatibility.h"
#import "../../Sources/Workshop/Host/TGWorkshopPaths.h"

@implementation TGWorkshopArchiveExtractor
@synthesize maximumEntryCount;
@synthesize maximumTotalSize;
@synthesize maximumFileSize;
@synthesize maximumPathLength;
@synthesize maximumPathDepth;
- (BOOL)extractArchiveAtPath:(NSString *)archivePath
         toEmptyDirectoryPath:(NSString *)destinationPath
                       error:(NSError **)error {
    (void)archivePath;
    (void)destinationPath;
    (void)error;
    return NO;
}
@end

@implementation TGWorkshopBundleValidator
- (BOOL)validateBundleAtPath:(NSString *)bundlePath
                catalogEntry:(id)entry
                     manifest:(NSDictionary **)manifest
                        error:(NSError **)error {
    (void)bundlePath;
    (void)entry;
    (void)manifest;
    (void)error;
    return NO;
}
@end

@implementation TGWorkshopIntegrity
+ (NSString *)SHA256ForFileAtPath:(NSString *)path error:(NSError **)error {
    (void)path;
    (void)error;
    return nil;
}
+ (BOOL)fileAtPath:(NSString *)path matchesSHA256:(NSString *)expectedSHA256 error:(NSError **)error {
    (void)path;
    (void)expectedSHA256;
    (void)error;
    return NO;
}
+ (BOOL)verifySignature:(NSData *)signature
               overData:(NSData *)data
                 domain:(NSString *)domain
  certificateDERAtPath:(NSString *)certificatePath
                  error:(NSError **)error {
    (void)signature;
    (void)data;
    (void)domain;
    (void)certificatePath;
    (void)error;
    return NO;
}
@end

@implementation TGWorkshopCompatibility
+ (BOOL)catalogEntryIsCompatible:(id)entry
              applicationVersion:(NSString *)applicationVersion
                   systemVersion:(NSString *)systemVersion
                     architecture:(NSString *)architecture
                            error:(NSError **)error {
    (void)entry;
    (void)applicationVersion;
    (void)systemVersion;
    (void)architecture;
    (void)error;
    return NO;
}
+ (NSString *)currentSystemVersion { return @"10.9"; }
+ (NSString *)currentArchitecture { return @"x86_64"; }
@end

static NSUInteger TGFailures = 0;

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        TGFailures++;
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    }
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *root = [[[NSProcessInfo processInfo] environment] objectForKey:@"TELEGRAPHICA_WORKSHOP_TEST_ROOT"];
    TGAssert([root length] > 0, @"test root should be configured");

    NSError *error = nil;
    TGAssert(TGWorkshopEnsureBaseDirectories(&error), @"base directories should be created");

    NSString *identifier = @"com.michirose.telegraphica.workshop.test";
    NSString *moduleRoot = [TGWorkshopModulesDirectory() stringByAppendingPathComponent:identifier];
    NSString *bundleRoot = [[[moduleRoot stringByAppendingPathComponent:@"Versions"]
                             stringByAppendingPathComponent:@"1.0.0"]
                            stringByAppendingPathComponent:[identifier stringByAppendingPathExtension:@"bundle"]];
    NSString *dataRoot = TGWorkshopDataDirectoryForModuleIdentifier(identifier);
    TGAssert(TGWorkshopEnsureDirectory(bundleRoot, &error), @"installed bundle directory should be created");
    TGAssert(TGWorkshopEnsureDirectory(dataRoot, &error), @"module data directory should be created");

    TGWorkshopRegistryStore *store = [[[TGWorkshopRegistryStore alloc] initWithRegistryPath:TGWorkshopRegistryPath()] autorelease];
    NSDictionary *record = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"1.0.0", @"active_version",
                            [NSNumber numberWithBool:NO], @"pending_removal",
                            [NSNumber numberWithBool:NO], @"remove_data",
                            nil];
    [store setRecord:record forModuleIdentifier:identifier];
    TGAssert([store save:&error], @"installed module record should be saved");

    TGWorkshopInstaller *installer = [[[TGWorkshopInstaller alloc]
                                       initWithRegistryStore:store
                                       packageCertificatePathsByKeyIdentifier:[NSDictionary dictionary]] autorelease];
    TGAssert([installer markModuleForRemoval:identifier removeData:NO error:&error],
             @"module should be marked for removal");
    TGAssert([installer processPendingRemovals:&error],
             @"pending removal should finish in the same session");
    TGAssert(![[NSFileManager defaultManager] fileExistsAtPath:moduleRoot],
             @"installed module files should be removed");
    TGAssert([[NSFileManager defaultManager] fileExistsAtPath:dataRoot],
             @"module progress should remain when removeData is false");
    TGAssert([store recordForModuleIdentifier:identifier] == nil,
             @"registry should not retain a ghost installed version");

    fprintf(stdout, "Workshop installer state tests: %lu failure(s)\n", (unsigned long)TGFailures);
    [pool drain];
    return TGFailures == 0 ? 0 : 1;
}
