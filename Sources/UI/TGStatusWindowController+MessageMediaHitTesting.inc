- (NSRect)messageBubbleCellFrameForRow:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return NSZeroRect;
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (!bubbleColumn) {
        return NSZeroRect;
    }
    NSUInteger columnIndex = [[self.messageTableView tableColumns] indexOfObject:bubbleColumn];
    if (columnIndex == NSNotFound) {
        return NSZeroRect;
    }
    return [self.messageTableView frameOfCellAtColumn:(NSInteger)columnIndex row:row];
}

- (NSArray *)mediaLayoutEntriesForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isVisualMediaMessage] || NSIsEmptyRect(cellFrame)) {
        return [NSArray array];
    }

    NSString *messageText = ([item isStickerMessage] || TGMessageItemIsNonVisualPlayableMedia(item)) ? @"" : TGDisplayTextForMessageItem(item);
    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = [self shouldShowGroupSenderDetailsForMessageItem:item];
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));
    BOOL flipped = [self.messageTableView isFlipped];

    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
            NSString *statusDots = TGOutgoingStatusDotsInlineTextForItem(item);
            if ([statusDots length] > 0) {
                NSMutableDictionary *statusAttributes = [NSMutableDictionary dictionaryWithDictionary:timeAttributes];
                [statusAttributes setObject:[NSFont boldSystemFontOfSize:7.0] forKey:NSFontAttributeName];
                [statusAttributes setObject:[NSColor colorWithCalibratedWhite:0.470 alpha:0.78] forKey:NSForegroundColorAttributeName];
                NSString *statusSuffix = [NSString stringWithFormat:@" %@", statusDots];
                NSAttributedString *statusSuffixText = [[[NSAttributedString alloc] initWithString:statusSuffix attributes:statusAttributes] autorelease];
                [composedMessageText appendAttributedString:statusSuffixText];
            }
        }
    }

    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [composedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 12000.0)
                                                         options:NSStringDrawingUsesLineFragmentOrigin];
    }

    NSSize photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    CGFloat photoBubbleWidth = photoSize.width + 16.0;
    if (photoBubbleWidth > bubbleWidth) {
        bubbleWidth = photoBubbleWidth;
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat mediaFooterHeight = TGMessageMediaFooterHeightForItem(item);
    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat contextHeaderHeight = TGMessageContextHeaderHeightForItem(item);
    CGFloat bubbleHeight = photoSize.height + 24.0 + mediaFooterHeight + senderHeaderHeight + contextHeaderHeight;
    if (NSHeight(measuredRect) > 0.0) {
        bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    bubbleHeight += TGReactionBandHeightForMessageItem(item);

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = flipped ? (NSMinY(bubbleRect) + 9.0) : (NSMaxY(bubbleRect) - 9.0);
    contentTop += flipped ? senderHeaderHeight : -senderHeaderHeight;
    contentTop += flipped ? contextHeaderHeight : -contextHeaderHeight;
    CGFloat reactionBandHeight = TGReactionBandHeightForMessageItem(item);
    if (!flipped) {
        contentTop -= reactionBandHeight;
    }
    if (!flipped && [messageText length] == 0 && mediaFooterHeight > 0.0) {
        contentTop -= mediaFooterHeight;
    }
    NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                  flipped ? contentTop : (contentTop - photoSize.height),
                                  photoSize.width,
                                  photoSize.height);
    NSArray *mediaItems = [item visualMediaItems];
    NSArray *tileRects = TGMediaTileRectsForMessageItem(item, imageRect);
    NSMutableArray *entries = [NSMutableArray array];
    NSUInteger tileIndex = 0;
    NSUInteger tileCount = [tileRects count];
    NSUInteger mediaCount = [mediaItems count];
    for (tileIndex = 0; tileIndex < tileCount && tileIndex < mediaCount; tileIndex++) {
        NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
        id mediaObject = [mediaItems objectAtIndex:tileIndex];
        if (![mediaObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        tileRect = TGStickerAdjustedMediaRect((NSDictionary *)mediaObject, tileRect, [self.messageTableView isFlipped]);
        [entries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            mediaObject, @"media_item",
                            [NSValue valueWithRect:tileRect], @"frame",
                            [NSNumber numberWithUnsignedInteger:tileIndex], @"tile_index",
                            nil]];
    }
    return entries;
}

- (NSDictionary *)mediaItemForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    NSArray *entries = [self mediaLayoutEntriesForItem:item inCellFrame:cellFrame];
    NSUInteger index = 0;
    for (index = 0; index < [entries count]; index++) {
        NSDictionary *entry = [entries objectAtIndex:index];
        NSRect tileRect = [[entry objectForKey:@"frame"] rectValue];
        if (NSPointInRect(tablePoint, tileRect)) {
            return [entry objectForKey:@"media_item"];
        }
    }
    return nil;
}

