- (NSNumber *)notificationChatIDForChatItem:(TGChatItem *)item {
    if (![item isKindOfClass:[TGChatItem class]]) {
        return nil;
    }
    id chatID = [item isForumTopic] ? [item parentChatID] : [item chatID];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[chatID longLongValue]];
}

- (NSString *)notificationCacheKeyForChatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", [chatID longLongValue]];
}

- (TGChatItem *)chatItemForNotificationChatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    long long targetChatID = [chatID longLongValue];
    NSMutableArray *sources = [NSMutableArray array];
    if (self.chatItems) {
        [sources addObject:self.chatItems];
    }
    if (self.chatItemsBeforeTopicList) {
        [sources addObject:self.chatItemsBeforeTopicList];
    }

    NSUInteger sourceIndex = 0;
    for (sourceIndex = 0; sourceIndex < [sources count]; sourceIndex++) {
        NSArray *items = [sources objectAtIndex:sourceIndex];
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            id candidate = [items objectAtIndex:index];
            if (![candidate isKindOfClass:[TGChatItem class]]) {
                continue;
            }
            TGChatItem *item = (TGChatItem *)candidate;
            NSNumber *itemChatID = [self notificationChatIDForChatItem:item];
            if ([itemChatID respondsToSelector:@selector(longLongValue)] && [itemChatID longLongValue] == targetChatID) {
                return item;
            }
        }
    }
    return nil;
}

- (NSDictionary *)notificationChatInfoForChatID:(NSNumber *)chatID {
    NSString *cacheKey = [self notificationCacheKeyForChatID:chatID];
    if ([cacheKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    TGChatItem *item = [self chatItemForNotificationChatID:chatID];
    if ([item isKindOfClass:[TGChatItem class]]) {
        NSString *title = [item title];
        NSString *avatarPath = [item avatarLocalPath];
        if ([title length] > 0) {
            [info setObject:title forKey:@"title"];
        }
        if ([avatarPath length] > 0) {
            [info setObject:avatarPath forKey:@"avatar_local_path"];
        }
    }

    NSDictionary *cachedInfo = [self.notificationChatInfoByChatID objectForKey:cacheKey];
    if ([cachedInfo isKindOfClass:[NSDictionary class]]) {
        NSString *cachedTitle = [cachedInfo objectForKey:@"title"];
        NSString *cachedAvatarPath = [cachedInfo objectForKey:@"avatar_local_path"];
        id cachedMuted = [cachedInfo objectForKey:@"notifications_muted"];
        if ([[info objectForKey:@"title"] length] == 0 && [cachedTitle length] > 0) {
            [info setObject:cachedTitle forKey:@"title"];
        }
        if ([[info objectForKey:@"avatar_local_path"] length] == 0 && [cachedAvatarPath length] > 0) {
            [info setObject:cachedAvatarPath forKey:@"avatar_local_path"];
        }
        if (cachedMuted) {
            [info setObject:cachedMuted forKey:@"notifications_muted"];
        }
    }

    BOOL needsFetch = ([[info objectForKey:@"title"] length] == 0 || [[info objectForKey:@"avatar_local_path"] length] == 0);
    if (needsFetch && [self.client respondsToSelector:@selector(chatSummaryForChatID:downloadAvatar:timeout:error:)]) {
        NSError *chatInfoError = nil;
        NSDictionary *fetchedInfo = [self.client chatSummaryForChatID:chatID
                                                       downloadAvatar:YES
                                                              timeout:1.2
                                                                error:&chatInfoError];
        if ([fetchedInfo isKindOfClass:[NSDictionary class]]) {
            NSString *fetchedTitle = [fetchedInfo objectForKey:@"title"];
            NSString *fetchedAvatarPath = [fetchedInfo objectForKey:@"avatar_local_path"];
            id fetchedMuted = [fetchedInfo objectForKey:@"notifications_muted"];
            if ([fetchedTitle length] > 0) {
                [info setObject:fetchedTitle forKey:@"title"];
            }
            if ([fetchedAvatarPath length] > 0) {
                [info setObject:fetchedAvatarPath forKey:@"avatar_local_path"];
            }
            if (fetchedMuted) {
                [info setObject:fetchedMuted forKey:@"notifications_muted"];
            }
        }
        if ([chatInfoError localizedDescription]) {
            [self appendDetail:[NSString stringWithFormat:@"Notification chat info fallback: %@", [chatInfoError localizedDescription]]];
        }
    }

    if ([info count] > 0) {
        [self.notificationChatInfoByChatID setObject:[NSDictionary dictionaryWithDictionary:info] forKey:cacheKey];
        return info;
    }
    return nil;
}

- (NSString *)chatMuteDefaultsKeyForChatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", [chatID longLongValue]];
}

- (NSMutableDictionary *)mutableChatMuteOverrides {
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGChatNotificationMuteOverridesDefaultsKey];
    if ([stored isKindOfClass:[NSDictionary class]]) {
        return [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)stored];
    }
    return [NSMutableDictionary dictionary];
}

