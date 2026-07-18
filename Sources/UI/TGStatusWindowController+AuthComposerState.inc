- (void)startLiveUpdateTimerIfNeeded {
    if (self.liveUpdateTimer) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(pollLiveUpdates:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.liveUpdateTimer = timer;
}

- (void)stopLiveUpdateTimer {
    if (!self.liveUpdateTimer) {
        return;
    }

    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)prepareForApplicationTermination {
    [self stopLiveUpdateTimer];
    [self setControlsBusy:YES];
    [self.client shutdownWithTimeout:3.0];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (BOOL)isTerminalAuthorizationState:(NSString *)state {
    return [state isEqualToString:@"loggingOut"] ||
           [state isEqualToString:@"closing"] ||
           [state isEqualToString:@"closed"];
}

- (void)recoverTDLibClientAfterAuthorizationState:(NSString *)state
                                    expectedClient:(TGTDLibClient *)expectedClient {
    if (![self isTerminalAuthorizationState:state] || !expectedClient || self.client != expectedClient || self.authClientRecoveryInFlight) {
        return;
    }

    if (self.authClientRecoveryAttemptCount >= 3) {
        [self.statusField setStringValue:@"Sign-in restart required"];
        [self appendDetail:@"TDLib sign-in recovery paused after three attempts. Use Try Again to retry without deleting local configuration."];
        [self updateAuthControlsForState:state];
        [self setControlsBusy:NO];
        return;
    }

    self.authClientRecoveryInFlight = YES;
    self.authClientRecoveryAttemptCount++;
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Restarting Telegram connection..."];
    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state %@ requires a fresh client (attempt %lu of 3).",
                        state,
                        (unsigned long)self.authClientRecoveryAttemptCount]];

    TGTDLibClient *clientToRecover = [expectedClient retain];
    NSString *initialState = [state copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *observedState = initialState;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:6.0];

        while ([self isTerminalAuthorizationState:observedState] &&
               ![observedState isEqualToString:@"closed"] &&
               [[NSDate date] compare:deadline] == NSOrderedAscending) {
            NSError *stateError = nil;
            NSString *nextState = [clientToRecover authorizationStateSummaryWithTimeout:1.0 error:&stateError];
            if ([nextState length] > 0) {
                observedState = nextState;
            } else if ([[stateError localizedDescription] rangeOfString:@"shutting down" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                break;
            }
            if (![observedState isEqualToString:@"closed"]) {
                [NSThread sleepForTimeInterval:0.15];
            }
        }

        [clientToRecover shutdownWithTimeout:1.0];
        [NSThread sleepForTimeInterval:0.2 * self.authClientRecoveryAttemptCount];
        TGTDLibClient *replacementClient = [[[TGTDLibClient alloc] init] autorelease];
        NSString *lastObservedState = [observedState copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == clientToRecover) {
                self.client = replacementClient;
                self.initialConnectStarted = NO;
                self.authClientRecoveryInFlight = NO;
                [self appendDetail:[NSString stringWithFormat:@"TDLib client recreated after auth state %@.",
                                    [lastObservedState length] > 0 ? lastObservedState : initialState]];
                [self setControlsBusy:NO];
                [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
            } else {
                self.authClientRecoveryInFlight = NO;
            }
        });

        [lastObservedState release];
        [initialState release];
        [clientToRecover release];
        [pool drain];
    });
}

- (void)updateSendControls {
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    BOOL canTargetChat = [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget;
    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.attachPhotoButton setEnabled:canTargetChat];
    [self.stickerButton setEnabled:canTargetChat];
    [self.voiceRecordButton setEnabled:canTargetChat];
    [self.sendTextField setEnabled:canTargetChat];
    [self.sendMessageButton setEnabled:(canTargetChat && [trimmedText length] > 0)];
}