- (void)scheduleInlineMediaPlaybackRefresh {
    [self scheduleInlineMediaPlaybackRefreshAfterDelay:0.0];
}

- (void)scheduleInlineMediaPlaybackRefreshAfterDelay:(NSTimeInterval)delay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refreshInlineMediaPlayback)
                                               object:nil];
    [self performSelector:@selector(refreshInlineMediaPlayback) withObject:nil afterDelay:delay];
}

- (void)logInlinePlaybackDiagnosticOnceForKey:(NSString *)key message:(NSString *)message {
    if ([key length] == 0 || [message length] == 0) {
        return;
    }
    if (!self.inlineMediaPlaybackDiagnosticKeys) {
        self.inlineMediaPlaybackDiagnosticKeys = [NSMutableSet set];
    }
    if ([self.inlineMediaPlaybackDiagnosticKeys containsObject:key]) {
        return;
    }
    [self.inlineMediaPlaybackDiagnosticKeys addObject:key];
    [[TGLogger sharedLogger] log:message];
}

- (void)refreshInlineMediaPlayback {
    BOOL chatsVisible = ([self.currentAuthState isEqualToString:@"ready"] &&
                         [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats] &&
                         ![self.messageScrollView isHidden] &&
                         ![self.messageTableView isHidden]);
    if (!chatsVisible || [self.messageItems count] == 0 || [self.stickerPickerWindow isVisible]) {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        return;
    }

    NSRect visibleRect = [[self.messageScrollView contentView] bounds];
    NSRange visibleRows = [self.messageTableView rowsInRect:visibleRect];
    if (visibleRows.location == NSNotFound || visibleRows.length == 0) {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        return;
    }

    NSMutableArray *descriptors = [NSMutableArray array];
    NSUInteger lastRow = NSMaxRange(visibleRows);
    if (lastRow > [self.messageItems count]) {
        lastRow = [self.messageItems count];
    }
    NSUInteger row = 0;
    for (row = visibleRows.location; row < lastRow && [descriptors count] < 5; row++) {
        id candidate = [self.messageItems objectAtIndex:row];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        NSArray *entries = [self mediaLayoutEntriesForItem:item inCellFrame:[self messageBubbleCellFrameForRow:(NSInteger)row]];
        NSUInteger entryIndex = 0;
        for (entryIndex = 0; entryIndex < [entries count] && [descriptors count] < 5; entryIndex++) {
            NSDictionary *entry = [entries objectAtIndex:entryIndex];
            NSDictionary *mediaItem = [entry objectForKey:@"media_item"];
            NSRect frame = [[entry objectForKey:@"frame"] rectValue];
            NSString *path = TGInlinePlaybackPathForMediaItem(mediaItem);
            NSString *contentType = TGMediaItemContentType(mediaItem);
            NSString *extension = [[path pathExtension] lowercaseString];
            NSString *playbackKind = TGInlinePlaybackKindForMediaItem(mediaItem);
            BOOL animation = ([contentType isEqualToString:@"messageAnimation"] ||
                              [extension isEqualToString:@"gif"] ||
                              [extension isEqualToString:@"webm"] ||
                              [playbackKind isEqualToString:TGInlineMediaKindTGS]);
            if ([contentType isEqualToString:@"messageSticker"]) {
                id messageID = [mediaItem objectForKey:@"message_id"];
                if (![messageID respondsToSelector:@selector(longLongValue)]) {
                    messageID = [item messageID];
                }
                NSString *format = TGMediaItemStickerFormat(mediaItem);
                NSString *diagnosticKey = [NSString stringWithFormat:@"chat-sticker-%@-%@-%@",
                                           messageID ? messageID : [NSNumber numberWithUnsignedInteger:row],
                                           format ? format : @"unknown",
                                           path ? [path lastPathComponent] : @"missing"];
                if ([playbackKind isEqualToString:TGInlineMediaKindTGS] ||
                    [extension isEqualToString:@"gif"] ||
                    [extension isEqualToString:@"webm"]) {
                    [self logInlinePlaybackDiagnosticOnceForKey:diagnosticKey
                                                        message:[NSString stringWithFormat:@"Media Playback: chat candidate %@", TGMediaItemInlinePlaybackDiagnosticSummary(mediaItem)]];
                }
            }
            if (!animation || [path length] == 0 || !NSIntersectsRect(frame, visibleRect)) {
                continue;
            }
            id messageID = [mediaItem objectForKey:@"message_id"];
            if (![messageID respondsToSelector:@selector(longLongValue)]) {
                messageID = [item messageID];
            }
            NSNumber *tileIndex = [entry objectForKey:@"tile_index"];
            NSString *identifier = [NSString stringWithFormat:@"%@:%@:%@",
                                    messageID ? messageID : [NSNumber numberWithUnsignedInteger:row],
                                    tileIndex ? tileIndex : [NSNumber numberWithUnsignedInteger:entryIndex],
                                    path];
            [self logInlinePlaybackDiagnosticOnceForKey:[NSString stringWithFormat:@"chat-descriptor-%@", identifier]
                                                message:[NSString stringWithFormat:@"Media Playback: chat descriptor queued kind=%@ file=%@",
                                                         playbackKind, [path lastPathComponent]]];
            [descriptors addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    identifier, TGInlineMediaIdentifierKey,
                                    path, TGInlineMediaPathKey,
                                    [NSValue valueWithRect:frame], TGInlineMediaFrameKey,
                                    playbackKind, TGInlineMediaKindKey,
                                    nil]];
        }
    }
    [self.inlineMediaPlaybackCoordinator updateWithDescriptors:descriptors];
}

