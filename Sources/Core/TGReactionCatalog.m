#import "TGReactionCatalog.h"

NSString * const TGReactionCatalogEmojiItemsKey = @"emoji_items";
NSString * const TGReactionCatalogCustomEmojiItemsKey = @"custom_emoji_items";
NSString * const TGReactionCatalogAreTagsKey = @"are_tags";
NSString * const TGReactionCatalogUnavailableKey = @"unavailable";

static BOOL TGReactionCatalogBoolean(id value) {
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static void TGReactionCatalogAppendArray(id candidate,
                                         NSMutableArray *emojiItems,
                                         NSMutableArray *customEmojiItems,
                                         NSMutableSet *seenKeys) {
    if (![candidate isKindOfClass:[NSArray class]]) {
        return;
    }
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)candidate count]; index++) {
        id rawItem = [(NSArray *)candidate objectAtIndex:index];
        if (![rawItem isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *item = (NSDictionary *)rawItem;
        if (TGReactionCatalogBoolean([item objectForKey:@"needs_premium"]) ||
            TGReactionCatalogBoolean([item objectForKey:@"is_premium"])) {
            continue;
        }
        NSDictionary *type = [[item objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
            ? [item objectForKey:@"type"] : item;
        NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [type objectForKey:@"@type"] : @"";
        if ([typeName isEqualToString:@"reactionTypePaid"] ||
            [typeName isEqualToString:@"reactionTypeStars"] ||
            [typeName isEqualToString:@"reactionTypeStar"]) {
            continue;
        }
        if ([typeName isEqualToString:@"reactionTypeEmoji"]) {
            NSString *emoji = [[type objectForKey:@"emoji"] isKindOfClass:[NSString class]]
                ? [type objectForKey:@"emoji"] : nil;
            NSString *key = [NSString stringWithFormat:@"emoji:%@", emoji ? emoji : @""];
            if ([emoji length] > 0 && ![seenKeys containsObject:key]) {
                [seenKeys addObject:key];
                [emojiItems addObject:emoji];
            }
            continue;
        }
        if ([typeName isEqualToString:@"reactionTypeCustomEmoji"]) {
            id identifier = [type objectForKey:@"custom_emoji_id"];
            if (![identifier respondsToSelector:@selector(longLongValue)] ||
                [identifier longLongValue] <= 0) {
                continue;
            }
            NSString *key = [NSString stringWithFormat:@"custom:%lld", [identifier longLongValue]];
            if (![seenKeys containsObject:key]) {
                [seenKeys addObject:key];
                [customEmojiItems addObject:[NSNumber numberWithLongLong:[identifier longLongValue]]];
            }
        }
    }
}

NSDictionary *TGReactionCatalogFromTDLibResponse(NSDictionary *response) {
    NSMutableArray *emojiItems = [NSMutableArray array];
    NSMutableArray *customEmojiItems = [NSMutableArray array];
    NSMutableSet *seenKeys = [NSMutableSet set];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return [NSDictionary dictionaryWithObjectsAndKeys:
                emojiItems, TGReactionCatalogEmojiItemsKey,
                customEmojiItems, TGReactionCatalogCustomEmojiItemsKey,
                [NSNumber numberWithBool:YES], TGReactionCatalogUnavailableKey,
                nil];
    }

    /* Newer TDLib separates display-priority groups; older builds used reactions. */
    TGReactionCatalogAppendArray([response objectForKey:@"top_reactions"], emojiItems, customEmojiItems, seenKeys);
    TGReactionCatalogAppendArray([response objectForKey:@"recent_reactions"], emojiItems, customEmojiItems, seenKeys);
    TGReactionCatalogAppendArray([response objectForKey:@"popular_reactions"], emojiItems, customEmojiItems, seenKeys);
    TGReactionCatalogAppendArray([response objectForKey:@"reactions"], emojiItems, customEmojiItems, seenKeys);

    BOOL unavailable = ([[response objectForKey:@"unavailability_reason"] isKindOfClass:[NSDictionary class]] ||
                        ([emojiItems count] == 0 && [customEmojiItems count] == 0));
    return [NSDictionary dictionaryWithObjectsAndKeys:
            emojiItems, TGReactionCatalogEmojiItemsKey,
            customEmojiItems, TGReactionCatalogCustomEmojiItemsKey,
            [NSNumber numberWithBool:TGReactionCatalogBoolean([response objectForKey:@"are_tags"])], TGReactionCatalogAreTagsKey,
            [NSNumber numberWithBool:unavailable], TGReactionCatalogUnavailableKey,
            nil];
}

