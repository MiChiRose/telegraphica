- (void)ensurePhotoSendPreviewWindow {
    if (self.photoSendPreviewWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 520, 560);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Send photo"];
    [window setReleasedWhenClosed:NO];

    NSView *contentView = [[[NSView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    NSTextField *titleField = [self labelWithFrame:NSMakeRect(24, 518, 472, 24)
                                              text:@"1 media"
                                              font:[NSFont boldSystemFontOfSize:16.0]];
    [titleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:titleField];
    self.photoSendTitleField = titleField;

    NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(44, 124, 432, 376)] autorelease];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageFrameStyle:NSImageFrameGrayBezel];
    [imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:imageView];
    self.photoSendPreviewImageView = imageView;

    TGComposerInputBackgroundView *captionBackground = [[[TGComposerInputBackgroundView alloc] initWithFrame:NSMakeRect(44, 76, 432, 30)] autorelease];
    [captionBackground setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:captionBackground];
    self.photoSendCaptionBackgroundView = captionBackground;

    NSTextField *captionField = [[[NSTextField alloc] initWithFrame:NSMakeRect(53, 83, 414, 18)] autorelease];
    [self applyComposerTextFieldStyle:captionField];
    [[captionField cell] setPlaceholderString:TGLoc(@"caption.placeholder")];
    [captionField setDelegate:(id)self];
    [captionField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:captionField];
    self.photoSendCaptionField = captionField;

    NSTextField *errorField = [self labelWithFrame:NSMakeRect(44, 58, 432, 16)
                                              text:@""
                                              font:[NSFont systemFontOfSize:11.0]];
    [errorField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [errorField setHidden:YES];
    [errorField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [[errorField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:errorField];
    self.photoSendErrorField = errorField;

    NSButton *cancelButton = [self modalCloseButtonWithFrame:NSMakeRect(244, 28, 108, 30)];
    [cancelButton setTitle:TGLoc(@"cancel")];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(cancelPendingPhotoSend:)];
    [cancelButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:cancelButton];

    NSButton *sendButton = [[[NSButton alloc] initWithFrame:NSMakeRect(368, 28, 108, 30)] autorelease];
    [sendButton setTitle:TGLoc(@"send")];
    [sendButton setTarget:self];
    [sendButton setAction:@selector(sendPendingPhotoPreview:)];
    [self applySkeuomorphicButtonStyle:sendButton isPrimary:YES];
    [sendButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:sendButton];
    self.photoSendSendButton = sendButton;

    self.photoSendPreviewWindow = window;
}

- (void)presentPhotoSendPreviewForPath:(NSString *)path {
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before sending a photo."];
        return;
    }
    if (self.controlsBusy) {
        [self appendDetail:@"Wait for the current Telegram operation to finish before sending a photo."];
        return;
    }
    if (!TGIsSupportedPhotoPath(path)) {
        [self appendDetail:@"Photo send supports local JPG, PNG, and TIFF files."];
        return;
    }

    NSString *standardPath = [path stringByStandardizingPath];
    NSImage *image = TGImageWithCorrectOrientationFromFile(standardPath);
    if (!image) {
        image = [[[NSImage alloc] initWithContentsOfFile:standardPath] autorelease];
    }
    if (!image) {
        [self appendDetail:@"Could not load the selected photo preview."];
        return;
    }

    [self ensurePhotoSendPreviewWindow];
    self.pendingPhotoSendPath = standardPath;
    self.pendingPhotoSendChatID = self.selectedChatID;
    self.pendingPhotoSendThreadID = self.selectedMessageThreadID;
    self.pendingPhotoSendTopicKind = self.selectedMessageTopicKind;
    [self.photoSendPreviewImageView setImage:image];
    [self.photoSendCaptionField setStringValue:@""];
    [[self.photoSendCaptionField cell] setPlaceholderString:TGLoc(@"caption.placeholder")];
    [self.photoSendErrorField setStringValue:@""];
    [self.photoSendErrorField setHidden:YES];
    [self.photoSendSendButton setTitle:TGLoc(@"send")];
    [self.photoSendSendButton setEnabled:YES];
    [self.photoSendPreviewWindow center];
    [self.photoSendPreviewWindow makeKeyAndOrderFront:nil];
    [[self.photoSendPreviewWindow contentView] setNeedsDisplay:YES];
}

- (void)cancelPendingPhotoSend:(id)sender {
    (void)sender;
    self.pendingPhotoSendPath = nil;
    self.pendingPhotoSendChatID = nil;
    self.pendingPhotoSendThreadID = nil;
    self.pendingPhotoSendTopicKind = nil;
    [self.photoSendPreviewWindow orderOut:nil];
    [self requestComposerRefocus];
}

- (void)submitPhotoAtPath:(NSString *)path caption:(NSString *)caption chatID:(NSNumber *)targetChatID messageThreadID:(NSNumber *)targetThreadID messageTopicKind:(NSString *)targetTopicKind {
    if (![path length] || ![targetChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSNumber *chatID = [targetChatID retain];
    NSNumber *messageThreadID = [targetThreadID retain];
    NSString *messageTopicKind = [targetTopicKind copy];
    NSString *photoPath = [[path stringByStandardizingPath] copy];
    NSString *safeCaption = [caption isKindOfClass:[NSString class]] ? caption : @"";
    NSString *photoCaption = [safeCaption copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending photo..."];
    [self appendDetail:(messageThreadID ? @"Submitting topic photo message to TDLib..." : @"Submitting photo message to TDLib...")];
    [[TGLogger sharedLogger] log:@"TDLib photo message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSString *sendSummary = [client sendPhotoMessageToChatID:chatID
                                                 messageThreadID:messageThreadID
                                               messageTopicKind:messageTopicKind
                                                       localPath:photoPath
                                                         caption:photoCaption
                                                         timeout:18.0
                                                           error:&sendError];
        NSString *sendErrorMessage = [[sendError localizedDescription] copy];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        BOOL sendSucceeded = ([sendSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if (sendSucceeded) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:@"Photo sent"];
                [self appendDetail:@"TDLib send: photo message accepted by TDLib."];
                [[TGLogger sharedLogger] log:@"TDLib photo message send accepted."];
                self.pendingPhotoSendPath = nil;
                self.pendingPhotoSendChatID = nil;
                self.pendingPhotoSendThreadID = nil;
                self.pendingPhotoSendTopicKind = nil;
                if (self.photoSendPreviewWindow && ![self.photoSendPreviewWindow isVisible]) {
                    [self.photoSendSendButton setTitle:TGLoc(@"send")];
                    [self.photoSendSendButton setEnabled:YES];
                }
                if (self.photoSendPreviewWindow && [self.photoSendPreviewWindow isVisible]) {
                    [self.photoSendPreviewWindow orderOut:nil];
                    [self.photoSendSendButton setTitle:TGLoc(@"send")];
                    [self.photoSendSendButton setEnabled:YES];
                    [self.photoSendErrorField setStringValue:@""];
                    [self.photoSendErrorField setHidden:YES];
                }
                if (selectionStillCurrent) {
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                NSString *message = ([sendErrorMessage length] > 0) ? sendErrorMessage : @"Photo send was not confirmed.";
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Photo was not retried automatically to avoid duplicate sends."];
                } else {
                    [self.statusField setStringValue:@"Photo send failed"];
                }
                [self appendDetail:[NSString stringWithFormat:@"TDLib send: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib photo message send failed."];
                if (self.photoSendPreviewWindow && [self.photoSendPreviewWindow isVisible]) {
                    [self.photoSendSendButton setTitle:TGLoc(@"send")];
                    [self.photoSendSendButton setEnabled:YES];
                    [self.photoSendErrorField setStringValue:message];
                    [self.photoSendErrorField setHidden:NO];
                }
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (sendSucceeded && selectionStillCurrent) {
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                         selector:@selector(refreshSelectedMessagesAfterMediaSend)
                                                           object:nil];
                [self performSelector:@selector(refreshSelectedMessagesAfterMediaSend) withObject:nil afterDelay:1.25];
                [self requestComposerRefocus];
            }
            [authorizationState release];
            [sendErrorMessage release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [photoPath release];
            [photoCaption release];
        });

        [client release];
        [pool drain];
    });
}

- (void)refreshSelectedMessagesAfterMediaSend {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID || self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }
    NSNumber *chatID = [self.selectedChatID retain];
    [self reloadMessagesForChatID:chatID interactive:NO];
    [chatID release];
}

- (void)sendPendingPhotoPreview:(id)sender {
    (void)sender;
    NSString *path = [self.pendingPhotoSendPath copy];
    NSString *caption = [[self.photoSendCaptionField stringValue] copy];
    NSNumber *chatID = [self.pendingPhotoSendChatID retain];
    NSNumber *threadID = [self.pendingPhotoSendThreadID retain];
    NSString *topicKind = [self.pendingPhotoSendTopicKind copy];
    if (![path length] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        [self.photoSendErrorField setStringValue:@"Photo target is no longer available."];
        [self.photoSendErrorField setHidden:NO];
    } else {
        [self.photoSendErrorField setStringValue:@""];
        [self.photoSendErrorField setHidden:YES];
        [self.photoSendSendButton setTitle:TGLoc(@"sending")];
        [self.photoSendSendButton setEnabled:NO];
        [self submitPhotoAtPath:path caption:caption chatID:chatID messageThreadID:threadID messageTopicKind:topicKind];
    }
    [path release];
    [caption release];
    [chatID release];
    [threadID release];
    [topicKind release];
}

- (void)ensureStickerPickerWindow {
    if (self.stickerPickerWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 430, 430);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:TGLoc(@"stickers")];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    NSView *contentView = [[[NSView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    NSTextField *statusField = [self labelWithFrame:NSMakeRect(18, 392, 394, 20)
                                               text:@"Recent stickers"
                                               font:[NSFont systemFontOfSize:12.0]];
    [self applyMutedLabelStyle:statusField];
    [contentView addSubview:statusField];
    self.stickerPickerStatusField = statusField;

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(18, 18, 394, 362)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    NSView *gridView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 376, 360)] autorelease];
    [scrollView setDocumentView:gridView];
    [[scrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stickerPickerScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[scrollView contentView]];
    [contentView addSubview:scrollView];
    self.stickerPickerScrollView = scrollView;
    self.stickerPickerContentView = gridView;
    self.stickerPickerPlaybackCoordinator = [[[TGInlineMediaPlaybackCoordinator alloc] initWithHostView:gridView
                                                                                           maximumActiveItems:5] autorelease];
    self.stickerPickerWindow = window;
}

- (void)stickerPickerScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.stickerPickerScrollView contentView]) {
        return;
    }
    [self refreshStickerPickerPlayback];
}

