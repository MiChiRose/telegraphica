#import "TGCustomEmojiParser.h"

NSString * const TGCustomEmojiIdentifierKey = @"custom_emoji_id";
NSString * const TGCustomEmojiFileIDKey = @"custom_emoji_file_id";
NSString * const TGCustomEmojiLocalPathKey = @"custom_emoji_local_path";
NSString * const TGCustomEmojiFormatKey = @"custom_emoji_format";

static NSNumber *TGCustomEmojiIdentifierFromEntity(NSDictionary *entity) {
    NSDictionary *type = [[entity objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [entity objectForKey:@"type"] : nil;
    if (![[type objectForKey:@"@type"] isEqualToString:@"textEntityTypeCustomEmoji"]) {
        return nil;
    }
    id value = [type objectForKey:@"custom_emoji_id"];
    if (![value respondsToSelector:@selector(longLongValue)] || [value longLongValue] <= 0) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[value longLongValue]];
}

NSArray *TGCustomEmojiIdentifiersFromEntities(NSArray *entities) {
    if (![entities isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }
    NSMutableArray *identifiers = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [entities count]; index++) {
        id entity = [entities objectAtIndex:index];
        NSNumber *identifier = [entity isKindOfClass:[NSDictionary class]]
            ? TGCustomEmojiIdentifierFromEntity((NSDictionary *)entity) : nil;
        if (identifier && ![identifiers containsObject:identifier]) {
            [identifiers addObject:identifier];
        }
    }
    return identifiers;
}

static NSDictionary *TGCustomEmojiFileObjectFromSticker(NSDictionary *sticker) {
    NSArray *keys = [NSArray arrayWithObjects:@"sticker", @"premium_animation", nil];
    NSUInteger index = 0;
    for (index = 0; index < [keys count]; index++) {
        id file = [sticker objectForKey:[keys objectAtIndex:index]];
        if ([file isKindOfClass:[NSDictionary class]]) {
            return file;
        }
    }
    NSDictionary *thumbnail = [[sticker objectForKey:@"thumbnail"] isKindOfClass:[NSDictionary class]]
        ? [sticker objectForKey:@"thumbnail"] : nil;
    id file = [thumbnail objectForKey:@"file"];
    return [file isKindOfClass:[NSDictionary class]] ? file : nil;
}

static NSString *TGCustomEmojiCompletedPathFromFile(NSDictionary *file) {
    NSDictionary *local = [[file objectForKey:@"local"] isKindOfClass:[NSDictionary class]]
        ? [file objectForKey:@"local"] : nil;
    if (![[local objectForKey:@"is_downloading_completed"] boolValue]) {
        return nil;
    }
    id path = [local objectForKey:@"path"];
    return ([path isKindOfClass:[NSString class]] && [path length] > 0) ? path : nil;
}

NSDictionary *TGCustomEmojiDescriptorsFromResponse(NSDictionary *response,
                                                    NSArray *requestedIdentifiers) {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return [NSDictionary dictionary];
    }
    id responseType = [response objectForKey:@"@type"];
    id stickersObject = [response objectForKey:@"stickers"];
    if (![responseType isEqualToString:@"stickers"] || ![stickersObject isKindOfClass:[NSArray class]]) {
        return [NSDictionary dictionary];
    }

    NSArray *stickers = (NSArray *)stickersObject;
    NSMutableDictionary *descriptors = [NSMutableDictionary dictionary];
    NSUInteger index = 0;
    for (index = 0; index < [stickers count]; index++) {
        id object = [stickers objectAtIndex:index];
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *sticker = (NSDictionary *)object;
        id rawIdentifier = [sticker objectForKey:@"custom_emoji_id"];
        NSNumber *identifier = nil;
        if ([rawIdentifier respondsToSelector:@selector(longLongValue)] && [rawIdentifier longLongValue] > 0) {
            identifier = [NSNumber numberWithLongLong:[rawIdentifier longLongValue]];
        } else if (index < [requestedIdentifiers count]) {
            id requested = [requestedIdentifiers objectAtIndex:index];
            if ([requested respondsToSelector:@selector(longLongValue)] && [requested longLongValue] > 0) {
                identifier = [NSNumber numberWithLongLong:[requested longLongValue]];
            }
        }
        if (!identifier) {
            continue;
        }

        NSMutableDictionary *descriptor = [NSMutableDictionary dictionaryWithObject:identifier
                                                                              forKey:TGCustomEmojiIdentifierKey];
        NSDictionary *file = TGCustomEmojiFileObjectFromSticker(sticker);
        id fileID = [file objectForKey:@"id"];
        if ([fileID respondsToSelector:@selector(integerValue)] && [fileID integerValue] > 0) {
            [descriptor setObject:[NSNumber numberWithInteger:[fileID integerValue]]
                           forKey:TGCustomEmojiFileIDKey];
        }
        NSString *path = TGCustomEmojiCompletedPathFromFile(file);
        if ([path length] > 0) {
            [descriptor setObject:path forKey:TGCustomEmojiLocalPathKey];
        }
        NSDictionary *format = [[sticker objectForKey:@"format"] isKindOfClass:[NSDictionary class]]
            ? [sticker objectForKey:@"format"] : nil;
        NSString *formatType = [[format objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [format objectForKey:@"@type"] : nil;
        if ([formatType length] > 0) {
            [descriptor setObject:formatType forKey:TGCustomEmojiFormatKey];
        }
        [descriptors setObject:descriptor forKey:identifier];
    }
    return descriptors;
}

NSArray *TGEntitiesByApplyingCustomEmojiDescriptors(NSArray *entities,
                                                    NSDictionary *descriptorsByIdentifier) {
    if (![entities isKindOfClass:[NSArray class]] || [entities count] == 0) {
        return [NSArray array];
    }
    NSMutableArray *updatedEntities = [NSMutableArray arrayWithCapacity:[entities count]];
    NSUInteger index = 0;
    for (index = 0; index < [entities count]; index++) {
        id object = [entities objectAtIndex:index];
        if (![object isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *entity = (NSDictionary *)object;
        NSNumber *identifier = TGCustomEmojiIdentifierFromEntity(entity);
        NSDictionary *descriptor = identifier ? [descriptorsByIdentifier objectForKey:identifier] : nil;
        if ([descriptor isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithDictionary:entity];
            NSArray *keys = [NSArray arrayWithObjects:
                             TGCustomEmojiIdentifierKey,
                             TGCustomEmojiFileIDKey,
                             TGCustomEmojiLocalPathKey,
                             TGCustomEmojiFormatKey,
                             nil];
            NSUInteger keyIndex = 0;
            for (keyIndex = 0; keyIndex < [keys count]; keyIndex++) {
                NSString *key = [keys objectAtIndex:keyIndex];
                id value = [descriptor objectForKey:key];
                if (value) {
                    [copy setObject:value forKey:key];
                }
            }
            [updatedEntities addObject:copy];
        } else {
            [updatedEntities addObject:entity];
        }
    }
    return updatedEntities;
}

