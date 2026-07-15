- (TGMessageItem *)messageItemAtCurrentEventWithRow:(NSInteger *)rowOut tablePoint:(NSPoint *)pointOut {
    NSEvent *event = [NSApp currentEvent];
    if (!event) {
        return nil;
    }
    NSPoint tablePoint = [self.messageTableView convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self.messageTableView rowAtPoint:tablePoint];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return nil;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    if (rowOut) {
        *rowOut = row;
    }
    if (pointOut) {
        *pointOut = tablePoint;
    }
    return (TGMessageItem *)item;
}

- (BOOL)messageItem:(TGMessageItem *)item atRow:(NSInteger)row containsTablePoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || row < 0) {
        return NO;
    }
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSRect bubbleRect = TGMessageBubbleRectForItem(item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:item]);
    return (!NSIsEmptyRect(bubbleRect) && NSPointInRect(tablePoint, bubbleRect));
}

- (BOOL)currentEventHitsActionableMessageContentForItem:(TGMessageItem *)item row:(NSInteger)row tablePoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || row < 0) {
        return NO;
    }
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    if (NSIsEmptyRect(cellFrame)) {
        return NO;
    }
    NSDictionary *mediaItem = [self mediaItemForItem:item inCellFrame:cellFrame atPoint:tablePoint];
    if (mediaItem) {
        return TGMediaItemSupportsPreview(mediaItem);
    }
    if (TGMessageItemIsNonVisualPlayableMedia(item)) {
        NSRect bubbleRect = TGMessageBubbleRectForItem(item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:item]);
        if (!NSIsEmptyRect(bubbleRect) && NSPointInRect(tablePoint, bubbleRect)) {
            return YES;
        }
    }
    NSURL *url = [self messageLinkURLForItem:item inCellFrame:cellFrame atPoint:tablePoint];
    return (url != nil);
}

- (TGChatItem *)chatItemAtCurrentEventWithRow:(NSInteger *)rowOut {
    NSEvent *event = [NSApp currentEvent];
    if (!event) {
        return nil;
    }
    NSPoint tablePoint = [self.chatTableView convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = [self.chatTableView rowAtPoint:tablePoint];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        return nil;
    }
    id item = [self.chatItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGChatItem class]]) {
        return nil;
    }
    if (rowOut) {
        *rowOut = row;
    }
    return (TGChatItem *)item;
}

- (NSMenuItem *)chatMuteMenuItemWithTitle:(NSString *)title duration:(NSTimeInterval)duration chatItem:(TGChatItem *)item {
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title
                                                       action:@selector(muteChatFromMenu:)
                                                keyEquivalent:@""] autorelease];
    NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                             item, @"chat",
                             [NSNumber numberWithDouble:duration], @"duration",
                             nil];
    [menuItem setRepresentedObject:payload];
    [menuItem setTarget:self];
    [menuItem setImage:TGTemplateIconAssetImage(@"sound-off", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    return menuItem;
}

- (NSMenuItem *)chatCurrentMuteStateMenuItemForChatItem:(TGChatItem *)item {
    NSString *title = @"Notifications are on";
    NSNumber *chatID = [self notificationChatIDForChatItem:item];
    if ([self isChatIDLocallyMuted:chatID]) {
        title = @"Notifications are muted locally";
    } else if ([item serverNotificationsMuted]) {
        title = @"Muted in Telegram";
    }
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
    [menuItem setEnabled:NO];
    [menuItem setImage:TGTemplateIconAssetImage(([self isChatIDLocallyMuted:chatID] || [item serverNotificationsMuted]) ? @"sound-off" : @"bell",
                                                NSMakeSize(16.0, 16.0),
                                                [NSColor blackColor],
                                                0.72)];
    return menuItem;
}

- (NSString *)safeDownloadFileNameFromName:(NSString *)name fallback:(NSString *)fallback {
    NSString *candidate = ([name length] > 0) ? name : fallback;
    if ([candidate length] == 0) {
        candidate = @"telegraphica-download";
    }
    NSMutableString *safeName = [NSMutableString stringWithString:candidate];
    NSCharacterSet *badCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/:\\"];
    NSUInteger index = 0;
    while (index < [safeName length]) {
        unichar ch = [safeName characterAtIndex:index];
        if ([badCharacters characterIsMember:ch]) {
            [safeName replaceCharactersInRange:NSMakeRange(index, 1) withString:@"-"];
        }
        index++;
    }
    return safeName;
}

- (NSString *)uniqueDownloadDestinationForFileName:(NSString *)fileName {
    NSString *folder = TGConfiguredDownloadFolderPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:folder
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    NSString *safeName = [self safeDownloadFileNameFromName:fileName fallback:@"telegraphica-download"];
    NSString *destination = [folder stringByAppendingPathComponent:safeName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:destination]) {
        return destination;
    }
    NSString *base = [safeName stringByDeletingPathExtension];
    NSString *extension = [safeName pathExtension];
    NSUInteger suffix = 2;
    while (suffix < 1000) {
        NSString *candidateName = ([extension length] > 0)
            ? [NSString stringWithFormat:@"%@-%lu.%@", base, (unsigned long)suffix, extension]
            : [NSString stringWithFormat:@"%@-%lu", safeName, (unsigned long)suffix];
        NSString *candidate = [folder stringByAppendingPathComponent:candidateName];
        if (![[NSFileManager defaultManager] fileExistsAtPath:candidate]) {
            return candidate;
        }
        suffix++;
    }
    return destination;
}