- (void)refreshStickerPickerPlayback {
    if (![self.stickerPickerWindow isVisible] || !self.stickerPickerContentView) {
        [self.stickerPickerPlaybackCoordinator removeAllPlayback];
        return;
    }

    NSRect visibleRect = [[self.stickerPickerScrollView contentView] bounds];
    NSMutableArray *descriptors = [NSMutableArray array];
    NSArray *subviews = [self.stickerPickerContentView subviews];
    NSUInteger index = 0;
    for (index = 0; index < [subviews count]; index++) {
        NSView *candidateView = [subviews objectAtIndex:index];
        if (![candidateView isKindOfClass:[NSButton class]] || !NSIntersectsRect([candidateView frame], visibleRect)) {
            continue;
        }
        NSInteger stickerIndex = [(NSButton *)candidateView tag];
        if (stickerIndex < 0 || (NSUInteger)stickerIndex >= [self.stickerPickerItems count]) {
            continue;
        }
        id candidateItem = [self.stickerPickerItems objectAtIndex:(NSUInteger)stickerIndex];
        if (![candidateItem isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *path = TGInlinePlaybackPathForMediaItem((NSDictionary *)candidateItem);
        if ([path length] == 0) {
            continue;
        }
        NSString *identifier = [NSString stringWithFormat:@"sticker-picker-%ld-%@", (long)stickerIndex, path];
        NSString *playbackKind = TGInlinePlaybackKindForMediaItem((NSDictionary *)candidateItem);
        NSRect playbackFrame = TGStickerPickerContentRectForButtonFrame([candidateView frame]);
        [descriptors addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                identifier, TGInlineMediaIdentifierKey,
                                path, TGInlineMediaPathKey,
                                [NSValue valueWithRect:playbackFrame], TGInlineMediaFrameKey,
                                playbackKind, TGInlineMediaKindKey,
                                nil]];
    }
    [self.stickerPickerPlaybackCoordinator updateWithDescriptors:descriptors];
}

- (void)rebuildStickerPickerGrid {
    NSView *gridView = self.stickerPickerContentView;
    if (!gridView) {
        return;
    }
    NSArray *oldSubviews = [[gridView subviews] copy];
    NSUInteger removeIndex = 0;
    for (removeIndex = 0; removeIndex < [oldSubviews count]; removeIndex++) {
        [[oldSubviews objectAtIndex:removeIndex] removeFromSuperview];
    }
    [oldSubviews release];

    CGFloat buttonSide = 58.0;
    CGFloat gap = 10.0;
    NSUInteger columns = 5;
    CGFloat contentWidth = 376.0;
    NSUInteger count = [self.stickerPickerItems count];
    NSUInteger rows = (count == 0) ? 1 : ((count + columns - 1) / columns);
    CGFloat contentHeight = rows * (buttonSide + gap) + gap;
    if (contentHeight < 360.0) {
        contentHeight = 360.0;
    }
    [gridView setFrame:NSMakeRect(0, 0, contentWidth, contentHeight)];

    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        id candidate = [self.stickerPickerItems objectAtIndex:index];
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *item = (NSDictionary *)candidate;
        NSUInteger row = index / columns;
        NSUInteger column = index % columns;
        CGFloat x = gap + (CGFloat)column * (buttonSide + gap);
        CGFloat y = contentHeight - gap - buttonSide - (CGFloat)row * (buttonSide + gap);
        NSButton *button = TGStickerPickerButtonWithFrame(NSMakeRect(x, y, buttonSide, buttonSide),
                                                          item,
                                                          (NSInteger)index,
                                                          self,
                                                          @selector(sendStickerFromPickerButton:));
        [gridView addSubview:button];
    }
    [self refreshStickerPickerPlayback];
}

