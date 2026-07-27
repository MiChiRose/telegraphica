- (void)showChatFolderManagementWindow:(id)sender {
    (void)sender;
    if (!self.client || ![self.currentAuthState isEqualToString:@"ready"]) {
        NSBeep();
        return;
    }
    if (!self.chatFolderManagementWindowController) {
        self.chatFolderManagementWindowController = [[[TGChatFolderManagementWindowController alloc] initWithClient:self.client] autorelease];
        [self.chatFolderManagementWindowController setDelegate:self];
    }
    [[self.chatFolderManagementWindowController window] center];
    [self.chatFolderManagementWindowController showWindow:self];
    [[self.chatFolderManagementWindowController window] makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
    [self.chatFolderManagementWindowController reloadFolders];
}

- (void)chatFolderManagementWindowControllerDidChangeFolders:(TGChatFolderManagementWindowController *)controller {
    (void)controller;
    self.chatFilterRefreshRetryCount = 0;
    [self reloadChatFiltersIfReady];
}
