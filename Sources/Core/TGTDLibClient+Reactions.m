#import "TGTDLibClient+Reactions.h"

@interface TGTDLibClient (ReactionsPrivate)

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;

@end

static NSString *TGStandardReactionEmojiFromObject(id object) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSDictionary *dictionary = (NSDictionary *)object;
    NSDictionary *reactionType = [[dictionary objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [dictionary objectForKey:@"type"] : dictionary;
    NSString *typeName = [reactionType objectForKey:@"@type"];
    if (![typeName isEqualToString:@"reactionTypeEmoji"]) {
        return nil;
    }
    NSString *emoji = [reactionType objectForKey:@"emoji"];
    return ([emoji isKindOfClass:[NSString class]] && [emoji length] > 0) ? emoji : nil;
}

@implementation TGTDLibClient (Reactions)

- (NSArray *)availableStandardReactionEmojisForChatID:(NSNumber *)chatID
                                             messageID:(NSNumber *)messageID
                                               rowSize:(NSUInteger)rowSize
                                               timeout:(NSTimeInterval)timeout
                                                 error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Available reactions require valid chat and message identifiers." code:119];
        }
        return nil;
    }

    NSUInteger safeRowSize = rowSize;
    if (safeRowSize < 5) {
        safeRowSize = 8;
    } else if (safeRowSize > 25) {
        safeRowSize = 25;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"getMessageAvailableReactions", @"@type",
                             chatID, @"chat_id",
                             messageID, @"message_id",
                             [NSNumber numberWithUnsignedInteger:safeRowSize], @"row_size",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-available-reactions"
                                                           timeout:timeout
                                                         errorCode:119
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]] ||
        ![[response objectForKey:@"@type"] isEqualToString:@"availableReactions"]) {
        return nil;
    }

    NSMutableArray *emojis = [NSMutableArray array];
    NSArray *listKeys = [NSArray arrayWithObjects:@"top_reactions", @"recent_reactions", @"popular_reactions", nil];
    for (NSString *listKey in listKeys) {
        id listObject = [response objectForKey:listKey];
        if (![listObject isKindOfClass:[NSArray class]]) {
            continue;
        }
        for (id reactionObject in (NSArray *)listObject) {
            NSString *emoji = TGStandardReactionEmojiFromObject(reactionObject);
            if ([emoji length] > 0 && ![emojis containsObject:emoji]) {
                [emojis addObject:emoji];
            }
        }
    }
    return emojis;
}

@end