- (NSString *)composerDraftKeyForChatID:(NSNumber *)chatID
                        messageThreadID:(NSNumber *)messageThreadID
                         messageTopicKind:(NSString *)messageTopicKind {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    long long threadValue = ([messageThreadID respondsToSelector:@selector(longLongValue)] ? [messageThreadID longLongValue] : 0);
    NSString *topicKind = ([messageTopicKind length] > 0) ? messageTopicKind : @"main";
    return [NSString stringWithFormat:@"%lld|%lld|%@", [chatID longLongValue], threadValue, topicKind];
}

- (NSString *)currentComposerDraftKey {
    return [self composerDraftKeyForChatID:self.selectedChatID
                           messageThreadID:self.selectedMessageThreadID
                            messageTopicKind:self.selectedMessageTopicKind];
}

- (void)setComposerTextWithoutSavingDraft:(NSString *)text {
    BOOL previousSuppress = self.suppressComposerDraftSave;
    self.suppressComposerDraftSave = YES;
    [self.sendTextField setStringValue:(text ? text : @"")];
    self.suppressComposerDraftSave = previousSuppress;
    [self updateSendControls];
    [self layoutContentView];
}

- (void)saveComposerDraftForChatID:(NSNumber *)chatID
                   messageThreadID:(NSNumber *)messageThreadID
                    messageTopicKind:(NSString *)messageTopicKind {
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    if ([key length] == 0) {
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    if ([text length] > 0) {
        [self.composerDraftsByTargetKey setObject:text forKey:key];
    } else {
        [self.composerDraftsByTargetKey removeObjectForKey:key];
    }

    NSNumber *replyMessageID = nil;
    if ([self.replyTargetChatID respondsToSelector:@selector(longLongValue)] &&
        [chatID respondsToSelector:@selector(longLongValue)] &&
        [self.replyTargetChatID longLongValue] == [chatID longLongValue] &&
        (!self.replyTargetThreadID || !messageThreadID || [self.replyTargetThreadID longLongValue] == [messageThreadID longLongValue]) &&
        [self.replyTargetMessageItem.messageID respondsToSelector:@selector(longLongValue)]) {
        replyMessageID = self.replyTargetMessageItem.messageID;
    }
    [self scheduleComposerDraftSyncForChatID:chatID
                             messageThreadID:messageThreadID
                            messageTopicKind:messageTopicKind
                                        text:text
                            replyToMessageID:replyMessageID];
}

- (void)saveCurrentComposerDraft {
    if (self.suppressComposerDraftSave) {
        return;
    }
    [self saveComposerDraftForChatID:self.selectedChatID
                     messageThreadID:self.selectedMessageThreadID
                      messageTopicKind:self.selectedMessageTopicKind];
}

- (void)restoreComposerDraftForChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                       messageTopicKind:(NSString *)messageTopicKind {
    [self clearReplyTargetIfSelectionDiffersFromChatID:chatID
                                       messageThreadID:messageThreadID
                                      messageTopicKind:messageTopicKind];
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    NSString *draft = ([key length] > 0) ? [self.composerDraftsByTargetKey objectForKey:key] : nil;
    [self setComposerTextWithoutSavingDraft:draft];
}

- (void)removeComposerDraftForChatID:(NSNumber *)chatID
                     messageThreadID:(NSNumber *)messageThreadID
                      messageTopicKind:(NSString *)messageTopicKind {
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    if ([key length] > 0) {
        [self.composerDraftsByTargetKey removeObjectForKey:key];
    }
    [self scheduleComposerDraftSyncForChatID:chatID
                             messageThreadID:messageThreadID
                            messageTopicKind:messageTopicKind
                                        text:@""
                            replyToMessageID:nil];
}

- (void)scheduleComposerDraftSyncForChatID:(NSNumber *)chatID
                           messageThreadID:(NSNumber *)messageThreadID
                          messageTopicKind:(NSString *)messageTopicKind
                                      text:(NSString *)text
                          replyToMessageID:(NSNumber *)replyToMessageID {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    self.composerDraftSyncChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    self.composerDraftSyncThreadID = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) ? [NSNumber numberWithLongLong:[messageThreadID longLongValue]] : nil;
    self.composerDraftSyncTopicKind = messageTopicKind;
    self.composerDraftSyncText = ([text isKindOfClass:[NSString class]] ? text : @"");
    self.composerDraftSyncReplyMessageID = ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) ? [NSNumber numberWithLongLong:[replyToMessageID longLongValue]] : nil;

    [self.composerDraftSyncTimer invalidate];
    self.composerDraftSyncGeneration++;
    self.composerDraftSyncTimer = [NSTimer scheduledTimerWithTimeInterval:0.8
                                                                   target:self
                                                                 selector:@selector(composerDraftSyncTimerFired:)
                                                                 userInfo:nil
                                                                  repeats:NO];
}

