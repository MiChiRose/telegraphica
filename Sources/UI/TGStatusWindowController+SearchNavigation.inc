static NSString *TGSearchFilterIdentifierForIndex(NSInteger index) {
    switch (index) {
        case 1: return @"photos";
        case 2: return @"documents";
        case 3: return @"links";
        case 4: return @"voice";
        default: return @"all";
    }
}

- (NSString *)searchResultChatTitleForChatID:(NSNumber *)chatID fallback:(NSString *)fallback {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return ([fallback length] > 0 ? fallback : @"Chat");
    }
    NSUInteger index = 0;
    NSArray *collections[2] = { self.chatItems, self.chatItemsBeforeTopicList };
    NSUInteger collectionIndex = 0;
    for (collectionIndex = 0; collectionIndex < 2; collectionIndex++) {
        NSArray *items = collections[collectionIndex];
        for (index = 0; index < [items count]; index++) {
            id candidate = [items objectAtIndex:index];
            if (![candidate isKindOfClass:[TGChatItem class]]) {
                continue;
            }
            TGChatItem *chatItem = (TGChatItem *)candidate;
            NSNumber *candidateID = [chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID];
            if ([candidateID respondsToSelector:@selector(longLongValue)] && [candidateID longLongValue] == [chatID longLongValue]) {
                return [[chatItem title] length] > 0 ? [chatItem title] : ([fallback length] > 0 ? fallback : @"Chat");
            }
        }
    }
    return ([fallback length] > 0 ? fallback : [NSString stringWithFormat:@"Chat %@", chatID]);
}

- (NSString *)searchMediaTypeForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return @"";
    }
    if ([item isPhotoMessage]) {
        return @"Photo";
    }
    if ([item isDocumentMessage]) {
        return @"Document";
    }
    if ([item isVoiceNoteMessage]) {
        return @"Voice";
    }
    if ([item isPlayableMediaMessage]) {
        return @"Media";
    }
    if ([item isStickerMessage]) {
        return @"Sticker";
    }
    return [item contentType] ? [item contentType] : @"";
}

- (TGSearchResultItem *)searchResultForMessageItem:(TGMessageItem *)item chatTitle:(NSString *)chatTitle {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
    [result setChatID:[item chatID]];
    [result setMessageID:[item messageID]];
    if ([[item chatID] respondsToSelector:@selector(longLongValue)] &&
        [self.selectedChatID respondsToSelector:@selector(longLongValue)] &&
        [[item chatID] longLongValue] == [self.selectedChatID longLongValue]) {
        [result setMessageThreadID:self.selectedMessageThreadID];
        [result setMessageTopicKind:self.selectedMessageTopicKind];
    }
    [result setChatTitle:[self searchResultChatTitleForChatID:[item chatID] fallback:chatTitle]];
    [result setSenderName:[item senderDisplayName]];
    [result setDate:[item date]];
    [result setSnippet:[item preview]];
    [result setMediaType:[self searchMediaTypeForMessageItem:item]];
    [result setMessageItem:item];
    return result;
}

- (void)setSearchStatusText:(NSString *)text {
    [self.searchStatusField setStringValue:([text length] > 0 ? text : @"")];
}