- (NSURL *)messageLinkURLForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || NSIsEmptyRect(cellFrame)) {
        return nil;
    }
    if (TGMessageItemIsNonVisualPlayableMedia(item)) {
        return nil;
    }
    NSString *messageText = TGDisplayTextForMessageItem(item);
    if ([messageText length] == 0 || !TGFirstURLInMessageItem(item)) {
        return nil;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = [self shouldShowGroupSenderDetailsForMessageItem:item];
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
        }
    }
    NSAttributedString *attributedMessageText = composedMessageText;
    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [attributedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 12000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
    } else {
        measuredRect = NSZeroRect;
    }
    NSSize photoSize = NSZeroSize;
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0 + senderHeaderHeight;
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0 + senderHeaderHeight;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    bubbleHeight += TGReactionBandHeightForMessageItem(item);

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    contentTop -= senderHeaderHeight;
    if (visualMediaMessage) {
        NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                      contentTop - photoSize.height,
                                      photoSize.width,
                                      photoSize.height);
        contentTop = NSMinY(imageRect) - 8.0;
    }

    CGFloat textHeight = ceil(NSHeight(measuredRect));
    if (textHeight <= 0.0) {
        return nil;
    }
    NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                 contentTop - textHeight,
                                 NSWidth(bubbleRect) - 24.0,
                                 textHeight + 2.0);
    if (!NSPointInRect(tablePoint, textRect)) {
        return nil;
    }

    NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:attributedMessageText] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
    NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSWidth(textRect), 12000.0)] autorelease];
    [textContainer setLineFragmentPadding:0.0];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];

    NSPoint textPoint = NSMakePoint(tablePoint.x - NSMinX(textRect), tablePoint.y - NSMinY(textRect));
    CGFloat fraction = 0.0;
    NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:textPoint
                                               inTextContainer:textContainer
                        fractionOfDistanceThroughGlyph:&fraction];
    if (glyphIndex >= [layoutManager numberOfGlyphs]) {
        return nil;
    }
    NSRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                inTextContainer:textContainer];
    if (!NSPointInRect(textPoint, NSInsetRect(glyphRect, -3.0, -4.0))) {
        return nil;
    }
    NSUInteger characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    if (characterIndex >= [messageText length]) {
        return nil;
    }
    return TGURLAtCharacterIndexInString(messageText, characterIndex);
}

- (void)openMessageLink:(id)sender {
    (void)sender;
    NSInteger row = [self.messageTableView clickedRow];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSEvent *event = [NSApp currentEvent];
    if (!event) {
        return;
    }
    NSPoint tablePoint = [self.messageTableView convertPoint:[event locationInWindow] fromView:nil];
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSRect bubbleRect = TGMessageBubbleRectForItem((TGMessageItem *)item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
    if (TGMessageItemHasCommentThread((TGMessageItem *)item)) {
        NSRect commentRect = TGMessageCommentBarRectForItem((TGMessageItem *)item, bubbleRect, [self.messageTableView isFlipped]);
        if (!NSIsEmptyRect(commentRect) && NSPointInRect(tablePoint, commentRect)) {
            [self openMessageCommentsForItem:(TGMessageItem *)item];
            return;
        }
    }
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:tablePoint];
    if (mediaItem) {
        [self openMediaPreviewForMediaItem:mediaItem];
        return;
    }
    if (TGMessageItemIsNonVisualPlayableMedia((TGMessageItem *)item)) {
        if (!NSIsEmptyRect(bubbleRect) && NSPointInRect(tablePoint, bubbleRect)) {
            [self openPlayableMediaForMessageItem:(TGMessageItem *)item];
            return;
        }
    }

    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:tablePoint];
    if (!url) {
        return;
    }
    if ([[NSWorkspace sharedWorkspace] openURL:url]) {
        [self appendDetail:@"Opened message link in default browser."];
    } else {
        [self appendDetail:@"Could not open message link in default browser."];
    }
}

