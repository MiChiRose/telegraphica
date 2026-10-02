#import <Foundation/Foundation.h>
#import "TGMessageThreadSupport.h"
#import "TGMessageItem.h"
#import "TGTDLibClient+MessageThreads.h"

static NSDictionary *TGThreadFixture(NSString *name) {
    NSString *path = [@"Tests/Fixtures" stringByAppendingPathComponent:name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) { fprintf(stderr, "Missing thread fixture: %s\n", [path UTF8String]); exit(1); }
    id fixture = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![fixture isKindOfClass:[NSDictionary class]]) { fprintf(stderr, "Invalid thread fixture\n"); exit(1); }
    return fixture;
}

@implementation TGTDLibClient
@end

@interface TGThreadProbeClient : TGTDLibClient
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) NSDictionary *response;
@property (nonatomic, copy) NSString *failType;
@property (nonatomic, copy) NSString *fixtureRuntime;
@end
@implementation TGThreadProbeClient
@synthesize requests = _requests, response = _response, failType = _failType, fixtureRuntime = _fixtureRuntime;
- (id)init { self = [super init]; if (self) { self.requests = [NSMutableArray array]; } return self; }
- (void)dealloc { [_requests release]; [_response release]; [_failType release]; [_fixtureRuntime release]; [super dealloc]; }
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error { (void)timeout; (void)error; return @"ready"; }
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code { return [NSError errorWithDomain:@"TGThreadProbe" code:code userInfo:[NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey]]; }
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)prefix timeout:(NSTimeInterval)timeout errorCode:(NSInteger)code error:(NSError **)error {
    (void)prefix; (void)timeout; (void)code;
    [self.requests addObject:request];
    if ([[request objectForKey:@"@type"] isEqual:self.failType]) {
        if (error) { *error = [self errorWithDescription:@"Unsupported fixture schema" code:400]; }
        return nil;
    }
    if ([self.fixtureRuntime length] > 0) {
        // Exercise actual JSON fields, as tdjson sees them. The legacy fixture
        // ignores topic_id; the modern fixture ignores message_thread_id.
        NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:NULL];
        NSDictionary *serialized = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        BOOL modern = [self.fixtureRuntime isEqualToString:@"modern"];
        id scope = modern ? [[serialized objectForKey:@"topic_id"] objectForKey:@"message_thread_id"]
                          : [serialized objectForKey:@"message_thread_id"];
        BOOL scoped = [scope respondsToSelector:@selector(longLongValue)] && [scope longLongValue] == 700;
        if ([self.fixtureRuntime isEqualToString:@"unscoped"]) { scoped = NO; }
        return TGThreadFixture(scoped ? (modern ? @"message_thread_history_modern.json" : @"message_thread_history_legacy.json")
                                     : @"message_thread_history_unscoped.json");
    }
    return self.response;
}
- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID { (void)chatID; return messages; }
@end

