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
    if (TGMessageItemHasCommentThread(item)) {
        NSRect bubbleRect = TGMessageBubbleRectForItem(item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:item]);
        NSRect commentRect = TGMessageCommentBarRectForItem(item, bubbleRect, [self.messageTableView isFlipped]);
        if (!NSIsEmptyRect(commentRect) && NSPointInRect(tablePoint, commentRect)) {
            return YES;
        }
    }
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
    if (TGMessageItemIsNonVisualDocument(item)) {
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

- (NSMenuItem *)pollOptionMenuItemWithTitle:(NSString *)title optionIndex:(NSUInteger)optionIndex messageItem:(TGMessageItem *)item chosen:(BOOL)chosen {
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:item forKey:@"message"];
    [payload setObject:[NSNumber numberWithUnsignedInteger:optionIndex] forKey:@"option_index"];

    NSString *displayTitle = chosen ? [NSString stringWithFormat:@"✓ %@", title] : title;
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:displayTitle
                                                       action:@selector(votePollOptionFromMenu:)
                                                keyEquivalent:@""] autorelease];
    [menuItem setRepresentedObject:payload];
    [menuItem setTarget:self];
    [menuItem setEnabled:(!chosen && ![item isPollClosed])];
    return menuItem;
}

- (NSMenu *)pollOptionsMenuForItem:(TGMessageItem *)item {
    NSMenu *pollMenu = [[[NSMenu alloc] initWithTitle:TGLoc(@"message.poll.vote")] autorelease];
    NSArray *options = [item pollOptions];
    NSUInteger index = 0;
    for (index = 0; index < [options count]; index++) {
        id candidate = [options objectAtIndex:index];
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *option = (NSDictionary *)candidate;
        NSString *optionText = [option objectForKey:TGMessagePollOptionTextKey];
        if (![optionText isKindOfClass:[NSString class]] || [optionText length] == 0) {
            optionText = [NSString stringWithFormat:TGLoc(@"message.poll.optionFallback"), (unsigned long)(index + 1)];
        }
        BOOL chosen = [[option objectForKey:TGMessagePollOptionChosenKey] boolValue];
        [pollMenu addItem:[self pollOptionMenuItemWithTitle:optionText optionIndex:index messageItem:item chosen:chosen]];
    }
    if ([[pollMenu itemArray] count] == 0) {
        NSMenuItem *emptyItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.poll.noOptions")
                                                            action:nil
                                                     keyEquivalent:@""] autorelease];
        [emptyItem setEnabled:NO];
        [pollMenu addItem:emptyItem];
    }
    return pollMenu;
}

- (NSMenuItem *)chatCurrentMuteStateMenuItemForChatItem:(TGChatItem *)item {
    NSString *title = TGLoc(@"chat.notifications.serverOn");
    NSNumber *chatID = [self notificationChatIDForChatItem:item];
    if ([self isChatIDLocallyMuted:chatID]) {
        title = TGLoc(@"chat.notifications.localFallback");
    } else if ([item serverNotificationsMuted]) {
        title = TGLoc(@"chat.notifications.serverMuted");
    }
    NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
    [menuItem setEnabled:NO];
    [menuItem setImage:TGTemplateIconAssetImage(([self isChatIDLocallyMuted:chatID] || [item serverNotificationsMuted]) ? @"sound-off" : @"bell",
                                                NSMakeSize(16.0, 16.0),
                                                [NSColor blackColor],
                                                0.72)];
    return menuItem;
}

static NSImage *TGMessageViewerMenuAvatarImage(NSDictionary *summary) {
    NSString *avatarPath = [summary objectForKey:@"avatar_local_path"];
    NSString *displayName = [summary objectForKey:@"display_name"];
    NSImage *image = [[[NSImage alloc] initWithSize:NSMakeSize(18.0, 18.0)] autorelease];
    [image lockFocus];
    NSRect rect = NSMakeRect(0.0, 0.0, 18.0, 18.0);
    [[NSColor clearColor] set];
    NSRectFill(rect);
    TGDrawAvatarInRect(avatarPath, displayName, rect, NO, NO);
    [image unlockFocus];
    return image;
}

static NSString *TGMessageViewerMenuTitle(NSDictionary *summary) {
    NSString *displayName = [summary objectForKey:@"display_name"];
    NSString *title = [displayName length] > 0 ? displayName : TGLoc(@"message.viewers.unknown");
    id viewDate = [summary objectForKey:@"view_date"];
    if ([viewDate respondsToSelector:@selector(integerValue)] && [viewDate integerValue] > 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[viewDate integerValue]];
        NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        NSString *time = [formatter stringFromDate:date];
        if ([time length] > 0) {
            title = [NSString stringWithFormat:@"%@ · %@", title, time];
        }
    }
    return title;
}