- (void)composerDraftSyncTimerFired:(NSTimer *)timer {
    (void)timer;
    self.composerDraftSyncTimer = nil;
    if (![self.currentAuthState isEqualToString:@"ready"] ||
        ![self.composerDraftSyncChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSNumber *chatID = [self.composerDraftSyncChatID retain];
    NSNumber *threadID = [self.composerDraftSyncThreadID retain];
    NSString *topicKind = [self.composerDraftSyncTopicKind copy];
    NSString *text = [self.composerDraftSyncText copy];
    NSNumber *replyMessageID = [self.composerDraftSyncReplyMessageID retain];
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.composerDraftSyncGeneration;
    SEL draftSelector = @selector(setDraftMessageForChatID:messageThreadID:messageTopicKind:text:replyToMessageID:timeout:error:);

    if (![client isKindOfClass:[TGTDLibClient class]] || ![client respondsToSelector:draftSelector]) {
        [[TGLogger sharedLogger] log:@"Drafts: skipped remote draft sync because TDLib client is unavailable."];
        [chatID release];
        [threadID release];
        [topicKind release];
        [text release];
        [replyMessageID release];
        [client release];
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *draftError = nil;
        BOOL ok = NO;
        NSString *errorMessage = nil;
        NSString *exceptionMessage = nil;

        @try {
            ok = [client setDraftMessageForChatID:chatID
                                  messageThreadID:threadID
                                 messageTopicKind:topicKind
                                             text:text
                                 replyToMessageID:replyMessageID
                                          timeout:4.0
                                            error:&draftError];
            errorMessage = [[draftError localizedDescription] copy];
        } @catch (NSException *exception) {
            exceptionMessage = [[NSString alloc] initWithFormat:@"%@: %@",
                                [exception name] ? [exception name] : @"exception",
                                [exception reason] ? [exception reason] : @"unknown draft sync failure"];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL stale = (generation != self.composerDraftSyncGeneration || self.client != client);
            if (!stale) {
                if ([exceptionMessage length] > 0) {
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Drafts: remote draft sync skipped after exception: %@", exceptionMessage]];
                } else if (!ok && [errorMessage length] > 0) {
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Drafts: remote draft sync failed: %@", errorMessage]];
                }
            }
            [exceptionMessage release];
            [errorMessage release];
            [chatID release];
            [threadID release];
            [topicKind release];
            [text release];
            [replyMessageID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)handleComposerDraftUpdateSummary:(NSDictionary *)summary {
    id chatID = [summary objectForKey:@"chat_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    id threadID = [summary objectForKey:@"message_thread_id"];
    NSNumber *safeThreadID = ([threadID respondsToSelector:@selector(longLongValue)] && [threadID longLongValue] > 0) ? [NSNumber numberWithLongLong:[threadID longLongValue]] : nil;
    NSString *key = [self composerDraftKeyForChatID:[NSNumber numberWithLongLong:[chatID longLongValue]]
                                    messageThreadID:safeThreadID
                                    messageTopicKind:nil];
    if ([key length] == 0) {
        return;
    }

    BOOL hasDraft = [[summary objectForKey:@"has_draft"] boolValue];
    NSString *text = [summary objectForKey:@"text"];
    if (hasDraft && [text length] > 0) {
        [self.composerDraftsByTargetKey setObject:text forKey:key];
    } else {
        [self.composerDraftsByTargetKey removeObjectForKey:key];
        text = @"";
    }

    NSString *currentKey = [self currentComposerDraftKey];
    if (![currentKey isEqualToString:key]) {
        return;
    }

    NSString *currentText = [self.sendTextField stringValue];
    BOOL composerEditing = ([self.sendTextField currentEditor] != nil);
    if (!composerEditing || [currentText length] == 0 || [currentText isEqualToString:text]) {
        [self setComposerTextWithoutSavingDraft:text];
    }
}

- (BOOL)isComposerActivelyEditing {
    NSText *editor = [self.sendTextField currentEditor];
    return (editor != nil && [[self window] firstResponder] == editor);
}

- (void)refocusComposerIfPossible {
    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        (self.showingForumTopicList && self.selectedMessageThreadID == nil) ||
        [self.sendTextField isHidden]) {
        return;
    }
    [self updateSendControls];
    [self.sendTextField setEnabled:YES];

    NSText *existingEditor = [self.sendTextField currentEditor];
    if (existingEditor != nil && [[self window] firstResponder] == existingEditor) {
        return;
    }

    NSRange previousSelection = NSMakeRange(NSNotFound, 0);
    if (existingEditor != nil) {
        previousSelection = [existingEditor selectedRange];
    }

    [[self window] makeFirstResponder:self.sendTextField];

    NSText *editor = [self.sendTextField currentEditor];
    if (editor != nil) {
        NSUInteger textLength = [[self.sendTextField stringValue] length];
        if (previousSelection.location != NSNotFound &&
            NSMaxRange(previousSelection) <= textLength) {
            [editor setSelectedRange:previousSelection];
        } else {
            [editor setSelectedRange:NSMakeRange(textLength, 0)];
        }
    }
}

- (void)consumePendingComposerRefocus:(id)sender {
    (void)sender;
    if (!self.composerRefocusPending) {
        return;
    }
    if (self.controlsBusy || self.backgroundMessageRefreshInFlight) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(consumePendingComposerRefocus:)
                                                   object:nil];
        [self performSelector:@selector(consumePendingComposerRefocus:)
                    withObject:nil
                    afterDelay:0.12];
        return;
    }
    self.composerRefocusPending = NO;
    [self refocusComposerIfPossible];
}

- (void)requestComposerRefocus {
    if ([self isComposerActivelyEditing]) {
        self.composerRefocusPending = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(consumePendingComposerRefocus:)
                                                   object:nil];
        return;
    }
    self.composerRefocusPending = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(consumePendingComposerRefocus:)
                                               object:nil];
    [self performSelector:@selector(consumePendingComposerRefocus:)
                withObject:nil
                afterDelay:0.05];
}

- (BOOL)canLoadMoreChats {
    return (!self.controlsBusy &&
            [self.currentAuthState isEqualToString:@"ready"] &&
            !self.showingForumTopicList &&
            [self.chatItems count] > 0 &&
            !self.chatsExhausted &&
            [self.chatItems count] < TGStatusChatPreviewMaximumLimit);
}

- (void)updateOutgoingReadStateForVisibleMessages {
    long long lastReadOutboxMessageID = 0;
    if ([self.selectedChatLastReadOutboxMessageID respondsToSelector:@selector(longLongValue)]) {
        lastReadOutboxMessageID = [self.selectedChatLastReadOutboxMessageID longLongValue];
    }

    NSUInteger index = 0;
    BOOL changed = NO;
    for (index = 0; index < [self.messageItems count]; index++) {
        id candidate = [self.messageItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        BOOL read = NO;
        if ([item outgoing] && ![item sending] && [[item messageID] respondsToSelector:@selector(longLongValue)] && lastReadOutboxMessageID > 0) {
            read = ([[item messageID] longLongValue] <= lastReadOutboxMessageID);
        }
        if ([item outgoingRead] != read) {
            [item setOutgoingRead:read];
            changed = YES;
        }
    }
    if (changed) {
        [self.messageTableView reloadData];
    }
}

- (void)setLoginErrorMessage:(NSString *)message {
    self.loginErrorLocalizationKey = nil;
    BOOL hasMessage = ([message length] > 0);
    self.loginErrorVisible = hasMessage;
    [self.authStateField setStringValue:(hasMessage ? message : @"")];
    if (hasMessage) {
        [self.authStateField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    } else {
        [self applyMutedLabelStyle:self.authStateField];
    }
    if ([self.authTextFieldBackgroundView isKindOfClass:[TGAuthInputBackgroundView class]]) {
        [(TGAuthInputBackgroundView *)self.authTextFieldBackgroundView setErrorState:hasMessage];
    }
    if ([self.authSecondaryTextFieldBackgroundView isKindOfClass:[TGAuthInputBackgroundView class]]) {
        [(TGAuthInputBackgroundView *)self.authSecondaryTextFieldBackgroundView setErrorState:hasMessage];
    }
}

- (void)setLoginErrorWithLocalizationKey:(NSString *)key {
    [self setLoginErrorMessage:([key length] > 0 ? TGLoc(key) : nil)];
    self.loginErrorLocalizationKey = key;
}

- (NSString *)loginErrorLocalizationKeyForAuthState:(NSString *)state {
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        return @"login.error.phone";
    }
    if ([state isEqualToString:@"waitCode"]) {
        return @"login.error.code";
    }
    if ([state isEqualToString:@"waitPassword"]) {
        return @"login.error.password";
    }
    return @"login.error.general";
}

- (void)focusLoginInputIfNeeded {
    if (self.controlsBusy || [self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    NSTextField *inputField = [self.currentAuthState isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    if (!inputField || [inputField isHidden] || ![inputField isEnabled]) {
        return;
    }
    [[self window] makeFirstResponder:inputField];
}

- (void)scheduleLoginInputFocus {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(focusLoginInputIfNeeded) object:nil];
    [self performSelector:@selector(focusLoginInputIfNeeded) withObject:nil afterDelay:0.05];
}

- (void)updateAuthControlsForState:(NSString *)state {
    NSString *previousState = [self.currentAuthState copy];
    self.currentAuthState = state;
    BOOL authStateChanged = (!previousState || ![previousState isEqualToString:state]);
    BOOL authInputsEnabled = !(self.controlsBusy || self.authSubmissionInFlight);
    if (authStateChanged) {
        [self setLoginErrorMessage:nil];
        [self.authTextField setStringValue:@""];
        [self.authSecureField setStringValue:@""];
    }
    [self.loadChatsButton setEnabled:NO];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.attachPhotoButton setEnabled:NO];
    [self.stickerButton setEnabled:NO];
    [self.voiceRecordButton setEnabled:NO];
    [self.sendMessageButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        [self updateApplicationBadge];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.selectedChatTypeSummary = nil;
        self.selectedChatAvatarLocalPath = nil;
        self.selectedChatLastReadOutboxMessageID = nil;
        self.selectedMessageThreadID = nil;
        self.selectedMessageTopicKind = nil;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.autoChatListLoadArmed = YES;
        self.autoChatListRefreshArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self refreshSelectedChatHeaderDisplay];
        [self setComposerTextWithoutSavingDraft:nil];
        self.activeSection = TGSectionChats;
    }

    if (![state isEqualToString:@"ready"]) {
        self.accountUnreadCount = 0;
        self.hasAccountUnreadCount = NO;
        [self.localMuteUnreadCountsByChatID removeAllObjects];
        [self updateApplicationBadge];
        self.activeSection = TGSectionChats;
        self.drawerOpen = NO;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        self.selectedChatFilterID = nil;
        self.chatFilterInfos = [NSArray array];
        self.chatFilterRefreshRetryCount = 0;
        self.chatFilterRefreshPending = NO;
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(reloadChatFiltersIfReady)
                                                   object:nil];
        self.profileSummaryLoaded = NO;
        [self clearProfileDisplayCache];
        [self.client invalidateMainChatListExhaustion];
        self.pendingLiveChatRefresh = NO;
        self.pendingLiveMessageRefresh = NO;
    } else if (![previousState isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        self.chatFilterRefreshRetryCount = 0;
        if ([self.chatItems count] == 0) {
            self.pendingLiveChatRefresh = YES;
            [self handlePendingLiveRefreshesIfPossible];
        }
    }

    if ([state isEqualToString:@"waitApiCredentials"]) {
        [self.statusField setStringValue:TGLoc(@"login.config.title")];
        [self refreshLoginLocalizedText];
        [self.authStateField setStringValue:TGLoc(@"login.config.missing")];
        [self.authStateField setHidden:NO];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:YES];
        [self.authSecondaryLabel setHidden:YES];
        [self.authSecondaryTextFieldBackgroundView setHidden:YES];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.authButton setEnabled:NO];
        [self.authButton setHidden:YES];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([self isTerminalAuthorizationState:state]) {
        [self.statusField setStringValue:@"Restarting Telegram connection..."];
        [self.loginTitleField setStringValue:TGLoc(@"login.connecting.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.recovering.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.status")];
        [self.authStateField setStringValue:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:YES];
        [self.authSecondaryLabel setHidden:YES];
        [self.authSecondaryTextFieldBackgroundView setHidden:YES];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:TGLoc(@"login.retry")];
        [self.authButton setEnabled:(!self.controlsBusy && !self.authClientRecoveryInFlight && self.authClientRecoveryAttemptCount >= 3)];
        [self.authButton setHidden:(self.authClientRecoveryAttemptCount < 3)];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.statusField setStringValue:@"Sign in required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.phone.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.phone.label")];
        [[self.authTextField cell] setPlaceholderString:@"+123456789"];
        [[self.authSecureField cell] setPlaceholderString:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:authInputsEnabled];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.statusField setStringValue:@"Login code required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.code.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.code.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.code.label")];
        [[self.authTextField cell] setPlaceholderString:@"12345"];
        [[self.authSecureField cell] setPlaceholderString:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:authInputsEnabled];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.statusField setStringValue:@"Password required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.password.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.password.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.password.label")];
        [[self.authTextField cell] setPlaceholderString:@""];
        [[self.authSecureField cell] setPlaceholderString:TGLoc(@"login.password.label")];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:authInputsEnabled];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    [self.authLabel setStringValue:TGLoc(@"login.status")];
    if ([state isEqualToString:@"ready"]) {
        [self.statusField setStringValue:@"Connected"];
        [self.authStateField setStringValue:@""];
    } else if ([state length] > 0) {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@""];
    } else {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@""];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authSecondaryLabel setHidden:YES];
    [self.authSecondaryTextFieldBackgroundView setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [[self.authTextField cell] setPlaceholderString:@""];
    [[self.authSecureField cell] setPlaceholderString:@""];
    [self.authButton setTitle:TGLoc(@"login.send")];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.chatSearchButton setEnabled:[state isEqualToString:@"ready"]];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.conversationSearchButton setEnabled:([state isEqualToString:@"ready"] && hasMessageTarget)];
    [self.logoutButton setEnabled:([state isEqualToString:@"ready"] && !self.controlsBusy)];
    [self updateSendControls];
    [self refreshProfileDisplay];
    [self updateVisibleSection];
    if ([state isEqualToString:@"ready"] && !self.profileSummaryLoaded && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }

    [previousState release];
}

