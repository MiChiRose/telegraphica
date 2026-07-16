- (void)openSelectedChatProfile:(id)sender {
    (void)sender;
    if (!self.selectedChatID) {
        return;
    }

    NSString *title = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Selected chat";
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = @"Selected chat";
    }

    NSMutableString *details = [NSMutableString string];
    if ([self.selectedChatTypeSummary length] > 0) {
        [details appendFormat:@"%@\n", self.selectedChatTypeSummary];
    }
    if ([self.selectedChatID respondsToSelector:@selector(longLongValue)]) {
        [details appendFormat:@"Chat ID: %lld", [self.selectedChatID longLongValue]];
    }
    if ([self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)]) {
        if ([details length] > 0) {
            [details appendString:@"\n"];
        }
        [details appendFormat:@"Topic ID: %lld", [self.selectedMessageThreadID longLongValue]];
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title];
    [alert setInformativeText:([details length] > 0) ? details : @"No additional profile fields are available yet."];
    [alert addButtonWithTitle:@"Close"];
    if ([self.selectedChatAvatarLocalPath length] > 0) {
        NSImage *avatarImage = [[[NSImage alloc] initWithContentsOfFile:self.selectedChatAvatarLocalPath] autorelease];
        if (avatarImage) {
            [alert setIcon:avatarImage];
        }
    }
    [alert runModal];
}

- (void)renderActiveSessionsSummary:(NSDictionary *)summary errorMessage:(NSString *)errorMessage {
    [self.activeSessionsRefreshButton setEnabled:YES];
    if ([errorMessage length] > 0 || ![summary isKindOfClass:[NSDictionary class]]) {
        NSString *message = [NSString stringWithFormat:TGLoc(@"settings.sessions.failed"),
                             ([errorMessage length] > 0 ? errorMessage : TGLoc(@"settings.sessions.unknownError"))];
        [self.activeSessionsStatusField setStringValue:message];
        [self.activeSessionsTextView setString:@""];
        return;
    }

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
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 70, 560, 342)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];
        NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:YES];
        [textView setDrawsBackground:NO];
        [scrollView setDocumentView:textView];
        [contentView addSubview:scrollView];
        self.activeSessionsTextView = textView;

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
        NSString *compatibilitySummary = [info objectForKey:@"TelegraphicaCompatibilitySummary"];
        if ([compatibilitySummary length] > 0) {
            versionText = [versionText stringByAppendingFormat:@" — %@", compatibilitySummary];
        }
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
        NSButton *authorButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 140, 340, 24)] autorelease];
        [authorButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.author") attributes:linkAttributes] autorelease]];
        [authorButton setBordered:NO];
        [authorButton setButtonType:NSMomentaryPushInButton];
        [authorButton setTarget:self];
        [authorButton setAction:@selector(openAuthorPage:)];
        [authorButton setToolTip:TGAuthorURLString];
        [[authorButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:authorButton];

        NSButton *projectButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 108, 340, 24)] autorelease];
        [projectButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.project") attributes:linkAttributes] autorelease]];
        [projectButton setBordered:NO];
        [projectButton setButtonType:NSMomentaryPushInButton];
        [projectButton setTarget:self];
        [projectButton setAction:@selector(openProjectPage:)];
        [projectButton setToolTip:TGProjectURLString];
        [[projectButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:projectButton];

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
