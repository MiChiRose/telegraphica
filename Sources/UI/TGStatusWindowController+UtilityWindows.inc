static NSNumber *TGActiveSessionSelectableIdentifier(NSDictionary *session) {
    if (![session isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id rawID = [session objectForKey:@"id"];
    if (![rawID respondsToSelector:@selector(longLongValue)] || [rawID longLongValue] == 0) {
        rawID = [session objectForKey:@"session_id"];
    }
    if (![rawID respondsToSelector:@selector(longLongValue)] || [rawID longLongValue] == 0) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[rawID longLongValue]];
}

static NSString *TGActiveSessionMenuTitle(NSDictionary *session, NSString *unknownDevice) {
    NSString *device = [session objectForKey:@"device_model"];
    NSString *application = [session objectForKey:@"application_name"];
    NSString *platform = [session objectForKey:@"platform"];
    NSString *location = [session objectForKey:@"location"];
    NSString *title = ([device length] > 0) ? device : (([application length] > 0) ? application : unknownDevice);
    NSMutableArray *details = [NSMutableArray array];
    if ([application length] > 0 && ![application isEqualToString:title]) {
        [details addObject:application];
    }
    if ([platform length] > 0 && ![platform isEqualToString:title]) {
        [details addObject:platform];
    }
    if ([location length] > 0) {
        [details addObject:location];
    }
    if ([details count] == 0) {
        return title;
    }
    return [NSString stringWithFormat:@"%@ — %@", title, [details componentsJoinedByString:@", "]];
}

static NSString *TGActiveSessionTableTitle(NSDictionary *session, NSString *unknownDevice, NSString *languageCode) {
    NSString *device = [session objectForKey:@"device_model"];
    NSString *application = [session objectForKey:@"application_name"];
    NSString *platform = [session objectForKey:@"platform"];
    NSString *systemVersion = [session objectForKey:@"system_version"];
    NSString *location = [session objectForKey:@"location"];
    NSString *title = ([device length] > 0) ? device : (([application length] > 0) ? application : unknownDevice);
    NSMutableArray *details = [NSMutableArray array];
    if ([application length] > 0 && ![application isEqualToString:title]) {
        [details addObject:application];
    }
    if ([platform length] > 0) {
        NSString *platformText = platform;
        if ([systemVersion length] > 0) {
            platformText = [platformText stringByAppendingFormat:@" %@", systemVersion];
        }
        if (![platformText isEqualToString:title]) {
            [details addObject:platformText];
        }
    }
    if ([location length] > 0) {
        [details addObject:location];
    }
    NSString *lastActive = [TGActiveSessionsPresentation dateTextForTimestamp:[session objectForKey:@"last_active_date"]
                                                                 languageCode:languageCode];
    if ([lastActive length] > 0) {
        [details addObject:lastActive];
    }
    if ([details count] == 0) {
        return title;
    }
    return [NSString stringWithFormat:@"%@\n%@", title, [details componentsJoinedByString:@" · "]];
}

- (void)openSelectedChatProfile:(id)sender {
    [self openMediaCenter:sender];
}

- (void)renderActiveSessionsSummary:(NSDictionary *)summary errorMessage:(NSString *)errorMessage {
    [self.activeSessionsRefreshButton setEnabled:YES];
    [self.activeSessionsTerminateButton setEnabled:NO];
    [self.activeSessionsTerminatePopup removeAllItems];
    [self.activeSessionsTerminatePopup addItemWithTitle:TGLoc(@"settings.sessions.selectDevice")];
    [[[self.activeSessionsTerminatePopup menu] itemAtIndex:0] setRepresentedObject:nil];
    self.activeSessionsSelectableSessions = [NSArray array];
    [self.activeSessionsTableView reloadData];
    self.activeSessionsSummary = nil;
    if ([errorMessage length] > 0 || ![summary isKindOfClass:[NSDictionary class]]) {
        NSString *message = [NSString stringWithFormat:TGLoc(@"settings.sessions.failed"),
                             ([errorMessage length] > 0 ? errorMessage : TGLoc(@"settings.sessions.unknownError"))];
        [self.activeSessionsStatusField setStringValue:message];
        [self.activeSessionsTextView setString:@""];
        return;
    }
    self.activeSessionsSummary = summary;

    TGActiveSessionsLocalizationBlock localize = ^NSString *(NSString *key) {
        return TGLoc(key);
    };
    [self.activeSessionsStatusField setStringValue:[TGActiveSessionsPresentation statusTextForSummary:summary
                                                                                              localize:localize]];
    NSAttributedString *output = [TGActiveSessionsPresentation detailsTextForSummary:summary
                                                                         languageCode:TGLanguageCode()
                                                                             localize:localize
                                                                            textColor:TGClassicInkColor()
                                                                           mutedColor:TGClassicMutedInkColor()];
    [[self.activeSessionsTextView textStorage] setAttributedString:output];

    NSArray *sessions = [summary objectForKey:@"sessions"];
    NSMutableArray *selectableSessions = [NSMutableArray array];
    NSUInteger sessionsWithIdentifier = 0;
    NSUInteger currentSessions = 0;
    if ([sessions isKindOfClass:[NSArray class]]) {
        NSUInteger index = 0;
        for (index = 0; index < [sessions count]; index++) {
            NSDictionary *session = [sessions objectAtIndex:index];
            if (![session isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSNumber *sessionID = TGActiveSessionSelectableIdentifier(session);
            if (![sessionID respondsToSelector:@selector(longLongValue)] || [sessionID longLongValue] == 0) {
                continue;
            }
            sessionsWithIdentifier++;
            if ([[session objectForKey:@"is_current"] boolValue]) {
                currentSessions++;
                continue;
            }
            NSString *title = TGActiveSessionMenuTitle(session, TGLoc(@"settings.sessions.unknownDevice"));
            [selectableSessions addObject:session];
            [self.activeSessionsTerminatePopup addItemWithTitle:title];
            [[[self.activeSessionsTerminatePopup menu] itemAtIndex:([[self.activeSessionsTerminatePopup itemArray] count] - 1)] setRepresentedObject:sessionID];
        }
    }
    self.activeSessionsSelectableSessions = selectableSessions;
    [self.activeSessionsTableView reloadData];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Active Sessions: received=%lu with_id=%lu current=%lu selectable=%lu.",
                                  ([sessions isKindOfClass:[NSArray class]] ? (unsigned long)[sessions count] : 0UL),
                                  (unsigned long)sessionsWithIdentifier,
                                  (unsigned long)currentSessions,
                                  (unsigned long)[selectableSessions count]]];
    BOOL hasTerminableSessions = ([[self.activeSessionsTerminatePopup itemArray] count] > 1);
    if (hasTerminableSessions) {
        [self.activeSessionsTerminatePopup selectItemAtIndex:1];
        [self.activeSessionsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    } else {
        [self.activeSessionsTerminatePopup selectItemAtIndex:0];
        [self.activeSessionsTableView deselectAll:nil];
    }
    [self.activeSessionsTerminatePopup setEnabled:hasTerminableSessions];
    [self.activeSessionsTerminateButton setEnabled:hasTerminableSessions];
}

- (void)terminateSelectedActiveSession:(id)sender {
    (void)sender;
    NSMenuItem *selectedItem = [self.activeSessionsTerminatePopup selectedItem];
    NSNumber *sessionID = [selectedItem representedObject];
    NSInteger selectedRow = [self.activeSessionsTableView selectedRow];
    if ((![sessionID respondsToSelector:@selector(longLongValue)] || [sessionID longLongValue] == 0) &&
        selectedRow >= 0 && (NSUInteger)selectedRow < [self.activeSessionsSelectableSessions count]) {
        id selectedSession = [self.activeSessionsSelectableSessions objectAtIndex:(NSUInteger)selectedRow];
        if ([selectedSession isKindOfClass:[NSDictionary class]]) {
            sessionID = TGActiveSessionSelectableIdentifier((NSDictionary *)selectedSession);
            NSString *fallbackTitle = TGActiveSessionMenuTitle((NSDictionary *)selectedSession, TGLoc(@"settings.sessions.unknownDevice"));
            NSInteger menuIndex = selectedRow + 1;
            if (menuIndex > 0 && menuIndex < (NSInteger)[[self.activeSessionsTerminatePopup itemArray] count]) {
                [self.activeSessionsTerminatePopup selectItemAtIndex:menuIndex];
                selectedItem = [self.activeSessionsTerminatePopup selectedItem];
            } else if ([fallbackTitle length] > 0) {
                selectedItem = [[[NSMenuItem alloc] initWithTitle:fallbackTitle action:NULL keyEquivalent:@""] autorelease];
            }
        }
    }
    if (![sessionID respondsToSelector:@selector(longLongValue)] || [sessionID longLongValue] == 0) {
        NSBeep();
        return;
    }
    BOOL foundFreshTerminableSession = NO;
    NSArray *sessions = [self.activeSessionsSummary objectForKey:@"sessions"];
    if ([sessions isKindOfClass:[NSArray class]]) {
        NSUInteger index = 0;
        for (index = 0; index < [sessions count]; index++) {
            NSDictionary *session = [sessions objectAtIndex:index];
            if (![session isKindOfClass:[NSDictionary class]] || [[session objectForKey:@"is_current"] boolValue]) {
                continue;
            }
            NSNumber *knownSessionID = TGActiveSessionSelectableIdentifier(session);
            if ([knownSessionID respondsToSelector:@selector(longLongValue)] &&
                [knownSessionID longLongValue] == [sessionID longLongValue]) {
                foundFreshTerminableSession = YES;
                break;
            }
        }
    }
    if (!foundFreshTerminableSession) {
        [self.activeSessionsStatusField setStringValue:TGLoc(@"settings.sessions.stale")];
        [self reloadActiveSessions:nil];
        NSBeep();
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"settings.sessions.terminate.title")];
    [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"settings.sessions.terminate.message"),
                               [selectedItem title] ? [selectedItem title] : TGLoc(@"settings.sessions.unknownDevice")]];
    [alert addButtonWithTitle:TGLoc(@"settings.sessions.terminate")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSUInteger requestGeneration = self.activeSessionsRequestGeneration + 1;
    self.activeSessionsRequestGeneration = requestGeneration;
    [self.activeSessionsStatusField setStringValue:TGLoc(@"settings.sessions.terminating")];
    [self.activeSessionsRefreshButton setEnabled:NO];
    [self.activeSessionsTerminateButton setEnabled:NO];
    [self.activeSessionsTerminatePopup setEnabled:NO];

    TGTDLibClient *client = [self.client retain];
    NSNumber *sessionIDCopy = [[NSNumber numberWithLongLong:[sessionID longLongValue]] retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *terminateError = nil;
        BOOL ok = [client terminateActiveSessionWithID:sessionIDCopy timeout:8.0 error:&terminateError];
        NSString *errorMessage = [[terminateError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestGeneration == self.activeSessionsRequestGeneration &&
                self.client == client &&
                [self.currentAuthState isEqualToString:@"ready"]) {
                if (ok) {
                    [self.activeSessionsStatusField setStringValue:TGLoc(@"settings.sessions.terminate.done")];
                    [self reloadActiveSessions:nil];
                } else {
                    NSString *message = [NSString stringWithFormat:TGLoc(@"settings.sessions.terminate.failed"),
                                         ([errorMessage length] > 0 ? errorMessage : TGLoc(@"settings.sessions.unknownError"))];
                    [self.activeSessionsStatusField setStringValue:message];
                    [self.activeSessionsRefreshButton setEnabled:YES];
                    [self.activeSessionsTerminateButton setEnabled:([[self.activeSessionsTerminatePopup itemArray] count] > 1)];
                    [self.activeSessionsTerminatePopup setEnabled:([[self.activeSessionsTerminatePopup itemArray] count] > 1)];
                }
            }
            [errorMessage release];
            [sessionIDCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)activeSessionsTerminatePopupSelectionDidChange:(id)sender {
    (void)sender;
    NSInteger popupIndex = [self.activeSessionsTerminatePopup indexOfSelectedItem];
    if (popupIndex > 0 && (NSUInteger)(popupIndex - 1) < [self.activeSessionsSelectableSessions count]) {
        [self.activeSessionsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)(popupIndex - 1)] byExtendingSelection:NO];
        [self.activeSessionsTableView scrollRowToVisible:(popupIndex - 1)];
        [self.activeSessionsTerminateButton setEnabled:YES];
    } else {
        [self.activeSessionsTableView deselectAll:nil];
        [self.activeSessionsTerminateButton setEnabled:NO];
    }
}

- (void)reloadActiveSessions:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self.activeSessionsRefreshButton setEnabled:YES];
        return;
    }
    NSUInteger requestGeneration = self.activeSessionsRequestGeneration + 1;
    self.activeSessionsRequestGeneration = requestGeneration;
    [self.activeSessionsStatusField setStringValue:TGLoc(@"settings.sessions.loading")];
    [self.activeSessionsRefreshButton setEnabled:NO];
    [self.activeSessionsTextView setString:@""];
    self.activeSessionsSelectableSessions = [NSArray array];
    [self.activeSessionsTableView reloadData];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sessionsError = nil;
        NSDictionary *summary = [[client activeSessionsSummaryWithTimeout:8.0 error:&sessionsError] retain];
        NSString *errorMessage = [[sessionsError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestGeneration == self.activeSessionsRequestGeneration &&
                self.client == client &&
                [self.currentAuthState isEqualToString:@"ready"]) {
                [self renderActiveSessionsSummary:summary errorMessage:errorMessage];
            } else if (requestGeneration == self.activeSessionsRequestGeneration) {
                [self.activeSessionsRefreshButton setEnabled:YES];
            }
            [summary release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)showActiveSessionsWindow:(id)sender {
    (void)sender;
    if (!self.activeSessionsWindow) {
        NSRect frame = NSMakeRect(0, 0, 620, 480);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:TGLoc(@"settings.section.sessions")];
        [window setMinSize:NSMakeSize(500.0, 360.0)];
        [window setReleasedWhenClosed:NO];
        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        NSTextField *statusField = [self labelWithFrame:NSMakeRect(24, 438, 440, 20)
                                                    text:TGLoc(@"settings.sessions.loading")
                                                    font:[NSFont systemFontOfSize:12.0]];
        [self applyMutedLabelStyle:statusField];
        [statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [contentView addSubview:statusField];
        self.activeSessionsStatusField = statusField;

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 58, 584, 366)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 112, 560, 300)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];
        NSTableView *sessionsTable = [[[NSTableView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [sessionsTable setHeaderView:nil];
        [sessionsTable setRowHeight:58.0];
        [sessionsTable setAllowsMultipleSelection:NO];
        [sessionsTable setAllowsEmptySelection:NO];
        [sessionsTable setUsesAlternatingRowBackgroundColors:NO];
        [sessionsTable setBackgroundColor:[NSColor clearColor]];
        [sessionsTable setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
        [sessionsTable setGridColor:TGClassicTableGridColor()];
        [sessionsTable setDelegate:self];
        [sessionsTable setDataSource:self];
        NSTableColumn *sessionColumn = [[[NSTableColumn alloc] initWithIdentifier:@"active_session"] autorelease];
        [sessionColumn setWidth:NSWidth([[scrollView contentView] bounds])];
        [sessionColumn setResizingMask:NSTableColumnAutoresizingMask];
        NSTextFieldCell *sessionCell = [[[NSTextFieldCell alloc] initTextCell:@""] autorelease];
        [sessionCell setFont:[NSFont systemFontOfSize:12.0]];
        [sessionCell setLineBreakMode:NSLineBreakByTruncatingTail];
        [sessionCell setWraps:YES];
        [sessionCell setScrollable:NO];
        [sessionColumn setDataCell:sessionCell];
        [sessionsTable addTableColumn:sessionColumn];
        [scrollView setDocumentView:sessionsTable];
        [contentView addSubview:scrollView];
        self.activeSessionsTableView = sessionsTable;
        NSTextView *textView = [[[NSTextView alloc] initWithFrame:NSZeroRect] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:NO];
        [textView setDrawsBackground:NO];
        self.activeSessionsTextView = textView;

        NSPopUpButton *terminatePopup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(30, 70, 402, 28) pullsDown:NO] autorelease];
        [terminatePopup setEnabled:NO];
        [terminatePopup setTarget:self];
        [terminatePopup setAction:@selector(activeSessionsTerminatePopupSelectionDidChange:)];
        [terminatePopup setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
        [contentView addSubview:terminatePopup];
        self.activeSessionsTerminatePopup = terminatePopup;

        NSButton *terminateButton = [[[NSButton alloc] initWithFrame:NSMakeRect(444, 70, 146, 28)] autorelease];
        [terminateButton setTitle:TGLoc(@"settings.sessions.terminate")];
        [terminateButton setTarget:self];
        [terminateButton setAction:@selector(terminateSelectedActiveSession:)];
        [self applyDestructiveSettingsButtonStyle:terminateButton];
        [terminateButton setImage:TGTemplateIconAssetImage(@"running",
                                                           NSMakeSize(16.0, 16.0),
                                                           [NSColor colorWithCalibratedRed:0.920 green:0.140 blue:0.140 alpha:1.0],
                                                           1.0)];
        [terminateButton setEnabled:NO];
        [terminateButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:terminateButton];
        self.activeSessionsTerminateButton = terminateButton;

        NSButton *refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(350, 18, 120, 30)] autorelease];
        [refreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
        [refreshButton setTarget:self];
        [refreshButton setAction:@selector(reloadActiveSessions:)];
        [self applyUtilityButtonStyle:refreshButton];
        [refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:refreshButton];
        self.activeSessionsRefreshButton = refreshButton;

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(482, 18, 120, 30)];
        [closeButton setTitle:TGLoc(@"close")];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];
        self.activeSessionsCloseButton = closeButton;
        self.activeSessionsWindow = window;
    }
    [self.activeSessionsWindow setTitle:TGLoc(@"settings.section.sessions")];
    [self.activeSessionsRefreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
    [self.activeSessionsTerminateButton setTitle:TGLoc(@"settings.sessions.terminate")];
    [self.activeSessionsWindow center];
    [self.activeSessionsWindow makeKeyAndOrderFront:nil];
    [self reloadActiveSessions:nil];
}