- (NSMenu *)messageViewersSubmenuForItem:(TGMessageItem *)item {
    NSMenu *submenu = [[[NSMenu alloc] initWithTitle:TGLoc(@"message.whoRead")] autorelease];
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        NSMenuItem *unavailable = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.viewers.signInUnavailable")
                                                              action:nil
                                                       keyEquivalent:@""] autorelease];
        [unavailable setEnabled:NO];
        [submenu addItem:unavailable];
        return submenu;
    }

    NSMenuItem *loading = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.viewers.loading")
                                                      action:nil
                                               keyEquivalent:@""] autorelease];
    [loading setEnabled:NO];
    [submenu addItem:loading];

    NSMenu *submenuRetained = [submenu retain];
    NSNumber *chatID = [item.chatID retain];
    NSNumber *messageID = [item.messageID retain];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *viewersError = nil;
        NSArray *viewers = [[client messageViewersForChatID:chatID
                                                  messageID:messageID
                                                      limit:20
                                                    timeout:5.0
                                                      error:&viewersError] retain];
        NSString *errorMessage = [[viewersError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [submenuRetained removeAllItems];
            if (!viewers) {
                NSString *message = [errorMessage length] > 0 ? errorMessage : TGLoc(@"message.viewers.unavailable");
                NSMenuItem *unavailable = [[[NSMenuItem alloc] initWithTitle:message
                                                                      action:nil
                                                               keyEquivalent:@""] autorelease];
                [unavailable setEnabled:NO];
                [submenuRetained addItem:unavailable];
            } else if ([viewers count] == 0) {
                NSMenuItem *empty = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.viewers.empty")
                                                                action:nil
                                                         keyEquivalent:@""] autorelease];
                [empty setEnabled:NO];
                [submenuRetained addItem:empty];
            } else {
                NSUInteger index = 0;
                for (index = 0; index < [viewers count]; index++) {
                    NSDictionary *summary = [viewers objectAtIndex:index];
                    NSMenuItem *viewerItem = [[[NSMenuItem alloc] initWithTitle:TGMessageViewerMenuTitle(summary)
                                                                         action:nil
                                                                  keyEquivalent:@""] autorelease];
                    [viewerItem setEnabled:NO];
                    [viewerItem setImage:TGMessageViewerMenuAvatarImage(summary)];
                    [submenuRetained addItem:viewerItem];
                }
            }
            [viewers release];
            [errorMessage release];
            [chatID release];
            [messageID release];
            [client release];
            [submenuRetained release];
        });
        [pool drain];
    });
    return submenu;
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
    NSString *localPath = nil;
    NSNumber *fileID = nil;
    NSString *fileName = [item downloadFileName];
    NSArray *mediaItems = [item visualMediaItems];
    if ([mediaItems count] > 0) {
        id media = [mediaItems objectAtIndex:0];
        if ([media isKindOfClass:[NSDictionary class]]) {
            fileID = TGMediaItemFullFileID(media);
            localPath = TGMediaItemFullLocalPath(media);
            if ([localPath length] == 0) {
                localPath = TGMediaItemLocalPath(media);
            }
            if ([fileName length] == 0) {
                id mediaFileName = [(NSDictionary *)media objectForKey:@"file_name"];
                if ([mediaFileName isKindOfClass:[NSString class]]) {
                    fileName = mediaFileName;
                }
            }
        }
    }
    if (!fileID) {
        fileID = [item mediaFileID];
    }
    if ([localPath length] == 0) {
        localPath = [item mediaLocalPath];
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

- (NSString *)localAttachmentPathForMessageItem:(TGMessageItem *)item {
    NSString *localPath = nil;
    [self downloadFileIDForMessageItem:item localPath:&localPath fileName:NULL];
    BOOL isDirectory = NO;
    if ([localPath length] > 0 &&
        [[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDirectory] &&
        !isDirectory) {
        return localPath;
    }
    return nil;
}

- (void)openDocumentAttachmentForMessageItem:(TGMessageItem *)item {
    NSString *localPath = [self localAttachmentPathForMessageItem:item];
    if ([localPath length] == 0) {
        [self downloadAttachmentForMessageItem:item];
        return;
    }
    if ([[NSWorkspace sharedWorkspace] openFile:localPath]) {
        [self.statusField setStringValue:TGLoc(@"media.center.open")];
        [self appendDetail:[NSString stringWithFormat:@"Opened document %@", [localPath lastPathComponent]]];
    } else {
        [self.statusField setStringValue:TGLoc(@"media.center.openFailed")];
    }
}

- (void)downloadAttachmentForMessageItem:(TGMessageItem *)item {
    NSString *localPath = nil;
    NSString *fileName = nil;
    NSNumber *fileID = [self downloadFileIDForMessageItem:item localPath:&localPath fileName:&fileName];
    [[TGDownloadManager sharedManager] setClient:self.client];
    NSString *identifier = [[TGDownloadManager sharedManager] enqueueFileID:fileID
                                                          suggestedFileName:fileName
                                                          fallbackLocalPath:localPath
                                                                 completion:^(NSString *savedPath, NSError *error, BOOL cancelled) {
        if (cancelled) {
            [self.statusField setStringValue:TGLoc(@"downloads.state.cancelled")];
        } else if ([savedPath length] > 0) {
            [self.statusField setStringValue:TGLoc(@"downloads.state.completed")];
            [self appendDetail:[NSString stringWithFormat:@"Downloaded to %@", savedPath]];
        } else {
            [self.statusField setStringValue:TGLoc(@"downloads.state.failed")];
            [self appendDetail:[error localizedDescription]];
        }
    }];
    if ([identifier length] > 0) {
        [self.statusField setStringValue:TGLoc(@"downloads.state.queued")];
    } else {
        [self appendDetail:TGLoc(@"downloads.unavailable")];
    }
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

    BOOL chatHasUnreadState = (([[item unreadCount] respondsToSelector:@selector(integerValue)] &&
                                [[item unreadCount] integerValue] > 0) ||
                               [item isMarkedAsUnread]);
    NSMenuItem *markReadItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(chatHasUnreadState ? @"chat.markRead" : @"chat.markUnread")
                                                           action:@selector(toggleChatReadStateFromMenu:)
                                                    keyEquivalent:@""] autorelease];
    [markReadItem setRepresentedObject:item];
    [markReadItem setTarget:self];
    [markReadItem setEnabled:(![item isForumTopic] && [self.currentAuthState isEqualToString:@"ready"])];
    [markReadItem setImage:TGTemplateIconAssetImage(@"bell", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    [menu addItem:markReadItem];

    NSMenuItem *jumpToDateItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.jumpToDate")
                                                              action:@selector(jumpToChatDateFromMenu:)
                                                       keyEquivalent:@""] autorelease];
    [jumpToDateItem setRepresentedObject:item];
    [jumpToDateItem setTarget:self];
    [jumpToDateItem setEnabled:(![item isForumTopic] && [self.currentAuthState isEqualToString:@"ready"])];
    [menu addItem:jumpToDateItem];

    NSMenuItem *pinItem = [[[NSMenuItem alloc] initWithTitle:([item isPinned] ? TGLoc(@"chat.unpin") : TGLoc(@"chat.pin"))
                                                      action:@selector(toggleChatPinnedFromMenu:)
                                               keyEquivalent:@""] autorelease];
    [pinItem setRepresentedObject:item];
    [pinItem setTarget:self];
    [pinItem setEnabled:(![item isForumTopic])];
    [menu addItem:pinItem];

    NSMenuItem *archiveItem = [[[NSMenuItem alloc] initWithTitle:(self.showingArchivedChats ? TGLoc(@"chat.unarchive") : TGLoc(@"chat.archive"))
                                                          action:@selector(toggleChatArchivedFromMenu:)
                                                   keyEquivalent:@""] autorelease];
    [archiveItem setRepresentedObject:item];
    [archiveItem setTarget:self];
    [archiveItem setEnabled:(![item isForumTopic])];
    [archiveItem setImage:TGTemplateIconAssetImage(@"archive", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    [menu addItem:archiveItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:[self chatCurrentMuteStateMenuItemForChatItem:item]];

    if ([self isChatItemEffectivelyMuted:item]) {
        NSMenuItem *unmuteItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.notifications.enable")
                                                             action:@selector(unmuteChatFromMenu:)
                                                      keyEquivalent:@""] autorelease];
        [unmuteItem setRepresentedObject:item];
        [unmuteItem setTarget:self];
        [unmuteItem setImage:TGTemplateIconAssetImage(@"bell", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
        [menu addItem:unmuteItem];
    }

    NSMenu *muteMenu = [[[NSMenu alloc] initWithTitle:TGLoc(@"chat.notifications.mute")] autorelease];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:TGLoc(@"chat.notifications.hour") duration:(60.0 * 60.0) chatItem:item]];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:TGLoc(@"chat.notifications.day") duration:(24.0 * 60.0 * 60.0) chatItem:item]];
    [muteMenu addItem:[NSMenuItem separatorItem]];
    [muteMenu addItem:[self chatMuteMenuItemWithTitle:TGLoc(@"chat.notifications.forever") duration:-1.0 chatItem:item]];
    NSMenuItem *muteRoot = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.notifications.mute")
                                                       action:nil
                                                keyEquivalent:@""] autorelease];
    [muteRoot setImage:TGTemplateIconAssetImage(@"sound-off", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
    [muteRoot setSubmenu:muteMenu];
    [menu addItem:muteRoot];

    BOOL destructiveSeparatorAdded = NO;
    if (![item isForumTopic] && [self.currentAuthState isEqualToString:@"ready"]) {
        [menu addItem:[NSMenuItem separatorItem]];
        destructiveSeparatorAdded = YES;
        NSMenuItem *clearHistoryItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.clearHistory")
                                                                    action:@selector(clearChatHistoryFromMenu:)
                                                             keyEquivalent:@""] autorelease];
        [clearHistoryItem setRepresentedObject:item];
        [clearHistoryItem setTarget:self];
        [clearHistoryItem setImage:TGTemplateIconAssetImage(@"trash",
                                                            NSMakeSize(16.0, 16.0),
                                                            [NSColor redColor],
                                                            0.90)];
        [menu addItem:clearHistoryItem];

        NSString *typeSummary = [item typeSummary];
        if ([typeSummary isEqualToString:@"Private"]) {
            NSMenuItem *deleteChatItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.delete")
                                                                     action:@selector(deletePrivateChatFromMenu:)
                                                              keyEquivalent:@""] autorelease];
            [deleteChatItem setRepresentedObject:item];
            [deleteChatItem setTarget:self];
            [deleteChatItem setImage:TGTemplateIconAssetImage(@"trash",
                                                              NSMakeSize(16.0, 16.0),
                                                              [NSColor redColor],
                                                              0.95)];
            [menu addItem:deleteChatItem];
        }
    }

    NSString *typeSummary = [item typeSummary];
    BOOL canLeave = (![item isForumTopic] &&
                     ([typeSummary isEqualToString:@"Group"] ||
                      [typeSummary isEqualToString:@"Supergroup"] ||
                      [typeSummary isEqualToString:@"Channel"]));
    if (canLeave) {
        if (!destructiveSeparatorAdded) {
            [menu addItem:[NSMenuItem separatorItem]];
        }
        NSMenuItem *leaveItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.leave")
                                                            action:@selector(leaveChatFromMenu:)
                                                     keyEquivalent:@""] autorelease];
        [leaveItem setRepresentedObject:item];
        [leaveItem setTarget:self];
        [menu addItem:leaveItem];
    }
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
    if ([item failedToSend]) {
        NSMenuItem *retryItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.retrySend")
                                                            action:@selector(retryFailedTextMessageFromMenu:)
                                                     keyEquivalent:@""] autorelease];
        [retryItem setRepresentedObject:item];
        [retryItem setTarget:self];
        [retryItem setImage:TGTemplateIconAssetImage(@"reload", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
        [menu addItem:retryItem];

        NSMenuItem *copyUnsentItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.copyUnsentText")
                                                                  action:@selector(copyMessageTextFromMenu:)
                                                           keyEquivalent:@""] autorelease];
        [copyUnsentItem setRepresentedObject:item];
        [copyUnsentItem setTarget:self];
        [copyUnsentItem setImage:TGTemplateIconAssetImage(@"document", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.78)];
        [menu addItem:copyUnsentItem];
        if ([[item sendFailureSummary] length] > 0) {
            NSMenuItem *errorItem = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@: %@", TGLoc(@"message.sendFailed"), [item sendFailureSummary]]
                                                                action:nil
                                                         keyEquivalent:@""] autorelease];
            [errorItem setEnabled:NO];
            [menu addItem:errorItem];
        }
        return;
    }
    if (TGMessageItemHasDownloadableAttachment(item)) {
        NSString *localAttachmentPath = [self localAttachmentPathForMessageItem:item];
        if (TGMessageItemIsNonVisualDocument(item) && [localAttachmentPath length] > 0) {
            NSMenuItem *openDocumentItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.open")
                                                                        action:@selector(openMessageDocumentFromMenu:)
                                                                 keyEquivalent:@""] autorelease];
            [openDocumentItem setRepresentedObject:item];
            [openDocumentItem setTarget:self];
            [menu addItem:openDocumentItem];

            NSMenuItem *saveDocumentItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.saveAs")
                                                                        action:@selector(saveMessageDocumentAsFromMenu:)
                                                                 keyEquivalent:@""] autorelease];
            [saveDocumentItem setRepresentedObject:item];
            [saveDocumentItem setTarget:self];
            [menu addItem:saveDocumentItem];

            NSMenuItem *revealDocumentItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.reveal")
                                                                          action:@selector(revealMessageDocumentFromMenu:)
                                                                   keyEquivalent:@""] autorelease];
            [revealDocumentItem setRepresentedObject:item];
            [revealDocumentItem setTarget:self];
            [menu addItem:revealDocumentItem];
        }
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
    NSString *copyableText = ([[item editableText] length] > 0) ? [item editableText] : TGDisplayTextForMessageItem(item);
    if ([copyableText length] > 0) {
        NSMenuItem *copyTextItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.copyText")
                                                               action:@selector(copyMessageTextFromMenu:)
                                                        keyEquivalent:@""] autorelease];
        [copyTextItem setRepresentedObject:item];
        [copyTextItem setTarget:self];
        [copyTextItem setImage:TGTemplateIconAssetImage(@"document", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.78)];
        [menu addItem:copyTextItem];
        addedMessageAction = YES;
    }

    NSString *messageLinkChatType = [self.selectedChatTypeSummary isKindOfClass:[NSString class]]
        ? self.selectedChatTypeSummary
        : @"";
    BOOL supportsMessageLinks = ([messageLinkChatType isEqualToString:@"Group"] ||
                                 [messageLinkChatType isEqualToString:@"Supergroup"] ||
                                 [messageLinkChatType isEqualToString:@"Channel"]);
    if (supportsMessageLinks) {
        NSMenuItem *copyLinkItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.copyLink")
                                                               action:@selector(copyMessageLinkFromMenu:)
                                                        keyEquivalent:@""] autorelease];
        [copyLinkItem setRepresentedObject:item];
        [copyLinkItem setTarget:self];
        [copyLinkItem setEnabled:[self.currentAuthState isEqualToString:@"ready"]];
        [menu addItem:copyLinkItem];
        addedMessageAction = YES;
    }

    if ([item isPollMessage]) {
        NSMenuItem *pollItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.poll.vote")
                                                           action:nil
                                                    keyEquivalent:@""] autorelease];
        [pollItem setImage:TGTemplateIconAssetImage(@"poll", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.80)];
        [pollItem setSubmenu:[self pollOptionsMenuForItem:item]];
        [pollItem setEnabled:(![item isPollClosed] && [[item pollOptions] count] > 0)];
        [menu addItem:pollItem];
        addedMessageAction = YES;
    }

    if ([[item replyMarkup] isKindOfClass:[NSDictionary class]]) {
        NSMenuItem *botButtonsItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"bot.keyboard.open")
                                                                 action:@selector(openBotKeyboardFromMenu:)
                                                          keyEquivalent:@""] autorelease];
        [botButtonsItem setRepresentedObject:item];
        [botButtonsItem setTarget:self];
        [menu addItem:botButtonsItem];
        addedMessageAction = YES;
    }

    BOOL canReply = (![item capabilitiesKnown] || [item canBeReplied]);
    if (canReply) {
        NSMenuItem *replyItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.reply")
                                                            action:@selector(replyToMessageFromMenu:)
                                                     keyEquivalent:@""] autorelease];
        [replyItem setRepresentedObject:item];
        [replyItem setTarget:self];
        [menu addItem:replyItem];
        addedMessageAction = YES;
    }

    if (TGMessageItemHasCommentThread(item)) {
        NSMenuItem *commentsItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.comments.open")
                                                               action:@selector(openMessageCommentsFromMenu:)
                                                        keyEquivalent:@""] autorelease];
        [commentsItem setRepresentedObject:item];
        [commentsItem setTarget:self];
        [commentsItem setImage:TGTemplateIconAssetImage(@"chats", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.82)];
        [menu addItem:commentsItem];
        addedMessageAction = YES;
    }

    NSMenuItem *forwardItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.forward")
                                                          action:@selector(forwardMessageFromMenu:)
                                                   keyEquivalent:@""] autorelease];
    [forwardItem setRepresentedObject:item];
    [forwardItem setTarget:self];
    [menu addItem:forwardItem];
    if ([self.profileUserID respondsToSelector:@selector(longLongValue)]) {
        NSMenuItem *savedForwardItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.forward.saved")
                                                                   action:@selector(forwardMessageToSavedMessagesFromMenu:)
                                                            keyEquivalent:@""] autorelease];
        [savedForwardItem setRepresentedObject:item];
        [savedForwardItem setTarget:self];
        [menu addItem:savedForwardItem];
    }
    if ([item.messageID respondsToSelector:@selector(longLongValue)] && [item.chatID respondsToSelector:@selector(longLongValue)]) {
        NSMenuItem *pinMessageItem = [[[NSMenuItem alloc] initWithTitle:([item isPinned] ? TGLoc(@"message.unpin") : TGLoc(@"message.pin"))
                                                                 action:@selector(toggleMessagePinnedFromMenu:)
                                                          keyEquivalent:@""] autorelease];
        [pinMessageItem setRepresentedObject:item];
        [pinMessageItem setTarget:self];
        [pinMessageItem setImage:TGTemplateIconAssetImage(@"flag-triangle", NSMakeSize(16.0, 16.0), [NSColor blackColor], 0.78)];
        [menu addItem:pinMessageItem];
        addedMessageAction = YES;
    }
    NSString *messageViewersChatType = [self.selectedChatTypeSummary isKindOfClass:[NSString class]]
        ? self.selectedChatTypeSummary : @"";
    BOOL supportsMessageViewers = ([messageViewersChatType isEqualToString:@"Group"] ||
                                   [messageViewersChatType isEqualToString:@"Supergroup"]);
    if ([item outgoing] && supportsMessageViewers) {
        NSMenuItem *readByItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.whoRead")
                                                             action:nil
                                                      keyEquivalent:@""] autorelease];
        [readByItem setRepresentedObject:item];
        [readByItem setTarget:self];
        [readByItem setSubmenu:[self messageViewersSubmenuForItem:item]];
        [menu addItem:readByItem];
    }
    BOOL canEdit = (([item capabilitiesKnown] && [item canBeEdited]) ||
                    (![item capabilitiesKnown] && [item outgoing]));
    if (canEdit && [[item editableText] length] > 0 && [[item contentType] isEqualToString:@"messageText"]) {
        NSMenuItem *editItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.edit")
                                                           action:@selector(editMessageFromMenu:)
                                                    keyEquivalent:@""] autorelease];
        [editItem setRepresentedObject:item];
        [editItem setTarget:self];
        [menu addItem:editItem];
        addedMessageAction = YES;
    }
    BOOL canDelete = (![item capabilitiesKnown] || [item canBeDeletedOnlyForSelf] || [item canBeDeletedForAllUsers]);
    if (canDelete && [item.messageID respondsToSelector:@selector(longLongValue)] && [item.chatID respondsToSelector:@selector(longLongValue)]) {
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
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *reactionTitleItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"message.reactions.more")
                                                                action:nil
                                                         keyEquivalent:@""] autorelease];
    [reactionTitleItem setEnabled:NO];
    [menu addItem:reactionTitleItem];
    NSArray *emojis = [NSArray arrayWithObjects:
                       @"👍", @"👎", @"❤", @"🔥", @"🥰", @"👏", @"😁", @"🤔",
                       @"🤯", @"😱", @"😢", @"🎉", @"🤩", @"🤮", @"💩", @"🙏",
                       @"👌", @"🕊", @"🤡", @"🥱", @"🥴", @"😍", @"🐳", @"💯",
                       @"🤣", @"⚡", @"🍌", @"🏆", @"💔", @"🤨", @"😐", @"👀",
                       nil];
    NSUInteger reactionIndex = 0;
    while (reactionIndex < [emojis count]) {
        NSUInteger remaining = [emojis count] - reactionIndex;
        NSUInteger rowCount = MIN((NSUInteger)8, remaining);
        NSArray *rowEmojis = [emojis subarrayWithRange:NSMakeRange(reactionIndex, rowCount)];
        TGReactionMenuRowView *rowView = [[[TGReactionMenuRowView alloc]
            initWithEmojis:rowEmojis
                   message:item
            chosenReactions:[item chosenReactionEmojis]
                    target:self
                    action:@selector(reactToMessageFromMenu:)] autorelease];
        NSMenuItem *rowItem = [[[NSMenuItem alloc] initWithTitle:@""
                                                          action:nil
                                                   keyEquivalent:@""] autorelease];
        [rowItem setView:rowView];
        [menu addItem:rowItem];
        reactionIndex += rowCount;
    }
}