- (NSTimeInterval)localNotificationMuteUntilForChatID:(NSNumber *)chatID {
    NSString *key = [self chatMuteDefaultsKeyForChatID:chatID];
    if ([key length] == 0) {
        return 0.0;
    }
    NSDictionary *overrides = [[NSUserDefaults standardUserDefaults] objectForKey:TGChatNotificationMuteOverridesDefaultsKey];
    if (![overrides isKindOfClass:[NSDictionary class]]) {
        return 0.0;
    }
    id value = [(NSDictionary *)overrides objectForKey:key];
    if (![value respondsToSelector:@selector(doubleValue)]) {
        return 0.0;
    }
    NSTimeInterval muteUntil = [value doubleValue];
    if (muteUntil < 0.0) {
        return muteUntil;
    }
    if (muteUntil > [[NSDate date] timeIntervalSince1970]) {
        return muteUntil;
    }
    NSMutableDictionary *mutableOverrides = [self mutableChatMuteOverrides];
    [mutableOverrides removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] setObject:mutableOverrides forKey:TGChatNotificationMuteOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return 0.0;
}

- (BOOL)isChatIDLocallyMuted:(NSNumber *)chatID {
    return ([self localNotificationMuteUntilForChatID:chatID] != 0.0);
}

- (BOOL)isChatItemEffectivelyMuted:(TGChatItem *)item {
    if (![item isKindOfClass:[TGChatItem class]]) {
        return NO;
    }
    return ([item serverNotificationsMuted] || [self isChatIDLocallyMuted:[self notificationChatIDForChatItem:item]]);
}

- (void)applyLocalNotificationMuteStateToItems:(NSArray *)items {
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        NSNumber *chatID = [self notificationChatIDForChatItem:item];
        NSString *chatKey = [self chatMuteDefaultsKeyForChatID:chatID];
        BOOL locallyMuted = [self isChatIDLocallyMuted:chatID];
        if ([chatKey length] > 0 && ![item isForumTopic]) {
            NSNumber *unreadCount = [item unreadCount];
            if (locallyMuted && ![item serverNotificationsMuted]) {
                NSUInteger localUnreadCount = [unreadCount respondsToSelector:@selector(unsignedIntegerValue)] ? [unreadCount unsignedIntegerValue] : 0;
                [self.localMuteUnreadCountsByChatID setObject:[NSNumber numberWithUnsignedInteger:localUnreadCount] forKey:chatKey];
            } else {
                [self.localMuteUnreadCountsByChatID removeObjectForKey:chatKey];
            }
        }
        [item setNotificationsMuted:[self isChatItemEffectivelyMuted:item]];
    }
}

- (NSUInteger)localMuteUnreadAdjustment {
    NSUInteger total = 0;
    NSArray *chatKeys = [[self.localMuteUnreadCountsByChatID allKeys] copy];
    NSUInteger index = 0;
    for (index = 0; index < [chatKeys count]; index++) {
        NSString *chatKey = [chatKeys objectAtIndex:index];
        NSNumber *chatID = [NSNumber numberWithLongLong:[chatKey longLongValue]];
        if (![self isChatIDLocallyMuted:chatID]) {
            [self.localMuteUnreadCountsByChatID removeObjectForKey:chatKey];
            continue;
        }
        id unreadCount = [self.localMuteUnreadCountsByChatID objectForKey:chatKey];
        if ([unreadCount respondsToSelector:@selector(unsignedIntegerValue)]) {
            total += [unreadCount unsignedIntegerValue];
        }
    }
    [chatKeys release];
    return total;
}

- (BOOL)isChatIDMutedForNotifications:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return NO;
    }
    if ([self isChatIDLocallyMuted:chatID]) {
        return YES;
    }
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        NSNumber *itemChatID = [self notificationChatIDForChatItem:item];
        if ([itemChatID respondsToSelector:@selector(longLongValue)] && [itemChatID longLongValue] == [chatID longLongValue]) {
            return [item notificationsMuted];
        }
    }
    return NO;
}

