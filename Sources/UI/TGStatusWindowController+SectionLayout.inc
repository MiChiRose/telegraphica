- (void)showView:(NSView *)view visible:(BOOL)visible {
    if (!view) {
        return;
    }
    [view setHidden:!visible];
    [view setAlphaValue:1.0];
}

- (void)showMessageDropOverlay:(BOOL)visible {
    self.messageDropOverlayVisible = visible;
    BOOL showChats = ([self.currentAuthState isEqualToString:@"ready"] && [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats]);
    [self showView:self.messageDropOverlayView visible:(visible && showChats)];
    [self.messageDropOverlayView setNeedsDisplay:YES];
}

- (void)messageTableViewDragDidEnd:(id)sender {
    (void)sender;
    [self showMessageDropOverlay:NO];
}

- (void)messageTableViewPaste:(id)sender {
    (void)sender;
    BOOL handled = [self handlePasteAttachmentFromPasteboard:[NSPasteboard generalPasteboard]];
    if (!handled) {
        [[TGLogger sharedLogger] log:@"Pasteboard: message table paste did not contain a supported image/file attachment."];
    }
    if ([self.sendTextField isEnabled]) {
        [[self window] makeFirstResponder:self.sendTextField];
    }
}

- (void)messageTableViewCopy:(id)sender {
    (void)sender;
    NSInteger row = [self.messageTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        NSBeep();
        return;
    }
    id candidate = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![candidate isKindOfClass:[TGMessageItem class]]) {
        NSBeep();
        return;
    }
    TGMessageItem *item = (TGMessageItem *)candidate;
    NSString *text = TGDisplayTextForMessageItem(item);
    if ([text length] == 0) {
        text = [item preview];
    }
    if ([text length] == 0) {
        NSBeep();
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteboard setString:text forType:NSStringPboardType];
    [[TGLogger sharedLogger] log:@"Pasteboard: copied selected message text."];
}

- (void)updateVisibleSection {
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSString *section = self.activeSection ? self.activeSection : TGSectionChats;
    if (!ready && ![section isEqualToString:TGSectionChats]) {
        section = TGSectionChats;
        self.activeSection = TGSectionChats;
    }
    BOOL showLogin = !ready;
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);

    [self updateNavigationButtonsForSection:section enabled:!self.controlsBusy];
    [self showView:self.topPanelView visible:(ready && !drawerHidden && self.drawerOpen)];
    [self showView:self.accountBadgeView visible:(ready && !drawerHidden && self.drawerOpen)];
    [self showView:self.bottomNavigationView visible:ready];

    [self showView:self.loginPanelView visible:showLogin];
    [self showView:self.loginIconView visible:showLogin];
    [self showView:self.loginBrandField visible:showLogin];
    [self showView:self.loginTitleField visible:showLogin];
    [self showView:self.loginHintField visible:showLogin];

    [self showView:self.authLabel visible:showLogin];
    [self showView:self.authStateField visible:(showLogin && self.loginErrorVisible)];
    [self showView:self.authTextFieldBackgroundView visible:(showLogin && [self isAuthInputState:self.currentAuthState])];
    [self showView:self.authTextField visible:(showLogin && ([self.currentAuthState isEqualToString:@"waitPhoneNumber"] || [self.currentAuthState isEqualToString:@"waitCode"]))];
    [self showView:self.authSecondaryLabel visible:NO];
    [self showView:self.authSecondaryTextFieldBackgroundView visible:NO];
    [self showView:self.authSecureField visible:(showLogin && [self.currentAuthState isEqualToString:@"waitPassword"])];
    [self showView:self.authButton visible:(showLogin && [self isAuthInputState:self.currentAuthState])];
    [self showView:self.busySpinner visible:(showLogin && self.controlsBusy)];
    [self showView:self.loginLogsButton visible:showLogin];
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        [self showView:[self.loginLanguageButtons objectAtIndex:loginLanguageIndex] visible:showLogin];
    }

    BOOL showChats = (ready && [section isEqualToString:TGSectionChats]);
    [self showView:self.drawerButton visible:(ready && !drawerHidden)];
    [self showView:self.sidebarPanelView visible:showChats];
    [self showView:self.conversationPanelView visible:showChats];
    [self showView:self.chatsLabel visible:showChats];
    [self showView:self.topicBackButton visible:(showChats && self.showingForumTopicList)];
    [self showView:self.loadChatsButton visible:showChats];
    [self showView:self.loadMoreChatsButton visible:NO];
    [self showView:self.chatSearchButton visible:showChats];
    [self showView:self.chatScrollSurfaceView visible:showChats];
    [self showView:self.chatScrollView visible:showChats];
    [self showView:self.messagesLabel visible:NO];
    [self showView:self.loadMessagesButton visible:showChats];
    [self showView:self.loadOlderMessagesButton visible:NO];
    [self showView:self.conversationSearchButton visible:showChats];
    [self showView:self.mediaCenterButton visible:showChats];
    BOOL canUseChatHeaderActions = (showChats &&
                                    [self.currentAuthState isEqualToString:@"ready"] &&
                                    self.selectedChatID != nil);
    [self.mediaCenterButton setEnabled:canUseChatHeaderActions];
    BOOL showCommentThreadBack = (showChats &&
                                  [self.selectedMessageTopicKind isEqualToString:@"thread"] &&
                                  [self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)]);
    [self showView:self.commentThreadBackButton visible:showCommentThreadBack];
    [self showView:self.selectedChatField visible:showChats];
    [self showView:self.typingIndicatorField visible:(showChats && [[self.typingIndicatorField stringValue] length] > 0)];
    BOOL showSelectedChatProfile = (showChats && self.selectedChatID != nil);
    [self showView:self.selectedChatAvatarView visible:showSelectedChatProfile];
    [self showView:self.selectedChatProfileButton visible:showSelectedChatProfile];
    [self showView:self.messageScrollSurfaceView visible:showChats];
    [self showView:self.messageScrollView visible:showChats];
    [self showView:self.messageLoadingSpinner visible:(showChats && self.messageLoadingIndicatorVisible)];
    [self showView:self.messageJumpToNewestButton visible:showChats];
    BOOL canJumpToNewest = (showChats &&
                            [self.currentAuthState isEqualToString:@"ready"] &&
                            self.selectedChatID != nil);
    [self.messageJumpToNewestButton setEnabled:canJumpToNewest];
    BOOL showSearchPanel = (showChats && self.searchPanelVisible);
    [self showView:self.searchPanelView visible:showSearchPanel];
    [self showView:self.searchTextField visible:showSearchPanel];
    [self showView:self.searchScopePopUpButton visible:showSearchPanel];
    [self showView:self.searchFilterPopUpButton visible:showSearchPanel];
    [self showView:self.searchCloseButton visible:showSearchPanel];
    [self showView:self.searchStatusField visible:showSearchPanel];
    [self showView:self.searchResultsScrollView visible:showSearchPanel];
    [self showView:self.searchResultsTableView visible:showSearchPanel];
    BOOL showPinnedPanel = (showChats && !self.searchPanelVisible && self.pinnedMessageItem != nil);
    [self showView:self.pinnedMessagePanelView visible:showPinnedPanel];
    [self showView:self.pinnedMessageStripeField visible:showPinnedPanel];
    [self showView:self.pinnedMessageLabelField visible:showPinnedPanel];
    [self showView:self.pinnedMessageTextField visible:showPinnedPanel];
    [self showView:self.pinnedMessageButton visible:showPinnedPanel];
    BOOL showReplyPanel = (showChats && self.replyTargetMessageItem != nil);
    [self showView:self.replyPanelView visible:showReplyPanel];
    [self showView:self.replyPanelTitleField visible:showReplyPanel];
    [self showView:self.replyPanelTextField visible:showReplyPanel];
    [self showView:self.replyPanelCancelButton visible:showReplyPanel];
    if (showChats) {
        [self scheduleInlineMediaPlaybackRefresh];
    } else {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    }
    if (!showChats) {
        self.messageDropOverlayVisible = NO;
    }
    [self showView:self.messageDropOverlayView visible:(showChats && self.messageDropOverlayVisible)];
    [self showView:self.sendLabel visible:NO];
    [self showView:self.attachPhotoButton visible:showChats];
    [self showView:self.stickerButton visible:showChats];
    [self showView:self.voiceRecordButton visible:showChats];
    [self showView:self.voiceRecordingIndicatorField visible:NO];
    [self showView:self.sendTextFieldBackgroundView visible:showChats];
    [self showView:self.sendTextField visible:showChats];
    [self showView:self.sendMessageButton visible:showChats];

    BOOL showProfile = (ready && [section isEqualToString:TGSectionProfile]);
    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    BOOL showProfileDetails = (showProfile && profileDetailRows > 0);
    [self showView:self.profilePanelView visible:showProfile];
    [self showView:self.profileScrollView visible:showProfile];
    [self showView:self.profileSummaryCardView visible:showProfile];
    [self showView:self.profileInfoCardView visible:(showProfile && profileHasBio)];
    [self showView:self.profileDetailsCardView visible:showProfileDetails];
    [self showView:self.profileActionsCardView visible:showProfile];
    [self showView:self.profileAvatarView visible:showProfile];
    [self showView:self.profileTitleField visible:showProfile];
    [self showView:self.profileNameField visible:(showProfile && [[self.profileNameField stringValue] length] > 0)];
    [self showView:self.profileUsernameField visible:(showProfile && [[self.profileUsernameField stringValue] length] > 0)];
    [self showView:self.profileIDField visible:NO];
    [self showView:self.profileStateField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAboutSectionField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAccountSectionField visible:showProfileDetails];
    [self showView:self.profileUsernameRowTitleField visible:(showProfile && profileHasUsername)];
    [self showView:self.profileUsernameRowValueField visible:(showProfile && profileHasUsername)];
    [self showView:self.profilePhoneRowTitleField visible:(showProfile && profileHasPhone)];
    [self showView:self.profilePhoneRowValueField visible:(showProfile && profileHasPhone)];
    [self showView:self.profileIDRowTitleField visible:(showProfile && profileHasID)];
    [self showView:self.profileIDRowValueField visible:(showProfile && profileHasID)];
    [self showView:self.profileDetailsSeparatorOne visible:(showProfileDetails && profileDetailRows > 1)];
    [self showView:self.profileDetailsSeparatorTwo visible:(showProfileDetails && profileDetailRows > 2)];
    [self showView:self.profileRefreshButton visible:NO];
    [self showView:self.logoutButton visible:showProfile];

    BOOL showSettings = (ready && [section isEqualToString:TGSectionSettings]);
    [self showView:self.settingsPanelView visible:showSettings];
    [self showView:self.settingsScrollView visible:showSettings];
    [self showView:self.settingsAccountCardView visible:showSettings];
    [self showView:self.settingsDrawerCardView visible:showSettings];
    [self showView:self.settingsResourceCardView visible:showSettings];
    [self showView:self.settingsThemeCardView visible:showSettings];
    [self showView:self.settingsFilesCardView visible:showSettings];
    [self showView:self.settingsHelpCardView visible:showSettings];
    [self showView:self.settingsSessionCardView visible:showSettings];
    [self showView:self.settingsTitleField visible:showSettings];
    [self showView:self.settingsStateField visible:showSettings];
    [self showView:self.settingsDrawerSectionField visible:showSettings];
    [self showView:self.settingsResourceSectionField visible:showSettings];
    [self showView:self.settingsLibraryField visible:showSettings];
    [self showView:self.settingsFilesSectionField visible:showSettings];
    [self showView:self.settingsHelpSectionField visible:showSettings];
    [self showView:self.settingsStorageField visible:showSettings];
    [self showView:self.settingsThemeCategoryLabel visible:showSettings];
    [self showView:self.themeCategoryPopUpButton visible:showSettings];
    [self showView:self.settingsThemeLabel visible:showSettings];
    [self showView:self.themePopUpButton visible:showSettings];
    [self showView:self.settingsNotificationsEnabledButton visible:showSettings];
    [self showView:self.settingsNotificationSoundButton visible:showSettings];
    [self showView:self.settingsNotificationBadgeButton visible:showSettings];
    [self showView:self.settingsNotificationPreviewButton visible:showSettings];
    [self showView:self.settingsNotificationsWhenActiveButton visible:showSettings];
    [self showView:self.settingsDrawerHiddenButton visible:showSettings];
    [self showView:self.settingsTypingIndicatorsButton visible:showSettings];
    [self showView:self.settingsEconomyModeButton visible:showSettings];
    [self showView:self.settingsAutoDownloadPhotosButton visible:showSettings];
    [self showView:self.settingsAutoDownloadVideosButton visible:showSettings];
    [self showView:self.settingsAutoDownloadDocumentsButton visible:showSettings];
    [self showView:self.settingsAutoplayAnimatedStickersButton visible:showSettings];
    [self showView:self.settingsStopInactiveAnimationsButton visible:showSettings];
    [self showView:self.settingsMaxAutoDownloadLabel visible:showSettings];
    [self showView:self.settingsMaxAutoDownloadPopUpButton visible:showSettings];
    [self showView:self.settingsMaxAnimationsLabel visible:showSettings];
    [self showView:self.settingsMaxAnimationsPopUpButton visible:showSettings];
    [self showView:self.settingsMediaCacheLimitLabel visible:showSettings];
    [self showView:self.settingsMediaCacheLimitPopUpButton visible:showSettings];
    [self showView:self.settingsResourceHintField visible:showSettings];
    [self showView:self.settingsLanguageLabel visible:showSettings];
    [self showView:self.settingsLanguagePopUpButton visible:showSettings];
    [self showView:self.settingsMessagesAsBlocksButton visible:showSettings];
    [self showView:self.settingsChatTextSizeSectionField visible:showSettings];
    [self showView:self.settingsChatTextSizeSlider visible:showSettings];
    [self showView:self.settingsChatTextSizeValueField visible:showSettings];
    [self showView:self.settingsActiveSessionsDetailField visible:showSettings];
    [self showView:self.settingsActiveSessionsButton visible:showSettings];
    [self showView:self.settingsDownloadFolderHelpField visible:showSettings];
    [self showView:self.settingsDownloadFolderButton visible:showSettings];
    [self showView:self.settingsStorageUsageButton visible:showSettings];
    [self showView:self.settingsDeleteLocalDataButton visible:showSettings];
    [self showView:self.settingsCheckUpdatesButton visible:showSettings];
    [self showView:self.settingsUpdateDotView visible:(showSettings && self.updateAvailable)];
    [self showView:self.settingsAppearanceButton visible:NO];
    [self showView:self.settingsLogsButton visible:showSettings];
    [self showView:self.settingsAboutButton visible:showSettings];

    [self showView:self.aboutPanelView visible:NO];
    [self showView:self.aboutCardView visible:NO];
    [self showView:self.aboutIconView visible:NO];
    [self showView:self.aboutTitleField visible:NO];
    [self showView:self.aboutVersionField visible:NO];
    [self showView:self.aboutCopyrightField visible:NO];
    [self showView:self.aboutLinkField visible:NO];

    [self showView:self.diagnosticsPanelView visible:NO];
    [self showView:self.logsCardView visible:NO];
    [self showView:self.diagnosticsLabel visible:NO];
    [self showView:self.detailsScrollView visible:NO];
    [self showView:self.checkButton visible:NO];
    [self refreshUpdateAvailabilityBadge];
}