- (NSNumber *)downloadFileIDForMessageItem:(TGMessageItem *)item localPath:(NSString **)localPathOut fileName:(NSString **)fileNameOut {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    NSString *localPath = [item mediaLocalPath];
    NSNumber *fileID = [item mediaFileID];
    NSString *fileName = [item downloadFileName];
    NSArray *mediaItems = [item visualMediaItems];
    if (([localPath length] == 0 || !fileID) && [mediaItems count] > 0) {
        id media = [mediaItems objectAtIndex:0];
        if ([media isKindOfClass:[NSDictionary class]]) {
            if ([localPath length] == 0) {
                localPath = TGMediaItemFullLocalPath(media);
                if ([localPath length] == 0) {
                    localPath = TGMediaItemLocalPath(media);
                }
            }
            if (!fileID) {
                fileID = TGMediaItemFullFileID(media);
            }
            if ([fileName length] == 0) {
                id mediaFileName = [(NSDictionary *)media objectForKey:@"file_name"];
                if ([mediaFileName isKindOfClass:[NSString class]]) {
                    fileName = mediaFileName;
                }
            }
        }
    }
    if ([fileName length] == 0 && [localPath length] > 0) {
        fileName = [localPath lastPathComponent];
    }
    if ([fileName length] == 0) {
        fileName = [item isDocumentMessage] ? @"document" : @"media";
    }
    if (localPathOut) {
        *localPathOut = localPath;
    }
    if (fileNameOut) {
        *fileNameOut = fileName;
    }
    return fileID;
}