- (void)openBotKeyboardFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![[item replyMarkup] isKindOfClass:[NSDictionary class]]) {
        return;
    }
    [[self.botKeyboardWindowController window] close];
    self.botKeyboardWindowController = [[[TGBotKeyboardWindowController alloc] initWithClient:self.client
                                                                                        chatID:[item chatID]
                                                                                     messageID:[item messageID]
                                                                                   replyMarkup:[item replyMarkup]] autorelease];
    [self.botKeyboardWindowController showWindow:self];
    [[self.botKeyboardWindowController window] center];
    [[self.botKeyboardWindowController window] makeKeyAndOrderFront:self];
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

- (void)copyMessageTextFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSString *text = ([[item editableText] length] > 0) ? [item editableText] : TGDisplayTextForMessageItem(item);
    if ([text length] == 0 && [[item retryText] length] > 0) {
        text = [item retryText];
    }
    if ([text length] == 0) {
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSStringPboardType];
    [self appendDetail:@"Message text copied to clipboard."];
}

- (void)copyMessageLinkFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    NSNumber *chatID = [[NSNumber numberWithLongLong:[[item chatID] longLongValue]] retain];
    NSNumber *messageID = [[NSNumber numberWithLongLong:[[item messageID] longLongValue]] retain];
    BOOL inMessageThread = ([self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)] &&
                            [self.selectedMessageThreadID longLongValue] > 0LL);
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:TGLoc(@"message.linkCopying")];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *linkError = nil;
        NSString *messageLink = [[client messageLinkForChatID:chatID
                                                   messageID:messageID
                                             inMessageThread:inMessageThread
                                                     timeout:6.0
                                                       error:&linkError] copy];
        NSString *errorMessage = [[linkError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([messageLink length] > 0) {
                NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                [pasteboard clearContents];
                [pasteboard setString:messageLink forType:NSStringPboardType];
                [self.statusField setStringValue:TGLoc(@"message.linkCopied")];
                [self appendDetail:@"Message link copied to clipboard."];
            } else {
                [self.statusField setStringValue:TGLoc(@"message.linkUnavailable")];
                [self appendDetail:[NSString stringWithFormat:@"TDLib message link: %@",
                                    [errorMessage length] > 0 ? errorMessage : @"link unavailable"]];
                NSBeep();
            }
            [messageLink release];
            [errorMessage release];
            [chatID release];
            [messageID release];
            [client release];
        });
        [pool drain];
    });
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

