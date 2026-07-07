#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "Services/TGLogger.h"

static void TGUncaughtExceptionHandler(NSException *exception) {
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Uncaught exception: %@ %@", [exception name], [exception reason]]];
}

int main(int argc, const char * argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSSetUncaughtExceptionHandler(&TGUncaughtExceptionHandler);

    NSApplication *application = [NSApplication sharedApplication];
    AppDelegate *delegate = [[[AppDelegate alloc] init] autorelease];
    [application setDelegate:delegate];
    [application run];

    [pool drain];
    return 0;
}
