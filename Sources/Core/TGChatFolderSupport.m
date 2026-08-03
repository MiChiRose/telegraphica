#import "TGChatFolderSupport.h"

static NSString *TGChatFolderSafeString(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *TGChatFolderTitleFromObject(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return TGChatFolderSafeString(value);
    }
    if (![value isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    id text = [(NSDictionary *)value objectForKey:@"text"];
    if ([text isKindOfClass:[NSDictionary class]]) {
        text = [(NSDictionary *)text objectForKey:@"text"];
    }
    return TGChatFolderSafeString(text);
}

NSArray *TGChatFolderSafeIdentifierArray(id value) {
    if (![value isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)value count]; index++) {
        id identifier = [(NSArray *)value objectAtIndex:index];
        if ([identifier respondsToSelector:@selector(longLongValue)]) {
            [result addObject:[NSNumber numberWithLongLong:[identifier longLongValue]]];
        }
    }
    return result;
}

NSArray *TGChatFolderNormalizeInviteLinks(id response) {
    if (![response isKindOfClass:[NSDictionary class]] ||
        ![[response objectForKey:@"@type"] isEqualToString:@"chatFolderInviteLinks"] ||
        ![[response objectForKey:@"invite_links"] isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *links = [NSMutableArray array];
    NSArray *source = [response objectForKey:@"invite_links"];
    NSUInteger index = 0;
    for (index = 0; index < [source count]; index++) {
        NSDictionary *item = [[source objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [source objectAtIndex:index] : nil;
        NSString *inviteLink = TGChatFolderSafeString([item objectForKey:@"invite_link"]);
        if ([inviteLink length] == 0) {
            continue;
        }
        NSString *name = TGChatFolderSafeString([item objectForKey:@"name"]);
        [links addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                          inviteLink, @"invite_link",
                          name, @"name",
                          TGChatFolderSafeIdentifierArray([item objectForKey:@"chat_ids"]), @"chat_ids",
                          nil]];
    }
    return links;
}

NSArray *TGChatFolderNormalizeRecommendedFolders(id response) {
    if (![response isKindOfClass:[NSDictionary class]] ||
        ![[response objectForKey:@"@type"] isEqualToString:@"recommendedChatFolders"] ||
        ![[response objectForKey:@"chat_folders"] isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *folders = [NSMutableArray array];
    NSArray *source = [response objectForKey:@"chat_folders"];
    NSUInteger index = 0;
    for (index = 0; index < [source count]; index++) {
        NSDictionary *item = [[source objectAtIndex:index] isKindOfClass:[NSDictionary class]]
            ? [source objectAtIndex:index] : nil;
        NSDictionary *folder = [[item objectForKey:@"folder"] isKindOfClass:[NSDictionary class]]
            ? [item objectForKey:@"folder"] : nil;
        NSString *title = TGChatFolderTitleFromObject([folder objectForKey:@"name"]);
        if ([title length] == 0) {
            title = TGChatFolderTitleFromObject([folder objectForKey:@"title"]);
        }
        if ([title length] == 0) {
            continue;
        }
        NSMutableDictionary *definition = [NSMutableDictionary dictionary];
        [definition setObject:title forKey:@"title"];
        [definition setObject:@"folder" forKey:@"api_kind"];
        [definition setObject:TGChatFolderSafeIdentifierArray([folder objectForKey:@"pinned_chat_ids"]) forKey:@"pinned_chat_ids"];
        [definition setObject:TGChatFolderSafeIdentifierArray([folder objectForKey:@"included_chat_ids"]) forKey:@"included_chat_ids"];
        [definition setObject:TGChatFolderSafeIdentifierArray([folder objectForKey:@"excluded_chat_ids"]) forKey:@"excluded_chat_ids"];
        NSArray *booleanKeys = [NSArray arrayWithObjects:@"exclude_muted", @"exclude_read", @"exclude_archived",
                                @"include_contacts", @"include_non_contacts", @"include_bots", @"include_groups",
                                @"include_channels", @"is_shareable", nil];
        NSUInteger booleanIndex = 0;
        for (booleanIndex = 0; booleanIndex < [booleanKeys count]; booleanIndex++) {
            NSString *key = [booleanKeys objectAtIndex:booleanIndex];
            [definition setObject:[NSNumber numberWithBool:[[folder objectForKey:key] boolValue]] forKey:key];
        }
        NSString *iconName = @"Custom";
        if ([[folder objectForKey:@"icon"] isKindOfClass:[NSDictionary class]] &&
            [[[folder objectForKey:@"icon"] objectForKey:@"name"] isKindOfClass:[NSString class]]) {
            iconName = [[folder objectForKey:@"icon"] objectForKey:@"name"];
        }
        [definition setObject:iconName forKey:@"icon_name"];
        [definition setObject:[NSNumber numberWithInteger:-1] forKey:@"color_id"];
        [folders addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            title, @"title",
                            TGChatFolderSafeString([item objectForKey:@"description"]), @"description",
                            definition, @"definition",
                            nil]];
    }
    return folders;
}

NSNumber *TGChatFolderOptionInteger(id response) {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *value = (NSDictionary *)response;
    if ([[value objectForKey:@"@type"] isEqualToString:@"optionValueInteger"] &&
        [[value objectForKey:@"value"] respondsToSelector:@selector(longLongValue)]) {
        return [NSNumber numberWithLongLong:[[value objectForKey:@"value"] longLongValue]];
    }
    return nil;
}
