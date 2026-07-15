- (NSString *)shortPreviewForReplyMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return @"";
    }
    NSString *text = TGDisplayTextForMessageItem(item);
    if ([text length] == 0) {
        if ([item isStickerMessage]) {
            text = @"Sticker";
        } else if ([item isVoiceNoteMessage]) {
            text = @"Voice message";
        } else if ([item isVideoNoteMessage]) {
            text = @"Video note";
        } else if ([item isVisualMediaMessage]) {
            text = [item visualMediaPlaceholderTitle];
        } else {
            text = [item preview];
        }
    }
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([text length] > 120) {
        text = [[text substringToIndex:117] stringByAppendingString:@"..."];
    }
    return ([text length] > 0) ? text : @"Message";
}

- (void)updateReplyPanelContent {
    TGMessageItem *item = self.replyTargetMessageItem;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        [self.replyPanelTitleField setStringValue:@"Reply"];
        [self.replyPanelTextField setStringValue:@""];
        return;
    }
    NSString *title = nil;
    if ([[item senderDisplayName] length] > 0) {
        title = [NSString stringWithFormat:@"Reply to %@", [item senderDisplayName]];
    } else if ([item outgoing]) {
        title = @"Reply to yourself";
    } else {
        title = @"Reply";
    }
    [self.replyPanelTitleField setStringValue:title];
    [self.replyPanelTextField setStringValue:[self shortPreviewForReplyMessageItem:item]];
}

- (void)clearReplyTarget {
    self.replyTargetMessageItem = nil;
    self.replyTargetChatID = nil;
    self.replyTargetThreadID = nil;
    self.replyTargetTopicKind = nil;
    [self updateVisibleSection];
    [self layoutContentView];
}

- (void)clearReplyTargetIfSelectionDiffersFromChatID:(NSNumber *)chatID
                                      messageThreadID:(NSNumber *)messageThreadID
                                     messageTopicKind:(NSString *)messageTopicKind {
    if (!self.replyTargetMessageItem) {
        return;
    }
    BOOL sameChat = (self.replyTargetChatID && chatID && [self.replyTargetChatID longLongValue] == [chatID longLongValue]);
    BOOL sameThread = ((!self.replyTargetThreadID && !messageThreadID) ||
                       (self.replyTargetThreadID && messageThreadID && [self.replyTargetThreadID longLongValue] == [messageThreadID longLongValue]));
    BOOL sameTopic = ((!self.replyTargetTopicKind && !messageTopicKind) ||
                      (self.replyTargetTopicKind && messageTopicKind && [self.replyTargetTopicKind isEqualToString:messageTopicKind]));
    if (!sameChat || !sameThread || !sameTopic) {
        [self clearReplyTarget];
    }
}

- (void)replyToMessageFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    self.replyTargetMessageItem = item;
    self.replyTargetChatID = [NSNumber numberWithLongLong:[[item chatID] longLongValue]];
    self.replyTargetThreadID = self.selectedMessageThreadID;
    self.replyTargetTopicKind = self.selectedMessageTopicKind;
    [self updateReplyPanelContent];
    [self updateVisibleSection];
    [self layoutContentView];
    [self requestComposerRefocus];
}

- (void)cancelReplyTarget:(id)sender {
    (void)sender;
    [self clearReplyTarget];
    [self requestComposerRefocus];
}

