- (NSNumber *)oldestLoadedMessageID {
    long long minimumMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            long long value = [messageID longLongValue];
            if (minimumMessageID == 0 || value < minimumMessageID) {
                minimumMessageID = value;
            }
        }
    }
    if (minimumMessageID > 0) {
        return [NSNumber numberWithLongLong:minimumMessageID];
    }
    return nil;
}

- (NSArray *)messageItemsInDisplayOrderFromItems:(NSArray *)items {
    return [items sortedArrayUsingFunction:TGCompareMessageItemsAscending context:NULL];
}

- (NSString *)deduplicationKeyForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }

    id chatID = [item chatID];
    id date = [item date];
    NSString *preview = [item preview] ? [item preview] : @"";
    long long chatValue = [chatID respondsToSelector:@selector(longLongValue)] ? [chatID longLongValue] : 0;
    long long dateValue = [date respondsToSelector:@selector(longLongValue)] ? [date longLongValue] : 0;

    return [NSString stringWithFormat:@"%lld|%lld|%d|%@", chatValue, dateValue, [item outgoing] ? 1 : 0, preview];
}

- (BOOL)messageItem:(TGMessageItem *)left isLikelyLocalDuplicateOfMessageItem:(TGMessageItem *)right {
    if (![left isKindOfClass:[TGMessageItem class]] || ![right isKindOfClass:[TGMessageItem class]]) {
        return NO;
    }
    if (![left outgoing] || ![right outgoing]) {
        return NO;
    }
    id leftChatID = [left chatID];
    id rightChatID = [right chatID];
    if (![leftChatID respondsToSelector:@selector(longLongValue)] ||
        ![rightChatID respondsToSelector:@selector(longLongValue)] ||
        [leftChatID longLongValue] != [rightChatID longLongValue]) {
        return NO;
    }
    NSString *leftPreview = [left preview] ? [left preview] : @"";
    NSString *rightPreview = [right preview] ? [right preview] : @"";
    NSString *leftContentType = [left contentType] ? [left contentType] : @"";
    NSString *rightContentType = [right contentType] ? [right contentType] : @"";
    if (![leftContentType isEqualToString:rightContentType]) {
        return NO;
    }
    BOOL leftHasID = ([[left messageID] respondsToSelector:@selector(longLongValue)] && [[left messageID] longLongValue] > 0);
    BOOL rightHasID = ([[right messageID] respondsToSelector:@selector(longLongValue)] && [[right messageID] longLongValue] > 0);
    long long leftDate = [[left date] respondsToSelector:@selector(longLongValue)] ? [[left date] longLongValue] : 0;
    long long rightDate = [[right date] respondsToSelector:@selector(longLongValue)] ? [[right date] longLongValue] : 0;
    long long delta = leftDate - rightDate;
    if (delta < 0) {
        delta = -delta;
    }
    if ([left isVisualMediaMessage] || [right isVisualMediaMessage]) {
        BOOL stickerLike = [leftContentType isEqualToString:@"messageSticker"];
        NSString *leftMediaPath = [left mediaLocalPath] ? [left mediaLocalPath] : @"";
        NSString *rightMediaPath = [right mediaLocalPath] ? [right mediaLocalPath] : @"";
        if ([leftMediaPath length] == 0) {
            NSArray *leftMediaItems = [left visualMediaItems];
            if ([leftMediaItems count] > 0 && [[leftMediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
                id candidatePath = [(NSDictionary *)[leftMediaItems objectAtIndex:0] objectForKey:@"local_path"];
                if ([candidatePath isKindOfClass:[NSString class]]) {
                    leftMediaPath = (NSString *)candidatePath;
                }
            }
        }
        if ([rightMediaPath length] == 0) {
            NSArray *rightMediaItems = [right visualMediaItems];
            if ([rightMediaItems count] > 0 && [[rightMediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
                id candidatePath = [(NSDictionary *)[rightMediaItems objectAtIndex:0] objectForKey:@"local_path"];
                if ([candidatePath isKindOfClass:[NSString class]]) {
                    rightMediaPath = (NSString *)candidatePath;
                }
            }
        }
        if (leftHasID && rightHasID) {
            return ([[left messageID] longLongValue] == [[right messageID] longLongValue]);
        }
        if ([leftMediaPath length] > 0 && [rightMediaPath length] > 0 && ![leftMediaPath isEqualToString:rightMediaPath]) {
            return NO;
        }
        if ([leftMediaPath length] == 0 || [rightMediaPath length] == 0) {
            if (stickerLike && [leftPreview isEqualToString:rightPreview] && ([left sending] || [right sending] || !leftHasID || !rightHasID)) {
                return (delta <= 300);
            }
            return NO;
        }
    }
    if (![leftPreview isEqualToString:rightPreview]) {
        return NO;
    }
    if ([left sending] || [right sending]) {
        return (delta <= 300);
    }
    return (delta <= 30);
}

- (TGMessageItem *)preferredMessageItemForDuplicateLeft:(TGMessageItem *)left right:(TGMessageItem *)right {
    if ([left sending] && ![right sending]) {
        return right;
    }
    if (![left sending] && [right sending]) {
        return left;
    }
    id leftID = [left messageID];
    id rightID = [right messageID];
    BOOL leftHasID = ([leftID respondsToSelector:@selector(longLongValue)] && [leftID longLongValue] > 0);
    BOOL rightHasID = ([rightID respondsToSelector:@selector(longLongValue)] && [rightID longLongValue] > 0);
    if (rightHasID && !leftHasID) {
        return right;
    }
    if (leftHasID && !rightHasID) {
        return left;
    }
    long long leftIDValue = leftHasID ? [leftID longLongValue] : 0;
    long long rightIDValue = rightHasID ? [rightID longLongValue] : 0;
    if (rightIDValue > leftIDValue) {
        return right;
    }
    return left;
}

- (NSArray *)deduplicatedMessageItemsFromItems:(NSArray *)items {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        if (![item isKindOfClass:[TGMessageItem class]]) {
            continue;
        }

        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            NSString *messageKey = [NSString stringWithFormat:@"id:%lld", [messageID longLongValue]];
            if ([messageIDs containsObject:messageKey]) {
                continue;
            }
            [messageIDs addObject:messageKey];
        }

        TGMessageItem *previousItem = [result lastObject];
        if ([item outgoing] && previousItem && [previousItem isKindOfClass:[TGMessageItem class]] && [previousItem outgoing]) {
            if ([self messageItem:item isLikelyLocalDuplicateOfMessageItem:previousItem]) {
                TGMessageItem *preferredItem = [self preferredMessageItemForDuplicateLeft:previousItem right:item];
                [result replaceObjectAtIndex:([result count] - 1) withObject:preferredItem];
                continue;
            }
            if ([item isVisualMediaMessage] || [previousItem isVisualMediaMessage]) {
                [result addObject:item];
                continue;
            }
            NSString *currentFallbackKey = [self deduplicationKeyForMessageItem:item];
            NSString *previousFallbackKey = [self deduplicationKeyForMessageItem:previousItem];
            if ([currentFallbackKey length] > 0 && [currentFallbackKey isEqualToString:previousFallbackKey]) {
                id currentID = [item messageID];
                id previousID = [previousItem messageID];
                BOOL currentHasID = ([currentID respondsToSelector:@selector(longLongValue)] && [currentID longLongValue] > 0);
                BOOL previousHasID = ([previousID respondsToSelector:@selector(longLongValue)] && [previousID longLongValue] > 0);
                if (currentHasID && previousHasID && [currentID longLongValue] != [previousID longLongValue]) {
                    [result addObject:item];
                    continue;
                }
                if (currentHasID && !previousHasID) {
                    [result replaceObjectAtIndex:([result count] - 1) withObject:item];
                }
                continue;
            }
        }

        [result addObject:item];
    }

    return result;
}

- (BOOL)removeDisplayedMessageWithID:(NSNumber *)messageID chatID:(NSNumber *)chatID {
    if (![messageID respondsToSelector:@selector(longLongValue)] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return NO;
    }
    long long targetMessageID = [messageID longLongValue];
    long long targetChatID = [chatID longLongValue];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        if (![item isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        id itemMessageID = [item messageID];
        id itemChatID = [item chatID];
        if ([itemMessageID respondsToSelector:@selector(longLongValue)] &&
            [itemChatID respondsToSelector:@selector(longLongValue)] &&
            [itemMessageID longLongValue] == targetMessageID &&
            [itemChatID longLongValue] == targetChatID) {
            [self.messageItems removeObjectAtIndex:index];
            [self.inlineMediaPlaybackCoordinator removeAllPlayback];
            [self.messageTableView reloadData];
            [self scheduleInlineMediaPlaybackRefresh];
            return YES;
        }
    }
    return NO;
}

- (void)scrollMessagesToNewestIfAvailable {
    NSUInteger count = [self.messageItems count];
    if (count > 0) {
        NSInteger newestRow = (NSInteger)count - 1;
        [self.messageTableView scrollRowToVisible:newestRow];
        NSClipView *clipView = [self.messageScrollView contentView];
        NSView *documentView = [self.messageScrollView documentView];
        if (clipView && documentView) {
            NSRect visibleRect = [clipView bounds];
            NSRect documentBounds = [documentView bounds];
            NSPoint targetPoint = NSMakePoint(NSMinX(visibleRect), NSMaxY(documentBounds) - NSHeight(visibleRect));
            if (targetPoint.y < 0.0) {
                targetPoint.y = 0.0;
            }
            [clipView scrollToPoint:targetPoint];
            [self.messageScrollView reflectScrolledClipView:clipView];
        }
    }
    [self updateMessageJumpToNewestButtonVisibility];
}

- (BOOL)shouldShowMessageJumpToNewestButton {
    if (self.messageItemsRepresentFocusedContext &&
        [self.currentAuthState isEqualToString:@"ready"] &&
        self.selectedChatID &&
        ![self.messageScrollView isHidden]) {
        return YES;
    }
    if ([self.messageItems count] <= 20 || !self.messageScrollView || [self.messageScrollView isHidden]) {
        return NO;
    }
    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }
    NSRange visibleRows = [self.messageTableView rowsInRect:[clipView bounds]];
    if (visibleRows.length == 0) {
        return NO;
    }
    NSInteger lastVisibleRow = (NSInteger)(visibleRows.location + visibleRows.length - 1);
    NSInteger newestRow = (NSInteger)[self.messageItems count] - 1;
    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromBottom = NSMaxY(documentBounds) - NSMaxY(visibleRect);
    return ((newestRow - lastVisibleRow) >= 20 && distanceFromBottom > 48.0);
}

- (void)updateMessageJumpToNewestButtonVisibility {
    BOOL ready = ([self.currentAuthState isEqualToString:@"ready"] &&
                  [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats] &&
                  self.selectedChatID != nil);
    [self.messageJumpToNewestButton setHidden:!ready];
    [self.messageJumpToNewestButton setEnabled:ready];
}

- (void)jumpToNewestMessages:(id)sender {
    (void)sender;
    self.forceMessageScrollToNewest = YES;
    if (self.messageItemsRepresentFocusedContext && self.selectedChatID) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.messageItemsRepresentFocusedContext = NO;
        self.olderMessagesExhausted = NO;
        self.messageLoadingIndicatorVisible = YES;
        [self.messageLoadingSpinner startAnimation:self];
        [self updateVisibleSection];
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }
    [self scrollMessagesToNewestIfAvailable];
    [self performSelector:@selector(scrollMessagesToNewestIfAvailable) withObject:nil afterDelay:0.0];
    [self updateMessageJumpToNewestButtonVisibility];
}

- (void)applyRecentMessageItems:(NSArray *)items preservingOlderItems:(BOOL)preserveOlder {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    BOOL forceScrollToNewest = self.forceMessageScrollToNewest;
    self.forceMessageScrollToNewest = NO;
    if (!preserveOlder || [self.messageItems count] == 0) {
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:orderedItems]];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateOutgoingReadStateForVisibleMessages];
        [self markVisiblePinnedMessagesFromPinnedItems];
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        [self.messageTableView reloadData];
        [self scrollMessagesToNewestIfAvailable];
        return;
    }

    BOOL shouldScrollToNewest = forceScrollToNewest || [self isMessageHistoryNearBottom];
    NSMutableDictionary *messageIndexesByID = [NSMutableDictionary dictionary];
    NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:self.messageItems];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID) {
            [messageIndexesByID setObject:[NSNumber numberWithUnsignedInteger:index] forKey:messageID];
        }
    }

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        NSNumber *existingIndex = messageID ? [messageIndexesByID objectForKey:messageID] : nil;
        if (existingIndex) {
            [mergedItems replaceObjectAtIndex:[existingIndex unsignedIntegerValue] withObject:item];
            continue;
        }
        if (messageID) {
            [messageIndexesByID setObject:[NSNumber numberWithUnsignedInteger:[mergedItems count]] forKey:messageID];
        }
        [mergedItems addObject:item];
    }

    [self.messageItems removeAllObjects];
    [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    [self updateOutgoingReadStateForVisibleMessages];
    [self markVisiblePinnedMessagesFromPinnedItems];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    if (shouldScrollToNewest) {
        [self scrollMessagesToNewestIfAvailable];
    } else {
        [self updateMessageJumpToNewestButtonVisibility];
    }
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items preservingVisiblePosition:(BOOL)preserveVisiblePosition {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSInteger firstVisibleRow = 0;
    if (preserveVisiblePosition) {
        NSPoint visibleOrigin = [[self.messageScrollView contentView] bounds].origin;
        firstVisibleRow = [self.messageTableView rowAtPoint:visibleOrigin];
        if (firstVisibleRow < 0) {
            firstVisibleRow = 0;
        }
    }
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *existingItem = [self.messageItems objectAtIndex:index];
        id messageID = [existingItem messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    NSMutableArray *itemsToPrepend = [NSMutableArray array];
    NSUInteger added = 0;
    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [itemsToPrepend addObject:item];
        added++;
    }

    if (added > 0) {
        NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:itemsToPrepend];
        [mergedItems addObjectsFromArray:self.messageItems];
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    }

    [self updateOutgoingReadStateForVisibleMessages];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    if (added > 0) {
        if (preserveVisiblePosition) {
            NSUInteger targetRow = (NSUInteger)firstVisibleRow + added;
            if (targetRow >= [self.messageItems count]) {
                targetRow = [self.messageItems count] - 1;
            }
            [self.messageTableView scrollRowToVisible:targetRow];
        } else {
            [self scrollMessagesToNewestIfAvailable];
        }
    } else {
        [self updateMessageJumpToNewestButtonVisibility];
    }
    return added;
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items {
    return [self appendOlderMessageItems:items preservingVisiblePosition:YES];
}

- (BOOL)isChatListNearBottom {
    if ([self.chatItems count] == 0 || self.chatsExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isChatListScrollable {
    if ([self.chatItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.chatTableView rowHeight] + [self.chatTableView intercellSpacing].height) * (CGFloat)[self.chatItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)isChatListNearTop {
    if ([self.chatItems count] == 0 || self.showingForumTopicList || ![self isChatListScrollable]) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 18.0);
}

- (void)chatScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.chatScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        self.controlsBusy ||
        self.backgroundChatRefreshInFlight ||
        [self.chatItems count] == 0) {
        return;
    }

    if ([self isChatListNearTop]) {
        self.autoChatListRefreshArmed = NO;
        return;
    }

    self.autoChatListRefreshArmed = YES;

    if (self.chatsExhausted) {
        return;
    }

    if (![self isChatListNearBottom]) {
        self.autoChatListLoadArmed = YES;
        return;
    }

    if (!self.autoChatListLoadArmed) {
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }

    if (nextLimit <= self.chatPreviewLimit) {
        self.autoChatListLoadArmed = NO;
        return;
    }

    self.autoChatListLoadArmed = NO;
    [self reloadChatsInteractive:NO preserveSelection:YES requestedLimit:nextLimit];
}

- (BOOL)isMessageHistoryNearBottom {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isMessageHistoryScrollable {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.messageTableView rowHeight] + [self.messageTableView intercellSpacing].height) * (CGFloat)[self.messageItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)messageHistoryNeedsPrefill {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }
    return ([self.messageItems count] < TGMessagePrefillMinimumRows || ![self isMessageHistoryScrollable]);
}