- (void)reloadStickerPickerItems {
    [self.stickerPickerStatusField setStringValue:@"Loading stickers..."];
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.stickerPickerLoadGeneration + 1;
    self.stickerPickerLoadGeneration = generation;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *stickerError = nil;
        NSArray *items = [[client recentStickerItemsWithLimit:40 timeout:8.0 error:&stickerError] copy];
        NSString *errorMessage = [[stickerError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL resultIsCurrent = (generation == self.stickerPickerLoadGeneration && client == self.client);
            if (!resultIsCurrent) {
                [items release];
                [errorMessage release];
                [client release];
                return;
            }
            if ([items count] > 0) {
                self.stickerPickerItems = items;
                [self.stickerPickerStatusField setStringValue:@"Recent stickers"];
            } else {
                self.stickerPickerItems = [NSArray array];
                [self.stickerPickerStatusField setStringValue:([errorMessage length] > 0 ? errorMessage : @"No recent stickers yet")];
            }
            [self rebuildStickerPickerGrid];
            [items release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)showStickerPicker:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        return;
    }
    [self ensureStickerPickerWindow];
    [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    [self.stickerPickerWindow setTitle:TGLoc(@"stickers")];
    [self.stickerPickerWindow center];
    [self.stickerPickerWindow makeKeyAndOrderFront:nil];
    if ([self.stickerPickerItems count] == 0) {
        [self reloadStickerPickerItems];
    } else {
        [self rebuildStickerPickerGrid];
    }
}

- (void)sendStickerFromPickerButton:(id)sender {
    NSInteger stickerIndex = [sender respondsToSelector:@selector(tag)] ? [sender tag] : -1;
    id represented = (stickerIndex >= 0 && (NSUInteger)stickerIndex < [self.stickerPickerItems count]) ? [self.stickerPickerItems objectAtIndex:(NSUInteger)stickerIndex] : nil;
    if (![represented isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *sticker = (NSDictionary *)represented;
    NSNumber *fileID = TGMediaItemFullFileID(sticker);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        fileID = [sticker objectForKey:@"file_id"];
    }
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self appendDetail:@"Sticker file id is not available."];
        return;
    }
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    NSString *emoji = [[sticker objectForKey:@"emoji"] copy];
    NSNumber *width = [[sticker objectForKey:@"width"] retain];
    NSNumber *height = [[sticker objectForKey:@"height"] retain];
    [self.stickerPickerWindow orderOut:nil];
    [self.stickerPickerPlaybackCoordinator removeAllPlayback];
    [self scheduleInlineMediaPlaybackRefresh];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending sticker..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSString *summary = [[client sendStickerMessageToChatID:chatID
                                                messageThreadID:messageThreadID
                                               messageTopicKind:messageTopicKind
                                                  stickerFileID:fileID
                                                          emoji:emoji
                                                          width:width
                                                         height:height
                                                        timeout:10.0
                                                          error:&sendError] copy];
        NSString *errorMessage = [[sendError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([summary length] > 0) {
                [self.statusField setStringValue:@"Sticker sent"];
                self.forceMessageScrollToNewest = YES;
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
            } else {
                [self.statusField setStringValue:@"Sticker send failed"];
                [self appendDetail:([errorMessage length] > 0 ? errorMessage : @"Sticker send was not confirmed.")];
            }
            [self setControlsBusy:NO];
            [self requestComposerRefocus];
            [errorMessage release];
            [summary release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [emoji release];
            [width release];
            [height release];
            [client release];
        });
        [pool drain];
    });
}

