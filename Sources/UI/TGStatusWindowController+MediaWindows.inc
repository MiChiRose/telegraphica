static NSString *TGMediaCenterFilterIdentifierForIndex(NSInteger index) {
    switch (index) {
        case 1: return @"documents";
        case 2: return @"links";
        case 3: return @"audio";
        case 4: return @"voice";
        case 5: return @"animations";
        case 6: return @"polls";
        default: return @"all";
    }
}

static NSArray *TGMediaCenterFilterIdentifiersForSelection(NSInteger index) {
    if (index == 0) {
        return [NSArray arrayWithObjects:@"photos", @"videos", nil];
    }
    if (index == 4) {
        return [NSArray arrayWithObjects:@"voice", @"videoNotes", nil];
    }
    if (index == 7) {
        return [NSArray array];
    }
    NSString *single = TGMediaCenterFilterIdentifierForIndex(index);
    if (![single isEqualToString:@"all"]) {
        return [NSArray arrayWithObject:single];
    }
    return [NSArray arrayWithObjects:@"photos", @"videos", @"documents", @"links", @"audio", @"voice", @"videoNotes", @"animations", @"polls", nil];
}

static NSString *TGMediaCenterReadableSize(unsigned long long bytes) {
    if (bytes == 0) {
        return @"0 B";
    }
    double value = (double)bytes;
    NSArray *units = [NSArray arrayWithObjects:@"B", @"KB", @"MB", @"GB", nil];
    NSUInteger unit = 0;
    while (value >= 1024.0 && unit + 1 < [units count]) {
        value /= 1024.0;
        unit++;
    }
    if (unit == 0) {
        return [NSString stringWithFormat:@"%llu %@", bytes, [units objectAtIndex:unit]];
    }
    return [NSString stringWithFormat:@"%.1f %@", value, [units objectAtIndex:unit]];
}

static unsigned long long TGMediaCenterFileSizeAtPath(NSString *path) {
    if ([path length] == 0) {
        return 0;
    }
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSNumber *size = [attributes objectForKey:NSFileSize];
    return [size respondsToSelector:@selector(unsignedLongLongValue)] ? [size unsignedLongLongValue] : 0;
}

static NSDictionary *TGMediaCenterFirstMediaDictionaryForItem(TGMessageItem *item) {
    NSArray *mediaItems = [item mediaItems];
    if ([mediaItems count] > 0 && [[mediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
        return [mediaItems objectAtIndex:0];
    }
    return nil;
}

static NSString *TGMediaCenterLocalPathForItem(TGMessageItem *item) {
    NSDictionary *media = TGMediaCenterFirstMediaDictionaryForItem(item);
    NSString *path = media ? TGMediaItemFullLocalPath(media) : nil;
    if ([path length] == 0) {
        path = [item mediaLocalPath];
    }
    if ([path length] == 0 && media) {
        path = TGMediaItemLocalPath(media);
    }
    return path;
}

static NSNumber *TGMediaCenterFileIDForItem(TGMessageItem *item) {
    NSDictionary *media = TGMediaCenterFirstMediaDictionaryForItem(item);
    NSNumber *fileID = media ? TGMediaItemFullFileID(media) : nil;
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        fileID = [item mediaFileID];
    }
    return fileID;
}

static unsigned long long TGMediaCenterSizeForItem(TGMessageItem *item) {
    NSNumber *declaredSize = [item downloadFileSize];
    if ([declaredSize respondsToSelector:@selector(unsignedLongLongValue)] && [declaredSize unsignedLongLongValue] > 0) {
        return [declaredSize unsignedLongLongValue];
    }
    return TGMediaCenterFileSizeAtPath(TGMediaCenterLocalPathForItem(item));
}

static NSString *TGMediaCenterTypeTitleForItem(TGMessageItem *item) {
    if ([item isPhotoMessage]) {
        return @"Photo";
    }
    if ([[item contentType] isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    if ([item isVoiceNoteMessage]) {
        return @"Voice";
    }
    if ([item isVideoNoteMessage]) {
        return @"Video note";
    }
    if ([item isStickerMessage]) {
        return @"Sticker";
    }
    if ([[item contentType] isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([[item contentType] isEqualToString:@"messageAudio"]) {
        return @"Audio";
    }
    if ([item isPollMessage]) {
        return @"Poll";
    }
    if ([item isDocumentMessage]) {
        return @"Document";
    }
    return @"Media";
}

static NSString *TGMediaCenterTitleForItem(TGMessageItem *item) {
    NSString *fileName = [item downloadFileName];
    if ([fileName length] > 0) {
        return fileName;
    }
    NSString *preview = [item preview];
    if ([preview length] > 0) {
        return preview;
    }
    return TGMediaCenterTypeTitleForItem(item);
}

static NSString *TGMediaCenterDateStringForItem(TGMessageItem *item) {
    NSNumber *dateNumber = [item date];
    if (![dateNumber respondsToSelector:@selector(doubleValue)] || [dateNumber doubleValue] <= 0.0) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[dateNumber doubleValue]];
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    return [formatter stringFromDate:date];
}

static NSImage *TGMediaCenterThumbnailForItem(TGMessageItem *item) {
    NSDictionary *media = TGMediaCenterFirstMediaDictionaryForItem(item);
    NSData *miniData = media ? TGMediaItemMiniThumbnailData(media) : nil;
    if ([miniData length] > 0) {
        NSImage *miniImage = [[[NSImage alloc] initWithData:miniData] autorelease];
        if (miniImage) {
            return miniImage;
        }
    }
    NSString *path = TGMediaCenterLocalPathForItem(item);
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    return TGImageWithCorrectOrientationFromFile(path);
}

static NSComparisonResult TGMediaCenterCompareItems(TGMessageItem *left, TGMessageItem *right, NSInteger sortIndex) {
    if (sortIndex == 2) {
        unsigned long long leftSize = TGMediaCenterSizeForItem(left);
        unsigned long long rightSize = TGMediaCenterSizeForItem(right);
        if (leftSize > rightSize) {
            return NSOrderedAscending;
        }
        if (leftSize < rightSize) {
            return NSOrderedDescending;
        }
    }
    long long leftDate = [[left date] respondsToSelector:@selector(longLongValue)] ? [[left date] longLongValue] : 0LL;
    long long rightDate = [[right date] respondsToSelector:@selector(longLongValue)] ? [[right date] longLongValue] : 0LL;
    if (sortIndex == 1) {
        if (leftDate < rightDate) return NSOrderedAscending;
        if (leftDate > rightDate) return NSOrderedDescending;
    } else {
        if (leftDate > rightDate) return NSOrderedAscending;
        if (leftDate < rightDate) return NSOrderedDescending;
    }
    return NSOrderedSame;
}

static BOOL TGMediaCenterSelectionUsesGrid(NSInteger index) {
    return (index == 0 || index == 5);
}

static BOOL TGMediaCenterSelectionUsesGroups(NSInteger index) {
    return (index == 7);
}

static NSString *TGMediaCenterExtensionBadgeForItem(TGMessageItem *item) {
    NSString *fileName = [item downloadFileName];
    NSString *extension = [[fileName pathExtension] lowercaseString];
    if ([extension length] > 0) {
        return [extension uppercaseString];
    }
    NSString *type = TGMediaCenterTypeTitleForItem(item);
    if ([type length] > 4) {
        return [[type substringToIndex:4] uppercaseString];
    }
    return [type uppercaseString];
}

static NSImage *TGMediaCenterPreviewImageForItem(TGMessageItem *item) {
    NSString *path = TGMediaCenterLocalPathForItem(item);
    if ([path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *extension = [[path pathExtension] lowercaseString];
        NSImage *image = nil;
        if ([extension isEqualToString:@"gif"]) {
            image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
        if (!image) {
            image = TGImageWithCorrectOrientationFromFile(path);
        }
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
        if (image) {
            return image;
        }
    }
    return TGMediaCenterThumbnailForItem(item);
}

- (NSMenu *)mediaCenterContextMenuForIndex:(NSUInteger)index {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
    NSMenuItem *previewItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.preview")
                                                         action:@selector(previewMediaCenterItem:)
                                                  keyEquivalent:@""] autorelease];
    [previewItem setTarget:self];
    [previewItem setTag:(NSInteger)index];
    [menu addItem:previewItem];

    NSMenuItem *openItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.open")
                                                       action:@selector(openMediaCenterItem:)
                                                keyEquivalent:@""] autorelease];
    [openItem setTarget:self];
    [openItem setTag:(NSInteger)index];
    [menu addItem:openItem];

    NSMenuItem *downloadItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.download")
                                                           action:@selector(downloadMediaCenterItem:)
                                                    keyEquivalent:@""] autorelease];
    [downloadItem setTarget:self];
    [downloadItem setTag:(NSInteger)index];
    [menu addItem:downloadItem];

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *goItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.goToFile")
                                                     action:@selector(goToMediaCenterItem:)
                                              keyEquivalent:@""] autorelease];
    [goItem setTarget:self];
    [goItem setTag:(NSInteger)index];
    [menu addItem:goItem];

    NSMenuItem *deleteItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"media.center.deleteLocal")
                                                         action:@selector(deleteLocalMediaCenterItem:)
                                                  keyEquivalent:@""] autorelease];
    [deleteItem setTarget:self];
    [deleteItem setTag:(NSInteger)index];
    [menu addItem:deleteItem];
    return menu;
}