- (void)setLocalNotificationMuteForChatID:(NSNumber *)chatID duration:(NSTimeInterval)duration {
    NSString *key = [self chatMuteDefaultsKeyForChatID:chatID];
    if ([key length] == 0) {
        return;
    }

    NSMutableDictionary *overrides = [self mutableChatMuteOverrides];
    if (duration == 0.0) {
        [overrides removeObjectForKey:key];
    } else if (duration < 0.0) {
        [overrides setObject:[NSNumber numberWithDouble:-1.0] forKey:key];
    } else {
        NSTimeInterval muteUntil = [[NSDate date] timeIntervalSince1970] + duration;
        [overrides setObject:[NSNumber numberWithDouble:muteUntil] forKey:key];
    }

    [[NSUserDefaults standardUserDefaults] setObject:overrides forKey:TGChatNotificationMuteOverridesDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self applyLocalNotificationMuteStateToItems:self.chatItems];
    [self.chatTableView reloadData];
    [self updateApplicationBadge];
}

- (NSUInteger)totalUnreadCountFromChatItems {
    NSUInteger total = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        if ([item notificationsMuted]) {
            continue;
        }
        NSNumber *unreadCount = [item unreadCount];
        if ([unreadCount respondsToSelector:@selector(integerValue)] && [unreadCount integerValue] > 0) {
            total += (NSUInteger)[unreadCount integerValue];
        }
    }
    return total;
}

- (void)updateApplicationBadge {
    NSUInteger unreadCount = self.hasAccountUnreadCount ? self.accountUnreadCount : [self totalUnreadCountFromChatItems];
    if (self.hasAccountUnreadCount) {
        NSUInteger localMuteAdjustment = [self localMuteUnreadAdjustment];
        unreadCount = (localMuteAdjustment < unreadCount) ? (unreadCount - localMuteAdjustment) : 0;
    }
    NSString *badge = nil;
    if (unreadCount > 999) {
        badge = @"999+";
    } else if (unreadCount > 0) {
        badge = [NSString stringWithFormat:@"%lu", (unsigned long)unreadCount];
    }
    NSString *dockBadge = TGUserDefaultBoolWithDefault(TGNotificationBadgeEnabledDefaultsKey, YES) ? badge : nil;
    [[[NSApplication sharedApplication] dockTile] setBadgeLabel:dockBadge];

    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        NSButton *button = [self.navigationButtons objectAtIndex:index];
        if ([button tag] != 0 || ![[button cell] isKindOfClass:[TGNavigationButtonCell class]]) {
            continue;
        }
        [(TGNavigationButtonCell *)[button cell] setBadgeText:badge];
        [button setNeedsDisplay:YES];
        break;
    }
}

- (void)refreshUpdateAvailabilityBadge {
    NSString *badgeText = self.updateAvailable ? @"1" : nil;
    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        NSButton *button = [self.navigationButtons objectAtIndex:index];
        if ([button tag] != 2 || ![[button cell] isKindOfClass:[TGNavigationButtonCell class]]) {
            continue;
        }
        [(TGNavigationButtonCell *)[button cell] setBadgeText:badgeText];
        [button setNeedsDisplay:YES];
        break;
    }
    [self.settingsUpdateDotView setHidden:(!self.updateAvailable ||
                                           ![(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionSettings])];
    NSRect buttonBounds = [self.settingsCheckUpdatesButton bounds];
    [self.settingsUpdateDotView setFrame:NSMakeRect(NSMaxX(buttonBounds) - 20.0,
                                                    floor((NSHeight(buttonBounds) - 10.0) / 2.0),
                                                    10.0,
                                                    10.0)];
    [self.settingsUpdateDotView setNeedsDisplay:YES];
}

- (void)setUpdateAvailableFromVersion:(NSString *)version {
    BOOL available = ([version isKindOfClass:[NSString class]] &&
                      TGVersionStringIsNewer(version, TGCurrentApplicationVersionString()));
    self.updateAvailable = available;
    self.availableUpdateVersion = available ? version : nil;
    if (available) {
        [[NSUserDefaults standardUserDefaults] setObject:version forKey:TGAvailableUpdateVersionDefaultsKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGAvailableUpdateVersionDefaultsKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self refreshUpdateAvailabilityBadge];
}

- (void)notificationSettingChanged:(id)sender {
    (void)sender;
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsNotificationsEnabledButton state] == NSOnState)
                                            forKey:TGNotificationsEnabledDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsNotificationSoundButton state] == NSOnState)
                                            forKey:TGNotificationSoundEnabledDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsNotificationBadgeButton state] == NSOnState)
                                            forKey:TGNotificationBadgeEnabledDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsNotificationPreviewButton state] == NSOnState)
                                            forKey:TGNotificationPreviewEnabledDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsNotificationsWhenActiveButton state] == NSOnState)
                                            forKey:TGNotificationsWhenActiveDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateApplicationBadge];
}

