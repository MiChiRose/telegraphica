- (void)buildChatSearchWindowIfNeeded {
    if (self.chatSearchWindow) {
        return;
    }

    self.chatSearchWindow = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 460, 340)
                                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO] autorelease];
    [self.chatSearchWindow setTitle:@"Search chats"];
    [self.chatSearchWindow setReleasedWhenClosed:NO];
    [self.chatSearchWindow setBackgroundColor:[NSColor colorWithCalibratedRed:0.93 green:0.96 blue:0.98 alpha:1.0]];

    TGChatSearchPanelView *panelView = [[[TGChatSearchPanelView alloc] initWithFrame:NSMakeRect(0, 0, 460, 340)] autorelease];
    [panelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [panelView setTarget:self];
    [panelView setQueryChangedAction:@selector(chatSearchWindowQueryChanged:)];
    [panelView setCommitAction:@selector(chatSearchWindowResultActivated:)];
    [panelView setCloseAction:@selector(closeChatSearchWindow:)];
    self.chatSearchWindowResultsView = panelView;
    [self.chatSearchWindow setContentView:panelView];
}

- (TGChatSearchPanelView *)chatSearchPanelView {
    return [self.chatSearchWindowResultsView isKindOfClass:[TGChatSearchPanelView class]] ? (TGChatSearchPanelView *)self.chatSearchWindowResultsView : nil;
}

- (void)openChatSearchWindow:(id)sender {
    (void)sender;
    [self buildChatSearchWindowIfNeeded];
    [NSApp activateIgnoringOtherApps:YES];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: opening chat search window with %lu visible chat candidate(s).",
                                  (unsigned long)[self.chatItems count]]];
    TGChatSearchPanelView *panelView = [self chatSearchPanelView];
    [panelView setQuery:@""];
    [panelView setStatusText:@"Recent chats. Type to filter by chat, group, or person."];
    [panelView setSelectedIndex:-1];
    [self updateChatSearchWindowResults];
    [self.chatSearchWindow center];
    [self.chatSearchWindow makeKeyAndOrderFront:self];
    [self.chatSearchWindow orderFrontRegardless];
    [self.chatSearchWindow makeFirstResponder:panelView];
}

- (void)closeChatSearchWindow:(id)sender {
    (void)sender;
    [self.chatSearchWindow orderOut:self];
    if ([self.sendTextField isEnabled]) {
        [[self window] makeFirstResponder:self.sendTextField];
    }
}

- (void)clearChatSearchWindowResultButtons {
    [self.chatSearchWindowResultButtons removeAllObjects];
}

- (void)updateChatSearchWindowResults {
    [self buildChatSearchWindowIfNeeded];
    TGChatSearchPanelView *panelView = [self chatSearchPanelView];
    NSString *query = [[panelView query] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.chatSearchWindowResults removeAllObjects];
    if ([query length] > 0) {
        [self.chatSearchWindowResults addObjectsFromArray:[self localChatSearchResultsForQuery:query]];
    } else {
        NSArray *source = self.showingForumTopicList && self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : self.chatItems;
        NSUInteger index = 0;
        for (index = 0; index < [source count] && [self.chatSearchWindowResults count] < 12; index++) {
            id candidate = [source objectAtIndex:index];
            if (![candidate isKindOfClass:[TGChatItem class]]) {
                continue;
            }
            TGChatItem *chatItem = (TGChatItem *)candidate;
            TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
            [result setChatID:([chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID])];
            [result setMessageThreadID:[chatItem messageThreadID]];
            [result setMessageTopicKind:[chatItem messageTopicKind]];
            [result setChatTitle:[[chatItem title] length] > 0 ? [chatItem title] : @"Chat"];
            [result setSnippet:[chatItem typeSummary]];
            [result setChatTitleOnly:YES];
            [self.chatSearchWindowResults addObject:result];
        }
    }
    if ([query length] == 0) {
        [panelView setStatusText:([self.chatSearchWindowResults count] == 0 ? @"No loaded chats yet" : @"Recent chats. Type to filter by chat, group, or person.")];
    } else {
        [panelView setStatusText:([self.chatSearchWindowResults count] == 0 ? @"No chats found" : [NSString stringWithFormat:@"Found chats: %lu", (unsigned long)[self.chatSearchWindowResults count]])];
    }
    [panelView setResults:self.chatSearchWindowResults];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: chat search query length=%lu results=%lu.",
                                  (unsigned long)[query length],
                                  (unsigned long)[self.chatSearchWindowResults count]]];
}

- (void)chatSearchWindowQueryChanged:(id)sender {
    (void)sender;
    [self updateChatSearchWindowResults];
}

- (void)chatSearchWindowTextCommitted:(id)sender {
    (void)sender;
    [self chatSearchWindowResultActivated:[self chatSearchPanelView]];
}

- (void)chatSearchWindowResultClicked:(id)sender {
    (void)sender;
    [self chatSearchWindowResultActivated:[self chatSearchPanelView]];
}

- (void)chatSearchWindowResultActivated:(id)sender {
    TGChatSearchPanelView *panelView = [sender isKindOfClass:[TGChatSearchPanelView class]] ? (TGChatSearchPanelView *)sender : [self chatSearchPanelView];
    TGSearchResultItem *result = [panelView selectedResult];
    if (!result && [self.chatSearchWindowResults count] > 0) {
        result = [self.chatSearchWindowResults objectAtIndex:0];
    }
    if (![result isKindOfClass:[TGSearchResultItem class]]) {
        return;
    }
    [self closeChatSearchWindow:self];
    [self jumpToSearchResult:result];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doChatSearchWindowCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (control != self.chatSearchWindowTextField) {
        return NO;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self closeChatSearchWindow:control];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:) ||
        commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        [self chatSearchWindowTextCommitted:control];
        return YES;
    }
    return NO;
}
