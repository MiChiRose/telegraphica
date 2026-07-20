static void TGDrawAttachmentPreviewImageInRect(NSImage *image, NSRect rect) {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];
    [[NSColor colorWithCalibratedWhite:0.96 alpha:1.0] set];
    [path fill];
    if (image) {
        NSSize imageSize = [image size];
        if (imageSize.width > 0.0 && imageSize.height > 0.0) {
            CGFloat scale = MIN(NSWidth(rect) / imageSize.width, NSHeight(rect) / imageSize.height);
            NSSize drawSize = NSMakeSize(floor(imageSize.width * scale), floor(imageSize.height * scale));
            NSRect drawRect = NSMakeRect(NSMidX(rect) - floor(drawSize.width / 2.0),
                                         NSMidY(rect) - floor(drawSize.height / 2.0),
                                         drawSize.width,
                                         drawSize.height);
            [NSGraphicsContext saveGraphicsState];
            [path addClip];
            [image drawInRect:drawRect
                     fromRect:NSZeroRect
                    operation:NSCompositeSourceOver
                     fraction:1.0
               respectFlipped:NO
                        hints:nil];
            [NSGraphicsContext restoreGraphicsState];
        }
    }
    [[NSColor colorWithCalibratedWhite:0.70 alpha:0.78] set];
    [path setLineWidth:1.0];
    [path stroke];
}

static NSString *TGSummarizeAttachmentDescriptors(NSArray *descriptors) {
    unsigned long long totalSize = 0;
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count]; index++) {
        TGAttachmentDescriptor *descriptor = [descriptors objectAtIndex:index];
        if ([descriptor isKindOfClass:[TGAttachmentDescriptor class]]) {
            totalSize += descriptor.fileSize;
        }
    }
    NSString *countText = [NSString stringWithFormat:@"%lu file%@", (unsigned long)[descriptors count], ([descriptors count] == 1 ? @"" : @"s")];
    return [NSString stringWithFormat:@"%@ • %@", countText, TGResourcePolicyReadableSize((long long)totalSize)];
}

static NSString *TGAttachmentBatchProgressText(NSUInteger index, NSUInteger count) {
    return [NSString stringWithFormat:@"Sending %lu of %lu...", (unsigned long)index, (unsigned long)count];
}

static NSString *TGAttachmentQueueStateText(TGFileTransferStateKind state) {
    switch (state) {
        case TGFileTransferStatePreparing:
            return @"Ready";
        case TGFileTransferStateSending:
            return @"Sending";
        case TGFileTransferStateSucceeded:
            return @"Sent";
        case TGFileTransferStateFailed:
            return @"Failed";
        case TGFileTransferStateCancelled:
            return @"Cancelled";
    }
    return @"Ready";
}

static NSArray *TGAttachmentQueueItemsFromDescriptors(NSArray *descriptors) {
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count]; index++) {
        id descriptor = [descriptors objectAtIndex:index];
        if ([descriptor isKindOfClass:[TGAttachmentDescriptor class]]) {
            [items addObject:[TGAttachmentQueueItem itemWithDescriptor:(TGAttachmentDescriptor *)descriptor
                                                                 index:index
                                                                 state:TGFileTransferStatePreparing
                                                               message:@"Ready"]];
        }
    }
    return items;
}

static NSArray *TGAttachmentDescriptorsFromQueueItems(NSArray *queueItems, BOOL failedOnly) {
    NSMutableArray *descriptors = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [queueItems count]; index++) {
        id itemObject = [queueItems objectAtIndex:index];
        if (![itemObject isKindOfClass:[TGAttachmentQueueItem class]]) {
            continue;
        }
        TGAttachmentQueueItem *item = (TGAttachmentQueueItem *)itemObject;
        if (failedOnly && ![item isFailed]) {
            continue;
        }
        if ([item.descriptor isKindOfClass:[TGAttachmentDescriptor class]]) {
            [descriptors addObject:item.descriptor];
        }
    }
    return descriptors;
}

static NSUInteger TGAttachmentQueueFailedCount(NSArray *queueItems) {
    NSUInteger failedCount = 0;
    NSUInteger index = 0;
    for (index = 0; index < [queueItems count]; index++) {
        id itemObject = [queueItems objectAtIndex:index];
        if ([itemObject isKindOfClass:[TGAttachmentQueueItem class]] && [(TGAttachmentQueueItem *)itemObject isFailed]) {
            failedCount++;
        }
    }
    return failedCount;
}

static long long TGLocalFailedOutgoingMessageID(void) {
    static long long counter = 0;
    counter--;
    return counter;
}

static BOOL TGAttachmentDescriptorsCanSendAsMediaAlbum(NSArray *descriptors) {
    if ([descriptors count] < 2 || [descriptors count] > 10) {
        return NO;
    }
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count]; index++) {
        id object = [descriptors objectAtIndex:index];
        if (![object isKindOfClass:[TGAttachmentDescriptor class]]) {
            return NO;
        }
        TGAttachmentDescriptor *descriptor = (TGAttachmentDescriptor *)object;
        if (descriptor.kind != TGAttachmentKindPhoto && descriptor.kind != TGAttachmentKindVideo) {
            return NO;
        }
    }
    return YES;
}

static NSArray *TGAttachmentMediaAlbumItemsFromDescriptors(NSArray *descriptors) {
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [descriptors count]; index++) {
        TGAttachmentDescriptor *descriptor = [descriptors objectAtIndex:index];
        NSString *kind = (descriptor.kind == TGAttachmentKindVideo) ? @"video" : @"photo";
        if ([descriptor.path length] > 0) {
            NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         kind, @"kind",
                                         descriptor.path, @"path",
                                         nil];
            if (descriptor.pixelWidth > 0 && descriptor.pixelHeight > 0) {
                [item setObject:[NSNumber numberWithUnsignedInteger:descriptor.pixelWidth] forKey:@"width"];
                [item setObject:[NSNumber numberWithUnsignedInteger:descriptor.pixelHeight] forKey:@"height"];
            }
            [items addObject:item];
        }
    }
    return items;
}

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

    NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(44, 204, 432, 296)] autorelease];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageFrameStyle:NSImageFrameGrayBezel];
    [imageView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:imageView];
    self.photoSendPreviewImageView = imageView;

    NSTextField *metaField = [self labelWithFrame:NSMakeRect(44, 188, 432, 16)
                                             text:@""
                                             font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:metaField];
    [metaField setAlignment:NSCenterTextAlignment];
    [[metaField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [metaField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:metaField];
    self.photoSendMetaField = metaField;

    NSScrollView *queueScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(44, 112, 432, 70)] autorelease];
    [queueScrollView setBorderType:NSBezelBorder];
    [queueScrollView setHasVerticalScroller:YES];
    [queueScrollView setAutohidesScrollers:YES];
    [queueScrollView setDrawsBackground:YES];
    [queueScrollView setBackgroundColor:[NSColor colorWithCalibratedWhite:0.985 alpha:1.0]];
    [queueScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    NSView *queueContentView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 428, 70)] autorelease];
    [queueScrollView setDocumentView:queueContentView];
    [contentView addSubview:queueScrollView];
    self.photoSendQueueScrollView = queueScrollView;
    self.photoSendQueueContentView = queueContentView;

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

- (NSImage *)previewImageForAttachmentDescriptor:(TGAttachmentDescriptor *)descriptor {
    if (descriptor.kind == TGAttachmentKindPhoto) {
        NSImage *image = TGImageWithCorrectOrientationFromFile(descriptor.path);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:descriptor.path] autorelease];
        }
        if (image) {
            return image;
        }
    }

    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:descriptor.path];
    [icon setSize:NSMakeSize(128.0, 128.0)];
    return icon;
}

- (NSImage *)previewImageForAttachmentDescriptors:(NSArray *)descriptors {
    if ([descriptors count] <= 1) {
        return [self previewImageForAttachmentDescriptor:[descriptors count] > 0 ? [descriptors objectAtIndex:0] : nil];
    }

    NSSize canvasSize = NSMakeSize(432.0, 376.0);
    NSImage *canvas = [[[NSImage alloc] initWithSize:canvasSize] autorelease];
    [canvas lockFocus];
    [[NSColor colorWithCalibratedWhite:0.985 alpha:1.0] set];
    NSRectFill(NSMakeRect(0.0, 0.0, canvasSize.width, canvasSize.height));

    TGAttachmentDescriptor *firstDescriptor = [descriptors objectAtIndex:0];
    NSImage *mainImage = [self previewImageForAttachmentDescriptor:firstDescriptor];
    TGDrawAttachmentPreviewImageInRect(mainImage, NSMakeRect(8.0, 112.0, canvasSize.width - 16.0, 256.0));

    NSUInteger visibleCount = MIN([descriptors count], (NSUInteger)4);
    CGFloat thumbGap = 8.0;
    CGFloat thumbWidth = floor((canvasSize.width - 16.0 - (CGFloat)(visibleCount - 1) * thumbGap) / (CGFloat)visibleCount);
    if (thumbWidth > 96.0) {
        thumbWidth = 96.0;
    }
    CGFloat rowWidth = (CGFloat)visibleCount * thumbWidth + (CGFloat)(visibleCount - 1) * thumbGap;
    CGFloat rowX = floor((canvasSize.width - rowWidth) / 2.0);
    NSUInteger index = 0;
    for (index = 0; index < visibleCount; index++) {
        TGAttachmentDescriptor *descriptor = [descriptors objectAtIndex:index];
        NSImage *thumbnail = [self previewImageForAttachmentDescriptor:descriptor];
        NSRect thumbRect = NSMakeRect(rowX + (CGFloat)index * (thumbWidth + thumbGap), 8.0, thumbWidth, 88.0);
        TGDrawAttachmentPreviewImageInRect(thumbnail, thumbRect);
        if (index == visibleCount - 1 && [descriptors count] > visibleCount) {
            NSBezierPath *overlayPath = [NSBezierPath bezierPathWithRoundedRect:thumbRect xRadius:8.0 yRadius:8.0];
            [[NSColor colorWithCalibratedWhite:0.0 alpha:0.34] set];
            [overlayPath fill];
            NSString *remainingText = [NSString stringWithFormat:@"+%lu", (unsigned long)([descriptors count] - visibleCount + 1)];
            NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont boldSystemFontOfSize:22.0], NSFontAttributeName,
                                        [NSColor whiteColor], NSForegroundColorAttributeName,
                                        nil];
            NSSize textSize = [remainingText sizeWithAttributes:attributes];
            [remainingText drawAtPoint:NSMakePoint(NSMidX(thumbRect) - floor(textSize.width / 2.0),
                                                   NSMidY(thumbRect) - floor(textSize.height / 2.0))
                        withAttributes:attributes];
            break;
        }
    }

    [canvas unlockFocus];
    return canvas;
}

