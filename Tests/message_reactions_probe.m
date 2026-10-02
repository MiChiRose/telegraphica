#import <Foundation/Foundation.h>
#import "TGMessageReactionParser.h"

static void TGAssert(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "Message reactions probe failed: %s\n", message); exit(1); }
}

static NSDictionary *TGReactionFixture(NSString *name) {
    NSString *path = [@"Tests/Fixtures" stringByAppendingPathComponent:name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    id value = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
    TGAssert([value isKindOfClass:[NSDictionary class]], "serialized reaction fixture must load");
    return value;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSDictionary *legacyMessage = TGReactionFixture(@"message_reactions_legacy.json");
    NSDictionary *modernMessage = TGReactionFixture(@"message_reactions_modern.json");
    NSDictionary *legacy = TGMessageReactionInfoFromObject(legacyMessage);
    NSDictionary *modern = TGMessageReactionInfoFromObject(modernMessage);
    NSString *expected = @"❤️ 48  👍 122  🔥  😁 7  😢 2  🤔 17";
    TGAssert([[legacy objectForKey:@"summary"] isEqual:expected], "original TDLib string/vector schema preserves all six reactions and complete counters");
    TGAssert([[modern objectForKey:@"summary"] isEqual:expected], "modern nested typed schema must not truncate to three reactions");
    TGAssert([legacy isEqual:modern], "old and new serialized messages yield identical display metadata");
    TGAssert([[[modern objectForKey:@"summary"] componentsSeparatedByString:@"  "] count] == 6, "one summary entry per ordinary reaction");
    TGAssert([[modern objectForKey:@"chosen_emojis"] isEqual:[NSArray arrayWithObject:@"🤔"]], "chosen reaction beyond the third remains selectable");
    TGAssert([[legacy objectForKey:@"can_get_added_reactions"] boolValue], "legacy top-level sender-list capability is retained");

    // Intermediate TDLib uses typed entries but keeps the original vector.
    NSMutableDictionary *transitional = [NSMutableDictionary dictionaryWithDictionary:legacyMessage];
    [transitional setObject:[NSDictionary dictionaryWithObject:
        [[[modernMessage objectForKey:@"interaction_info"] objectForKey:@"reactions"] objectForKey:@"reactions"]
        forKey:@"reactions"] forKey:@"interaction_info"];
    TGAssert([TGMessageReactionInfoFromObject(transitional) isEqual:modern], "typed direct vector schema remains supported");
    [transitional removeObjectForKey:@"can_get_added_reactions"];
    NSDictionary *updateInfo = TGMessageReactionInfoFromObject(transitional);
    TGAssert([[updateInfo objectForKey:@"summary"] isEqual:expected] && ![updateInfo objectForKey:@"can_get_added_reactions"], "legacy interaction update omits unavailable capability without inventing false");
    NSDictionary *invalid = TGMessageReactionInfoFromObject(TGReactionFixture(@"message_reactions_invalid.json"));
    TGAssert([[invalid objectForKey:@"summary"] isEqual:@"👍 48"], "custom/paid/unknown types and malformed or nonpositive counts must not fabricate ordinary reactions");
    TGAssert([[invalid objectForKey:@"chosen_emojis"] isEqual:[NSArray arrayWithObject:@"👍"]], "unsupported chosen identities are not offered as ordinary emoji");
    TGAssert(![[invalid objectForKey:@"can_get_added_reactions"] boolValue], "modern false capability is authoritative");

    NSMutableDictionary *overridden = [NSMutableDictionary dictionaryWithDictionary:TGReactionFixture(@"message_reactions_invalid.json")];
    [overridden setObject:@YES forKey:@"can_get_added_reactions"];
    TGAssert(![[TGMessageReactionInfoFromObject(overridden) objectForKey:@"can_get_added_reactions"] boolValue], "modern capability overrides stale top-level value");
    NSDictionary *emptyAvailable = TGMessageReactionInfoFromObject([NSDictionary dictionaryWithObjectsAndKeys:
        @YES, @"can_get_added_reactions", [NSDictionary dictionaryWithObject:[NSArray array] forKey:@"reactions"], @"interaction_info", nil]);
    TGAssert([[emptyAvailable objectForKey:@"can_get_added_reactions"] boolValue] && ![emptyAvailable objectForKey:@"summary"], "available legacy sender list remains available even without ordinary display reactions");
    TGAssert(!TGMessageReactionInfoFromObject([NSDictionary dictionaryWithObject:[NSNull null] forKey:@"interaction_info"]), "null interaction metadata is safe");
    TGAssert(!TGMessageReactionInfoFromObject([NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:@"invalid" forKey:@"reactions"] forKey:@"interaction_info"]), "invalid reaction container is safe");
    TGAssert(!TGMessageReactionInfoFromObject((id)[NSNull null]), "null message is safe");
    printf("Message reactions probe passed\n");
    [pool drain];
    return 0;
}
