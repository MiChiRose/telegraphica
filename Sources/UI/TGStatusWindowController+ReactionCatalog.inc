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
    (void)item;
    NSMutableArray *renderableEmojis = [NSMutableArray array];
    for (NSString *emoji in [self fallbackStandardReactionEmojis]) {
        if (TGReactionEmojiCanRender(emoji)) {
            [renderableEmojis addObject:emoji];
        }
    }
    return renderableEmojis;
}
