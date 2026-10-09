// A logout result belongs to its captured session, even if recovery replaces
// the client while TDLib is finishing the request.
- (void)applyLogoutSummary:(NSString *)logoutSummary errorMessage:(NSString *)logoutErrorMessage
                    owner:(TGTDLibClient *)client {
    if (self.client != client) { return; }
    if (logoutSummary) {
        [self resetNotificationDeliveryAfterLogout];
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
}
