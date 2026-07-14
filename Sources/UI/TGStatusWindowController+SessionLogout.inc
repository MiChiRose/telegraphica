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

