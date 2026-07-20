- (NSArray *)closedChatSuggestionSourceItems {
    NSArray *source = (self.showingForumTopicList && self.chatItemsBeforeTopicList) ? self.chatItemsBeforeTopicList : self.chatItems;
    NSMutableArray *primary = [NSMutableArray array];
    NSMutableArray *fallback = [NSMutableArray array];
    NSMutableSet *seenIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [source count]; index++) {
        id candidate = [source objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]] || [(TGChatItem *)candidate isForumTopic]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;
        NSNumber *chatID = [item chatID];
        if (![chatID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        NSNumber *normalizedID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        if ([seenIDs containsObject:normalizedID]) {
            continue;
        }
        [seenIDs addObject:normalizedID];
        BOOL privateLike = ([[item typeSummary] isEqualToString:@"Private"] || [item isSavedMessages]);
        if (privateLike) {
            [primary addObject:item];
        } else {
            [fallback addObject:item];
        }
        if ([primary count] >= 8) {
            break;
        }
    }
    if ([primary count] < 8) {
        for (index = 0; index < [fallback count] && [primary count] < 8; index++) {
            [primary addObject:[fallback objectAtIndex:index]];
        }
    }
    return primary;
}

- (void)rebuildClosedChatSuggestions {
    NSUInteger index = 0;
    for (index = 0; index < [self.closedChatSuggestionViews count]; index++) {
        id view = [self.closedChatSuggestionViews objectAtIndex:index];
        if ([view isKindOfClass:[NSView class]]) {
            [(NSView *)view removeFromSuperview];
        }
    }

    NSArray *items = [self closedChatSuggestionSourceItems];
    NSMutableArray *views = [NSMutableArray array];
    for (index = 0; index < [items count]; index++) {
        TGChatItem *item = [items objectAtIndex:index];
        TGGroupedCardView *tile = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(0, 0, 74, 82)] autorelease];
        [tile setDrawsInterior:NO];

        TGProfileAvatarView *avatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(15.0, 28.0, 44.0, 44.0)] autorelease];
        [avatarView setDisplayName:[[item title] length] > 0 ? [item title] : TGLoc(@"search.chats.fallbackChat")];
        [avatarView setAvatarLocalPath:[item avatarLocalPath]];
        [tile addSubview:avatarView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(3.0, 4.0, 68.0, 18.0)
                                                  text:([[item title] length] > 0 ? [item title] : TGLoc(@"search.chats.fallbackChat"))
                                                  font:[NSFont boldSystemFontOfSize:11.0]];
        [titleField setAlignment:NSCenterTextAlignment];
        [titleField setTextColor:TGClassicInkColor()];
        [[titleField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [tile addSubview:titleField];

        NSButton *button = [[[NSButton alloc] initWithFrame:[tile bounds]] autorelease];
        [button setBordered:NO];
        [button setTransparent:YES];
        [button setTitle:@""];
        [button setTag:(NSInteger)index];
        [button setTarget:self];
        [button setAction:@selector(openClosedChatSuggestion:)];
        [button setToolTip:[[item title] length] > 0 ? [item title] : TGLoc(@"search.chats.openHint")];
        [tile addSubview:button];
        [self.closedChatPlaceholderView addSubview:tile];
        [views addObject:tile];
    }
    self.closedChatSuggestionItems = items;
    self.closedChatSuggestionViews = views;
    [self applyPointingHandCursorToButtonsInView:self.closedChatPlaceholderView];
}