- (void)showMessageViewersFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Message viewers are available only after sign-in is ready."];
        return;
    }

    self.messageViewersWindowController = [[[TGMessageViewersWindowController alloc] initWithMessagePreview:[item preview]] autorelease];
    [self.messageViewersWindowController showWindow:self];
    [[self.messageViewersWindowController window] makeKeyAndOrderFront:self];
    [self.messageViewersWindowController showLoading];

    NSNumber *chatID = [[item chatID] retain];
    NSNumber *messageID = [[item messageID] retain];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *viewersError = nil;
        NSArray *viewers = [[client messageViewersForChatID:chatID
                                                  messageID:messageID
                                                      limit:80
                                                    timeout:8.0
                                                      error:&viewersError] retain];
        NSString *errorMessage = [[viewersError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (viewers) {
                [self.messageViewersWindowController showViewerSummaries:viewers];
            } else {
                [self.messageViewersWindowController showErrorMessage:([errorMessage length] > 0 ? errorMessage : @"Readers are unavailable for this message.")];
            }
            [viewers release];
            [errorMessage release];
            [chatID release];
            [messageID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)toggleMessagePinnedFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Pinning messages is available only after sign-in is ready."];
        return;
    }

    BOOL targetPinned = ![item isPinned];
    TGMessageItem *itemCopy = [item retain];
    NSNumber *chatID = [[NSNumber numberWithLongLong:[[item chatID] longLongValue]] retain];
    NSNumber *messageID = [[NSNumber numberWithLongLong:[[item messageID] longLongValue]] retain];
    TGTDLibClient *client = [self.client retain];

    [item setPinned:targetPinned];
    [self.messageTableView reloadData];
    [self.statusField setStringValue:(targetPinned ? TGLoc(@"message.pin") : TGLoc(@"message.unpin"))];
    [self appendDetail:[NSString stringWithFormat:@"%@ message...", targetPinned ? @"Pinning" : @"Unpinning"]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *pinError = nil;
        BOOL succeeded = [client setMessagePinnedForChatID:chatID messageID:messageID pinned:targetPinned timeout:8.0 error:&pinError];
        NSString *errorMessage = [[pinError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self.statusField setStringValue:(targetPinned ? TGLoc(@"message.pin") : TGLoc(@"message.unpin"))];
                [self appendDetail:[NSString stringWithFormat:@"%@ message accepted by TDLib.", targetPinned ? @"Pin" : @"Unpin"]];
                [self loadPinnedMessageForSelectedChat];
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            } else {
                [itemCopy setPinned:!targetPinned];
                [self.messageTableView reloadData];
                [self.statusField setStringValue:@"Pin unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib pin message: %@", [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [itemCopy release];
            [chatID release];
            [messageID release];
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
    BOOL canDeleteOnlyForSelf = (hasKnownDeleteOptions ? [item canBeDeletedOnlyForSelf] : YES);
    BOOL canDeleteForAllUsers = (hasKnownDeleteOptions ? [item canBeDeletedForAllUsers] : YES);
    BOOL savedMessagesChat = NO;
    if ([self.profileUserID respondsToSelector:@selector(longLongValue)] &&
        [[item chatID] respondsToSelector:@selector(longLongValue)] &&
        [self.profileUserID longLongValue] != 0LL &&
        [[item chatID] longLongValue] == [self.profileUserID longLongValue]) {
        savedMessagesChat = YES;
    }
    NSString *typeSummary = ([self.selectedChatTypeSummary isKindOfClass:[NSString class]] ? [self.selectedChatTypeSummary lowercaseString] : @"");
    BOOL selectedGroupLikeChat = ([typeSummary rangeOfString:@"group"].location != NSNotFound);
    BOOL outgoingGroupMessage = (selectedGroupLikeChat && [item outgoing] && canDeleteForAllUsers);

    TGMessageDeleteChoice choice = TGMessageDeleteChoiceCancel;
    BOOL singleDeleteMode = (savedMessagesChat ||
                             outgoingGroupMessage ||
                             (hasKnownDeleteOptions && (canDeleteOnlyForSelf != canDeleteForAllUsers)));
    if (singleDeleteMode) {
        if (![TGMessageActionDialogs confirmPlainDeleteMessage]) {
            return;
        }
        choice = (canDeleteForAllUsers ? TGMessageDeleteChoiceForEveryone : TGMessageDeleteChoiceOnlyForSelf);
    } else {
        choice = [TGMessageActionDialogs deleteChoiceWithCanDeleteOnlyForSelf:canDeleteOnlyForSelf
                                                         canDeleteForAllUsers:canDeleteForAllUsers];
        if (choice == TGMessageDeleteChoiceCancel) {
            return;
        }
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

- (void)openMessageDocumentFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if ([item isKindOfClass:[TGMessageItem class]]) {
        [self openDocumentAttachmentForMessageItem:item];
    }
}

- (void)saveMessageDocumentAsFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSString *localPath = [self localAttachmentPathForMessageItem:item];
    NSError *error = nil;
    NSString *savedPath = [TGMediaFileActions saveCopyOfFileAtPath:localPath
                                                 suggestedFileName:[item downloadFileName]
                                                             error:&error];
    if ([savedPath length] > 0) {
        [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.savedAs"),
                                         [savedPath lastPathComponent]]];
    } else if (error) {
        [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.saveAsFailed"),
                                         [error localizedDescription]]];
    }
}

- (void)revealMessageDocumentFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    NSString *localPath = [self localAttachmentPathForMessageItem:item];
    if (![TGMediaFileActions revealFileAtPath:localPath]) {
        [self.statusField setStringValue:TGLoc(@"media.center.revealFailed")];
    }
}

- (void)votePollOptionFromMenu:(id)sender {
    NSDictionary *payload = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return;
    }
    TGMessageItem *item = [payload objectForKey:@"message"];
    NSNumber *optionIndex = [payload objectForKey:@"option_index"];
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![[item messageID] respondsToSelector:@selector(longLongValue)] ||
        ![optionIndex respondsToSelector:@selector(unsignedIntegerValue)]) {
        return;
    }
    NSNumber *selectedOption = [NSNumber numberWithInteger:[optionIndex integerValue]];
    if ([item isPollMultipleChoice]) {
        [self togglePollOptionForMessageItem:item optionIndex:[selectedOption unsignedIntegerValue]];
    } else {
        [self submitPollAnswerForMessageItem:item optionIndexes:[NSArray arrayWithObject:selectedOption]];
    }
}