- (void)interfaceSettingChanged:(id)sender {
    (void)sender;
    BOOL drawerHidden = ([self.settingsDrawerHiddenButton state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:drawerHidden forKey:TGDrawerHiddenDefaultsKey];
    [[NSUserDefaults standardUserDefaults] setBool:([self.settingsTypingIndicatorsButton state] == NSOnState)
                                            forKey:TGTypingIndicatorsEnabledDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (drawerHidden) {
        self.drawerOpen = NO;
    }
    [self layoutContentView];
    [self updateVisibleSection];
    [self refreshSelectedChatHeaderDisplay];
}

- (void)refreshChatDisplayPreferenceControls {
    [self.settingsMessagesAsBlocksButton setState:(TGChatMessagesAsBlocksEnabled() ? NSOnState : NSOffState)];
    NSInteger level = TGChatMessageTextSizeLevel();
    [self.settingsChatTextSizeSlider setIntegerValue:level];
    [self.settingsChatTextSizeValueField setStringValue:TGLoc(TGChatMessageTextSizeLocalizationKeyForLevel(level))];
    [self.settingsChatTextSizeValueField setNeedsDisplay:YES];
}

- (void)chatDisplayPreferencesDidChange:(NSNotification *)notification {
    (void)notification;
    [self refreshChatDisplayPreferenceControls];
    [self.messageTableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [self.messageItems count])]];
    [self.messageTableView reloadData];
    [self scheduleInlineMediaPlaybackRefresh];
}

- (void)chatDisplaySettingChanged:(id)sender {
    if (sender == self.settingsMessagesAsBlocksButton) {
        TGSetChatMessagesAsBlocksEnabled([self.settingsMessagesAsBlocksButton state] == NSOnState);
    } else if (sender == self.settingsChatTextSizeSlider) {
        TGSetChatMessageTextSizeLevel(lround([self.settingsChatTextSizeSlider doubleValue]));
    }
    [self refreshChatDisplayPreferenceControls];
}

- (void)languageSelectionChanged:(id)sender {
    NSMenuItem *selectedItem = [self.settingsLanguagePopUpButton selectedItem];
    NSString *code = [selectedItem representedObject];
    if (![code isKindOfClass:[NSString class]] || [code length] == 0) {
        code = @"ru";
    }
    [self applyLanguageCode:code];
    (void)sender;
}

- (void)loginLanguageChanged:(id)sender {
    NSInteger tag = [sender respondsToSelector:@selector(tag)] ? [sender tag] : 0;
    NSString *code = (tag == 1) ? @"en" : ((tag == 2) ? @"be" : @"ru");
    [self applyLanguageCode:code];
}

- (void)applyLanguageCode:(NSString *)code {
    TGSetLanguageCode(code);
    if (self.aboutWindow) {
        [self.aboutWindow close];
        self.aboutWindow = nil;
    }
    NSString *visibleErrorKey = [self.loginErrorLocalizationKey copy];
    [self refreshLocalizedText];
    if ([visibleErrorKey length] > 0) {
        [self setLoginErrorWithLocalizationKey:visibleErrorKey];
    }
    [visibleErrorKey release];
    [self refreshProfileDisplay];
    if ([self.currentAuthState isEqualToString:@"ready"]) {
        [self rebuildDrawerFolderButtons];
    }
    if ([self.activeSessionsWindow isVisible]) {
        [self reloadActiveSessions:nil];
    }
    [self layoutContentView];
    [self updateVisibleSection];
    [self refreshThemeAppearance];
}

- (void)refreshLoginLanguageButtons {
    NSString *currentCode = TGLanguageCode();
    NSUInteger index = 0;
    for (index = 0; index < [self.loginLanguageButtons count]; index++) {
        NSButton *button = [self.loginLanguageButtons objectAtIndex:index];
        NSString *buttonCode = ([button tag] == 1) ? @"en" : (([button tag] == 2) ? @"be" : @"ru");
        BOOL selected = [buttonCode isEqualToString:currentCode];
        [button setBezelStyle:NSRoundedBezelStyle];
        [button setFont:(selected ? [NSFont boldSystemFontOfSize:11.0] : [NSFont systemFontOfSize:11.0])];
        [button setState:NSOffState];
        [button setNeedsDisplay:YES];
    }
}

