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
    if (maxWindowWidth < 360.0) {
        maxWindowWidth = 360.0;
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
    if (contentWidth < 360.0) {
        contentWidth = 360.0;
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

    [self.mediaPreviewWindow setMinSize:NSMakeSize(320.0, 220.0)];
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
    [window setMinSize:NSMakeSize(320, 220)];
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
    [zoomOutButton setTitle:@""];
    [zoomOutButton setImage:TGTemplateIconAssetImage(@"remove-ellipse", NSMakeSize(18.0, 18.0), TGClassicHeaderTextColor(1.0), 1.0)];
    [zoomOutButton setImagePosition:NSImageOnly];
    [zoomOutButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@""] autorelease]];
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
    [zoomInButton setTitle:@""];
    [zoomInButton setImage:TGTemplateIconAssetImage(@"add-ellipse", NSMakeSize(18.0, 18.0), TGClassicHeaderTextColor(1.0), 1.0)];
    [zoomInButton setImagePosition:NSImageOnly];
    [zoomInButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@""] autorelease]];
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