- (void)refreshProfile:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy) {
        [self.profileRefreshButton setEnabled:YES];
        return;
    }
    self.profileSummaryLoaded = NO;
    [self.profileRefreshButton setEnabled:NO];
    [self reloadProfileSummaryIfReady];
}

- (void)showAppearanceWindow:(id)sender {
    (void)sender;
    if (!self.appearanceWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 260);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Appearance"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 72, 420, 124)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [contentView addSubview:cardView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(34, 214, 220, 22)
                                                  text:@"Appearance"
                                                  font:[NSFont boldSystemFontOfSize:14.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSTextField *themeLabel = [self labelWithFrame:NSMakeRect(54, 142, 86, 22)
                                                  text:@"Theme"
                                                  font:[NSFont systemFontOfSize:13.0]];
        [contentView addSubview:themeLabel];

        NSPopUpButton *themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(142, 136, 282, 30) pullsDown:NO] autorelease];
        NSArray *themeIdentifiers = TGThemeIdentifiers();
        NSUInteger themeIndex = 0;
        for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
            NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
            [themePopUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
            [[themePopUpButton lastItem] setRepresentedObject:themeIdentifier];
        }
        [themePopUpButton setTarget:self];
        [themePopUpButton setAction:@selector(themeSelectionChanged:)];
        [themePopUpButton setAutoresizingMask:NSViewMaxYMargin];
        [contentView addSubview:themePopUpButton];
        self.appearanceThemePopUpButton = themePopUpButton;

        NSTextField *hintField = [self labelWithFrame:NSMakeRect(54, 98, 370, 22)
                                                 text:@"Theme changes apply immediately."
                                                 font:[NSFont systemFontOfSize:12.0]];
        [self applyMutedLabelStyle:hintField];
        [contentView addSubview:hintField];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(330, 22, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.appearanceWindow = window;
    }

    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [self.appearanceWindow center];
    [self.appearanceWindow makeKeyAndOrderFront:nil];
}