- (void)chooseDownloadFolder:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];
    [panel setDirectoryURL:[NSURL fileURLWithPath:TGConfiguredDownloadFolderPath()]];
    NSInteger result = [panel runModal];
    if (result != NSOKButton) {
        return;
    }

    NSURL *url = [panel URL];
    NSString *path = [url path];
    if ([path length] == 0) {
        return;
    }

    TGSetConfiguredDownloadFolderPath(path);
    [self refreshDownloadFolderButtonTitle];
}

- (void)openProjectReleasesPage {
    NSURL *releaseURL = TGUpdateProjectReleasesURL();
    if (releaseURL) {
        [[NSWorkspace sharedWorkspace] openURL:releaseURL];
    }
}

- (NSString *)uniqueDownloadPathForUpdateFileName:(NSString *)fileName {
    NSString *folder = TGConfiguredDownloadFolderPath();
    if ([folder length] == 0) {
        folder = TGDefaultDownloadFolderPath();
    }
    NSString *safeName = ([fileName length] > 0) ? [fileName lastPathComponent] : @"Telegraphica-update.dmg";
    NSString *candidate = [folder stringByAppendingPathComponent:safeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
        return candidate;
    }

    NSString *base = [safeName stringByDeletingPathExtension];
    NSString *ext = [safeName pathExtension];
    NSUInteger index = 2;
    while (index < 1000) {
        NSString *numberedName = ([ext length] > 0)
            ? [NSString stringWithFormat:@"%@-%lu.%@", base, (unsigned long)index, ext]
            : [NSString stringWithFormat:@"%@-%lu", base, (unsigned long)index];
        candidate = [folder stringByAppendingPathComponent:numberedName];
        if (![[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
            return candidate;
        }
        index++;
    }
    return [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu", base, (unsigned long)[[NSDate date] timeIntervalSince1970]]];
}

- (void)downloadUpdateFromInfo:(NSDictionary *)releaseInfo {
    NSString *downloadURLString = TGUpdateDownloadURLStringFromInfo(releaseInfo);
    if ([downloadURLString length] == 0) {
        [self openProjectReleasesPage];
        return;
    }

    NSString *fileName = TGUpdateDownloadFileNameFromInfo(releaseInfo);
    NSString *targetPath = [self uniqueDownloadPathForUpdateFileName:fileName];
    NSString *folder = [targetPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];

    NSString *previousStatus = [[self.statusField stringValue] copy];
    [self.statusField setStringValue:@"Downloading update..."];
    [self.settingsCheckUpdatesButton setEnabled:NO];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: downloading %@ to %@.", downloadURLString, [targetPath lastPathComponent]]];

    NSDictionary *infoCopy = [releaseInfo retain];
    NSString *targetPathCopy = [targetPath copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSURL *downloadURL = [NSURL URLWithString:downloadURLString];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:downloadURL
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:120.0];
        [request setHTTPMethod:@"GET"];
        [request setValue:TGUpdateCheckUserAgentString() forHTTPHeaderField:@"User-Agent"];
        NSURLResponse *response = nil;
        NSData *data = nil;
        if (downloadURL) {
            data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&downloadError];
        }
        if (!downloadURL && !downloadError) {
            downloadError = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                                code:30
                                            userInfo:[NSDictionary dictionaryWithObject:@"Update download URL is invalid." forKey:NSLocalizedDescriptionKey]];
        }
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (statusCode < 200 || statusCode >= 300) {
                downloadError = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                                    code:statusCode
                                                userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Update download returned HTTP %ld.", (long)statusCode] forKey:NSLocalizedDescriptionKey]];
            }
        }
        if (!downloadError && [data length] == 0) {
            downloadError = [NSError errorWithDomain:@"TelegraphicaUpdate"
                                                code:31
                                            userInfo:[NSDictionary dictionaryWithObject:@"Downloaded update is empty." forKey:NSLocalizedDescriptionKey]];
        }

        BOOL wroteFile = NO;
        if (!downloadError) {
            wroteFile = [data writeToFile:targetPathCopy options:NSDataWritingAtomic error:&downloadError];
        }
        if (!downloadError && wroteFile) {
            NSString *expectedSHA256 = [infoCopy objectForKey:@"sha256"];
            if ([expectedSHA256 length] > 0) {
                NSError *shaError = nil;
                if (!TGUpdateFileMatchesSHA256(targetPathCopy, expectedSHA256, &shaError)) {
                    downloadError = [shaError retain];
                    [[NSFileManager defaultManager] removeItemAtPath:targetPathCopy error:NULL];
                    [downloadError autorelease];
                }
            }
        }

        NSString *errorMessage = [[downloadError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.statusField setStringValue:([previousStatus length] > 0 ? previousStatus : @"")];
            [self.settingsCheckUpdatesButton setEnabled:YES];
            if ([errorMessage length] > 0) {
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: download failed: %@.", errorMessage]];
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert setMessageText:TGLoc(@"update.download.failed.title")];
                [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"update.download.failed.message"), errorMessage]];
                [alert addButtonWithTitle:TGLoc(@"update.open")];
                [alert addButtonWithTitle:@"OK"];
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    [self openProjectReleasesPage];
                }
            } else {
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: downloaded update to %@.", targetPathCopy]];
                NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                [alert setMessageText:TGLoc(@"update.downloaded.title")];
                [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"update.downloaded.message"), targetPathCopy]];
                [alert addButtonWithTitle:TGLoc(@"update.downloaded.open")];
                [alert addButtonWithTitle:@"OK"];
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    BOOL openedInstaller = [[NSWorkspace sharedWorkspace] openFile:targetPathCopy];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: open installer %@ for %@.", openedInstaller ? @"requested" : @"failed", targetPathCopy]];
                    if (openedInstaller) {
                        [NSApp performSelector:@selector(terminate:) withObject:self afterDelay:0.35];
                    }
                }
            }
            [infoCopy release];
            [targetPathCopy release];
            [errorMessage release];
            [previousStatus release];
        });
        [pool drain];
    });
}