- (void)setControlsBusy:(BOOL)busy {
    _controlsBusy = busy;
    if (busy) {
        [self.busySpinner setHidden:NO];
        [self.busySpinner startAnimation:self];
    } else {
        [self.busySpinner stopAnimation:self];
        [self.busySpinner setHidden:YES];
    }
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        [[self.loginLanguageButtons objectAtIndex:loginLanguageIndex] setEnabled:YES];
    }
    [self.checkButton setEnabled:!busy];
    [self.logsCheckButton setEnabled:!busy];
    [self.logoutButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self updateNavigationButtonsForSection:(self.activeSection ? self.activeSection : TGSectionChats) enabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.chatSearchButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.conversationSearchButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.attachPhotoButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.stickerButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.voiceRecordButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.sendTextField setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.sendMessageButton setEnabled:NO];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMoreChatsButton setEnabled:NO];
        [self.chatSearchButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
        [self.loadOlderMessagesButton setEnabled:NO];
        [self.conversationSearchButton setEnabled:NO];
        [self.logoutButton setEnabled:NO];
        [self.chatTableView setEnabled:NO];
        [self.messageTableView setEnabled:NO];
        [self.attachPhotoButton setEnabled:NO];
        [self.stickerButton setEnabled:NO];
        [self.voiceRecordButton setEnabled:NO];
        [self.sendTextField setEnabled:NO];
        [self.sendMessageButton setEnabled:NO];
    } else {
        [self.chatTableView setEnabled:YES];
        [self.messageTableView setEnabled:YES];
        [self updateAuthControlsForState:self.currentAuthState];
        [self handlePendingLiveRefreshesIfPossible];
    }
    [self updateVisibleSection];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.searchTextField) {
        [self scheduleSearchRequest];
        return;
    } else if ([notification object] == self.chatSearchWindowTextField) {
        [self updateChatSearchWindowResults];
        return;
    } else if ([notification object] == self.sendTextField) {
        [self saveCurrentComposerDraft];
        [self updateSendControls];
        [self layoutContentView];
    } else if ([notification object] == self.authTextField || [notification object] == self.authSecureField) {
        if (self.loginErrorVisible) {
            [self setLoginErrorMessage:nil];
            [self updateVisibleSection];
        }
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (control == self.searchTextField &&
        [self control:control textView:textView doSearchCommandBySelector:commandSelector]) {
        return YES;
    }
    if (control == self.chatSearchWindowTextField &&
        [self control:control textView:textView doChatSearchWindowCommandBySelector:commandSelector]) {
        return YES;
    }
    if (control == self.sendTextField && commandSelector == @selector(paste:)) {
        if ([self handlePasteAttachmentFromPasteboard:[NSPasteboard generalPasteboard]]) {
            return YES;
        }
        return NO;
    }
    if (control == self.sendTextField &&
        (commandSelector == @selector(insertNewline:) ||
         commandSelector == @selector(insertLineBreak:) ||
         commandSelector == @selector(insertNewlineIgnoringFieldEditor:))) {
        NSUInteger modifierFlags = [[[NSApplication sharedApplication] currentEvent] modifierFlags];
        BOOL wantsLineBreak = (commandSelector == @selector(insertLineBreak:) ||
                               (modifierFlags & NSShiftKeyMask) != 0);
        if (wantsLineBreak) {
            [textView insertNewline:nil];
            [self layoutContentView];
            [self updateSendControls];
            return YES;
        }
        [self sendMessage:control];
        return YES;
    }
    if ((control == self.authTextField || control == self.authSecureField) && commandSelector == @selector(insertNewline:)) {
        [self submitAuthInput:control];
        return YES;
    }
    return NO;
}