- (void)showStorageUsageWindow:(id)sender {
    if (!self.storageUsageWindowController) {
        self.storageUsageWindowController = [[[TGStorageUsageWindowController alloc] initWithClient:self.client] autorelease];
    }
    [self.storageUsageWindowController showWindow:sender];
}

- (void)showLogsWindow:(id)sender {
    (void)sender;
    if (!self.logsWindow) {
        NSRect frame = NSMakeRect(0, 0, 660, 440);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Diagnostic Logs"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 58, 624, 354)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 70, 600, 330)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];

        NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:YES];
        [textView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
        [textView setTextColor:TGClassicMutedInkColor()];
        [textView setBackgroundColor:TGClassicTablePaperColor()];
        [scrollView setDocumentView:textView];
        [contentView addSubview:scrollView];
        self.logsWindowDetailsView = textView;

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(22, 414, 300, 20)
                                                  text:@"Diagnostic Logs"
                                                  font:[NSFont boldSystemFontOfSize:13.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSButton *checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(390, 18, 120, 30)] autorelease];
        [checkButton setTitle:@"Check"];
        [checkButton setTarget:self];
        [checkButton setAction:@selector(checkTDLib:)];
        [self applyUtilityButtonStyle:checkButton];
        [checkButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:checkButton];
        self.logsCheckButton = checkButton;

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(522, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.logsWindow = window;
    }

    [self.logsCheckButton setEnabled:!self.controlsBusy];
    NSMutableString *logText = [NSMutableString string];
    NSString *visibleDetails = self.detailsView ? [self.detailsView string] : @"";
    if ([visibleDetails length] > 0) {
        [logText appendString:visibleDetails];
    }
    NSString *runtimeLog = [[TGLogger sharedLogger] currentLog];
    if ([runtimeLog length] > 0) {
        if ([logText length] > 0) {
            [logText appendString:@"\n"];
        }
        [logText appendString:@"Runtime Component Logs\n"];
        [logText appendString:runtimeLog];
        [logText appendString:@"\n"];
    }
    [self.logsWindowDetailsView setString:logText];
    NSRange endRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
    [self.logsWindowDetailsView scrollRangeToVisible:endRange];
    [self.logsWindow center];
    [self.logsWindow makeKeyAndOrderFront:nil];
}