- (CGFloat)composerInputHeightForWidth:(CGFloat)width {
    if (width < 80.0) {
        width = 80.0;
    }

    NSString *text = [self.sendTextField stringValue];
    if ([text length] == 0) {
        return TGComposerMinimumInputHeight();
    }

    NSFont *font = [self.sendTextField font];
    if (!font) {
        font = [NSFont systemFontOfSize:13.0];
    }

    NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                paragraphStyle, NSParagraphStyleAttributeName,
                                nil];
    NSRect measuredRect = [text boundingRectWithSize:NSMakeSize(width, 12000.0)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes];
    CGFloat measuredHeight = ceil(NSHeight(measuredRect)) + 4.0;

    NSUInteger explicitLines = 1;
    NSUInteger index = 0;
    for (index = 0; index < [text length]; index++) {
        if ([text characterAtIndex:index] == '\n') {
            explicitLines++;
        }
    }
    CGFloat explicitHeight = 4.0 + ((CGFloat)explicitLines * TGComposerLineHeight());
    CGFloat height = MAX(measuredHeight, explicitHeight);
    if (height < TGComposerMinimumInputHeight()) {
        height = TGComposerMinimumInputHeight();
    }
    if (height > TGComposerMaximumInputHeight()) {
        height = TGComposerMaximumInputHeight();
    }
    return height;
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 10.0;
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);
    BOOL drawerVisible = (!drawerHidden && self.drawerOpen);
    BOOL drawerConsumesLayout = drawerVisible;
    CGFloat railGutter = (!drawerHidden && self.drawerOpen) ? 10.0 : 0.0;
    CGFloat panelGutter = 10.0;
    CGFloat railWidth = (!drawerHidden && self.drawerOpen) ? 108.0 : 0.0;
    CGFloat railX = margin;
    CGFloat railY = margin;
    CGFloat railHeight = height - (margin * 2.0);
    CGFloat railTop = railY + railHeight;
    CGFloat mainX = drawerConsumesLayout ? (railX + railWidth + railGutter) : margin;
    CGFloat mainY = margin;
    CGFloat mainWidth = width - mainX - margin;
    CGFloat mainHeight = railHeight;
    CGFloat mainTop = mainY + mainHeight;
    CGFloat sidebarWidth = 292.0;

    if (railHeight < 520.0) {
        railHeight = 520.0;
        railTop = railY + railHeight;
        mainHeight = railHeight;
        mainTop = mainY + mainHeight;
    }
    if (width < 900.0) {
        sidebarWidth = 248.0;
    } else if (width < 1040.0) {
        sidebarWidth = 272.0;
    }

    CGFloat conversationX = mainX + sidebarWidth + panelGutter;
    CGFloat conversationWidth = width - conversationX - margin;
    if (conversationWidth < 320.0) {
        CGFloat reduction = 320.0 - conversationWidth;
        sidebarWidth -= reduction;
        if (sidebarWidth < 220.0) {
            sidebarWidth = 220.0;
        }
        conversationX = mainX + sidebarWidth + panelGutter;
        conversationWidth = width - conversationX - margin;
    }
    if (mainWidth < 420.0) {
        mainWidth = 420.0;
    }

    [self.topPanelView setFrame:NSMakeRect(railX, railY, railWidth, railHeight)];
    [self.sidebarPanelView setFrame:NSMakeRect(mainX, mainY, sidebarWidth, mainHeight)];
    [self.conversationPanelView setFrame:NSMakeRect(conversationX, mainY, conversationWidth, mainHeight)];
    [self.diagnosticsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.profilePanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.settingsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.aboutPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    if (drawerVisible) {
        [contentView addSubview:self.topPanelView positioned:NSWindowAbove relativeTo:nil];
    }

    CGFloat accountBadgeWidth = railWidth - 48.0;
    if (accountBadgeWidth < 0.0) {
        accountBadgeWidth = 0.0;
    }
    [self.accountBadgeView setFrame:NSMakeRect(railX + 24.0, railTop - 124.0, accountBadgeWidth, 60.0)];
    if (drawerVisible) {
        [contentView addSubview:self.accountBadgeView positioned:NSWindowAbove relativeTo:nil];
    }
    [self.titleField setFont:[NSFont boldSystemFontOfSize:13.0]];
    [[self.titleField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.titleField setFrame:NSMakeRect(railX + 9.0, railTop - 48.0, railWidth - 18.0, 18.0)];
    [self.statusField setFont:[NSFont systemFontOfSize:9.0]];
    [[self.statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.statusField setFrame:NSMakeRect(railX + 9.0, railTop - 66.0, railWidth - 18.0, 14.0)];

    CGFloat drawerFolderButtonHeight = 46.0;
    CGFloat drawerFolderButtonGap = 8.0;
    CGFloat drawerFolderButtonY = railTop - 196.0;
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [self.drawerFolderButtons count]; navigationIndex++) {
        NSButton *folderButton = [self.drawerFolderButtons objectAtIndex:navigationIndex];
        [folderButton setFrame:NSMakeRect(railX + 8.0, drawerFolderButtonY, railWidth - 16.0, drawerFolderButtonHeight)];
        if (drawerVisible) {
            [contentView addSubview:folderButton positioned:NSWindowAbove relativeTo:nil];
        }
        drawerFolderButtonY -= (drawerFolderButtonHeight + drawerFolderButtonGap);
    }
    if (drawerVisible) {
        [contentView addSubview:self.titleField positioned:NSWindowAbove relativeTo:nil];
        [contentView addSubview:self.statusField positioned:NSWindowAbove relativeTo:nil];
        [contentView addSubview:self.drawerButton positioned:NSWindowAbove relativeTo:nil];
    }

    CGFloat bottomNavigationHeight = 62.0;
    CGFloat bottomNavigationX = mainX + 8.0;
    CGFloat bottomNavigationY = mainY + 8.0;
    CGFloat bottomNavigationWidth = sidebarWidth - 16.0;
    if (bottomNavigationWidth < 204.0) {
        bottomNavigationWidth = sidebarWidth - 8.0;
        bottomNavigationX = mainX + 4.0;
    }
    [self.bottomNavigationView setFrame:NSMakeRect(bottomNavigationX,
                                                   bottomNavigationY,
                                                   bottomNavigationWidth,
                                                   bottomNavigationHeight)];
    CGFloat bottomNavigationInnerX = bottomNavigationX + 8.0;
    CGFloat bottomNavigationButtonGap = 6.0;
    CGFloat bottomNavigationButtonHeight = 48.0;
    CGFloat bottomNavigationButtonY = bottomNavigationY + floor((bottomNavigationHeight - bottomNavigationButtonHeight) / 2.0);
    CGFloat bottomNavigationButtonWidth = floor((bottomNavigationWidth - 16.0 - (bottomNavigationButtonGap * 2.0)) / 3.0);
    if (bottomNavigationButtonWidth < 58.0) {
        bottomNavigationButtonWidth = 58.0;
    }
    for (navigationIndex = 0; navigationIndex < [self.navigationButtons count]; navigationIndex++) {
        NSButton *navigationButton = [self.navigationButtons objectAtIndex:navigationIndex];
        CGFloat buttonX = bottomNavigationInnerX + ((bottomNavigationButtonWidth + bottomNavigationButtonGap) * navigationIndex);
        [navigationButton setFrame:NSMakeRect(buttonX,
                                              bottomNavigationButtonY,
                                              bottomNavigationButtonWidth,
                                              bottomNavigationButtonHeight)];
        if (navigationIndex == 0 && self.markAllChatsReadSpinner) {
            [self.markAllChatsReadSpinner setFrame:NSMakeRect(buttonX + bottomNavigationButtonWidth - 22.0,
                                                              bottomNavigationButtonY + 6.0,
                                                              14.0,
                                                              14.0)];
        }
    }
    BOOL readyForMainShell = [self.currentAuthState isEqualToString:@"ready"];
    CGFloat loginAreaX = readyForMainShell ? mainX : margin;
    CGFloat loginAreaY = margin;
    CGFloat loginAreaWidth = readyForMainShell ? mainWidth : (width - (margin * 2.0));
    CGFloat loginAreaHeight = height - (margin * 2.0);
    CGFloat loginWidth = loginAreaWidth - 96.0;
    if (loginWidth > 580.0) {
        loginWidth = 580.0;
    }
    if (loginWidth < 390.0) {
        loginWidth = loginAreaWidth - 24.0;
    }
    CGFloat loginHeight = 276.0;
    CGFloat loginX = loginAreaX + floor((loginAreaWidth - loginWidth) / 2.0);
    CGFloat centeredLoginY = loginAreaY + floor((loginAreaHeight - loginHeight) / 2.0) - 8.0;
    CGFloat brandIconSide = 68.0;
    CGFloat brandIconY = centeredLoginY + loginHeight + 24.0;
    CGFloat brandTitleY = brandIconY - 30.0;
    if (brandIconY + brandIconSide > loginAreaY + loginAreaHeight - 12.0) {
        brandIconY = loginAreaY + loginAreaHeight - brandIconSide - 12.0;
        brandTitleY = brandIconY - 30.0;
    }
    CGFloat loginY = brandTitleY - loginHeight - 18.0;
    if (loginY < loginAreaY + 18.0) {
        loginY = loginAreaY + 18.0;
    }
    [self.loginIconView setFrame:NSMakeRect(loginAreaX + floor((loginAreaWidth - brandIconSide) / 2.0),
                                            brandIconY,
                                            brandIconSide,
                                            brandIconSide)];
    [self.loginBrandField setFrame:NSMakeRect(loginAreaX + floor((loginAreaWidth - 360.0) / 2.0),
                                              brandTitleY,
                                              360.0,
                                              26.0)];
    [self.loginPanelView setFrame:NSMakeRect(loginX, loginY, loginWidth, loginHeight)];
    [self.loginTitleField setFrame:NSMakeRect(loginX + 36.0, loginY + loginHeight - 58.0, loginWidth - 72.0, 28.0)];
    [self.loginHintField setFrame:NSMakeRect(loginX + 54.0, loginY + loginHeight - 112.0, loginWidth - 108.0, 44.0)];
    [self.authLabel setFrame:NSMakeRect(loginX + 54.0, loginY + 114.0, loginWidth - 108.0, 18.0)];
    [self.authSecondaryLabel setFrame:NSMakeRect(loginX + 54.0, loginY + 94.0, loginWidth - 108.0, 18.0)];
    CGFloat loginButtonWidth = 92.0;
    CGFloat loginInputX = loginX + 54.0;
    CGFloat loginButtonX = loginX + loginWidth - 54.0 - loginButtonWidth;
    CGFloat loginInputWidth = loginButtonX - loginInputX - 12.0;
    if (loginInputWidth < 180.0) {
        loginInputWidth = 180.0;
    }
    CGFloat primaryInputY = loginY + 82.0;
    CGFloat secondaryInputY = loginY + 62.0;
    CGFloat loginErrorHeight = 28.0;
    CGFloat loginErrorGap = 4.0;
    CGFloat loginErrorY = primaryInputY - loginErrorGap - loginErrorHeight;
    [self.authStateField setFrame:NSMakeRect(loginX + 54.0, loginErrorY, loginWidth - 108.0, loginErrorHeight)];
    [self.authTextFieldBackgroundView setFrame:NSMakeRect(loginInputX, primaryInputY, loginInputWidth, 32.0)];
    [self.authTextField setFrame:NSMakeRect(loginInputX + 9.0, primaryInputY + 7.0, loginInputWidth - 18.0, 18.0)];
    [self.authSecondaryTextFieldBackgroundView setFrame:NSMakeRect(loginInputX, secondaryInputY, loginInputWidth, 32.0)];
    [self.authSecureField setFrame:NSMakeRect(loginInputX + 9.0, primaryInputY + 7.0, loginInputWidth - 18.0, 18.0)];
    [self.authButton setFrame:NSMakeRect(loginButtonX, primaryInputY, loginButtonWidth, 32.0)];
    [self.busySpinner setFrame:NSMakeRect(loginX + loginWidth - 36.0, primaryInputY + 8.0, 16.0, 16.0)];
    [self.loginLogsButton setFrame:NSMakeRect(width - margin - 74.0, margin + 6.0, 74.0, 28.0)];
    CGFloat loginLanguageX = margin;
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        NSButton *languageButton = [self.loginLanguageButtons objectAtIndex:loginLanguageIndex];
        [languageButton setFrame:NSMakeRect(loginLanguageX + (loginLanguageIndex * 48.0), margin + 6.0, 42.0, 28.0)];
    }

    CGFloat headerButtonSize = 30.0;
    CGFloat sectionHeaderVisualOffset = -2.0;
    CGFloat headerButtonY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - headerButtonSize) / 2.0) + sectionHeaderVisualOffset;
    CGFloat headerLabelY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - 20.0) / 2.0) + sectionHeaderVisualOffset;
    CGFloat headerLeftX = mainX + 12.0;
    CGFloat globalHeaderTitleX = mainX + 18.0;
    CGFloat chatHeaderTitleX = mainX + 16.0;
    if (!drawerHidden) {
        [self.drawerButton setFrame:NSMakeRect(headerLeftX, headerButtonY, headerButtonSize, headerButtonSize)];
        [[self.drawerButton superview] addSubview:self.drawerButton positioned:NSWindowAbove relativeTo:nil];
        headerLeftX += headerButtonSize + 8.0;
        globalHeaderTitleX = headerLeftX;
        chatHeaderTitleX = headerLeftX;
    }
    if (self.showingForumTopicList) {
        [self.topicBackButton setFrame:NSMakeRect(headerLeftX, headerButtonY, headerButtonSize, headerButtonSize)];
        chatHeaderTitleX = headerLeftX + headerButtonSize + 8.0;
    } else {
        [self.topicBackButton setFrame:NSMakeRect(mainX + 12.0, headerButtonY, headerButtonSize, headerButtonSize)];
    }
    [self.chatsLabel setFrame:NSMakeRect(chatHeaderTitleX, headerLabelY, sidebarWidth - (chatHeaderTitleX - mainX) - 58.0, 20.0)];
    [self.loadMoreChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.loadChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.chatSearchButton setFrame:NSMakeRect(mainX + sidebarWidth - 18.0 - (headerButtonSize * 2.0), headerButtonY, headerButtonSize, headerButtonSize)];
    CGFloat chatListX = mainX + 8.0;
    CGFloat chatListBottom = bottomNavigationY + bottomNavigationHeight + 9.0;
    CGFloat chatListTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat chatListHeight = chatListTop - chatListBottom;
    if (chatListHeight < 128.0) {
        chatListHeight = 128.0;
    }
    CGFloat chatListWidth = sidebarWidth - 16.0;
    if (chatListWidth < 132.0) {
        chatListWidth = 132.0;
    }
    NSRect chatSurfaceFrame = NSMakeRect(chatListX, chatListBottom, chatListWidth, chatListHeight);
    [self.chatScrollSurfaceView setFrame:chatSurfaceFrame];
    [self.chatScrollView setFrame:NSInsetRect(chatSurfaceFrame, 5.0, 5.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"chat"];
    if (chatColumn) {
        [self.chatScrollView tile];
        CGFloat chatWidth = NSWidth([[self.chatScrollView contentView] bounds]);
        if (chatWidth < 132.0) {
            chatWidth = 132.0;
        }
        [chatColumn setWidth:chatWidth];
    }

    CGFloat conversationRefreshX = conversationX + conversationWidth - 12.0 - headerButtonSize;
    CGFloat conversationJumpX = conversationRefreshX - 6.0 - headerButtonSize;
    CGFloat conversationMediaX = conversationJumpX - 6.0 - headerButtonSize;
    CGFloat conversationSearchX = conversationMediaX - 6.0 - headerButtonSize;
    [self.loadOlderMessagesButton setFrame:NSMakeRect(conversationRefreshX, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.loadMessagesButton setFrame:NSMakeRect(conversationRefreshX, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.messageJumpToNewestButton setFrame:NSMakeRect(conversationJumpX, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.mediaCenterButton setFrame:NSMakeRect(conversationMediaX, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.conversationSearchButton setFrame:NSMakeRect(conversationSearchX, headerButtonY, headerButtonSize, headerButtonSize)];
    BOOL layoutCommentThreadBack = ([self.selectedMessageTopicKind isEqualToString:@"thread"] &&
                                    [self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)]);
    CGFloat conversationHeaderLeftX = conversationX + 16.0;
    if (layoutCommentThreadBack) {
        [self.commentThreadBackButton setFrame:NSMakeRect(conversationX + 12.0, headerButtonY, headerButtonSize, headerButtonSize)];
        conversationHeaderLeftX = NSMaxX([self.commentThreadBackButton frame]) + 8.0;
    } else {
        [self.commentThreadBackButton setFrame:NSMakeRect(conversationX + 12.0, headerButtonY, headerButtonSize, headerButtonSize)];
    }
    [self.messagesLabel setFrame:NSMakeRect(conversationX + 16.0, headerLabelY, 0.0, 20.0)];
    CGFloat selectedAvatarSize = 24.0;
    CGFloat selectedAvatarX = conversationHeaderLeftX;
    CGFloat selectedAvatarY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - selectedAvatarSize) / 2.0) + sectionHeaderVisualOffset;
    [self.selectedChatAvatarView setFrame:NSMakeRect(selectedAvatarX, selectedAvatarY, selectedAvatarSize, selectedAvatarSize)];
    CGFloat selectedTitleX = NSMaxX([self.selectedChatAvatarView frame]) + 8.0;
    CGFloat selectedTitleWidth = NSMinX([self.conversationSearchButton frame]) - selectedTitleX - 12.0;
    if (selectedTitleWidth < 120.0) {
        selectedTitleWidth = 120.0;
    }
    BOOL hasTypingText = ([[self.typingIndicatorField stringValue] length] > 0);
    CGFloat selectedTitleY = hasTypingText ? (headerLabelY + 4.0) : headerLabelY;
    [self.selectedChatField setFrame:NSMakeRect(selectedTitleX,
                                                selectedTitleY,
                                                selectedTitleWidth,
                                                17.0)];
    [self.typingIndicatorField setFrame:NSMakeRect(selectedTitleX,
                                                   headerLabelY - 8.0,
                                                   selectedTitleWidth,
                                                   14.0)];
    CGFloat profileHitMaxX = NSMinX([self.conversationSearchButton frame]) - 10.0;
    CGFloat profileHitWidth = profileHitMaxX - selectedAvatarX;
    if (profileHitWidth < selectedAvatarSize) {
        profileHitWidth = selectedAvatarSize;
    }
    [self.selectedChatProfileButton setFrame:NSMakeRect(selectedAvatarX,
                                                        selectedAvatarY - 2.0,
                                                        profileHitWidth,
                                                        selectedAvatarSize + 4.0)];

    NSArray *chatHeaderControls = [NSArray arrayWithObjects:
                                   self.conversationSearchButton,
                                   self.mediaCenterButton,
                                   self.messageJumpToNewestButton,
                                   self.loadMessagesButton,
                                   self.loadOlderMessagesButton,
                                   self.commentThreadBackButton,
                                   nil];
    NSUInteger chatHeaderControlIndex = 0;
    for (chatHeaderControlIndex = 0; chatHeaderControlIndex < [chatHeaderControls count]; chatHeaderControlIndex++) {
        NSView *control = [chatHeaderControls objectAtIndex:chatHeaderControlIndex];
        if ([control superview]) {
            [[control superview] addSubview:control positioned:NSWindowAbove relativeTo:nil];
        }
    }

    CGFloat estimatedSendFieldWidth = conversationWidth - 198.0;
    if (estimatedSendFieldWidth < 160.0) {
        estimatedSendFieldWidth = 160.0;
    }
    CGFloat composerInputHeight = [self composerInputHeightForWidth:(estimatedSendFieldWidth - 16.0)];
    CGFloat composerHeight = composerInputHeight + 16.0;
    if (composerHeight < 42.0) {
        composerHeight = 42.0;
    }
    CGFloat composerY = mainY + 8.0;
    BOOL hasReplyPanel = (self.replyTargetMessageItem != nil);
    CGFloat replyPanelHeight = hasReplyPanel ? 46.0 : 0.0;
    CGFloat replyPanelGap = hasReplyPanel ? 6.0 : 0.0;
    CGFloat messageBottom = composerY + composerHeight + replyPanelHeight + replyPanelGap + 4.0;
    CGFloat messageTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat panelInsetX = conversationX + 8.0;
    CGFloat panelWidth = conversationWidth - 16.0;
    if (panelWidth < 260.0) {
        panelWidth = 260.0;
    }
    if (self.searchPanelVisible) {
        BOOL hasSearchText = ([[self.searchTextField stringValue] length] > 0);
        BOOL hasSearchResults = ([self.searchResultItems count] > 0);
        CGFloat searchHeight = (hasSearchResults || (hasSearchText && self.searchLoading)) ? 174.0 : 78.0;
        CGFloat searchY = messageTop - searchHeight;
        [self.searchPanelView setFrame:NSMakeRect(panelInsetX, searchY, panelWidth, searchHeight)];
        BOOL hidesScopeControl = (self.chatTitleSearchOnly || self.searchInlineCurrentChatOnly);
        CGFloat searchFieldWidth = hidesScopeControl ? (panelWidth - 212.0) : (panelWidth - 326.0);
        [self.searchTextField setFrame:NSMakeRect(panelInsetX + 14.0, searchY + searchHeight - 40.0, searchFieldWidth, 24.0)];
        [self.searchScopePopUpButton setFrame:NSMakeRect(panelInsetX + panelWidth - 306.0, searchY + searchHeight - 42.0, 132.0, 26.0)];
        [self.searchFilterPopUpButton setFrame:NSMakeRect(panelInsetX + panelWidth - 168.0, searchY + searchHeight - 42.0, 106.0, 26.0)];
        [self.searchCloseButton setFrame:NSMakeRect(panelInsetX + panelWidth - 54.0, searchY + searchHeight - 42.0, 38.0, 26.0)];
        [self.searchScopePopUpButton setHidden:hidesScopeControl];
        [self.searchFilterPopUpButton setHidden:NO];
        [self.searchStatusField setFrame:NSMakeRect(panelInsetX + 14.0, searchY + searchHeight - 62.0, panelWidth - 28.0, 18.0)];
        [self.searchResultsScrollView setFrame:NSMakeRect(panelInsetX + 14.0, searchY + 12.0, panelWidth - 28.0, searchHeight - 78.0)];
        [self.searchResultsScrollView setHidden:!(hasSearchResults || self.searchLoading)];
        [self.searchResultsTableView setHidden:!(hasSearchResults || self.searchLoading)];
        NSTableColumn *searchColumn = [self.searchResultsTableView tableColumnWithIdentifier:@"search"];
        if (searchColumn) {
            [self.searchResultsScrollView tile];
            [searchColumn setWidth:NSWidth([[self.searchResultsScrollView contentView] bounds])];
        }
        messageTop = searchY - 6.0;
    }
    BOOL hasPinnedPanel = (self.pinnedMessageItem != nil && !self.searchPanelVisible);
    if (hasPinnedPanel) {
        CGFloat pinnedHeight = 48.0;
        CGFloat pinnedY = messageTop - pinnedHeight;
        [self.pinnedMessagePanelView setFrame:NSMakeRect(panelInsetX, pinnedY, panelWidth, pinnedHeight)];
        [self.pinnedMessageStripeField setFrame:NSMakeRect(panelInsetX + 12.0, pinnedY + 9.0, 10.0, pinnedHeight - 16.0)];
        [self.pinnedMessageLabelField setFrame:NSMakeRect(panelInsetX + 28.0, pinnedY + 27.0, 180.0, 15.0)];
        [self.pinnedMessageTextField setFrame:NSMakeRect(panelInsetX + 28.0, pinnedY + 9.0, panelWidth - 78.0, 18.0)];
        [self.pinnedMessageButton setFrame:NSMakeRect(panelInsetX, pinnedY, panelWidth, pinnedHeight)];
        messageTop = pinnedY - 6.0;
    }
    CGFloat messageHeight = messageTop - messageBottom;
    if (messageHeight < 160.0) {
        messageHeight = 160.0;
    }
    CGFloat messageScrollX = panelInsetX;
    CGFloat messageScrollWidth = panelWidth;
    if (messageScrollWidth < 260.0) {
        messageScrollWidth = 260.0;
    }
    NSRect messageSurfaceFrame = NSMakeRect(messageScrollX, messageBottom, messageScrollWidth, messageHeight);
    [self.messageScrollSurfaceView setFrame:messageSurfaceFrame];
    [self.messageScrollView setFrame:NSInsetRect(messageSurfaceFrame, 5.0, 5.0)];
    [self.messageLoadingSpinner setFrame:NSMakeRect(NSMidX(messageSurfaceFrame) - 12.0,
                                                    NSMidY(messageSurfaceFrame) - 12.0,
                                                    24.0,
                                                    24.0)];
    CGFloat dropOverlayInset = (NSHeight(messageSurfaceFrame) > 130.0) ? 24.0 : 12.0;
    [self.messageDropOverlayView setFrame:NSInsetRect(messageSurfaceFrame, dropOverlayInset, dropOverlayInset)];
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (bubbleColumn) {
        [self.messageScrollView tile];
        CGFloat bubbleWidth = NSWidth([[self.messageScrollView contentView] bounds]);
        if (bubbleWidth < 260.0) {
            bubbleWidth = 260.0;
        }
        [bubbleColumn setWidth:bubbleWidth];
    }

    CGFloat sendButtonWidth = 38.0;
    CGFloat attachButtonWidth = 38.0;
    CGFloat smallComposerButtonWidth = 34.0;
    CGFloat composerButtonGap = 6.0;
    CGFloat attachButtonX = conversationX + 12.0;
    CGFloat sendButtonX = conversationX + conversationWidth - sendButtonWidth - 12.0;
    CGFloat voiceButtonX = sendButtonX - composerButtonGap - smallComposerButtonWidth;
    CGFloat stickerButtonX = voiceButtonX - composerButtonGap - smallComposerButtonWidth;
    CGFloat sendFieldX = attachButtonX + attachButtonWidth + 8.0;
    CGFloat sendFieldWidth = stickerButtonX - sendFieldX - 10.0;
    if (sendFieldWidth < 160.0) {
        sendFieldWidth = 160.0;
    }
    CGFloat composerInnerHeight = composerInputHeight + 10.0;
    CGFloat composerControlY = composerY + floor((composerHeight - 32.0) / 2.0);
    CGFloat composerInputBackgroundY = composerY + floor((composerHeight - composerInnerHeight) / 2.0);
    [self.sendLabel setFrame:NSMakeRect(conversationX + 14.0, composerY + 8.0, 0.0, 22.0)];
    [self.attachPhotoButton setFrame:NSMakeRect(attachButtonX, composerControlY, attachButtonWidth, 32.0)];
    [self.sendTextFieldBackgroundView setFrame:NSMakeRect(sendFieldX, composerInputBackgroundY, sendFieldWidth, composerInnerHeight)];
    [self.sendTextField setFrame:NSMakeRect(sendFieldX + 8.0, composerInputBackgroundY + 5.0, sendFieldWidth - 16.0, composerInputHeight)];
    [self.stickerButton setFrame:NSMakeRect(stickerButtonX, composerControlY, smallComposerButtonWidth, 32.0)];
    [self.voiceRecordButton setFrame:NSMakeRect(voiceButtonX, composerControlY, smallComposerButtonWidth, 32.0)];
    [self.sendMessageButton setFrame:NSMakeRect(sendButtonX, composerControlY, sendButtonWidth, 32.0)];
    [self.voiceRecordingIndicatorField setFrame:NSMakeRect(sendFieldX + 2.0, composerY + composerHeight + 2.0, 0.0, 0.0)];
    if (hasReplyPanel) {
        CGFloat replyY = composerY + composerHeight + 6.0;
        CGFloat replyX = sendFieldX;
        CGFloat replyWidth = sendButtonX + sendButtonWidth - sendFieldX;
        if (replyWidth < 220.0) {
            replyWidth = 220.0;
        }
        [self.replyPanelView setFrame:NSMakeRect(replyX, replyY, replyWidth, 40.0)];
        CGFloat replyTextX = replyX + 14.0;
        CGFloat replyTextWidth = replyWidth - 26.0;
        if (replyTextWidth < 80.0) {
            replyTextWidth = 80.0;
        }
        [self.replyPanelTitleField setFrame:NSMakeRect(replyTextX, replyY + 22.0, replyTextWidth, 14.0)];
        [self.replyPanelTextField setFrame:NSMakeRect(replyTextX, replyY + 7.0, replyTextWidth, 15.0)];
        [self.replyPanelCancelButton setFrame:NSMakeRect(attachButtonX, replyY + 4.0, attachButtonWidth, 32.0)];
    }

    CGFloat panelTitleY = headerLabelY;
    CGFloat contentTop = mainTop - TGPanelHeaderHeight;
    CGFloat groupedWidth = mainWidth - 56.0;
    if (groupedWidth > 760.0) {
        groupedWidth = 760.0;
    }
    if (groupedWidth < 360.0) {
        groupedWidth = mainWidth - 32.0;
    }
    [self.profileTitleField setFrame:NSMakeRect(globalHeaderTitleX, panelTitleY, 240.0, 22.0)];
    CGFloat profileScrollBottom = bottomNavigationY + bottomNavigationHeight + 10.0;
    CGFloat profileScrollTop = mainTop - TGPanelHeaderHeight - 8.0;
    CGFloat profileScrollHeight = profileScrollTop - profileScrollBottom;
    if (profileScrollHeight < 180.0) {
        profileScrollHeight = 180.0;
    }
    CGFloat profileScrollX = mainX + 8.0;
    CGFloat profileScrollWidth = mainWidth - 16.0;
    if (profileScrollWidth < 360.0) {
        profileScrollWidth = 360.0;
    }
    [self.profileScrollView setFrame:NSMakeRect(profileScrollX,
                                                profileScrollBottom,
                                                profileScrollWidth,
                                                profileScrollHeight)];

    CGFloat profileDocWidth = profileScrollWidth - 18.0;
    if (profileDocWidth < 340.0) {
        profileDocWidth = profileScrollWidth;
    }
    CGFloat initialProfileDocHeight = NSHeight([self.profileContentView frame]);
    if (initialProfileDocHeight < profileScrollHeight) {
        initialProfileDocHeight = profileScrollHeight;
    }
    [self.profileContentView setFrame:NSMakeRect(0.0, 0.0, profileDocWidth, initialProfileDocHeight)];

    CGFloat profileGroupedWidth = profileDocWidth - 56.0;
    if (profileGroupedWidth > 760.0) {
        profileGroupedWidth = 760.0;
    }
    if (profileGroupedWidth < 300.0) {
        profileGroupedWidth = profileDocWidth - 24.0;
    }
    CGFloat profileGroupedX = floor((profileDocWidth - profileGroupedWidth) / 2.0);
    CGFloat profileLabelHeight = 16.0;
    CGFloat profileLabelGap = 7.0;
    CGFloat profileGroupGap = 12.0;
    CGFloat profileNextY = 18.0;

    CGFloat profileSummaryHeight = 190.0;
    CGFloat profileSummaryY = profileNextY;
    [self.profileSummaryCardView setFrame:NSMakeRect(profileGroupedX, profileSummaryY, profileGroupedWidth, profileSummaryHeight)];
    CGFloat profileAvatarSize = 96.0;
    CGFloat profileAvatarX = profileGroupedX + floor((profileGroupedWidth - profileAvatarSize) / 2.0);
    CGFloat profileAvatarY = profileSummaryY + 18.0;
    [self.profileAvatarView setFrame:NSMakeRect(profileAvatarX,
                                                profileAvatarY,
                                                profileAvatarSize,
                                                profileAvatarSize)];
    CGFloat profileTextX = profileGroupedX + 22.0;
    CGFloat profileTextWidth = profileGroupedWidth - 44.0;
    [self.profileNameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 124.0, profileTextWidth, 26.0)];
    [self.profileUsernameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 154.0, profileTextWidth, 20.0)];

    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    profileNextY = profileSummaryY + profileSummaryHeight + profileGroupGap;

    if (profileHasBio) {
        [self.profileAboutSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, profileLabelHeight)];
        NSDictionary *bioAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont systemFontOfSize:13.0], NSFontAttributeName,
                                       nil];
        NSString *bioText = [self.profileStateField stringValue];
        NSRect bioRect = [bioText boundingRectWithSize:NSMakeSize(profileGroupedWidth - 44.0, 12000.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:bioAttributes];
        CGFloat bioTextHeight = ceil(NSHeight(bioRect));
        CGFloat profileInfoHeight = bioTextHeight + 28.0;
        if (profileInfoHeight < 54.0) {
            profileInfoHeight = 54.0;
        }
        if (profileInfoHeight > 112.0) {
            profileInfoHeight = 112.0;
        }
        CGFloat profileInfoY = profileNextY + profileLabelHeight + profileLabelGap;
        [self.profileInfoCardView setFrame:NSMakeRect(profileGroupedX, profileInfoY, profileGroupedWidth, profileInfoHeight)];
        [self.profileStateField setFrame:NSMakeRect(profileGroupedX + 22.0, profileInfoY + 13.0, profileGroupedWidth - 44.0, profileInfoHeight - 26.0)];
        profileNextY = profileInfoY + profileInfoHeight + profileGroupGap;
    } else {
        [self.profileAboutSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, 0.0)];
        [self.profileInfoCardView setFrame:NSMakeRect(profileGroupedX, profileNextY, profileGroupedWidth, 0.0)];
        [self.profileStateField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, profileGroupedWidth - 44.0, 0.0)];
    }

    if (profileDetailRows > 0) {
        CGFloat rowHeight = 44.0;
        CGFloat detailsHeight = ((CGFloat)profileDetailRows * rowHeight) + 10.0;
        CGFloat accountSectionY = profileNextY;
        CGFloat detailsY = accountSectionY + profileLabelHeight + profileLabelGap;
        [self.profileAccountSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, accountSectionY, profileGroupedWidth - 40.0, profileLabelHeight)];
        [self.profileDetailsCardView setFrame:NSMakeRect(profileGroupedX, detailsY, profileGroupedWidth, detailsHeight)];

        CGFloat rowTitleX = profileGroupedX + 22.0;
        CGFloat rowValueX = profileGroupedX + 208.0;
        CGFloat rowValueWidth = profileGroupedWidth - 230.0;
        if (rowValueWidth < 160.0) {
            rowValueX = profileGroupedX + 148.0;
            rowValueWidth = profileGroupedWidth - 170.0;
        }
        CGFloat rowY = detailsY + 11.0;
        NSUInteger laidOutRows = 0;
        CGFloat separatorOneY = 0.0;
        CGFloat separatorTwoY = 0.0;

        if (profileHasUsername) {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            separatorOneY = rowY + 32.0;
            rowY += rowHeight;
        } else {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasPhone) {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            if (laidOutRows == 1) {
                separatorOneY = rowY + 32.0;
            } else {
                separatorTwoY = rowY + 32.0;
            }
            rowY += rowHeight;
        } else {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasID) {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
        } else {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileDetailRows > 1) {
            [self.profileDetailsSeparatorOne setFrame:NSMakeRect(profileGroupedX + 22.0, separatorOneY, profileGroupedWidth - 44.0, 1.0)];
        }
        if (profileDetailRows > 2) {
            if (separatorTwoY <= 0.0) {
                separatorTwoY = separatorOneY + rowHeight;
            }
            [self.profileDetailsSeparatorTwo setFrame:NSMakeRect(profileGroupedX + 22.0, separatorTwoY, profileGroupedWidth - 44.0, 1.0)];
        }
        profileNextY = detailsY + detailsHeight + profileGroupGap;
    } else {
        [self.profileAccountSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, 0.0)];
        [self.profileDetailsCardView setFrame:NSMakeRect(profileGroupedX, profileNextY, profileGroupedWidth, 0.0)];
        [self.profileUsernameRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profileUsernameRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
        [self.profilePhoneRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profilePhoneRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
        [self.profileIDRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profileIDRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
    }

    CGFloat profileActionsHeight = 52.0;
    CGFloat profileActionsY = profileNextY;
    [self.profileActionsCardView setFrame:NSMakeRect(profileGroupedX, profileActionsY, profileGroupedWidth, profileActionsHeight)];
    [self.profileRefreshButton setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY, 0.0, 0.0)];
    [self.logoutButton setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY + 11.0, profileGroupedWidth - 44.0, 30.0)];
    [self.profileIDField setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY, 0.0, 0.0)];
    profileNextY = profileActionsY + profileActionsHeight + 18.0;

    CGFloat profileDocHeight = profileNextY;
    if (profileDocHeight < profileScrollHeight) {
        profileDocHeight = profileScrollHeight;
    }
    [self.profileContentView setFrame:NSMakeRect(0.0, 0.0, profileDocWidth, profileDocHeight)];
    NSClipView *profileClipView = [self.profileScrollView contentView];
    NSPoint profileClipOrigin = [profileClipView bounds].origin;
    if (profileClipOrigin.x != 0.0) {
        [profileClipView setBoundsOrigin:NSMakePoint(0.0, profileClipOrigin.y)];
    }

    [self.settingsTitleField setFrame:NSMakeRect(globalHeaderTitleX, panelTitleY, 240.0, 22.0)];

    CGFloat settingsScrollBottom = bottomNavigationY + bottomNavigationHeight + 10.0;
    CGFloat settingsScrollTop = mainTop - TGPanelHeaderHeight - 8.0;
    CGFloat settingsScrollHeight = settingsScrollTop - settingsScrollBottom;
    if (settingsScrollHeight < 180.0) {
        settingsScrollHeight = 180.0;
    }
    CGFloat settingsScrollX = mainX + 8.0;
    CGFloat settingsScrollWidth = mainWidth - 16.0;
    if (settingsScrollWidth < 360.0) {
        settingsScrollWidth = 360.0;
    }
    [self.settingsScrollView setFrame:NSMakeRect(settingsScrollX,
                                                 settingsScrollBottom,
                                                 settingsScrollWidth,
                                                 settingsScrollHeight)];

    CGFloat settingsDocWidth = settingsScrollWidth - 18.0;
    if (settingsDocWidth < 340.0) {
        settingsDocWidth = settingsScrollWidth;
    }
    CGFloat settingsLabelHeight = 16.0;
    CGFloat settingsLabelGap = 7.0;
    CGFloat settingsGroupGap = 12.0;
    CGFloat settingsBottomPadding = 58.0;
    CGFloat notificationCardHeight = 140.0;
    CGFloat drawerCardHeight = 78.0;
    CGFloat resourceCardHeight = 276.0;
    CGFloat interfaceCardHeight = 184.0;
    CGFloat sessionsCardHeight = 72.0;
    CGFloat filesCardHeight = 140.0;
    CGFloat helpCardHeight = 112.0;
    CGFloat settingsDocHeight = 18.0;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + notificationCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + drawerCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + resourceCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + interfaceCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + sessionsCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + filesCardHeight + settingsGroupGap;
    settingsDocHeight += settingsLabelHeight + settingsLabelGap + helpCardHeight + settingsBottomPadding;
    if (settingsDocHeight < settingsScrollHeight) {
        settingsDocHeight = settingsScrollHeight;
    }
    [self.settingsContentView setFrame:NSMakeRect(0.0, 0.0, settingsDocWidth, settingsDocHeight)];
    NSClipView *settingsClipView = [self.settingsScrollView contentView];
    NSPoint settingsClipOrigin = [settingsClipView bounds].origin;
    CGFloat maxSettingsClipY = MAX(0.0, settingsDocHeight - settingsScrollHeight);
    if (settingsClipOrigin.x != 0.0 || settingsClipOrigin.y > maxSettingsClipY) {
        [settingsClipView setBoundsOrigin:NSMakePoint(0.0, MIN(settingsClipOrigin.y, maxSettingsClipY))];
    }

    CGFloat settingsGroupedWidth = settingsDocWidth - 56.0;
    if (settingsGroupedWidth > 760.0) {
        settingsGroupedWidth = 760.0;
    }
    if (settingsGroupedWidth < 300.0) {
        settingsGroupedWidth = settingsDocWidth - 24.0;
    }
    CGFloat settingsGroupedX = floor((settingsDocWidth - settingsGroupedWidth) / 2.0);
    CGFloat rowLeft = settingsGroupedX + 22.0;
    CGFloat rowWidth = settingsGroupedWidth - 44.0;
    CGFloat settingsNextY = 18.0;

    [self.settingsStateField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat notificationCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsAccountCardView setFrame:NSMakeRect(settingsGroupedX, notificationCardY, settingsGroupedWidth, notificationCardHeight)];
    [self.settingsNotificationsEnabledButton setFrame:NSMakeRect(rowLeft, notificationCardY + 12.0, rowWidth, 22.0)];
    [self.settingsNotificationSoundButton setFrame:NSMakeRect(rowLeft, notificationCardY + 36.0, rowWidth, 22.0)];
    [self.settingsNotificationBadgeButton setFrame:NSMakeRect(rowLeft, notificationCardY + 60.0, rowWidth, 22.0)];
    [self.settingsNotificationPreviewButton setFrame:NSMakeRect(rowLeft, notificationCardY + 84.0, rowWidth, 22.0)];
    [self.settingsNotificationsWhenActiveButton setFrame:NSMakeRect(rowLeft, notificationCardY + 108.0, rowWidth, 22.0)];
    settingsNextY = notificationCardY + notificationCardHeight + settingsGroupGap;

    [self.settingsDrawerSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat drawerCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsDrawerCardView setFrame:NSMakeRect(settingsGroupedX, drawerCardY, settingsGroupedWidth, drawerCardHeight)];
    [self.settingsDrawerHiddenButton setFrame:NSMakeRect(rowLeft, drawerCardY + 12.0, rowWidth, 22.0)];
    [self.settingsTypingIndicatorsButton setFrame:NSMakeRect(rowLeft, drawerCardY + 42.0, rowWidth, 22.0)];
    settingsNextY = drawerCardY + drawerCardHeight + settingsGroupGap;

    [self.settingsResourceSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat resourceCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsResourceCardView setFrame:NSMakeRect(settingsGroupedX, resourceCardY, settingsGroupedWidth, resourceCardHeight)];
    [self.settingsEconomyModeButton setFrame:NSMakeRect(rowLeft, resourceCardY + 12.0, rowWidth, 22.0)];
    [self.settingsAutoDownloadPhotosButton setFrame:NSMakeRect(rowLeft, resourceCardY + 42.0, rowWidth, 22.0)];
    [self.settingsAutoDownloadVideosButton setFrame:NSMakeRect(rowLeft, resourceCardY + 70.0, rowWidth, 22.0)];
    [self.settingsAutoDownloadDocumentsButton setFrame:NSMakeRect(rowLeft, resourceCardY + 98.0, rowWidth, 22.0)];
    CGFloat resourcePopupWidth = 190.0;
    if (resourcePopupWidth > rowWidth - 180.0) {
        resourcePopupWidth = rowWidth - 180.0;
    }
    if (resourcePopupWidth < 120.0) {
        resourcePopupWidth = 120.0;
    }
    [self.settingsMaxAutoDownloadLabel setFrame:NSMakeRect(rowLeft, resourceCardY + 128.0, 170.0, 22.0)];
    [self.settingsMaxAutoDownloadPopUpButton setFrame:NSMakeRect(rowLeft + 178.0, resourceCardY + 124.0, resourcePopupWidth, 28.0)];
    [self.settingsAutoplayAnimatedStickersButton setFrame:NSMakeRect(rowLeft, resourceCardY + 158.0, rowWidth, 22.0)];
    [self.settingsMaxAnimationsLabel setFrame:NSMakeRect(rowLeft, resourceCardY + 188.0, 170.0, 22.0)];
    [self.settingsMaxAnimationsPopUpButton setFrame:NSMakeRect(rowLeft + 178.0, resourceCardY + 184.0, resourcePopupWidth, 28.0)];
    [self.settingsStopInactiveAnimationsButton setFrame:NSMakeRect(rowLeft, resourceCardY + 218.0, rowWidth, 22.0)];
    [self.settingsMediaCacheLimitLabel setFrame:NSMakeRect(rowLeft, resourceCardY + 248.0, 170.0, 22.0)];
    [self.settingsMediaCacheLimitPopUpButton setFrame:NSMakeRect(rowLeft + 178.0, resourceCardY + 244.0, resourcePopupWidth, 28.0)];
    [self.settingsResourceHintField setFrame:NSMakeRect(rowLeft + 390.0, resourceCardY + 126.0, MAX(160.0, rowWidth - 390.0), 54.0)];
    settingsNextY = resourceCardY + resourceCardHeight + settingsGroupGap;

    [self.settingsLibraryField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat interfaceCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsThemeCardView setFrame:NSMakeRect(settingsGroupedX, interfaceCardY, settingsGroupedWidth, interfaceCardHeight)];
    [self.settingsAppearanceButton setFrame:NSMakeRect(rowLeft, interfaceCardY, 0.0, 0.0)];

    CGFloat popupWidth = 210.0;
    if (popupWidth > settingsGroupedWidth - 150.0) {
        popupWidth = settingsGroupedWidth - 150.0;
    }
    CGFloat labelWidth = 88.0;
    CGFloat popupX = rowLeft + labelWidth + 8.0;
    [self.settingsThemeCategoryLabel setFrame:NSMakeRect(rowLeft, interfaceCardY + 14.0, labelWidth, 22.0)];
    [self.themeCategoryPopUpButton setFrame:NSMakeRect(popupX, interfaceCardY + 10.0, popupWidth, 28.0)];
    [self.settingsThemeLabel setFrame:NSMakeRect(rowLeft, interfaceCardY + 46.0, labelWidth, 22.0)];
    [self.themePopUpButton setFrame:NSMakeRect(popupX, interfaceCardY + 42.0, popupWidth, 28.0)];
    [self.settingsLanguageLabel setFrame:NSMakeRect(rowLeft, interfaceCardY + 80.0, labelWidth, 22.0)];
    [self.settingsLanguagePopUpButton setFrame:NSMakeRect(popupX, interfaceCardY + 76.0, popupWidth, 28.0)];
    [self.settingsMessagesAsBlocksButton setFrame:NSMakeRect(rowLeft, interfaceCardY + 112.0, rowWidth, 22.0)];
    [self.settingsChatTextSizeSectionField setFrame:NSMakeRect(rowLeft, interfaceCardY + 146.0, labelWidth, 22.0)];
    CGFloat textSizeValueWidth = 110.0;
    CGFloat textSizeSliderWidth = rowWidth - labelWidth - textSizeValueWidth - 28.0;
    if (textSizeSliderWidth < 120.0) {
        textSizeSliderWidth = 120.0;
    }
    [self.settingsChatTextSizeSlider setFrame:NSMakeRect(popupX, interfaceCardY + 140.0, textSizeSliderWidth, 28.0)];
    [self.settingsChatTextSizeValueField setFrame:NSMakeRect(popupX + textSizeSliderWidth + 10.0,
                                                             interfaceCardY + 146.0,
                                                             textSizeValueWidth,
                                                             22.0)];
    settingsNextY = interfaceCardY + interfaceCardHeight + settingsGroupGap;

    [self.settingsStorageField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat sessionsCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsSessionCardView setFrame:NSMakeRect(settingsGroupedX, sessionsCardY, settingsGroupedWidth, sessionsCardHeight)];
    [self.settingsActiveSessionsDetailField setFrame:NSMakeRect(rowLeft, sessionsCardY + 10.0, rowWidth, 18.0)];
    [self.settingsActiveSessionsButton setFrame:NSMakeRect(rowLeft, sessionsCardY + 34.0, rowWidth, 28.0)];
    settingsNextY = sessionsCardY + sessionsCardHeight + settingsGroupGap;

    [self.settingsFilesSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat filesCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsFilesCardView setFrame:NSMakeRect(settingsGroupedX, filesCardY, settingsGroupedWidth, filesCardHeight)];
    [self.settingsDownloadFolderHelpField setFrame:NSMakeRect(rowLeft, filesCardY + 12.0, rowWidth, 18.0)];
    [self.settingsDownloadFolderButton setFrame:NSMakeRect(rowLeft, filesCardY + 38.0, rowWidth, 28.0)];
    [self.settingsStorageUsageButton setFrame:NSMakeRect(rowLeft, filesCardY + 70.0, rowWidth, 28.0)];
    [self.settingsDeleteLocalDataButton setFrame:NSMakeRect(rowLeft, filesCardY + 102.0, rowWidth, 28.0)];
    settingsNextY = filesCardY + filesCardHeight + settingsGroupGap;

    [self.settingsHelpSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat helpCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsHelpCardView setFrame:NSMakeRect(settingsGroupedX, helpCardY, settingsGroupedWidth, helpCardHeight)];
    [self.settingsLogsButton setFrame:NSMakeRect(rowLeft, helpCardY + 10.0, rowWidth, 28.0)];
    [self.settingsAboutButton setFrame:NSMakeRect(rowLeft, helpCardY + 42.0, rowWidth, 28.0)];
    [self.settingsCheckUpdatesButton setFrame:NSMakeRect(rowLeft, helpCardY + 74.0, rowWidth, 28.0)];
    [self.settingsUpdateDotView setFrame:NSMakeRect(rowWidth - 20.0, 9.0, 10.0, 10.0)];
    CGFloat aboutWidth = groupedWidth;
    if (aboutWidth > 560.0) {
        aboutWidth = 560.0;
    }
    CGFloat aboutX = mainX + floor((mainWidth - aboutWidth) / 2.0);
    CGFloat aboutHeight = 326.0;
    CGFloat aboutY = contentTop - aboutHeight - 24.0;
    [self.aboutCardView setFrame:NSMakeRect(aboutX, aboutY, aboutWidth, aboutHeight)];
    CGFloat aboutIconSize = 118.0;
    CGFloat aboutCenterX = aboutX + (aboutWidth / 2.0);
    [self.aboutIconView setFrame:NSMakeRect(aboutCenterX - (aboutIconSize / 2.0), aboutY + aboutHeight - aboutIconSize - 26.0, aboutIconSize, aboutIconSize)];
    [self.aboutTitleField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 134.0, aboutWidth - 72.0, 30.0)];
    [self.aboutVersionField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 104.0, aboutWidth - 72.0, 22.0)];
    [self.aboutCopyrightField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 72.0, aboutWidth - 72.0, 22.0)];
    [self.aboutLinkField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 40.0, aboutWidth - 72.0, 22.0)];

    [self.diagnosticsLabel setFrame:NSMakeRect(globalHeaderTitleX, panelTitleY, 160.0, 18.0)];
    [self.checkButton setFrame:NSMakeRect(mainX + mainWidth - 166.0, headerButtonY, 150.0, headerButtonSize)];
    CGFloat logsCardX = mainX + 18.0;
    CGFloat logsCardY = mainY + 18.0;
    CGFloat logsCardWidth = mainWidth - 36.0;
    CGFloat logsCardHeight = mainHeight - TGPanelHeaderHeight - 36.0;
    [self.logsCardView setFrame:NSMakeRect(logsCardX, logsCardY, logsCardWidth, logsCardHeight)];
    [self.detailsScrollView setFrame:NSMakeRect(logsCardX + 12.0, logsCardY + 12.0, logsCardWidth - 24.0, logsCardHeight - 24.0)];
    [self applyPointingHandCursorToButtonsInView:contentView];
}