- (void)submitPollAnswerForMessageItem:(TGMessageItem *)item optionIndexes:(NSArray *)optionIndexes {
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![[item messageID] respondsToSelector:@selector(longLongValue)] ||
        ![optionIndexes isKindOfClass:[NSArray class]] ||
        [optionIndexes count] == 0 ||
        [item isPollClosed] ||
        [[item pollVoteState] isEqualToString:@"sending"]) {
        return;
    }

    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [[item chatID] retain];
    NSNumber *messageID = [[item messageID] retain];
    NSArray *selectedOptions = [optionIndexes copy];
    [item setPollVoteState:@"sending"];
    [item setPollVoteMessage:TGLoc(@"message.poll.sending")];
    [self.statusField setStringValue:TGLoc(@"message.poll.sending")];
    [self.messageTableView reloadData];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *voteError = nil;
        BOOL ok = [client setPollAnswerForChatID:chatID
                                       messageID:messageID
                                   optionIndexes:selectedOptions
                                         timeout:8.0
                                           error:&voteError];
        NSString *errorMessage = [[voteError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [item setPollVoteState:(ok ? @"sent" : @"failed")];
            [item setPollVoteMessage:(ok ? TGLoc(@"message.poll.sent") : ([errorMessage length] > 0 ? errorMessage : TGLoc(@"message.poll.failed")))];
            if (ok) {
                [item setPendingPollOptionIndexes:nil];
                [self.statusField setStringValue:TGLoc(@"message.poll.sent")];
                [self appendDetail:@"Poll vote accepted by TDLib."];
                [self refreshSelectedMessagesAfterMediaSend];
            } else {
                [self.statusField setStringValue:TGLoc(@"message.poll.failed")];
                [self appendDetail:[NSString stringWithFormat:@"Poll vote failed: %@", [errorMessage length] > 0 ? errorMessage : @"TDLib rejected the vote"]];
            }
            [errorMessage release];
            [selectedOptions release];
            [messageID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)togglePollOptionForMessageItem:(TGMessageItem *)item optionIndex:(NSUInteger)optionIndex {
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item isPollMultipleChoice] ||
        [item isPollClosed] ||
        [[item pollVoteState] isEqualToString:@"sending"]) {
        return;
    }
    NSMutableArray *selected = [NSMutableArray array];
    NSArray *existing = [item pendingPollOptionIndexes];
    NSUInteger index = 0;
    BOOL removed = NO;
    for (index = 0; index < [existing count]; index++) {
        id object = [existing objectAtIndex:index];
        if (![object respondsToSelector:@selector(unsignedIntegerValue)]) {
            continue;
        }
        if ([object unsignedIntegerValue] == optionIndex) {
            removed = YES;
            continue;
        }
        [selected addObject:[NSNumber numberWithUnsignedInteger:[object unsignedIntegerValue]]];
    }
    if (!removed) {
        [selected addObject:[NSNumber numberWithUnsignedInteger:optionIndex]];
    }
    [selected sortUsingSelector:@selector(compare:)];
    [item setPollVoteState:nil];
    [item setPollVoteMessage:nil];
    [item setPendingPollOptionIndexes:([selected count] > 0 ? selected : nil)];
    [self.messageTableView reloadData];
}