- (void)showAboutWindow:(id)sender {
    (void)sender;
    if (!self.aboutWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 440);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:TGLoc(@"about.title")];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 54, 420, 352)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSImageView *iconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(190, 280, 100, 100)] autorelease];
        NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
        if (!appIcon) {
            appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
        }
        [iconView setImage:appIcon];
        [iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [iconView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:iconView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(70, 242, 340, 30)
                                                  text:@"Telegraphica"
                                                  font:[NSFont boldSystemFontOfSize:22.0]];
        [titleField setAlignment:NSCenterTextAlignment];
        [contentView addSubview:titleField];

        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [info objectForKey:@"CFBundleVersion"];
        NSString *versionText = [NSString stringWithFormat:TGLoc(@"about.version"), version ? version : @"0.1.0", build ? build : @"0.1.0"];
        NSTextField *versionField = [self labelWithFrame:NSMakeRect(70, 212, 340, 22)
                                                    text:versionText
                                                    font:[NSFont systemFontOfSize:12.0]];
        [versionField setAlignment:NSCenterTextAlignment];
        [self applyMutedLabelStyle:versionField];
        [contentView addSubview:versionField];

        NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@. %@", TGCurrentYearString(), TGLoc(@"about.rights")];
        NSTextField *copyrightField = [self labelWithFrame:NSMakeRect(60, 178, 360, 22)
                                                      text:copyrightText
                                                      font:[NSFont systemFontOfSize:12.0]];
        [copyrightField setAlignment:NSCenterTextAlignment];
        [[copyrightField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [self applyMutedLabelStyle:copyrightField];
        [contentView addSubview:copyrightField];

        NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                        TGClassicLinkColor(), NSForegroundColorAttributeName,
                                        [NSNumber numberWithInteger:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
                                        nil];
        NSButton *authorButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 142, 340, 24)] autorelease];
        [authorButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.author") attributes:linkAttributes] autorelease]];
        [authorButton setImage:TGTemplateIconAssetImage(@"instagram", NSMakeSize(16.0, 16.0), TGClassicLinkColor(), 1.0)];
        [authorButton setImagePosition:NSImageLeft];
        [authorButton setBordered:NO];
        [authorButton setButtonType:NSMomentaryPushInButton];
        [authorButton setTarget:self];
        [authorButton setAction:@selector(openAuthorPage:)];
        [authorButton setToolTip:TGAuthorURLString];
        [[authorButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:authorButton];

        NSButton *projectButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 112, 340, 24)] autorelease];
        [projectButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.project") attributes:linkAttributes] autorelease]];
        [projectButton setImage:TGTemplateIconAssetImage(@"github", NSMakeSize(16.0, 16.0), TGClassicLinkColor(), 1.0)];
        [projectButton setImagePosition:NSImageLeft];
        [projectButton setBordered:NO];
        [projectButton setButtonType:NSMomentaryPushInButton];
        [projectButton setTarget:self];
        [projectButton setAction:@selector(openProjectPage:)];
        [projectButton setToolTip:TGProjectURLString];
        [[projectButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:projectButton];

        NSButton *channelButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 82, 340, 24)] autorelease];
        [channelButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.channel") attributes:linkAttributes] autorelease]];
        [channelButton setImage:TGTemplateIconAssetImage(@"telegram", NSMakeSize(16.0, 16.0), TGClassicLinkColor(), 1.0)];
        [channelButton setImagePosition:NSImageLeft];
        [channelButton setBordered:NO];
        [channelButton setButtonType:NSMomentaryPushInButton];
        [channelButton setTarget:self];
        [channelButton setAction:@selector(openChannelPage:)];
        [channelButton setToolTip:TGChannelURLString];
        [[channelButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:channelButton];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(180, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.aboutWindow = window;
    }

    [self.aboutWindow center];
    [self.aboutWindow makeKeyAndOrderFront:nil];
}

- (void)openProjectPage:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:TGProjectURLString]];
}

