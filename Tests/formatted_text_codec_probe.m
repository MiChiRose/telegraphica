#import <Foundation/Foundation.h>
#import "TGFormattedTextCodec.h"

static NSUInteger failures = 0;

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        failures++;
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    }
}

static NSDictionary *Entity(NSString *typeName, NSUInteger offset, NSUInteger length) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:offset], @"offset",
            [NSNumber numberWithUnsignedInteger:length], @"length",
            [NSDictionary dictionaryWithObject:typeName forKey:@"@type"], @"type",
            nil];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSString *emojiText = @"A😀B";
    NSArray *valid = TGValidatedTDLibTextEntities(
        [NSArray arrayWithObject:Entity(@"textEntityTypeBold", 1, 2)], emojiText);
    Assert([valid count] == 1, @"a full surrogate pair must be accepted as a UTF-16 entity range");
    NSArray *splitSurrogate = TGValidatedTDLibTextEntities(
        [NSArray arrayWithObject:Entity(@"textEntityTypeBold", 1, 1)], emojiText);
    Assert([splitSurrogate count] == 0, @"an entity must not split a surrogate pair");

    NSString *original = @"Hello bright world";
    NSArray *entities = [NSArray arrayWithObjects:
        Entity(@"textEntityTypeBold", 0, 5),
        Entity(@"textEntityTypeItalic", 6, 6),
        Entity(@"textEntityTypeTextUrl", 13, 5),
        nil];
    NSArray *rebased = TGRebasedTDLibTextEntities(original, entities, @"Hello very bright world");
    Assert([rebased count] == 3, @"an insertion between entities must preserve each untouched entity");
    Assert([[[rebased objectAtIndex:2] objectForKey:@"offset"] unsignedIntegerValue] == 18,
           @"an entity after an insertion must shift by the UTF-16 delta");

    NSArray *touched = TGRebasedTDLibTextEntities(original, entities, @"Hello vivid world");
    Assert([touched count] == 2, @"an entity directly modified by the edit must be removed safely");

    NSArray *enclosing = [NSArray arrayWithObject:Entity(@"textEntityTypeBlockQuote", 0, [original length])];
    NSArray *expanded = TGRebasedTDLibTextEntities(original, enclosing, @"Hello very bright world");
    Assert([expanded count] == 1 &&
           [[[expanded objectAtIndex:0] objectForKey:@"length"] unsignedIntegerValue] == [@"Hello very bright world" length],
           @"an enclosing quote must expand across an internal edit");

    NSDictionary *formatted = TGTDLibFormattedTextObject(emojiText, valid);
    Assert([[formatted objectForKey:@"@type"] isEqualToString:@"formattedText"],
           @"the request builder must emit a TDLib formattedText object");
    Assert([[[formatted objectForKey:@"entities"] objectAtIndex:0] objectForKey:@"type"] != nil,
           @"the request builder must retain the entity type payload");

    if (failures == 0) {
        printf("Formatted text codec probe passed.\n");
    }
    [pool drain];
    return failures == 0 ? 0 : 1;
}
