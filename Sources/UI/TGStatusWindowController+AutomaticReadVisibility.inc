/* Automatic read receipts require a conversation the user can actually see.
   Explicit “Mark as read” commands use their separate confirmed-read path. */
- (BOOL)conversationAllowsAutomaticRead {
    return self.client && [self.currentAuthState isEqualToString:@"ready"] && self.selectedChatID &&
        TGConversationTranscriptIsVisible(self.messageScrollView, [self window], [NSApp isActive],
            (!self.activeSection || [self.activeSection isEqualToString:TGSectionChats]),
            self.chatNavigationClosed, self.mediaCenterVisible);
}

- (void)invalidateAutomaticReadRequests {
    self.automaticReadGeneration = self.automaticReadGeneration + 1;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scheduleVisibleMessageItemsRead) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissCurrentUnreadSeparator) object:nil];
    [self.visibleReadReceiptMessageIDs removeAllObjects];
}

- (void)synchronizeUserOpenedChat {
    BOOL visible = [self conversationAllowsAutomaticRead];
    if (!visible) [self invalidateAutomaticReadRequests];
    [self.client setUserOpenedChatID:(visible ? self.selectedChatID : nil)];
}

- (void)conversationVisibilityDidChange:(NSNotification *)notification {
    /* Will-resign/hide arrives before NSApp/window flags have changed. */
    NSString *name = [notification name];
    BOOL leaving = [name isEqualToString:NSApplicationWillResignActiveNotification] ||
                   [name isEqualToString:NSApplicationWillHideNotification] ||
                   [name isEqualToString:NSWindowWillMiniaturizeNotification] ||
                   [name isEqualToString:NSWindowDidResignKeyNotification];
    [self invalidateAutomaticReadRequests];
    if (leaving) {
        [self.client setUserOpenedChatID:nil];
        return;
    }
    [self synchronizeUserOpenedChat];
    [self scheduleVisibleMessageItemsRead];
}

- (NSArray *)visibleUnreadMessageItemsAwaitingReceipt {
    if (!self.selectedChatID || [self.messageItems count] == 0) {
        return [NSArray array];
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSRange visibleRows = [self.messageTableView rowsInRect:[clipView bounds]];
    if (visibleRows.length == 0 || visibleRows.location == NSNotFound) {
        return [NSArray array];
    }

    long long lastReadMessageID = [self.selectedChatLastReadInboxMessageID respondsToSelector:@selector(longLongValue)] ? [self.selectedChatLastReadInboxMessageID longLongValue] : 0;
    NSMutableArray *visibleUnreadItems = [NSMutableArray array];
    NSUInteger lastRow = MIN(NSMaxRange(visibleRows), [self.messageItems count]);
    NSUInteger row = visibleRows.location;
    for (row = visibleRows.location; row < lastRow; row++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:row];
        NSNumber *messageID = [item messageID];
        if (![[item chatID] isEqual:self.selectedChatID] || [item outgoing] ||
            ![messageID respondsToSelector:@selector(longLongValue)] ||
            [messageID longLongValue] <= lastReadMessageID ||
            [self.visibleReadReceiptMessageIDs containsObject:messageID]) {
            continue;
        }
        [visibleUnreadItems addObject:item];
    }
    return visibleUnreadItems;
}

- (void)scheduleVisibleMessageItemsRead {
    if (![self conversationAllowsAutomaticRead] || self.initialUnreadPositionPending) {
        return;
    }

    NSArray *items = [self visibleUnreadMessageItemsAwaitingReceipt];
    if ([items count] == 0) {
        return;
    }

    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSNumber *messageID = [[items objectAtIndex:index] messageID];
        if (messageID) {
            [self.visibleReadReceiptMessageIDs addObject:messageID];
        }
    }
    [self markVisibleMessageItemsReadForChatID:self.selectedChatID
                               messageThreadID:self.selectedMessageThreadID
                              messageTopicKind:self.selectedMessageTopicKind
                                         items:items];
}

- (void)markVisibleMessageItemsReadForChatID:(NSNumber *)chatID
                              messageThreadID:(NSNumber *)messageThreadID
                             messageTopicKind:(NSString *)messageTopicKind
                                        items:(NSArray *)items {
    NSArray *messageIDs = [self readReceiptMessageIDsFromItems:items];
    if ([messageIDs count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [messageThreadID retain];
    NSString *messageTopicKindCopy = [messageTopicKind copy];
    NSArray *messageIDsCopy = [messageIDs copy];
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.automaticReadGeneration;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        __block BOOL allowed = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            allowed = (generation == self.automaticReadGeneration && self.client == client &&
                       [self conversationAllowsAutomaticRead] && [self.selectedChatID isEqual:chatIDCopy] &&
                       ((self.selectedMessageThreadID == messageThreadIDCopy) || [self.selectedMessageThreadID isEqual:messageThreadIDCopy]) &&
                       ((self.selectedMessageTopicKind == messageTopicKindCopy) || [self.selectedMessageTopicKind isEqual:messageTopicKindCopy]));
        });
        NSError *readError = nil;
        BOOL success = allowed && [client markVisibleMessagesAsReadForChatID:chatIDCopy
                                           messageThreadID:messageThreadIDCopy
                                          messageTopicKind:messageTopicKindCopy
                                                messageIDs:messageIDsCopy
                                                   timeout:4.0
                                                     error:&readError];
        NSString *readErrorMessage = [[readError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameSelection = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue]);
            BOOL sameThread = ((!messageThreadIDCopy && !self.selectedMessageThreadID) ||
                               (messageThreadIDCopy && self.selectedMessageThreadID &&
                                [messageThreadIDCopy longLongValue] == [self.selectedMessageThreadID longLongValue]));
            BOOL sameTopic = ((self.selectedMessageTopicKind == messageTopicKindCopy) || [self.selectedMessageTopicKind isEqual:messageTopicKindCopy]);
            BOOL sameContext = (self.client == client && generation == self.automaticReadGeneration && sameSelection && sameThread && sameTopic);
            if (!success && sameContext) {
                [self.visibleReadReceiptMessageIDs minusSet:[NSSet setWithArray:messageIDsCopy]];
            }
            /* Non-forced viewMessages OK is not proof of a server read: the
               openChat acknowledgement may still be in flight. Notification
               cleanup waits for authoritative read-inbox updates/snapshots. */
            if (success && sameContext && [self conversationAllowsAutomaticRead]) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                         selector:@selector(dismissCurrentUnreadSeparator)
                                                           object:nil];
                [self performSelector:@selector(dismissCurrentUnreadSeparator)
                           withObject:nil
                           afterDelay:1.25];
            }
            if (!success && [readErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib visible read state: %@", readErrorMessage]];
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