- (void)downloadAttachmentForMessageItem:(TGMessageItem *)item {
    NSString *localPath = nil;
    NSString *fileName = nil;
    NSNumber *fileID = [self downloadFileIDForMessageItem:item localPath:&localPath fileName:&fileName];
    if ([localPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        NSString *destination = [self uniqueDownloadDestinationForFileName:fileName];
        NSError *copyError = nil;
        if ([[NSFileManager defaultManager] copyItemAtPath:localPath toPath:destination error:&copyError]) {
            [self appendDetail:[NSString stringWithFormat:@"Downloaded to %@", destination]];
        } else {
            [self appendDetail:[NSString stringWithFormat:@"Download copy failed: %@", [copyError localizedDescription]]];
        }
        return;
    }
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self appendDetail:@"Attachment file id is not available yet."];
        return;
    }

    NSNumber *fileIDCopy = [fileID retain];
    NSString *fileNameCopy = [fileName copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Downloading file..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSString *downloadedPath = [[client downloadedLocalPathForFileID:fileIDCopy timeout:16.0 error:&downloadError] copy];
        NSString *downloadErrorMessage = [[downloadError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([downloadedPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:downloadedPath]) {
                NSString *destination = [self uniqueDownloadDestinationForFileName:fileNameCopy];
                NSError *copyError = nil;
                if ([[NSFileManager defaultManager] copyItemAtPath:downloadedPath toPath:destination error:&copyError]) {
                    [self.statusField setStringValue:@"File downloaded"];
                    [self appendDetail:[NSString stringWithFormat:@"Downloaded to %@", destination]];
                } else {
                    [self.statusField setStringValue:@"Download failed"];
                    [self appendDetail:[NSString stringWithFormat:@"Download copy failed: %@", [copyError localizedDescription]]];
                }
            } else {
                [self.statusField setStringValue:@"Download failed"];
                [self appendDetail:([downloadErrorMessage length] > 0 ? downloadErrorMessage : @"TDLib did not return a file path.")];
            }
            [downloadedPath release];
            [downloadErrorMessage release];
            [fileIDCopy release];
            [fileNameCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)populateChatContextMenu:(NSMenu *)menu {
    [menu removeAllItems];
    NSInteger row = -1;
    TGChatItem *item = [self chatItemAtCurrentEventWithRow:&row];
    if (!item) {
        return;
    }

    NSString *chatTitle = [[item title] length] > 0 ? [item title] : @"Chat";
    NSMenuItem *titleItem = [[[NSMenuItem alloc] initWithTitle:chatTitle action:nil keyEquivalent:@""] autorelease];
    [titleItem setEnabled:NO];
    [menu addItem:titleItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *markReadItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.markRead")
                                                           action:@selector(markChatReadFromMenu:)
                                                    keyEquivalent:@""] autorelease];
    [markReadItem setRepresentedObject:item];
    [markReadItem setTarget:self];
    [markReadItem setEnabled:([[item unreadCount] respondsToSelector:@selector(integerValue)] && [[item unreadCount] integerValue] > 0)];
    [markReadItem setImage:TGTemplateIconAssetImage(@"bell", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    [menu addItem:markReadItem];

    NSMenuItem *pinItem = [[[NSMenuItem alloc] initWithTitle:([item isPinned] ? TGLoc(@"chat.unpin") : TGLoc(@"chat.pin"))
                                                      action:@selector(toggleChatPinnedFromMenu:)
                                               keyEquivalent:@""] autorelease];
    [pinItem setRepresentedObject:item];
    [pinItem setTarget:self];
    [pinItem setEnabled:(![item isForumTopic])];
    [menu addItem:pinItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:[self chatCurrentMuteStateMenuItemForChatItem:item]];

    if ([self isChatIDLocallyMuted:[self notificationChatIDForChatItem:item]]) {
        NSMenuItem *unmuteItem = [[[NSMenuItem alloc] initWithTitle:@"Enable local notifications"
                                                             action:@selector(unmuteChatFromMenu:)
                                                      keyEquivalent:@""] autorelease];
        [unmuteItem setRepresentedObject:item];
        [unmuteItem setTarget:self];
        [unmuteItem setImage:TGTemplateIconAssetImage(@"bell", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
        [menu addItem:unmuteItem];
    }

    NSMenu *muteMenu = [[[NSMenu alloc] initWithTitle:@"Mute notifications"] autorelease];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:@"For 1 hour" duration:(60.0 * 60.0) chatItem:item]];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:@"For 1 day" duration:(24.0 * 60.0 * 60.0) chatItem:item]];
    [muteMenu addItem:[NSMenuItem separatorItem]];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:@"Forever" duration:-1.0 chatItem:item]];
    NSMenuItem *muteRoot = [[[NSMenuItem alloc] initWithTitle:@"Mute notifications"
                                                       action:nil
                                                keyEquivalent:@""] autorelease];
    [muteRoot setImage:TGTemplateIconAssetImage(@"sound-off", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    [muteRoot setSubmenu:muteMenu];
    [menu addItem:muteRoot];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == self.chatContextMenu) {
        [self populateChatContextMenu:menu];
        return;
    }

    if (menu != self.messageContextMenu) {
        return;
    }

    [menu removeAllItems];
    NSInteger row = -1;
    NSPoint tablePoint = NSZeroPoint;
    TGMessageItem *item = [self messageItemAtCurrentEventWithRow:&row tablePoint:&tablePoint];
    if (!item || ![item.messageID respondsToSelector:@selector(longLongValue)] || ![item.chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (![self messageItem:item atRow:row containsTablePoint:tablePoint]) {
        return;
    }
    if (TGMessageItemHasDownloadableAttachment(item)) {
        NSString *downloadTitle = [item isDocumentMessage] ? TGLoc(@"message.downloadDocument") : TGLoc(@"message.downloadMedia");
        NSMenuItem *downloadItem = [[[NSMenuItem alloc] initWithTitle:downloadTitle
                                                               action:@selector(downloadMessageAttachmentFromMenu:)
                                                        keyEquivalent:@""] autorelease];
        [downloadItem setRepresentedObject:item];
        [downloadItem setTarget:self];
        [downloadItem setImage:TGTemplateIconAssetImage(([item isDocumentMessage] ? @"document" : @"image"), NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
        [menu addItem:downloadItem];
        [menu addItem:[NSMenuItem separatorItem]];
    }
    BOOL addedMessageAction = NO;
    if (([item canBeEdited] || [item outgoing]) && [[item editableText] length] > 0 && [[item contentType] isEqualToString:@"messageText"]) {
        NSMenuItem *editItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.edit")
                                                           action:@selector(editMessageFromMenu:)
                                                    keyEquivalent:@""] autorelease];
        [editItem setRepresentedObject:item];
        [editItem setTarget:self];
        [menu addItem:editItem];
        addedMessageAction = YES;
    }
    if ([item.messageID respondsToSelector:@selector(longLongValue)] && [item.chatID respondsToSelector:@selector(longLongValue)]) {
        NSMenuItem *deleteItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.delete")
                                                             action:@selector(deleteMessageFromMenu:)
                                                      keyEquivalent:@""] autorelease];
        [deleteItem setRepresentedObject:item];
        [deleteItem setTarget:self];
        [deleteItem setImage:TGTemplateIconAssetImage(@"trash", NSMakeSize(16.0, 16.0), [NSColor redColor], 0.90)];
        [menu addItem:deleteItem];
        addedMessageAction = YES;
    }
    if (addedMessageAction) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    NSArray *emojis = [NSArray arrayWithObjects:@"🔥", @"😁", @"👍", @"👎", @"❤", @"😢", @"😱", nil];
    NSUInteger index = 0;
    for (index = 0; index < [emojis count]; index++) {
        NSString *emoji = [emojis objectAtIndex:index];
        BOOL chosen = [[item chosenReactionEmojis] containsObject:emoji];
        NSString *title = chosen ? [NSString stringWithFormat:@"%@ %@", emoji, @"✓"] : emoji;
        NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title
                                                          action:@selector(reactToMessageFromMenu:)
                                                   keyEquivalent:@""] autorelease];
        NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                                 item, @"message",
                                 emoji, @"emoji",
                                 nil];
        [menuItem setRepresentedObject:payload];
        [menuItem setTarget:self];
        [menu addItem:menuItem];
    }

    NSArray *moreEmojis = [NSArray arrayWithObjects:@"😂", @"🎉", @"👏", @"🙏", @"😍", @"🤔", @"🤯", @"💯", @"😡", @"🥰", nil];
    if ([moreEmojis count] > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
        NSMenu *moreMenu = [[[NSMenu alloc] initWithTitle:@"More reactions"] autorelease];
        for (index = 0; index < [moreEmojis count]; index++) {
            NSString *emoji = [moreEmojis objectAtIndex:index];
            BOOL chosen = [[item chosenReactionEmojis] containsObject:emoji];
            NSString *title = chosen ? [NSString stringWithFormat:@"%@ %@", emoji, @"✓"] : emoji;
            NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title
                                                              action:@selector(reactToMessageFromMenu:)
                                                       keyEquivalent:@""] autorelease];
            NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
                                     item, @"message",
                                     emoji, @"emoji",
                                     nil];
            [menuItem setRepresentedObject:payload];
            [menuItem setTarget:self];
            [moreMenu addItem:menuItem];
        }
        NSMenuItem *moreItem = [[[NSMenuItem alloc] initWithTitle:@"More reactions"
                                                           action:nil
                                                    keyEquivalent:@""] autorelease];
        [moreItem setSubmenu:moreMenu];
        [menu addItem:moreItem];
    }
}