- (void)setMediaCenterLoading:(BOOL)loading {
    _mediaCenterLoading = loading;
    if (self.mediaCenterLoadingSpinner) {
        [self.mediaCenterLoadingSpinner setHidden:!loading];
        if (loading) {
            [self.mediaCenterLoadingSpinner startAnimation:self];
        } else {
            [self.mediaCenterLoadingSpinner stopAnimation:self];
        }
    }
}

- (void)ensureMediaCenterWindow {
    if (self.mediaCenterWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 760, 680);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Chat info"];
    [window setMinSize:NSMakeSize(560.0, 460.0)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    CGFloat avatarSize = 92.0;
    TGProfileAvatarView *avatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(floor((NSWidth(frame) - avatarSize) / 2.0),
                                                                                     548.0,
                                                                                     avatarSize,
                                                                                     avatarSize)] autorelease];
    [avatarView setDisplayName:([self.selectedChatTitle length] > 0 ? self.selectedChatTitle : @"Chat")];
    [avatarView setAvatarLocalPath:self.selectedChatAvatarLocalPath];
    [avatarView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
    [contentView addSubview:avatarView];

    NSString *titleText = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Selected chat";
    NSTextField *titleField = [self labelWithFrame:NSMakeRect(80.0, 516.0, NSWidth(frame) - 160.0, 26.0)
                                              text:titleText
                                              font:[NSFont boldSystemFontOfSize:20.0]];
    [titleField setAlignment:NSCenterTextAlignment];
    [titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:titleField];

    NSMutableString *subtitle = [NSMutableString string];
    if ([self.selectedChatTypeSummary length] > 0) {
        [subtitle appendString:self.selectedChatTypeSummary];
    }
    if ([self.selectedChatID respondsToSelector:@selector(longLongValue)]) {
        if ([subtitle length] > 0) {
            [subtitle appendString:@" · "];
        }
        [subtitle appendFormat:@"ID %lld", [self.selectedChatID longLongValue]];
    }
    NSTextField *subtitleField = [self labelWithFrame:NSMakeRect(80.0, 492.0, NSWidth(frame) - 160.0, 20.0)
                                                 text:([subtitle length] > 0 ? subtitle : @"Chat details")
                                                 font:[NSFont systemFontOfSize:13.0]];
    [subtitleField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:subtitleField];
    [subtitleField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:subtitleField];

    TGGroupedCardView *infoCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(36.0, 422.0, NSWidth(frame) - 72.0, 58.0)] autorelease];
    [infoCard setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:infoCard];

    NSTextField *infoTitle = [self labelWithFrame:NSMakeRect(18.0, 31.0, NSWidth([infoCard bounds]) - 36.0, 18.0)
                                             text:TGLoc(@"media.center.titleCard")
                                             font:[NSFont boldSystemFontOfSize:12.0]];
    [infoTitle setAutoresizingMask:NSViewWidthSizable];
    [infoCard addSubview:infoTitle];

    NSTextField *infoText = [self labelWithFrame:NSMakeRect(18.0, 12.0, NSWidth([infoCard bounds]) - 36.0, 16.0)
                                            text:TGLoc(@"media.center.hint")
                                            font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:infoText];
    [infoText setAutoresizingMask:NSViewWidthSizable];
    [infoCard addSubview:infoText];

    NSSegmentedControl *tabControl = [[[NSSegmentedControl alloc] initWithFrame:NSMakeRect(66.0, 382.0, NSWidth(frame) - 132.0, 28.0)] autorelease];
    NSArray *tabTitles = [NSArray arrayWithObjects:
                          TGLoc(@"media.center.tab.media"),
                          TGLoc(@"media.center.tab.files"),
                          TGLoc(@"media.center.tab.links"),
                          TGLoc(@"media.center.tab.music"),
                          TGLoc(@"media.center.tab.voice"),
                          TGLoc(@"media.center.tab.gif"),
                          TGLoc(@"media.center.tab.polls"),
                          TGLoc(@"media.center.tab.groups"),
                          nil];
    [tabControl setSegmentCount:[tabTitles count]];
    NSUInteger tabIndex = 0;
    for (tabIndex = 0; tabIndex < [tabTitles count]; tabIndex++) {
        [tabControl setLabel:[tabTitles objectAtIndex:tabIndex] forSegment:tabIndex];
        [tabControl setWidth:76.0 forSegment:tabIndex];
    }
    [tabControl setSelectedSegment:0];
    [tabControl setTarget:self];
    [tabControl setAction:@selector(reloadMediaCenter:)];
    if ([[tabControl cell] respondsToSelector:@selector(setTrackingMode:)]) {
        [[tabControl cell] setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    }
    [tabControl setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:tabControl];
    self.mediaCenterTabControl = tabControl;

    NSPopUpButton *sortPopup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(448.0, 438.0, 116.0, 26.0) pullsDown:NO] autorelease];
    [sortPopup addItemsWithTitles:[NSArray arrayWithObjects:@"Newest", @"Oldest", @"Largest", nil]];
    [sortPopup setTarget:self];
    [sortPopup setAction:@selector(rebuildMediaCenterRows)];
    [sortPopup setHidden:YES];
    self.mediaCenterSortPopUpButton = sortPopup;

    NSButton *refreshButton = [[[TGHeaderActionButton alloc] initWithFrame:NSMakeRect(NSWidth(frame) - 72.0, 344.0, 34.0, 30.0)] autorelease];
    [refreshButton setTitle:@"↻"];
    [refreshButton setToolTip:TGLoc(@"settings.sessions.refresh")];
    [refreshButton setTarget:self];
    [refreshButton setAction:@selector(reloadMediaCenter:)];
    [self applyHeaderIconButtonStyle:refreshButton];
    [refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:refreshButton];
    self.mediaCenterRefreshButton = refreshButton;

    NSTextField *statusField = [self labelWithFrame:NSMakeRect(36.0, 350.0, NSWidth(frame) - 170.0, 18.0)
                                               text:TGLoc(@"media.center.chooseChat")
                                               font:[NSFont systemFontOfSize:12.0]];
    [self applyMutedLabelStyle:statusField];
    [statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:statusField];
    self.mediaCenterStatusField = statusField;

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(36.0, 24.0, NSWidth(frame) - 72.0, 314.0)] autorelease];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[scrollView contentView] setDrawsBackground:NO];
    TGFlippedDocumentView *resultsView = [[[TGFlippedDocumentView alloc] initWithFrame:NSMakeRect(0.0, 0.0, NSWidth(frame) - 90.0, 80.0)] autorelease];
    [scrollView setDocumentView:resultsView];
    [contentView addSubview:scrollView];
    self.mediaCenterScrollView = scrollView;
    self.mediaCenterResultsView = resultsView;

    NSProgressIndicator *loadingSpinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(floor((NSWidth(frame) - 24.0) / 2.0), 176.0, 24.0, 24.0)] autorelease];
    [loadingSpinner setStyle:NSProgressIndicatorSpinningStyle];
    [loadingSpinner setDisplayedWhenStopped:NO];
    [loadingSpinner setHidden:YES];
    [loadingSpinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    [contentView addSubview:loadingSpinner];
    self.mediaCenterLoadingSpinner = loadingSpinner;

    self.mediaCenterWindow = window;
}

