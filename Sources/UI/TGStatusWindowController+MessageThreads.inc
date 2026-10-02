// Discussion navigation owns its return context independently of the selected
// chat: a channel post can resolve to a different discussion supergroup.
- (NSDictionary *)commentThreadNavigationContext {
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    NSArray *keys = [NSArray arrayWithObjects:@"selectedChatID", @"selectedMessageThreadID",
        @"selectedMessageTopicKind", @"selectedChatTitle", @"selectedChatTypeSummary",
        @"selectedChatAvatarLocalPath", @"selectedChatLastReadInboxMessageID",
        @"selectedChatLastReadOutboxMessageID", @"selectedChatUnreadCount",
        @"initialUnreadPositionPending", @"unreadSeparatorDismissedForCurrentSelection",
        @"showingForumTopicList", @"forumTopicsPresentedInTopBar",
        @"topicParentChatID", @"topicParentTitle", @"topicParentAvatarLocalPath",
        @"chatItemsBeforeTopicList", @"forumTopicItems", nil];
    NSString *key = nil;
    for (key in keys) {
        id value = [self valueForKey:key];
        [context setObject:value ? value : (id)[NSNull null] forKey:key];
    }
    return context;
}

- (void)restoreCommentThreadNavigationContext:(NSDictionary *)context {
    NSString *key = nil;
    for (key in context) {
        id value = [context objectForKey:key];
        [self setValue:(value == [NSNull null] ? nil : value) forKey:key];
    }
    if (self.showingForumTopicList) {
        self.suppressChatSelectionHandling = YES;
        [self.chatItems removeAllObjects];
        [self.chatItems addObjectsFromArray:self.forumTopicItems ? self.forumTopicItems : [NSArray array]];
        [self.chatTableView reloadData];
        NSUInteger row = 0;
        for (TGChatItem *topic in self.chatItems) {
            if ([[topic messageThreadID] isEqual:self.selectedMessageThreadID]) {
                [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                break;
            }
            row++;
        }
        self.suppressChatSelectionHandling = NO;
        [self.composeChatButton setAction:@selector(createForumTopic:)];
        [self.composeChatButton setToolTip:TGLoc(@"forum.topic.create")];
        [self.loadChatsButton setToolTip:@"Refresh topics"];
        [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)",
            self.topicParentTitle ? self.topicParentTitle : @"Topics", (unsigned long)[self.forumTopicItems count]]];
    }
    [self rebuildForumTopicTabs];
}

- (void)resetMessagePresentationForCommentNavigation {
    self.pinnedMessageItems = [NSArray array];
    self.pinnedMessageItem = nil;
    self.pinnedMessageCarouselIndex = 0;
    self.searchGeneration++;
    self.forumTopicNavigationGeneration++;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    self.messageItemsRepresentFocusedContext = NO;
    [self clearTypingIndicator];
    [self.visibleReadReceiptMessageIDs removeAllObjects];
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    [self restoreComposerDraftForChatID:self.selectedChatID
                        messageThreadID:self.selectedMessageThreadID
                       messageTopicKind:self.selectedMessageTopicKind];
    [self refreshSelectedChatHeaderDisplay];
    [self refreshForumTopicTabSelection];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
    [self reloadMessagesForChatID:self.selectedChatID interactive:NO];
    [self requestComposerRefocus];
}