- (void)openMessageCommentsFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    [self openMessageCommentsForItem:item];
}

- (void)markChatReadFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]]) {
        return;
    }
    [self markChatItemRead:item];
}

- (void)toggleChatReadStateFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] || [item isForumTopic]) {
        return;
    }
    BOOL hasUnreadState = (([[item unreadCount] respondsToSelector:@selector(integerValue)] &&
                            [[item unreadCount] integerValue] > 0) ||
                           [item isMarkedAsUnread]);
    if (hasUnreadState) {
        [self markChatItemRead:item];
    } else {
        [self markChatItemUnread:item];
    }
}

- (void)markChatItemUnread:(TGChatItem *)item {
    if (![item isKindOfClass:[TGChatItem class]] ||
        [item isForumTopic] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    TGChatItem *retainedItem = [item retain];
    NSNumber *chatID = [[item chatID] retain];
    TGTDLibClient *client = [self.client retain];
    [retainedItem setMarkedAsUnread:YES];
    [self.chatTableView reloadData];
    [self updateApplicationBadge];
    [self.statusField setStringValue:TGLoc(@"chat.markingUnread")];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *stateError = nil;
        BOOL success = [client setChatWithID:chatID markedAsUnread:YES timeout:5.0 error:&stateError];
        NSString *errorMessage = [[stateError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.statusField setStringValue:TGLoc(@"chat.markedUnread")];
            } else {
                [retainedItem setMarkedAsUnread:NO];
                [self.chatTableView reloadData];
                [self updateApplicationBadge];
                [self.statusField setStringValue:TGLoc(@"chat.markUnreadFailed")];
                if ([errorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib mark unread: %@", errorMessage]];
                }
            }
            [errorMessage release];
            [retainedItem release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)markChatItemRead:(TGChatItem *)item {
    NSNumber *sourceChatID = [item isForumTopic] ? [item parentChatID] : [item chatID];
    NSNumber *sourceThreadID = [item isForumTopic] ? [item messageThreadID] : nil;
    NSString *sourceTopicKind = [item isForumTopic] ? [item messageTopicKind] : nil;
    NSNumber *chatID = [sourceChatID retain];
    NSNumber *threadID = [sourceThreadID retain];
    NSString *topicKind = [sourceTopicKind copy];
    TGChatItem *retainedItem = [item retain];
    BOOL wasMarkedAsUnread = [item isMarkedAsUnread];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        [chatID release];
        [threadID release];
        [topicKind release];
        [retainedItem release];
        return;
    }

    TGTDLibClient *client = [self.client retain];
    [retainedItem setMarkedAsUnread:NO];
    [self clearUnreadCountForChatID:chatID messageThreadID:threadID];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *stateError = nil;
        BOOL unreadStateCleared = ([retainedItem isForumTopic] ||
                                   [client setChatWithID:chatID markedAsUnread:NO timeout:5.0 error:&stateError]);
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatID
                                                    messageThreadID:threadID
                                                   messageTopicKind:topicKind
                                                              limit:50
                                                            timeout:6.0
                                                              error:&messageError];
        NSArray *itemsCopy = [items copy];
        NSString *errorMessage = [[messageError localizedDescription] copy];
        NSString *stateErrorMessage = [[stateError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!unreadStateCleared && wasMarkedAsUnread) {
                [retainedItem setMarkedAsUnread:YES];
                [self.chatTableView reloadData];
                [self updateApplicationBadge];
                if ([stateErrorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib clear marked unread: %@", stateErrorMessage]];
                }
            }
            if ([itemsCopy count] > 0) {
                [self markMessageItemsReadForChatID:chatID messageThreadID:threadID messageTopicKind:topicKind items:itemsCopy];
            } else if ([errorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib mark read: %@", errorMessage]];
            }
            [itemsCopy release];
            [errorMessage release];
            [stateErrorMessage release];
            [retainedItem release];
            [chatID release];
            [threadID release];
            [topicKind release];
            [client release];
        });
        [pool drain];
    });
}