- (NSArray *)messageIDsForMessageActionItem:(TGMessageItem *)item {
    NSMutableArray *messageIDs = [NSMutableArray array];
    if ([item isMediaAlbumMessage]) {
        NSArray *mediaItems = [item visualMediaItems];
        NSUInteger index = 0;
        for (index = 0; index < [mediaItems count]; index++) {
            id media = [mediaItems objectAtIndex:index];
            if (![media isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            id messageID = [(NSDictionary *)media objectForKey:@"message_id"];
            if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
                NSNumber *safeID = [NSNumber numberWithLongLong:[messageID longLongValue]];
                if (![messageIDs containsObject:safeID]) {
                    [messageIDs addObject:safeID];
                }
            }
        }
    }
    if ([messageIDs count] == 0 && [item.messageID respondsToSelector:@selector(longLongValue)]) {
        [messageIDs addObject:[NSNumber numberWithLongLong:[item.messageID longLongValue]]];
    }
    return messageIDs;
}

- (void)editMessageFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)] ||
        [[item editableText] length] == 0) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Message editing is available only after sign-in is ready."];
        return;
    }

    NSString *editedText = [TGMessageActionDialogs editedTextForCurrentText:[item editableText]];
    if ([editedText length] == 0 || [editedText isEqualToString:[item editableText]]) {
        return;
    }

    NSNumber *chatID = [[item chatID] retain];
    NSNumber *messageID = [[item messageID] retain];
    NSString *text = [editedText copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Editing message..."];
    [self appendDetail:@"Submitting message edit through TDLib..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *capabilitiesError = nil;
        NSDictionary *capabilities = [client messageActionCapabilitiesForChatID:chatID messageID:messageID timeout:6.0 error:&capabilitiesError];
        BOOL canEdit = [[capabilities objectForKey:@"can_be_edited"] boolValue];
        NSError *editError = nil;
        NSString *editSummary = nil;
        if (canEdit) {
            editSummary = [client editTextMessageInChatID:chatID messageID:messageID text:text timeout:8.0 error:&editError];
        }
        NSString *errorMessage = [[(canEdit ? editError : capabilitiesError) localizedDescription] copy];
        BOOL succeeded = ([editSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:@"Message edited"];
                [self appendDetail:@"TDLib message edit accepted."];
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            } else {
                [self.statusField setStringValue:@"Edit unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib edit message: %@", [errorMessage length] > 0 ? errorMessage : @"message can no longer be edited"]];
            }
            [errorMessage release];
            [chatID release];
            [messageID release];
            [text release];
            [client release];
        });
        [pool drain];
    });
}

