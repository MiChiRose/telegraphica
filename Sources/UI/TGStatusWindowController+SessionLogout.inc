- (void)logout:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Logout is available only after sign-in is ready."];
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Log out of Telegram?"];
    [alert setInformativeText:@"Telegraphica will close the current local TDLib session. You will need to sign in again on this Mac."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Logout"];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Logging out..."];
    [self appendDetail:@"Submitting Telegram logout to TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *logoutError = nil;
        NSString *logoutSummary = [[client logOutWithTimeout:8.0 error:&logoutError] copy];
        NSString *logoutErrorMessage = [[logoutError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (logoutSummary) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", logoutSummary]];
                [[TGLogger sharedLogger] log:@"TDLib logout accepted."];
                self.client = [[[TGTDLibClient alloc] init] autorelease];
                self.initialConnectStarted = NO;
                self.authClientRecoveryInFlight = NO;
                self.authClientRecoveryAttemptCount = 0;
                self.profileSummaryLoaded = NO;
                self.pendingLiveChatRefresh = NO;
                self.pendingLiveMessageRefresh = NO;
                [self.chatItems removeAllObjects];
                [self.messageItems removeAllObjects];
                [self.chatTableView deselectAll:nil];
                [self.chatTableView reloadData];
                [self.messageTableView reloadData];
                self.selectedChatID = nil;
                self.selectedChatTitle = nil;
                self.selectedChatTypeSummary = nil;
                self.selectedChatAvatarLocalPath = nil;
                self.selectedChatLastReadOutboxMessageID = nil;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                self.chatsExhausted = NO;
                self.olderMessagesExhausted = NO;
                self.autoChatListLoadArmed = YES;
                self.autoChatListRefreshArmed = YES;
                self.autoOlderMessagesLoadArmed = YES;
                [self refreshSelectedChatHeaderDisplay];
                [self.composerDraftsByTargetKey removeAllObjects];
                [self setComposerTextWithoutSavingDraft:nil];
                [self updateApplicationBadge];
                [self updateAuthControlsForState:@"closed"];
                [self setControlsBusy:NO];
                [self checkTDLib:nil];
            } else {
                NSString *message = logoutErrorMessage ? logoutErrorMessage : @"TDLib logout did not return a result.";
                [self.statusField setStringValue:@"Logout failed"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", message]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib logout failed: %@", message]];
                [self setControlsBusy:NO];
            }
            [logoutSummary release];
            [logoutErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)deleteLocalData:(id)sender {
    (void)sender;
    if (self.controlsBusy) {
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert setMessageText:TGLoc(@"settings.localData.confirm.title")];
    [alert setInformativeText:TGLoc(@"settings.localData.confirm.message")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    [alert addButtonWithTitle:TGLoc(@"settings.localData.delete")];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    [self setControlsBusy:YES];
    [self.settingsDeleteLocalDataButton setEnabled:NO];
    [self.statusField setStringValue:TGLoc(@"settings.localData.busy")];
    [self appendDetail:@"Local data reset requested. Stopping TDLib before deleting Telegraphica-owned local files."];
    [[TGLogger sharedLogger] log:@"Local data reset requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *resultSummary = [[TGLocalDataReset resetLocalDataWithClient:client timeout:5.0] retain];
        NSArray *errors = [[resultSummary objectForKey:TGLocalDataResetErrorMessagesKey] retain];
        NSString *offlineNote = [[resultSummary objectForKey:TGLocalDataResetOfflineNoteKey] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.client = nil;
            self.initialConnectStarted = NO;
            self.authClientRecoveryInFlight = NO;
            self.authClientRecoveryAttemptCount = 0;
            self.profileSummaryLoaded = NO;
            self.pendingLiveChatRefresh = NO;
            self.pendingLiveMessageRefresh = NO;
            [self.chatItems removeAllObjects];
            [self.messageItems removeAllObjects];
            [self.chatTableView deselectAll:nil];
            [self.chatTableView reloadData];
            [self.messageTableView reloadData];
            self.selectedChatID = nil;
            self.selectedChatTitle = nil;
            self.selectedChatTypeSummary = nil;
            self.selectedChatAvatarLocalPath = nil;
            self.selectedChatLastReadOutboxMessageID = nil;
            self.selectedMessageThreadID = nil;
            self.selectedMessageTopicKind = nil;
            self.chatsExhausted = NO;
            self.olderMessagesExhausted = NO;
            self.autoChatListLoadArmed = YES;
            self.autoChatListRefreshArmed = YES;
            self.autoOlderMessagesLoadArmed = YES;
            [self refreshSelectedChatHeaderDisplay];
            [self.composerDraftsByTargetKey removeAllObjects];
            [self clearReplyTarget];
            [self setComposerTextWithoutSavingDraft:nil];
            [self updateApplicationBadge];
            [self updateAuthControlsForState:@"closed"];
            [self.detailsView setString:@""];
            [self setControlsBusy:NO];
            [self.settingsDeleteLocalDataButton setEnabled:YES];

            NSString *message = nil;
            if ([errors count] > 0) {
                message = [NSString stringWithFormat:TGLoc(@"settings.localData.partial"), [errors componentsJoinedByString:@"; "]];
            } else {
                message = TGLoc(@"settings.localData.done");
            }
            [self.statusField setStringValue:message];

            NSAlert *doneAlert = [[[NSAlert alloc] init] autorelease];
            [doneAlert setMessageText:TGLoc(@"settings.localData.delete")];
            if ([offlineNote length] > 0) {
                [doneAlert setInformativeText:[NSString stringWithFormat:@"%@\n\n%@", message, offlineNote]];
            } else {
                [doneAlert setInformativeText:message];
            }
            [doneAlert addButtonWithTitle:@"OK"];
            [doneAlert runModal];

            [offlineNote release];
            [errors release];
            [resultSummary release];
            [client release];
        });
        [pool drain];
    });
}