- (void)layoutMediaCenterWindowSubviews {
    if (!self.mediaCenterWindow) {
        return;
    }
    NSView *contentView = [self.mediaCenterWindow contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat tabWidth = 608.0;
    if (tabWidth > width - 72.0) {
        tabWidth = width - 72.0;
    }
    [self.mediaCenterTabControl setFrame:NSMakeRect(floor((width - tabWidth) / 2.0), height - 298.0, tabWidth, 28.0)];
    [self.mediaCenterStatusField setFrame:NSMakeRect(52.0, height - 334.0, width - 136.0, 18.0)];
    [self.mediaCenterRefreshButton setFrame:NSMakeRect(width - 72.0, height - 342.0, 34.0, 30.0)];
    [self.mediaCenterScrollView setFrame:NSMakeRect(36.0, 24.0, width - 72.0, MAX(120.0, height - 370.0))];
    [self.mediaCenterLoadingSpinner setFrame:NSMakeRect(floor((width - 24.0) / 2.0),
                                                        floor((height - 24.0) / 2.0) - 64.0,
                                                        24.0,
                                                        24.0)];
    if (self.mediaCenterPreviewOverlayView) {
        [self.mediaCenterPreviewOverlayView setFrame:[self.mediaCenterScrollView frame]];
        [self.mediaCenterPreviewCloseButton setFrame:NSMakeRect(NSWidth([self.mediaCenterPreviewOverlayView bounds]) - 44.0,
                                                                NSHeight([self.mediaCenterPreviewOverlayView bounds]) - 40.0,
                                                                28.0,
                                                                26.0)];
        [self.mediaCenterPreviewTitleField setFrame:NSMakeRect(18.0,
                                                               NSHeight([self.mediaCenterPreviewOverlayView bounds]) - 36.0,
                                                               NSWidth([self.mediaCenterPreviewOverlayView bounds]) - 72.0,
                                                               20.0)];
        [self.mediaCenterPreviewImageView setFrame:NSMakeRect(18.0,
                                                              18.0,
                                                              NSWidth([self.mediaCenterPreviewOverlayView bounds]) - 36.0,
                                                              MAX(80.0, NSHeight([self.mediaCenterPreviewOverlayView bounds]) - 64.0))];
    }
}

- (void)buildMediaCenterGridRowsWithItems:(NSArray *)items width:(CGFloat)width {
    CGFloat gap = 8.0;
    CGFloat tileWidth = 112.0;
    CGFloat tileHeight = 136.0;
    NSUInteger columns = (NSUInteger)floor((width + gap) / (tileWidth + gap));
    if (columns < 2) {
        columns = 2;
    }
    tileWidth = floor((width - gap * ((CGFloat)columns + 1.0)) / (CGFloat)columns);
    if (tileWidth > 132.0) {
        tileWidth = 132.0;
    }
    NSUInteger rows = ([items count] == 0) ? 1 : (([items count] + columns - 1) / columns);
    CGFloat contentHeight = gap + (CGFloat)rows * (tileHeight + gap);
    [self.mediaCenterResultsView setFrame:NSMakeRect(0.0, 0.0, width, MAX(100.0, contentHeight))];

    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        TGMessageItem *item = [items objectAtIndex:index];
        NSUInteger column = index % columns;
        NSUInteger rowIndex = index / columns;
        CGFloat tileX = gap + (CGFloat)column * (tileWidth + gap);
        CGFloat tileY = gap + (CGFloat)rowIndex * (tileHeight + gap);
        TGGroupedCardView *tile = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(tileX, tileY, tileWidth, tileHeight)] autorelease];
        [self.mediaCenterResultsView addSubview:tile];

        NSRect previewRect = NSMakeRect(8.0, 8.0, tileWidth - 16.0, 86.0);
        NSImage *thumbnail = TGMediaCenterThumbnailForItem(item);
        if (thumbnail) {
            NSImageView *imageView = [[[NSImageView alloc] initWithFrame:previewRect] autorelease];
            [imageView setImage:thumbnail];
            [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
            [imageView setImageFrameStyle:NSImageFrameNone];
            [tile addSubview:imageView];
        } else {
            NSTextField *typeField = [self labelWithFrame:NSMakeRect(10.0, 32.0, tileWidth - 20.0, 24.0)
                                                     text:TGMediaCenterTypeTitleForItem(item)
                                                     font:[NSFont boldSystemFontOfSize:13.0]];
            [typeField setAlignment:NSCenterTextAlignment];
            [tile addSubview:typeField];
        }

        NSString *titleText = TGMediaCenterTitleForItem(item);
        NSTextField *title = [self labelWithFrame:NSMakeRect(8.0, 99.0, tileWidth - 16.0, 18.0)
                                             text:titleText
                                             font:[NSFont boldSystemFontOfSize:11.0]];
        [[title cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [tile addSubview:title];

        NSString *details = [NSString stringWithFormat:@"%@ · %@",
                             TGMediaCenterReadableSize(TGMediaCenterSizeForItem(item)),
                             TGMediaCenterDateStringForItem(item)];
        NSTextField *subtitle = [self labelWithFrame:NSMakeRect(8.0, 116.0, tileWidth - 16.0, 16.0)
                                                text:details
                                                font:[NSFont systemFontOfSize:10.0]];
        [[subtitle cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [self applyMutedLabelStyle:subtitle];
        [tile addSubview:subtitle];

        NSButton *button = [[[TGPointingHandButton alloc] initWithFrame:[tile bounds]] autorelease];
        [button setTitle:@""];
        [button setBordered:NO];
        [button setTransparent:YES];
        [button setTarget:self];
        [button setAction:@selector(previewMediaCenterItem:)];
        [button setTag:(NSInteger)index];
        [button setMenu:[self mediaCenterContextMenuForIndex:index]];
        [tile addSubview:button];
    }
}

- (void)buildMediaCenterListRowsWithItems:(NSArray *)items width:(CGFloat)width {
    CGFloat rowHeight = 74.0;
    CGFloat gap = 8.0;
    CGFloat contentHeight = gap + (CGFloat)[items count] * (rowHeight + gap);
    [self.mediaCenterResultsView setFrame:NSMakeRect(0.0, 0.0, width, MAX(100.0, contentHeight))];

    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        TGMessageItem *item = [items objectAtIndex:index];
        CGFloat y = gap + (CGFloat)index * (rowHeight + gap);
        TGGroupedCardView *row = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(gap, y, width - gap * 2.0, rowHeight)] autorelease];
        [self.mediaCenterResultsView addSubview:row];

        NSImage *thumbnail = TGMediaCenterThumbnailForItem(item);
        if (thumbnail) {
            NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(12.0, 12.0, 50.0, 50.0)] autorelease];
            [imageView setImage:thumbnail];
            [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
            [row addSubview:imageView];
        } else {
            TGGroupedCardView *badge = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(12.0, 12.0, 50.0, 50.0)] autorelease];
            [row addSubview:badge];
            NSTextField *badgeText = [self labelWithFrame:NSMakeRect(0.0, 16.0, 50.0, 18.0)
                                                     text:TGMediaCenterExtensionBadgeForItem(item)
                                                     font:[NSFont boldSystemFontOfSize:12.0]];
            [badgeText setAlignment:NSCenterTextAlignment];
            [badge addSubview:badgeText];
        }

        NSTextField *title = [self labelWithFrame:NSMakeRect(76.0, 16.0, NSWidth([row bounds]) - 94.0, 22.0)
                                             text:TGMediaCenterTitleForItem(item)
                                             font:[NSFont boldSystemFontOfSize:13.0]];
        [[title cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [row addSubview:title];

        NSString *details = [NSString stringWithFormat:@"%@ · %@ · %@",
                             TGMediaCenterTypeTitleForItem(item),
                             TGMediaCenterReadableSize(TGMediaCenterSizeForItem(item)),
                             TGMediaCenterDateStringForItem(item)];
        NSTextField *subtitle = [self labelWithFrame:NSMakeRect(76.0, 40.0, NSWidth([row bounds]) - 94.0, 18.0)
                                                text:details
                                                font:[NSFont systemFontOfSize:12.0]];
        [[subtitle cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [self applyMutedLabelStyle:subtitle];
        [row addSubview:subtitle];

        NSButton *button = [[[TGPointingHandButton alloc] initWithFrame:[row bounds]] autorelease];
        [button setTitle:@""];
        [button setBordered:NO];
        [button setTransparent:YES];
        [button setTarget:self];
        [button setAction:@selector(previewMediaCenterItem:)];
        [button setTag:(NSInteger)index];
        [button setMenu:[self mediaCenterContextMenuForIndex:index]];
        [row addSubview:button];
    }
}

- (void)buildMediaCenterGroupRowsWithItems:(NSArray *)items width:(CGFloat)width {
    CGFloat rowHeight = 66.0;
    CGFloat gap = 8.0;
    CGFloat contentHeight = gap + (CGFloat)[items count] * (rowHeight + gap);
    [self.mediaCenterResultsView setFrame:NSMakeRect(0.0, 0.0, width, MAX(100.0, contentHeight))];

    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id object = [items objectAtIndex:index];
        if (![object isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *chatItem = (TGChatItem *)object;
        CGFloat y = gap + (CGFloat)index * (rowHeight + gap);
        TGGroupedCardView *row = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(gap, y, width - gap * 2.0, rowHeight)] autorelease];
        [self.mediaCenterResultsView addSubview:row];

        TGProfileAvatarView *avatar = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(12.0, 12.0, 42.0, 42.0)] autorelease];
        [avatar setDisplayName:([chatItem.title length] > 0 ? chatItem.title : @"Group")];
        [avatar setAvatarLocalPath:chatItem.avatarLocalPath];
        [row addSubview:avatar];

        NSTextField *title = [self labelWithFrame:NSMakeRect(68.0, 13.0, NSWidth([row bounds]) - 86.0, 22.0)
                                             text:([chatItem.title length] > 0 ? chatItem.title : TGLoc(@"media.center.group.untitled"))
                                             font:[NSFont boldSystemFontOfSize:13.0]];
        [[title cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [row addSubview:title];

        NSString *details = ([chatItem.typeSummary length] > 0 ? chatItem.typeSummary : TGLoc(@"media.center.tab.groups"));
        NSTextField *subtitle = [self labelWithFrame:NSMakeRect(68.0, 36.0, NSWidth([row bounds]) - 86.0, 18.0)
                                                text:details
                                                font:[NSFont systemFontOfSize:12.0]];
        [[subtitle cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [self applyMutedLabelStyle:subtitle];
        [row addSubview:subtitle];
    }
}

- (void)rebuildMediaCenterRows {
    if (!self.mediaCenterResultsView) {
        return;
    }
    NSArray *subviews = [[self.mediaCenterResultsView subviews] copy];
    NSUInteger removeIndex = 0;
    for (removeIndex = 0; removeIndex < [subviews count]; removeIndex++) {
        [[subviews objectAtIndex:removeIndex] removeFromSuperview];
    }
    [subviews release];

    NSInteger selectedTab = self.mediaCenterTabControl ? [self.mediaCenterTabControl selectedSegment] : 0;
    NSInteger sortIndex = [self.mediaCenterSortPopUpButton indexOfSelectedItem];
    NSArray *items = nil;
    if (TGMediaCenterSelectionUsesGroups(selectedTab)) {
        items = [[self.mediaCenterItems sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
            NSString *leftTitle = [left isKindOfClass:[TGChatItem class]] ? [(TGChatItem *)left title] : @"";
            NSString *rightTitle = [right isKindOfClass:[TGChatItem class]] ? [(TGChatItem *)right title] : @"";
            return [leftTitle localizedCaseInsensitiveCompare:rightTitle];
        }] retain];
    } else {
        items = [[self.mediaCenterItems sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
            return TGMediaCenterCompareItems(left, right, sortIndex);
        }] retain];
    }

    CGFloat width = MAX(420.0, NSWidth([self.mediaCenterScrollView bounds]) - 18.0);

    if ([items count] == 0) {
        NSTextField *empty = [self labelWithFrame:NSMakeRect(18.0, 34.0, width - 36.0, 20.0)
                                             text:(self.mediaCenterLoading ? TGLoc(@"media.center.loading") : (TGMediaCenterSelectionUsesGroups(selectedTab) ? TGLoc(@"media.center.groups.empty") : TGLoc(@"media.center.empty")))
                                             font:[NSFont systemFontOfSize:13.0]];
        [self applyMutedLabelStyle:empty];
        [self.mediaCenterResultsView addSubview:empty];
        [items release];
        return;
    }

    if (TGMediaCenterSelectionUsesGroups(selectedTab)) {
        [self buildMediaCenterGroupRowsWithItems:items width:width];
    } else if (TGMediaCenterSelectionUsesGrid(selectedTab)) {
        [self buildMediaCenterGridRowsWithItems:items width:width];
    } else {
        [self buildMediaCenterListRowsWithItems:items width:width];
    }
    [[self.mediaCenterScrollView contentView] scrollToPoint:NSMakePoint(0.0, 0.0)];
    [self.mediaCenterScrollView reflectScrolledClipView:[self.mediaCenterScrollView contentView]];
    [items release];
}

- (TGMessageItem *)mediaCenterItemForSender:(id)sender {
    NSInteger index = [sender respondsToSelector:@selector(tag)] ? [sender tag] : -1;
    NSInteger selectedTab = self.mediaCenterTabControl ? [self.mediaCenterTabControl selectedSegment] : 0;
    if (TGMediaCenterSelectionUsesGroups(selectedTab)) {
        return nil;
    }
    NSArray *items = [self.mediaCenterItems sortedArrayUsingComparator:^NSComparisonResult(id left, id right) {
        return TGMediaCenterCompareItems(left, right, [self.mediaCenterSortPopUpButton indexOfSelectedItem]);
    }];
    if (index < 0 || (NSUInteger)index >= [items count]) {
        return nil;
    }
    id object = [items objectAtIndex:(NSUInteger)index];
    return [object isKindOfClass:[TGMessageItem class]] ? (TGMessageItem *)object : nil;
}

- (void)reloadMediaCenter:(id)sender {
    (void)sender;
    [self ensureMediaCenterWindow];
    [self layoutMediaCenterWindowSubviews];
    NSNumber *chatID = [self.selectedChatID retain];
    NSNumber *threadID = [self.selectedMessageThreadID retain];
    NSString *topicKind = [self.selectedMessageTopicKind copy];
    NSString *selectedTypeSummary = [self.selectedChatTypeSummary copy];
    NSString *query = nil;
    if (self.mediaCenterSearchField) {
        query = [[self.mediaCenterSearchField stringValue] copy];
    }
    if (!query) {
        query = [@"" copy];
    }
    NSInteger selectedTab = self.mediaCenterTabControl ? [self.mediaCenterTabControl selectedSegment] : 0;
    if (selectedTab < 0) {
        selectedTab = 0;
    }
    BOOL groupsMode = TGMediaCenterSelectionUsesGroups(selectedTab);
    NSArray *filters = [TGMediaCenterFilterIdentifiersForSelection(selectedTab) retain];
    NSUInteger generation = self.mediaCenterGeneration + 1;
    self.mediaCenterGeneration = generation;
    [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.loading")];
    [self closeMediaCenterInlinePreview:nil];
    self.mediaCenterLoading = YES;
    [self.mediaCenterItems removeAllObjects];
    [self rebuildMediaCenterRows];

    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        self.mediaCenterLoading = NO;
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.openChatFirst")];
        [chatID release];
        [threadID release];
        [topicKind release];
        [selectedTypeSummary release];
        [query release];
        [filters release];
        return;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSMutableArray *foundItems = [NSMutableArray array];
        NSMutableSet *seenKeys = [NSMutableSet set];
        NSError *lastError = nil;
        if (groupsMode) {
            NSString *typeSummary = ([selectedTypeSummary length] > 0 ? [selectedTypeSummary lowercaseString] : @"");
            BOOL privateChat = ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] > 0LL);
            if ([typeSummary rangeOfString:@"private"].location != NSNotFound) {
                privateChat = YES;
            }
            if (!privateChat) {
                lastError = [NSError errorWithDomain:@"TelegraphicaMediaCenter"
                                                code:601
                                            userInfo:[NSDictionary dictionaryWithObject:TGLoc(@"media.center.groups.privateOnly")
                                                                                 forKey:NSLocalizedDescriptionKey]];
            } else {
                NSError *groupsError = nil;
                NSArray *groups = [client commonGroupChatPreviewItemsForUserID:chatID limit:36 timeout:8.0 error:&groupsError];
                if (groups) {
                    [foundItems addObjectsFromArray:groups];
                } else {
                    lastError = groupsError;
                }
            }
        } else {
            NSUInteger filterIndex = 0;
            for (filterIndex = 0; filterIndex < [filters count]; filterIndex++) {
                NSString *filter = [filters objectAtIndex:filterIndex];
                NSError *searchError = nil;
                NSArray *results = [client searchMessagePreviewItemsForChatID:chatID
                                                               messageThreadID:threadID
                                                              messageTopicKind:topicKind
                                                                         query:query
                                                                        filter:filter
                                                                 fromMessageID:nil
                                                                         limit:36
                                                                       timeout:8.0
                                                                         error:&searchError];
                if (!results) {
                    lastError = searchError;
                    continue;
                }
                NSUInteger resultIndex = 0;
                for (resultIndex = 0; resultIndex < [results count]; resultIndex++) {
                    TGMessageItem *item = [results objectAtIndex:resultIndex];
                    NSString *key = [NSString stringWithFormat:@"%@:%@",
                                     [item chatID] ? [item chatID] : chatID,
                                     [item messageID] ? [item messageID] : [NSNumber numberWithUnsignedInteger:resultIndex]];
                    if (![seenKeys containsObject:key]) {
                        [seenKeys addObject:key];
                        [foundItems addObject:item];
                    }
                }
            }
        }
        NSString *errorMessage = [[lastError localizedDescription] copy];
        NSArray *itemsCopy = [foundItems copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.mediaCenterGeneration == generation) {
                self.mediaCenterLoading = NO;
                [self.mediaCenterItems removeAllObjects];
                [self.mediaCenterItems addObjectsFromArray:itemsCopy];
                unsigned long long cacheBytes = 0;
                NSUInteger cacheIndex = 0;
                for (cacheIndex = 0; cacheIndex < [self.mediaCenterItems count]; cacheIndex++) {
                    id object = [self.mediaCenterItems objectAtIndex:cacheIndex];
                    if ([object isKindOfClass:[TGMessageItem class]]) {
                        cacheBytes += TGMediaCenterFileSizeAtPath(TGMediaCenterLocalPathForItem((TGMessageItem *)object));
                    }
                }
                if ([self.mediaCenterItems count] > 0 && groupsMode) {
                    [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.groups.loadedStatus"),
                                                                 (unsigned long)[self.mediaCenterItems count]]];
                } else if ([self.mediaCenterItems count] > 0) {
                    [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.loadedStatus"),
                                                                 (unsigned long)[self.mediaCenterItems count],
                                                                 TGMediaCenterReadableSize(cacheBytes)]];
                } else if ([errorMessage length] > 0) {
                    [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.failed"), errorMessage]];
                } else {
                    [self.mediaCenterStatusField setStringValue:(groupsMode ? TGLoc(@"media.center.groups.empty") : TGLoc(@"media.center.empty"))];
                }
                [self rebuildMediaCenterRows];
            }
            [itemsCopy release];
            [errorMessage release];
            [chatID release];
            [threadID release];
            [topicKind release];
            [selectedTypeSummary release];
            [query release];
            [filters release];
            [client release];
        });
        [pool drain];
    });
}