- (void)rebuildAttachmentQueueList {
    NSView *queueView = self.photoSendQueueContentView;
    if (!queueView) {
        return;
    }
    NSArray *oldSubviews = [[queueView subviews] copy];
    NSUInteger removeIndex = 0;
    for (removeIndex = 0; removeIndex < [oldSubviews count]; removeIndex++) {
        [[oldSubviews objectAtIndex:removeIndex] removeFromSuperview];
    }
    [oldSubviews release];

    NSArray *queueItems = self.pendingAttachmentQueueItems;
    CGFloat rowHeight = 24.0;
    CGFloat contentHeight = MAX(72.0, (CGFloat)[queueItems count] * rowHeight);
    [queueView setFrame:NSMakeRect(0.0, 0.0, 428.0, contentHeight)];

    NSUInteger index = 0;
    for (index = 0; index < [queueItems count]; index++) {
        id itemObject = [queueItems objectAtIndex:index];
        if (![itemObject isKindOfClass:[TGAttachmentQueueItem class]]) {
            continue;
        }
        TGAttachmentQueueItem *item = (TGAttachmentQueueItem *)itemObject;
        TGAttachmentDescriptor *descriptor = item.descriptor;
        CGFloat y = contentHeight - rowHeight - (CGFloat)index * rowHeight;

        NSTextField *nameField = [self labelWithFrame:NSMakeRect(8.0, y + 4.0, 238.0, 16.0)
                                                 text:([descriptor.fileName length] > 0 ? descriptor.fileName : @"File")
                                                 font:[NSFont systemFontOfSize:11.0]];
        [[nameField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
        [queueView addSubview:nameField];

        NSTextField *stateField = [self labelWithFrame:NSMakeRect(252.0, y + 4.0, 86.0, 16.0)
                                                  text:TGAttachmentQueueStateText(item.transferState.state)
                                                  font:[NSFont boldSystemFontOfSize:11.0]];
        if (item.transferState.state == TGFileTransferStateFailed) {
            [stateField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
        } else if (item.transferState.state == TGFileTransferStateSucceeded) {
            [stateField setTextColor:[NSColor colorWithCalibratedRed:0.130 green:0.520 blue:0.250 alpha:1.0]];
        } else {
            [self applyMutedLabelStyle:stateField];
        }
        [queueView addSubview:stateField];

        NSTextField *sizeField = [self labelWithFrame:NSMakeRect(342.0, y + 4.0, 76.0, 16.0)
                                                 text:[descriptor readableSize]
                                                 font:[NSFont systemFontOfSize:11.0]];
        [self applyMutedLabelStyle:sizeField];
        [sizeField setAlignment:NSRightTextAlignment];
        [queueView addSubview:sizeField];
    }
    [queueView setNeedsDisplay:YES];
}

- (void)setAttachmentQueueItemAtIndex:(NSUInteger)index state:(TGFileTransferStateKind)state message:(NSString *)message {
    if (index >= [self.pendingAttachmentQueueItems count]) {
        return;
    }
    id itemObject = [self.pendingAttachmentQueueItems objectAtIndex:index];
    if (![itemObject isKindOfClass:[TGAttachmentQueueItem class]]) {
        return;
    }
    TGAttachmentQueueItem *item = (TGAttachmentQueueItem *)itemObject;
    item.transferState = [TGFileTransferState stateWithState:state
                                               progressKnown:(state == TGFileTransferStateSucceeded)
                                                    progress:(state == TGFileTransferStateSucceeded ? 1.0 : 0.0)
                                                     message:message];
    [self rebuildAttachmentQueueList];
}

- (void)resetAttachmentQueueItemsForDescriptors:(NSArray *)descriptors {
    self.pendingAttachmentQueueItems = TGAttachmentQueueItemsFromDescriptors(descriptors);
    [self rebuildAttachmentQueueList];
}

- (void)presentAttachmentPreviewForDescriptors:(NSArray *)descriptors {
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before sending a file."];
        return;
    }
    if (self.controlsBusy) {
        [self appendDetail:@"Wait for the current Telegram operation to finish before sending a file."];
        return;
    }
    NSMutableArray *safeDescriptors = [NSMutableArray array];
    NSUInteger sourceIndex = 0;
    for (sourceIndex = 0; sourceIndex < [descriptors count] && [safeDescriptors count] < 10; sourceIndex++) {
        id candidate = [descriptors objectAtIndex:sourceIndex];
        if ([candidate isKindOfClass:[TGAttachmentDescriptor class]] && [(TGAttachmentDescriptor *)candidate isSupported]) {
            [safeDescriptors addObject:candidate];
        }
    }
    TGAttachmentDescriptor *descriptor = [safeDescriptors count] > 0 ? [safeDescriptors objectAtIndex:0] : nil;
    if (![descriptor isKindOfClass:[TGAttachmentDescriptor class]] || ![descriptor isSupported]) {
        [self appendDetail:@"This file is not supported."];
        return;
    }
    BOOL hasLargeDescriptor = NO;
    NSUInteger descriptorIndex = 0;
    for (descriptorIndex = 0; descriptorIndex < [safeDescriptors count]; descriptorIndex++) {
        if ([[safeDescriptors objectAtIndex:descriptorIndex] isLarge]) {
            hasLargeDescriptor = YES;
            break;
        }
    }
    if (hasLargeDescriptor) {
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert setMessageText:([safeDescriptors count] > 1 ? @"Send large files?" : @"Send large file?")];
        [alert setInformativeText:([safeDescriptors count] > 1 ? [NSString stringWithFormat:@"%@. Sending may take a while.", TGSummarizeAttachmentDescriptors(safeDescriptors)] : [NSString stringWithFormat:@"%@ is %@. Sending may take a while.", descriptor.fileName, [descriptor readableSize]])];
        [alert addButtonWithTitle:TGLoc(@"send")];
        [alert addButtonWithTitle:TGLoc(@"cancel")];
        if ([alert runModal] != NSAlertFirstButtonReturn) {
            return;
        }
    }

    [self ensurePhotoSendPreviewWindow];
    self.pendingAttachmentDescriptor = descriptor;
    self.pendingAttachmentDescriptors = safeDescriptors;
    self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStatePreparing progressKnown:NO progress:0.0 message:@"Ready to send"];
    self.pendingAttachmentCancelRequested = NO;
    self.pendingPhotoSendPath = descriptor.path;
    self.pendingPhotoSendChatID = self.selectedChatID;
    self.pendingPhotoSendThreadID = self.selectedMessageThreadID;
    self.pendingPhotoSendTopicKind = self.selectedMessageTopicKind;
    [self.photoSendPreviewWindow setTitle:([safeDescriptors count] > 1 ? @"Send media" : [NSString stringWithFormat:@"Send %@", [descriptor.typeLabel lowercaseString]])];
    [self.photoSendTitleField setStringValue:[NSString stringWithFormat:@"%lu media", (unsigned long)[safeDescriptors count]]];
    [self.photoSendPreviewImageView setImage:[self previewImageForAttachmentDescriptors:safeDescriptors]];
    [self.photoSendMetaField setStringValue:([safeDescriptors count] > 1 ? TGSummarizeAttachmentDescriptors(safeDescriptors) : [descriptor summary])];
    [self.photoSendCaptionField setStringValue:@""];
    [[self.photoSendCaptionField cell] setPlaceholderString:TGLoc(@"caption.placeholder")];
    [self.photoSendErrorField setStringValue:@""];
    [self.photoSendErrorField setHidden:YES];
    [self.photoSendSendButton setTitle:TGLoc(@"send")];
    [self.photoSendSendButton setEnabled:YES];
    [self resetAttachmentQueueItemsForDescriptors:safeDescriptors];
    [self.photoSendPreviewWindow center];
    [self.photoSendPreviewWindow makeKeyAndOrderFront:nil];
    [[self.photoSendPreviewWindow contentView] setNeedsDisplay:YES];
}

- (void)presentAttachmentPreviewForDescriptor:(TGAttachmentDescriptor *)descriptor {
    if (![descriptor isKindOfClass:[TGAttachmentDescriptor class]]) {
        [self presentAttachmentPreviewForDescriptors:[NSArray array]];
        return;
    }
    [self presentAttachmentPreviewForDescriptors:[NSArray arrayWithObject:descriptor]];
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
    TGAttachmentDescriptor *descriptor = [TGAttachmentDescriptor descriptorForPath:path];
    if (descriptor.kind != TGAttachmentKindPhoto) {
        [self appendDetail:@"Photo send supports local JPG, PNG, TIFF, GIF, and WebP files."];
        return;
    }
    [self presentAttachmentPreviewForDescriptor:descriptor];
}