- (NSDictionary *)forwardDestinationForChatItem:(TGChatItem *)chatItem {
    if (![chatItem isKindOfClass:[TGChatItem class]]) {
        return nil;
    }
    NSNumber *chatID = [chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    NSMutableDictionary *destination = [NSMutableDictionary dictionary];
    [destination setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    if ([chatItem isForumTopic] && [[chatItem messageThreadID] respondsToSelector:@selector(longLongValue)]) {
        [destination setObject:[NSNumber numberWithLongLong:[[chatItem messageThreadID] longLongValue]] forKey:@"thread_id"];
        if ([[chatItem messageTopicKind] length] > 0) {
            [destination setObject:[chatItem messageTopicKind] forKey:@"topic_kind"];
        }
    }
    NSString *title = [[chatItem title] length] > 0 ? [chatItem title] : @"Chat";
    [destination setObject:title forKey:@"title"];
    return destination;
}

- (NSArray *)forwardDestinationItems {
    NSMutableArray *destinations = [NSMutableArray array];
    if ([self.profileUserID respondsToSelector:@selector(longLongValue)]) {
        NSDictionary *saved = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithLongLong:[self.profileUserID longLongValue]], @"chat_id",
                               @"Saved Messages", @"title",
                               nil];
        [destinations addObject:saved];
    }
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        NSDictionary *destination = [self forwardDestinationForChatItem:[self.chatItems objectAtIndex:index]];
        if ([destination count] > 0) {
            [destinations addObject:destination];
        }
    }
    return destinations;
}

- (void)forwardMessageItem:(TGMessageItem *)item toDestination:(NSDictionary *)destination {
    if (![item isKindOfClass:[TGMessageItem class]] || ![destination isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSNumber *fromChatID = [[item chatID] retain];
    NSArray *messageIDs = [[self messageIDsForMessageActionItem:item] retain];
    NSNumber *toChatID = [[destination objectForKey:@"chat_id"] retain];
    NSNumber *threadID = [[destination objectForKey:@"thread_id"] retain];
    NSString *topicKind = [[destination objectForKey:@"topic_kind"] copy];
    NSString *destinationTitle = [[destination objectForKey:@"title"] copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Forwarding..."];
    [self appendDetail:[NSString stringWithFormat:@"Forwarding message to %@...", [destinationTitle length] > 0 ? destinationTitle : @"chat"]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *forwardError = nil;
        NSString *forwardSummary = [client forwardMessagesFromChatID:fromChatID
                                                           messageIDs:messageIDs
                                                            toChatID:toChatID
                                                     messageThreadID:threadID
                                                    messageTopicKind:topicKind
                                                            timeout:8.0
                                                              error:&forwardError];
        NSString *errorMessage = [[forwardError localizedDescription] copy];
        BOOL succeeded = ([forwardSummary length] > 0);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:@"Message forwarded"];
                [self appendDetail:@"TDLib forward accepted."];
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
            } else {
                [self.statusField setStringValue:@"Forward failed"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib forward: %@", [errorMessage length] > 0 ? errorMessage : @"not confirmed"]];
            }
            [errorMessage release];
            [fromChatID release];
            [messageIDs release];
            [toChatID release];
            [threadID release];
            [topicKind release];
            [destinationTitle release];
            [client release];
        });
        [pool drain];
    });
}

- (void)forwardMessageFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSArray *destinations = [self forwardDestinationItems];
    if ([destinations count] == 0) {
        [self appendDetail:@"Forward unavailable: no destination chats loaded yet."];
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Forward message"];
    [alert setInformativeText:@"Choose where to forward this message."];
    [alert addButtonWithTitle:@"Forward"];
    [alert addButtonWithTitle:@"Cancel"];
    NSPopUpButton *popup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 300, 26) pullsDown:NO] autorelease];
    NSUInteger index = 0;
    for (index = 0; index < [destinations count]; index++) {
        NSDictionary *destination = [destinations objectAtIndex:index];
        NSString *title = [destination objectForKey:@"title"];
        [popup addItemWithTitle:([title length] > 0 ? title : @"Chat")];
        [[popup lastItem] setRepresentedObject:destination];
    }
    [alert setAccessoryView:popup];
    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        return;
    }
    NSDictionary *destination = [[popup selectedItem] representedObject];
    [self forwardMessageItem:item toDestination:destination];
}

- (void)forwardMessageToSavedMessagesFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] || ![self.profileUserID respondsToSelector:@selector(longLongValue)]) {
        [self appendDetail:@"Saved Messages destination is not available yet."];
        return;
    }
    NSDictionary *destination = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithLongLong:[self.profileUserID longLongValue]], @"chat_id",
                                 @"Saved Messages", @"title",
                                 nil];
    [self forwardMessageItem:item toDestination:destination];
}