- (void)openMediaCenter:(id)sender {
    (void)sender;
    if (!self.selectedChatID) {
        [[TGLogger sharedLogger] log:@"Media Center: open requested without a selected chat."];
        NSBeep();
        return;
    }
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Center: opening for chat=%lld thread=%@.",
                                  [self.selectedChatID longLongValue],
                                  self.selectedMessageThreadID ? [self.selectedMessageThreadID description] : @"none"]];
    @try {
        [[TGLogger sharedLogger] log:@"Media Center: ensuring window."];
        if (self.mediaCenterWindow) {
            [self.mediaCenterWindow close];
            self.mediaCenterWindow = nil;
            self.mediaCenterSearchField = nil;
            self.mediaCenterFilterPopUpButton = nil;
            self.mediaCenterSortPopUpButton = nil;
            self.mediaCenterStatusField = nil;
            self.mediaCenterScrollView = nil;
            self.mediaCenterResultsView = nil;
            self.mediaCenterTabControl = nil;
            self.mediaCenterRefreshButton = nil;
            self.mediaCenterLoadingSpinner = nil;
            self.mediaCenterPreviewOverlayView = nil;
            self.mediaCenterPreviewImageView = nil;
            self.mediaCenterPreviewTitleField = nil;
            self.mediaCenterPreviewCloseButton = nil;
        }
        [self ensureMediaCenterWindow];
        if (!self.mediaCenterWindow) {
            [[TGLogger sharedLogger] log:@"Media Center: failed to create window."];
            NSBeep();
            return;
        }
        [[TGLogger sharedLogger] log:@"Media Center: laying out window."];
        [self layoutMediaCenterWindowSubviews];
        if ([self.mediaCenterWindow isMiniaturized]) {
            [[TGLogger sharedLogger] log:@"Media Center: deminiaturizing window."];
            [self.mediaCenterWindow deminiaturize:self];
        }
        [[TGLogger sharedLogger] log:@"Media Center: ordering window front."];
        [self.mediaCenterWindow center];
        [self.mediaCenterWindow makeKeyAndOrderFront:self];
        [self.mediaCenterWindow orderFrontRegardless];
        [self.mediaCenterWindow makeFirstResponder:nil];
        [self.mediaCenterWindow displayIfNeeded];
        [NSApp activateIgnoringOtherApps:YES];
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Center: window ordered visible=%@ key=%@ frame=%@.",
                                      [self.mediaCenterWindow isVisible] ? @"yes" : @"no",
                                      [self.mediaCenterWindow isKeyWindow] ? @"yes" : @"no",
                                      NSStringFromRect([self.mediaCenterWindow frame])]];
    } @catch (NSException *exception) {
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Center: open failed with exception %@: %@.",
                                      [exception name],
                                      [exception reason]]];
        NSBeep();
        return;
    }
    [self reloadMediaCenter:nil];
}