- (NSString *)searchResultIdentityKey:(TGSearchResultItem *)result {
    if (![result isKindOfClass:[TGSearchResultItem class]]) {
        return nil;
    }
    if (result.chatTitleOnly) {
        return [NSString stringWithFormat:@"chat:%lld:%lld:%@", [result.chatID longLongValue], [result.messageThreadID longLongValue], result.messageTopicKind ? result.messageTopicKind : @""];
    }
    if (![result.chatID respondsToSelector:@selector(longLongValue)] || ![result.messageID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"msg:%lld:%lld", [result.chatID longLongValue], [result.messageID longLongValue]];
}

- (NSNumber *)searchPaginationAnchorMessageID {
    NSInteger index = (NSInteger)[self.searchResultItems count] - 1;
    for (; index >= 0; index--) {
        TGSearchResultItem *result = [self.searchResultItems objectAtIndex:(NSUInteger)index];
        if ([result isKindOfClass:[TGSearchResultItem class]] &&
            !result.chatTitleOnly &&
            [result.messageID respondsToSelector:@selector(longLongValue)]) {
            return [NSNumber numberWithLongLong:[result.messageID longLongValue]];
        }
    }
    return nil;
}

- (void)openSearchPanelGlobal:(BOOL)global {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    self.searchPanelVisible = YES;
    self.searchEndReached = NO;
    self.globalSearchOffset = nil;
    [self.searchScopePopUpButton selectItemAtIndex:(global ? 1 : 0)];
    if (!global && !self.selectedChatID) {
        [self.searchScopePopUpButton selectItemAtIndex:1];
    }
    [self.searchResultItems removeAllObjects];
    [self.searchResultsTableView reloadData];
    [self setSearchStatusText:@"Введите запрос"];
    [self updateVisibleSection];
    [self layoutContentView];
    [[self window] makeFirstResponder:self.searchTextField];
}

- (void)openChatSearch:(id)sender {
    (void)sender;
    [self openSearchPanelGlobal:NO];
}

- (void)openGlobalSearch:(id)sender {
    (void)sender;
    [self openSearchPanelGlobal:YES];
}

- (void)closeSearchPanel:(id)sender {
    (void)sender;
    self.searchPanelVisible = NO;
    self.searchLoading = NO;
    self.searchGeneration++;
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = nil;
    [self.searchResultItems removeAllObjects];
    [self.searchResultsTableView reloadData];
    [self updateVisibleSection];
    [self layoutContentView];
    if ([self.sendTextField isEnabled]) {
        [[self window] makeFirstResponder:self.sendTextField];
    }
}

- (void)scheduleSearchRequest {
    [self.searchDebounceTimer invalidate];
    self.searchDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.30
                                                                target:self
                                                              selector:@selector(searchDebounceTimerFired:)
                                                              userInfo:nil
                                                               repeats:NO];
}

- (void)searchDebounceTimerFired:(NSTimer *)timer {
    (void)timer;
    self.searchDebounceTimer = nil;
    [self performSearchReset:YES];
}

- (void)searchTextCommitted:(id)sender {
    (void)sender;
    [self performSearchReset:YES];
}

- (void)searchScopeChanged:(id)sender {
    (void)sender;
    [self performSearchReset:YES];
}

- (void)searchFilterChanged:(id)sender {
    (void)sender;
    [self performSearchReset:YES];
}