- (void)showUpdateCheckResult:(NSDictionary *)releaseInfo errorMessage:(NSString *)errorMessage manual:(BOOL)manual {
    if ([errorMessage length] > 0) {
        if (manual) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:TGLoc(@"settings.update")];
            [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"update.failed"), errorMessage]];
            [alert addButtonWithTitle:TGLoc(@"update.open")];
            [alert addButtonWithTitle:@"OK"];
            NSInteger result = [alert runModal];
            if (result == NSAlertFirstButtonReturn) {
                [self openProjectReleasesPage];
            }
        } else {
            [self appendDetail:[NSString stringWithFormat:@"Update check: %@", errorMessage]];
        }
        return;
    }

    NSString *remoteVersion = [releaseInfo objectForKey:@"version"];
    NSString *currentVersion = TGCurrentApplicationVersionString();
    if (![remoteVersion isKindOfClass:[NSString class]] || !TGVersionStringIsNewer(remoteVersion, currentVersion)) {
        [self setUpdateAvailableFromVersion:nil];
        if (manual) {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:TGLoc(@"update.none")];
            [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"update.noneMessage"), currentVersion]];
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
        }
        return;
    }

    [self setUpdateAvailableFromVersion:remoteVersion];
    if (!manual) {
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: version %@ is available; settings badge was updated.", remoteVersion]];
        return;
    }

    NSString *urlString = [releaseInfo objectForKey:@"url"];
    if ([urlString length] == 0) {
        urlString = TGUpdateProjectReleasesURLString();
    }
    NSString *downloadURLString = TGUpdateDownloadURLStringFromInfo(releaseInfo);
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"update.title")];
    [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"update.availableMessage"), remoteVersion]];
    if ([downloadURLString length] > 0) {
        [alert addButtonWithTitle:TGLoc(@"update.download")];
        [alert addButtonWithTitle:TGLoc(@"update.open")];
    } else {
        [alert addButtonWithTitle:TGLoc(@"update.open")];
    }
    [alert addButtonWithTitle:TGLoc(@"update.later")];
    NSInteger result = [alert runModal];
    if (result == NSAlertFirstButtonReturn) {
        if ([downloadURLString length] > 0) {
            [self downloadUpdateFromInfo:releaseInfo];
            return;
        }
        NSURL *releaseURL = [NSURL URLWithString:urlString];
        if (releaseURL) {
            [[NSWorkspace sharedWorkspace] openURL:releaseURL];
        } else {
            [self openProjectReleasesPage];
        }
    } else if ([downloadURLString length] > 0 && result == NSAlertSecondButtonReturn) {
        NSURL *releaseURL = [NSURL URLWithString:urlString];
        if (releaseURL) {
            [[NSWorkspace sharedWorkspace] openURL:releaseURL];
        } else {
            [self openProjectReleasesPage];
        }
    }
}

