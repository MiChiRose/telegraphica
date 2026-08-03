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

- (NSArray *)standardReactionEmojisForMessageItem:(TGMessageItem *)item {
    NSString *cacheKey = nil;
    if ([item isKindOfClass:[TGMessageItem class]] &&
        [[item chatID] respondsToSelector:@selector(longLongValue)] &&
        [[item messageID] respondsToSelector:@selector(longLongValue)]) {
        cacheKey = [NSString stringWithFormat:@"%lld:%lld",
                    [[item chatID] longLongValue], [[item messageID] longLongValue]];
    }
    NSArray *serverEmojis = [self.availableReactionEmojisByMessageKey objectForKey:cacheKey];
    if ([serverEmojis count] > 0) {
        NSMutableArray *renderableServerEmojis = [NSMutableArray array];
        for (NSString *emoji in serverEmojis) {
            if (TGReactionEmojiCanRender(emoji)) {
                [renderableServerEmojis addObject:emoji];
            }
        }
        if ([renderableServerEmojis count] > 0) {
            return renderableServerEmojis;
        }
    }

    if ([cacheKey length] > 0 &&
        ![self.availableReactionEmojisByMessageKey objectForKey:cacheKey] &&
        ![self.availableReactionRequestsInFlight containsObject:cacheKey]) {
        [self.availableReactionRequestsInFlight addObject:cacheKey];
        NSNumber *chatID = [[item chatID] retain];
        NSNumber *messageID = [[item messageID] retain];
        NSString *requestKey = [cacheKey copy];
        TGTDLibClient *client = [self.client retain];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            NSError *error = nil;
            NSDictionary *catalog = [client availableReactionCatalogForChatID:chatID
                                                                      messageID:messageID
                                                                        rowSize:8U
                                                                        timeout:5.0
                                                                          error:&error];
            NSArray *loadedEmojis = [[catalog objectForKey:TGReactionCatalogEmojiItemsKey] copy];
            BOOL shouldCacheResult = (catalog != nil ||
                [[client capabilities] supportStateForCapability:TGTDLibCapabilityAvailableReactions] ==
                    TGTDLibCapabilityStateUnsupported);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.availableReactionRequestsInFlight removeObject:requestKey];
                /* Unsupported/valid empty results are cached; transient failures may retry. */
                if (shouldCacheResult) {
                    [self.availableReactionEmojisByMessageKey setObject:(loadedEmojis ? loadedEmojis : [NSArray array])
                                                                  forKey:requestKey];
                }
                while ([self.availableReactionEmojisByMessageKey count] > 80U) {
                    id oldestKey = [[self.availableReactionEmojisByMessageKey allKeys] objectAtIndex:0];
                    [self.availableReactionEmojisByMessageKey removeObjectForKey:oldestKey];
                }
                [loadedEmojis release];
                [requestKey release];
                [chatID release];
                [messageID release];
            });
            [client release];
            [pool drain];
        });
    }

    NSMutableArray *renderableEmojis = [NSMutableArray array];
    for (NSString *emoji in [self fallbackStandardReactionEmojis]) {
        if (TGReactionEmojiCanRender(emoji)) {
            [renderableEmojis addObject:emoji];
        }
    }
    return renderableEmojis;
}
