- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.searchResultsTableView) {
        return (NSInteger)[self.searchResultItems count];
    }
    if (tableView == self.messageTableView) {
        return (NSInteger)[self.messageItems count];
    }
    return (NSInteger)[self.chatItems count];
}

- (BOOL)shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]] || [item outgoing] || [[item senderDisplayName] length] == 0) {
        return NO;
    }
    NSString *type = [self.selectedChatTypeSummary lowercaseString];
    if ([type length] == 0 && !self.selectedMessageThreadID) {
        return NO;
    }
    BOOL groupLike = ([type rangeOfString:@"group"].location != NSNotFound ||
                      [type rangeOfString:@"forum"].location != NSNotFound ||
                      [type rangeOfString:@"thread"].location != NSNotFound ||
                      [type rangeOfString:@"topic"].location != NSNotFound ||
                      self.selectedMessageThreadID != nil);
    return groupLike;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView == self.searchResultsTableView) {
        return 44.0;
    }
    if (tableView != self.messageTableView) {
        return [tableView rowHeight];
    }
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return [tableView rowHeight];
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return [tableView rowHeight];
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    CGFloat availableWidth = bubbleColumn ? [bubbleColumn width] : NSWidth([self.messageScrollView frame]);
    return TGMessageBubbleHeightForItem((TGMessageItem *)item, availableWidth, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
}

