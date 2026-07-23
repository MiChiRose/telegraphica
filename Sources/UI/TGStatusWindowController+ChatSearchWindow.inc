- (void)buildChatSearchWindowIfNeeded {
    if (self.chatSearchWindow) {
        return;
    }

    self.chatSearchWindow = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 460, 340)
                                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO] autorelease];
    [self.chatSearchWindow setTitle:TGLoc(@"search.chats.title")];
    [self.chatSearchWindow setReleasedWhenClosed:NO];
    [self.chatSearchWindow setBackgroundColor:[NSColor colorWithCalibratedRed:0.93 green:0.96 blue:0.98 alpha:1.0]];

    TGChatSearchPanelView *panelView = [[[TGChatSearchPanelView alloc] initWithFrame:NSMakeRect(0, 0, 460, 340)] autorelease];
    [panelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [panelView setTarget:self];
    [panelView setQueryChangedAction:@selector(chatSearchWindowQueryChanged:)];
    [panelView setCommitAction:@selector(chatSearchWindowResultActivated:)];
    [panelView setCloseAction:@selector(closeChatSearchWindow:)];
    self.chatSearchWindowResultsView = panelView;
    self.chatSearchWindowTextField = [panelView searchField];
    [self.chatSearchWindow setContentView:panelView];
    [panelView layoutPanelSubviews];
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
    [panelView setStatusText:TGLoc(@"search.chats.recent")];
    [panelView setSelectedIndex:-1];
    [self updateChatSearchWindowResults];
    [panelView layoutPanelSubviews];
    [panelView setNeedsDisplay:YES];
    [self.chatSearchWindow center];
    [self.chatSearchWindow makeKeyAndOrderFront:self];
    [self.chatSearchWindow orderFrontRegardless];
    [panelView displayIfNeeded];
    [self.chatSearchWindow makeFirstResponder:[panelView searchField]];
}

