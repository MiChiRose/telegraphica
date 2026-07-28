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
    self.activeSection = TGSectionChats;
    self.showingArchivedChats = NO;
    self.selectedChatFilterID = nil;
    [self refreshChatListTitle];
    self.chatNavigationClosed = NO;
    self.selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    self.selectedChatTitle = ([title length] > 0 ? title : TGLoc(@"chats"));
    self.selectedChatTypeSummary = nil;
    self.selectedChatAvatarLocalPath = nil;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    self.suppressChatSelectionHandling = YES;
    [self.chatTableView deselectAll:nil];
    self.suppressChatSelectionHandling = NO;
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    self.forceMessageScrollToNewest = YES;
    [self refreshSelectedChatHeaderDisplay];
    [self updateVisibleSection];
    [self appendDetail:[NSString stringWithFormat:@"Opening chat %@.", self.selectedChatID]];
    [self reloadMessagesForChatID:self.selectedChatID interactive:NO];
    [self reloadChatsInteractive:NO
               preserveSelection:YES
                  requestedLimit:TGStatusChatPreviewMaximumLimit];
}

- (void)contactsViewController:(TGContactsViewController *)controller
                 didOpenChatID:(NSNumber *)chatID
                         title:(NSString *)title {
    (void)controller;
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    [self chatLifecycleWindowController:nil didOpenChatID:chatID title:title];
}

- (void)contactsViewControllerDidRequestNewConversation:(TGContactsViewController *)controller {
    (void)controller;
    [self openNewChatWindow:nil];
}

- (BOOL)contactsViewController:(TGContactsViewController *)controller
         didRequestSendContact:(NSDictionary *)contact {
    (void)controller;
    if (![self.currentAuthState isEqualToString:@"ready"] ||
        ![self.selectedChatID respondsToSelector:@selector(longLongValue)] ||
        [[contact objectForKey:@"phone_number"] length] == 0) {
        return NO;
    }
    NSString *firstName = [contact objectForKey:@"first_name"];
    if ([firstName length] == 0) {
        firstName = [contact objectForKey:@"display_name"];
    }
    NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:
                            firstName ? firstName : @"", @"first_name",
                            [contact objectForKey:@"last_name"] ? [contact objectForKey:@"last_name"] : @"", @"last_name",
                            [contact objectForKey:@"phone_number"], @"phone_number",
                            nil];
    self.activeSection = TGSectionChats;
    [self updateVisibleSection];
    [self sendSharedComposerItemWithKind:@"contact" values:values];
    return YES;
}

- (void)openProfileFromSettings:(id)sender {
    [self openProfileFromDrawer:sender];
}

- (void)returnFromProfileToSettings:(id)sender {
    (void)sender;
    self.activeSection = TGSectionSettings;
    [self updateVisibleSection];
}

- (void)toggleChatArchivedFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] ||
        [item isForumTopic] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    BOOL targetArchived = !self.showingArchivedChats;
    NSNumber *chatID = [[NSNumber numberWithLongLong:[[item chatID] longLongValue]] retain];
    NSString *title = [([[item title] length] > 0 ? [item title] : TGLoc(@"chats")) copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:(targetArchived ? TGLoc(@"chat.archiving") : TGLoc(@"chat.unarchiving"))];
    [self appendDetail:[NSString stringWithFormat:@"%@ %@...",
                        targetArchived ? @"Archiving" : @"Unarchiving",
                        title]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *archiveError = nil;
        BOOL succeeded = [client setChatWithID:chatID
                                      archived:targetArchived
                                       timeout:8.0
                                         error:&archiveError];
        NSString *errorMessage = [[archiveError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:(targetArchived ? TGLoc(@"chat.archived") : TGLoc(@"chat.unarchived"))];
                [self appendDetail:[NSString stringWithFormat:@"%@ %@.",
                                    targetArchived ? @"Archived" : @"Returned from archive",
                                    title]];
                [self.client invalidateMainChatListExhaustion];
                [self reloadChatsInteractive:NO preserveSelection:YES];
            } else {
                [self.statusField setStringValue:TGLoc(@"chat.archiveFailed")];
                [self appendDetail:[NSString stringWithFormat:@"Chat archive request failed: %@",
                                    [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [chatID release];
            [title release];
            [client release];
        });
        [pool drain];
    });
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

- (void)clearChatHistoryFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] ||
        [item isForumTopic] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    NSString *title = [[item title] length] > 0 ? [item title] : TGLoc(@"chats");
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:[NSString stringWithFormat:TGLoc(@"chat.clearHistoryConfirmTitle"), title]];
    [alert setInformativeText:TGLoc(@"chat.clearHistoryConfirm")];
    [alert addButtonWithTitle:TGLoc(@"chat.clearHistory")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSNumber *chatID = [[NSNumber numberWithLongLong:[[item chatID] longLongValue]] retain];
    NSString *titleCopy = [title copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:TGLoc(@"chat.clearingHistory")];
    [self appendDetail:[NSString stringWithFormat:@"Clearing history for %@...", titleCopy]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *clearError = nil;
        BOOL succeeded = [client deleteChatHistoryForChatID:chatID
                                        removeFromChatList:NO
                                                     revoke:NO
                                                    timeout:10.0
                                                      error:&clearError];
        NSString *errorMessage = [[clearError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:TGLoc(@"chat.historyCleared")];
                [self appendDetail:[NSString stringWithFormat:@"Cleared history for %@.", titleCopy]];
                if (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]) {
                    self.messageLoadingGeneration++;
                    self.pendingLiveMessageRefresh = NO;
                    self.messageItemsRepresentFocusedContext = NO;
                    [self.messageItems removeAllObjects];
                    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
                    [self.messageTableView reloadData];
                    self.olderMessagesExhausted = YES;
                    self.autoOlderMessagesLoadArmed = NO;
                    self.forceMessageScrollToNewest = NO;
                    [self refreshBotReplyMarkupFromMessages];
                    [self updateMessageJumpToNewestButtonVisibility];
                }
                [self reloadChatsInteractive:NO preserveSelection:YES];
            } else {
                [self.statusField setStringValue:TGLoc(@"chat.clearHistoryFailed")];
                [self appendDetail:[NSString stringWithFormat:@"Clear chat history failed: %@",
                                    [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [chatID release];
            [titleCopy release];
            [client release];
        });
        [pool drain];
    });
}
