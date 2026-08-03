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
        ![self.availableReactionOperationsByMessageKey objectForKey:cacheKey]) {
        NSNumber *chatID = [item chatID];
        NSNumber *messageID = [item messageID];
        NSString *requestKey = [[cacheKey copy] autorelease];
        TGTDLibClient *client = self.client;
        __block TGStatusWindowController *owner = self; /* MRC: deliberately non-retaining. */
        TGTDLibOperation *operation = [[[TGTDLibOperation alloc]
            initWithGeneration:0U
                         timeout:5.5
                      idempotent:YES
               maximumRetryCount:0U
                            work:^id(NSError **error) {
                                return [client availableReactionCatalogForChatID:chatID
                                                                             messageID:messageID
                                                                               rowSize:8U
                                                                               timeout:5.0
                                                                                 error:error];
                            }
                 generationCheck:nil
                      completion:^(id result, NSError *error) {
                          (void)error;
                          TGStatusWindowController *strongOwner = owner;
                          if (!strongOwner) {
                              return;
                          }
                          NSDictionary *catalog = [result isKindOfClass:[NSDictionary class]] ? result : nil;
                          NSArray *loadedEmojis = [catalog objectForKey:TGReactionCatalogEmojiItemsKey];
                          BOOL unsupported = ([[client capabilities]
                              supportStateForCapability:TGTDLibCapabilityAvailableReactions] ==
                              TGTDLibCapabilityStateUnsupported);
                          [strongOwner.availableReactionOperationsByMessageKey removeObjectForKey:requestKey];
                          /* Unsupported/valid empty results are cached; transient failures may retry. */
                          if (catalog || unsupported) {
                              [strongOwner.availableReactionEmojisByMessageKey
                                  setObject:(loadedEmojis ? loadedEmojis : [NSArray array])
                                     forKey:requestKey];
                          }
                          while ([strongOwner.availableReactionEmojisByMessageKey count] > 80U) {
                              id oldestKey = [[strongOwner.availableReactionEmojisByMessageKey allKeys] objectAtIndex:0];
                              [strongOwner.availableReactionEmojisByMessageKey removeObjectForKey:oldestKey];
                          }
                      }] autorelease];
        [self.availableReactionOperationsByMessageKey setObject:operation forKey:cacheKey];
        [operation start];
    }

    NSMutableArray *renderableEmojis = [NSMutableArray array];
    for (NSString *emoji in [self fallbackStandardReactionEmojis]) {
        if (TGReactionEmojiCanRender(emoji)) {
            [renderableEmojis addObject:emoji];
        }
    }
    return renderableEmojis;
}