- (void)checkForUpdatesManual:(BOOL)manual {
    if (!manual) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval last = [[NSUserDefaults standardUserDefaults] doubleForKey:TGLastUpdateCheckDefaultsKey];
        if (last > 0.0 && (now - last) < (24.0 * 60.0 * 60.0)) {
            return;
        }
        [[NSUserDefaults standardUserDefaults] setDouble:now forKey:TGLastUpdateCheckDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    NSString *previousStatus = nil;
    if (manual) {
        previousStatus = [[self.statusField stringValue] copy];
        [self.statusField setStringValue:@"Checking for updates..."];
        [self.settingsCheckUpdatesButton setEnabled:NO];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *updateError = nil;
        NSDictionary *releaseInfo = [TGLatestUpdateInfoWithError(&updateError) retain];
        NSString *errorMessage = [[updateError localizedDescription] copy];
        if (releaseInfo) {
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Updater: update info loaded from %@; version=%@; asset=%@.",
                                          [releaseInfo objectForKey:@"source"] ? [releaseInfo objectForKey:@"source"] : @"unknown",
                                          [releaseInfo objectForKey:@"version"] ? [releaseInfo objectForKey:@"version"] : @"unknown",
                                          TGUpdateDownloadFileNameFromInfo(releaseInfo)]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (manual) {
                [self.statusField setStringValue:([previousStatus length] > 0 ? previousStatus : @"")];
                [self.settingsCheckUpdatesButton setEnabled:YES];
            }
            [self showUpdateCheckResult:releaseInfo errorMessage:errorMessage manual:manual];
            [releaseInfo release];
            [errorMessage release];
            [previousStatus release];
        });
        [pool drain];
    });
}

- (void)checkForUpdatesOnLaunch {
    [self checkForUpdatesManual:NO];
}

- (void)checkForUpdatesManually:(id)sender {
    (void)sender;
    [self checkForUpdatesManual:YES];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    (void)center;
    (void)notification;
    if (!TGUserDefaultBoolWithDefault(TGNotificationsEnabledDefaultsKey, YES)) {
        return NO;
    }
    if ([NSApp isActive]) {
        return TGUserDefaultBoolWithDefault(TGNotificationsWhenActiveDefaultsKey, NO);
    }
    return YES;
}

- (BOOL)selectChatFromNotificationWithChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return NO;
    }

    NSUInteger fallbackIndex = NSNotFound;
    NSUInteger topicIndex = NSNotFound;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        NSNumber *itemChatID = [item isForumTopic] ? [item parentChatID] : [item chatID];
        if (![itemChatID respondsToSelector:@selector(longLongValue)] || [itemChatID longLongValue] != [chatID longLongValue]) {
            continue;
        }
        if ([messageThreadID respondsToSelector:@selector(longLongValue)] &&
            [messageThreadID longLongValue] > 0 &&
            [item isForumTopic] &&
            [[item messageThreadID] respondsToSelector:@selector(longLongValue)] &&
            [[item messageThreadID] longLongValue] == [messageThreadID longLongValue]) {
            topicIndex = index;
            break;
        }
        if (fallbackIndex == NSNotFound) {
            fallbackIndex = index;
        }
    }

    NSUInteger targetIndex = (topicIndex != NSNotFound) ? topicIndex : fallbackIndex;
    if (targetIndex == NSNotFound && [self chatItemsContainForumTopicRows]) {
        [self removeForumTopicRowsPreservingChatID:chatID];
        return [self selectChatFromNotificationWithChatID:chatID messageThreadID:messageThreadID];
    }
    if (targetIndex == NSNotFound) {
        return NO;
    }

    BOOL alreadySelected = ([self.chatTableView selectedRow] == (NSInteger)targetIndex);
    [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:targetIndex] byExtendingSelection:NO];
    [self.chatTableView scrollRowToVisible:targetIndex];
    if (alreadySelected && self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]) {
        [self reloadMessagesForChatID:chatID interactive:NO];
    }
    [self clearUnreadCountForChatID:chatID messageThreadID:messageThreadID];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(markCurrentSelectionReadAfterNotification)
                                               object:nil];
    [self performSelector:@selector(markCurrentSelectionReadAfterNotification) withObject:nil afterDelay:1.2];
    return YES;
}

- (void)markCurrentSelectionReadAfterNotification {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        return;
    }
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *threadID = [self.selectedMessageThreadID retain];
    NSString *topicKind = [self.selectedMessageTopicKind copy];
    NSArray *items = [self.messageItems copy];
    [self clearUnreadCountForChatID:chatID messageThreadID:threadID];
    if ([items count] > 0) {
        [self markMessageItemsReadForChatID:chatID messageThreadID:threadID messageTopicKind:topicKind items:items];
    }
    [items release];
    [topicKind release];
    [threadID release];
    [chatID release];
}