- (void)cancelPendingPhotoSend:(id)sender {
    (void)sender;
    if (self.controlsBusy && self.photoSendPreviewWindow && [self.photoSendPreviewWindow isVisible]) {
        self.pendingAttachmentCancelRequested = YES;
        [self.photoSendErrorField setStringValue:@"Cancelling after the current file..."];
        [self.photoSendErrorField setHidden:NO];
        [self appendDetail:@"Attachment queue: cancellation requested."];
        return;
    }
    self.pendingPhotoSendPath = nil;
    self.pendingAttachmentDescriptor = nil;
    self.pendingAttachmentDescriptors = nil;
    self.pendingAttachmentTransferState = nil;
    self.pendingAttachmentQueueItems = nil;
    self.pendingAttachmentCancelRequested = NO;
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
    NSNumber *replyToMessageID = [[self composerReplyToMessageIDForChatID:chatID] retain];
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
	                                                replyToMessageID:replyToMessageID
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
                self.pendingAttachmentDescriptor = nil;
                self.pendingAttachmentDescriptors = nil;
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
                    if (replyToMessageID) {
                        [self clearReplyTarget];
                    }
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
            [replyToMessageID release];
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

- (NSNumber *)composerReplyToMessageIDForChatID:(NSNumber *)chatID {
    if (self.replyTargetMessageItem &&
        [self.replyTargetChatID respondsToSelector:@selector(longLongValue)] &&
        [chatID respondsToSelector:@selector(longLongValue)] &&
        [self.replyTargetChatID longLongValue] == [chatID longLongValue] &&
        [[self.replyTargetMessageItem messageID] respondsToSelector:@selector(longLongValue)] &&
        [[self.replyTargetMessageItem messageID] longLongValue] > 0) {
        return [self.replyTargetMessageItem messageID];
    }
    return nil;
}

- (void)submitAttachmentDescriptor:(TGAttachmentDescriptor *)descriptor caption:(NSString *)caption chatID:(NSNumber *)targetChatID messageThreadID:(NSNumber *)targetThreadID messageTopicKind:(NSString *)targetTopicKind {
    if (![descriptor isKindOfClass:[TGAttachmentDescriptor class]] || ![targetChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    if (descriptor.kind == TGAttachmentKindPhoto) {
        [self submitPhotoAtPath:descriptor.path caption:caption chatID:targetChatID messageThreadID:targetThreadID messageTopicKind:targetTopicKind];
        return;
    }

    TGAttachmentDescriptor *descriptorCopy = [descriptor retain];
    NSNumber *chatID = [targetChatID retain];
    NSNumber *messageThreadID = [targetThreadID retain];
    NSString *messageTopicKind = [targetTopicKind copy];
    NSString *safeCaption = [caption isKindOfClass:[NSString class]] ? caption : @"";
    NSString *attachmentCaption = [safeCaption copy];
    NSNumber *replyToMessageID = [[self composerReplyToMessageIDForChatID:chatID] retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:[NSString stringWithFormat:@"Sending %@...", [descriptorCopy.typeLabel lowercaseString]]];
    self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStateSending progressKnown:NO progress:0.0 message:@"Sending"];
    [self setAttachmentQueueItemAtIndex:0 state:TGFileTransferStateSending message:@"Sending"];
    [self appendDetail:[NSString stringWithFormat:@"Submitting %@ to TDLib: %@", [descriptorCopy.typeLabel lowercaseString], descriptorCopy.fileName]];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSString *summary = nil;
        if (descriptorCopy.kind == TGAttachmentKindVideo) {
            summary = [[client sendVideoMessageToChatID:chatID
                                        messageThreadID:messageThreadID
                                       messageTopicKind:messageTopicKind
	                                              localPath:descriptorCopy.path
	                                                caption:attachmentCaption
	                                       replyToMessageID:replyToMessageID
	                                                timeout:24.0
	                                                  error:&sendError] copy];
        } else if (descriptorCopy.kind == TGAttachmentKindAudio) {
            summary = [[client sendAudioMessageToChatID:chatID
                                        messageThreadID:messageThreadID
                                       messageTopicKind:messageTopicKind
	                                              localPath:descriptorCopy.path
	                                                caption:attachmentCaption
	                                       replyToMessageID:replyToMessageID
	                                                timeout:24.0
	                                                  error:&sendError] copy];
        } else {
            summary = [[client sendDocumentMessageToChatID:chatID
                                           messageThreadID:messageThreadID
                                          messageTopicKind:messageTopicKind
	                                                 localPath:descriptorCopy.path
	                                                   caption:attachmentCaption
	                                          replyToMessageID:replyToMessageID
	                                                   timeout:24.0
	                                                     error:&sendError] copy];
        }
        NSString *errorMessage = [[sendError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if ([summary length] > 0) {
                self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStateSucceeded progressKnown:NO progress:1.0 message:@"Sent"];
                [self setAttachmentQueueItemAtIndex:0 state:TGFileTransferStateSucceeded message:@"Sent"];
                [self.statusField setStringValue:@"File sent"];
                [self appendDetail:@"TDLib send: file message accepted by TDLib."];
                self.pendingPhotoSendPath = nil;
                self.pendingAttachmentDescriptor = nil;
                self.pendingAttachmentDescriptors = nil;
                self.pendingAttachmentTransferState = nil;
                self.pendingAttachmentQueueItems = nil;
                self.pendingAttachmentCancelRequested = NO;
                self.pendingPhotoSendChatID = nil;
                self.pendingPhotoSendThreadID = nil;
                self.pendingPhotoSendTopicKind = nil;
                [self.photoSendPreviewWindow orderOut:nil];
                [self.photoSendSendButton setTitle:TGLoc(@"send")];
                [self.photoSendSendButton setEnabled:YES];
                [self.photoSendErrorField setStringValue:@""];
                [self.photoSendErrorField setHidden:YES];
                if (selectionStillCurrent) {
                    if (replyToMessageID) {
                        [self clearReplyTarget];
                    }
                    self.forceMessageScrollToNewest = YES;
                    self.pendingLiveChatRefresh = YES;
                    self.pendingLiveMessageRefresh = YES;
                    [self handlePendingLiveRefreshesIfPossible];
                    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                             selector:@selector(refreshSelectedMessagesAfterMediaSend)
                                                               object:nil];
                    [self performSelector:@selector(refreshSelectedMessagesAfterMediaSend) withObject:nil afterDelay:1.25];
                }
            } else {
                NSString *message = ([errorMessage length] > 0) ? errorMessage : @"File send was not confirmed.";
                self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStateFailed progressKnown:NO progress:0.0 message:message];
                [self setAttachmentQueueItemAtIndex:0 state:TGFileTransferStateFailed message:message];
                [self.statusField setStringValue:@"File send failed"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib send: %@", message]];
                if (self.photoSendPreviewWindow && [self.photoSendPreviewWindow isVisible]) {
                    [self.photoSendSendButton setTitle:@"Retry failed"];
                    [self.photoSendSendButton setEnabled:YES];
                    [self.photoSendErrorField setStringValue:message];
                    [self.photoSendErrorField setHidden:NO];
                }
            }
            [self setControlsBusy:NO];
            [self requestComposerRefocus];
            [summary release];
            [errorMessage release];
            [descriptorCopy release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [attachmentCaption release];
            [replyToMessageID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)submitAttachmentDescriptors:(NSArray *)descriptors caption:(NSString *)caption chatID:(NSNumber *)targetChatID messageThreadID:(NSNumber *)targetThreadID messageTopicKind:(NSString *)targetTopicKind {
    if ([descriptors count] == 0 || ![targetChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    NSArray *descriptorCopies = [descriptors retain];
    NSNumber *chatID = [targetChatID retain];
    NSNumber *messageThreadID = [targetThreadID retain];
    NSString *messageTopicKind = [targetTopicKind copy];
    NSString *safeCaption = [caption isKindOfClass:[NSString class]] ? caption : @"";
    NSString *firstCaption = [safeCaption copy];
    NSNumber *replyToMessageID = [[self composerReplyToMessageIDForChatID:chatID] retain];
    BOOL sendAsAlbum = TGAttachmentDescriptorsCanSendAsMediaAlbum(descriptorCopies);
    self.pendingAttachmentCancelRequested = NO;
    [self resetAttachmentQueueItemsForDescriptors:descriptorCopies];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Composer: sending %lu attachment(s); mediaAlbum=%@.",
                                  (unsigned long)[descriptorCopies count],
                                  sendAsAlbum ? @"yes" : @"no"]];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:(sendAsAlbum ? @"Sending media album..." : TGAttachmentBatchProgressText(1, [descriptorCopies count]))];
    self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStateSending progressKnown:NO progress:0.0 message:@"Sending"];
    [self appendDetail:[NSString stringWithFormat:@"Submitting %lu attachment(s) to TDLib%@...",
                        (unsigned long)[descriptorCopies count],
                        sendAsAlbum ? @" as a media album" : @""]];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *firstErrorMessage = nil;
        NSUInteger sentCount = 0;
        BOOL cancelled = NO;
        if (sendAsAlbum) {
            NSError *sendError = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSUInteger albumIndex = 0;
                for (albumIndex = 0; albumIndex < [descriptorCopies count]; albumIndex++) {
                    [self setAttachmentQueueItemAtIndex:albumIndex state:TGFileTransferStateSending message:@"Sending album"];
                }
            });
            NSArray *albumItems = TGAttachmentMediaAlbumItemsFromDescriptors(descriptorCopies);
            NSString *summary = [[client sendMediaAlbumToChatID:chatID
                                                messageThreadID:messageThreadID
                                               messageTopicKind:messageTopicKind
	                                                localMediaItems:albumItems
	                                                        caption:firstCaption
	                                               replyToMessageID:replyToMessageID
	                                                        timeout:24.0
	                                                          error:&sendError] copy];
            if ([summary length] > 0) {
                sentCount = [descriptorCopies count];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUInteger albumIndex = 0;
                    for (albumIndex = 0; albumIndex < [descriptorCopies count]; albumIndex++) {
                        [self setAttachmentQueueItemAtIndex:albumIndex state:TGFileTransferStateSucceeded message:@"Sent"];
                    }
                });
            } else {
                NSString *rawErrorMessage = ([[sendError localizedDescription] length] > 0 ? [sendError localizedDescription] : @"Media album send was not confirmed.");
                firstErrorMessage = [rawErrorMessage copy];
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSUInteger albumIndex = 0;
                    for (albumIndex = 0; albumIndex < [descriptorCopies count]; albumIndex++) {
                        [self setAttachmentQueueItemAtIndex:albumIndex state:TGFileTransferStateFailed message:firstErrorMessage];
                    }
                });
            }
            [summary release];
        } else {
            NSUInteger index = 0;
            for (index = 0; index < [descriptorCopies count]; index++) {
                if (self.pendingAttachmentCancelRequested) {
                    cancelled = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSUInteger cancelIndex = index;
                        for (cancelIndex = index; cancelIndex < [descriptorCopies count]; cancelIndex++) {
                            [self setAttachmentQueueItemAtIndex:cancelIndex state:TGFileTransferStateCancelled message:@"Cancelled"];
                        }
                    });
                    break;
                }
                TGAttachmentDescriptor *descriptor = [descriptorCopies objectAtIndex:index];
                NSString *captionForMessage = (index == 0) ? firstCaption : @"";
                NSError *sendError = nil;
                NSString *summary = nil;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self setAttachmentQueueItemAtIndex:index state:TGFileTransferStateSending message:@"Sending"];
                    [self.statusField setStringValue:TGAttachmentBatchProgressText(index + 1, [descriptorCopies count])];
                });
                if (descriptor.kind == TGAttachmentKindPhoto) {
                    summary = [[client sendPhotoMessageToChatID:chatID
                                                messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
	                                                      localPath:descriptor.path
	                                                        caption:captionForMessage
	                                               replyToMessageID:(index == 0 ? replyToMessageID : nil)
	                                                        timeout:18.0
	                                                          error:&sendError] copy];
                } else if (descriptor.kind == TGAttachmentKindVideo) {
                    summary = [[client sendVideoMessageToChatID:chatID
                                               messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
	                                                     localPath:descriptor.path
	                                                       caption:captionForMessage
	                                              replyToMessageID:(index == 0 ? replyToMessageID : nil)
	                                                       timeout:24.0
	                                                         error:&sendError] copy];
                } else if (descriptor.kind == TGAttachmentKindAudio) {
                    summary = [[client sendAudioMessageToChatID:chatID
                                               messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
	                                                     localPath:descriptor.path
	                                                       caption:captionForMessage
	                                              replyToMessageID:(index == 0 ? replyToMessageID : nil)
	                                                       timeout:24.0
	                                                         error:&sendError] copy];
                } else {
                    summary = [[client sendDocumentMessageToChatID:chatID
                                                  messageThreadID:messageThreadID
                                                 messageTopicKind:messageTopicKind
	                                                        localPath:descriptor.path
	                                                          caption:captionForMessage
	                                                 replyToMessageID:(index == 0 ? replyToMessageID : nil)
	                                                          timeout:24.0
	                                                            error:&sendError] copy];
                }
                if ([summary length] > 0) {
                    sentCount++;
                    [summary release];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setAttachmentQueueItemAtIndex:index state:TGFileTransferStateSucceeded message:@"Sent"];
                    });
                } else {
                    NSString *rawErrorMessage = ([[sendError localizedDescription] length] > 0 ? [sendError localizedDescription] : @"Attachment send was not confirmed.");
                    firstErrorMessage = [rawErrorMessage copy];
                    [summary release];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setAttachmentQueueItemAtIndex:index state:TGFileTransferStateFailed message:firstErrorMessage];
                    });
                    break;
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if (sentCount == [descriptorCopies count]) {
                self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:TGFileTransferStateSucceeded progressKnown:NO progress:1.0 message:@"Sent"];
                [self.statusField setStringValue:(sendAsAlbum ? @"Media album sent" : @"Media sent")];
                [self appendDetail:[NSString stringWithFormat:@"TDLib send: %lu attachment(s) accepted by TDLib%@.",
                                    (unsigned long)sentCount,
                                    sendAsAlbum ? @" as an album" : @""]];
                self.pendingPhotoSendPath = nil;
                self.pendingAttachmentDescriptor = nil;
                self.pendingAttachmentDescriptors = nil;
                self.pendingAttachmentTransferState = nil;
                self.pendingAttachmentQueueItems = nil;
                self.pendingAttachmentCancelRequested = NO;
                self.pendingPhotoSendChatID = nil;
                self.pendingPhotoSendThreadID = nil;
                self.pendingPhotoSendTopicKind = nil;
                [self.photoSendPreviewWindow orderOut:nil];
                [self.photoSendSendButton setTitle:TGLoc(@"send")];
                [self.photoSendSendButton setEnabled:YES];
                [self.photoSendErrorField setStringValue:@""];
                [self.photoSendErrorField setHidden:YES];
                if (selectionStillCurrent) {
                    if (replyToMessageID) {
                        [self clearReplyTarget];
                    }
                    self.forceMessageScrollToNewest = YES;
                    self.pendingLiveChatRefresh = YES;
                    self.pendingLiveMessageRefresh = YES;
                    [self handlePendingLiveRefreshesIfPossible];
                    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                             selector:@selector(refreshSelectedMessagesAfterMediaSend)
                                                               object:nil];
                    [self performSelector:@selector(refreshSelectedMessagesAfterMediaSend) withObject:nil afterDelay:1.25];
                }
            } else {
                NSString *message = cancelled ? @"Attachment queue cancelled." : (([firstErrorMessage length] > 0) ? firstErrorMessage : @"Attachment send was not confirmed.");
                self.pendingAttachmentTransferState = [TGFileTransferState stateWithState:(cancelled ? TGFileTransferStateCancelled : TGFileTransferStateFailed) progressKnown:NO progress:0.0 message:message];
                [self.statusField setStringValue:(cancelled ? @"Media send cancelled" : @"Media send failed")];
                [self appendDetail:[NSString stringWithFormat:@"TDLib send: sent %lu of %lu; %@", (unsigned long)sentCount, (unsigned long)[descriptorCopies count], message]];
                NSUInteger failedCount = TGAttachmentQueueFailedCount(self.pendingAttachmentQueueItems);
                [self.photoSendSendButton setTitle:(failedCount > 0 ? @"Retry failed" : TGLoc(@"send"))];
                [self.photoSendSendButton setEnabled:(failedCount > 0)];
                [self.photoSendErrorField setStringValue:message];
                [self.photoSendErrorField setHidden:NO];
            }
            [self setControlsBusy:NO];
            [self requestComposerRefocus];
            [firstErrorMessage release];
            [descriptorCopies release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [firstCaption release];
            [replyToMessageID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)sendPendingPhotoPreview:(id)sender {
    (void)sender;
    NSString *path = [self.pendingPhotoSendPath copy];
    NSString *caption = [[self.photoSendCaptionField stringValue] copy];
    NSNumber *chatID = [self.pendingPhotoSendChatID retain];
    NSNumber *threadID = [self.pendingPhotoSendThreadID retain];
    NSString *topicKind = [self.pendingPhotoSendTopicKind copy];
    TGAttachmentDescriptor *descriptor = [self.pendingAttachmentDescriptor retain];
    NSArray *descriptors = [self.pendingAttachmentDescriptors retain];
    NSArray *queueItems = [self.pendingAttachmentQueueItems retain];
    BOOL retryingFailedDescriptors = NO;
    if (TGAttachmentQueueFailedCount(queueItems) > 0) {
        NSArray *failedDescriptors = TGAttachmentDescriptorsFromQueueItems(queueItems, YES);
        if ([failedDescriptors count] > 0) {
            [descriptors release];
            descriptors = [failedDescriptors retain];
            retryingFailedDescriptors = YES;
            if ([descriptors count] > 0) {
                [descriptor release];
                descriptor = [[descriptors objectAtIndex:0] retain];
            }
        }
    }
    NSString *effectivePath = [path length] > 0 ? path : [descriptor path];
    if (![effectivePath length] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        [self.photoSendErrorField setStringValue:@"Attachment target is no longer available."];
        [self.photoSendErrorField setHidden:NO];
    } else {
        [self.photoSendErrorField setStringValue:@""];
        [self.photoSendErrorField setHidden:YES];
        [self.photoSendSendButton setTitle:TGLoc(@"sending")];
        [self.photoSendSendButton setEnabled:NO];
        if (retryingFailedDescriptors) {
            [self resetAttachmentQueueItemsForDescriptors:descriptors];
            self.pendingAttachmentDescriptors = descriptors;
            self.pendingAttachmentDescriptor = descriptor;
        }
        if ([descriptors count] > 1) {
            [self submitAttachmentDescriptors:descriptors caption:caption chatID:chatID messageThreadID:threadID messageTopicKind:topicKind];
        } else if ([descriptor isKindOfClass:[TGAttachmentDescriptor class]]) {
            [self submitAttachmentDescriptor:descriptor caption:caption chatID:chatID messageThreadID:threadID messageTopicKind:topicKind];
        } else {
            [self submitPhotoAtPath:effectivePath caption:caption chatID:chatID messageThreadID:threadID messageTopicKind:topicKind];
        }
    }
    [path release];
    [caption release];
    [chatID release];
    [threadID release];
    [topicKind release];
    [descriptor release];
    [descriptors release];
    [queueItems release];
}

- (void)ensureStickerPickerWindow {
    if (self.stickerPickerWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 560, 500);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:TGLoc(@"stickers")];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    NSView *contentView = [[[TGStickerPickerBackgroundView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    NSTextField *statusField = [self labelWithFrame:NSMakeRect(20, 466, 134, 18)
                                               text:TGLoc(@"stickers.recent")
                                               font:[NSFont systemFontOfSize:12.0]];
    [self applyMutedLabelStyle:statusField];
    [contentView addSubview:statusField];
    self.stickerPickerStatusField = statusField;

    NSButton *recentButton = [[[NSButton alloc] initWithFrame:NSMakeRect(166, 458, 116, 30)] autorelease];
    [recentButton setCell:[[[TGStickerPickerTabButtonCell alloc] initTextCell:TGLoc(@"stickers.recent.tab")] autorelease]];
    [recentButton setTitle:TGLoc(@"stickers.recent.tab")];
    [recentButton setImage:TGTemplateIconAssetImage(@"history", NSMakeSize(14.0, 14.0), TGClassicHeaderTextColor(0.96), 1.0)];
    [recentButton setImagePosition:NSImageLeft];
    [recentButton setBordered:NO];
    [recentButton setFocusRingType:NSFocusRingTypeNone];
    [recentButton setTarget:self];
    [recentButton setAction:@selector(selectRecentStickerPickerTab:)];
    [recentButton setToolTip:TGLoc(@"stickers.recent.tab")];
    [contentView addSubview:recentButton];
    self.stickerPickerRecentButton = recentButton;

    NSButton *favoriteButton = [[[NSButton alloc] initWithFrame:NSMakeRect(292, 458, 124, 30)] autorelease];
    [favoriteButton setCell:[[[TGStickerPickerTabButtonCell alloc] initTextCell:TGLoc(@"stickers.favorites.tab")] autorelease]];
    [favoriteButton setTitle:TGLoc(@"stickers.favorites.tab")];
    [favoriteButton setImage:TGTemplateIconAssetImage(@"heart", NSMakeSize(14.0, 14.0), TGClassicHeaderTextColor(0.96), 1.0)];
    [favoriteButton setImagePosition:NSImageLeft];
    [favoriteButton setBordered:NO];
    [favoriteButton setFocusRingType:NSFocusRingTypeNone];
    [favoriteButton setTarget:self];
    [favoriteButton setAction:@selector(selectFavoriteStickerPickerTab:)];
    [favoriteButton setToolTip:TGLoc(@"stickers.favorites.tab")];
    [contentView addSubview:favoriteButton];
    self.stickerPickerFavoriteButton = favoriteButton;

    TGComposerInputBackgroundView *stickerSearchBackground = [[[TGComposerInputBackgroundView alloc] initWithFrame:NSMakeRect(20, 428, 410, 28)] autorelease];
    [contentView addSubview:stickerSearchBackground];

    NSSearchField *searchField = [[[NSSearchField alloc] initWithFrame:NSMakeRect(30, 434, 390, 18)] autorelease];
    [self applyComposerTextFieldStyle:searchField];
    if ([[searchField cell] respondsToSelector:@selector(setSearchButtonCell:)]) {
        [[searchField cell] setSearchButtonCell:nil];
    }
    if ([[searchField cell] respondsToSelector:@selector(setCancelButtonCell:)]) {
        [[searchField cell] setCancelButtonCell:nil];
    }
    [[searchField cell] setPlaceholderString:TGLoc(@"stickers.search.placeholder")];
    [self applyComposerPlaceholderStyle:searchField];
    [searchField setTarget:self];
    [searchField setAction:@selector(searchStickerPickerByEmoji:)];
    [contentView addSubview:searchField];
    self.stickerPickerSearchField = searchField;

    NSButton *removeSetButton = [[[NSButton alloc] initWithFrame:NSMakeRect(448, 427, 44, 30)] autorelease];
    [removeSetButton setCell:[[[TGStickerPickerTabButtonCell alloc] initTextCell:@""] autorelease]];
    [removeSetButton setTitle:@""];
    [removeSetButton setImage:TGTemplateIconAssetImage(@"folder-remove", NSMakeSize(17.0, 17.0), TGClassicHeaderTextColor(0.96), 1.0)];
    [removeSetButton setImagePosition:NSImageOnly];
    [removeSetButton setBordered:NO];
    [removeSetButton setFocusRingType:NSFocusRingTypeNone];
    [removeSetButton setTarget:self];
    [removeSetButton setAction:@selector(removeSelectedStickerSetFromPicker:)];
    [removeSetButton setToolTip:TGLoc(@"stickers.removeSet")];
    [contentView addSubview:removeSetButton];

    TGStickerPickerPanelView *railPanel = [[[TGStickerPickerPanelView alloc] initWithFrame:NSMakeRect(12, 352, 536, 66)] autorelease];
    [railPanel setAutoresizingMask:NSViewWidthSizable];
    [contentView addSubview:railPanel];

    NSScrollView *setScrollView = [[[TGStickerSetRailScrollView alloc] initWithFrame:NSMakeRect(20, 360, 520, 50)] autorelease];
    [setScrollView setBorderType:NSNoBorder];
    [setScrollView setDrawsBackground:NO];
    [setScrollView setHasVerticalScroller:NO];
    [setScrollView setHasHorizontalScroller:NO];
    [setScrollView setAutohidesScrollers:YES];
    [setScrollView setAutoresizingMask:NSViewWidthSizable];
    NSView *setContentView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 514, 50)] autorelease];
    [setScrollView setDocumentView:setContentView];
    [contentView addSubview:setScrollView];
    self.stickerPickerSetScrollView = setScrollView;
    self.stickerPickerSetContentView = setContentView;

    TGStickerPickerPanelView *gridPanel = [[[TGStickerPickerPanelView alloc] initWithFrame:NSMakeRect(12, 14, 536, 330)] autorelease];
    [gridPanel setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:gridPanel];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 22, 520, 314)] autorelease];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setDrawsBackground:NO];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    NSView *gridView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 500, 314)] autorelease];
    [scrollView setDocumentView:gridView];
    [[scrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stickerPickerScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[scrollView contentView]];
    [contentView addSubview:scrollView];
    self.stickerPickerScrollView = scrollView;
    self.stickerPickerContentView = gridView;
    self.stickerPickerPlaybackCoordinator = nil;
    self.stickerPickerSetCache = [NSMutableDictionary dictionary];
    self.stickerPickerRailPreviewState = [NSMutableDictionary dictionary];
    self.stickerPickerWindow = window;
}