- (void)layoutClosedChatPlaceholderViewInFrame:(NSRect)messageSurfaceFrame {
    if (!self.closedChatPlaceholderView) {
        return;
    }
    [self.closedChatTitleField setTextColor:TGClassicInkColor()];
    [self.closedChatHintField setTextColor:TGClassicMutedInkColor()];
    CGFloat cardWidth = NSWidth(messageSurfaceFrame) - 70.0;
    if (cardWidth > 500.0) {
        cardWidth = 500.0;
    }
    if (cardWidth < 320.0) {
        cardWidth = 320.0;
    }
    CGFloat cardHeight = ([self.closedChatSuggestionViews count] > 4) ? 230.0 : 150.0;
    if (NSHeight(messageSurfaceFrame) < cardHeight + 24.0) {
        cardHeight = MAX(130.0, NSHeight(messageSurfaceFrame) - 24.0);
    }
    CGFloat cardX = NSMinX(messageSurfaceFrame) + floor((NSWidth(messageSurfaceFrame) - cardWidth) / 2.0);
    CGFloat cardY = NSMinY(messageSurfaceFrame) + floor((NSHeight(messageSurfaceFrame) - cardHeight) / 2.0);
    [self.closedChatPlaceholderView setFrame:NSMakeRect(cardX, cardY, cardWidth, cardHeight)];
    [self.closedChatTitleField setFrame:NSMakeRect(24.0, cardHeight - 42.0, cardWidth - 48.0, 22.0)];
    [self.closedChatHintField setFrame:NSMakeRect(38.0, 18.0, cardWidth - 76.0, 34.0)];

    NSUInteger count = [self.closedChatSuggestionViews count];
    if (count == 0) {
        return;
    }
    NSUInteger columns = count > 4 ? 4 : count;
    CGFloat tileWidth = 74.0;
    CGFloat tileHeight = 82.0;
    CGFloat gap = 12.0;
    CGFloat rowWidth = ((CGFloat)columns * tileWidth) + ((CGFloat)(columns - 1) * gap);
    CGFloat startX = floor((cardWidth - rowWidth) / 2.0);
    CGFloat firstRowY = cardHeight - 130.0;
    if (firstRowY < 56.0) {
        firstRowY = 56.0;
    }
    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        NSView *tile = [self.closedChatSuggestionViews objectAtIndex:index];
        NSUInteger row = index / columns;
        NSUInteger column = index % columns;
        CGFloat tileX = startX + ((tileWidth + gap) * (CGFloat)column);
        CGFloat tileY = firstRowY - ((tileHeight + 8.0) * (CGFloat)row);
        [tile setFrame:NSMakeRect(tileX, tileY, tileWidth, tileHeight)];
    }
}

- (void)openClosedChatSuggestion:(id)sender {
    NSInteger index = [sender respondsToSelector:@selector(tag)] ? [sender tag] : -1;
    if (index < 0 || (NSUInteger)index >= [self.closedChatSuggestionItems count]) {
        return;
    }
    id candidate = [self.closedChatSuggestionItems objectAtIndex:(NSUInteger)index];
    if (![candidate isKindOfClass:[TGChatItem class]]) {
        return;
    }
    TGChatItem *item = (TGChatItem *)candidate;
    NSNumber *chatID = nil;
    if ([[item chatID] respondsToSelector:@selector(longLongValue)]) {
        chatID = [NSNumber numberWithLongLong:[[item chatID] longLongValue]];
    }
    if (!chatID) {
        return;
    }
    self.chatNavigationClosed = NO;
    self.suppressedForumTopicAutoOpenChatID = nil;
    NSUInteger selectedIndex = [self indexOfChatID:chatID inChatItems:self.chatItems];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        [self tableViewSelectionDidChange:[NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
                                                                         object:self.chatTableView]];
    }
    [self updateVisibleSection];
    [self layoutContentView];
}

- (void)closeCurrentChatNavigation:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || ![(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats]) {
        return;
    }
    if (self.searchPanelVisible) {
        [self closeSearchPanel:sender];
        return;
    }
    NSNumber *previousChatID = [self.selectedChatID retain];
    NSNumber *previousThreadID = [self.selectedMessageThreadID retain];
    NSString *previousTopicKind = [self.selectedMessageTopicKind copy];
    [self saveComposerDraftForChatID:previousChatID
                     messageThreadID:previousThreadID
                    messageTopicKind:previousTopicKind];
    if (self.showingForumTopicList) {
        [self closeForumTopicList:nil];
    }
    self.chatNavigationClosed = YES;
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    self.selectedChatTypeSummary = nil;
    self.selectedChatAvatarLocalPath = nil;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    self.pinnedMessageItems = [NSArray array];
    self.pinnedMessageItem = nil;
    self.pinnedMessageCarouselIndex = 0;
    self.searchGeneration++;
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    self.suppressChatSelectionHandling = YES;
    [self.chatTableView deselectAll:nil];
    self.suppressChatSelectionHandling = NO;
    [self.messageTableView reloadData];
    [self setComposerTextWithoutSavingDraft:nil];
    [self clearReplyTarget];
    [self refreshSelectedChatHeaderDisplay];
    [self rebuildClosedChatSuggestions];
    [self updateAuthControlsForState:self.currentAuthState];
    [self updateVisibleSection];
    [self layoutContentView];
    [[TGLogger sharedLogger] log:@"Navigation: current chat closed; showing recent private chat suggestions."];
    [previousChatID release];
    [previousThreadID release];
    [previousTopicKind release];
}

- (void)cancelOperation:(id)sender {
    [self closeCurrentChatNavigation:sender];
}

- (BOOL)isForumTopicAutoOpenSuppressedForChatID:(NSNumber *)chatID {
    return (self.suppressedForumTopicAutoOpenChatID &&
            [chatID respondsToSelector:@selector(longLongValue)] &&
            [self.suppressedForumTopicAutoOpenChatID longLongValue] == [chatID longLongValue]);
}