- (void)downloadMediaCenterItem:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSNumber *fileID = TGMediaCenterFileIDForItem(item);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.noFileID")];
        return;
    }
    NSNumber *fileIDCopy = [fileID retain];
    TGTDLibClient *client = [self.client retain];
    [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloading")];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *path = [[client downloadedLocalPathForFileID:fileIDCopy timeout:18.0 error:&error] copy];
        NSString *message = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([path length] > 0) {
                [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.downloaded"), [path lastPathComponent]]];
            } else {
                [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:TGLoc(@"media.center.downloadFailed"), ([message length] > 0 ? message : @"TDLib did not return a local path.")]];
            }
            [self rebuildMediaCenterRows];
            [path release];
            [message release];
            [fileIDCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)openMediaCenterItem:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSString *path = TGMediaCenterLocalPathForItem(item);
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.downloadBeforeOpen")];
        return;
    }
    if (![[NSWorkspace sharedWorkspace] openFile:path]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.openFailed")];
    }
}

- (void)closeMediaCenterInlinePreview:(id)sender {
    (void)sender;
    if (self.mediaCenterPreviewOverlayView) {
        [self.mediaCenterPreviewOverlayView removeFromSuperview];
    }
    self.mediaCenterPreviewOverlayView = nil;
    self.mediaCenterPreviewImageView = nil;
    self.mediaCenterPreviewTitleField = nil;
    self.mediaCenterPreviewCloseButton = nil;
}

- (void)previewMediaCenterItem:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    if (!item) {
        return;
    }
    NSString *path = TGMediaCenterLocalPathForItem(item);
    BOOL preferAnimated = ([[item contentType] isEqualToString:@"messageAnimation"]);
    if ([path length] == 0 || ![self openMediaPreviewAtPath:path preferAnimated:preferAnimated]) {
        [self.mediaCenterStatusField setStringValue:TGLoc(@"media.center.previewUnavailable")];
        return;
    }
    [self closeMediaCenterInlinePreview:nil];
}

- (void)goToMediaCenterItem:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    if (!item) {
        return;
    }
    TGSearchResultItem *result = [[[TGSearchResultItem alloc] init] autorelease];
    result.chatID = [item chatID] ? [item chatID] : self.selectedChatID;
    result.messageID = [item messageID];
    result.messageThreadID = self.selectedMessageThreadID;
    result.messageTopicKind = self.selectedMessageTopicKind;
    result.chatTitle = self.selectedChatTitle;
    result.senderName = [item senderDisplayName];
    result.date = [item date];
    result.snippet = TGMediaCenterTitleForItem(item);
    result.mediaType = TGMediaCenterTypeTitleForItem(item);
    result.messageItem = item;
    [self.mediaCenterWindow close];
    [self jumpToSearchResult:result];
}

- (void)deleteLocalMediaCenterItem:(id)sender {
    TGMessageItem *item = [self mediaCenterItemForSender:sender];
    NSString *path = TGMediaCenterLocalPathForItem(item);
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self.mediaCenterStatusField setStringValue:@"No local file to delete."];
        return;
    }
    NSError *error = nil;
    if ([[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
        [self.mediaCenterStatusField setStringValue:@"Deleted local copy only. Cloud message is untouched."];
    } else {
        [self.mediaCenterStatusField setStringValue:[NSString stringWithFormat:@"Could not delete local copy: %@", [error localizedDescription]]];
    }
    [self rebuildMediaCenterRows];
}

- (void)ensureMediaPlaybackWindow {
    if (self.mediaPlaybackWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 520, 360);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Media"];
    [window setMinSize:NSMakeSize(360, 260)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    NSTextField *titleField = [self labelWithFrame:NSMakeRect(88, 88, 284, 18)
                                              text:@"Voice message"
                                              font:[NSFont boldSystemFontOfSize:12.0]];
    [titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:titleField];
    self.mediaPlaybackTitleField = titleField;

    NSView *containerView = [[[NSView alloc] initWithFrame:NSMakeRect(24, 64, 472, 272)] autorelease];
    [containerView setWantsLayer:YES];
    [containerView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:containerView];
    self.mediaPlaybackContainerView = containerView;

    NSButton *playPauseButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 18, 42, 30)] autorelease];
    [playPauseButton setTitle:@"pause"];
    [playPauseButton setCell:[[[TGMediaPlaybackButtonCell alloc] initTextCell:@"pause"] autorelease]];
    [playPauseButton setBordered:NO];
    [playPauseButton setFocusRingType:NSFocusRingTypeNone];
    [playPauseButton setToolTip:@"Play or pause media"];
    [playPauseButton setTarget:self];
    [playPauseButton setAction:@selector(toggleMediaPlayback:)];
    [playPauseButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:playPauseButton];
    self.mediaPlaybackPlayPauseButton = playPauseButton;

    NSSlider *progressSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(88, 61, 220, 22)] autorelease];
    [progressSlider setMinValue:0.0];
    [progressSlider setMaxValue:1.0];
    [progressSlider setDoubleValue:0.0];
    [progressSlider setContinuous:YES];
    [progressSlider setTarget:self];
    [progressSlider setAction:@selector(mediaPlaybackSliderChanged:)];
    [progressSlider setEnabled:NO];
    [progressSlider setAutoresizingMask:NSViewWidthSizable];
    [contentView addSubview:progressSlider];
    self.mediaPlaybackProgressSlider = progressSlider;

    NSTextField *timeField = [self labelWithFrame:NSMakeRect(88, 41, 220, 18)
                                             text:@"0:00 / 0:00"
                                             font:[NSFont systemFontOfSize:12.0]];
    [self applyMutedLabelStyle:timeField];
    [timeField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:timeField];
    self.mediaPlaybackTimeField = timeField;

    NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(376, 18, 120, 30)];
    [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:closeButton];
    self.mediaPlaybackCloseButton = closeButton;

    self.mediaPlaybackWindow = window;
}

- (NSTimeInterval)secondsFromMediaPlaybackTime:(CMTime)time {
    if (CMTIME_IS_INVALID(time) || CMTIME_IS_INDEFINITE(time)) {
        return 0.0;
    }
    Float64 seconds = CMTimeGetSeconds(time);
    if (!isfinite(seconds) || seconds < 0.0) {
        return 0.0;
    }
    return seconds;
}

- (NSTimeInterval)currentMediaPlaybackDuration {
    NSTimeInterval duration = self.mediaPlaybackKnownDuration;
    AVPlayerItem *item = [self.mediaPlaybackPlayer currentItem];
    if (item) {
        NSTimeInterval itemDuration = [self secondsFromMediaPlaybackTime:[item duration]];
        if (itemDuration > 0.0) {
            duration = itemDuration;
        }
    }
    return duration;
}

- (void)updateMediaPlaybackTimelineWithCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
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
    [self.mediaPlaybackProgressSlider setMinValue:0.0];
    [self.mediaPlaybackProgressSlider setMaxValue:sliderMaximum];
    [self.mediaPlaybackProgressSlider setDoubleValue:currentTime];
    [self.mediaPlaybackProgressSlider setEnabled:(duration > 0.0 && self.mediaPlaybackPlayer != nil)];
    [self.mediaPlaybackTimeField setStringValue:[NSString stringWithFormat:@"%@ / %@",
                                                  TGVoicePreviewTimeString(currentTime),
                                                  TGVoicePreviewTimeString(duration)]];
}

- (void)invalidateMediaPlaybackTimer {
    [self.mediaPlaybackTimer invalidate];
    self.mediaPlaybackTimer = nil;
}

- (void)mediaPlaybackTimerDidFire:(NSTimer *)timer {
    (void)timer;
    if (!self.mediaPlaybackPlayer) {
        [self invalidateMediaPlaybackTimer];
        [self updateMediaPlaybackTimelineWithCurrentTime:0.0 duration:0.0];
        return;
    }

    NSTimeInterval duration = [self currentMediaPlaybackDuration];
    NSTimeInterval currentTime = [self secondsFromMediaPlaybackTime:[self.mediaPlaybackPlayer currentTime]];
    if (duration > 0.0 && currentTime >= duration - 0.05 && [self.mediaPlaybackPlayer rate] == 0.0) {
        [self.mediaPlaybackPlayer seekToTime:CMTimeMakeWithSeconds(0.0, 600)];
        self.mediaPlaybackPlaying = NO;
        [self updateMediaPlaybackButton];
        [self invalidateMediaPlaybackTimer];
        [self updateMediaPlaybackTimelineWithCurrentTime:0.0 duration:duration];
        return;
    }
    [self updateMediaPlaybackTimelineWithCurrentTime:currentTime duration:duration];
}