- (void)closeChatSearchWindow:(id)sender {
    (void)sender;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(updateChatSearchWindowResults)
                                               object:nil];
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
    NSUInteger generation = self.chatSearchGeneration + 1;
    self.chatSearchGeneration = generation;
    [self.chatSearchWindowResults removeAllObjects];
    NSArray *source = self.showingForumTopicList && self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : self.chatItems;
    if ([query length] > 0) {
        [self.chatSearchWindowResults addObjectsFromArray:[self localChatSearchResultsForQuery:query]];
    } else {
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
            [result setChatTitle:[[chatItem title] length] > 0 ? [chatItem title] : TGLoc(@"search.chats.fallbackChat")];
            [result setSnippet:[chatItem typeSummary]];
            [result setChatTitleOnly:YES];
            [self.chatSearchWindowResults addObject:result];
        }
    }
    if ([query length] == 0) {
        [panelView setStatusText:([self.chatSearchWindowResults count] == 0 ? TGLoc(@"search.chats.loadingRecent") : TGLoc(@"search.chats.recent"))];
    } else {
        if (self.demoMode) {
            [panelView setStatusText:([self.chatSearchWindowResults count] == 0
                                      ? TGLoc(@"search.chats.empty")
                                      : [NSString stringWithFormat:TGLoc(@"search.chats.found"),
                                         (unsigned long)[self.chatSearchWindowResults count]])];
        } else {
            [panelView setStatusText:([self.chatSearchWindowResults count] == 0
                                      ? TGLoc(@"search.chats.searching")
                                      : [NSString stringWithFormat:TGLoc(@"search.chats.loadedSearching"),
                                         (unsigned long)[self.chatSearchWindowResults count]])];
        }
    }
    [panelView setResults:self.chatSearchWindowResults];
    [panelView layoutPanelSubviews];
    [panelView setNeedsDisplay:YES];
    [panelView displayIfNeeded];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: chat search query length=%lu results=%lu.",
                                  (unsigned long)[query length],
                                  (unsigned long)[self.chatSearchWindowResults count]]];

    if (self.demoMode) {
        return;
    }

    if ([query length] == 0) {
        if ([self.chatSearchWindowResults count] == 0) {
            TGTDLibClient *client = [self.client retain];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                NSError *loadError = nil;
                NSArray *serverItems = [[client mainChatPreviewItemsWithLimit:24 timeout:5.0 error:&loadError] retain];
                NSString *errorMessage = [[loadError localizedDescription] copy];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.chatSearchGeneration == generation) {
                        TGChatSearchPanelView *activePanelView = [self chatSearchPanelView];
                        [self.chatSearchWindowResults removeAllObjects];
                        NSUInteger index = 0;
                        for (index = 0; index < [serverItems count] && [self.chatSearchWindowResults count] < 12; index++) {
                            id candidate = [serverItems objectAtIndex:index];
                            if (![candidate isKindOfClass:[TGChatItem class]]) {
                                continue;
                            }
                            TGChatItem *chatItem = (TGChatItem *)candidate;
                            TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
                            [result setChatID:([chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID])];
                            [result setMessageThreadID:[chatItem messageThreadID]];
                            [result setMessageTopicKind:[chatItem messageTopicKind]];
                            [result setChatTitle:[[chatItem title] length] > 0 ? [chatItem title] : TGLoc(@"search.chats.fallbackChat")];
                            [result setSnippet:[chatItem typeSummary]];
                            [result setChatTitleOnly:YES];
                            [self.chatSearchWindowResults addObject:result];
                        }
                        [activePanelView setResults:self.chatSearchWindowResults];
                        [activePanelView layoutPanelSubviews];
                        [activePanelView setNeedsDisplay:YES];
                        [activePanelView displayIfNeeded];
                        if ([self.chatSearchWindowResults count] > 0) {
                            [activePanelView setStatusText:TGLoc(@"search.chats.recent")];
                        } else if ([errorMessage length] > 0) {
                            [activePanelView setStatusText:[NSString stringWithFormat:TGLoc(@"search.chats.failed"), errorMessage]];
                            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: recent chat load failed: %@", errorMessage]];
                        } else {
                            [activePanelView setStatusText:TGLoc(@"search.chats.noLoaded")];
                        }
                    }
                    [serverItems release];
                    [errorMessage release];
                    [client release];
                });
                [pool drain];
            });
        }
        return;
    }

    NSArray *localSnapshot = [[NSArray alloc] initWithArray:self.chatSearchWindowResults];
    TGTDLibClient *client = [self.client retain];
    NSString *queryCopy = [query copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *searchError = nil;
        NSArray *serverItems = [[client searchChatPreviewItemsWithQuery:queryCopy
                                                                  limit:30
                                                                timeout:5.0
                                                                  error:&searchError] retain];
        NSString *errorMessage = [[searchError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.chatSearchGeneration != generation) {
                [serverItems release];
                [errorMessage release];
                [localSnapshot release];
                [queryCopy release];
                [client release];
                return;
            }

            [self.chatSearchWindowResults removeAllObjects];
            NSMutableSet *seenKeys = [NSMutableSet set];
            NSUInteger index = 0;
            for (index = 0; index < [localSnapshot count]; index++) {
                id localCandidate = [localSnapshot objectAtIndex:index];
                if (![localCandidate isKindOfClass:[TGSearchResultItem class]]) {
                    continue;
                }
                TGSearchResultItem *localResult = (TGSearchResultItem *)localCandidate;
                NSString *key = [NSString stringWithFormat:@"%lld:%lld:%@",
                                 [[localResult chatID] respondsToSelector:@selector(longLongValue)] ? [[localResult chatID] longLongValue] : 0LL,
                                 [[localResult messageThreadID] respondsToSelector:@selector(longLongValue)] ? [[localResult messageThreadID] longLongValue] : 0LL,
                                 [localResult messageTopicKind] ? [localResult messageTopicKind] : @""];
                if ([seenKeys containsObject:key]) {
                    continue;
                }
                [seenKeys addObject:key];
                [self.chatSearchWindowResults addObject:localResult];
            }
            for (index = 0; index < [serverItems count]; index++) {
                id candidate = [serverItems objectAtIndex:index];
                if (![candidate isKindOfClass:[TGChatItem class]]) {
                    continue;
                }
                TGChatItem *chatItem = (TGChatItem *)candidate;
                NSNumber *resultChatID = [chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID];
                if (![resultChatID respondsToSelector:@selector(longLongValue)]) {
                    continue;
                }
                NSString *key = [NSString stringWithFormat:@"%lld:%lld:%@",
                                 [resultChatID longLongValue],
                                 [[chatItem messageThreadID] respondsToSelector:@selector(longLongValue)] ? [[chatItem messageThreadID] longLongValue] : 0LL,
                                 [chatItem messageTopicKind] ? [chatItem messageTopicKind] : @""];
                if ([seenKeys containsObject:key]) {
                    continue;
                }
                [seenKeys addObject:key];
                TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
                [result setChatID:resultChatID];
                [result setMessageThreadID:[chatItem messageThreadID]];
                [result setMessageTopicKind:[chatItem messageTopicKind]];
                [result setChatTitle:[[chatItem title] length] > 0 ? [chatItem title] : TGLoc(@"search.chats.fallbackChat")];
                [result setSnippet:[chatItem typeSummary]];
                [result setChatTitleOnly:YES];
                [self.chatSearchWindowResults addObject:result];
            }

            TGChatSearchPanelView *activePanelView = [self chatSearchPanelView];
            [activePanelView setResults:self.chatSearchWindowResults];
            [activePanelView layoutPanelSubviews];
            [activePanelView setNeedsDisplay:YES];
            [activePanelView displayIfNeeded];
            if ([self.chatSearchWindowResults count] > 0) {
                [activePanelView setStatusText:([queryCopy length] == 0 ? TGLoc(@"search.chats.recent") : [NSString stringWithFormat:TGLoc(@"search.chats.found"), (unsigned long)[self.chatSearchWindowResults count]])];
            } else if ([errorMessage length] > 0) {
                [activePanelView setStatusText:[NSString stringWithFormat:TGLoc(@"search.chats.failed"), errorMessage]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: chat search failed: %@", errorMessage]];
            } else {
                [activePanelView setStatusText:([queryCopy length] == 0 ? TGLoc(@"search.chats.noLoaded") : TGLoc(@"search.chats.empty"))];
            }
            [serverItems release];
            [errorMessage release];
            [localSnapshot release];
            [queryCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)chatSearchWindowQueryChanged:(id)sender {
    (void)sender;
    TGChatSearchPanelView *panelView = [self chatSearchPanelView];
    NSString *query = [[panelView query] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [panelView setStatusText:([query length] == 0 ? TGLoc(@"search.chats.recent") : TGLoc(@"search.chats.searching"))];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(updateChatSearchWindowResults)
                                               object:nil];
    [self performSelector:@selector(updateChatSearchWindowResults) withObject:nil afterDelay:0.25];
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
