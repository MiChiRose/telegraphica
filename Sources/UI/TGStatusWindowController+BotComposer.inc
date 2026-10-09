- (void)setBotComposerVisible:(BOOL)visible animated:(BOOL)animated {
    BOOL chatsVisible = ([self.currentAuthState isEqualToString:@"ready"] &&
                         [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats] &&
                         !self.chatNavigationClosed);
    BOOL presentationVisible = visible && chatsVisible;
    BOOL wasHidden = [self.botActionButton isHidden];
    CGFloat wasAlpha = [self.botActionButton alphaValue];
    self.botComposerVisible = visible;
    [self layoutContentView];
    [self.botActionButton setHidden:wasHidden];
    [self.botActionButton setAlphaValue:wasAlpha];
    if (animated && chatsVisible) {
        TGSetViewVisibleAnimated(self.botActionButton, presentationVisible);
    } else {
        TGCancelViewVisibilityAnimation(self.botActionButton);
        [self.botActionButton setHidden:!presentationVisible];
        [self.botActionButton setAlphaValue:1.0];
    }
    if (!presentationVisible && self.botCommandPanelVisible) {
        [self setBotCommandPanelVisible:NO animated:NO];
    }
    [self updateSendControls];
}

- (void)setBotCommandPanelVisible:(BOOL)visible animated:(BOOL)animated {
    BOOL canShow = (visible && self.botComposerVisible && self.selectedBotUserID != nil &&
                    [self.currentAuthState isEqualToString:@"ready"] &&
                    [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats] &&
                    !self.chatNavigationClosed);
    BOOL wasHidden = [self.botCommandPanelView isHidden];
    CGFloat wasAlpha = [self.botCommandPanelView alphaValue];
    BOOL changed = self.botCommandPanelVisible != canShow;
    self.botCommandPanelVisible = canShow;
    [self layoutContentView];
    if (canShow && changed) {
        if (self.activeBotReplyMarkup) {
            [self.botCommandPanelView showReplyMarkup:self.activeBotReplyMarkup];
        } else {
            [self.botCommandPanelView loadCommandsForUserID:self.selectedBotUserID];
        }
    }
    [self.botCommandPanelView setHidden:wasHidden];
    [self.botCommandPanelView setAlphaValue:wasAlpha];
    if (animated) {
        TGSetViewVisibleAnimated(self.botCommandPanelView, canShow);
    } else {
        TGCancelViewVisibilityAnimation(self.botCommandPanelView);
        [self.botCommandPanelView setHidden:!canShow];
        [self.botCommandPanelView setAlphaValue:1.0];
    }
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
    if (!self.selectedBotUserID && self.botCommandPanelVisible) {
        [self setBotCommandPanelVisible:NO animated:YES];
    }
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
                for (id candidate in self.chatItems) {
                    if ([candidate isKindOfClass:[TGChatItem class]] &&
                        [[candidate chatID] respondsToSelector:@selector(longLongValue)] &&
                        [[candidate chatID] longLongValue] == [chatID longLongValue]) {
                        [(TGChatItem *)candidate setBot:isBot];
                    }
                }
                [self.chatTableView reloadData];
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
    if (self.selectedBotUserID) {
        [self setBotCommandPanelVisible:!self.botCommandPanelVisible animated:YES];
        return;
    }
    if (self.activeBotReplyMarkup && self.activeBotReplyMarkupMessageID) {
        [self setBotCommandPanelVisible:!self.botCommandPanelVisible animated:YES];
        return;
    }
    NSBeep();
}

- (void)botCommandChosen:(NSDictionary *)command {
    if ([[command objectForKey:@"tg_panel_kind"] isEqualToString:@"reply"]) {
        NSDictionary *type = [[command objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
            ? [command objectForKey:@"type"] : nil;
        NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [type objectForKey:@"@type"] : @"";
        NSString *text = [[command objectForKey:@"text"] isKindOfClass:[NSString class]]
            ? [command objectForKey:@"text"] : @"";
        if ([typeName isEqualToString:@"keyboardButtonTypeText"] || [typeName length] == 0) {
            [self.sendTextField setStringValue:text];
            [self setBotCommandPanelVisible:NO animated:YES];
            [self sendMessage:nil];
        } else {
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:TGLoc(@"bot.keyboard.title")];
            [alert setInformativeText:([typeName rangeOfString:@"WebApp"].location != NSNotFound)
                ? TGLoc(@"bot.webApp.officialOnly") : TGLoc(@"bot.personalData.manualOnly")];
            [alert addButtonWithTitle:TGLoc(@"ok")];
            [alert runModal];
        }
        return;
    }
    NSString *name = [[command objectForKey:@"command"] isKindOfClass:[NSString class]]
        ? [command objectForKey:@"command"] : @"";
    if ([name length] == 0) {
        NSBeep();
        return;
    }
    [self.sendTextField setStringValue:[@"/" stringByAppendingString:name]];
    [self setBotCommandPanelVisible:NO animated:YES];
    [[self window] makeFirstResponder:self.sendTextField];
}
