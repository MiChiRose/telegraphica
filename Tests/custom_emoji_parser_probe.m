#import <Foundation/Foundation.h>
#import "TGCustomEmojiParser.h"
#include <stdio.h>

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "%s\n", [message UTF8String]);
        exit(2);
    }
}

int main(int argc, const char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Assert(argc == 2, @"fixture path is required");
    NSData *data = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];

    NSDictionary *type101 = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"textEntityTypeCustomEmoji", @"@type", @101, @"custom_emoji_id", nil];
    NSDictionary *type102 = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"textEntityTypeCustomEmoji", @"@type", @102, @"custom_emoji_id", nil];
    NSArray *entities = [NSArray arrayWithObjects:
                         [NSDictionary dictionaryWithObjectsAndKeys:@0, @"offset", @2, @"length", type101, @"type", nil],
                         [NSDictionary dictionaryWithObjectsAndKeys:@2, @"offset", @2, @"length", type102, @"type", nil],
                         [NSDictionary dictionaryWithObjectsAndKeys:@4, @"offset", @1, @"length",
                          [NSDictionary dictionaryWithObject:@"textEntityTypeBold" forKey:@"@type"], @"type", nil],
                         [NSDictionary dictionaryWithObjectsAndKeys:@6, @"offset", @1, @"length", type101, @"type", nil],
                         nil];
    NSArray *identifiers = TGCustomEmojiIdentifiersFromEntities(entities);
    Assert([identifiers count] == 2, @"custom emoji identifiers must be unique");
    Assert([[identifiers objectAtIndex:0] longLongValue] == 101, @"first identifier mismatch");

    NSDictionary *descriptors = TGCustomEmojiDescriptorsFromResponse(response, identifiers);
    Assert([descriptors count] == 2, @"both server stickers must be parsed");
    Assert([[[descriptors objectForKey:@101] objectForKey:TGCustomEmojiLocalPathKey]
            isEqualToString:@"/tmp/fixture-custom-emoji.webp"], @"completed path missing");
    Assert([[[descriptors objectForKey:@102] objectForKey:TGCustomEmojiFileIDKey] integerValue] == 502,
           @"requested-order fallback identifier failed");
    Assert([[descriptors objectForKey:@102] objectForKey:TGCustomEmojiLocalPathKey] == nil,
           @"incomplete download must not expose a local path");

    NSArray *updated = TGEntitiesByApplyingCustomEmojiDescriptors(entities, descriptors);
    Assert([updated count] == [entities count], @"entity count changed");
    Assert([[[updated objectAtIndex:0] objectForKey:TGCustomEmojiFileIDKey] integerValue] == 501,
           @"descriptor was not attached to entity");
    Assert([[updated objectAtIndex:2] objectForKey:TGCustomEmojiFileIDKey] == nil,
           @"non-custom entity was modified");
    Assert([[TGCustomEmojiDescriptorsFromResponse([NSDictionary dictionary], identifiers) allKeys] count] == 0,
           @"malformed response must fail closed");

    fprintf(stdout, "Custom emoji parser probe passed.\n");
    [pool drain];
    return 0;
}