- (BOOL)isMessageHistoryNearTop {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    if (![self isMessageHistoryScrollable]) {
        return NO;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 48.0);
}

- (void)messageScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.messageScrollView contentView]) {
        return;
    }

    [self refreshInlineMediaPlayback];
    [self updateMessageJumpToNewestButtonVisibility];

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        self.olderMessagesExhausted ||
        [self.messageItems count] == 0) {
        return;
    }

    if (![self isMessageHistoryNearTop]) {
        self.autoOlderMessagesLoadArmed = YES;
        return;
    }

    if (!self.autoOlderMessagesLoadArmed) {
        return;
    }

    self.autoOlderMessagesLoadArmed = NO;
    [self reloadOlderMessagesInteractive];
}

- (void)prefillOlderMessagesIfNeededWithAttemptsRemaining:(NSUInteger)attemptsRemaining {
    if (attemptsRemaining == 0 ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        ![self messageHistoryNeedsPrefill]) {
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    self.backgroundMessageRefreshInFlight = YES;

      TGTDLibClient *client = [self.client retain];
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        BOOL hadMessageError = (messageError != nil);
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
          NSArray *itemsCopy = [items copy];

          dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            NSUInteger added = 0;
            if (selectionStillCurrent && itemsCopy) {
                added = [self appendOlderMessageItems:itemsCopy preservingVisiblePosition:NO];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: prefilled %lu older previews", (unsigned long)added]];
                }
            } else if (selectionStillCurrent && hadMessageError) {
                self.autoOlderMessagesLoadArmed = YES;
            }

            self.backgroundMessageRefreshInFlight = NO;
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            } else {
                [self updateAuthControlsForState:self.currentAuthState];
            }

            if (selectionStillCurrent &&
                added > 0 &&
                attemptsRemaining > 1 &&
                [self messageHistoryNeedsPrefill]) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:(attemptsRemaining - 1)];
            } else {
                [self handlePendingLiveRefreshesIfPossible];
            }

            [itemsCopy release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection {
    [self reloadChatsInteractive:interactive preserveSelection:preserveSelection requestedLimit:self.chatPreviewLimit];
}

- (NSArray *)readReceiptMessageIDsFromItems:(NSArray *)items {
    if (![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *messageIDs = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        if ([item outgoing]) {
            continue;
        }
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            [messageIDs addObject:[NSNumber numberWithLongLong:[messageID longLongValue]]];
        }
    }
    return messageIDs;
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID {
    [self clearUnreadCountForChatID:chatID messageThreadID:nil];
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    BOOL wantsTopic = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    long long targetChatID = [chatID longLongValue];
    long long targetThreadID = wantsTopic ? [messageThreadID longLongValue] : 0;
    BOOL didClear = NO;
    NSUInteger clearedUnreadCount = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;

        id itemChatID = [item chatID];
        id parentChatID = [item parentChatID];
        long long itemChatValue = [itemChatID respondsToSelector:@selector(longLongValue)] ? [itemChatID longLongValue] : 0;
        long long parentChatValue = [parentChatID respondsToSelector:@selector(longLongValue)] ? [parentChatID longLongValue] : 0;
        BOOL chatMatches = (itemChatValue == targetChatID || parentChatValue == targetChatID);
        if (!chatMatches) {
            continue;
        }

        if (wantsTopic && ![item isForumTopic]) {
            continue;
        }
        if (wantsTopic && [item isForumTopic]) {
            id itemThreadID = [item messageThreadID];
            if (![itemThreadID respondsToSelector:@selector(longLongValue)] || [itemThreadID longLongValue] != targetThreadID) {
                continue;
            }
        }
        if ([[item unreadCount] respondsToSelector:@selector(integerValue)] && [[item unreadCount] integerValue] > 0) {
            clearedUnreadCount += [[item unreadCount] unsignedIntegerValue];
            [item setUnreadCount:[NSNumber numberWithInteger:0]];
            didClear = YES;
        }
    }

    if (didClear) {
        NSString *chatKey = [self chatMuteDefaultsKeyForChatID:chatID];
        NSNumber *cachedUnreadCount = ([chatKey length] > 0) ? [self.localMuteUnreadCountsByChatID objectForKey:chatKey] : nil;
        if (cachedUnreadCount) {
            NSUInteger cachedValue = [cachedUnreadCount unsignedIntegerValue];
            NSUInteger updatedValue = (clearedUnreadCount >= cachedValue) ? 0 : (cachedValue - clearedUnreadCount);
            [self.localMuteUnreadCountsByChatID setObject:[NSNumber numberWithUnsignedInteger:updatedValue] forKey:chatKey];
        }
        [self.chatTableView reloadData];
        [self updateApplicationBadge];
    }
}

- (void)scheduleMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    NSArray *itemsCopy = [items copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                           (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
        BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                              (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
        BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
        BOOL messagePaneVisible = ([self.messageScrollView window] != nil && ![self.messageScrollView isHidden]);
        if (selectionStillCurrent && messagePaneVisible && [self.currentAuthState isEqualToString:@"ready"]) {
            [self clearUnreadCountForChatID:chatIDCopy messageThreadID:messageThreadIDCopy];
            [self markMessageItemsReadForChatID:chatIDCopy messageThreadID:messageThreadIDCopy messageTopicKind:messageTopicKindCopy items:itemsCopy];
        }
        [chatIDCopy release];
        [messageThreadIDCopy release];
        [messageTopicKindCopy release];
        [itemsCopy release];
    });
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind items:(NSArray *)items {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSArray *messageIDs = [self readReceiptMessageIDsFromItems:items];
    if ([messageIDs count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [messageThreadID retain];
    NSString *messageTopicKindCopy = [messageTopicKind copy];
    NSArray *messageIDsCopy = [messageIDs copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *readError = nil;
        BOOL success = [client markMessagesAsReadForChatID:chatIDCopy
                                           messageThreadID:messageThreadIDCopy
                                          messageTopicKind:messageTopicKindCopy
                                                messageIDs:messageIDsCopy
                                                   timeout:4.0
                                                     error:&readError];
        NSString *readErrorMessage = [[readError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self clearUnreadCountForChatID:chatIDCopy messageThreadID:messageThreadIDCopy];
                [self appendDetail:@"TDLib read state: selected chat messages marked as read."];
            } else if ([readErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib read state: %@", readErrorMessage]];
            }
            [readErrorMessage release];
            [chatIDCopy release];
            [messageThreadIDCopy release];
            [messageTopicKindCopy release];
            [messageIDsCopy release];
            [client release];
        });

        [pool drain];
    });
}

- (void)reloadProfileSummaryIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy || self.profileSummaryLoading) {
        return;
    }

    self.profileSummaryLoading = YES;
    [self.profileRefreshButton setEnabled:NO];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *profileError = nil;
        NSDictionary *profile = [[client currentUserProfileSummaryWithTimeout:6.0 error:&profileError] retain];
        NSString *profileErrorMessage = [[profileError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client != client || ![self.currentAuthState isEqualToString:@"ready"]) {
                self.profileSummaryLoading = NO;
                [self.profileRefreshButton setEnabled:YES];
                [profile release];
                [profileErrorMessage release];
                return;
            }

            if (profile) {
                NSString *displayName = [profile objectForKey:@"display_name"];
                NSString *firstName = [profile objectForKey:@"first_name"];
                NSString *lastName = [profile objectForKey:@"last_name"];
                NSString *username = [profile objectForKey:@"username"];
                NSString *phoneNumber = [profile objectForKey:@"phone_number"];
                NSString *bio = [profile objectForKey:@"bio"];
                id userID = [profile objectForKey:@"id"];
                if ([userID respondsToSelector:@selector(longLongValue)]) {
                    self.profileUserID = [NSNumber numberWithLongLong:[userID longLongValue]];
                } else {
                    self.profileUserID = nil;
                }
                self.profileDisplayName = ([displayName length] > 0) ? displayName : nil;
                self.profileFirstName = ([firstName length] > 0) ? firstName : nil;
                self.profileLastName = ([lastName length] > 0) ? lastName : nil;
                self.profileUsername = ([username length] > 0) ? username : nil;
                self.profilePhoneNumber = ([phoneNumber length] > 0) ? phoneNumber : nil;
                self.profileAvatarLocalPath = [profile objectForKey:@"avatar_path"];
                self.profileBio = ([bio length] > 0) ? bio : nil;
                [self refreshProfileDisplay];
                [self updateSavedMessagesPresentationForChatItems];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = YES;
            } else {
                self.profileFirstName = nil;
                self.profileLastName = nil;
                self.profilePhoneNumber = nil;
                self.profileBio = nil;
                [self.profileStateField setStringValue:@""];
                [self refreshProfileDisplay];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = NO;
                if (profileErrorMessage) {
                    [self appendDetail:[NSString stringWithFormat:@"Profile: %@", profileErrorMessage]];
                }
            }
            self.profileSummaryLoading = NO;
            [self.profileRefreshButton setEnabled:YES];
            [profile release];
            [profileErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection requestedLimit:(NSUInteger)requestedLimit {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        if (interactive) {
            [self appendDetail:@"Chats are available only after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = YES;
        return;
    }

    NSNumber *preferredChatID = preserveSelection ? [self.selectedChatID retain] : nil;
    NSNumber *activeFilterID = [self.selectedChatFilterID retain];
    NSPoint visibleChatOrigin = NSZeroPoint;
    BOOL shouldRestoreChatOrigin = NO;
    if (!interactive) {
        NSClipView *chatClipView = [self.chatScrollView contentView];
        if (chatClipView) {
            visibleChatOrigin = [chatClipView bounds].origin;
            shouldRestoreChatOrigin = YES;
        }
    }
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading chats..."];
        [self appendDetail:activeFilterID ? @"Loading folder chat previews from TDLib..." : @"Loading main chat previews from TDLib..."];
    } else {
        self.backgroundChatRefreshInFlight = YES;
    }

    if (requestedLimit == 0) {
        requestedLimit = TGStatusChatPreviewInitialLimit;
    } else if (requestedLimit > TGStatusChatPreviewMaximumLimit) {
        requestedLimit = TGStatusChatPreviewMaximumLimit;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        BOOL chatsExhausted = NO;
        NSArray *items = nil;
        if (activeFilterID) {
            items = [client chatPreviewItemsForChatFilterID:activeFilterID
                                                      limit:requestedLimit
                                                    timeout:10.0
                                                  exhausted:&chatsExhausted
                                                      error:&chatError];
        } else {
            items = [client mainChatPreviewItemsWithLimit:requestedLimit timeout:10.0 error:&chatError];
            chatsExhausted = [client mainChatListExhausted];
        }
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL filterStillCurrent = NO;
            if (!activeFilterID && !self.selectedChatFilterID) {
                filterStillCurrent = YES;
            } else if (activeFilterID && self.selectedChatFilterID && [activeFilterID integerValue] == [self.selectedChatFilterID integerValue]) {
                filterStillCurrent = YES;
            }

            if (!filterStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib chats: ignored stale folder result after selection changed."];
                } else {
                    [self appendDetail:@"TDLib live refresh: ignored stale folder result after selection changed."];
                }
            } else if (itemsCopy) {
                self.chatPreviewLimit = [itemsCopy count];
                self.chatsExhausted = chatsExhausted;
                NSNumber *effectivePreferredChatID = preferredChatID;
                if (preserveSelection &&
                    preferredChatID &&
                    self.selectedChatID &&
                    [self.selectedChatID longLongValue] != [preferredChatID longLongValue]) {
                    effectivePreferredChatID = self.selectedChatID;
                }
                [self applyChatItems:itemsCopy preserveSelection:preserveSelection preferredChatID:effectivePreferredChatID];
                if (!interactive && shouldRestoreChatOrigin) {
                    NSClipView *chatClipView = [self.chatScrollView contentView];
                    NSView *chatDocumentView = [self.chatScrollView documentView];
                    if (chatClipView && chatDocumentView) {
                        NSRect visibleRect = [chatClipView bounds];
                        NSRect documentBounds = [chatDocumentView bounds];
                        CGFloat maxY = NSMaxY(documentBounds) - NSHeight(visibleRect);
                        if (maxY < 0.0) {
                            maxY = 0.0;
                        }
                        CGFloat restoredY = visibleChatOrigin.y;
                        if (restoredY > maxY) {
                            restoredY = maxY;
                        }
                        if (restoredY < 0.0) {
                            restoredY = 0.0;
                        }
                        [chatClipView scrollToPoint:NSMakePoint(visibleChatOrigin.x, restoredY)];
                        [self.chatScrollView reflectScrolledClipView:chatClipView];
                    }
                }
                [self setOfflineModeActive:NO reason:nil];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu %@chat previews (limit %lu)", (unsigned long)[itemsCopy count], activeFilterID ? @"folder " : @"", (unsigned long)requestedLimit]];
                    if (self.chatsExhausted) {
                        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
                    }
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                BOOL looksOffline = TGStatusErrorLooksOffline(chatErrorMessage);
                if (interactive) {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable. Keeping the current chat list visible; refresh after the connection returns."];
                    } else {
                        NSString *message = chatErrorMessage ? @"Chat preview request failed. Check connection state and try again." : @"Chat list did not return a result.";
                        [self.statusField setStringValue:@"Chats unavailable"];
                        [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                    }
                } else {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable during live chat refresh. Keeping cached chats visible."];
                    } else {
                        [self appendDetail:@"TDLib live refresh: chat preview refresh failed."];
                    }
                }
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundChatRefreshInFlight = NO;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
            [activeFilterID release];
            [preferredChatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadMessagesForChatID:(NSNumber *)chatID interactive:(BOOL)interactive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !chatID) {
        if (interactive) {
            [self appendDetail:@"Select a chat after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    BOOL shouldShowMessageLoading = (interactive || [self.messageItems count] == 0 || self.forceMessageScrollToNewest);
    NSUInteger messageLoadingGeneration = 0;
    if (shouldShowMessageLoading) {
        messageLoadingGeneration = self.messageLoadingGeneration + 1;
        self.messageLoadingGeneration = messageLoadingGeneration;
        self.messageLoadingIndicatorVisible = YES;
        [self.messageLoadingSpinner startAnimation:self];
        [self updateVisibleSection];
    }
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading messages..."];
        [self appendDetail:(messageThreadIDCopy ? @"Loading recent topic message previews from TDLib..." : @"Loading recent message previews from TDLib...")];
    } else {
        self.backgroundMessageRefreshInFlight = YES;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatIDCopy
                                                    messageThreadID:messageThreadIDCopy
                                                   messageTopicKind:messageTopicKindCopy
                                                              limit:TGMessagePreviewInitialLimit
                                                            timeout:8.0
                                                              error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
                }
            } else if (itemsCopy) {
                BOOL preserveOlder = (!interactive && [self.messageItems count] > 0);
                if (self.forceMessageScrollToNewest) {
                    preserveOlder = NO;
                }
                self.messageItemsRepresentFocusedContext = NO;
                [self applyRecentMessageItems:itemsCopy preservingOlderItems:preserveOlder];
                [self scheduleMessageItemsReadForChatID:chatIDCopy items:itemsCopy];
                [self setOfflineModeActive:NO reason:nil];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                BOOL looksOffline = TGStatusErrorLooksOffline(messageErrorMessage);
                if (interactive) {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable. Keeping the current messages visible; refresh after the connection returns."];
                    } else {
                        NSString *message = messageErrorMessage ? @"Message preview request failed. Check connection state and try again." : @"Message history did not return a result.";
                        [self.statusField setStringValue:@"Messages unavailable"];
                        [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                    }
                } else {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable during live message refresh. Keeping cached messages visible."];
                    } else {
                        [self appendDetail:@"TDLib live refresh: selected chat refresh failed."];
                    }
                }
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            BOOL shouldPrefillOlderMessages = (selectionStillCurrent && itemsCopy && [self messageHistoryNeedsPrefill]);
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundMessageRefreshInFlight = NO;
            }
            if (shouldShowMessageLoading && self.messageLoadingGeneration == messageLoadingGeneration) {
                self.messageLoadingIndicatorVisible = NO;
                [self.messageLoadingSpinner stopAnimation:self];
                [self updateVisibleSection];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (shouldPrefillOlderMessages) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:TGMessagePrefillMaxAttempts];
            } else if (!interactive) {
                [self handlePendingLiveRefreshesIfPossible];
            }
            if (self.composerRefocusPending && selectionStillCurrent) {
                [self consumePendingComposerRefocus:nil];
            }
            [itemsCopy release];
              [messageErrorMessage release];
              [authorizationState release];
              [messageTopicKindCopy release];
              [messageThreadIDCopy release];
              [chatIDCopy release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadOlderMessagesInteractive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after sign-in is ready."];
        return;
    }

    if (self.backgroundMessageRefreshInFlight) {
        [self appendDetail:@"TDLib messages: wait for the current message load to finish."];
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [self appendDetail:@"TDLib messages: load recent messages before requesting older history."];
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    NSUInteger messageLoadingGeneration = self.messageLoadingGeneration + 1;
    self.messageLoadingGeneration = messageLoadingGeneration;
    self.messageLoadingIndicatorVisible = YES;
    [self.messageLoadingSpinner startAnimation:self];
    [self updateVisibleSection];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Loading older messages..."];
    [self appendDetail:(messageThreadIDCopy ? @"Loading older topic message previews from TDLib..." : @"Loading older message previews from TDLib...")];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale older-history result for previous chat selection."];
            } else if (itemsCopy) {
                NSUInteger added = [self appendOlderMessageItems:itemsCopy];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added == 0) {
                    self.autoOlderMessagesLoadArmed = NO;
                }
                [self.statusField setStringValue:(added > 0) ? @"Connected" : @"No older messages"];
                [self setOfflineModeActive:NO reason:nil];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: appended %lu older previews", (unsigned long)added]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib older message previews appended: %lu", (unsigned long)added]];
            } else {
                if (TGStatusErrorLooksOffline(messageErrorMessage)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Older history will stay deferred until the connection returns."];
                } else {
                    [self.statusField setStringValue:@"Older messages unavailable"];
                    NSString *message = messageErrorMessage ? messageErrorMessage : @"Older message history did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                }
                [[TGLogger sharedLogger] log:@"TDLib older message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (self.messageLoadingGeneration == messageLoadingGeneration) {
                self.messageLoadingIndicatorVisible = NO;
                [self.messageLoadingSpinner stopAnimation:self];
                [self updateVisibleSection];
            }
            [self handlePendingLiveRefreshesIfPossible];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)handlePendingLiveRefreshesIfPossible {
    if (self.controlsBusy || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (self.pendingLiveMessageRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && hasMessageTarget) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.pendingLiveMessageRefresh = NO;
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }

    if (self.pendingLiveChatRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && !self.showingForumTopicList) {
        self.pendingLiveChatRefresh = NO;
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)pollLiveUpdates:(NSTimer *)timer {
    (void)timer;
    if (!self.client) {
        return;
    }

    NSArray *updates = [self.client drainSafeUpdateSummaries];
    if ([updates count] == 0) {
        return;
    }

    NSNumber *selectedChatID = [self.selectedChatID retain];
    NSString *latestAuthorizationState = nil;
    BOOL needsChatRefresh = NO;
    BOOL needsMessageRefresh = NO;
    BOOL needsChatFilterRefresh = NO;
    BOOL needsPinnedMessageRefresh = NO;

    NSUInteger index = 0;
    for (index = 0; index < [updates count]; index++) {
        NSDictionary *summary = [updates objectAtIndex:index];
        if (![summary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *kind = [summary objectForKey:@"kind"];
        if ([kind isEqualToString:@"authorization"]) {
            NSString *state = [summary objectForKey:@"state"];
            if ([state length] > 0) {
                latestAuthorizationState = state;
            }
            continue;
        }

        if ([kind isEqualToString:@"new_message"] || [kind isEqualToString:@"chat_update"] || [kind isEqualToString:@"message_update"]) {
            needsChatRefresh = YES;
            self.chatsExhausted = NO;
            [self.client invalidateMainChatListExhaustion];
            if ([kind isEqualToString:@"new_message"]) {
                id direction = [summary objectForKey:@"direction"];
                id incomingChatID = [summary objectForKey:@"chat_id"];
                NSString *incomingChatKey = [self chatMuteDefaultsKeyForChatID:incomingChatID];
                NSNumber *knownLocalUnreadCount = ([incomingChatKey length] > 0) ? [self.localMuteUnreadCountsByChatID objectForKey:incomingChatKey] : nil;
                if ([direction isEqualToString:@"Incoming"] && knownLocalUnreadCount) {
                    NSUInteger updatedLocalUnreadCount = [knownLocalUnreadCount unsignedIntegerValue] + 1;
                    [self.localMuteUnreadCountsByChatID setObject:[NSNumber numberWithUnsignedInteger:updatedLocalUnreadCount] forKey:incomingChatKey];
                    [self updateApplicationBadge];
                }
                [self presentNotificationForUpdateSummary:summary];
            }
            id chatID = [summary objectForKey:@"chat_id"];
            id oldMessageID = [summary objectForKey:@"old_message_id"];
            if ([kind isEqualToString:@"message_update"] &&
                [oldMessageID respondsToSelector:@selector(longLongValue)] &&
                [chatID respondsToSelector:@selector(longLongValue)]) {
                [self removeDisplayedMessageWithID:oldMessageID chatID:chatID];
            }
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsMessageRefresh = YES;
            }
        } else if ([kind isEqualToString:@"chat_action"]) {
            [self handleTypingUpdateSummary:summary];
        } else if ([kind isEqualToString:@"draft_update"]) {
            [self handleComposerDraftUpdateSummary:summary];
        } else if ([kind isEqualToString:@"pinned_message_update"]) {
            id chatID = [summary objectForKey:@"chat_id"];
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsPinnedMessageRefresh = YES;
            }
        } else if ([kind isEqualToString:@"poll_update"]) {
            if (selectedChatID && [self.messageItems count] > 0) {
                needsMessageRefresh = YES;
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Polls: live update received%@; refreshing selected messages.",
                                              [summary objectForKey:@"poll_id"] ? [NSString stringWithFormat:@" poll=%@", [summary objectForKey:@"poll_id"]] : @""]];
            }
        } else if ([kind isEqualToString:@"account_unread"]) {
            id unreadCount = [summary objectForKey:@"count"];
            if ([unreadCount respondsToSelector:@selector(unsignedIntegerValue)]) {
                self.accountUnreadCount = [unreadCount unsignedIntegerValue];
                self.hasAccountUnreadCount = YES;
                [self updateApplicationBadge];
            }
        } else if ([kind isEqualToString:@"chat_filters"]) {
            needsChatFilterRefresh = YES;
        }
    }

    if ([latestAuthorizationState length] > 0 && ![latestAuthorizationState isEqualToString:self.currentAuthState]) {
        [self updateAuthControlsForState:latestAuthorizationState];
        if ([self isTerminalAuthorizationState:latestAuthorizationState]) {
            [self recoverTDLibClientAfterAuthorizationState:latestAuthorizationState expectedClient:self.client];
        } else {
            self.authClientRecoveryAttemptCount = 0;
        }
    }

    if (needsChatRefresh) {
        self.pendingLiveChatRefresh = YES;
    }
    if (needsMessageRefresh) {
        self.pendingLiveMessageRefresh = YES;
    }
    if (needsChatFilterRefresh) {
        [self reloadChatFiltersIfReady];
    }
    if (needsPinnedMessageRefresh) {
        [self loadPinnedMessageForSelectedChat];
    }

    [selectedChatID release];
    [self handlePendingLiveRefreshesIfPossible];
}

