- (void)buildChatSearchWindowIfNeeded {
    if (self.chatSearchWindow) {
        return;
    }

    self.chatSearchWindow = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 440, 420)
                                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                           backing:NSBackingStoreBuffered
                                                             defer:NO] autorelease];
    [self.chatSearchWindow setTitle:@"Search chats"];
    [self.chatSearchWindow setReleasedWhenClosed:NO];

    TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:NSMakeRect(0, 0, 440, 420)] autorelease];
    [self.chatSearchWindow setContentView:contentView];

    NSTextField *titleField = [[[NSTextField alloc] initWithFrame:NSMakeRect(22, 376, 396, 22)] autorelease];
    [titleField setStringValue:@"Search chats"];
    [titleField setFont:[NSFont boldSystemFontOfSize:16.0]];
    [titleField setTextColor:TGClassicInkColor()];
    [titleField setEditable:NO];
    [titleField setSelectable:NO];
    [titleField setBordered:NO];
    [titleField setDrawsBackground:NO];
    [contentView addSubview:titleField];

    self.chatSearchWindowTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(22, 338, 396, 28)] autorelease];
    [self.chatSearchWindowTextField setFont:[NSFont systemFontOfSize:13.0]];
    [self.chatSearchWindowTextField setPlaceholderString:@"Chat, group, person"];
    [self.chatSearchWindowTextField setTarget:self];
    [self.chatSearchWindowTextField setAction:@selector(chatSearchWindowTextCommitted:)];
    [self.chatSearchWindowTextField setDelegate:self];
    [contentView addSubview:self.chatSearchWindowTextField];

    self.chatSearchWindowStatusField = [self labelWithFrame:NSMakeRect(24, 312, 392, 18)
                                                       text:@"Start typing to find a chat"
                                                       font:[NSFont systemFontOfSize:11.0]];
    [self.chatSearchWindowStatusField setTextColor:TGClassicMutedInkColor()];
    [contentView addSubview:self.chatSearchWindowStatusField];

    self.chatSearchWindowScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 400, 286)] autorelease];
    [self.chatSearchWindowScrollView setBorderType:NSNoBorder];
    [self.chatSearchWindowScrollView setHasVerticalScroller:YES];
    [self.chatSearchWindowScrollView setDrawsBackground:NO];
    self.chatSearchWindowResultsView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 382, 286)] autorelease];
    [self.chatSearchWindowScrollView setDocumentView:self.chatSearchWindowResultsView];
    [contentView addSubview:self.chatSearchWindowScrollView];

    [self applyPointingHandCursorToButtonsInView:contentView];
}

- (void)openChatSearchWindow:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    [self buildChatSearchWindowIfNeeded];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: opening chat search window with %lu visible chat candidate(s).",
                                  (unsigned long)[self.chatItems count]]];
    [self.chatSearchWindowResults removeAllObjects];
    [self.chatSearchWindowTextField setStringValue:@""];
    [self.chatSearchWindowStatusField setStringValue:@"Start typing to find a chat"];
    [self updateChatSearchWindowResults];
    [self.chatSearchWindow center];
    [self.chatSearchWindow makeKeyAndOrderFront:self];
    [self.chatSearchWindow makeFirstResponder:self.chatSearchWindowTextField];
    [self applyPointingHandCursorToButtonsInView:[self.chatSearchWindow contentView]];
}

- (void)closeChatSearchWindow:(id)sender {
    (void)sender;
    [self.chatSearchWindow orderOut:self];
    if ([self.sendTextField isEnabled]) {
        [[self window] makeFirstResponder:self.sendTextField];
    }
}

- (void)clearChatSearchWindowResultButtons {
    NSArray *buttons = [[self.chatSearchWindowResultButtons copy] autorelease];
    NSUInteger index = 0;
    for (index = 0; index < [buttons count]; index++) {
        NSButton *button = [buttons objectAtIndex:index];
        [button removeFromSuperview];
    }
    [self.chatSearchWindowResultButtons removeAllObjects];
}

- (void)updateChatSearchWindowResults {
    [self buildChatSearchWindowIfNeeded];
    NSString *query = [[self.chatSearchWindowTextField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.chatSearchWindowResults removeAllObjects];
    if ([query length] > 0) {
        [self.chatSearchWindowResults addObjectsFromArray:[self localChatSearchResultsForQuery:query]];
    }
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Search: chat search query length=%lu results=%lu.",
                                  (unsigned long)[query length],
                                  (unsigned long)[self.chatSearchWindowResults count]]];

    [self clearChatSearchWindowResultButtons];
    CGFloat rowHeight = 46.0;
    CGFloat width = NSWidth([self.chatSearchWindowResultsView frame]);
    NSUInteger count = [self.chatSearchWindowResults count];
    CGFloat contentHeight = MAX(286.0, rowHeight * (CGFloat)MAX(count, (NSUInteger)1));
    [self.chatSearchWindowResultsView setFrame:NSMakeRect(0, 0, width, contentHeight)];

    if ([query length] == 0) {
        [self.chatSearchWindowStatusField setStringValue:@"Start typing to find a chat"];
        return;
    }
    [self.chatSearchWindowStatusField setStringValue:(count == 0 ? @"No chats found" : [NSString stringWithFormat:@"Found chats: %lu", (unsigned long)count])];

    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        TGSearchResultItem *result = [self.chatSearchWindowResults objectAtIndex:index];
        NSString *title = [result displayTitle] ? [result displayTitle] : @"";
        NSString *subtitle = [result displaySubtitle] ? [result displaySubtitle] : @"";
        NSString *buttonTitle = ([subtitle length] > 0) ? [NSString stringWithFormat:@"%@\n%@", title, subtitle] : title;
        CGFloat y = contentHeight - ((CGFloat)(index + 1) * rowHeight);
        NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(0, y, width - 8.0, rowHeight - 4.0)] autorelease];
        [button setTitle:buttonTitle];
        [button setFont:[NSFont systemFontOfSize:12.0]];
        [button setAlignment:NSLeftTextAlignment];
        [button setBezelStyle:NSRegularSquareBezelStyle];
        [button setTarget:self];
        [button setAction:@selector(chatSearchWindowResultClicked:)];
        [button setTag:(NSInteger)index];
        [[button cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [self.chatSearchWindowResultsView addSubview:button];
        [self.chatSearchWindowResultButtons addObject:button];
    }
    [self applyPointingHandCursorToButtonsInView:self.chatSearchWindowResultsView];
}

- (void)chatSearchWindowTextCommitted:(id)sender {
    (void)sender;
    if ([self.chatSearchWindowResults count] > 0) {
        TGSearchResultItem *result = [self.chatSearchWindowResults objectAtIndex:0];
        [self closeChatSearchWindow:self];
        [self jumpToSearchResult:result];
    }
}

- (void)chatSearchWindowResultClicked:(id)sender {
    NSInteger index = [sender respondsToSelector:@selector(tag)] ? [sender tag] : -1;
    if (index < 0 || (NSUInteger)index >= [self.chatSearchWindowResults count]) {
        return;
    }
    TGSearchResultItem *result = [self.chatSearchWindowResults objectAtIndex:(NSUInteger)index];
    [self closeChatSearchWindow:self];
    [self jumpToSearchResult:result];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doChatSearchWindowCommandBySelector:(SEL)commandSelector {
    (void)textView;
    if (control != self.chatSearchWindowTextField) {
        return NO;
    }
    if (commandSelector == @selector(cancelOperation:)) {
        [self closeChatSearchWindow:control];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:) ||
        commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        [self chatSearchWindowTextCommitted:control];
        return YES;
    }
    return NO;
}