- (void)jumpToChatDateFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGChatItem class]] ||
        [item isForumTopic] ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    NSDate *date = [TGDatePickerDialog dateWithTitle:TGLoc(@"chat.jumpToDate.title")
                                                help:TGLoc(@"chat.jumpToDate.help")
                                         actionTitle:TGLoc(@"chat.jumpToDate.action")
                                         initialDate:[NSDate date]
                                             minDate:nil];
    if (!date) {
        return;
    }

    NSNumber *chatID = [[item chatID] retain];
    NSString *chatTitle = [[item title] copy];
    NSInteger unixDate = (NSInteger)[date timeIntervalSince1970];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:TGLoc(@"chat.jumpToDate.loading")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *lookupError = nil;
        TGMessageItem *messageItem = [[client messagePreviewItemForChatID:chatID
                                                                 unixDate:unixDate
                                                                  timeout:8.0
                                                                    error:&lookupError] retain];
        NSString *errorMessage = [[lookupError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (messageItem && [[messageItem messageID] respondsToSelector:@selector(longLongValue)]) {
                TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
                [result setChatID:chatID];
                [result setMessageID:[messageItem messageID]];
                [result setChatTitle:chatTitle];
                [result setMessageItem:messageItem];
                [self jumpToSearchResult:result];
            } else {
                [self.statusField setStringValue:TGLoc(@"chat.jumpToDate.notFound")];
                if ([errorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib jump to date: %@", errorMessage]];
                }
            }
            [messageItem release];
            [errorMessage release];
            [chatID release];
            [chatTitle release];
            [client release];
        });
        [pool drain];
    });
}