- (void)openAuthorPage:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:TGAuthorURLString]];
}

- (void)openChannelPage:(id)sender {
    (void)sender;
    [self.aboutWindow orderOut:nil];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:TGChannelURLString]];
}

- (void)themeSelectionChanged:(id)sender {
    NSPopUpButton *sourcePopUpButton = [sender isKindOfClass:[NSPopUpButton class]] ? (NSPopUpButton *)sender : self.themePopUpButton;
    NSMenuItem *selectedItem = [sourcePopUpButton selectedItem];
    NSString *themeIdentifier = [selectedItem representedObject];
    if (!TGThemeIdentifierIsValid(themeIdentifier)) {
        themeIdentifier = TGThemeIdentifierVKBlue;
    }
    TGSetActiveThemeIdentifier(themeIdentifier);
    [[NSUserDefaults standardUserDefaults] setObject:themeIdentifier forKey:TGThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self selectThemePopUpItemForIdentifier:themeIdentifier];
    [self refreshThemeAppearance];
    [self appendDetail:[NSString stringWithFormat:@"Theme changed: %@", TGThemeDisplayNameForIdentifier(themeIdentifier)]];
}

- (void)themeCategorySelectionChanged:(id)sender {
    NSPopUpButton *sourcePopUpButton = [sender isKindOfClass:[NSPopUpButton class]] ? (NSPopUpButton *)sender : self.themeCategoryPopUpButton;
    NSString *categoryIdentifier = [[sourcePopUpButton selectedItem] representedObject];
    NSArray *themeIdentifiers = TGThemeIdentifiersForCategory(categoryIdentifier);
    if ([themeIdentifiers count] == 0) {
        return;
    }

    NSString *currentThemeIdentifier = TGCurrentThemeIdentifier();
    NSString *selectedThemeIdentifier = currentThemeIdentifier;
    if (![themeIdentifiers containsObject:selectedThemeIdentifier]) {
        selectedThemeIdentifier = [themeIdentifiers objectAtIndex:0];
    }

    [self populateThemePopUpButton:self.themePopUpButton
             forCategoryIdentifier:categoryIdentifier
                selectedIdentifier:selectedThemeIdentifier];
    if (![selectedThemeIdentifier isEqualToString:currentThemeIdentifier]) {
        [self themeSelectionChanged:self.themePopUpButton];
    }
}