- (void)appendDetail:(NSString *)detail {
    if (![detail isKindOfClass:[NSString class]] || [detail length] == 0) {
        return;
    }
    NSString *current = [self.detailsView string];
    NSString *section = TGLogSectionForDetail(detail);
    NSMutableString *addition = [NSMutableString string];
    if (![self.lastLogSection isEqualToString:section]) {
        [addition appendFormat:@"%@%@\n", ([current length] > 0 ? @"\n" : @""), section];
        self.lastLogSection = section;
    }
    [addition appendFormat:@"%@  %@\n", TGLogTimestampString(), detail];
    [self.detailsView setString:[current stringByAppendingString:addition]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
    if (self.logsWindowDetailsView) {
        [self.logsWindowDetailsView setString:[self.detailsView string]];
        NSRange logsEndRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
        [self.logsWindowDetailsView scrollRangeToVisible:logsEndRange];
    }
}

- (void)setOfflineModeActive:(BOOL)active reason:(NSString *)reason {
    if (active) {
        [self.statusField setStringValue:@"Offline"];
        if (!self.offlineModeActive && [reason length] > 0) {
            [self appendDetail:reason];
        }
    } else if (self.offlineModeActive) {
        [self appendDetail:@"Network connection restored."];
    }
    self.offlineModeActive = active;
}