- (void)startMediaPlaybackTimer {
    [self invalidateMediaPlaybackTimer];
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.2
                                             target:self
                                           selector:@selector(mediaPlaybackTimerDidFire:)
                                           userInfo:nil
                                            repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.mediaPlaybackTimer = timer;
}

- (void)mediaPlaybackSliderChanged:(id)sender {
    if (!self.mediaPlaybackPlayer) {
        return;
    }
    NSTimeInterval duration = [self currentMediaPlaybackDuration];
    NSTimeInterval value = [sender respondsToSelector:@selector(doubleValue)] ? [sender doubleValue] : 0.0;
    if (duration > 0.0 && value > duration) {
        value = duration;
    }
    if (value < 0.0) {
        value = 0.0;
    }
    [self.mediaPlaybackPlayer seekToTime:CMTimeMakeWithSeconds(value, 600)];
    [self updateMediaPlaybackTimelineWithCurrentTime:value duration:duration];
}

- (void)layoutMediaPlaybackWindowForAudioOnly:(BOOL)audioOnly title:(NSString *)title {
    [self ensureMediaPlaybackWindow];
    self.mediaPlaybackAudioOnly = audioOnly;

    if (audioOnly) {
        [self.mediaPlaybackWindow setMinSize:NSMakeSize(360.0, 128.0)];
        [self.mediaPlaybackWindow setContentSize:NSMakeSize(430.0, 128.0)];
        [self.mediaPlaybackContainerView setHidden:YES];
        [self.mediaPlaybackTitleField setHidden:NO];
        [self.mediaPlaybackTitleField setStringValue:([title length] > 0 ? title : @"Voice message")];
        [self.mediaPlaybackTitleField setFrame:NSMakeRect(88.0, 91.0, 260.0, 18.0)];
        [self.mediaPlaybackPlayPauseButton setFrame:NSMakeRect(22.0, 38.0, 48.0, 48.0)];
        [self.mediaPlaybackProgressSlider setHidden:NO];
        [self.mediaPlaybackProgressSlider setFrame:NSMakeRect(88.0, 61.0, 220.0, 22.0)];
        [self.mediaPlaybackTimeField setHidden:NO];
        [self.mediaPlaybackTimeField setFrame:NSMakeRect(88.0, 39.0, 220.0, 18.0)];
        [self.mediaPlaybackCloseButton setFrame:NSMakeRect(318.0, 18.0, 88.0, 28.0)];
    } else {
        [self.mediaPlaybackWindow setMinSize:NSMakeSize(360.0, 260.0)];
        [self.mediaPlaybackWindow setContentSize:NSMakeSize(520.0, 360.0)];
        [self.mediaPlaybackContainerView setHidden:NO];
        [self.mediaPlaybackContainerView setFrame:NSMakeRect(24.0, 64.0, 472.0, 272.0)];
        [self.mediaPlaybackTitleField setHidden:YES];
        [self.mediaPlaybackPlayPauseButton setFrame:NSMakeRect(24.0, 18.0, 42.0, 30.0)];
        [self.mediaPlaybackProgressSlider setHidden:YES];
        [self.mediaPlaybackTimeField setHidden:YES];
        [self.mediaPlaybackCloseButton setFrame:NSMakeRect(376.0, 18.0, 120.0, 30.0)];
    }
}

- (void)updateMediaPlaybackButton {
    [self.mediaPlaybackPlayPauseButton setTitle:(self.mediaPlaybackPlaying ? @"pause" : @"play")];
    [self.mediaPlaybackPlayPauseButton setToolTip:(self.mediaPlaybackPlaying ? @"Pause media" : @"Play media")];
    [self.mediaPlaybackPlayPauseButton setNeedsDisplay:YES];
}

- (void)layoutMediaPlaybackLayer {
    if (!self.mediaPlaybackLayer || !self.mediaPlaybackContainerView) {
        return;
    }
    [self.mediaPlaybackLayer setFrame:[self.mediaPlaybackContainerView bounds]];
}

- (void)resetMediaPlaybackState {
    [self invalidateMediaPlaybackTimer];
    [self.mediaPlaybackPlayer pause];
    [self.mediaPlaybackLayer removeFromSuperlayer];
    self.mediaPlaybackPlayer = nil;
    self.mediaPlaybackLayer = nil;
    self.mediaPlaybackPlaying = NO;
    self.mediaPlaybackKnownDuration = 0.0;
    [self updateMediaPlaybackButton];
    [self updateMediaPlaybackTimelineWithCurrentTime:0.0 duration:0.0];
}

- (void)toggleMediaPlayback:(id)sender {
    (void)sender;
    if (!self.mediaPlaybackPlayer) {
        return;
    }
    if (self.mediaPlaybackPlaying) {
        [self.mediaPlaybackPlayer pause];
        self.mediaPlaybackPlaying = NO;
        [self invalidateMediaPlaybackTimer];
    } else {
        NSTimeInterval duration = [self currentMediaPlaybackDuration];
        NSTimeInterval currentTime = [self secondsFromMediaPlaybackTime:[self.mediaPlaybackPlayer currentTime]];
        if (duration > 0.0 && currentTime >= duration - 0.05) {
            [self.mediaPlaybackPlayer seekToTime:CMTimeMakeWithSeconds(0.0, 600)];
        }
        [self.mediaPlaybackPlayer play];
        self.mediaPlaybackPlaying = YES;
        if (self.mediaPlaybackAudioOnly) {
            [self startMediaPlaybackTimer];
        }
    }
    [self updateMediaPlaybackButton];
    [self updateMediaPlaybackTimelineWithCurrentTime:[self secondsFromMediaPlaybackTime:[self.mediaPlaybackPlayer currentTime]]
                                            duration:[self currentMediaPlaybackDuration]];
}

static BOOL TGMediaPlaybackPathLooksUnsupportedOnMavericks(NSString *path, BOOL audioOnly) {
    if (!audioOnly) {
        return NO;
    }
    NSString *extension = [[path pathExtension] lowercaseString];
    return ([extension isEqualToString:@"ogg"] ||
            [extension isEqualToString:@"oga"] ||
            [extension isEqualToString:@"opus"]);
}

static BOOL TGMediaPlaybackMimeLooksUnsupportedOnMavericks(NSString *mimeType, BOOL audioOnly) {
    if (!audioOnly) {
        return NO;
    }
    NSString *mime = [mimeType isKindOfClass:[NSString class]] ? [mimeType lowercaseString] : @"";
    return ([mime rangeOfString:@"ogg"].location != NSNotFound ||
            [mime rangeOfString:@"opus"].location != NSNotFound);
}

- (BOOL)showUnsupportedMavericksVoicePlaybackForPath:(NSString *)path mimeType:(NSString *)mimeType {
    NSString *message = @"This voice message uses Ogg/Opus. OS X 10.9 AVFoundation cannot decode it without a bundled Opus decoder.";
    [self appendDetail:[NSString stringWithFormat:@"Media playback: %@", message]];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Playback: unsupported audio file=%@ mime=%@ reason=%@",
                                  [path length] > 0 ? [path lastPathComponent] : @"unknown",
                                  [mimeType length] > 0 ? mimeType : @"unknown",
                                  message]];
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:@"Voice message cannot be played yet"];
    [alert setInformativeText:message];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    return NO;
}

- (BOOL)openPlayableMediaAtPath:(NSString *)path title:(NSString *)title duration:(NSNumber *)duration audioOnly:(BOOL)audioOnly mimeType:(NSString *)mimeType {
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self appendDetail:@"Playable media file is not available yet."];
        return NO;
    }
    NSString *playablePath = path;
    NSError *transcodeError = nil;
    if (TGVoicePathLooksLikeOggOpus(path, mimeType, audioOnly)) {
        [self.statusField setStringValue:@"Preparing voice..."];
        playablePath = TGPlayableVoicePathByTranscodingIfNeeded(path, mimeType, audioOnly, &transcodeError);
        if ([playablePath length] == 0) {
            NSString *message = [transcodeError localizedDescription];
            if ([message length] == 0) {
                message = @"This voice message uses Ogg/Opus and could not be decoded.";
            }
            [self appendDetail:[NSString stringWithFormat:@"Media playback: %@", message]];
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Playback: Opus transcode failed file=%@ mime=%@ reason=%@",
                                          [path lastPathComponent],
                                          [mimeType length] > 0 ? mimeType : @"unknown",
                                          message]];
            return [self showUnsupportedMavericksVoicePlaybackForPath:path mimeType:mimeType];
        }
    } else if (TGMediaPlaybackPathLooksUnsupportedOnMavericks(path, audioOnly) ||
               TGMediaPlaybackMimeLooksUnsupportedOnMavericks(mimeType, audioOnly)) {
        return [self showUnsupportedMavericksVoicePlaybackForPath:path mimeType:mimeType];
    }

    [self ensureMediaPlaybackWindow];
    [self resetMediaPlaybackState];
    [self layoutMediaPlaybackWindowForAudioOnly:audioOnly title:title];
    self.mediaPlaybackKnownDuration = ([duration respondsToSelector:@selector(doubleValue)] && [duration doubleValue] > 0.0) ? [duration doubleValue] : 0.0;

    NSURL *url = [NSURL fileURLWithPath:playablePath];
    AVPlayer *player = [[[AVPlayer alloc] initWithURL:url] autorelease];
    if (!player) {
        [self appendDetail:@"Could not create media player."];
        return NO;
    }

    self.mediaPlaybackPlayer = player;
    if (!audioOnly) {
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
        [layer setVideoGravity:AVLayerVideoGravityResizeAspect];
        [layer setFrame:[self.mediaPlaybackContainerView bounds]];
        [[self.mediaPlaybackContainerView layer] addSublayer:layer];
        self.mediaPlaybackLayer = layer;
    }
    self.mediaPlaybackPlaying = YES;
    [self updateMediaPlaybackButton];
    [self.mediaPlaybackWindow setTitle:([title length] > 0 ? title : @"Media")];
    [self.mediaPlaybackWindow center];
    [self.mediaPlaybackWindow makeKeyAndOrderFront:nil];
    [self layoutMediaPlaybackLayer];
    [self updateMediaPlaybackTimelineWithCurrentTime:0.0 duration:[self currentMediaPlaybackDuration]];
    [self.mediaPlaybackPlayer play];
    if (audioOnly) {
        [self startMediaPlaybackTimer];
    }
    return YES;
}