- (void)updateStickerPickerRailThumbnailForSetID:(NSNumber *)setID withItem:(NSDictionary *)item {
    if (![setID respondsToSelector:@selector(longLongValue)] || ![item isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSMutableArray *updatedSets = [NSMutableArray arrayWithCapacity:[self.stickerPickerStickerSets count]];
    BOOL changed = NO;
    NSUInteger index = 0;
    for (index = 0; index < [self.stickerPickerStickerSets count]; index++) {
        id candidate = [self.stickerPickerStickerSets objectAtIndex:index];
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            [updatedSets addObject:candidate];
            continue;
        }
        NSDictionary *set = (NSDictionary *)candidate;
        NSNumber *candidateID = [set objectForKey:@"id"];
        if ([candidateID respondsToSelector:@selector(longLongValue)] && [candidateID longLongValue] == [setID longLongValue]) {
            NSMutableDictionary *mutableSet = [NSMutableDictionary dictionaryWithDictionary:set];
            [mutableSet setObject:item forKey:@"rail_item"];
            [updatedSets addObject:mutableSet];
            changed = YES;
        } else {
            [updatedSets addObject:set];
        }
    }
    if (changed) {
        [self.stickerPickerRailPreviewState setObject:@"done" forKey:[setID stringValue]];
        self.stickerPickerStickerSets = updatedSets;
        [self rebuildStickerPickerSetRail];
    }
}

- (BOOL)stickerPickerItemHasRenderableRailPreview:(NSDictionary *)item {
    if (![item isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *localPath = TGMediaItemLocalPath(item);
    if ([localPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        NSImage *image = TGImageWithCorrectOrientationFromFile(localPath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:localPath] autorelease];
        }
        if (image) {
            return YES;
        }
    }
    NSData *miniThumbnailData = TGMediaItemMiniThumbnailData(item);
    if ([miniThumbnailData length] > 0) {
        NSImage *image = [[[NSImage alloc] initWithData:miniThumbnailData] autorelease];
        return (image != nil);
    }
    return NO;
}

- (NSDictionary *)stickerPickerRenderableRailItemFromItem:(NSDictionary *)item client:(TGTDLibClient *)client {
    if (![item isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    if ([self stickerPickerItemHasRenderableRailPreview:item]) {
        return item;
    }
    NSNumber *fileID = TGMediaItemFullFileID(item);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0 || !client) {
        return nil;
    }
    NSError *downloadError = nil;
    NSString *downloadedPath = [client downloadedLocalPathForFileID:fileID timeout:6.0 error:&downloadError];
    if ([downloadedPath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:downloadedPath]) {
        return nil;
    }
    NSMutableDictionary *renderableItem = [NSMutableDictionary dictionaryWithDictionary:item];
    [renderableItem setObject:downloadedPath forKey:@"local_path"];
    if ([[renderableItem objectForKey:@"full_local_path"] length] == 0) {
        [renderableItem setObject:downloadedPath forKey:@"full_local_path"];
    }
    return renderableItem;
}

- (BOOL)stickerPickerSetNeedsRailPreview:(NSDictionary *)setInfo {
    if (![setInfo isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSDictionary *railItem = [[setInfo objectForKey:@"rail_item"] isKindOfClass:[NSDictionary class]] ? [setInfo objectForKey:@"rail_item"] : nil;
    if ([self stickerPickerItemHasRenderableRailPreview:railItem]) {
        return NO;
    }
    NSDictionary *thumbnail = [[setInfo objectForKey:@"thumbnail"] isKindOfClass:[NSDictionary class]] ? [setInfo objectForKey:@"thumbnail"] : nil;
    if ([self stickerPickerItemHasRenderableRailPreview:thumbnail]) {
        return NO;
    }
    NSNumber *setID = [setInfo objectForKey:@"id"];
    if (![setID respondsToSelector:@selector(longLongValue)] || [setID longLongValue] == 0LL) {
        return NO;
    }
    NSString *key = [setID stringValue];
    NSString *state = [self.stickerPickerRailPreviewState objectForKey:key];
    return !([state isEqualToString:@"loading"] || [state isEqualToString:@"done"]);
}

- (void)preloadStickerPickerRailPreviews {
    if ([self.stickerPickerStickerSets count] == 0 || !self.client) {
        return;
    }
    TGTDLibClient *client = [self.client retain];
    NSArray *setsSnapshot = [self.stickerPickerStickerSets copy];
    NSMutableArray *setIDsToLoad = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [setsSnapshot count]; index++) {
        NSDictionary *setInfo = [[setsSnapshot objectAtIndex:index] isKindOfClass:[NSDictionary class]] ? [setsSnapshot objectAtIndex:index] : nil;
        if (![self stickerPickerSetNeedsRailPreview:setInfo]) {
            continue;
        }
        NSNumber *setID = [setInfo objectForKey:@"id"];
        NSString *key = [setID stringValue];
        [self.stickerPickerRailPreviewState setObject:@"loading" forKey:key];
        [setIDsToLoad addObject:setID];
    }
    if ([setIDsToLoad count] == 0) {
        [setsSnapshot release];
        [client release];
        return;
    }
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: rail preview preload queued count=%lu", (unsigned long)[setIDsToLoad count]]];
    [self rebuildStickerPickerSetRail];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSUInteger loadIndex = 0;
        for (loadIndex = 0; loadIndex < [setIDsToLoad count]; loadIndex++) {
            NSNumber *setID = [setIDsToLoad objectAtIndex:loadIndex];
            NSError *setError = nil;
            NSArray *items = [[client stickerItemsForStickerSetID:setID limit:8 timeout:12.0 error:&setError] copy];
            NSDictionary *firstItem = nil;
            NSUInteger itemIndex = 0;
            for (itemIndex = 0; itemIndex < [items count]; itemIndex++) {
                NSDictionary *rawItem = [[items objectAtIndex:itemIndex] isKindOfClass:[NSDictionary class]] ? [items objectAtIndex:itemIndex] : nil;
                firstItem = [self stickerPickerRenderableRailItemFromItem:rawItem client:client];
                if (firstItem) {
                    break;
                }
            }
            [firstItem retain];
            NSString *errorMessage = [[setError localizedDescription] copy];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *key = [setID stringValue];
                if (client == self.client) {
                    if (firstItem) {
                        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: rail preview loaded for set %@", key]];
                        [self updateStickerPickerRailThumbnailForSetID:setID withItem:firstItem];
                    } else {
                        [self.stickerPickerRailPreviewState removeObjectForKey:key];
                        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: rail preview unavailable for set %@%@",
                                                      key,
                                                      [errorMessage length] > 0 ? [NSString stringWithFormat:@" error=%@", errorMessage] : @""]];
                        [self rebuildStickerPickerSetRail];
                    }
                }
                [firstItem release];
                [items release];
                [errorMessage release];
            });
        }
        [setsSnapshot release];
        [client release];
        [pool drain];
    });
}