- (NSString *)temporaryVoiceRecordingPath {
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"TelegraphicaVoice"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    NSString *name = [NSString stringWithFormat:@"voice-%lld.m4a", (long long)([[NSDate date] timeIntervalSince1970] * 1000.0)];
    return [directory stringByAppendingPathComponent:name];
}

- (void)invalidateVoicePreviewTimer {
    [self.voicePreviewTimer invalidate];
    self.voicePreviewTimer = nil;
}

- (void)updateVoicePreviewTimelineWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    if (duration < 0.1) {
        duration = 0.0;
    }
    if (currentTime < 0.0) {
        currentTime = 0.0;
    }
    if (duration > 0.0 && currentTime > duration) {
        currentTime = duration;
    }

    CGFloat sliderMaximum = (duration > 0.0) ? duration : 1.0;
    [self.voicePreviewProgressSlider setMinValue:0.0];
    [self.voicePreviewProgressSlider setMaxValue:sliderMaximum];
    [self.voicePreviewProgressSlider setDoubleValue:currentTime];
    [self.voicePreviewProgressSlider setEnabled:(duration > 0.0)];

    NSString *timeText = [NSString stringWithFormat:@"%@ / %@",
                          TGVoicePreviewTimeString(currentTime),
                          TGVoicePreviewTimeString(duration)];
    [self.voicePreviewTimeField setStringValue:timeText];
}

