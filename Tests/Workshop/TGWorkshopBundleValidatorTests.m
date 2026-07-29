#import <Cocoa/Cocoa.h>
#import <sys/stat.h>
#import <unistd.h>

#import "../../Sources/Workshop/Catalog/TGWorkshopCatalogEntry.h"
#import "../../Sources/Workshop/Security/TGWorkshopBundleValidator.h"

static NSUInteger TGFailures = 0;

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        TGFailures++;
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    }
}

static TGWorkshopCatalogEntry *TGEntry(NSString *identifier) {
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                identifier, @"id",
                                @"Test plugin", @"name",
                                [NSDictionary dictionaryWithObject:@"Test plugin" forKey:@"en"], @"localized_name",
                                [NSDictionary dictionaryWithObject:@"Test" forKey:@"en"], @"description",
                                @"1.0.1", @"version",
                                [NSNumber numberWithInteger:1], @"api_version",
                                @"0.5.2", @"minimum_app_version",
                                @"10.9", @"minimum_os_version",
                                [NSArray arrayWithObject:@"x86_64"], @"architectures",
                                @"games", @"category",
                                [NSNumber numberWithInteger:1], @"archive_size",
                                [NSNumber numberWithInteger:1], @"unpacked_size",
                                [NSNumber numberWithInteger:1], @"entry_count",
                                [@"" stringByPaddingToLength:64 withString:@"0" startingAtIndex:0], @"sha256",
                                [NSDictionary dictionaryWithObject:@"test" forKey:@"key_id"], @"signature",
                                @"https://example.com/plugin.zip", @"download_url",
                                [NSArray arrayWithObject:@"module-data"], @"permissions",
                                nil];
    return [[[TGWorkshopCatalogEntry alloc] initWithDictionary:dictionary error:NULL] autorelease];
}

static NSString *TGCreateBundle(NSString *root, NSString *identifier) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *bundlePath = [root stringByAppendingPathComponent:@"Test.bundle"];
    NSString *executableDirectory = [bundlePath stringByAppendingPathComponent:@"Contents/MacOS"];
    NSString *resourcesDirectory = [bundlePath stringByAppendingPathComponent:@"Contents/Resources"];
    [fileManager createDirectoryAtPath:executableDirectory
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:NULL];
    [fileManager createDirectoryAtPath:resourcesDirectory
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:NULL];

    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          identifier, @"CFBundleIdentifier",
                          @"1.0.1", @"CFBundleShortVersionString",
                          @"RetroConsole", @"CFBundleExecutable",
                          @"TGRetroConsoleModule", @"NSPrincipalClass",
                          nil];
    NSDictionary *manifest = [NSDictionary dictionaryWithObjectsAndKeys:
                              identifier, @"identifier",
                              @"1.0.1", @"version",
                              @"TGRetroConsoleModule", @"principal_class",
                              [NSNumber numberWithInteger:1], @"api_version",
                              nil];
    [info writeToFile:[bundlePath stringByAppendingPathComponent:@"Contents/Info.plist"] atomically:YES];
    [manifest writeToFile:[resourcesDirectory stringByAppendingPathComponent:@"WorkshopModule.plist"]
               atomically:YES];
    NSString *executablePath = [executableDirectory stringByAppendingPathComponent:@"RetroConsole"];
    [@"#!/bin/sh\nexit 0\n" writeToFile:executablePath
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:NULL];
    chmod([executablePath fileSystemRepresentation], 0755);
    return bundlePath;
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"telegraphica-workshop-validator-%d", getpid()]];
    [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];

    NSString *retroIdentifier = @"com.michirose.telegraphica.workshop.retroconsole";
    NSString *bundlePath = TGCreateBundle(root, retroIdentifier);
    NSString *coresPath = [bundlePath stringByAppendingPathComponent:@"Contents/Resources/Cores"];
    [[NSFileManager defaultManager] createDirectoryAtPath:coresPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    [@"core" writeToFile:[coresPath stringByAppendingPathComponent:@"quicknes_libretro.dylib"]
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:NULL];

    TGWorkshopBundleValidator *validator = [[[TGWorkshopBundleValidator alloc] init] autorelease];
    TGAssert([validator validateBundleAtPath:bundlePath
                               catalogEntry:TGEntry(retroIdentifier)
                                    manifest:NULL
                                       error:NULL],
             @"the approved Retro Console core should be accepted");

    [@"core" writeToFile:[coresPath stringByAppendingPathComponent:@"unapproved_libretro.dylib"]
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:NULL];
    TGAssert(![validator validateBundleAtPath:bundlePath
                                catalogEntry:TGEntry(retroIdentifier)
                                     manifest:NULL
                                        error:NULL],
             @"an unapproved nested dynamic library should still be rejected");

    [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
    fprintf(stdout, "Workshop bundle validator tests: %lu failure(s)\n",
            (unsigned long)TGFailures);
    [pool drain];
    return TGFailures == 0 ? 0 : 1;
}
