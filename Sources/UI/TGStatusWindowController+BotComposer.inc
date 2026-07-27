- (void)setBotComposerVisible:(BOOL)visible animated:(BOOL)animated {
    if (self.botComposerVisible == visible) {
        [self.botActionButton setHidden:!visible];
        [self.botActionButton setAlphaValue:visible ? 1.0 : 0.0];
        [self updateSendControls];
        return;
    }

    NSRect oldButtonFrame = [self.botActionButton frame];
    NSRect oldBackgroundFrame = [self.sendTextFieldBackgroundView frame];
    NSRect oldTextFrame = [self.sendTextField frame];
    self.botComposerVisible = visible;
    [self layoutContentView];
    NSRect targetButtonFrame = [self.botActionButton frame];
    NSRect targetBackgroundFrame = [self.sendTextFieldBackgroundView frame];
    NSRect targetTextFrame = [self.sendTextField frame];

    if (!animated || ![[self window] isVisible]) {
        [self.botActionButton setHidden:!visible];
        [self.botActionButton setAlphaValue:visible ? 1.0 : 0.0];
        [self updateSendControls];
        return;
    }

    [self.botActionButton setHidden:NO];
    [self.sendTextFieldBackgroundView setFrame:oldBackgroundFrame];
    [self.sendTextField setFrame:oldTextFrame];
    if (visible) {
        NSRect startButtonFrame = targetButtonFrame;
        startButtonFrame.origin.x -= 7.0;
        [self.botActionButton setFrame:startButtonFrame];
        [self.botActionButton setAlphaValue:0.0];
    } else {
        [self.botActionButton setFrame:oldButtonFrame];
        [self.botActionButton setAlphaValue:1.0];
    }

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        [context setDuration:0.16];
        [[self.botActionButton animator] setFrame:targetButtonFrame];
        [[self.botActionButton animator] setAlphaValue:visible ? 1.0 : 0.0];
        [[self.sendTextFieldBackgroundView animator] setFrame:targetBackgroundFrame];
        [[self.sendTextField animator] setFrame:targetTextFrame];
    } completionHandler:^{
        [self.botActionButton setHidden:!visible];
        [self.botActionButton setAlphaValue:visible ? 1.0 : 0.0];
    }];
    [self updateSendControls];
}

- (void)refreshBotReplyMarkupFromMessages {
    NSDictionary *replyMarkup = nil;
    NSNumber *messageID = nil;
    NSInteger index = (NSInteger)[self.messageItems count] - 1;
    for (; index >= 0; index--) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        NSDictionary *markup = [[item replyMarkup] isKindOfClass:[NSDictionary class]]
            ? [item replyMarkup] : nil;
        if (!markup) {
            continue;
        }
        NSString *type = [[markup objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [markup objectForKey:@"@type"] : @"";
        if ([type isEqualToString:@"replyMarkupRemoveKeyboard"]) {
            break;
        }
        if ([type isEqualToString:@"replyMarkupShowKeyboard"]) {
            replyMarkup = markup;
            messageID = [item messageID];
            break;
        }
    }
    self.activeBotReplyMarkup = replyMarkup;
    self.activeBotReplyMarkupMessageID = messageID;
    [self setBotComposerVisible:(self.selectedBotUserID != nil || replyMarkup != nil) animated:YES];
}

- (void)refreshBotComposerForSelectedChat {
    self.botComposerGeneration++;
    NSUInteger generation = self.botComposerGeneration;
    NSNumber *chatID = [self.selectedChatID retain];
    self.selectedBotUserID = nil;
    self.activeBotReplyMarkup = nil;
    self.activeBotReplyMarkupMessageID = nil;
    [self refreshBotReplyMarkupFromMessages];
    if (!chatID) {
        [self setBotComposerVisible:NO animated:YES];
        return;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *summary = [[client chatDetailsSummaryForChatID:chatID timeout:8.0 error:NULL] retain];
        NSNumber *userID = [[summary objectForKey:@"user_id"] retain];
        NSDictionary *profile = [[summary objectForKey:@"profile"] isKindOfClass:[NSDictionary class]]
            ? [summary objectForKey:@"profile"] : nil;
        BOOL isBot = [[profile objectForKey:@"is_bot"] boolValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameChat = (self.selectedChatID &&
                             [self.selectedChatID longLongValue] == [chatID longLongValue]);
            if (generation == self.botComposerGeneration && sameChat) {
                self.selectedBotUserID = isBot ? userID : nil;
                [self refreshBotReplyMarkupFromMessages];
            }
            [userID release];
            [summary release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)openBotActionsFromComposer:(id)sender {
    (void)sender;
    if (!self.selectedChatID) {
        NSBeep();
        return;
    }
    if (self.activeBotReplyMarkup && self.activeBotReplyMarkupMessageID) {
        [[self.botKeyboardWindowController window] close];
        self.botKeyboardWindowController = [[[TGBotKeyboardWindowController alloc] initWithClient:self.client
                                                                                           chatID:self.selectedChatID
                                                                                        messageID:self.activeBotReplyMarkupMessageID
                                                                                      replyMarkup:self.activeBotReplyMarkup] autorelease];
        [self.botKeyboardWindowController showWindow:self];
        [[self.botKeyboardWindowController window] center];
        [[self.botKeyboardWindowController window] makeKeyAndOrderFront:self];
        return;
    }
    if (!self.selectedBotUserID) {
        NSBeep();
        return;
    }
    [[self.botInteractionWindowController window] close];
    self.botInteractionWindowController = [[[TGBotInteractionWindowController alloc] initWithClient:self.client
                                                                                              userID:self.selectedBotUserID
                                                                                              chatID:self.selectedChatID] autorelease];
    [self.botInteractionWindowController showWindow:self];
    [[self.botInteractionWindowController window] center];
    [[self.botInteractionWindowController window] makeKeyAndOrderFront:self];
    [self.botInteractionWindowController reloadBot];
}