- (void)openChatFromNotification:(NSUserNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    if (![userInfo isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSNumber *chatID = [userInfo objectForKey:@"chat_id"];
    NSNumber *messageThreadID = [userInfo objectForKey:@"message_thread_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    [self showWindow:nil];
    [[self window] makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    self.activeSection = TGSectionChats;
    [self updateNavigationButtonsForSection:TGSectionChats enabled:!self.controlsBusy];
    [self layoutContentView];
    [self updateVisibleSection];
    if (![self selectChatFromNotificationWithChatID:chatID messageThreadID:messageThreadID]) {
        self.pendingNotificationChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
            self.pendingNotificationThreadID = [NSNumber numberWithLongLong:[messageThreadID longLongValue]];
        } else {
            self.pendingNotificationThreadID = nil;
        }
        [self appendDetail:@"Notification selected a chat that is not loaded yet. Refreshing chats."];
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [self openChatFromNotification:notification];
    if ([center respondsToSelector:@selector(removeDeliveredNotification:)]) {
        [center removeDeliveredNotification:notification];
    }
}

- (NSString *)titleForChatID:(NSNumber *)chatID fallback:(NSString *)fallback {
    NSDictionary *info = [self notificationChatInfoForChatID:chatID];
    NSString *title = [info objectForKey:@"title"];
    if ([title length] > 0) {
        return title;
    }
    return fallback;
}

- (NSString *)avatarLocalPathForChatID:(NSNumber *)chatID {
    NSDictionary *info = [self notificationChatInfoForChatID:chatID];
    NSString *avatarPath = [info objectForKey:@"avatar_local_path"];
    return ([avatarPath length] > 0) ? avatarPath : nil;
}

- (NSImage *)notificationAvatarImageForChatID:(NSNumber *)chatID {
    NSString *avatarPath = [self avatarLocalPathForChatID:chatID];
    if ([avatarPath length] == 0) {
        return nil;
    }
    NSImage *avatarImage = TGImageWithCorrectOrientationFromFile(avatarPath);
    if (!avatarImage) {
        return nil;
    }
    [avatarImage setSize:NSMakeSize(64.0, 64.0)];
    return avatarImage;
}

- (void)presentNotificationForUpdateSummary:(NSDictionary *)summary {
    if (!TGUserDefaultBoolWithDefault(TGNotificationsEnabledDefaultsKey, YES)) {
        return;
    }
    if (![summary isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSString *direction = [summary objectForKey:@"direction"];
    if (![direction isEqualToString:@"Incoming"]) {
        return;
    }

    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    if ([self isChatIDMutedForNotifications:chatID]) {
        return;
    }
    NSDictionary *notificationChatInfo = [self notificationChatInfoForChatID:chatID];
    id serverMuted = [notificationChatInfo objectForKey:@"notifications_muted"];
    if ([serverMuted respondsToSelector:@selector(boolValue)] && [serverMuted boolValue]) {
        return;
    }
    NSString *title = [notificationChatInfo objectForKey:@"title"];
    if ([title length] == 0) {
        title = @"New message";
    }
    NSString *preview = [summary objectForKey:@"preview"];
    if (![preview isKindOfClass:[NSString class]] || [preview length] == 0) {
        preview = @"New message";
    }
    if (!TGUserDefaultBoolWithDefault(TGNotificationPreviewEnabledDefaultsKey, YES)) {
        preview = TGLoc(@"notification.hiddenPreview");
    }
    NSUserNotification *notification = [[[NSUserNotification alloc] init] autorelease];
    [notification setTitle:title];
    [notification setInformativeText:preview];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        [userInfo setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    }
    id messageID = [summary objectForKey:@"message_id"];
    if ([messageID respondsToSelector:@selector(longLongValue)]) {
        [userInfo setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
    }
    id messageThreadID = [summary objectForKey:@"message_thread_id"];
    if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
        [userInfo setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
    }
    if ([userInfo count] > 0) {
        [notification setUserInfo:userInfo];
    }
    if ([notification respondsToSelector:NSSelectorFromString(@"setContentImage:")]) {
        NSImage *avatarImage = [self notificationAvatarImageForChatID:chatID];
        if (avatarImage) {
            [notification setValue:avatarImage forKey:@"contentImage"];
        }
    }
    if (TGUserDefaultBoolWithDefault(TGNotificationSoundEnabledDefaultsKey, YES)) {
        [notification setSoundName:NSUserNotificationDefaultSoundName];
    }
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}
