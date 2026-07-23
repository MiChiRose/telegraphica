#import "AppDelegate.h"
#import "Core/TGDemoContent.h"
#import "Services/TGLogger.h"
#import "UI/TGStatusWindowController.h"
#include <stdlib.h>

@implementation AppDelegate

@synthesize statusWindowController = _statusWindowController;

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self buildMainMenu];

    [[TGLogger sharedLogger] startDiagnosticSession];
    [[TGLogger sharedLogger] log:@"Telegraphica launched."];

    BOOL demoMode = [TGDemoContent isEnabledFromEnvironment];
    self.statusWindowController = [[[TGStatusWindowController alloc] initWithDemoMode:demoMode] autorelease];
    [self.statusWindowController showWindow:self];

    if (getenv("TELEGRAPHICA_SMOKE_LAUNCH")) {
        [[TGLogger sharedLogger] log:@"Smoke launch mode: main window initialized; terminating cleanly."];
        [self performSelector:@selector(terminateSmokeLaunch:) withObject:nil afterDelay:0.25];
        return;
    }

    [NSApp activateIgnoringOtherApps:YES];
}

- (void)terminateSmokeLaunch:(id)sender {
    (void)sender;
    [NSApp terminate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    if (!flag) {
        [self.statusWindowController showWindow:self];
        [NSApp activateIgnoringOtherApps:YES];
    }
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

    NSMenuItem *fileMenuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
    [mainMenu addItem:fileMenuItem];
    NSMenu *fileMenu = [[[NSMenu alloc] initWithTitle:@"File"] autorelease];
    NSMenuItem *closeItem = [[[NSMenuItem alloc] initWithTitle:@"Close"
                                                        action:@selector(performClose:)
                                                 keyEquivalent:@"w"] autorelease];
    [fileMenu addItem:closeItem];
    [fileMenuItem setSubmenu:fileMenu];

    NSMenuItem *editMenuItem = [[[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""] autorelease];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[[NSMenu alloc] initWithTitle:@"Edit"] autorelease];
    NSMenuItem *undoItem = [[[NSMenuItem alloc] initWithTitle:@"Undo"
                                                       action:NSSelectorFromString(@"undo:")
                                                keyEquivalent:@"z"] autorelease];
    [editMenu addItem:undoItem];
    NSMenuItem *redoItem = [[[NSMenuItem alloc] initWithTitle:@"Redo"
                                                       action:NSSelectorFromString(@"redo:")
                                                keyEquivalent:@"Z"] autorelease];
    [redoItem setKeyEquivalentModifierMask:(NSCommandKeyMask | NSShiftKeyMask)];
    [editMenu addItem:redoItem];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"] autorelease]];
    [editMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"] autorelease]];
    [editMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"] autorelease]];
    [editMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""] autorelease]];
    [editMenu addItem:[NSMenuItem separatorItem]];
    [editMenu addItem:[[[NSMenuItem alloc] initWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"] autorelease]];
    [editMenuItem setSubmenu:editMenu];

    [NSApp setMainMenu:mainMenu];
}

- (void)dealloc {
    [_statusWindowController release];
    [super dealloc];
}

@end
