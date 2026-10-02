#import "TGMessageReactionParser.h"

static BOOL TGReactionParserBool(id value) {
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static NSString *TGStandardReactionEmoji(NSDictionary *reaction) {
    id type = [reaction objectForKey:@"type"];
    if ([type isKindOfClass:[NSDictionary class]]) {
        // Unknown/custom/paid reaction types do not acquire an invented glyph
        // or a standard reaction's add/remove identity.
        if (![@"reactionTypeEmoji" isEqual:[type objectForKey:@"@type"]]) { return nil; }
        id emoji = [type objectForKey:@"emoji"];
        return [emoji isKindOfClass:[NSString class]] && [emoji length] > 0 ? emoji : nil;
    }
    // TDLib's original messageReaction used reaction:string, before types.
    id legacyEmoji = [reaction objectForKey:@"reaction"];
    return [legacyEmoji isKindOfClass:[NSString class]] && [legacyEmoji length] > 0 ? legacyEmoji : nil;
}

NSDictionary *TGMessageReactionInfoFromObject(NSDictionary *messageObject) {
    if (![messageObject isKindOfClass:[NSDictionary class]]) { return nil; }
    id interaction = [messageObject objectForKey:@"interaction_info"];
    id container = [interaction isKindOfClass:[NSDictionary class]] ? [interaction objectForKey:@"reactions"] : nil;
    NSArray *reactions = nil;
    id capability = [messageObject objectForKey:@"can_get_added_reactions"];
    BOOL hasCapability = [capability respondsToSelector:@selector(boolValue)];
    BOOL canGetAdded = TGReactionParserBool(capability);
    if ([container isKindOfClass:[NSDictionary class]]) {
        id entries = [container objectForKey:@"reactions"];
        reactions = [entries isKindOfClass:[NSArray class]] ? entries : nil;
        capability = [container objectForKey:@"can_get_added_reactions"];
        if ([capability respondsToSelector:@selector(boolValue)]) {
            hasCapability = YES;
            canGetAdded = [capability boolValue];
        }
    } else if ([container isKindOfClass:[NSArray class]]) {
        reactions = container;
    }

    NSMutableArray *parts = [NSMutableArray array];
    NSMutableArray *chosen = [NSMutableArray array];
    id candidate = nil;
    for (candidate in reactions) {
        if (![candidate isKindOfClass:[NSDictionary class]]) { continue; }
        NSString *emoji = TGStandardReactionEmoji(candidate);
        id countObject = [candidate objectForKey:@"total_count"];
        if (![emoji length] || ![countObject isKindOfClass:[NSNumber class]] || [countObject integerValue] <= 0) { continue; }
        NSInteger count = [countObject integerValue];
        // Keep the complete integer and all ordinary reactions in TDLib order.
        [parts addObject:count == 1 ? emoji : [NSString stringWithFormat:@"%@ %ld", emoji, (long)count]];
        if (TGReactionParserBool([candidate objectForKey:@"is_chosen"]) && ![chosen containsObject:emoji]) {
            [chosen addObject:emoji];
        }
    }
    if (![parts count] && ![chosen count] && !hasCapability) { return nil; }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    // Legacy interaction updates omit this message-level capability. Absence
    // must remain distinguishable from an authoritative modern false value.
    if (hasCapability) { [info setObject:[NSNumber numberWithBool:canGetAdded] forKey:@"can_get_added_reactions"]; }
    if ([parts count]) { [info setObject:[parts componentsJoinedByString:@"  "] forKey:@"summary"]; }
    if ([chosen count]) { [info setObject:chosen forKey:@"chosen_emojis"]; }
    return info;
}
