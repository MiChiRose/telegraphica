#import "AppDelegate.h"
#import "Services/TGLogger.h"
#import "UI/TGStatusWindowController.h"

@implementation AppDelegate

@synthesize statusWindowController = _statusWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self buildMainMenu];

    NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
    if (appIcon) {
        [NSApp setApplicationIconImage:appIcon];
    }

    [[TGLogger sharedLogger] startDiagnosticSession];
    [[TGLogger sharedLogger] log:@"Telegraphica launched."];

    self.statusWindowController = [[[TGStatusWindowController alloc] init] autorelease];
    [self.statusWindowController showWindow:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    (void)sender;
    [self.statusWindowController prepareForApplicationTermination];
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.statusWindowController prepareForApplicationTermination];
}

- (void)buildMainMenu {
    NSMenu *mainMenu = [[[NSMenu alloc] initWithTitle:@"MainMenu"] autorelease];
    NSMenuItem *appMenuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:@"Telegraphica"] autorelease];
    NSString *quitTitle = [@"Quit " stringByAppendingString:[[NSProcessInfo processInfo] processName]];
    NSMenuItem *quitItem = [[[NSMenuItem alloc] initWithTitle:quitTitle
                                                       action:@selector(terminate:)
                                                keyEquivalent:@"q"] autorelease];
    [appMenu addItem:quitItem];
    [appMenuItem setSubmenu:appMenu];
    [NSApp setMainMenu:mainMenu];
}

- (void)dealloc {
    [_statusWindowController release];
    [super dealloc];
}

@end