static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Message thread probe failed: %s\n", message); exit(1); }
}
static NSDictionary *TGMessageWithReplies(NSInteger count) {
    return [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:
        [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:count] forKey:@"reply_count"]
        forKey:@"reply_info"] forKey:@"interaction_info"];
}
static TGMessageItem *TGItem(long long messageID, NSInteger count) {
    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@42 messageID:[NSNumber numberWithLongLong:messageID] date:@0 outgoing:NO preview:@"Photo"] autorelease];
    TGApplyMessageThreadMetadata(item, TGMessageWithReplies(count));
    return item;
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGAssert(TGMessageCanGetThreadFromObject(TGMessageWithReplies(0)), "zero-comment channel discussion must remain available on modern TDLib");
    TGAssert([TGMessageThreadReplyCountFromObject(TGMessageWithReplies(17)) integerValue] == 17, "reply count parsed");
    TGAssert(!TGMessageCanGetThreadFromObject([NSDictionary dictionaryWithObject:[NSNull null] forKey:@"interaction_info"]), "null interaction metadata must be safe");
    TGAssert(!TGMessageThreadReplyCountFromObject(TGMessageWithReplies(-1)), "negative count rejected");
    TGAssert(TGMessageCanGetThreadFromObject([NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:@YES forKey:@"can_get_message_thread"] forKey:@"message_properties"]), "nested modern properties capability");
    TGAssert(TGMessageCanGetThreadFromObject([NSDictionary dictionaryWithObject:@YES forKey:@"can_get_message_thread"]), "legacy direct capability");
    TGAssert([TGMessageChatIDFromObject([NSDictionary dictionaryWithObject:@-999 forKey:@"chat_id"], @42) longLongValue] == -999, "discussion messages must retain their actual chat ID");
    TGAssert([TGMessageChatIDFromObject([NSDictionary dictionary], @42) longLongValue] == 42, "fixture without chat ID retains fallback");

    TGMessageItem *album = TGItem(300, 0);
    TGMessageItem *source = TGItem(200, 9);
    TGMergeMessageThreadMetadata(album, source);
    [album setMessageID:@100];
    TGAssert([[album messageThreadReplyCount] integerValue] == 9 && [[album commentThreadMessageID] longLongValue] == 200, "album must preserve count and original comment owner when display ID changes");
    TGMergeMessageThreadMetadata(album, TGItem(100, 9));
    TGAssert([[album messageThreadReplyCount] integerValue] == 9, "album reply counts must not be summed");
    TGMessageItem *copy = [[album copy] autorelease];
    TGAssert([[copy commentThreadMessageID] longLongValue] == 200, "copy preserves comment owner");

    NSMutableDictionary *update = [NSMutableDictionary dictionaryWithDictionary:TGMessageWithReplies(12)];
    [update setObject:@"updateMessageInteractionInfo" forKey:@"@type"];
    [update setObject:@42 forKey:@"chat_id"]; [update setObject:@200 forKey:@"message_id"];
    NSDictionary *summary = TGMessageInteractionUpdateSummary(update, [NSDictionary dictionaryWithObject:@"A 2" forKey:@"summary"]);
    TGAssert([[summary objectForKey:@"kind"] isEqual:@"message_interaction_update"] && [[summary objectForKey:@"reply_count"] integerValue] == 12, "interaction update has targeted count payload");
    TGAssert([[[summary objectForKey:@"reaction_info"] objectForKey:@"summary"] isEqual:@"A 2"], "targeted update retains parsed reactions");
    [update setObject:[NSNull null] forKey:@"interaction_info"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGAssert([summary objectForKey:@"reply_count"] == [NSNull null] && ![[summary objectForKey:@"has_reply_info"] boolValue], "removed reply info can clear old count");

    TGMessageItem *lateAlbum = [[[TGMessageItem alloc] initWithChatID:@42 messageID:@100 date:@0 outgoing:NO preview:@"Photos"] autorelease];
    [lateAlbum setMediaItems:[NSArray arrayWithObjects:
        [NSDictionary dictionaryWithObject:@100 forKey:@"message_id"],
        [NSDictionary dictionaryWithObject:@200 forKey:@"message_id"],
        [NSNull null], nil]];
    [update setObject:[TGMessageWithReplies(12) objectForKey:@"interaction_info"] forKey:@"interaction_info"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGAssert(TGApplyMessageInteractionSummaryToItem(lateAlbum, summary), "first reply metadata on non-display album member changes row");
    TGAssert([[lateAlbum messageThreadReplyCount] integerValue] == 12 && [[lateAlbum commentThreadMessageID] longLongValue] == 200, "late album update discovers its actual comment owner");
    TGAssert(!TGApplyMessageInteractionSummaryToItem(lateAlbum, summary), "unchanged reply metadata avoids redundant redraw");
    [update setObject:@100 forKey:@"message_id"]; [update setObject:[NSNull null] forKey:@"interaction_info"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGApplyMessageInteractionSummaryToItem(lateAlbum, summary);
    TGAssert([[lateAlbum messageThreadReplyCount] integerValue] == 12 && [[lateAlbum commentThreadMessageID] longLongValue] == 200, "non-owner reaction/view update cannot erase album comments");
    [update setObject:@200 forKey:@"message_id"];
    [update setObject:[TGMessageWithReplies(0) objectForKey:@"interaction_info"] forKey:@"interaction_info"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGAssert(TGApplyMessageInteractionSummaryToItem(lateAlbum, summary) && [[lateAlbum messageThreadReplyCount] integerValue] == 0 && [lateAlbum canGetMessageThread], "owner can become zero-count discussion without hiding comment bar");
    [update setObject:[NSNull null] forKey:@"interaction_info"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGAssert(TGApplyMessageInteractionSummaryToItem(lateAlbum, summary) && ![lateAlbum messageThreadReplyCount] && [lateAlbum canGetMessageThread], "owner removal clears count while preserving known capability");
    [update setObject:@-999 forKey:@"chat_id"];
    TGAssert(!TGApplyMessageInteractionSummaryToItem(lateAlbum, TGMessageInteractionUpdateSummary(update, nil)), "same message ID from different chat cannot mutate row");
    [update setObject:@42 forKey:@"chat_id"]; [update setObject:@987 forKey:@"message_id"];
    TGAssert(!TGApplyMessageInteractionSummaryToItem(lateAlbum, TGMessageInteractionUpdateSummary(update, nil)), "unrelated message cannot mutate album");
    TGMessageItem *legacy = [[[TGMessageItem alloc] initWithChatID:@42 messageID:@100 date:@0 outgoing:NO preview:@"Legacy"] autorelease];
    [legacy setCanGetMessageThread:YES];
    [legacy setReactionSummary:@"A 2"]; [legacy setChosenReactionEmojis:[NSArray arrayWithObject:@"A"]]; [legacy setCanGetAddedReactions:YES];
    [update setObject:@100 forKey:@"message_id"];
    summary = TGMessageInteractionUpdateSummary(update, nil);
    TGAssert(TGApplyMessageInteractionSummaryToItem(legacy, summary) && ![legacy reactionSummary] && ![legacy chosenReactionEmojis], "empty reactions clear previously displayed reaction metadata");
    TGAssert([legacy canGetAddedReactions], "absent interaction capability preserves previously learned legacy sender-list access");
    NSDictionary *explicitUnavailable = [NSDictionary dictionaryWithObject:@NO forKey:@"can_get_added_reactions"];
    summary = TGMessageInteractionUpdateSummary(update, explicitUnavailable);
    TGAssert(TGApplyMessageInteractionSummaryToItem(legacy, summary) && ![legacy canGetAddedReactions], "explicit false interaction capability clears sender-list access");
    TGAssert([legacy canGetMessageThread], "reaction-only update preserves direct legacy capability");
    TGAssert(!TGApplyMessageInteractionSummaryToItem(legacy, summary), "view-count-only update with unchanged empty metadata avoids redraw");

    // TDLib updates are per source message, even when the UI displays an
    // aggregate album under its earliest message ID. Keep each source intact.
    NSDictionary *albumFixture = TGThreadFixture(@"message_album_reaction_updates.json");
    TGMessageItem *reactionAlbum = nil;
    for (NSDictionary *member in [albumFixture objectForKey:@"members"]) {
        TGMessageItem *photo = [[[TGMessageItem alloc] initWithChatID:@42 messageID:[member objectForKey:@"message_id"] date:@0 outgoing:NO preview:@"Photo"] autorelease];
        [photo setContentType:@"messagePhoto"];
        [photo setMediaLocalPath:@"/tmp/synthetic-album-photo.jpg"];
        [photo setReactionSummary:[member objectForKey:@"summary"]];
        [photo setChosenReactionEmojis:[member objectForKey:@"chosen_emojis"]];
        [photo setCanGetAddedReactions:[[member objectForKey:@"can_get_added_reactions"] boolValue]];
        if (!reactionAlbum) {
            reactionAlbum = [[photo copy] autorelease];
            [reactionAlbum setMediaItems:[photo visualMediaItems]];
        } else { [reactionAlbum addVisualMediaFromMessageItem:photo]; }
    }
    [reactionAlbum setMessageID:@100];
    NSString *sixReactions = @"❤️ 44  👍 11  🔥 7  😁 4  😢 3  🤔";
    TGAssert([[reactionAlbum reactionSummary] isEqual:sixReactions], "initial album aggregation keeps six complete reaction totals");
    TGAssert([[reactionAlbum chosenReactionEmojis] containsObject:@"❤️"] && [[reactionAlbum chosenReactionEmojis] containsObject:@"🤔"], "initial album chosen identities include all members");
    NSDictionary *displayUpdate = [albumFixture objectForKey:@"display_member_update"];
    NSDictionary *displayReactions = [albumFixture objectForKey:@"display_member_reactions"];
    summary = TGMessageInteractionUpdateSummary(displayUpdate, displayReactions);
    TGAssert(TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary), "display-member update applies its chosen metadata");
    TGAssert([[reactionAlbum reactionSummary] isEqual:sixReactions], "single-reaction display-member update must not replace six-reaction album aggregate");
    TGAssert([[reactionAlbum chosenReactionEmojis] isEqual:[NSArray arrayWithObject:@"🤔"]] && [reactionAlbum canGetAddedReactions], "chosen removal affects one member; absent capability preserves snapshot");
    TGAssert(!TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary), "repeating member update does not double counts or redraw");
    NSDictionary *otherUpdate = [albumFixture objectForKey:@"other_member_update"];
    NSDictionary *otherReactions = [albumFixture objectForKey:@"other_member_reactions"];
    summary = TGMessageInteractionUpdateSummary(otherUpdate, otherReactions);
    TGAssert(TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary), "non-display album member update must reach its row");
    TGAssert([[reactionAlbum reactionSummary] isEqual:@"❤️ 51  👍 11  🔥 7  😁 4  😢 3  🤔"], "changed member replaces its old count instead of adding both snapshots");
    TGAssert([[reactionAlbum chosenReactionEmojis] isEqual:[NSArray arrayWithObject:@"👍"]] && [reactionAlbum canGetAddedReactions], "another member's capability remains after explicit false on updated member");
    TGMessageItem *albumCopy = [[reactionAlbum copy] autorelease];
    summary = TGMessageInteractionUpdateSummary(displayUpdate, nil);
    TGAssert(TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary) && [[reactionAlbum reactionSummary] isEqual:[otherReactions objectForKey:@"summary"]], "member removal subtracts only its reaction count");
    TGAssert([[albumCopy reactionSummary] isEqual:@"❤️ 51  👍 11  🔥 7  😁 4  😢 3  🤔"], "updating album snapshots does not mutate a copied item");
    TGAssert([reactionAlbum canGetAddedReactions], "missing capability on removal preserves available member flag");
    summary = TGMessageInteractionUpdateSummary(displayUpdate, explicitUnavailable);
    TGAssert(TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary) && ![reactionAlbum canGetAddedReactions], "sender-list capability clears when no member permits it");
    summary = TGMessageInteractionUpdateSummary(otherUpdate, explicitUnavailable);
    TGAssert(TGApplyMessageInteractionSummaryToItem(reactionAlbum, summary) && ![reactionAlbum reactionSummary] && ![reactionAlbum chosenReactionEmojis], "removing last member reactions clears aggregate and chosen identities");

    TGThreadProbeClient *client = [[[TGThreadProbeClient alloc] init] autorelease];
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"messageThreadInfo", @"@type", @-999, @"chat_id", @700, @"message_thread_id", nil];
    NSDictionary *destination = [client resolveMessageThreadForChatID:@42 messageID:@200 timeout:1 error:NULL];
    TGAssert([[destination objectForKey:@"chat_id"] longLongValue] == -999 && [[destination objectForKey:@"message_thread_id"] longLongValue] == 700, "channel thread resolves distinct discussion chat and root");
    TGAssert([[[client.requests lastObject] objectForKey:@"message_id"] longLongValue] == 200, "resolution uses comment owning source message");
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"messageThreadInfo", @"@type", @0, @"chat_id", @700, @"message_thread_id", nil];
    NSError *error = nil;
    TGAssert(![client resolveMessageThreadForChatID:@42 messageID:@200 timeout:1 error:&error] && error, "malformed destination fails before navigation");
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"messages", @"@type", [NSArray array], @"messages", nil];
    [client.requests removeAllObjects];
    [client recentMessagePreviewItemsForChatID:@-999 messageThreadID:@700 messageTopicKind:@"thread" limit:20 timeout:1 error:NULL];
    NSDictionary *request = [client.requests lastObject];
    TGAssert([[request objectForKey:@"@type"] isEqual:@"getMessageThreadHistory"] && [[request objectForKey:@"chat_id"] longLongValue] == -999 && [[request objectForKey:@"message_id"] longLongValue] == 700, "resolved discussion history must use its own chat and root");
    [client.requests removeAllObjects];
    [client messagePreviewItemsForChatID:@42 messageThreadID:@77 messageTopicKind:@"forum" aroundMessageID:@900 newerMessageCount:5 limit:20 timeout:1 error:NULL];
    request = [client.requests lastObject];
    TGAssert([[request objectForKey:@"@type"] isEqual:@"getForumTopicHistory"] && [[request objectForKey:@"offset"] integerValue] == -5, "fresh forum history preserves centered request");
    [client.requests removeAllObjects]; client.failType = @"getForumTopicHistory";
    [client recentMessagePreviewItemsForChatID:@42 messageThreadID:@77 messageTopicKind:@"forum_legacy" limit:20 timeout:1 error:NULL];
    request = [client.requests lastObject];
    TGAssert([[request objectForKey:@"@type"] isEqual:@"searchChatMessages"] && [[[request objectForKey:@"topic_id"] objectForKey:@"@type"] isEqual:@"messageTopicForum"], "forum fallback remains topic scoped");
    [client.requests removeAllObjects]; client.failType = @"getMessageThreadHistory";
    [client recentMessagePreviewItemsForChatID:@42 messageThreadID:@77 messageTopicKind:@"thread" limit:20 timeout:1 error:NULL];
    request = [client.requests lastObject];
    TGAssert([[[request objectForKey:@"topic_id"] objectForKey:@"@type"] isEqual:@"messageTopicThread"], "thread fallback must not accidentally load a forum");
    // These nonempty fixtures reproduce a legacy tdjson parser silently
    // ignoring an unknown newer topic_id and returning another discussion.
    client.failType = @"getMessageThreadHistory";
    client.fixtureRuntime = @"legacy"; [client.requests removeAllObjects];
    NSArray *legacyHistory = [client recentMessagePreviewItemsForChatID:@-999 messageThreadID:@700 messageTopicKind:@"thread" limit:20 timeout:1 error:NULL];
    TGAssert([legacyHistory count] == 2 && [[[legacyHistory objectAtIndex:0] objectForKey:@"message_thread_id"] longLongValue] == 700, "legacy fallback must use its recognized JSON field, never unrelated group history");
    request = [client.requests lastObject];
    TGAssert([[request objectForKey:@"message_thread_id"] longLongValue] == 700 && [[[request objectForKey:@"topic_id"] objectForKey:@"message_thread_id"] longLongValue] == 700, "fallback request supplies matching scope in both schema generations");
    client.fixtureRuntime = @"modern"; [client.requests removeAllObjects];
    NSArray *modernHistory = [client recentMessagePreviewItemsForChatID:@-999 messageThreadID:@700 messageTopicKind:@"thread" limit:20 timeout:1 error:NULL];
    TGAssert([modernHistory count] == 1 && [[[[modernHistory objectAtIndex:0] objectForKey:@"topic_id"] objectForKey:@"message_thread_id"] longLongValue] == 700, "modern fallback remains scoped by topic_id");
    client.fixtureRuntime = @"unscoped"; [client.requests removeAllObjects]; error = nil;
    TGAssert(![client recentMessagePreviewItemsForChatID:@-999 messageThreadID:@700 messageTopicKind:@"thread" limit:20 timeout:1 error:&error] && error, "unscoped nonempty fallback response must fail rather than display another discussion");
    TGAssert([client.requests count] == 3, "invalid topic fallback must try the next legacy schema before failing");
    NSDictionary *unscoped = TGThreadFixture(@"message_thread_history_unscoped.json");
    TGAssert(!TGMessageThreadHistoryResponseIsScoped(unscoped, @-999, @700, @"thread"), "another root's serialized messages are rejected");
    TGAssert(TGMessageThreadHistoryResponseIsScoped(TGThreadFixture(@"message_thread_history_legacy.json"), @-999, @700, @"thread"), "legacy exact root with zero thread metadata is a valid anchor");
    TGAssert(!TGMessageThreadHistoryResponseIsScoped(TGThreadFixture(@"message_thread_history_legacy.json"), @-123, @700, @"thread"), "colliding thread IDs in another chat cannot pass validation");
    NSMutableDictionary *mixedResponse = [NSMutableDictionary dictionaryWithDictionary:TGThreadFixture(@"message_thread_history_modern.json")];
    [mixedResponse setObject:[NSArray arrayWithObjects:
        [[TGThreadFixture(@"message_thread_history_modern.json") objectForKey:@"messages"] objectAtIndex:0],
        [[unscoped objectForKey:@"messages"] objectAtIndex:0], nil] forKey:@"messages"];
    TGAssert(!TGMessageThreadHistoryResponseIsScoped(mixedResponse, @-999, @700, @"thread"), "mixed correct and unrelated results must not be accepted as a scoped page");

    NSDictionary *forumMessage = [NSDictionary dictionaryWithObjectsAndKeys:
        @"message", @"@type", @-999, @"chat_id", @701, @"id",
        [NSDictionary dictionaryWithObjectsAndKeys:@"messageTopicForum", @"@type", @700, @"forum_topic_id", nil], @"topic_id", nil];
    NSDictionary *forumResponse = [NSDictionary dictionaryWithObjectsAndKeys:@"foundChatMessages", @"@type", [NSArray arrayWithObject:forumMessage], @"messages", nil];
    TGAssert(TGMessageThreadHistoryResponseIsScoped(forumResponse, @-999, @700, @"forum"), "matching fresh forum metadata remains supported");
    TGAssert(!TGMessageThreadHistoryResponseIsScoped(forumResponse, @-999, @700, @"thread"), "equal numeric IDs with a different topic kind must not pass validation");
    TGAssert(!TGMessageThreadHistoryResponseIsScoped(TGThreadFixture(@"message_thread_history_modern.json"), @-999, @700, @"forum"), "forum fallback must not accept another kind of topic with the same ID");

    printf("Message thread probe passed.\n"); [pool drain]; return 0;
}