- (void)selectRecentStickerPickerTab:(id)sender {
    (void)sender;
    self.stickerPickerSelectedSetID = nil;
    [self.stickerPickerSearchField setStringValue:@""];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegraphicaStickerPickerLastSetID"];
    [self reloadStickerPickerItems];
}

- (void)selectFavoriteStickerPickerTab:(id)sender {
    (void)sender;
    self.stickerPickerSelectedSetID = nil;
    [self.stickerPickerSearchField setStringValue:@""];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegraphicaStickerPickerLastSetID"];
    [self reloadFavoriteStickerPickerItems];
}

- (void)searchStickerPickerByEmoji:(id)sender {
    (void)sender;
    NSString *query = [[self.stickerPickerSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0) {
        [self reloadStickerPickerItems];
        return;
    }
    self.stickerPickerSelectedSetID = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegraphicaStickerPickerLastSetID"];
    [self reloadStickerPickerItemsForEmoji:query];
}

- (void)selectStickerSetFromPickerButton:(id)sender {
    NSInteger setIndex = [sender respondsToSelector:@selector(tag)] ? [sender tag] : -1;
    id represented = (setIndex >= 0 && (NSUInteger)setIndex < [self.stickerPickerStickerSets count]) ? [self.stickerPickerStickerSets objectAtIndex:(NSUInteger)setIndex] : nil;
    if (![represented isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSNumber *setID = [(NSDictionary *)represented objectForKey:@"id"];
    if (![setID respondsToSelector:@selector(longLongValue)] || [setID longLongValue] == 0LL) {
        return;
    }
    self.stickerPickerSelectedSetID = setID;
    [self.stickerPickerSearchField setStringValue:@""];
    [[NSUserDefaults standardUserDefaults] setObject:[setID stringValue] forKey:@"TelegraphicaStickerPickerLastSetID"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self reloadStickerPickerItemsForSet:(NSDictionary *)represented];
}

- (void)removeSelectedStickerSetFromPicker:(id)sender {
    (void)sender;
    NSNumber *setID = [self.stickerPickerSelectedSetID retain];
    if (![setID respondsToSelector:@selector(longLongValue)] || [setID longLongValue] == 0LL) {
        [self.stickerPickerStatusField setStringValue:@"Select an installed sticker set first."];
        [setID release];
        return;
    }

    NSString *setTitle = @"this sticker set";
    NSUInteger index = 0;
    for (index = 0; index < [self.stickerPickerStickerSets count]; index++) {
        NSDictionary *set = [self.stickerPickerStickerSets objectAtIndex:index];
        NSNumber *candidateID = [set objectForKey:@"id"];
        if ([candidateID respondsToSelector:@selector(longLongValue)] && [candidateID longLongValue] == [setID longLongValue]) {
            NSString *title = [set objectForKey:@"title"];
            if ([title isKindOfClass:[NSString class]] && [title length] > 0) {
                setTitle = title;
            }
            break;
        }
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Remove sticker set?"];
    [alert setInformativeText:[NSString stringWithFormat:@"Remove %@ from your installed sticker sets?", setTitle]];
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        [setID release];
        return;
    }

    [self.stickerPickerStatusField setStringValue:@"Removing sticker set..."];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *changeError = nil;
        BOOL ok = [client setStickerSetInstalledForStickerSetID:setID installed:NO timeout:8.0 error:&changeError];
        NSString *errorMessage = [[changeError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok) {
                [self.stickerPickerSetCache removeObjectForKey:[setID stringValue]];
                [self.stickerPickerRailPreviewState removeObjectForKey:[setID stringValue]];
                self.stickerPickerStickerSets = [NSArray array];
                self.stickerPickerSelectedSetID = nil;
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TelegraphicaStickerPickerLastSetID"];
                [self reloadStickerPickerSetsIfNeeded];
                [self reloadStickerPickerItems];
                [self.stickerPickerStatusField setStringValue:@"Sticker set removed."];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: removed sticker set %@", setID]];
            } else {
                [self.stickerPickerStatusField setStringValue:([errorMessage length] > 0 ? errorMessage : @"Could not remove sticker set.")];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: remove set failed %@ error=%@", setID, [errorMessage length] > 0 ? errorMessage : @"unknown"]];
            }
            [errorMessage release];
            [setID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)rebuildStickerPickerSetRail {
    NSView *setView = self.stickerPickerSetContentView;
    if (!setView) {
        return;
    }
    NSArray *oldSubviews = [[setView subviews] copy];
    NSUInteger removeIndex = 0;
    for (removeIndex = 0; removeIndex < [oldSubviews count]; removeIndex++) {
        [[oldSubviews objectAtIndex:removeIndex] removeFromSuperview];
    }
    [oldSubviews release];

    CGFloat buttonSide = 48.0;
    CGFloat gap = 8.0;
    NSUInteger count = [self.stickerPickerStickerSets count];
    CGFloat visibleWidth = 514.0;
    if (self.stickerPickerSetScrollView) {
        visibleWidth = NSWidth([[self.stickerPickerSetScrollView contentView] bounds]);
    }
    CGFloat contentWidth = MAX(visibleWidth, gap + (CGFloat)count * (buttonSide + gap));
    CGFloat contentHeight = 50.0;
    [setView setFrame:NSMakeRect(0, 0, contentWidth, contentHeight)];

    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        id candidate = [self.stickerPickerStickerSets objectAtIndex:index];
        if (![candidate isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *set = (NSDictionary *)candidate;
        NSDictionary *thumbnail = nil;
        NSDictionary *railItem = [[set objectForKey:@"rail_item"] isKindOfClass:[NSDictionary class]] ? [set objectForKey:@"rail_item"] : nil;
        if ([self stickerPickerItemHasRenderableRailPreview:railItem]) {
            thumbnail = railItem;
        } else {
            NSDictionary *setThumbnail = [[set objectForKey:@"thumbnail"] isKindOfClass:[NSDictionary class]] ? [set objectForKey:@"thumbnail"] : nil;
            if ([self stickerPickerItemHasRenderableRailPreview:setThumbnail]) {
                thumbnail = setThumbnail;
            }
        }
        NSMutableDictionary *buttonItem = [NSMutableDictionary dictionary];
        if (thumbnail) {
            [buttonItem addEntriesFromDictionary:thumbnail];
        }
        if ([buttonItem count] == 0) {
            NSNumber *setID = [set objectForKey:@"id"];
            NSString *state = ([setID respondsToSelector:@selector(stringValue)] ? [self.stickerPickerRailPreviewState objectForKey:[setID stringValue]] : nil);
            if ([setID respondsToSelector:@selector(longLongValue)] && [setID longLongValue] != 0LL && ![state isEqualToString:@"done"]) {
                [buttonItem setObject:[NSNumber numberWithBool:YES] forKey:@"sticker_loading"];
            } else {
                [buttonItem setObject:@"stickers" forKey:@"emoji"];
            }
        }
        CGFloat x = gap + (CGFloat)index * (buttonSide + gap);
        NSRect buttonFrame = NSMakeRect(x, 1.0, buttonSide, buttonSide);
        NSButton *button = TGStickerPickerButtonWithFrame(buttonFrame,
                                                          buttonItem,
                                                          (NSInteger)index,
                                                          self,
                                                          @selector(selectStickerSetFromPickerButton:));
        NSString *tooltip = [set objectForKey:@"title"];
        if ([tooltip isKindOfClass:[NSString class]] && [tooltip length] > 0) {
            [button setToolTip:tooltip];
        }
        [setView addSubview:button];
        if (TGStickerPickerItemNeedsLoadingIndicator(buttonItem)) {
            TGStickerPickerLoadingView *spinner = [[[TGStickerPickerLoadingView alloc] initWithFrame:NSMakeRect(NSMidX(buttonFrame) - 11.0,
                                                                                                                NSMidY(buttonFrame) - 11.0,
                                                                                                                22.0,
                                                                                                                22.0)] autorelease];
            [spinner startAnimation:nil];
            [setView addSubview:spinner];
        }
    }
}

- (void)scrollStickerPickerSetRailToTop {
    NSScrollView *scrollView = self.stickerPickerSetScrollView;
    NSView *documentView = self.stickerPickerSetContentView;
    if (!scrollView || !documentView) {
        return;
    }
    [[scrollView documentView] scrollPoint:NSMakePoint(0.0, 0.0)];
    [scrollView reflectScrolledClipView:[scrollView contentView]];
}

- (void)scrollStickerPickerGridToTop {
    NSScrollView *scrollView = self.stickerPickerScrollView;
    NSView *documentView = self.stickerPickerContentView;
    if (!scrollView || !documentView) {
        return;
    }
    NSClipView *clipView = [scrollView contentView];
    NSRect visibleBounds = [clipView bounds];
    NSRect documentFrame = [documentView frame];
    CGFloat targetY = NSHeight(documentFrame) - NSHeight(visibleBounds);
    if (targetY < 0.0) {
        targetY = 0.0;
    }
    [clipView scrollToPoint:NSMakePoint(0.0, targetY)];
    [scrollView reflectScrolledClipView:clipView];
    [self refreshStickerPickerPlayback];
}

- (void)reloadStickerPickerSetsIfNeeded {
    if ([self.stickerPickerStickerSets count] > 0) {
        [self rebuildStickerPickerSetRail];
        [self scrollStickerPickerSetRailToTop];
        [self preloadStickerPickerRailPreviews];
        return;
    }
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *setError = nil;
        NSArray *sets = [[client installedStickerSetInfoItemsWithTimeout:8.0 error:&setError] copy];
        NSString *errorMessage = [[setError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL resultIsCurrent = (client == self.client);
            if (resultIsCurrent) {
                self.stickerPickerStickerSets = ([sets count] > 0 ? sets : [NSArray array]);
                [self rebuildStickerPickerSetRail];
                [self scrollStickerPickerSetRailToTop];
                [self preloadStickerPickerRailPreviews];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: loaded installed sticker sets count=%lu%@",
                                              (unsigned long)[self.stickerPickerStickerSets count],
                                              [errorMessage length] > 0 ? [NSString stringWithFormat:@" error=%@", errorMessage] : @""]];
                NSString *lastSetID = [[NSUserDefaults standardUserDefaults] stringForKey:@"TelegraphicaStickerPickerLastSetID"];
                if ([lastSetID length] > 0 && [self.stickerPickerItems count] == 0) {
                    NSUInteger index = 0;
                    for (index = 0; index < [self.stickerPickerStickerSets count]; index++) {
                        NSDictionary *set = [self.stickerPickerStickerSets objectAtIndex:index];
                        NSNumber *setID = [set objectForKey:@"id"];
                        if ([setID respondsToSelector:@selector(longLongValue)] && [[setID stringValue] isEqualToString:lastSetID]) {
                            self.stickerPickerSelectedSetID = setID;
                            [self reloadStickerPickerItemsForSet:set];
                            break;
                        }
                    }
                }
            }
            [sets release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)stickerPickerScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.stickerPickerScrollView contentView]) {
        return;
    }
    [self refreshStickerPickerPlayback];
}

- (void)refreshStickerPickerPlayback {
    if (!self.stickerPickerPlaybackCoordinator) {
        return;
    }
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
            NSString *diagnosticKey = [NSString stringWithFormat:@"picker-missing-%ld", (long)stickerIndex];
            [self logInlinePlaybackDiagnosticOnceForKey:diagnosticKey
                                                message:[NSString stringWithFormat:@"Media Playback: picker skipped %@", TGMediaItemInlinePlaybackDiagnosticSummary((NSDictionary *)candidateItem)]];
            continue;
        }
        NSString *identifier = [NSString stringWithFormat:@"sticker-picker-%ld-%@", (long)stickerIndex, path];
        NSString *playbackKind = TGInlinePlaybackKindForMediaItem((NSDictionary *)candidateItem);
        NSRect playbackFrame = TGStickerPickerContentRectForButtonFrame([candidateView frame]);
        [self logInlinePlaybackDiagnosticOnceForKey:[NSString stringWithFormat:@"picker-descriptor-%@", identifier]
                                            message:[NSString stringWithFormat:@"Media Playback: picker descriptor queued kind=%@ file=%@",
                                                     playbackKind, [path lastPathComponent]]];
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
    CGFloat contentWidth = 500.0;
    if (self.stickerPickerScrollView) {
        contentWidth = MAX(380.0, NSWidth([[self.stickerPickerScrollView contentView] bounds]));
    }
    NSUInteger columns = MAX(4, (NSUInteger)floor((contentWidth - gap) / (buttonSide + gap)));
    NSUInteger count = [self.stickerPickerItems count];
    NSUInteger rows = (count == 0) ? 1 : ((count + columns - 1) / columns);
    CGFloat contentHeight = rows * (buttonSide + gap) + gap;
    CGFloat minimumContentHeight = 314.0;
    if (self.stickerPickerScrollView) {
        minimumContentHeight = NSHeight([[self.stickerPickerScrollView contentView] bounds]);
    }
    if (contentHeight < minimumContentHeight) {
        contentHeight = minimumContentHeight;
    }
    [gridView setFrame:NSMakeRect(0, 0, contentWidth, contentHeight)];

    if (count == 0 && [[self.stickerPickerStatusField stringValue] hasPrefix:@"Loading"]) {
        TGStickerPickerLoadingView *spinner = [[[TGStickerPickerLoadingView alloc] initWithFrame:NSMakeRect(floor((contentWidth - 30.0) / 2.0),
                                                                                                    floor((contentHeight - 30.0) / 2.0),
                                                                                                    30.0,
                                                                                                    30.0)] autorelease];
        [spinner startAnimation:nil];
        [gridView addSubview:spinner];
    }

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
    self.stickerPickerSelectedSetID = nil;
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
                [[TGLogger sharedLogger] log:@"Stickers: ignored stale recent stickers response."];
                [items release];
                [errorMessage release];
                [client release];
                return;
            }
            if ([items count] > 0) {
                self.stickerPickerItems = items;
                [self.stickerPickerStatusField setStringValue:@"Recent stickers"];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: loaded recent stickers count=%lu", (unsigned long)[items count]]];
            } else {
                self.stickerPickerItems = [NSArray array];
                [self.stickerPickerStatusField setStringValue:([errorMessage length] > 0 ? errorMessage : @"No recent stickers yet")];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: recent stickers unavailable: %@", [errorMessage length] > 0 ? errorMessage : @"empty response"]];
            }
            [self rebuildStickerPickerGrid];
            [self scrollStickerPickerGridToTop];
            [items release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)reloadFavoriteStickerPickerItems {
    [self.stickerPickerStatusField setStringValue:@"Loading favorite stickers..."];
    self.stickerPickerSelectedSetID = nil;
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.stickerPickerLoadGeneration + 1;
    self.stickerPickerLoadGeneration = generation;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *stickerError = nil;
        NSArray *items = [[client favoriteStickerItemsWithLimit:40 timeout:8.0 error:&stickerError] copy];
        NSString *errorMessage = [[stickerError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL resultIsCurrent = (generation == self.stickerPickerLoadGeneration && client == self.client);
            if (resultIsCurrent) {
                self.stickerPickerItems = ([items count] > 0 ? items : [NSArray array]);
                [self.stickerPickerStatusField setStringValue:([items count] > 0 ? @"Favorite stickers" : ([errorMessage length] > 0 ? errorMessage : @"No favorite stickers yet"))];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: loaded favorite stickers count=%lu%@", (unsigned long)[items count], [errorMessage length] > 0 ? [NSString stringWithFormat:@" error=%@", errorMessage] : @""]];
                [self rebuildStickerPickerGrid];
                [self scrollStickerPickerGridToTop];
            }
            [items release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)reloadStickerPickerItemsForEmoji:(NSString *)emoji {
    NSString *query = [emoji copy];
    [self.stickerPickerStatusField setStringValue:[NSString stringWithFormat:@"Searching %@...", query]];
    self.stickerPickerItems = [NSArray array];
    [self rebuildStickerPickerGrid];
    [self scrollStickerPickerGridToTop];
    TGTDLibClient *client = [self.client retain];
    NSUInteger generation = self.stickerPickerLoadGeneration + 1;
    self.stickerPickerLoadGeneration = generation;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *stickerError = nil;
        NSArray *items = [[client stickerItemsForEmoji:query limit:60 timeout:8.0 error:&stickerError] copy];
        NSString *errorMessage = [[stickerError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL resultIsCurrent = (generation == self.stickerPickerLoadGeneration && client == self.client);
            if (resultIsCurrent) {
                self.stickerPickerItems = ([items count] > 0 ? items : [NSArray array]);
                [self.stickerPickerStatusField setStringValue:([items count] > 0 ? [NSString stringWithFormat:@"Stickers for %@", query] : ([errorMessage length] > 0 ? errorMessage : @"No stickers found"))];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: emoji search query=%@ count=%lu%@", query, (unsigned long)[items count], [errorMessage length] > 0 ? [NSString stringWithFormat:@" error=%@", errorMessage] : @""]];
                [self rebuildStickerPickerGrid];
                [self scrollStickerPickerGridToTop];
            }
            [items release];
            [errorMessage release];
            [query release];
            [client release];
        });
        [pool drain];
    });
}

- (void)reloadStickerPickerItemsForSet:(NSDictionary *)setInfo {
    NSNumber *setID = [setInfo objectForKey:@"id"];
    if (![setID respondsToSelector:@selector(longLongValue)] || [setID longLongValue] == 0LL) {
        [self reloadStickerPickerItems];
        return;
    }
    NSString *cacheKey = [setID stringValue];
    NSArray *cachedItems = [self.stickerPickerSetCache objectForKey:cacheKey];
    NSString *title = [setInfo objectForKey:@"title"];
    if (![title isKindOfClass:[NSString class]] || [title length] == 0) {
        title = [setInfo objectForKey:@"name"];
    }
    if (![title isKindOfClass:[NSString class]] || [title length] == 0) {
        title = @"Sticker set";
    }
    if ([cachedItems count] > 0) {
        self.stickerPickerItems = cachedItems;
        [self.stickerPickerStatusField setStringValue:title];
        [self updateStickerPickerRailThumbnailForSetID:setID withItem:[cachedItems objectAtIndex:0]];
        [self rebuildStickerPickerGrid];
        [self scrollStickerPickerGridToTop];
        return;
    }

    [self.stickerPickerStatusField setStringValue:[NSString stringWithFormat:@"Loading %@...", title]];
    self.stickerPickerItems = [NSArray array];
    [self rebuildStickerPickerGrid];
    [self scrollStickerPickerGridToTop];

    TGTDLibClient *client = [self.client retain];
    NSNumber *selectedSetID = [setID retain];
    NSString *titleCopy = [title copy];
    NSUInteger generation = self.stickerPickerLoadGeneration + 1;
    self.stickerPickerLoadGeneration = generation;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *setError = nil;
        NSArray *items = [[client stickerItemsForStickerSetID:selectedSetID limit:72 timeout:10.0 error:&setError] copy];
        NSString *errorMessage = [[setError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL resultIsCurrent = (generation == self.stickerPickerLoadGeneration &&
                                    client == self.client &&
                                    [self.stickerPickerSelectedSetID respondsToSelector:@selector(longLongValue)] &&
                                    [self.stickerPickerSelectedSetID longLongValue] == [selectedSetID longLongValue]);
            if (resultIsCurrent) {
                if ([items count] > 0) {
                    [self.stickerPickerSetCache setObject:items forKey:cacheKey];
                    self.stickerPickerItems = items;
                    [self updateStickerPickerRailThumbnailForSetID:selectedSetID withItem:[items objectAtIndex:0]];
                    [self.stickerPickerStatusField setStringValue:titleCopy];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: loaded set %@ count=%lu", titleCopy, (unsigned long)[items count]]];
                } else {
                    self.stickerPickerItems = [NSArray array];
                    [self.stickerPickerStatusField setStringValue:([errorMessage length] > 0 ? errorMessage : @"This sticker set is empty")];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: set %@ unavailable: %@", titleCopy, [errorMessage length] > 0 ? errorMessage : @"empty response"]];
                }
                [self rebuildStickerPickerGrid];
                [self scrollStickerPickerGridToTop];
            }
            [items release];
            [errorMessage release];
            [titleCopy release];
            [selectedSetID release];
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
    [self reloadStickerPickerSetsIfNeeded];
    if (self.stickerPickerSelectedSetID && [self.stickerPickerItems count] == 0) {
        NSString *selectedID = [self.stickerPickerSelectedSetID stringValue];
        NSUInteger index = 0;
        for (index = 0; index < [self.stickerPickerStickerSets count]; index++) {
            NSDictionary *set = [self.stickerPickerStickerSets objectAtIndex:index];
            NSNumber *setID = [set objectForKey:@"id"];
            if ([setID respondsToSelector:@selector(longLongValue)] && [[setID stringValue] isEqualToString:selectedID]) {
                [self reloadStickerPickerItemsForSet:set];
                return;
            }
        }
        [self reloadStickerPickerItems];
    } else if ([self.stickerPickerItems count] == 0) {
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
        [[TGLogger sharedLogger] log:@"Stickers: send aborted because file id is missing."];
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
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: send requested format=%@ file=%@", TGMediaItemStickerFormat(sticker), fileID]];
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
                [[TGLogger sharedLogger] log:@"Stickers: send accepted."];
                self.forceMessageScrollToNewest = YES;
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
            } else {
                [self.statusField setStringValue:@"Sticker send failed"];
                [self appendDetail:([errorMessage length] > 0 ? errorMessage : @"Sticker send was not confirmed.")];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Stickers: send failed: %@", [errorMessage length] > 0 ? errorMessage : @"not confirmed"]];
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

    NSButton *playButton = [[[NSButton alloc] initWithFrame:NSMakeRect(22, 48, 48, 48)] autorelease];
    [playButton setTitle:@"Play"];
    [playButton setCell:[[[TGMediaPlaybackButtonCell alloc] initTextCell:@"Play"] autorelease]];
    [playButton setBordered:NO];
    [playButton setFocusRingType:NSFocusRingTypeNone];
    [playButton setTarget:self];
    [playButton setAction:@selector(toggleVoicePreviewPlayback:)];
    [contentView addSubview:playButton];
    self.voicePreviewPlayButton = playButton;

    NSButton *stopButton = [[[NSButton alloc] initWithFrame:NSMakeRect(144, 54, 92, 30)] autorelease];
    [stopButton setTitle:@"Stop"];
    [stopButton setTarget:self];
    [stopButton setAction:@selector(toggleVoiceRecording:)];
    [self applySkeuomorphicButtonStyle:stopButton isPrimary:YES];
    [stopButton setHidden:YES];
    [contentView addSubview:stopButton];
    self.voicePreviewStopButton = stopButton;

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
    self.voicePreviewCancelButton = cancelButton;

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

- (void)configureVoicePreviewWindowForRecording {
    [self ensureVoicePreviewWindow];
    [self.voicePreviewTitleField setStringValue:TGLoc(@"voice.recording")];
    [self.voicePreviewTitleField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [self.voicePreviewErrorField setStringValue:@"Press Stop when you finish recording."];
    [self.voicePreviewErrorField setHidden:NO];
    [self.voicePreviewPlayButton setHidden:YES];
    [self.voicePreviewProgressSlider setHidden:YES];
    [self.voicePreviewTimeField setHidden:YES];
    [self.voicePreviewCancelButton setHidden:YES];
    [self.voicePreviewSendButton setHidden:YES];
    [self.voicePreviewStopButton setHidden:NO];
    [self.voicePreviewStopButton setEnabled:YES];
    [self.voicePreviewWindow center];
    [self.voicePreviewWindow makeKeyAndOrderFront:nil];
}

- (void)configureVoicePreviewWindowForReadyDuration:(NSTimeInterval)duration {
    [self ensureVoicePreviewWindow];
    [self.voicePreviewTitleField setStringValue:[NSString stringWithFormat:@"Voice message %.0fs", duration]];
    [self.voicePreviewTitleField setTextColor:[NSColor colorWithCalibratedWhite:0.08 alpha:1.0]];
    [self.voicePreviewPlayButton setTitle:@"Play"];
    [self.voicePreviewPlayButton setHidden:NO];
    [self.voicePreviewStopButton setHidden:YES];
    [self.voicePreviewProgressSlider setHidden:NO];
    [self.voicePreviewTimeField setHidden:NO];
    [self.voicePreviewCancelButton setHidden:NO];
    [self.voicePreviewSendButton setHidden:NO];
    [self.voicePreviewSendButton setTitle:TGLoc(@"send")];
    [self.voicePreviewSendButton setEnabled:YES];
    [self.voicePreviewErrorField setStringValue:@""];
    [self.voicePreviewErrorField setHidden:YES];
    [self updateVoicePreviewTimelineWithCurrentTime:0.0 duration:duration];
    [self.voicePreviewWindow center];
    [self.voicePreviewWindow makeKeyAndOrderFront:nil];
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
        NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.voiceRecordingStartDate];
        self.voicePreviewPlayer = nil;
        [self configureVoicePreviewWindowForReadyDuration:duration];
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
    [self.voiceRecordingIndicatorField setStringValue:@""];
    [self.voiceRecordingIndicatorField setHidden:YES];
    [self.voiceRecordButton setToolTip:TGLoc(@"voice.stopHint")];
    [self configureVoicePreviewWindowForRecording];
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

- (void)attachFileFromComposerMenu:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before attaching a photo."];
        return;
    }

    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:YES];
    [panel setAllowedFileTypes:[TGAttachmentDescriptor supportedOpenPanelTypes]];
    NSInteger result = [panel runModal];
    if (result != NSOKButton) {
        [self requestComposerRefocus];
        return;
    }

    NSArray *urls = [panel URLs];
    if ([urls count] == 0) {
        return;
    }
    NSMutableArray *descriptors = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [urls count] && [descriptors count] < 10; index++) {
        NSURL *url = [urls objectAtIndex:index];
        TGAttachmentDescriptor *descriptor = [TGAttachmentDescriptor descriptorForPath:[url path]];
        if ([descriptor isSupported]) {
            [descriptors addObject:descriptor];
        }
    }
    [self presentAttachmentPreviewForDescriptors:descriptors];
}

- (NSArray *)pollOptionsFromText:(NSString *)optionsText {
    NSMutableArray *options = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *lines = [optionsText componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger index = 0;
    for (index = 0; index < [lines count] && [options count] < 10; index++) {
        NSString *line = [[lines objectAtIndex:index] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *normalized = [line lowercaseString];
        if ([line length] == 0 || [seen containsObject:normalized]) {
            continue;
        }
        [seen addObject:normalized];
        [options addObject:line];
    }
    return options;
}

- (void)createPollFromComposerMenu:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        [self appendDetail:@"Select a chat after sign-in is ready before creating a poll."];
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"poll.create.title")];
    [alert setInformativeText:TGLoc(@"poll.create.hint")];
    [alert addButtonWithTitle:TGLoc(@"send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 390, 194)] autorelease];
    NSTextField *questionLabel = [self labelWithFrame:NSMakeRect(0, 170, 390, 18)
                                                 text:TGLoc(@"poll.create.question")
                                                 font:[NSFont systemFontOfSize:12.0]];
    [accessory addSubview:questionLabel];
    NSTextField *questionField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0, 145, 390, 22)] autorelease];
    [questionField setStringValue:@""];
    [accessory addSubview:questionField];

    NSTextField *optionsLabel = [self labelWithFrame:NSMakeRect(0, 120, 390, 18)
                                                text:TGLoc(@"poll.create.options")
                                                font:[NSFont systemFontOfSize:12.0]];
    [accessory addSubview:optionsLabel];
    NSScrollView *optionsScroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0, 42, 390, 76)] autorelease];
    [optionsScroll setHasVerticalScroller:YES];
    [optionsScroll setBorderType:NSBezelBorder];
    NSTextView *optionsView = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 372, 76)] autorelease];
    [optionsView setString:@"\n"];
    [optionsScroll setDocumentView:optionsView];
    [accessory addSubview:optionsScroll];

    NSButton *multipleButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0, 20, 185, 18)] autorelease];
    [multipleButton setButtonType:NSSwitchButton];
    [multipleButton setTitle:TGLoc(@"poll.create.multiple")];
    [accessory addSubview:multipleButton];
    NSButton *anonymousButton = [[[NSButton alloc] initWithFrame:NSMakeRect(198, 20, 185, 18)] autorelease];
    [anonymousButton setButtonType:NSSwitchButton];
    [anonymousButton setTitle:TGLoc(@"poll.create.anonymous")];
    [anonymousButton setState:NSOnState];
    [accessory addSubview:anonymousButton];

    NSTextField *errorField = [self labelWithFrame:NSMakeRect(0, 0, 390, 16)
                                              text:@""
                                              font:[NSFont systemFontOfSize:11.0]];
    [errorField setTextColor:[NSColor colorWithCalibratedRed:0.72 green:0.14 blue:0.12 alpha:1.0]];
    [accessory addSubview:errorField];
    [alert setAccessoryView:accessory];

    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        [self requestComposerRefocus];
        return;
    }

    NSString *question = [[questionField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *options = [self pollOptionsFromText:[optionsView string]];
    if ([question length] == 0 || [options count] < 2) {
        NSString *message = ([question length] == 0) ? TGLoc(@"poll.create.error.question") : TGLoc(@"poll.create.error.options");
        NSRunAlertPanel(TGLoc(@"poll.create.failed"), message, TGLoc(@"ok"), nil, nil);
        [self requestComposerRefocus];
        return;
    }

    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    NSString *questionCopy = [question copy];
    NSArray *optionsCopy = [options copy];
    BOOL allowMultiple = ([multipleButton state] == NSOnState);
    BOOL anonymous = ([anonymousButton state] == NSOnState);
    TGTDLibClient *client = [self.client retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:TGLoc(@"poll.create.sending")];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Polls: create requested options=%lu multiple=%@ anonymous=%@.",
                                  (unsigned long)[optionsCopy count],
                                  allowMultiple ? @"yes" : @"no",
                                  anonymous ? @"yes" : @"no"]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSString *summary = [[client sendPollMessageToChatID:chatID
                                             messageThreadID:messageThreadID
                                            messageTopicKind:messageTopicKind
                                                    question:questionCopy
                                                     options:optionsCopy
                                        allowMultipleAnswers:allowMultiple
                                                   anonymous:anonymous
                                                     timeout:8.0
                                                       error:&sendError] copy];
        NSString *errorMessage = [[sendError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([summary length] > 0) {
                [self.statusField setStringValue:TGLoc(@"poll.create.sent")];
                [self appendDetail:@"Poll sent."];
                self.forceMessageScrollToNewest = YES;
                [self refreshSelectedChatMessages:self];
            } else {
                [self.statusField setStringValue:TGLoc(@"poll.create.failed")];
                [self appendDetail:[NSString stringWithFormat:@"Poll send failed: %@", [errorMessage length] > 0 ? errorMessage : @"unknown error"]];
            }
            [self setControlsBusy:NO];
            [self requestComposerRefocus];
            [summary release];
            [errorMessage release];
            [optionsCopy release];
            [questionCopy release];
            [messageTopicKind release];
            [messageThreadID release];
            [chatID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)attachPhoto:(id)sender {
    (void)sender;
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget) {
        [self appendDetail:@"Select a chat after sign-in is ready before attaching a photo."];
        return;
    }
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:TGLoc(@"attach.photo")] autorelease];
    NSMenuItem *attachItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"attach.file")
                                                        action:@selector(attachFileFromComposerMenu:)
                                                 keyEquivalent:@""] autorelease];
    [attachItem setTarget:self];
    [menu addItem:attachItem];
    NSMenuItem *pollItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"poll.create.menu")
                                                      action:@selector(createPollFromComposerMenu:)
                                               keyEquivalent:@""] autorelease];
    [pollItem setTarget:self];
    [menu addItem:pollItem];
    [menu popUpMenuPositioningItem:nil
                        atLocation:NSMakePoint(0.0, NSHeight([self.attachPhotoButton bounds]) + 2.0)
                            inView:self.attachPhotoButton];
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
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *messageThreadID = [self.selectedMessageThreadID retain];
    NSString *messageTopicKind = [self.selectedMessageTopicKind copy];
    NSString *messageText = [text copy];
    NSArray *messageChunks = [TGOutgoingTextMessageChunks(messageText) retain];
    NSNumber *replyToMessageID = nil;
    if (self.replyTargetMessageItem &&
        [self.replyTargetChatID respondsToSelector:@selector(longLongValue)] &&
        [chatID respondsToSelector:@selector(longLongValue)] &&
        [self.replyTargetChatID longLongValue] == [chatID longLongValue] &&
        [[self.replyTargetMessageItem messageID] respondsToSelector:@selector(longLongValue)]) {
        replyToMessageID = [[[self.replyTargetMessageItem messageID] retain] autorelease];
    }
    [replyToMessageID retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Sending..."];
    if ([messageChunks count] > 1) {
        [self appendDetail:[NSString stringWithFormat:@"Submitting long text message to TDLib as %lu parts...", (unsigned long)[messageChunks count]]];
    } else {
        [self appendDetail:(messageThreadID ? @"Submitting topic text message to TDLib..." : @"Submitting text message to TDLib...")];
    }
    [[TGLogger sharedLogger] log:@"TDLib text message send requested."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSUInteger sentPartCount = 0;
        NSUInteger totalPartCount = [messageChunks count];
        NSUInteger chunkIndex = 0;
        for (chunkIndex = 0; chunkIndex < totalPartCount; chunkIndex++) {
            NSString *chunkText = [messageChunks objectAtIndex:chunkIndex];
            NSError *chunkError = nil;
            NSNumber *chunkReplyToMessageID = (chunkIndex == 0) ? replyToMessageID : nil;
            NSString *sendSummary = [client sendTextMessageToChatID:chatID
                                                    messageThreadID:messageThreadID
                                                  messageTopicKind:messageTopicKind
                                                               text:chunkText
                                                    replyToMessageID:chunkReplyToMessageID
                                                            timeout:8.0
                                                              error:&chunkError];
            if ([sendSummary length] == 0) {
                sendError = chunkError;
                break;
            }
            sentPartCount++;
        }
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        NSString *sendErrorMessage = [[sendError localizedDescription] copy];
        BOOL sendSucceeded = (totalPartCount > 0 && sentPartCount == totalPartCount);

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadID) ||
                               (self.selectedMessageThreadID && messageThreadID && [self.selectedMessageThreadID longLongValue] == [messageThreadID longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKind) ||
                                  (self.selectedMessageTopicKind && messageTopicKind && [self.selectedMessageTopicKind isEqualToString:messageTopicKind]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatID longLongValue] && sameThread && sameTopicKind);
            if (sendSucceeded) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:([messageChunks count] > 1 ? @"Messages sent" : @"Message sent")];
                if ([messageChunks count] > 1) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib send: long text accepted by TDLib in %lu parts.", (unsigned long)[messageChunks count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib long text message send accepted in %lu parts.", (unsigned long)[messageChunks count]]];
                } else {
                    [self appendDetail:@"TDLib send: text message accepted by TDLib."];
                    [[TGLogger sharedLogger] log:@"TDLib text message send accepted."];
                }
                [self removeComposerDraftForChatID:chatID
                                   messageThreadID:messageThreadID
                                    messageTopicKind:messageTopicKind];
                if (selectionStillCurrent) {
                    [self setComposerTextWithoutSavingDraft:nil];
                    if (replyToMessageID) {
                        [self clearReplyTarget];
                    }
                    self.forceMessageScrollToNewest = YES;
                }
            } else {
                NSString *message = ([sendErrorMessage length] > 0) ? sendErrorMessage : @"Text message was not confirmed.";
                if (selectionStillCurrent) {
                    [self addFailedTextMessageForChatID:chatID
                                        messageThreadID:messageThreadID
                                       messageTopicKind:messageTopicKind
                                                   text:messageText
                                       replyToMessageID:replyToMessageID
                                          sentPartCount:sentPartCount
                                         totalPartCount:[messageChunks count]
                                                  error:message];
                }
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Message was not retried automatically to avoid duplicate sends."];
                } else {
                    [self.statusField setStringValue:@"Send not confirmed"];
                }
                if ([messageChunks count] > 1) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib send: %@ Sent %lu of %lu parts. Do not retry automatically; it may or may not have been partially sent.",
                                        message,
                                        (unsigned long)sentPartCount,
                                        (unsigned long)[messageChunks count]]];
                } else {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib send: %@ Do not retry automatically; it may or may not have been sent.", message]];
                }
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
            [messageChunks release];
            [replyToMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (TGMessageItem *)failedTextMessageItemForChatID:(NSNumber *)chatID
                                  messageThreadID:(NSNumber *)messageThreadID
                                 messageTopicKind:(NSString *)messageTopicKind
                                             text:(NSString *)text
                                 replyToMessageID:(NSNumber *)replyToMessageID
                                    sentPartCount:(NSUInteger)sentPartCount
                                   totalPartCount:(NSUInteger)totalPartCount
                                            error:(NSString *)errorMessage {
    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:chatID
                                                       messageID:[NSNumber numberWithLongLong:TGLocalFailedOutgoingMessageID()]
                                                            date:[NSNumber numberWithInteger:(NSInteger)[[NSDate date] timeIntervalSince1970]]
                                                        outgoing:YES
                                                         preview:([text length] > 0 ? text : TGLoc(@"message.sendFailed"))] autorelease];
    [item setContentType:@"messageText"];
    [item setEditableText:text];
    [item setFailedToSend:YES];
    [item setCanBeReplied:NO];
    [item setCanBeEdited:NO];
    [item setCanBeDeletedOnlyForSelf:YES];
    [item setCanBeDeletedForAllUsers:NO];
    [item setCapabilitiesKnown:YES];
    [item setRetryMessageThreadID:messageThreadID];
    [item setRetryMessageTopicKind:messageTopicKind];
    [item setRetryText:text];
    [item setRetryReplyToMessageID:replyToMessageID];
    [item setRetrySentPartCount:[NSNumber numberWithUnsignedInteger:sentPartCount]];
    [item setRetryTotalPartCount:[NSNumber numberWithUnsignedInteger:totalPartCount]];
    [item setSendFailureSummary:([errorMessage length] > 0 ? errorMessage : TGLoc(@"message.sendFailed"))];
    if (replyToMessageID) {
        [item setReplyToMessageID:replyToMessageID];
        [item setReplyPreview:TGLoc(@"message.original")];
    }
    return item;
}