- (void)openMessageCommentsForItem:(TGMessageItem *)item {
    if (!TGMessageItemHasCommentThread(item)) {
        return;
    }
    NSNumber *chatID = [NSNumber numberWithLongLong:[[item chatID] longLongValue]];
    NSNumber *threadID = [NSNumber numberWithLongLong:[[item messageID] longLongValue]];
    NSNumber *previousChatID = [self.selectedChatID retain];
    NSNumber *previousThreadID = [self.selectedMessageThreadID retain];
    NSString *previousTopicKind = [self.selectedMessageTopicKind copy];
    [self saveComposerDraftForChatID:previousChatID
                     messageThreadID:previousThreadID
                    messageTopicKind:previousTopicKind];
    self.commentThreadParentTitle = self.selectedChatTitle;
    self.commentThreadParentTypeSummary = self.selectedChatTypeSummary;
    self.commentThreadParentAvatarLocalPath = self.selectedChatAvatarLocalPath;
    self.selectedChatID = chatID;
    self.selectedMessageThreadID = threadID;
    self.selectedMessageTopicKind = @"thread";
    if ([self.selectedChatTitle length] == 0) {
        self.selectedChatTitle = TGLoc(@"message.comments.threadTitle");
    } else if ([self.selectedChatTitle rangeOfString:TGLoc(@"message.comments.threadSuffix") options:NSCaseInsensitiveSearch].location == NSNotFound) {
        self.selectedChatTitle = [NSString stringWithFormat:@"%@ %@", self.selectedChatTitle, TGLoc(@"message.comments.threadSuffix")];
    }
    self.showingForumTopicList = NO;
    self.pinnedMessageItems = [NSArray array];
    self.pinnedMessageItem = nil;
    self.pinnedMessageCarouselIndex = 0;
    self.searchGeneration++;
    [self clearTypingIndicator];
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    [self restoreComposerDraftForChatID:self.selectedChatID
                        messageThreadID:self.selectedMessageThreadID
                       messageTopicKind:self.selectedMessageTopicKind];
    [self refreshSelectedChatHeaderDisplay];
    [self updateAuthControlsForState:self.currentAuthState];
    [self appendDetail:[NSString stringWithFormat:@"Opening comments thread for message %@.", threadID]];
    [self reloadMessagesForChatID:self.selectedChatID interactive:NO];
    [self requestComposerRefocus];
    [previousChatID release];
    [previousThreadID release];
    [previousTopicKind release];
}

- (void)closeMessageCommentsThread:(id)sender {
    (void)sender;
    if (![self.selectedMessageTopicKind isEqualToString:@"thread"] ||
        ![self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)] ||
        !self.selectedChatID) {
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *threadID = [self.selectedMessageThreadID retain];
    NSString *topicKind = [self.selectedMessageTopicKind copy];
    [self saveComposerDraftForChatID:chatID
                     messageThreadID:threadID
                    messageTopicKind:topicKind];

    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    if ([self.commentThreadParentTitle length] > 0) {
        self.selectedChatTitle = self.commentThreadParentTitle;
    }
    if ([self.commentThreadParentTypeSummary length] > 0) {
        self.selectedChatTypeSummary = self.commentThreadParentTypeSummary;
    }
    self.selectedChatAvatarLocalPath = self.commentThreadParentAvatarLocalPath;
    self.commentThreadParentTitle = nil;
    self.commentThreadParentTypeSummary = nil;
    self.commentThreadParentAvatarLocalPath = nil;
    self.pinnedMessageItems = [NSArray array];
    self.pinnedMessageItem = nil;
    self.pinnedMessageCarouselIndex = 0;
    self.searchGeneration++;
    [self clearTypingIndicator];
    [self.messageItems removeAllObjects];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.messageTableView reloadData];
    [self restoreComposerDraftForChatID:chatID
                        messageThreadID:nil
                       messageTopicKind:nil];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self refreshSelectedChatHeaderDisplay];
    [self updateAuthControlsForState:self.currentAuthState];
    [self loadPinnedMessageForSelectedChat];
    [self appendDetail:@"Closed comments thread and returned to channel."];
    [self reloadMessagesForChatID:chatID interactive:NO];
    [self requestComposerRefocus];

    [chatID release];
    [threadID release];
    [topicKind release];
}