- (void)deleteMessageFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Message deletion is available only after sign-in is ready."];
        return;
    }

    BOOL hasKnownDeleteOptions = ([item capabilitiesKnown] && ([item canBeDeletedOnlyForSelf] || [item canBeDeletedForAllUsers]));
    TGMessageDeleteChoice choice = [TGMessageActionDialogs deleteChoiceWithCanDeleteOnlyForSelf:(hasKnownDeleteOptions ? [item canBeDeletedOnlyForSelf] : YES)
                                                                           canDeleteForAllUsers:(hasKnownDeleteOptions ? [item canBeDeletedForAllUsers] : YES)];
    if (choice == TGMessageDeleteChoiceCancel) {
        return;
    }

    NSNumber *chatID = [[item chatID] retain];
    NSArray *messageIDs = [[self messageIDsForMessageActionItem:item] retain];
    BOOL revoke = (choice == TGMessageDeleteChoiceForEveryone);
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Deleting message..."];
    [self appendDetail:@"Submitting message deletion through TDLib..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *deleteError = nil;
        NSString *deleteSummary = [client deleteMessagesInChatID:chatID messageIDs:messageIDs revoke:revoke timeout:8.0 error:&deleteError];
        NSString *errorMessage = [[deleteError localizedDescription] copy];
        BOOL succeeded = ([deleteSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                BOOL removedDisplayedMessage = NO;
                for (NSNumber *messageID in messageIDs) {
                    if ([self removeDisplayedMessageWithID:messageID chatID:chatID]) {
                        removedDisplayedMessage = YES;
                    }
                }
                [self.statusField setStringValue:@"Message deleted"];
                [self appendDetail:(removedDisplayedMessage ? @"TDLib message deletion accepted; removed from current view." : @"TDLib message deletion accepted.")];
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            } else {
                [self.statusField setStringValue:@"Delete unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib delete message: %@", [errorMessage length] > 0 ? errorMessage : @"message can no longer be deleted"]];
            }
            [errorMessage release];
            [chatID release];
            [messageIDs release];
            [client release];
        });
        [pool drain];
    });
}

- (void)downloadMessageAttachmentFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    [self downloadAttachmentForMessageItem:item];
}