- (BOOL)openPlayableMediaAtPath:(NSString *)path title:(NSString *)title duration:(NSNumber *)duration audioOnly:(BOOL)audioOnly {
    return [self openPlayableMediaAtPath:path title:title duration:duration audioOnly:audioOnly mimeType:nil];
}

- (NSString *)titleForMediaItem:(NSDictionary *)mediaItem {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return @"Media";
    }
    id typeObject = [mediaItem objectForKey:@"content_type"];
    NSString *contentType = [typeObject isKindOfClass:[NSString class]] ? (NSString *)typeObject : nil;
    if ([contentType isEqualToString:@"messageVideoNote"]) {
        return @"Video message";
    }
    if ([contentType isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([contentType isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
    if ([mimeType hasPrefix:@"video/"]) {
        return @"Video";
    }
    if ([mimeType hasPrefix:@"audio/"]) {
        return @"Audio";
    }
    return TGMediaItemPlaceholder(mediaItem);
}

- (void)openPlayableMediaForMediaItem:(NSDictionary *)mediaItem {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return;
    }

    NSString *path = TGMediaItemPlayableLocalPath(mediaItem);
    if ([path length] == 0) {
        path = TGMediaItemFullLocalPath(mediaItem);
    }
    if ([path length] == 0) {
        path = TGMediaItemLocalPath(mediaItem);
    }
    if ([path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self openPlayableMediaAtPath:path
                                title:[self titleForMediaItem:mediaItem]
                             duration:[mediaItem objectForKey:@"duration"]
                            audioOnly:TGMediaItemIsAudioOnlyPlayable(mediaItem)
                              mimeType:[mediaItem objectForKey:@"mime_type"]];
        return;
    }

    NSNumber *fileID = TGMediaItemFullFileID(mediaItem);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self appendDetail:@"Playable media does not have a downloadable file id yet."];
        return;
    }

    NSNumber *fileIDCopy = [fileID retain];
    NSString *titleCopy = [[self titleForMediaItem:mediaItem] copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Loading media..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSString *downloadedPath = [[client downloadedLocalPathForFileID:fileIDCopy timeout:12.0 error:&downloadError] copy];
        NSString *downloadErrorMessage = [[downloadError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([downloadedPath length] > 0) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:@"Connected"];
                [self openPlayableMediaAtPath:downloadedPath
                                        title:titleCopy
                                     duration:[mediaItem objectForKey:@"duration"]
                                    audioOnly:TGMediaItemIsAudioOnlyPlayable(mediaItem)
                                      mimeType:[mediaItem objectForKey:@"mime_type"]];
            } else {
                NSString *message = ([downloadErrorMessage length] > 0) ? downloadErrorMessage : @"TDLib did not return a playable media file yet.";
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Media playback will be available after the file can download."];
                } else {
                    [self.statusField setStringValue:@"Connected"];
                }
                [self appendDetail:[NSString stringWithFormat:@"Media playback: %@", message]];
            }
            [downloadedPath release];
            [downloadErrorMessage release];
            [fileIDCopy release];
            [titleCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)openPlayableMediaForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isPlayableMediaMessage]) {
        return;
    }

    NSString *path = [item mediaLocalPath];
    if ([path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self openPlayableMediaAtPath:path
                                title:TGPlayableMediaTitleForMessageItem(item)
                             duration:[item mediaDuration]
                            audioOnly:TGMessageItemIsAudioOnlyPlayableMedia(item)
                              mimeType:[item mediaMimeType]];
        return;
    }

    NSNumber *fileID = [item mediaFileID];
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        [self appendDetail:@"Playable message does not have a downloadable file id yet."];
        return;
    }

    NSNumber *fileIDCopy = [fileID retain];
    NSString *titleCopy = [TGPlayableMediaTitleForMessageItem(item) copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Loading media..."];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSString *downloadedPath = [[client downloadedLocalPathForFileID:fileIDCopy timeout:12.0 error:&downloadError] copy];
        NSString *downloadErrorMessage = [[downloadError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([downloadedPath length] > 0) {
                [self setOfflineModeActive:NO reason:nil];
                [self.statusField setStringValue:@"Connected"];
                [self openPlayableMediaAtPath:downloadedPath
                                        title:titleCopy
                                     duration:[item mediaDuration]
                                    audioOnly:TGMessageItemIsAudioOnlyPlayableMedia(item)
                                      mimeType:[item mediaMimeType]];
            } else {
                NSString *message = ([downloadErrorMessage length] > 0) ? downloadErrorMessage : @"TDLib did not return a playable media file yet.";
                if (TGStatusErrorLooksOffline(message)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Media playback will be available after the file can download."];
                } else {
                    [self.statusField setStringValue:@"Connected"];
                }
                [self appendDetail:[NSString stringWithFormat:@"Media playback: %@", message]];
            }
            [downloadedPath release];
            [downloadErrorMessage release];
            [fileIDCopy release];
            [titleCopy release];
            [client release];
        });
        [pool drain];
    });
}

- (void)layoutMediaPreviewWindowControls {
    if (!self.mediaPreviewWindow || !self.mediaPreviewScrollView) {
        return;
    }

    NSView *contentView = [self.mediaPreviewWindow contentView];
    NSRect bounds = [contentView bounds];
    CGFloat bottomBarHeight = 58.0;
    [self.mediaPreviewScrollView setFrame:NSMakeRect(16.0,
                                                     bottomBarHeight,
                                                     MAX(120.0, NSWidth(bounds) - 32.0),
                                                     MAX(80.0, NSHeight(bounds) - bottomBarHeight - 16.0))];

    CGFloat buttonSide = 34.0;
    CGFloat fitWidth = 74.0;
    CGFloat gap = 10.0;
    CGFloat controlsWidth = buttonSide + gap + fitWidth + gap + buttonSide;
    CGFloat startX = floor((NSWidth(bounds) - controlsWidth) / 2.0);
    CGFloat y = 18.0;
    [self.mediaPreviewZoomOutButton setFrame:NSMakeRect(startX, y, buttonSide, 30.0)];
    [self.mediaPreviewFitButton setFrame:NSMakeRect(startX + buttonSide + gap, y, fitWidth, 30.0)];
    [self.mediaPreviewZoomInButton setFrame:NSMakeRect(startX + buttonSide + gap + fitWidth + gap, y, buttonSide, 30.0)];
}

- (void)resizeMediaPreviewWindowForImage:(NSImage *)image {
    if (!image || !self.mediaPreviewWindow) {
        return;
    }

    NSSize imageSize = [image size];
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        return;
    }

    NSScreen *screen = [self.mediaPreviewWindow screen];
    if (!screen) {
        screen = [NSScreen mainScreen];
    }
    NSRect visibleFrame = [screen visibleFrame];
    CGFloat maxWindowWidth = floor(NSWidth(visibleFrame) * 0.70);
    CGFloat maxWindowHeight = floor(NSHeight(visibleFrame) * 0.70);
    if (maxWindowWidth < 240.0) {
        maxWindowWidth = 240.0;
    }
    if (maxWindowHeight < 260.0) {
        maxWindowHeight = 260.0;
    }

    CGFloat chromeWidth = 32.0;
    CGFloat chromeHeight = 74.0;
    CGFloat availableImageWidth = MAX(160.0, maxWindowWidth - chromeWidth);
    CGFloat availableImageHeight = MAX(120.0, maxWindowHeight - chromeHeight);
    CGFloat scaleX = availableImageWidth / imageSize.width;
    CGFloat scaleY = availableImageHeight / imageSize.height;
    CGFloat scale = MIN(scaleX, scaleY);
    if (scale > 1.0) {
        scale = 1.0;
    }
    if (scale <= 0.0) {
        scale = 1.0;
    }

    CGFloat contentWidth = ceil(imageSize.width * scale) + chromeWidth;
    CGFloat contentHeight = ceil(imageSize.height * scale) + chromeHeight;
    if (contentWidth < 240.0) {
        contentWidth = 240.0;
    }
    if (contentHeight < 260.0) {
        contentHeight = 260.0;
    }
    if (contentWidth > maxWindowWidth) {
        contentWidth = maxWindowWidth;
    }
    if (contentHeight > maxWindowHeight) {
        contentHeight = maxWindowHeight;
    }

    [self.mediaPreviewWindow setMinSize:NSMakeSize(240.0, 220.0)];
    [self.mediaPreviewWindow setContentSize:NSMakeSize(contentWidth, contentHeight)];
    [self layoutMediaPreviewWindowControls];
}