- (void)connectOnLaunch:(id)sender {
    (void)sender;
    if (self.initialConnectStarted) {
        return;
    }
    self.initialConnectStarted = YES;
    [self checkTDLib:nil];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    if (self.controlsBusy) {
        return;
    }
    if (!self.client) {
        self.client = [[[TGTDLibClient alloc] init] autorelease];
    }
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Connecting..."];
    [self appendDetail:@"Connecting to Telegram core..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        BOOL parametersAttempted = NO;
        BOOL parametersMissingConfiguration = NO;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersAttempted = YES;
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:NULL];
                parametersMissingConfiguration = ([parametersSummary length] == 0);
            }
            BOOL missingInternalConfiguration = parametersMissingConfiguration;
            if ([authorizationState isEqualToString:@"waitTdlibParameters"] && missingInternalConfiguration) {
                finalAuthorizationState = @"waitApiCredentials";
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            if (![finalAuthorizationState isEqualToString:@"waitApiCredentials"]) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            }
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
            if (![finalAuthorizationState length]) {
                NSError *fallbackAuthorizationError = nil;
                NSString *fallbackAuthorizationState = [client authorizationStateSummaryWithTimeout:4.0 error:&fallbackAuthorizationError];
                if ([fallbackAuthorizationState length] > 0) {
                    finalAuthorizationState = fallbackAuthorizationState;
                } else if (!finalAuthorizationError && fallbackAuthorizationError) {
                    finalAuthorizationError = fallbackAuthorizationError;
                }
            }
            if (![finalAuthorizationState length] && [authorizationState length] > 0) {
                finalAuthorizationState = authorizationState;
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];
        NSString *receiverSummary = [[client receiverStatusSummary] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client != client) {
                return;
            }
            if (probeSummary) {
                [self.statusField setStringValue:[finalAuthorizationState isEqualToString:@"ready"] ? @"Connected" : @"Login required"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (receiverSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib receiver: %@", receiverSummary]];
                }
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersAttempted) {
                    [self appendDetail:@"TDLib parameters: could not set local parameters; current auth state requires API credentials or local configuration."];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                if ([finalAuthorizationState isEqualToString:@"waitApiCredentials"]) {
                    [self setLoginErrorWithLocalizationKey:@"login.config.missing"];
                    [self updateVisibleSection];
                }
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
                [self setControlsBusy:NO];
                if ([self isTerminalAuthorizationState:finalAuthorizationState]) {
                    [self recoverTDLibClientAfterAuthorizationState:finalAuthorizationState expectedClient:client];
                } else {
                    self.authClientRecoveryAttemptCount = 0;
                }
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self setControlsBusy:NO];
                [self.statusField setStringValue:@"Connection unavailable"];
                [self setLoginErrorWithLocalizationKey:@"login.connection.unavailable"];
                [self updateVisibleSection];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
        });

        [client release];
        [receiverSummary release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    if ([self isTerminalAuthorizationState:self.currentAuthState]) {
        if (!self.authClientRecoveryInFlight) {
            self.authClientRecoveryAttemptCount = 0;
            [self recoverTDLibClientAfterAuthorizationState:self.currentAuthState expectedClient:self.client];
        }
        return;
    }
    if (self.controlsBusy || self.authSubmissionInFlight) {
        return;
    }
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Login input is not available for the current connection state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    NSString *input = [[inputField stringValue] copy];
    if ([input length] == 0) {
        NSString *emptyErrorKey = @"login.empty.password";
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            emptyErrorKey = @"login.empty.phone";
        } else if ([state isEqualToString:@"waitCode"]) {
            emptyErrorKey = @"login.empty.code";
        }
        [self setLoginErrorWithLocalizationKey:emptyErrorKey];
        [self updateVisibleSection];
        [input release];
        [state release];
        [self appendDetail:@"Login input is empty."];
        return;
    }

    [self setLoginErrorMessage:nil];
    [self updateVisibleSection];
    self.authSubmissionInFlight = YES;
    [self setControlsBusy:YES];
    [self.authButton setTitle:TGLoc(@"login.sending")];
    [self.statusField setStringValue:@"Signing in..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.authSubmissionInFlight = NO;
            if (!authSummary && [state isEqualToString:@"waitCode"]) {
                [self.authTextField setStringValue:@""];
            } else if (!authSummary && [state isEqualToString:@"waitPassword"]) {
                [self.authSecureField setStringValue:@""];
            }
            if (authSummary) {
                [self.statusField setStringValue:@"Sign-in step submitted"];
                [self setLoginErrorMessage:nil];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"Sign-in needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:finalAuthorizationState]];
                }
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:state]];
                }
            } else {
                [self updateAuthControlsForState:state];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:state]];
                }
            }
            [self updateVisibleSection];
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    if (self.showingForumTopicList) {
        [self reloadCurrentForumTopicListInteractive:YES];
        return;
    }
    self.autoChatListLoadArmed = YES;
    self.autoChatListRefreshArmed = YES;
    [self reloadChatsInteractive:YES preserveSelection:YES];
}

- (void)loadMoreChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    if (self.chatsExhausted) {
        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }
    if (nextLimit == self.chatPreviewLimit) {
        [self appendDetail:@"TDLib chats: maximum preview limit reached for this build."];
        return;
    }
    [self reloadChatsInteractive:YES preserveSelection:YES requestedLimit:nextLimit];
}

- (void)loadMessages:(id)sender {
    (void)sender;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self reloadMessagesForChatID:self.selectedChatID interactive:YES];
}

- (void)loadOlderMessages:(id)sender {
    (void)sender;
    [self reloadOlderMessagesInteractive];
}