- (NSString *)tableView:(NSTableView *)tableView
      toolTipForCell:(NSCell *)cell
                rect:(NSRectPointer)rect
         tableColumn:(NSTableColumn *)tableColumn
                 row:(NSInteger)row
       mouseLocation:(NSPoint)mouseLocation {
    (void)cell;
    (void)rect;
    (void)tableColumn;
    (void)mouseLocation;
    if (tableView != self.messageTableView || row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return nil;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:mouseLocation];
    if (mediaItem) {
        if (!TGMediaItemSupportsPreview(mediaItem)) {
            return nil;
        }
        return TGMediaItemIsPlayable(mediaItem) ? @"Play media" : @"Open media preview";
    }
    if (TGMessageItemIsNonVisualPlayableMedia((TGMessageItem *)item)) {
        NSRect bubbleRect = TGMessageBubbleRectForItem((TGMessageItem *)item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
        if (!NSIsEmptyRect(bubbleRect) && NSPointInRect(mouseLocation, bubbleRect)) {
            return @"Play media";
        }
    }
    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:mouseLocation];
    return url ? @"Open link in default browser" : nil;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                  proposedRow:(NSInteger)row
        proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    (void)row;
    (void)dropOperation;
    if (tableView != self.messageTableView) {
        return NSDragOperationNone;
    }
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        [self showMessageDropOverlay:NO];
        return NSDragOperationNone;
    }
    TGAttachmentDescriptor *descriptor = [TGAttachmentDescriptor firstDescriptorFromPasteboard:[info draggingPasteboard]];
    if ([descriptor isSupported]) {
        [self.messageTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
        [self showMessageDropOverlay:YES];
        return NSDragOperationCopy;
    }
    [self showMessageDropOverlay:NO];
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
    (void)row;
    (void)dropOperation;
    [self showMessageDropOverlay:NO];
    if (tableView != self.messageTableView) {
        return NO;
    }
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        return NO;
    }
    TGAttachmentDescriptor *descriptor = [TGAttachmentDescriptor firstDescriptorFromPasteboard:[info draggingPasteboard]];
    if (![descriptor isSupported]) {
        if ([descriptor.errorMessage length] > 0) {
            [self appendDetail:descriptor.errorMessage];
        }
        return NO;
    }
    [self presentAttachmentPreviewForDescriptor:descriptor];
    return YES;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    id identifier = [tableColumn identifier];
    if (tableView == self.searchResultsTableView) {
        [textCell setFont:[NSFont systemFontOfSize:11.0]];
        [textCell setTextColor:TGClassicInkColor()];
        [textCell setDrawsBackground:[tableView isRowSelected:row]];
        if ([tableView isRowSelected:row]) {
            [textCell setBackgroundColor:TGClassicSelectedRowColor()];
        }
        [textCell setLineBreakMode:NSLineBreakByTruncatingTail];
        return;
    }
    if (tableView == self.chatTableView && [identifier isEqual:@"chat"] && [cell isKindOfClass:[TGChatListCell class]]) {
        TGChatItem *chatItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.chatItems count]) {
            id item = [self.chatItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGChatItem class]]) {
                chatItem = (TGChatItem *)item;
            }
        }
        [(TGChatListCell *)cell setHighlighted:[tableView isRowSelected:row]];
        [(TGChatListCell *)cell setChatItem:chatItem];
        return;
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"bubble"] && [cell isKindOfClass:[TGMessageBubbleCell class]]) {
        TGMessageItem *messageItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.messageItems count]) {
            id item = [self.messageItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGMessageItem class]]) {
                messageItem = (TGMessageItem *)item;
            }
        }
        [(TGMessageBubbleCell *)cell setMessageItem:messageItem];
        [(TGMessageBubbleCell *)cell setShowSenderDetails:[self shouldShowGroupSenderDetailsForMessageItem:messageItem]];
        [self scheduleInlineMediaPlaybackRefresh];
        return;
    }
    [textCell setAlignment:NSLeftTextAlignment];
    [textCell setFont:[NSFont systemFontOfSize:12.0]];
    [textCell setTextColor:TGClassicInkColor()];
    [textCell setDrawsBackground:NO];
    [textCell setLineBreakMode:NSLineBreakByTruncatingTail];

    if (tableView == self.chatTableView) {
        BOOL selected = [tableView isRowSelected:row];
        if (selected) {
            [textCell setDrawsBackground:YES];
            [textCell setBackgroundColor:TGClassicSelectedRowColor()];
            [textCell setTextColor:TGClassicSelectedRowTextColor()];
        }
        if ([identifier isEqual:@"title"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:12.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicInkColor()];
            }
        } else if ([identifier isEqual:@"unread_count"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicUnreadTextColor()];
            }
            [textCell setAlignment:NSCenterTextAlignment];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicMutedInkColor()];
            }
        }
    } else if (tableView == self.messageTableView) {
        if ([identifier isEqual:@"date"] || [identifier isEqual:@"direction"]) {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            [textCell setTextColor:TGClassicMutedInkColor()];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:12.0]];
            [textCell setTextColor:TGClassicInkColor()];
        }
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == self.searchResultsTableView) {
        if (row < 0 || (NSUInteger)row >= [self.searchResultItems count]) {
            return @"";
        }
        id candidate = [self.searchResultItems objectAtIndex:(NSUInteger)row];
        if (![candidate isKindOfClass:[TGSearchResultItem class]]) {
            return @"";
        }
        TGSearchResultItem *result = (TGSearchResultItem *)candidate;
        NSString *title = [result displayTitle];
        NSString *subtitle = [result displaySubtitle];
        NSString *date = [result dateSummary];
        NSMutableString *line = [NSMutableString stringWithString:title ? title : @""];
        if ([date length] > 0) {
            [line appendFormat:@"  %@", date];
        }
        if ([subtitle length] > 0) {
            [line appendFormat:@"\n%@", subtitle];
        }
        return line;
    }
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    id item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = nil;
    if (tableView == self.messageTableView && [item isKindOfClass:[TGMessageItem class]]) {
        if ([identifier isEqual:@"bubble"]) {
            value = @"";
        } else {
            value = [(TGMessageItem *)item valueForTableColumnIdentifier:identifier];
        }
    } else if (tableView == self.chatTableView && [item isKindOfClass:[TGChatItem class]]) {
        if ([identifier isEqual:@"chat"]) {
            value = @"";
        } else {
            value = [(TGChatItem *)item valueForTableColumnIdentifier:identifier];
        }
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"date"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger timestamp = [value integerValue];
        if (timestamp <= 0) {
            return @"";
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
        return [NSDateFormatter localizedStringFromDate:date
                                              dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
    }
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger unreadCount = [value integerValue];
        if (unreadCount <= 0) {
            return @"";
        }
        if (unreadCount > 999) {
            return @"999+";
        }
        return [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }
    return value ? value : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] == self.searchResultsTableView) {
        return;
    }
    if ([notification object] != self.chatTableView) {
        return;
    }
    if (self.suppressChatSelectionHandling) {
        return;
    }

    NSNumber *previousChatID = [self.selectedChatID retain];
    NSNumber *previousThreadID = [self.selectedMessageThreadID retain];
    NSString *previousTopicKind = [self.selectedMessageTopicKind copy];
    [self saveComposerDraftForChatID:previousChatID
                     messageThreadID:previousThreadID
                      messageTopicKind:previousTopicKind];
    NSInteger clickedRow = [self.chatTableView clickedRow];
    NSInteger row = (clickedRow >= 0) ? clickedRow : [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
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
        [self refreshSelectedChatHeaderDisplay];
        [self.messageItems removeAllObjects];
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        [self.messageTableView reloadData];
        [self setComposerTextWithoutSavingDraft:nil];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateAuthControlsForState:self.currentAuthState];
        [previousChatID release];
        [previousThreadID release];
        [previousTopicKind release];
        return;
    }

    TGChatItem *item = [[self.chatItems objectAtIndex:(NSUInteger)row] retain];
    BOOL selectedForumTopic = [item isForumTopic];
    id chatID = selectedForumTopic ? [item parentChatID] : [item chatID];
    id title = [item title];
    NSNumber *newChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        newChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        self.selectedChatID = newChatID;
    } else {
        self.selectedChatID = nil;
    }
    NSNumber *newThreadID = nil;
    NSString *newTopicKind = nil;
    if (selectedForumTopic && [[item messageThreadID] respondsToSelector:@selector(longLongValue)]) {
        newThreadID = [NSNumber numberWithLongLong:[[item messageThreadID] longLongValue]];
        newTopicKind = [[item messageTopicKind] length] > 0 ? [item messageTopicKind] : @"forum";
    }
    self.selectedMessageThreadID = newThreadID;
    self.selectedMessageTopicKind = newTopicKind;

    BOOL sameChat = ((previousChatID && newChatID) && ([previousChatID longLongValue] == [newChatID longLongValue]));
    BOOL sameThread = ((!previousThreadID && !newThreadID) ||
                       (previousThreadID && newThreadID && [previousThreadID longLongValue] == [newThreadID longLongValue]));
    BOOL sameTopicKind = ((!previousTopicKind && !newTopicKind) ||
                          (previousTopicKind && newTopicKind && [previousTopicKind isEqualToString:newTopicKind]));
    BOOL selectionChanged = !(sameChat && sameThread && sameTopicKind);
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"Selected chat";
    self.selectedChatTypeSummary = [item typeSummary];
    self.selectedChatAvatarLocalPath = [item avatarLocalPath];
    self.selectedChatLastReadOutboxMessageID = [item lastReadOutboxMessageID];
    [self updateOutgoingReadStateForVisibleMessages];
    [self refreshSelectedChatHeaderDisplay];
    BOOL shouldOpenTopicList = (!selectedForumTopic && !self.showingForumTopicList && [[item typeSummary] isEqualToString:@"Supergroup"]);
    if (selectionChanged) {
        [self clearTypingIndicator];
        self.searchGeneration++;
        self.pinnedMessageItems = [NSArray array];
        self.pinnedMessageItem = nil;
        self.pinnedMessageCarouselIndex = 0;
        [self.messageItems removeAllObjects];
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        [self.messageTableView reloadData];
        if (shouldOpenTopicList) {
            [self setComposerTextWithoutSavingDraft:nil];
        } else {
            [self restoreComposerDraftForChatID:newChatID
                                messageThreadID:newThreadID
                                 messageTopicKind:newTopicKind];
        }
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
    }
    [self updateAuthControlsForState:self.currentAuthState];
    if (selectionChanged || self.pinnedMessageItem == nil) {
        [self loadPinnedMessageForSelectedChat];
    }
    if (selectedForumTopic) {
        if (newThreadID) {
            [self appendDetail:[NSString stringWithFormat:@"Forum topic selected: %@ (%lld).", self.selectedChatTitle ? self.selectedChatTitle : @"Topic", [newThreadID longLongValue]]];
        }
    } else if (shouldOpenTopicList) {
        [self removeForumTopicRowsPreservingChatID:newChatID];
        [self loadForumTopicsForChatItem:item];
    }
    if (newChatID && (selectionChanged || [self.messageItems count] == 0)) {
        if (selectedForumTopic) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
            [self requestComposerRefocus];
        } else if (!shouldOpenTopicList) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
            [self requestComposerRefocus];
        }
    } else if (newChatID && !shouldOpenTopicList) {
        [self requestComposerRefocus];
    }
    [previousChatID release];
    [previousThreadID release];
    [previousTopicKind release];
    [item release];
}

