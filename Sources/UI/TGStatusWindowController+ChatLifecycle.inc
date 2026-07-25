- (TGChatLifecycleWindowController *)preparedChatLifecycleWindowController {
    if (!self.chatLifecycleWindowController) {
        TGChatLifecycleWindowController *controller = [[[TGChatLifecycleWindowController alloc] initWithClient:self.client] autorelease];
        [controller setDelegate:self];
        self.chatLifecycleWindowController = controller;
    }
    return self.chatLifecycleWindowController;
}

- (void)openNewChatWindow:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Contacts are available only after sign-in is ready."];
        return;
    }
    TGChatLifecycleWindowController *controller = [self preparedChatLifecycleWindowController];
    [[controller window] center];
    [controller showWindow:self];
    [[controller window] makeKeyAndOrderFront:self];
    [controller refreshContacts];
}

- (void)openJoinChatWindow:(id)sender {
    [self openNewChatWindow:sender];
    [[self preparedChatLifecycleWindowController] focusInviteLink];
}

- (void)chatLifecycleWindowController:(TGChatLifecycleWindowController *)controller
                        didOpenChatID:(NSNumber *)chatID
                                title:(NSString *)title {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    [[controller window] orderOut:self];
    self.selectedChatFilterID = nil;
    self.chatNavigationClosed = NO;
    self.selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    self.selectedChatTitle = ([title length] > 0 ? title : TGLoc(@"chats"));
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self appendDetail:[NSString stringWithFormat:@"Opening chat %@.", self.selectedChatID]];
    [self reloadChatsInteractive:NO preserveSelection:YES];
}

- (void)leaveChatFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] ||
        [item isForumTopic] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    NSString *typeSummary = [item typeSummary];
    BOOL canLeave = ([typeSummary isEqualToString:@"Group"] ||
                     [typeSummary isEqualToString:@"Supergroup"] ||
                     [typeSummary isEqualToString:@"Channel"]);
    if (!canLeave) {
        return;
    }

    NSString *title = [[item title] length] > 0 ? [item title] : TGLoc(@"chats");
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[NSString stringWithFormat:TGLoc(@"chat.leaveConfirmTitle"), title]];
    [alert setInformativeText:TGLoc(@"chat.leaveConfirm")];
    [alert addButtonWithTitle:TGLoc(@"chat.leave")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSNumber *chatID = [[[NSNumber alloc] initWithLongLong:[[item chatID] longLongValue]] autorelease];
    NSNumber *chatIDCopy = [chatID retain];
    NSString *titleCopy = [title copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:TGLoc(@"chat.leaving")];
    [self appendDetail:[NSString stringWithFormat:@"Leaving %@...", titleCopy]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *leaveError = nil;
        BOOL succeeded = [client leaveChatWithID:chatIDCopy timeout:10.0 error:&leaveError];
        NSString *errorMessage = [[leaveError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:TGLoc(@"chat.left")];
                [self appendDetail:[NSString stringWithFormat:@"Left %@.", titleCopy]];
                if (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]) {
                    self.selectedChatID = nil;
                    self.selectedMessageThreadID = nil;
                    self.selectedMessageTopicKind = nil;
                }
                [self reloadChatsInteractive:NO preserveSelection:NO];
            } else {
                [self.statusField setStringValue:TGLoc(@"chat.leaveFailed")];
                [self appendDetail:[NSString stringWithFormat:@"Leave chat failed: %@",
                                    [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [chatIDCopy release];
            [titleCopy release];
            [client release];
        });
        [pool drain];
    });
}
