- (NSArray *)fallbackStandardReactionEmojis {
    return [NSArray arrayWithObjects:
            @"👍", @"👎", @"❤", @"🔥", @"😂", @"😢", @"😭", @"😁",
            @"👏", @"😱", @"🎉", @"💩", @"🙏", @"👌", @"😍", @"👀",
            @"🥰", @"🤔", @"🤯", @"🤩", @"🤮",
            @"🕊", @"🤡", @"🥱", @"🥴", @"🐳", @"💯",
            @"🤣", @"⚡", @"🍌", @"🏆", @"💔", @"🤨", @"😐",
            @"🎃", @"👻", @"👨‍💻", @"🤝", @"✍", @"🤗", @"🫡", @"🎅",
            @"🎄", @"☃", @"💅", @"🤪", @"🗿", @"🆒", @"💘", @"🙉",
            nil];
}

- (NSString *)reactionCatalogKeyForChatID:(NSNumber *)chatID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld", [chatID longLongValue]];
}

- (void)prefetchReactionCatalogForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]] ||
        ![item.chatID respondsToSelector:@selector(longLongValue)] ||
        ![item.messageID respondsToSelector:@selector(longLongValue)] ||
        ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    NSString *catalogKey = [self reactionCatalogKeyForChatID:item.chatID];
    if ([catalogKey length] == 0) {
        return;
    }
    if (!self.availableReactionEmojisByChatID) {
        self.availableReactionEmojisByChatID = [NSMutableDictionary dictionary];
    }
    if (!self.reactionCatalogAttemptedChatIDs) {
        self.reactionCatalogAttemptedChatIDs = [NSMutableSet set];
    }
    if ([self.availableReactionEmojisByChatID objectForKey:catalogKey] ||
        [self.reactionCatalogAttemptedChatIDs containsObject:catalogKey]) {
        return;
    }
    [self.reactionCatalogAttemptedChatIDs addObject:catalogKey];

    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [[NSNumber numberWithLongLong:[item.chatID longLongValue]] retain];
    NSNumber *messageID = [[NSNumber numberWithLongLong:[item.messageID longLongValue]] retain];
    NSString *catalogKeyCopy = [catalogKey copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *catalogError = nil;
        NSArray *emojis = [[client availableStandardReactionEmojisForChatID:chatID
                                                                  messageID:messageID
                                                                    rowSize:8
                                                                    timeout:6.0
                                                                      error:&catalogError] retain];
        NSString *errorMessage = [[catalogError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (emojis) {
                [self.availableReactionEmojisByChatID setObject:emojis forKey:catalogKeyCopy];
                [self appendDetail:[NSString stringWithFormat:@"Reactions: loaded %lu server-approved emoji for chat %@.",
                                    (unsigned long)[emojis count],
                                    catalogKeyCopy]];
            } else if ([errorMessage length] > 0) {
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Reaction catalog fallback: %@", errorMessage]];
            }
            [emojis release];
            [errorMessage release];
            [catalogKeyCopy release];
            [chatID release];
            [messageID release];
            [client release];
        });
        [pool drain];
    });
}

- (NSArray *)standardReactionEmojisForMessageItem:(TGMessageItem *)item {
    (void)item;
    NSMutableArray *renderableEmojis = [NSMutableArray array];
    for (NSString *emoji in [self fallbackStandardReactionEmojis]) {
        if (TGReactionEmojiCanRender(emoji)) {
            [renderableEmojis addObject:emoji];
        }
    }
    return renderableEmojis;
}

- (NSArray *)telegramReactionEmojisForMessageItem:(TGMessageItem *)item {
    NSString *catalogKey = [self reactionCatalogKeyForChatID:item.chatID];
    NSArray *serverEmojis = [catalogKey length] > 0 ? [self.availableReactionEmojisByChatID objectForKey:catalogKey] : nil;
    [self prefetchReactionCatalogForMessageItem:item];
    NSArray *catalog = [serverEmojis count] > 0
        ? serverEmojis : [self fallbackStandardReactionEmojis];
    NSMutableArray *orderedEmojis = [NSMutableArray array];
    NSMutableSet *addedEmojis = [NSMutableSet setWithArray:
        [self standardReactionEmojisForMessageItem:item]];
    NSUInteger index = 0;

    /* Keep Telegram's additional server-approved reactions in their own list. */
    for (index = 0; index < [catalog count]; index++) {
        NSString *emoji = [catalog objectAtIndex:index];
        if (TGReactionEmojiCanRender(emoji) &&
            ![addedEmojis containsObject:emoji]) {
            [orderedEmojis addObject:emoji];
            [addedEmojis addObject:emoji];
        }
    }

    /*
     * Preserve unsupported server reactions at the end.  The row view uses
     * the safe question-mark fallback visually while retaining the original
     * emoji in the action payload.
     */
    NSUInteger unsupportedCount = 0;
    for (index = 0; index < [catalog count] && unsupportedCount < 8U; index++) {
        NSString *emoji = [catalog objectAtIndex:index];
        if (![addedEmojis containsObject:emoji]) {
            [orderedEmojis addObject:emoji];
            [addedEmojis addObject:emoji];
            unsupportedCount++;
        }
    }
    return orderedEmojis;
}

- (NSArray *)reactionEmojisForMessageItem:(TGMessageItem *)item {
    NSMutableArray *allEmojis = [NSMutableArray arrayWithArray:
        [self standardReactionEmojisForMessageItem:item]];
    [allEmojis addObjectsFromArray:[self telegramReactionEmojisForMessageItem:item]];
    return allEmojis;
}