- (void)activateSelectedChatRow:(id)sender {
    (void)sender;
    if (self.suppressChatSelectionHandling || self.showingForumTopicList || self.forumTopicRefreshInFlight) {
        return;
    }

    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        return;
    }

    id candidate = [self.chatItems objectAtIndex:(NSUInteger)row];
    if (![candidate isKindOfClass:[TGChatItem class]]) {
        return;
    }

    TGChatItem *item = [(TGChatItem *)candidate retain];
    if ([item isForumTopic] || ![[item typeSummary] isEqualToString:@"Supergroup"]) {
        [item release];
        return;
    }

    id chatID = [item chatID];
    NSNumber *selectedChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    }
    [self removeForumTopicRowsPreservingChatID:selectedChatID];
    [self loadForumTopicsForChatItem:item];
    [item release];
}

- (void)applyChatItems:(NSArray *)items preserveSelection:(BOOL)preserveSelection preferredChatID:(NSNumber *)preferredChatID {
    [self clearForumTopicListState];
    NSUInteger selectedIndex = NSNotFound;

    if (preserveSelection && preferredChatID) {
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            TGChatItem *item = [items objectAtIndex:index];
            id chatID = [item chatID];
            if ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [preferredChatID longLongValue]) {
                selectedIndex = index;
                break;
            }
        }
    }

    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:items];
    [self applyLocalNotificationMuteStateToItems:self.chatItems];
    [self.chatTableView reloadData];
    [self updateApplicationBadge];
    self.autoChatListLoadArmed = YES;
    self.autoChatListRefreshArmed = NO;

    if (self.pendingNotificationChatID) {
        NSNumber *pendingChatID = [self.pendingNotificationChatID retain];
        NSNumber *pendingThreadID = [self.pendingNotificationThreadID retain];
        if ([self selectChatFromNotificationWithChatID:pendingChatID messageThreadID:pendingThreadID]) {
            self.pendingNotificationChatID = nil;
            self.pendingNotificationThreadID = nil;
            [pendingChatID release];
            [pendingThreadID release];
            return;
        }
        [pendingChatID release];
        [pendingThreadID release];
    }

    if (selectedIndex != NSNotFound) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:selectedIndex];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        id selectedItem = [items objectAtIndex:selectedIndex];
        if ([selectedItem isKindOfClass:[TGChatItem class]]) {
            self.selectedChatLastReadOutboxMessageID = [(TGChatItem *)selectedItem lastReadOutboxMessageID];
            [self updateOutgoingReadStateForVisibleMessages];
        }
        return;
    }

    if ([items count] > 0 && [self.currentAuthState isEqualToString:@"ready"]) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:0];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:0];
        return;
    }

    [self.chatTableView deselectAll:nil];
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    self.selectedChatTypeSummary = nil;
    self.selectedChatAvatarLocalPath = nil;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self loadPinnedMessageForSelectedChat];
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    [self setComposerTextWithoutSavingDraft:nil];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self updateAuthControlsForState:self.currentAuthState];
}