- (void)markChatReadFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]]) {
        return;
    }
    NSNumber *sourceChatID = [item isForumTopic] ? [item parentChatID] : [item chatID];
    NSNumber *sourceThreadID = [item isForumTopic] ? [item messageThreadID] : nil;
    NSString *sourceTopicKind = [item isForumTopic] ? [item messageTopicKind] : nil;
    NSNumber *chatID = [sourceChatID retain];
    NSNumber *threadID = [sourceThreadID retain];
    NSString *topicKind = [sourceTopicKind copy];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        [chatID release];
        [threadID release];
        [topicKind release];
        return;
    }

    TGTDLibClient *client = [self.client retain];
    [self clearUnreadCountForChatID:chatID messageThreadID:threadID];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatID
                                                    messageThreadID:threadID
                                                   messageTopicKind:topicKind
                                                              limit:50
                                                            timeout:6.0
                                                              error:&messageError];
        NSArray *itemsCopy = [items copy];
        NSString *errorMessage = [[messageError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([itemsCopy count] > 0) {
                [self markMessageItemsReadForChatID:chatID messageThreadID:threadID messageTopicKind:topicKind items:itemsCopy];
            } else if ([errorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib mark read: %@", errorMessage]];
            }
            [itemsCopy release];
            [errorMessage release];
            [chatID release];
            [threadID release];
            [topicKind release];
            [client release];
        });
        [pool drain];
    });
}

- (void)toggleChatPinnedFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] || [item isForumTopic] || ![[item chatID] respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Pinning chats is available only after sign-in is ready."];
        return;
    }

    BOOL targetPinned = ![item isPinned];
    TGChatItem *itemCopy = [item retain];
    NSNumber *chatID = [[NSNumber numberWithLongLong:[[item chatID] longLongValue]] retain];
    NSNumber *chatFilterID = [self.selectedChatFilterID retain];
    NSString *title = [[item title] copy];
    TGTDLibClient *client = [self.client retain];

    [item setPinned:targetPinned];
    [self.chatTableView reloadData];
    [self.statusField setStringValue:(targetPinned ? TGLoc(@"chat.pin") : TGLoc(@"chat.unpin"))];
    [self appendDetail:[NSString stringWithFormat:@"%@ %@...", targetPinned ? @"Pinning" : @"Unpinning", [title length] > 0 ? title : @"chat"]];
    [[TGLogger sharedLogger] log:(targetPinned ? @"TDLib chat pin requested." : @"TDLib chat unpin requested.")];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *pinError = nil;
        BOOL succeeded = [client toggleChatPinnedForChatID:chatID chatFilterID:chatFilterID pinned:targetPinned timeout:6.0 error:&pinError];
        NSString *errorMessage = [[pinError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:(targetPinned ? TGLoc(@"chat.pin") : TGLoc(@"chat.unpin"))];
                [self appendDetail:[NSString stringWithFormat:@"%@ accepted for %@.", targetPinned ? @"Pin" : @"Unpin", [title length] > 0 ? title : @"chat"]];
                [self reloadChatsInteractive:NO preserveSelection:YES];
            } else {
                [itemCopy setPinned:!targetPinned];
                [self.chatTableView reloadData];
                [self.statusField setStringValue:@"Pin unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib pin chat: %@", [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [itemCopy release];
            [chatID release];
            [chatFilterID release];
            [title release];
            [client release];
        });
        [pool drain];
    });
}

- (void)muteChatFromMenu:(id)sender {
    id payload = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return;
    }
    TGChatItem *item = [(NSDictionary *)payload objectForKey:@"chat"];
    NSNumber *duration = [(NSDictionary *)payload objectForKey:@"duration"];
    NSNumber *chatID = [self notificationChatIDForChatItem:item];
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![duration respondsToSelector:@selector(doubleValue)]) {
        return;
    }
    [self setLocalNotificationMuteForChatID:chatID duration:[duration doubleValue]];
    [self appendDetail:[NSString stringWithFormat:@"Notifications muted locally for %@.", [[item title] length] > 0 ? [item title] : @"chat"]];
}

- (void)unmuteChatFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    NSNumber *chatID = [self notificationChatIDForChatItem:item];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    [self setLocalNotificationMuteForChatID:chatID duration:0.0];
    [self appendDetail:[NSString stringWithFormat:@"Local notifications enabled for %@.", [[item title] length] > 0 ? [item title] : @"chat"]];
}

