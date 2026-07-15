- (NSButton *)resourceSwitchWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 220, 22)] autorelease];
    [button setButtonType:NSSwitchButton];
    [button setTitle:title ? title : @""];
    [button setTarget:self];
    [button setAction:action];
    [button setFont:[NSFont systemFontOfSize:13.0]];
    [button setAutoresizingMask:NSViewMaxYMargin];
    return button;
}

- (NSTextField *)resourceLabelWithTitle:(NSString *)title {
    NSTextField *label = [self labelWithFrame:NSMakeRect(0, 0, 120, 22)
                                         text:title ? title : @""
                                         font:[NSFont systemFontOfSize:13.0]];
    [label setTextColor:TGClassicInkColor()];
    return label;
}

- (NSPopUpButton *)resourcePopUpWithAction:(SEL)action {
    NSPopUpButton *button = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 190, 28) pullsDown:NO] autorelease];
    [button setTarget:self];
    [button setAction:action];
    [button setAutoresizingMask:NSViewMaxYMargin];
    return button;
}

- (void)addByteChoicesToPopUp:(NSPopUpButton *)popUp values:(NSArray *)values {
    [popUp removeAllItems];
    NSUInteger index = 0;
    for (index = 0; index < [values count]; index++) {
        NSNumber *value = [values objectAtIndex:index];
        [popUp addItemWithTitle:TGResourcePolicyReadableSize([value unsignedLongLongValue])];
        [[popUp lastItem] setRepresentedObject:value];
    }
}

- (void)addAnimationChoicesToPopUp:(NSPopUpButton *)popUp values:(NSArray *)values {
    [popUp removeAllItems];
    NSUInteger index = 0;
    for (index = 0; index < [values count]; index++) {
        NSNumber *value = [values objectAtIndex:index];
        [popUp addItemWithTitle:[NSString stringWithFormat:@"%lu", (unsigned long)[value unsignedIntegerValue]]];
        [[popUp lastItem] setRepresentedObject:value];
    }
}

- (void)selectPopUp:(NSPopUpButton *)popUp representedUnsignedLongLong:(unsigned long long)value {
    NSArray *items = [popUp itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSMenuItem *item = [items objectAtIndex:index];
        id represented = [item representedObject];
        if ([represented respondsToSelector:@selector(unsignedLongLongValue)] &&
            [represented unsignedLongLongValue] == value) {
            [popUp selectItem:item];
            return;
        }
    }
    if ([items count] > 0) {
        [popUp selectItemAtIndex:0];
    }
}

- (void)selectPopUp:(NSPopUpButton *)popUp representedUnsignedInteger:(NSUInteger)value {
    NSArray *items = [popUp itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSMenuItem *item = [items objectAtIndex:index];
        id represented = [item representedObject];
        if ([represented respondsToSelector:@selector(unsignedIntegerValue)] &&
            [represented unsignedIntegerValue] == value) {
            [popUp selectItem:item];
            return;
        }
    }
    if ([items count] > 0) {
        [popUp selectItemAtIndex:0];
    }
}

- (void)buildResourceSettingsControlsInContentView:(NSView *)contentView {
    self.settingsEconomyModeButton = [self resourceSwitchWithTitle:@"Economy mode"
                                                            action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsEconomyModeButton];

    self.settingsAutoDownloadPhotosButton = [self resourceSwitchWithTitle:@"Auto-download photos"
                                                                   action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsAutoDownloadPhotosButton];

    self.settingsAutoDownloadVideosButton = [self resourceSwitchWithTitle:@"Auto-download videos"
                                                                   action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsAutoDownloadVideosButton];

    self.settingsAutoDownloadDocumentsButton = [self resourceSwitchWithTitle:@"Auto-download documents"
                                                                      action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsAutoDownloadDocumentsButton];

    self.settingsMaxAutoDownloadLabel = [self resourceLabelWithTitle:@"Max auto-download"];
    [contentView addSubview:self.settingsMaxAutoDownloadLabel];

    self.settingsMaxAutoDownloadPopUpButton = [self resourcePopUpWithAction:@selector(resourcePopUpChanged:)];
    [self addByteChoicesToPopUp:self.settingsMaxAutoDownloadPopUpButton values:TGResourcePolicyMaxAutoDownloadChoices()];
    [contentView addSubview:self.settingsMaxAutoDownloadPopUpButton];

    self.settingsAutoplayAnimatedStickersButton = [self resourceSwitchWithTitle:@"Autoplay animated stickers"
                                                                         action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsAutoplayAnimatedStickersButton];

    self.settingsMaxAnimationsLabel = [self resourceLabelWithTitle:@"Max active animations"];
    [contentView addSubview:self.settingsMaxAnimationsLabel];

    self.settingsMaxAnimationsPopUpButton = [self resourcePopUpWithAction:@selector(resourcePopUpChanged:)];
    [self addAnimationChoicesToPopUp:self.settingsMaxAnimationsPopUpButton values:TGResourcePolicyMaxActiveAnimationChoices()];
    [contentView addSubview:self.settingsMaxAnimationsPopUpButton];

    self.settingsStopInactiveAnimationsButton = [self resourceSwitchWithTitle:@"Stop animations when inactive"
                                                                       action:@selector(resourceSettingChanged:)];
    [contentView addSubview:self.settingsStopInactiveAnimationsButton];

    self.settingsMediaCacheLimitLabel = [self resourceLabelWithTitle:@"Media cache limit"];
    [contentView addSubview:self.settingsMediaCacheLimitLabel];

    self.settingsMediaCacheLimitPopUpButton = [self resourcePopUpWithAction:@selector(resourcePopUpChanged:)];
    [self addByteChoicesToPopUp:self.settingsMediaCacheLimitPopUpButton values:TGResourcePolicyMediaCacheLimitChoices()];
    [contentView addSubview:self.settingsMediaCacheLimitPopUpButton];

    self.settingsResourceHintField = [self labelWithFrame:NSMakeRect(0, 0, 300, 18)
                                                     text:@"Economy mode lowers auto-downloads and animation work. All values stay editable."
                                                     font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:self.settingsResourceHintField];
    [[self.settingsResourceHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [contentView addSubview:self.settingsResourceHintField];

    [self refreshResourceSettingsControls];
}

- (void)refreshResourceSettingsControls {
    [self.settingsEconomyModeButton setState:TGResourcePolicyEconomyModeEnabled() ? NSOnState : NSOffState];
    [self.settingsAutoDownloadPhotosButton setState:TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadPhoto) ? NSOnState : NSOffState];
    [self.settingsAutoDownloadVideosButton setState:TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVideo) ? NSOnState : NSOffState];
    [self.settingsAutoDownloadDocumentsButton setState:TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadDocument) ? NSOnState : NSOffState];
    [self.settingsAutoplayAnimatedStickersButton setState:TGResourcePolicyAutoplayAnimatedStickersEnabled() ? NSOnState : NSOffState];
    [self.settingsStopInactiveAnimationsButton setState:TGResourcePolicyStopAnimationsWhenInactiveEnabled() ? NSOnState : NSOffState];
    [self selectPopUp:self.settingsMaxAutoDownloadPopUpButton representedUnsignedLongLong:TGResourcePolicyMaxAutoDownloadBytes()];
    [self selectPopUp:self.settingsMaxAnimationsPopUpButton representedUnsignedInteger:TGResourcePolicyMaxActiveAnimations()];
    [self selectPopUp:self.settingsMediaCacheLimitPopUpButton representedUnsignedLongLong:TGResourcePolicyMediaCacheLimitBytes()];
}