- (void)openMessageCommentsForItem:(TGMessageItem *)item {
    if (!TGMessageItemHasCommentThread(item) || self.commentThreadOpenInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        return;
    }
    NSNumber *sourceMessageID = [item commentThreadMessageID] ? [item commentThreadMessageID] : [item messageID];
    NSNumber *sourceChatID = [[item chatID] retain];
    NSNumber *sourceMessageIDCopy = [sourceMessageID retain];
    NSDictionary *context = [[self commentThreadNavigationContext] retain];
    NSUInteger navigationGeneration = self.searchGeneration;
    NSUInteger forumGeneration = self.forumTopicNavigationGeneration;
    self.commentThreadOpenInFlight = YES;
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *destination = [[client resolveMessageThreadForChatID:sourceChatID
                                                                  messageID:sourceMessageIDCopy
                                                                    timeout:8.0 error:NULL] retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.commentThreadOpenInFlight = NO;
            NSDictionary *current = [self commentThreadNavigationContext];
            BOOL stillCurrent = (navigationGeneration == self.searchGeneration &&
                forumGeneration == self.forumTopicNavigationGeneration && !self.chatNavigationClosed &&
                [self.currentAuthState isEqualToString:@"ready"] &&
                [[context objectForKey:@"selectedChatID"] isEqual:[current objectForKey:@"selectedChatID"]] &&
                [[context objectForKey:@"selectedMessageThreadID"] isEqual:[current objectForKey:@"selectedMessageThreadID"]] &&
                [[context objectForKey:@"selectedMessageTopicKind"] isEqual:[current objectForKey:@"selectedMessageTopicKind"]]);
            if (stillCurrent && destination) {
                NSNumber *chatID = [destination objectForKey:@"chat_id"];
                NSNumber *threadID = [destination objectForKey:@"message_thread_id"];
                BOOL alreadyOpen = ([self.selectedMessageTopicKind isEqualToString:@"thread"] &&
                    [self.selectedChatID isEqual:chatID] && [self.selectedMessageThreadID isEqual:threadID]);
                if (!alreadyOpen) {
                    [self saveComposerDraftForChatID:self.selectedChatID
                                     messageThreadID:self.selectedMessageThreadID
                                    messageTopicKind:self.selectedMessageTopicKind];
                    if (![self.selectedMessageTopicKind isEqualToString:@"thread"]) {
                        self.commentThreadNavigationStack = [NSMutableArray array];
                    }
                    if (!self.commentThreadNavigationStack) {
                        self.commentThreadNavigationStack = [NSMutableArray array];
                    }
                    [self.commentThreadNavigationStack addObject:context];
                    self.selectedChatID = chatID;
                    self.selectedMessageThreadID = threadID;
                    self.selectedMessageTopicKind = @"thread";
                    self.selectedChatTitle = [NSString stringWithFormat:@"%@ %@",
                        [self.selectedChatTitle length] > 0 ? self.selectedChatTitle : TGLoc(@"message.comments.threadTitle"),
                        TGLoc(@"message.comments.threadSuffix")];
                    // Permissions belong to the discussion supergroup, not the
                    // read-only broadcast channel that owns the source post.
                    self.selectedChatTypeSummary = @"Supergroup";
                    self.showingForumTopicList = NO;
                    self.forumTopicsPresentedInTopBar = NO;
                    self.selectedChatLastReadInboxMessageID = nil;
                    self.selectedChatLastReadOutboxMessageID = nil;
                    self.selectedChatUnreadCount = 0;
                    self.initialUnreadPositionPending = NO;
                    self.unreadSeparatorDismissedForCurrentSelection = YES;
                    [self resetMessagePresentationForCommentNavigation];
                }
            } else if (stillCurrent) {
                [self.statusField setStringValue:TGLoc(@"message.comments.unavailable")];
                [self appendDetail:@"Comments: thread resolution failed; keeping the current conversation."];
            }
            [destination release];
            [sourceChatID release];
            [sourceMessageIDCopy release];
            [context release];
            [client release];
        });
        [pool drain];
    });
}

- (void)closeMessageCommentsThread:(id)sender {
    (void)sender;
    if (![self.selectedMessageTopicKind isEqualToString:@"thread"] ||
        [self.commentThreadNavigationStack count] == 0) {
        return;
    }
    [self saveComposerDraftForChatID:self.selectedChatID
                     messageThreadID:self.selectedMessageThreadID
                    messageTopicKind:self.selectedMessageTopicKind];
    NSDictionary *context = [[self.commentThreadNavigationStack lastObject] retain];
    [self.commentThreadNavigationStack removeLastObject];
    [self restoreCommentThreadNavigationContext:context];
    [context release];
    [self resetMessagePresentationForCommentNavigation];
    [self loadPinnedMessageForSelectedChat];
}

- (void)applyMessageInteractionUpdateSummary:(NSDictionary *)summary {
    NSMutableIndexSet *rows = [NSMutableIndexSet indexSet];
    NSUInteger row = 0;
    for (TGMessageItem *item in self.messageItems) {
        if (TGApplyMessageInteractionSummaryToItem(item, summary)) {
            [rows addIndex:row];
        }
        row++;
    }
    if ([rows count] > 0) {
        [self.messageTableView noteHeightOfRowsWithIndexesChanged:rows];
        [self.messageTableView reloadDataForRowIndexes:rows
                                       columnIndexes:[NSIndexSet indexSetWithIndex:0]];
    }
}