- (NSArray *)localChatSearchResultsForQuery:(NSString *)query {
    if ([query length] == 0) {
        return [NSArray array];
    }
    NSMutableArray *results = [NSMutableArray array];
    NSString *needle = [query lowercaseString];
    NSArray *source = self.showingForumTopicList && self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : self.chatItems;
    NSUInteger index = 0;
    for (index = 0; index < [source count]; index++) {
        id candidate = [source objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *chatItem = (TGChatItem *)candidate;
        NSString *title = [chatItem title] ? [chatItem title] : @"";
        if ([[title lowercaseString] rangeOfString:needle].location == NSNotFound) {
            continue;
        }
        TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
        [result setChatID:([chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID])];
        [result setMessageThreadID:[chatItem messageThreadID]];
        [result setMessageTopicKind:[chatItem messageTopicKind]];
        [result setChatTitle:title];
        [result setSnippet:[chatItem typeSummary]];
        [result setChatTitleOnly:YES];
        [results addObject:result];
        if ([results count] >= 12) {
            break;
        }
    }
    return results;
}

- (void)performSearchReset:(BOOL)reset {
    if (!self.searchPanelVisible) {
        return;
    }
    NSString *query = [[self.searchTextField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        self.searchLoading = NO;
        self.searchEndReached = NO;
        self.globalSearchOffset = nil;
        [self.searchResultItems removeAllObjects];
        [self.searchResultsTableView reloadData];
        [self setSearchStatusText:@"Введите запрос"];
        [self updateVisibleSection];
        [self layoutContentView];
        return;
    }
    BOOL global = ([self.searchScopePopUpButton indexOfSelectedItem] == 1 || self.selectedChatID == nil);
    NSString *filter = TGSearchFilterIdentifierForIndex([self.searchFilterPopUpButton indexOfSelectedItem]);
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *threadID = [self.selectedMessageThreadID retain];
    NSString *topicKind = [self.selectedMessageTopicKind copy];
    NSString *chatTitle = [self.selectedChatTitle copy];
    NSString *offset = reset ? nil : [self.globalSearchOffset copy];
    NSNumber *fromMessageID = (!global && !reset) ? [[self searchPaginationAnchorMessageID] retain] : nil;

    if (!reset && self.searchEndReached) {
        [offset release];
        [fromMessageID release];
        [chatID release];
        [threadID release];
        [topicKind release];
        [chatTitle release];
        return;
    }
    if (!reset && global && [offset length] == 0) {
        [offset release];
        [fromMessageID release];
        [chatID release];
        [threadID release];
        [topicKind release];
        [chatTitle release];
        return;
    }
    if (!reset && !global && ![fromMessageID respondsToSelector:@selector(longLongValue)]) {
        [offset release];
        [fromMessageID release];
        [chatID release];
        [threadID release];
        [topicKind release];
        [chatTitle release];
        return;
    }

    NSUInteger generation = self.searchGeneration + 1;
    self.searchGeneration = generation;
    self.searchLoading = YES;
    if (reset) {
        self.globalSearchOffset = nil;
        [self.searchResultItems removeAllObjects];
        [self.searchResultsTableView reloadData];
    }
    [self setSearchStatusText:@"Поиск..."];
    [self updateVisibleSection];
    [self layoutContentView];

    TGTDLibClient *client = [self.client retain];
    NSArray *localChatMatches = global ? [[self localChatSearchResultsForQuery:query] retain] : nil;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *searchError = nil;
        NSArray *messageItems = nil;
        NSString *newOffset = nil;
        if (global) {
            NSString *offsetToken = [offset copy];
            messageItems = [[client globalSearchMessagePreviewItemsWithQuery:query
                                                                      filter:filter
                                                                      offset:&offsetToken
                                                                       limit:30
                                                                     timeout:8.0
                                                                       error:&searchError] retain];
            newOffset = [offsetToken copy];
            [offsetToken release];
        } else {
            messageItems = [[client searchMessagePreviewItemsForChatID:chatID
                                                       messageThreadID:threadID
                                                      messageTopicKind:topicKind
                                                                 query:query
                                                                filter:filter
                                                         fromMessageID:fromMessageID
                                                                 limit:30
                                                               timeout:8.0
                                                                 error:&searchError] retain];
        }
        NSString *errorMessage = [[searchError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.searchGeneration != generation || !self.searchPanelVisible) {
                [messageItems release];
                [errorMessage release];
                [newOffset release];
                [localChatMatches release];
                [offset release];
                [fromMessageID release];
                [chatID release];
                [threadID release];
                [topicKind release];
                [chatTitle release];
                [client release];
                return;
            }
            self.searchLoading = NO;
            NSMutableArray *results = [NSMutableArray array];
            NSMutableSet *existingKeys = [NSMutableSet set];
            NSUInteger existingIndex = 0;
            for (existingIndex = 0; existingIndex < [self.searchResultItems count]; existingIndex++) {
                NSString *key = [self searchResultIdentityKey:[self.searchResultItems objectAtIndex:existingIndex]];
                if ([key length] > 0) {
                    [existingKeys addObject:key];
                }
            }
            if (global && reset && localChatMatches) {
                NSUInteger localIndex = 0;
                for (localIndex = 0; localIndex < [localChatMatches count]; localIndex++) {
                    TGSearchResultItem *localResult = [localChatMatches objectAtIndex:localIndex];
                    NSString *key = [self searchResultIdentityKey:localResult];
                    if ([key length] == 0 || ![existingKeys containsObject:key]) {
                        [results addObject:localResult];
                        if ([key length] > 0) {
                            [existingKeys addObject:key];
                        }
                    }
                }
            }
            if (messageItems) {
                NSUInteger index = 0;
                for (index = 0; index < [messageItems count]; index++) {
                    TGSearchResultItem *result = [self searchResultForMessageItem:[messageItems objectAtIndex:index] chatTitle:chatTitle];
                    NSString *key = [self searchResultIdentityKey:result];
                    if (result && ([key length] == 0 || ![existingKeys containsObject:key])) {
                        [results addObject:result];
                        if ([key length] > 0) {
                            [existingKeys addObject:key];
                        }
                    }
                }
            }
            [self.searchResultItems addObjectsFromArray:results];
            [self.searchResultsTableView reloadData];
            self.globalSearchOffset = newOffset;
            BOOL hasNextOffset = global ? ([newOffset length] > 0) : ([messageItems count] >= 30);
            self.searchEndReached = !hasNextOffset || ([messageItems count] == 0);
            if ([errorMessage length] > 0 && !messageItems) {
                [self setSearchStatusText:[NSString stringWithFormat:@"Ошибка: %@", errorMessage]];
            } else if ([self.searchResultItems count] == 0) {
                [self setSearchStatusText:@"Ничего не найдено"];
            } else {
                [self setSearchStatusText:[NSString stringWithFormat:@"Найдено: %lu%@", (unsigned long)[self.searchResultItems count], hasNextOffset ? @" · ещё есть результаты" : @""]];
            }
            [self updateVisibleSection];
            [self layoutContentView];
            [messageItems release];
            [errorMessage release];
            [newOffset release];
            [localChatMatches release];
            [offset release];
            [fromMessageID release];
            [chatID release];
            [threadID release];
            [topicKind release];
            [chatTitle release];
            [client release];
        });
        [pool drain];
    });
}