- (void)ensureMediaPreviewWindow {
    if (self.mediaPreviewWindow) {
        return;
    }

    NSRect frame = NSMakeRect(0, 0, 520, 420);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@""];
    [window setMinSize:NSMakeSize(240, 220)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];

    TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [window setContentView:contentView];

    TGMediaPreviewScrollView *scrollView = [[[TGMediaPreviewScrollView alloc] initWithFrame:NSMakeRect(16, 58, 488, 346)] autorelease];
    [scrollView setMagnificationTarget:self];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [scrollView setBorderType:NSNoBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];

    TGMediaPreviewImageView *imageView = [[[TGMediaPreviewImageView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)] autorelease];
    [imageView setMagnificationTarget:self];
    [imageView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [imageView setImageFrameStyle:NSImageFrameNone];
    [imageView setAnimates:YES];
    [scrollView setDocumentView:imageView];
    [contentView addSubview:scrollView];
    self.mediaPreviewScrollView = scrollView;
    self.mediaPreviewImageView = imageView;

    NSButton *zoomOutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(16, 18, 42, 30)] autorelease];
    [zoomOutButton setTitle:@"zoom-out"];
    [zoomOutButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"zoom-out"] autorelease]];
    [zoomOutButton setBordered:NO];
    [zoomOutButton setFocusRingType:NSFocusRingTypeNone];
    [zoomOutButton setToolTip:@"Zoom out"];
    [zoomOutButton setTarget:self];
    [zoomOutButton setAction:@selector(zoomOutMediaPreview:)];
    [zoomOutButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
    [contentView addSubview:zoomOutButton];
    self.mediaPreviewZoomOutButton = zoomOutButton;

    NSButton *fitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(66, 18, 74, 30)] autorelease];
    [fitButton setTitle:@"Fit"];
    [fitButton setToolTip:@"Fit media to window"];
    [fitButton setTarget:self];
    [fitButton setAction:@selector(fitMediaPreview:)];
    [self applyUtilityButtonStyle:fitButton];
    [fitButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
    [contentView addSubview:fitButton];
    self.mediaPreviewFitButton = fitButton;

    NSButton *zoomInButton = [[[NSButton alloc] initWithFrame:NSMakeRect(148, 18, 42, 30)] autorelease];
    [zoomInButton setTitle:@"zoom-in"];
    [zoomInButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"zoom-in"] autorelease]];
    [zoomInButton setBordered:NO];
    [zoomInButton setFocusRingType:NSFocusRingTypeNone];
    [zoomInButton setToolTip:@"Zoom in"];
    [zoomInButton setTarget:self];
    [zoomInButton setAction:@selector(zoomInMediaPreview:)];
    [zoomInButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
    [contentView addSubview:zoomInButton];
    self.mediaPreviewZoomInButton = zoomInButton;

    self.mediaPreviewWindow = window;
    [self layoutMediaPreviewWindowControls];
}

- (void)applyMediaPreviewZoomScale:(CGFloat)scale {
    NSImage *image = [self.mediaPreviewImageView image];
    if (!image) {
        return;
    }

    if (scale < 0.10) {
        scale = 0.10;
    }
    if (scale > 6.0) {
        scale = 6.0;
    }
    self.mediaPreviewZoomScale = scale;

    NSSize imageSize = [image size];
    CGFloat width = ceil(imageSize.width * scale);
    CGFloat height = ceil(imageSize.height * scale);
    if (width < 1.0) {
        width = 1.0;
    }
    if (height < 1.0) {
        height = 1.0;
    }
    [self.mediaPreviewImageView setFrame:NSMakeRect(0, 0, width, height)];
    [self.mediaPreviewImageView setNeedsDisplay:YES];
}

- (void)fitMediaPreview:(id)sender {
    (void)sender;
    NSImage *image = [self.mediaPreviewImageView image];
    if (!image) {
        return;
    }

    NSSize imageSize = [image size];
    NSRect visibleRect = [[self.mediaPreviewScrollView contentView] bounds];
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0 || NSWidth(visibleRect) <= 0.0 || NSHeight(visibleRect) <= 0.0) {
        [self applyMediaPreviewZoomScale:1.0];
        return;
    }

    CGFloat scaleX = NSWidth(visibleRect) / imageSize.width;
    CGFloat scaleY = NSHeight(visibleRect) / imageSize.height;
    CGFloat scale = (scaleX < scaleY) ? scaleX : scaleY;
    if (scale > 1.0) {
        scale = 1.0;
    }
    [self applyMediaPreviewZoomScale:scale];
}

- (void)zoomInMediaPreview:(id)sender {
    (void)sender;
    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    [self applyMediaPreviewZoomScale:scale * 1.25];
}

- (void)zoomOutMediaPreview:(id)sender {
    (void)sender;
    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    [self applyMediaPreviewZoomScale:scale / 1.25];
}

- (void)mediaPreviewView:(id)sender didMagnifyBy:(NSNumber *)magnificationNumber {
    (void)sender;
    CGFloat delta = [magnificationNumber respondsToSelector:@selector(doubleValue)] ? (CGFloat)[magnificationNumber doubleValue] : 0.0;
    if (delta > -0.002 && delta < 0.002) {
        return;
    }

    CGFloat scale = self.mediaPreviewZoomScale > 0.0 ? self.mediaPreviewZoomScale : 1.0;
    CGFloat factor = 1.0 + delta;
    if (factor < 0.25) {
        factor = 0.25;
    }
    if (factor > 4.0) {
        factor = 4.0;
    }
    [self applyMediaPreviewZoomScale:scale * factor];
}

- (BOOL)openMediaPreviewAtPath:(NSString *)path preferAnimated:(BOOL)preferAnimated {
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [self appendDetail:@"Media preview file is not available yet."];
        return NO;
    }

    NSString *extension = [[path pathExtension] lowercaseString];
    BOOL likelyAnimated = preferAnimated || [extension isEqualToString:@"gif"];
    NSImage *image = nil;
    if (likelyAnimated) {
        image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    }
    if (!image) {
        image = TGImageWithCorrectOrientationFromFile(path);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
    }
    if (!image) {
        [self appendDetail:@"Could not open media preview."];
        return NO;
    }

    [self ensureMediaPreviewWindow];
    self.mediaPreviewPath = path;
    [self.mediaPreviewImageView setImage:image];
    [self.mediaPreviewImageView setAnimates:YES];
    [self.mediaPreviewWindow setTitle:@""];
    [self resizeMediaPreviewWindowForImage:image];
    [self fitMediaPreview:nil];
    [self.mediaPreviewWindow center];
    [self.mediaPreviewWindow makeKeyAndOrderFront:nil];
    [self.mediaPreviewWindow makeFirstResponder:self.mediaPreviewImageView];
    return YES;
}

- (BOOL)openMediaPreviewAtPath:(NSString *)path {
    return [self openMediaPreviewAtPath:path preferAnimated:NO];
}

- (void)openMediaPreviewForMediaItem:(NSDictionary *)mediaItem {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return;
    }
    if (!TGMediaItemSupportsPreview(mediaItem)) {
        return;
    }
    if (TGMediaItemIsPlayable(mediaItem)) {
        [self openPlayableMediaForMediaItem:mediaItem];
        return;
    }

    NSUInteger requestGeneration = self.mediaPreviewRequestGeneration + 1;
    self.mediaPreviewRequestGeneration = requestGeneration;
    BOOL preferAnimated = TGMediaItemIsAnimation(mediaItem);
    NSString *fullPath = TGMediaItemFullLocalPath(mediaItem);
    if ([fullPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        if ([self openMediaPreviewAtPath:fullPath preferAnimated:preferAnimated]) {
            return;
        }
        NSString *fallbackPath = TGMediaItemLocalPath(mediaItem);
        if ([fallbackPath length] > 0 && ![fallbackPath isEqualToString:fullPath]) {
            [self openMediaPreviewAtPath:fallbackPath];
        }
        return;
    }

    NSString *fallbackPath = TGMediaItemLocalPath(mediaItem);
    NSNumber *fileID = TGMediaItemFullFileID(mediaItem);
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        if ([fallbackPath length] > 0) {
            [self openMediaPreviewAtPath:fallbackPath];
        }
        return;
    }

    NSNumber *fileIDCopy = [fileID retain];
    NSString *fallbackPathCopy = [fallbackPath copy];
    TGTDLibClient *client = [self.client retain];
    [self.statusField setStringValue:@"Loading full media..."];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *downloadError = nil;
        NSString *downloadedPath = [[client downloadedLocalPathForFileID:fileIDCopy timeout:12.0 error:&downloadError] copy];
        NSString *fallback = [fallbackPathCopy copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestGeneration != self.mediaPreviewRequestGeneration) {
                [downloadedPath release];
                [fallback release];
                [fileIDCopy release];
                [fallbackPathCopy release];
                [client release];
                return;
            }
            if ([downloadedPath length] > 0) {
                if ([self openMediaPreviewAtPath:downloadedPath preferAnimated:preferAnimated]) {
                    [self.statusField setStringValue:@"Connected"];
                } else if ([fallback length] > 0) {
                    [self openMediaPreviewAtPath:fallback];
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:@"Full media format is not previewable yet; opened cached preview."];
                } else {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:@"Full media format is not previewable yet."];
                }
            } else if ([fallback length] > 0) {
                [self openMediaPreviewAtPath:fallback];
                [self.statusField setStringValue:@"Connected"];
                [self appendDetail:@"Full media was not available yet; opened cached preview."];
            } else {
                [self.statusField setStringValue:@"Connected"];
                [self appendDetail:@"Full media was not available yet."];
            }
            [downloadedPath release];
            [fallback release];
            [fileIDCopy release];
            [fallbackPathCopy release];
            [client release];
        });
        [pool drain];
    });
}