- (NSTimeInterval)prepareVoicePreviewPlayerIfNeeded {
    if ([self.voiceRecordingPath length] == 0) {
        return 0.0;
    }
    if (!self.voicePreviewPlayer) {
        NSError *playError = nil;
        AVAudioPlayer *player = [[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:self.voiceRecordingPath] error:&playError] autorelease];
        if (!player) {
            [self appendDetail:[NSString stringWithFormat:@"Voice preview: %@", [playError localizedDescription] ? [playError localizedDescription] : @"could not play"]];
            if (self.voicePreviewErrorField) {
                [self.voicePreviewErrorField setStringValue:([playError localizedDescription] ? [playError localizedDescription] : @"Could not play voice preview.")];
                [self.voicePreviewErrorField setHidden:NO];
            }
            return 0.0;
        }
        [player prepareToPlay];
        self.voicePreviewPlayer = player;
    }
    return [self.voicePreviewPlayer duration];
}

- (void)voicePreviewTimerDidFire:(NSTimer *)timer {
    (void)timer;
    AVAudioPlayer *player = self.voicePreviewPlayer;
    if (!player) {
        [self invalidateVoicePreviewTimer];
        [self.voicePreviewPlayButton setTitle:@"Play"];
        [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:0.0];
        return;
    }

    NSTimeInterval duration = [player duration];
    NSTimeInterval currentTime = [player currentTime];
    if (![player isPlaying] && duration > 0.0 && currentTime >= duration - 0.05) {
        [player setCurrentTime:0.0];
        [self.voicePreviewPlayButton setTitle:@"Play"];
        [self invalidateVoicePreviewTimer];
        [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:duration];
        return;
    }
    [self updateVoicePreviewTimelineWithCurrentTime:currentTime duration:duration];
}

- (void)startVoicePreviewTimer {
    [self invalidateVoicePreviewTimer];
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.2
                                             target:self
                                           selector:@selector(voicePreviewTimerDidFire:)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.voicePreviewTimer = timer;
}

- (void)voicePreviewSliderChanged:(id)sender {
    NSTimeInterval value = [sender respondsToSelector:@selector(doubleValue)] ? [sender doubleValue] : 0.0;
    NSTimeInterval duration = [self prepareVoicePreviewPlayerIfNeeded];
    if (self.voicePreviewPlayer && duration > 0.0) {
        if (value > duration) {
            value = duration;
        }
        [self.voicePreviewPlayer setCurrentTime:value];
    }
    [self updateVoicePreviewTimelineWithCurrentTime:value duration:duration];
}