- (void)submitReactionEmoji:(NSString *)emoji toMessageItem:(TGMessageItem *)item removing:(BOOL)removing {
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)] ||
        ![emoji isKindOfClass:[NSString class]] ||
        [emoji length] == 0) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Reaction is available only after sign-in is ready."];
        return;
    }
    if (self.controlsBusy) {
        [self appendDetail:@"Wait for the current Telegram operation to finish before sending a reaction."];
        return;
    }

    NSNumber *chatID = [item.chatID retain];
    NSNumber *messageID = [item.messageID retain];
    NSString *reactionEmoji = [emoji copy];
    [self.statusField setStringValue:removing ? @"Removing reaction..." : @"Sending reaction..."];
    [self appendDetail:removing ? @"Removing message reaction through TDLib..." : @"Submitting message reaction to TDLib..."];
    [[TGLogger sharedLogger] log:removing ? @"TDLib reaction remove requested." : @"TDLib reaction send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *reactionError = nil;
        NSError *stateError = nil;
        NSString *reactionSummary = nil;
        if (removing) {
            reactionSummary = [client removeReactionFromChatID:chatID
                                                     messageID:messageID
                                                         emoji:reactionEmoji
                                                       timeout:8.0
                                                         error:&reactionError];
        } else {
            reactionSummary = [client addReactionToChatID:chatID
                                                messageID:messageID
                                                    emoji:reactionEmoji
                                                  timeout:8.0
                                                    error:&reactionError];
        }
        NSString *reactionErrorMessage = [[reactionError localizedDescription] copy];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        BOOL reactionSucceeded = ([reactionSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (reactionSucceeded) {
                [self.statusField setStringValue:removing ? @"Reaction removed" : @"Reaction sent"];
                [self appendDetail:removing ? @"TDLib reaction: removed by TDLib." : @"TDLib reaction: accepted by TDLib."];
                [[TGLogger sharedLogger] log:removing ? @"TDLib reaction remove accepted." : @"TDLib reaction send accepted."];
            } else {
                NSString *message = ([reactionErrorMessage length] > 0) ? reactionErrorMessage : @"Reaction was not accepted by TDLib.";
                [self.statusField setStringValue:@"Reaction unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib reaction: %@", message]];
                [[TGLogger sharedLogger] log:removing ? @"TDLib reaction remove failed or unsupported." : @"TDLib reaction send failed or unsupported."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (reactionSucceeded) {
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            }
            [authorizationState release];
            [reactionErrorMessage release];
            [chatID release];
            [messageID release];
            [reactionEmoji release];
        });

        [client release];
        [pool drain];
    });
}

- (void)sendReactionEmoji:(NSString *)emoji toMessageItem:(TGMessageItem *)item {
    BOOL removing = NO;
    if ([item isKindOfClass:[TGMessageItem class]] && [[item chosenReactionEmojis] containsObject:emoji]) {
        removing = YES;
    }
    [self submitReactionEmoji:emoji toMessageItem:item removing:removing];
}

- (void)reactToMessageFromMenu:(id)sender {
    id payload = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return;
    }
    TGMessageItem *item = [(NSDictionary *)payload objectForKey:@"message"];
    NSString *emoji = [(NSDictionary *)payload objectForKey:@"emoji"];
    [self sendReactionEmoji:emoji toMessageItem:item];
}

- (void)reactToMessageWithDefaultReaction:(id)sender {
    (void)sender;
    NSInteger row = [self.messageTableView clickedRow];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return;
    }
    id candidate = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![candidate isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    TGMessageItem *item = (TGMessageItem *)candidate;
    NSEvent *event = [NSApp currentEvent];
    if (event) {
        NSPoint tablePoint = [self.messageTableView convertPoint:[event locationInWindow] fromView:nil];
        if (![self messageItem:item atRow:row containsTablePoint:tablePoint]) {
            return;
        }
        if ([self currentEventHitsActionableMessageContentForItem:item row:row tablePoint:tablePoint]) {
            return;
        }
    }
    NSArray *chosenReactionEmojis = [item chosenReactionEmojis];
    NSString *chosenReactionEmoji = nil;
    if ([chosenReactionEmojis count] > 0 && [[chosenReactionEmojis objectAtIndex:0] isKindOfClass:[NSString class]]) {
        chosenReactionEmoji = [chosenReactionEmojis objectAtIndex:0];
    }
    if ([chosenReactionEmoji length] > 0) {
        [self submitReactionEmoji:chosenReactionEmoji toMessageItem:item removing:YES];
    } else {
        [self submitReactionEmoji:@"👍" toMessageItem:item removing:NO];
    }
}
