#import <Foundation/Foundation.h>
#import "../Sources/Core/TGReactionCatalog.h"

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Reaction catalog probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

static NSDictionary *TGAvailable(NSDictionary *type, BOOL premium) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"availableReaction", @"@type",
            type, @"type",
            [NSNumber numberWithBool:premium], @"needs_premium",
            nil];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDictionary *thumbsUp = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"reactionTypeEmoji", @"@type", @"👍", @"emoji", nil];
    NSDictionary *fire = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"reactionTypeEmoji", @"@type", @"🔥", @"emoji", nil];
    NSDictionary *premiumHeart = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"reactionTypeEmoji", @"@type", @"💘", @"emoji", nil];
    NSDictionary *custom = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"reactionTypeCustomEmoji", @"@type",
                            [NSNumber numberWithLongLong:123456789LL], @"custom_emoji_id", nil];
    NSDictionary *paid = [NSDictionary dictionaryWithObject:@"reactionTypePaid" forKey:@"@type"];
    NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"availableReactions", @"@type",
                              [NSArray arrayWithObjects:TGAvailable(thumbsUp, NO), TGAvailable(custom, NO), nil], @"top_reactions",
                              [NSArray arrayWithObjects:TGAvailable(thumbsUp, NO), TGAvailable(premiumHeart, YES), nil], @"recent_reactions",
                              [NSArray arrayWithObjects:TGAvailable(fire, NO), TGAvailable(paid, NO), nil], @"popular_reactions",
                              [NSNumber numberWithBool:NO], @"are_tags",
                              nil];
    NSDictionary *catalog = TGReactionCatalogFromTDLibResponse(response);
    NSArray *emojis = [catalog objectForKey:TGReactionCatalogEmojiItemsKey];
    NSArray *customItems = [catalog objectForKey:TGReactionCatalogCustomEmojiItemsKey];
    TGAssert([emojis isEqualToArray:[NSArray arrayWithObjects:@"👍", @"🔥", nil]],
             @"server order, de-duplication, and Premium filtering must be stable");
    TGAssert([customItems isEqualToArray:[NSArray arrayWithObject:[NSNumber numberWithLongLong:123456789LL]]],
             @"free custom identifiers must remain available for safe rendering");
    TGAssert(![[catalog objectForKey:TGReactionCatalogUnavailableKey] boolValue],
             @"non-empty response must be available");

    NSDictionary *legacy = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"availableReactions", @"@type",
                            [NSArray arrayWithObject:TGAvailable(fire, NO)], @"reactions", nil];
    TGAssert([[[TGReactionCatalogFromTDLibResponse(legacy) objectForKey:TGReactionCatalogEmojiItemsKey]
               firstObject] isEqualToString:@"🔥"], @"legacy reactions array must be accepted");

    NSDictionary *invalid = TGReactionCatalogFromTDLibResponse(nil);
    TGAssert([[invalid objectForKey:TGReactionCatalogUnavailableKey] boolValue],
             @"missing response must be marked unavailable");
    fprintf(stdout, "Reaction catalog probe passed.\n");
    [pool drain];
    return 0;
}