- (void)ensureVoicePreviewWindow {
    if (self.voicePreviewWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 380, 148);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Voice message"];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];
    NSView *contentView = [[[NSView alloc] initWithFrame:frame] autorelease];
    [window setContentView:contentView];

    NSTextField *titleField = [self labelWithFrame:NSMakeRect(20, 104, 340, 22)
                                              text:@"Voice message ready"
                                              font:[NSFont boldSystemFontOfSize:15.0]];
    [titleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:titleField];
    self.voicePreviewTitleField = titleField;

    NSButton *playButton = [[[NSButton alloc] initWithFrame:NSMakeRect(22, 58, 72, 28)] autorelease];
    [playButton setTitle:@"Play"];
    [playButton setTarget:self];
    [playButton setAction:@selector(toggleVoicePreviewPlayback:)];
    [self applySkeuomorphicButtonStyle:playButton isPrimary:NO];
    [contentView addSubview:playButton];
    self.voicePreviewPlayButton = playButton;

    NSSlider *progressSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(104, 61, 164, 22)] autorelease];
    [progressSlider setMinValue:0.0];
    [progressSlider setMaxValue:1.0];
    [progressSlider setDoubleValue:0.0];
    [progressSlider setContinuous:YES];
    [progressSlider setTarget:self];
    [progressSlider setAction:@selector(voicePreviewSliderChanged:)];
    [progressSlider setEnabled:NO];
    [contentView addSubview:progressSlider];
    self.voicePreviewProgressSlider = progressSlider;

    NSTextField *timeField = [self labelWithFrame:NSMakeRect(276, 60, 82, 20)
                                             text:@"0:00 / 0:00"
                                             font:[NSFont systemFontOfSize:11.0]];
    [timeField setAlignment:NSRightTextAlignment];
    [self applyMutedLabelStyle:timeField];
    [contentView addSubview:timeField];
    self.voicePreviewTimeField = timeField;

    NSButton *cancelButton = [self modalCloseButtonWithFrame:NSMakeRect(158, 20, 92, 28)];
    [cancelButton setTitle:TGLoc(@"cancel")];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(cancelVoicePreview:)];
    [contentView addSubview:cancelButton];

    NSButton *sendButton = [[[NSButton alloc] initWithFrame:NSMakeRect(266, 20, 92, 28)] autorelease];
    [sendButton setTitle:TGLoc(@"send")];
    [sendButton setTarget:self];
    [sendButton setAction:@selector(sendVoicePreview:)];
    [self applySkeuomorphicButtonStyle:sendButton isPrimary:YES];
    [contentView addSubview:sendButton];
    self.voicePreviewSendButton = sendButton;

    NSTextField *errorField = [self labelWithFrame:NSMakeRect(20, 88, 340, 14)
                                              text:@""
                                              font:[NSFont systemFontOfSize:11.0]];
    [errorField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [errorField setAlignment:NSCenterTextAlignment];
    [errorField setHidden:YES];
    [[errorField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:errorField];
    self.voicePreviewErrorField = errorField;

    self.voicePreviewWindow = window;
}

- (BOOL)ensureMicrophoneConsent {
    if (TGUserDefaultBoolWithDefault(TGMicrophoneConsentDefaultsKey, NO)) {
        return YES;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"voice.permission.title")];
    [alert setInformativeText:TGLoc(@"voice.permission.message")];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSInteger result = [alert runModal];
    if (result == NSAlertFirstButtonReturn) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TGMicrophoneConsentDefaultsKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return YES;
    }
    return NO;
}