- (BOOL)chatItemsContainForumTopicRows {
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id item = [self.chatItems objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray *)chatItemsByRemovingForumTopicRowsFromItems:(NSArray *)items {
    NSMutableArray *baseItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        [baseItems addObject:item];
    }
    return baseItems;
}

- (NSUInteger)indexOfChatID:(NSNumber *)chatID inChatItems:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return NSNotFound;
    }
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if (![item isKindOfClass:[TGChatItem class]] || [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        id itemChatID = [(TGChatItem *)item chatID];
        if ([itemChatID respondsToSelector:@selector(longLongValue)] && [itemChatID longLongValue] == [chatID longLongValue]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)removeForumTopicRowsPreservingChatID:(NSNumber *)chatID {
    if (![self chatItemsContainForumTopicRows]) {
        return;
    }
    NSArray *baseItems = [self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems];
    NSUInteger selectedIndex = [self indexOfChatID:chatID inChatItems:baseItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:baseItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
    }
    self.suppressChatSelectionHandling = NO;
}

- (NSString *)displayTitleForTopicItem:(TGChatItem *)item {
    NSString *title = [item title];
    if (![title isKindOfClass:[NSString class]]) {
        return @"Topic";
    }
    return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)showForumTopicListForChatItem:(TGChatItem *)chatItem topics:(NSArray *)topics {
    if (!chatItem || [topics count] == 0) {
        return;
    }

    self.chatItemsBeforeTopicList = [NSArray arrayWithArray:[self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems]];
    self.topicParentChatID = [chatItem chatID];
    self.topicParentTitle = [chatItem title];
    self.topicParentAvatarLocalPath = [chatItem avatarLocalPath];
    self.showingForumTopicList = YES;
    [self.loadChatsButton setToolTip:@"Refresh topics"];
    self.chatsExhausted = YES;
    self.autoChatListLoadArmed = NO;
    self.autoChatListRefreshArmed = NO;

    NSMutableArray *topicItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [topics count]; index++) {
        id candidate = [topics objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *topicItem = (TGChatItem *)candidate;
        [topicItem setAvatarLocalPath:self.topicParentAvatarLocalPath];
        [topicItems addObject:topicItem];
    }
    [self applyLocalNotificationMuteStateToItems:topicItems];

    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:topicItems];
    [self.chatTableView reloadData];
    self.suppressChatSelectionHandling = NO;

    self.selectedChatID = self.topicParentChatID;
    self.selectedChatTitle = self.topicParentTitle;
    self.selectedChatTypeSummary = @"Forum";
    self.selectedChatAvatarLocalPath = self.topicParentAvatarLocalPath;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    TGChatItem *firstTopicItem = ([topicItems count] > 0 && [[topicItems objectAtIndex:0] isKindOfClass:[TGChatItem class]]) ? [topicItems objectAtIndex:0] : nil;
    if (firstTopicItem) {
        NSNumber *firstThreadID = nil;
        if ([[firstTopicItem messageThreadID] respondsToSelector:@selector(longLongValue)]) {
            firstThreadID = [NSNumber numberWithLongLong:[[firstTopicItem messageThreadID] longLongValue]];
        }
        self.selectedChatTitle = [[firstTopicItem title] length] > 0 ? [firstTopicItem title] : self.topicParentTitle;
        self.selectedChatTypeSummary = [firstTopicItem typeSummary];
        self.selectedChatAvatarLocalPath = [firstTopicItem avatarLocalPath] ? [firstTopicItem avatarLocalPath] : self.topicParentAvatarLocalPath;
        self.selectedMessageThreadID = firstThreadID;
        self.selectedMessageTopicKind = ([[firstTopicItem messageTopicKind] length] > 0 ? [firstTopicItem messageTopicKind] : @"forum");
        self.suppressChatSelectionHandling = YES;
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:0];
        self.suppressChatSelectionHandling = NO;
    } else {
        [self.chatTableView deselectAll:nil];
    }
    [self refreshSelectedChatHeaderDisplay];
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    [self restoreComposerDraftForChatID:self.selectedChatID
                        messageThreadID:self.selectedMessageThreadID
                         messageTopicKind:self.selectedMessageTopicKind];
    NSString *topicListTitle = ([self.topicParentTitle length] > 0 ? self.topicParentTitle : @"Topics");
    [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
    if (firstTopicItem && self.selectedChatID && self.selectedMessageThreadID) {
        [self reloadMessagesForChatID:self.selectedChatID interactive:NO];
    }
}

- (void)closeForumTopicList:(id)sender {
    (void)sender;
    if (!self.showingForumTopicList) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    self.showingForumTopicList = NO;
    self.topicParentChatID = nil;
    self.topicParentTitle = nil;
    self.topicParentAvatarLocalPath = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    self.chatsExhausted = NO;
    self.autoChatListRefreshArmed = YES;

    NSArray *restoreItems = self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : [NSArray array];
    NSUInteger selectedIndex = [self indexOfChatID:parentChatID inChatItems:restoreItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:restoreItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
    } else {
        [self.chatTableView deselectAll:nil];
    }
    self.suppressChatSelectionHandling = NO;
    self.chatItemsBeforeTopicList = nil;
    [self.chatsLabel setStringValue:@"Chats"];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
    [parentChatID release];
}

- (void)reloadCurrentForumTopicListInteractive:(BOOL)interactive {
    if (!self.showingForumTopicList || ![self.topicParentChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    NSString *parentTitle = [self.topicParentTitle copy];
    NSString *parentAvatarPath = [self.topicParentAvatarLocalPath copy];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading topics..."];
        [self appendDetail:@"Reloading forum topics from TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:parentChatID limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL stillCurrent = (self.showingForumTopicList && self.topicParentChatID && [self.topicParentChatID longLongValue] == [parentChatID longLongValue]);
            if (stillCurrent && [topics count] > 0) {
                NSMutableArray *topicItems = [NSMutableArray array];
                NSUInteger index = 0;
                for (index = 0; index < [topics count]; index++) {
                    id candidate = [topics objectAtIndex:index];
                    if (![candidate isKindOfClass:[TGChatItem class]]) {
                        continue;
                    }
                    TGChatItem *topicItem = (TGChatItem *)candidate;
                    [topicItem setAvatarLocalPath:parentAvatarPath];
                    [topicItems addObject:topicItem];
                }
                self.suppressChatSelectionHandling = YES;
                [self.chatItems removeAllObjects];
                [self.chatItems addObjectsFromArray:topicItems];
                [self.chatTableView reloadData];
                self.suppressChatSelectionHandling = NO;
                self.selectedChatID = parentChatID;
                self.selectedChatTitle = parentTitle;
                self.selectedChatTypeSummary = @"Forum";
                self.selectedChatAvatarLocalPath = parentAvatarPath;
                self.selectedChatLastReadOutboxMessageID = nil;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                TGChatItem *firstTopicItem = ([topicItems count] > 0 && [[topicItems objectAtIndex:0] isKindOfClass:[TGChatItem class]]) ? [topicItems objectAtIndex:0] : nil;
                if (firstTopicItem) {
                    NSNumber *firstThreadID = nil;
                    if ([[firstTopicItem messageThreadID] respondsToSelector:@selector(longLongValue)]) {
                        firstThreadID = [NSNumber numberWithLongLong:[[firstTopicItem messageThreadID] longLongValue]];
                    }
                    self.selectedChatTitle = [[firstTopicItem title] length] > 0 ? [firstTopicItem title] : parentTitle;
                    self.selectedChatTypeSummary = [firstTopicItem typeSummary];
                    self.selectedChatAvatarLocalPath = [firstTopicItem avatarLocalPath] ? [firstTopicItem avatarLocalPath] : parentAvatarPath;
                    self.selectedMessageThreadID = firstThreadID;
                    self.selectedMessageTopicKind = ([[firstTopicItem messageTopicKind] length] > 0 ? [firstTopicItem messageTopicKind] : @"forum");
                    self.suppressChatSelectionHandling = YES;
                    [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
                    [self.chatTableView scrollRowToVisible:0];
                    self.suppressChatSelectionHandling = NO;
                } else {
                    [self.chatTableView deselectAll:nil];
                }
                [self refreshSelectedChatHeaderDisplay];
                [self loadPinnedMessageForSelectedChat];
                [self.messageItems removeAllObjects];
                [self.inlineMediaPlaybackCoordinator removeAllPlayback];
                [self.messageTableView reloadData];
                NSString *topicListTitle = ([parentTitle length] > 0 ? parentTitle : @"Topics");
                [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: loaded %lu topics.", (unsigned long)[topicItems count]]];
                if (firstTopicItem && self.selectedChatID && self.selectedMessageThreadID) {
                    [self reloadMessagesForChatID:self.selectedChatID interactive:NO];
                }
            } else if (stillCurrent && [topicErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            }
            [topics release];
            [topicErrorMessage release];
            [parentChatID release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}

- (void)loadForumTopicsForChatItem:(TGChatItem *)chatItem {
    if (!chatItem || [chatItem isForumTopic] || self.forumTopicRefreshInFlight) {
        return;
    }
    id chatID = [chatItem chatID];
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    if (![[chatItem typeSummary] isEqualToString:@"Supergroup"]) {
        return;
    }

    self.forumTopicRefreshInFlight = YES;
    NSUInteger topicLoadingGeneration = self.messageLoadingGeneration + 1;
    self.messageLoadingGeneration = topicLoadingGeneration;
    self.messageLoadingIndicatorVisible = YES;
    [self.messageLoadingSpinner startAnimation:self];
    [self updateVisibleSection];
    NSNumber *chatIDCopy = [[NSNumber numberWithLongLong:[chatID longLongValue]] retain];
    TGChatItem *chatItemCopy = [chatItem retain];
    NSString *parentTitle = [[chatItem title] copy];
    NSString *parentAvatarPath = [[chatItem avatarLocalPath] copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:chatIDCopy limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.forumTopicRefreshInFlight = NO;
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && self.selectedMessageThreadID == nil);
            if (selectionStillCurrent && [topics count] > 0) {
                [self showForumTopicListForChatItem:chatItemCopy topics:topics];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: found %lu topics in %@", (unsigned long)[topics count], parentTitle ? parentTitle : @"selected chat"]];
            } else if (selectionStillCurrent) {
                if ([topicErrorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
                }
                [self reloadMessagesForChatID:chatIDCopy interactive:NO];
            } else if (self.messageLoadingGeneration == topicLoadingGeneration) {
                self.messageLoadingIndicatorVisible = NO;
                [self.messageLoadingSpinner stopAnimation:self];
                [self updateVisibleSection];
            }
            [topics release];
            [topicErrorMessage release];
            [chatIDCopy release];
            [chatItemCopy release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}