- (void)activateSearchResult:(id)sender {
    (void)sender;
    NSInteger row = [self.searchResultsTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.searchResultItems count]) {
        return;
    }
    TGSearchResultItem *result = [self.searchResultItems objectAtIndex:(NSUInteger)row];
    if (![result isKindOfClass:[TGSearchResultItem class]]) {
        return;
    }
    [self jumpToSearchResult:result];
}

- (void)searchResultsScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.searchResultsScrollView contentView]) {
        return;
    }
    if (!self.searchPanelVisible || self.searchLoading || self.searchEndReached) {
        return;
    }
    NSString *query = [[self.searchTextField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0 || [self.searchResultItems count] == 0) {
        return;
    }

    NSClipView *clipView = [self.searchResultsScrollView contentView];
    NSRect visibleRect = [clipView bounds];
    NSRect documentRect = [[self.searchResultsScrollView documentView] frame];
    CGFloat remaining = NSMaxY(documentRect) - NSMaxY(visibleRect);
    if (remaining < 90.0) {
        [self performSearchReset:NO];
    }
}

- (void)jumpToSearchResult:(TGSearchResultItem *)result {
    if (![result.chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (result.chatTitleOnly || ![result.messageID respondsToSelector:@selector(longLongValue)]) {
        NSUInteger index = [self indexOfChatID:result.chatID inChatItems:self.chatItems];
        if (index != NSNotFound) {
            [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
            [self.chatTableView scrollRowToVisible:index];
        }
        return;
    }
    NSNumber *chatID = [result.chatID retain];
    NSNumber *messageID = [result.messageID retain];
    NSNumber *threadID = [result.messageThreadID retain];
    NSString *topicKind = [result.messageTopicKind copy];
    NSString *chatTitle = [result.chatTitle copy];
    NSUInteger generation = self.messageLoadingGeneration + 1;
    self.messageLoadingGeneration = generation;
    self.messageLoadingIndicatorVisible = YES;
    [self.messageLoadingSpinner startAnimation:self];
    [self updateVisibleSection];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *contextError = nil;
        NSArray *items = [[client messageContextPreviewItemsForChatID:chatID
                                                      messageThreadID:threadID
                                                     messageTopicKind:topicKind
                                                      centerMessageID:messageID
                                                                limit:24
                                                              timeout:8.0
                                                                error:&contextError] retain];
        NSString *errorMessage = [[contextError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (items) {
                self.selectedChatID = chatID;
                self.selectedChatTitle = ([chatTitle length] > 0 ? chatTitle : self.selectedChatTitle);
                if (threadID) {
                    self.selectedMessageThreadID = threadID;
                    self.selectedMessageTopicKind = topicKind;
                } else {
                    self.selectedMessageThreadID = nil;
                    self.selectedMessageTopicKind = nil;
                }
                [self refreshSelectedChatHeaderDisplay];
                [self.messageItems removeAllObjects];
                [self.messageItems addObjectsFromArray:[self messageItemsInDisplayOrderFromItems:items]];
                [self updateOutgoingReadStateForVisibleMessages];
                [self.messageTableView reloadData];
                NSUInteger index = [self indexOfMessageID:messageID inMessageItems:self.messageItems];
                if (index != NSNotFound) {
                    [self.messageTableView scrollRowToVisible:index];
                    [self.messageTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
                    self.highlightedSearchMessageID = messageID;
                    [self.searchHighlightTimer invalidate];
                    self.searchHighlightTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(clearSearchHighlightTimerFired:) userInfo:nil repeats:NO];
                }
            } else if ([errorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"Search jump failed: %@", errorMessage]];
            }
            if (self.messageLoadingGeneration == generation) {
                self.messageLoadingIndicatorVisible = NO;
                [self.messageLoadingSpinner stopAnimation:self];
                [self updateVisibleSection];
                [self layoutContentView];
            }
            [items release];
            [errorMessage release];
            [chatID release];
            [messageID release];
            [threadID release];
            [topicKind release];
            [chatTitle release];
            [client release];
        });
        [pool drain];
    });
}