- (void)toggleVoiceRecording:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        return;
    }

    if ([self.voiceRecorder isRecording]) {
        [self.voiceRecorder stop];
        self.voiceRecorder = nil;
        [self.voiceRecordButton setToolTip:@"Record voice message"];
        [self.statusField setStringValue:@"Voice recorded"];
        [self.voiceRecordingIndicatorField setStringValue:@""];
        [self.voiceRecordingIndicatorField setHidden:YES];
        [self ensureVoicePreviewWindow];
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.voiceRecordingStartDate];
        self.voicePreviewPlayer = nil;
        [self.voicePreviewTitleField setStringValue:[NSString stringWithFormat:@"Voice message %.0fs", duration]];
        [self.voicePreviewPlayButton setTitle:@"Play"];
        [self.voicePreviewSendButton setTitle:TGLoc(@"send")];
        [self.voicePreviewSendButton setEnabled:YES];
        [self.voicePreviewErrorField setStringValue:@""];
        [self.voicePreviewErrorField setHidden:YES];
        [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:duration];
        [self.voicePreviewWindow center];
        [self.voicePreviewWindow makeKeyAndOrderFront:nil];
        [self layoutContentView];
        [self updateVisibleSection];
        return;
    }

    if (![self ensureMicrophoneConsent]) {
        return;
    }

    [self invalidateVoicePreviewTimer];
    [self.voicePreviewPlayer stop];
    self.voicePreviewPlayer = nil;

    NSString *path = [self temporaryVoiceRecordingPath];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
                              [NSNumber numberWithFloat:44100.0], AVSampleRateKey,
                              [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                              [NSNumber numberWithInt:AVAudioQualityMedium], AVEncoderAudioQualityKey,
                              nil];
    NSError *recordError = nil;
    AVAudioRecorder *recorder = [[[AVAudioRecorder alloc] initWithURL:url settings:settings error:&recordError] autorelease];
    if (!recorder) {
        [self appendDetail:[NSString stringWithFormat:@"Voice recorder: %@", [recordError localizedDescription] ? [recordError localizedDescription] : @"could not start"]];
        return;
    }
    [recorder prepareToRecord];
    if (![recorder record]) {
        [self appendDetail:@"Voice recorder could not start recording."];
        return;
    }
    self.voiceRecordingPath = path;
    self.voiceRecordingStartDate = [NSDate date];
    self.voiceRecorder = recorder;
    [self.statusField setStringValue:TGLoc(@"voice.recording")];
    [self.voiceRecordingIndicatorField setStringValue:[NSString stringWithFormat:@"%@ %@", TGLoc(@"voice.recording"), TGLoc(@"voice.stopHint")]];
    [self.voiceRecordingIndicatorField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [self.voiceRecordingIndicatorField setHidden:NO];
    [self.voiceRecordButton setToolTip:TGLoc(@"voice.stopHint")];
    [self layoutContentView];
    [self updateVisibleSection];
}

- (void)toggleVoicePreviewPlayback:(id)sender {
    (void)sender;
    if ([self.voicePreviewPlayer isPlaying]) {
        [self.voicePreviewPlayer pause];
        [self.voicePreviewPlayButton setTitle:@"Play"];
        [self invalidateVoicePreviewTimer];
        [self updateVoicePreviewTimelineWithCurrentTime:[self.voicePreviewPlayer currentTime] duration:[self.voicePreviewPlayer duration]];
        return;
    }
    if ([self.voiceRecordingPath length] == 0) {
        return;
    }
    NSTimeInterval duration = [self prepareVoicePreviewPlayerIfNeeded];
    AVAudioPlayer *player = self.voicePreviewPlayer;
    if (!player) {
        return;
    }
    if (duration > 0.0 && [player currentTime] >= duration - 0.05) {
        [player setCurrentTime:0.0];
    }
    [player play];
    [self.voicePreviewPlayButton setTitle:@"Pause"];
    [self updateVoicePreviewTimelineWithCurrentTime:[player currentTime] duration:[player duration]];
    [self startVoicePreviewTimer];
}

- (void)cancelVoicePreview:(id)sender {
    (void)sender;
    [self invalidateVoicePreviewTimer];
    [self.voicePreviewPlayer stop];
    self.voicePreviewPlayer = nil;
    if ([self.voiceRecordingPath length] > 0) {
        [[NSFileManager defaultManager] removeItemAtPath:self.voiceRecordingPath error:NULL];
    }
    self.voiceRecordingPath = nil;
    self.voiceRecordingStartDate = nil;
    [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:0.0];
    [self.voicePreviewWindow orderOut:nil];
    [self requestComposerRefocus];
}