- (void)addFailedTextMessageForChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                                 text:(NSString *)text
                     replyToMessageID:(NSNumber *)replyToMessageID
                        sentPartCount:(NSUInteger)sentPartCount
                       totalPartCount:(NSUInteger)totalPartCount
                                error:(NSString *)errorMessage {
    if (![chatID respondsToSelector:@selector(longLongValue)] || [text length] == 0) {
        return;
    }
    TGMessageItem *item = [self failedTextMessageItemForChatID:chatID
                                               messageThreadID:messageThreadID
                                              messageTopicKind:messageTopicKind
                                                          text:text
                                              replyToMessageID:replyToMessageID
                                                 sentPartCount:sentPartCount
                                                totalPartCount:totalPartCount
                                                         error:errorMessage];
    [self.messageItems addObject:item];
    [self.messageTableView reloadData];
    [self scrollMessagesToNewestIfAvailable];
}

- (void)removeFailedTextMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSUInteger index = [self.messageItems indexOfObjectIdenticalTo:item];
    if (index != NSNotFound) {
        [self.messageItems removeObjectAtIndex:index];
        [self.messageTableView reloadData];
    }
}

- (void)retryFailedTextMessageFromMenu:(id)sender {
    TGMessageItem *item = [sender respondsToSelector:@selector(representedObject)] ? [sender representedObject] : nil;
    if (![item isKindOfClass:[TGMessageItem class]] || ![item failedToSend] || [[item retryText] length] == 0) {
        return;
    }
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Message retry is available only after sign-in is ready."];
        return;
    }
    NSUInteger sentPartCount = [[item retrySentPartCount] respondsToSelector:@selector(unsignedIntegerValue)] ? [[item retrySentPartCount] unsignedIntegerValue] : 0;
    NSUInteger totalPartCount = [[item retryTotalPartCount] respondsToSelector:@selector(unsignedIntegerValue)] ? [[item retryTotalPartCount] unsignedIntegerValue] : 1;
    NSString *warning = (totalPartCount > 1)
        ? [NSString stringWithFormat:TGLoc(@"message.retry.confirm.partial"), (unsigned long)sentPartCount, (unsigned long)totalPartCount]
        : TGLoc(@"message.retry.confirm.message");
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.retry.confirm.title")];
    [alert setInformativeText:warning];
    [alert addButtonWithTitle:TGLoc(@"message.retrySend")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return;
    }

    NSNumber *chatID = [[item chatID] retain];
    NSNumber *messageThreadID = [[item retryMessageThreadID] retain];
    NSString *messageTopicKind = [[item retryMessageTopicKind] copy];
    NSString *messageText = [[item retryText] copy];
    NSNumber *replyToMessageID = [[item retryReplyToMessageID] retain];
    NSArray *messageChunks = [TGOutgoingTextMessageChunks(messageText) retain];
    TGMessageItem *failedItem = [item retain];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:TGLoc(@"message.retry.sending")];
    [self appendDetail:@"Retrying failed text message by explicit user action."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sendError = nil;
        NSError *stateError = nil;
        NSUInteger retrySentPartCount = 0;
        NSUInteger retryTotalPartCount = [messageChunks count];
        NSUInteger chunkIndex = 0;
        for (chunkIndex = 0; chunkIndex < retryTotalPartCount; chunkIndex++) {
            NSString *chunkText = [messageChunks objectAtIndex:chunkIndex];
            NSError *chunkError = nil;
            NSNumber *chunkReplyToMessageID = (chunkIndex == 0) ? replyToMessageID : nil;
            NSString *sendSummary = [client sendTextMessageToChatID:chatID
                                                    messageThreadID:messageThreadID
                                                  messageTopicKind:messageTopicKind
                                                               text:chunkText
                                                    replyToMessageID:chunkReplyToMessageID
                                                            timeout:8.0
                                                              error:&chunkError];
            if ([sendSummary length] == 0) {
                sendError = chunkError;
                break;
            }
            retrySentPartCount++;
        }
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError] copy];
        NSString *sendErrorMessage = [[sendError localizedDescription] copy];
        BOOL sendSucceeded = (retryTotalPartCount > 0 && retrySentPartCount == retryTotalPartCount);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (sendSucceeded) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:TGLoc(@"message.retry.sent")];
                [self removeFailedTextMessageItem:failedItem];
                self.forceMessageScrollToNewest = YES;
                self.pendingLiveChatRefresh = YES;
                self.pendingLiveMessageRefresh = YES;
                [self handlePendingLiveRefreshesIfPossible];
                [self requestComposerRefocus];
            } else {
                NSString *message = ([sendErrorMessage length] > 0) ? sendErrorMessage : TGLoc(@"message.sendFailed");
                [failedItem setRetrySentPartCount:[NSNumber numberWithUnsignedInteger:retrySentPartCount]];
                [failedItem setRetryTotalPartCount:[NSNumber numberWithUnsignedInteger:retryTotalPartCount]];
                [failedItem setSendFailureSummary:message];
                [self.statusField setStringValue:TGLoc(@"message.retry.failed")];
                [self.messageTableView reloadData];
                [self appendDetail:@"Retry did not confirm the text message. It was not retried again automatically."];
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Retry stopped to avoid duplicate sends."];
                }
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [authorizationState release];
            [sendErrorMessage release];
            [failedItem release];
            [chatID release];
            [messageThreadID release];
            [messageTopicKind release];
            [messageText release];
            [replyToMessageID release];
            [messageChunks release];
        });

        [client release];
        [pool drain];
    });
}