- (void)markAllChatsReadFromMenu:(id)sender {
    (void)sender;
    [self setMarkAllChatsReadBusy:YES];
    NSMutableArray *seedItems = [NSMutableArray array];
    NSMutableSet *seenKeys = [NSMutableSet set];
    NSUInteger index = 0;
    NSArray *collections[2] = { self.chatItems, self.chatItemsBeforeTopicList };
    NSUInteger collectionIndex = 0;
    for (collectionIndex = 0; collectionIndex < 2; collectionIndex++) {
        NSArray *sourceItems = collections[collectionIndex];
        for (index = 0; index < [sourceItems count]; index++) {
            id candidate = [sourceItems objectAtIndex:index];
            TGChatItem *candidateItem = [candidate isKindOfClass:[TGChatItem class]] ? (TGChatItem *)candidate : nil;
            BOOL hasUnreadCount = ([[candidateItem unreadCount] respondsToSelector:@selector(integerValue)] &&
                                   [[candidateItem unreadCount] integerValue] > 0);
            if (!candidateItem || (!hasUnreadCount && ![candidateItem isMarkedAsUnread])) {
                continue;
            }
            TGChatItem *chatItem = candidateItem;
            NSNumber *sourceChatID = [chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID];
            NSNumber *sourceThreadID = [chatItem isForumTopic] ? [chatItem messageThreadID] : nil;
            if (![sourceChatID respondsToSelector:@selector(longLongValue)]) {
                continue;
            }
            NSString *key = [NSString stringWithFormat:@"%lld:%lld",
                             [sourceChatID longLongValue],
                             [sourceThreadID respondsToSelector:@selector(longLongValue)] ? [sourceThreadID longLongValue] : 0LL];
            if ([seenKeys containsObject:key]) {
                continue;
            }
            [seenKeys addObject:key];
            [seedItems addObject:chatItem];
        }
    }
    [self appendDetail:@"Read all: loading a wider unread chat set from TDLib..."];

    NSArray *seedCopy = [[NSArray alloc] initWithArray:seedItems];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *loadError = nil;
        NSArray *serverItems = [[client mainChatPreviewItemsWithLimit:500 timeout:8.0 error:&loadError] retain];
        NSString *errorMessage = [[loadError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *itemsToRead = [NSMutableArray array];
            NSMutableSet *finalSeenKeys = [NSMutableSet set];
            NSArray *sources[2] = { seedCopy, serverItems };
            NSUInteger sourceIndex = 0;
            for (sourceIndex = 0; sourceIndex < 2; sourceIndex++) {
                NSArray *source = sources[sourceIndex];
                NSUInteger itemIndex = 0;
                for (itemIndex = 0; itemIndex < [source count]; itemIndex++) {
                    id candidate = [source objectAtIndex:itemIndex];
                    TGChatItem *candidateItem = [candidate isKindOfClass:[TGChatItem class]] ? (TGChatItem *)candidate : nil;
                    BOOL hasUnreadCount = ([[candidateItem unreadCount] respondsToSelector:@selector(integerValue)] &&
                                           [[candidateItem unreadCount] integerValue] > 0);
                    if (!candidateItem || (!hasUnreadCount && ![candidateItem isMarkedAsUnread])) {
                        continue;
                    }
                    TGChatItem *chatItem = candidateItem;
                    NSNumber *sourceChatID = [chatItem isForumTopic] ? [chatItem parentChatID] : [chatItem chatID];
                    NSNumber *sourceThreadID = [chatItem isForumTopic] ? [chatItem messageThreadID] : nil;
                    if (![sourceChatID respondsToSelector:@selector(longLongValue)]) {
                        continue;
                    }
                    NSString *key = [NSString stringWithFormat:@"%lld:%lld",
                                     [sourceChatID longLongValue],
                                     [sourceThreadID respondsToSelector:@selector(longLongValue)] ? [sourceThreadID longLongValue] : 0LL];
                    if ([finalSeenKeys containsObject:key]) {
                        continue;
                    }
                    [finalSeenKeys addObject:key];
                    [itemsToRead addObject:chatItem];
                }
            }
            if ([itemsToRead count] == 0) {
                [self appendDetail:([errorMessage length] > 0 ? [NSString stringWithFormat:@"Read all: no unread chats found; wider load warning: %@", errorMessage] : @"Read all: no unread chats found.")];
            } else {
                [self appendDetail:[NSString stringWithFormat:@"Read all: marking %lu chat(s) as read.", (unsigned long)[itemsToRead count]]];
                NSUInteger readIndex = 0;
                for (readIndex = 0; readIndex < [itemsToRead count]; readIndex++) {
                    [self markChatItemRead:[itemsToRead objectAtIndex:readIndex]];
                }
            }
            [self setMarkAllChatsReadBusy:NO];
            [seedCopy release];
            [serverItems release];
            [errorMessage release];
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
    BOOL archived = self.showingArchivedChats;
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
        BOOL succeeded = [client toggleChatPinnedForChatID:chatID
                                              chatFilterID:chatFilterID
                                                  archived:archived
                                                    pinned:targetPinned
                                                   timeout:6.0
                                                     error:&pinError];
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
    [self setServerNotificationMuteForChatItem:item duration:[duration doubleValue]];
}

- (void)unmuteChatFromMenu:(id)sender {
    TGChatItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    NSNumber *chatID = [self notificationChatIDForChatItem:item];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    [self setServerNotificationMuteForChatItem:item duration:0.0];
}

- (void)setServerNotificationMuteForChatItem:(TGChatItem *)item duration:(NSTimeInterval)duration {
    NSNumber *sourceChatID = [self notificationChatIDForChatItem:item];
    if (![item isKindOfClass:[TGChatItem class]] ||
        ![sourceChatID respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    TGChatItem *itemCopy = [item retain];
    NSNumber *chatID = [[NSNumber numberWithLongLong:[sourceChatID longLongValue]] retain];
    NSString *title = [[[item title] length] > 0 ? [item title] : @"chat" copy];
    TGTDLibClient *client = [self.client retain];
    BOOL targetMuted = (duration != 0.0);

    [self.statusField setStringValue:(targetMuted ? TGLoc(@"chat.notifications.syncingMute")
                                                   : TGLoc(@"chat.notifications.syncingEnable"))];
    [[TGLogger sharedLogger] log:(targetMuted
        ? @"TDLib server chat mute requested."
        : @"TDLib server chat unmute requested.")];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *notificationError = nil;
        BOOL succeeded = [client setChatNotificationMuteForChatID:chatID
                                                          muteFor:duration
                                                          timeout:8.0
                                                            error:&notificationError];
        NSString *errorMessage = [[notificationError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (succeeded) {
                [self setLocalNotificationMuteForChatID:chatID duration:0.0];
                [itemCopy setServerNotificationsMuted:targetMuted];
                [itemCopy setNotificationsMuted:targetMuted];
                [self.chatTableView reloadData];
                [self updateApplicationBadge];
                [self.statusField setStringValue:(targetMuted ? TGLoc(@"chat.notifications.serverMuted")
                                                               : TGLoc(@"chat.notifications.serverOn"))];
                [self appendDetail:[NSString stringWithFormat:@"Telegram notification settings synchronized for %@.", title]];
                [self reloadChatsInteractive:NO preserveSelection:YES];
            } else {
                [self setLocalNotificationMuteForChatID:chatID duration:duration];
                [self.statusField setStringValue:TGLoc(@"chat.notifications.localFallback")];
                [self appendDetail:[NSString stringWithFormat:@"Telegram notification synchronization unavailable for %@: %@",
                                    title,
                                    [errorMessage length] > 0 ? errorMessage : @"request failed"]];
            }
            [errorMessage release];
            [itemCopy release];
            [chatID release];
            [title release];
            [client release];
        });
        [pool drain];
    });
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