- (void)sendVoicePreview:(id)sender {
    (void)sender;
    if ([self.voiceRecordingPath length] == 0) {
        return;
    }

    NSString *path = [self.voiceRecordingPath copy];
    NSTimeInterval durationInterval = 0.0;
    if (self.voicePreviewPlayer) {
        durationInterval = [self.voicePreviewPlayer duration];
    }
    if (durationInterval <= 0.0) {
        AVAudioPlayer *durationPlayer = [[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:NULL] autorelease];
        if (durationPlayer) {
            durationInterval = [durationPlayer duration];
        }
    }
    if (durationInterval <= 0.0 && self.voiceRecordingStartDate) {
        durationInterval = [[NSDate date] timeIntervalSinceDate:self.voiceRecordingStartDate];
    }
    NSNumber *duration = [NSNumber numberWithInteger:(NSInteger)ceil(durationInterval)];
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    [self.voicePreviewSendButton setTitle:TGLoc(@"sending")];
    [self.voicePreviewSendButton setEnabled:NO];
    [self.voicePreviewErrorField setStringValue:@""];
    [self.voicePreviewErrorField setHidden:YES];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending voice..."];
    [self invalidateVoicePreviewTimer];
    [self.voicePreviewPlayer stop];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSString *summary = [[client sendVoiceMessageToChatID:chatID
                                              messageThreadID:messageThreadID
                                             messageTopicKind:messageTopicKind
                                                    localPath:path
                                                     duration:duration
                                                      caption:@""
                                                      timeout:14.0
                                                        error:&sendError] copy];
        NSString *errorMessage = [[sendError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([summary length] > 0) {
                [self.statusField setStringValue:@"Voice sent"];
                self.forceMessageScrollToNewest = YES;
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                         selector:@selector(refreshSelectedMessagesAfterMediaSend)
                                                           object:nil];
                [self performSelector:@selector(refreshSelectedMessagesAfterMediaSend) withObject:nil afterDelay:1.25];
                [self.voicePreviewWindow orderOut:nil];
                [self.voicePreviewSendButton setTitle:TGLoc(@"send")];
                [self.voicePreviewSendButton setEnabled:YES];
                [self.voicePreviewErrorField setStringValue:@""];
                [self.voicePreviewErrorField setHidden:YES];
                self.voiceRecordingPath = nil;
                self.voiceRecordingStartDate = nil;
                self.voicePreviewPlayer = nil;
                [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:0.0];
            } else {
                [self.statusField setStringValue:@"Voice send failed"];
                [self appendDetail:([errorMessage length] > 0 ? errorMessage : @"Voice send was not confirmed.")];
                [self.voicePreviewSendButton setTitle:TGLoc(@"send")];
                [self.voicePreviewSendButton setEnabled:YES];
                [self.voicePreviewErrorField setStringValue:([errorMessage length] > 0 ? errorMessage : @"Voice send was not confirmed.")];
                [self.voicePreviewErrorField setHidden:NO];
            }
            [self setControlsBusy:NO];
            [self requestComposerRefocus];
            [summary release];
            [errorMessage release];
            [path release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [client release];
        });
        [pool drain];
    });
}

- (void)sendPhotoAtPath:(NSString *)path {
    [self presentPhotoSendPreviewForPath:path];
}

- (void)attachPhoto:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before attaching a photo."];
        return;
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"tif", @"tiff", nil]];
    NSInteger result = [panel runModal];
    if (result != NSOKButton) {
        [self requestComposerRefocus];
        return;
    }

    NSArray *urls = [panel URLs];
    if ([urls count] == 0) {
        return;
    }
    NSURL *url = [urls objectAtIndex:0];
    NSString *photoPath = [url path];
    [self sendPhotoAtPath:photoPath];
}

- (void)sendMessage:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before sending."];
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] == 0) {
        [self appendDetail:@"Message text is empty."];
        [self updateSendControls];
        return;
    }
    if ([text length] > 4096) {
        [self appendDetail:@"Message text is too long for this spike."];
        [self updateSendControls];
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    NSString *messageText = [text copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending..."];
    [self appendDetail:(messageThreadID ? @"Submitting topic text message to TDLib..." : @"Submitting text message to TDLib...")];
    [[TGLogger sharedLogger] log:@"TDLib text message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSString *sendSummary = [client sendTextMessageToChatID:chatID
                                                messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
                                                           text:messageText
                                                        timeout:8.0
                                                          error:&sendError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        NSString *sendErrorMessage = [[sendError localizedDescription] copy];
        BOOL sendSucceeded = ([sendSummary length] > 0);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if (sendSucceeded) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:@"Message sent"];
                [self appendDetail:@"TDLib send: text message accepted by TDLib."];
                [[TGLogger sharedLogger] log:@"TDLib text message send accepted."];
                [self removeComposerDraftForChatID:chatID
                                   messageThreadID:messageThreadID
                                    messageTopicKind:messageTopicKind];
                if (selectionStillCurrent) {
                    [self setComposerTextWithoutSavingDraft:nil];
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                NSString *message = ([sendErrorMessage length] > 0) ? sendErrorMessage : @"Text message was not confirmed.";
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Message was not retried automatically to avoid duplicate sends."];
                } else {
                    [self.statusField setStringValue:@"Send not confirmed"];
                }
                [self appendDetail:[NSString stringWithFormat:@"TDLib send: %@ Do not retry automatically; it may or may not have been sent.", message]];
                [[TGLogger sharedLogger] log:@"TDLib text message send not confirmed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            if (sendSucceeded && selectionStillCurrent) {
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            }
            [authorizationState release];
            [sendErrorMessage release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [messageText release];
        });

        [client release];
        [pool drain];
    });
}

