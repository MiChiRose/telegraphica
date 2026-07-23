#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "Core/TGDemoContent.h"
#import "Services/TGLogger.h"
#include <stdlib.h>
#include <string.h>

static void TGUncaughtExceptionHandler(NSException *exception) {
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Uncaught exception: %@ %@", [exception name], [exception reason]]];
}

int main(int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSSetUncaughtExceptionHandler(&TGUncaughtExceptionHandler);

    int argumentIndex = 0;
    for (argumentIndex = 1; argumentIndex < argc; argumentIndex++) {
        if (strcmp(argv[argumentIndex], "--demo-mode") == 0) {
            setenv("TELEGRAPHICA_DEMO_MODE", "1", 1);
            break;
        }
    }
    NSApplication *application = [NSApplication sharedApplication];
    AppDelegate *delegate = [[[AppDelegate alloc] init] autorelease];
    [application setDelegate:delegate];
    [application run];

    [pool drain];
    return 0;
}
