#import "TGAddedReactionsParser.h"

NSString * const TGAddedReactionsItemsKey = @"items";
NSString * const TGAddedReactionsNextOffsetKey = @"next_offset";
NSString * const TGAddedReactionSenderKey = @"sender";
NSString * const TGAddedReactionEmojiKey = @"emoji";
NSString * const TGAddedReactionCustomEmojiIDKey = @"custom_emoji_id";
NSString * const TGAddedReactionDateKey = @"date";

static NSDictionary *TGParsedAddedReaction(id candidate) {
    if (![candidate isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *reaction = (NSDictionary *)candidate;
    NSDictionary *sender = [[reaction objectForKey:@"sender_id"] isKindOfClass:[NSDictionary class]]
        ? [reaction objectForKey:@"sender_id"] : nil;
    NSDictionary *type = [[reaction objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [reaction objectForKey:@"type"] : nil;
    NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [type objectForKey:@"@type"] : @"";
    if (!sender || [typeName isEqualToString:@"reactionTypePaid"] || [typeName length] == 0) {
        return nil;
    }

    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithObject:sender
                                                                    forKey:TGAddedReactionSenderKey];
    if ([typeName isEqualToString:@"reactionTypeEmoji"]) {
        NSString *emoji = [[type objectForKey:@"emoji"] isKindOfClass:[NSString class]]
            ? [type objectForKey:@"emoji"] : @"";
        if ([emoji length] == 0) {
            return nil;
        }
        [item setObject:emoji forKey:TGAddedReactionEmojiKey];
    } else if ([typeName isEqualToString:@"reactionTypeCustomEmoji"]) {
        id identifier = [type objectForKey:@"custom_emoji_id"];
        if (![identifier respondsToSelector:@selector(longLongValue)] || [identifier longLongValue] <= 0) {
            return nil;
        }
        [item setObject:[NSNumber numberWithLongLong:[identifier longLongValue]]
                 forKey:TGAddedReactionCustomEmojiIDKey];
    } else {
        return nil;
    }
    id date = [reaction objectForKey:@"date"];
    if ([date respondsToSelector:@selector(integerValue)] && [date integerValue] > 0) {
        [item setObject:[NSNumber numberWithInteger:[date integerValue]] forKey:TGAddedReactionDateKey];
    }
    return item;
}

NSDictionary *TGAddedReactionsPageFromTDLibResponse(NSDictionary *response) {
    NSString *type = [response isKindOfClass:[NSDictionary class]] &&
        [[response objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [response objectForKey:@"@type"] : @"";
    if (![type isEqualToString:@"addedReactions"]) {
        return nil;
    }
    NSArray *rawItems = [[response objectForKey:@"reactions"] isKindOfClass:[NSArray class]]
        ? [response objectForKey:@"reactions"] : [NSArray array];
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [rawItems count] && [items count] < 100U; index++) {
        NSDictionary *item = TGParsedAddedReaction([rawItems objectAtIndex:index]);
        if (item) {
            [items addObject:item];
        }
    }
    NSString *nextOffset = [[response objectForKey:@"next_offset"] isKindOfClass:[NSString class]]
        ? [response objectForKey:@"next_offset"] : @"";
    return [NSDictionary dictionaryWithObjectsAndKeys:
            items, TGAddedReactionsItemsKey,
            nextOffset, TGAddedReactionsNextOffsetKey,
            nil];
}