- (void)windowDidResize:(NSNotification *)notification {
    if ([notification object] == self.mediaPreviewWindow) {
        [self layoutMediaPreviewWindowControls];
        [self fitMediaPreview:nil];
        return;
    }
    if ([notification object] == self.mediaPlaybackWindow) {
        [self layoutMediaPlaybackLayer];
        return;
    }
    if ([notification object] != [self window]) {
        return;
    }
    [self layoutContentView];
    [self.messageTableView reloadData];
    [self updateVisibleSection];
    [self scheduleInlineMediaPlaybackRefresh];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    if ([notification object] == [self window] && ![self.currentAuthState isEqualToString:@"ready"]) {
        [self scheduleLoginInputFocus];
    }
}

- (void)tearDownClosedMediaPreviewWindow:(NSWindow *)closingWindow {
    if (closingWindow != self.mediaPreviewWindow) {
        return;
    }
    self.mediaPreviewPath = nil;
    self.mediaPreviewZoomScale = 1.0;
    [self.mediaPreviewImageView setImage:nil];
    [closingWindow setDelegate:nil];
    self.mediaPreviewImageView = nil;
    self.mediaPreviewScrollView = nil;
    self.mediaPreviewZoomOutButton = nil;
    self.mediaPreviewFitButton = nil;
    self.mediaPreviewZoomInButton = nil;
    self.mediaPreviewWindow = nil;
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == self.mediaPreviewWindow) {
        NSWindow *closingWindow = [(NSWindow *)[notification object] retain];
        self.mediaPreviewRequestGeneration = self.mediaPreviewRequestGeneration + 1;
        self.mediaPreviewPath = nil;
        self.mediaPreviewZoomScale = 1.0;
        [self.mediaPreviewImageView setImage:nil];
        [closingWindow setDelegate:nil];
        [self performSelector:@selector(tearDownClosedMediaPreviewWindow:)
                   withObject:closingWindow
                   afterDelay:0.0];
        [closingWindow release];
    }
    if ([notification object] == self.mediaPlaybackWindow) {
        [self resetMediaPlaybackState];
        [self.mediaPlaybackWindow setDelegate:nil];
        self.mediaPlaybackContainerView = nil;
        self.mediaPlaybackTitleField = nil;
        self.mediaPlaybackPlayPauseButton = nil;
        self.mediaPlaybackProgressSlider = nil;
        self.mediaPlaybackTimeField = nil;
        self.mediaPlaybackCloseButton = nil;
        self.mediaPlaybackWindow = nil;
    }
    if ([notification object] == self.voicePreviewWindow) {
        if ([self.voiceRecorder isRecording]) {
            [self.voiceRecorder stop];
            self.voiceRecorder = nil;
            [self.voiceRecordButton setToolTip:@"Record voice message"];
            [self.statusField setStringValue:@"Voice recording cancelled"];
        }
        [self invalidateVoicePreviewTimer];
        [self.voicePreviewPlayer stop];
        self.voicePreviewPlayer = nil;
        if ([self.voiceRecordingPath length] > 0) {
            [[NSFileManager defaultManager] removeItemAtPath:self.voiceRecordingPath error:NULL];
        }
        self.voiceRecordingPath = nil;
        self.voiceRecordingStartDate = nil;
        [self.voiceRecordingIndicatorField setStringValue:@""];
        [self.voiceRecordingIndicatorField setHidden:YES];
        [self.voicePreviewWindow setDelegate:nil];
        self.voicePreviewTitleField = nil;
        self.voicePreviewPlayButton = nil;
        self.voicePreviewStopButton = nil;
        self.voicePreviewProgressSlider = nil;
        self.voicePreviewTimeField = nil;
        self.voicePreviewCancelButton = nil;
        self.voicePreviewSendButton = nil;
        self.voicePreviewErrorField = nil;
        self.voicePreviewWindow = nil;
        [self updateVisibleSection];
    }
    if ([notification object] == self.stickerPickerWindow) {
        [self.stickerPickerPlaybackCoordinator removeAllPlayback];
        [self scheduleInlineMediaPlaybackRefresh];
    }
}