- (NSUInteger)indexOfMessageID:(NSNumber *)messageID inMessageItems:(NSArray *)items {
    if (![messageID respondsToSelector:@selector(longLongValue)]) {
        return NSNotFound;
    }
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if ([candidate isKindOfClass:[TGMessageItem class]] &&
            [[(TGMessageItem *)candidate messageID] respondsToSelector:@selector(longLongValue)] &&
            [[(TGMessageItem *)candidate messageID] longLongValue] == [messageID longLongValue]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)clearSearchHighlightTimerFired:(NSTimer *)timer {
    (void)timer;
    self.highlightedSearchMessageID = nil;
    self.searchHighlightTimer = nil;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doSearchCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (control != self.searchTextField) {
        return NO;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self closeSearchPanel:control];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:) ||
        commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        if ([self.searchResultsTableView selectedRow] < 0 && [self.searchResultItems count] > 0) {
            [self.searchResultsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        }
        [self activateSearchResult:control];
        return YES;
    }
    if (commandSelector == @selector(moveDown:)) {
        NSInteger row = [self.searchResultsTableView selectedRow];
        NSInteger nextRow = row + 1;
        if (nextRow >= (NSInteger)[self.searchResultItems count]) {
            nextRow = (NSInteger)[self.searchResultItems count] - 1;
        }
        if (nextRow >= 0) {
            [self.searchResultsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)nextRow] byExtendingSelection:NO];
            [self.searchResultsTableView scrollRowToVisible:nextRow];
        }
        return YES;
    }
    if (commandSelector == @selector(moveUp:)) {
        NSInteger row = [self.searchResultsTableView selectedRow];
        NSInteger nextRow = row - 1;
        if (row < 0) {
            nextRow = (NSInteger)[self.searchResultItems count] - 1;
        }
        if (nextRow >= 0) {
            [self.searchResultsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)nextRow] byExtendingSelection:NO];
            [self.searchResultsTableView scrollRowToVisible:nextRow];
        }
        return YES;
    }
    return NO;
}

- (BOOL)handleSearchKeyEquivalent:(NSEvent *)event {
    if ([event type] != NSKeyDown) {
        return NO;
    }
    NSString *characters = [event charactersIgnoringModifiers];
    if ([characters length] == 0) {
        return NO;
    }
    unichar key = [characters characterAtIndex:0];
    NSUInteger flags = [event modifierFlags];
    BOOL command = ((flags & NSCommandKeyMask) != 0);
    BOOL shift = ((flags & NSShiftKeyMask) != 0);
    if (command && (key == 'f' || key == 'F')) {
        if (shift) {
            [self openGlobalSearch:self];
        } else {
            [self openChatSearch:self];
        }
        return YES;
    }
    if (key == 27 && self.searchPanelVisible) {
        [self closeSearchPanel:self];
        return YES;
    }
    return NO;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    if ([self handleSearchKeyEquivalent:event]) {
        return YES;
    }
    return NO;
}

- (void)loadPinnedMessageForSelectedChat {
    self.pinnedMessageItem = nil;
    if (![self.currentAuthState isEqualToString:@"ready"] || ![self.selectedChatID respondsToSelector:@selector(longLongValue)]) {
        [self updateVisibleSection];
        return;
    }
    NSNumber *chatID = [self.selectedChatID retain];
    NSUInteger generation = self.pinnedMessageGeneration + 1;
    self.pinnedMessageGeneration = generation;
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *pinnedError = nil;
        TGMessageItem *item = [[client pinnedMessagePreviewItemForChatID:chatID timeout:5.0 error:&pinnedError] retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.pinnedMessageGeneration == generation &&
                self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue]) {
                self.pinnedMessageItem = item;
                if (item) {
                    [self.pinnedMessageTextField setStringValue:[item preview] ? [item preview] : @"Pinned message"];
                } else {
                    [self.pinnedMessageTextField setStringValue:@""];
                }
                [self updateVisibleSection];
                [self layoutContentView];
            }
            [item release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)jumpToPinnedMessage:(id)sender {
    (void)sender;
    if (!self.pinnedMessageItem) {
        return;
    }
    TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
    [result setChatID:[self.pinnedMessageItem chatID]];
    [result setMessageID:[self.pinnedMessageItem messageID]];
    [result setChatTitle:self.selectedChatTitle];
    [result setMessageItem:self.pinnedMessageItem];
    [self jumpToSearchResult:result];
}