- (void)resourcePolicyDidChange:(NSNotification *)notification {
    (void)notification;
    [self refreshResourceSettingsControls];
    [self applyResourcePolicyToMediaSubsystems];
}

- (void)applyResourcePolicyToMediaSubsystems {
    NSUInteger maxAnimations = TGResourcePolicyMaxActiveAnimations();
    [self.inlineMediaPlaybackCoordinator setMaximumActiveItems:maxAnimations];
    [self.inlineMediaPlaybackCoordinator setAutoplayEnabled:TGResourcePolicyAutoplayAnimatedStickersEnabled()];
    [self.inlineMediaPlaybackCoordinator setStopWhenApplicationInactive:TGResourcePolicyStopAnimationsWhenInactiveEnabled()];
    [self.stickerPickerPlaybackCoordinator setMaximumActiveItems:maxAnimations];
    [self.stickerPickerPlaybackCoordinator setAutoplayEnabled:TGResourcePolicyAutoplayAnimatedStickersEnabled()];
    [self.stickerPickerPlaybackCoordinator setStopWhenApplicationInactive:TGResourcePolicyStopAnimationsWhenInactiveEnabled()];
    TGMediaImageLoaderSetCacheLimitBytes((NSUInteger)TGResourcePolicyMediaCacheLimitBytes());
    [self scheduleInlineMediaPlaybackRefresh];
    [self refreshStickerPickerPlayback];
}

- (void)resourceSettingChanged:(id)sender {
    if (sender == self.settingsEconomyModeButton) {
        TGResourcePolicySetEconomyModeEnabled([self.settingsEconomyModeButton state] == NSOnState);
        return;
    }
    if (sender == self.settingsAutoDownloadPhotosButton) {
        TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadPhoto, [self.settingsAutoDownloadPhotosButton state] == NSOnState);
    } else if (sender == self.settingsAutoDownloadVideosButton) {
        TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadVideo, [self.settingsAutoDownloadVideosButton state] == NSOnState);
    } else if (sender == self.settingsAutoDownloadDocumentsButton) {
        TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadDocument, [self.settingsAutoDownloadDocumentsButton state] == NSOnState);
    } else if (sender == self.settingsAutoplayAnimatedStickersButton) {
        TGResourcePolicySetAutoplayAnimatedStickersEnabled([self.settingsAutoplayAnimatedStickersButton state] == NSOnState);
    } else if (sender == self.settingsStopInactiveAnimationsButton) {
        TGResourcePolicySetStopAnimationsWhenInactiveEnabled([self.settingsStopInactiveAnimationsButton state] == NSOnState);
    }
    [self applyResourcePolicyToMediaSubsystems];
}

- (void)resourcePopUpChanged:(id)sender {
    id represented = [[sender selectedItem] representedObject];
    if (![represented respondsToSelector:@selector(unsignedLongLongValue)]) {
        return;
    }
    if (sender == self.settingsMaxAutoDownloadPopUpButton) {
        TGResourcePolicySetMaxAutoDownloadBytes([represented unsignedLongLongValue]);
    } else if (sender == self.settingsMediaCacheLimitPopUpButton) {
        TGResourcePolicySetMediaCacheLimitBytes([represented unsignedLongLongValue]);
    } else if (sender == self.settingsMaxAnimationsPopUpButton) {
        TGResourcePolicySetMaxActiveAnimations([represented unsignedIntegerValue]);
    }
    [self applyResourcePolicyToMediaSubsystems];
}
