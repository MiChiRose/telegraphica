#import <Foundation/Foundation.h>
#import "TGForumTopicRefreshSupport.h"

static void TGForumAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Forum refresh probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

static TGChatItem *TGForumTopic(long long threadID) {
    TGChatItem *item = [[[TGChatItem alloc] init] autorelease];
    [item setForumTopic:YES];
    [item setMessageThreadID:[NSNumber numberWithLongLong:threadID]];
    return item;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSNumber *chatID = [NSNumber numberWithLongLong:-100123];
    NSNumber *otherChatID = [NSNumber numberWithLongLong:-100456];
    TGForumAssert(TGForumTopicRefreshMatchesContext(8, 8, chatID, chatID, YES, NO), @"active presentation accepts its refresh");
    TGForumAssert(!TGForumTopicRefreshMatchesContext(8, 9, chatID, chatID, YES, NO), @"same forum reopened or refreshed again rejects stale completion");
    TGForumAssert(!TGForumTopicRefreshMatchesContext(8, 8, chatID, otherChatID, YES, NO), @"another forum rejects completion");
    TGForumAssert(!TGForumTopicRefreshMatchesContext(8, 8, chatID, chatID, NO, NO), @"hidden topics reject completion");
    TGForumAssert(!TGForumTopicRefreshMatchesContext(8, 8, chatID, chatID, YES, YES), @"closed navigation rejects completion");
    TGForumAssert(!TGForumTopicRefreshMatchesContext(8, 8, chatID, nil, YES, NO), @"missing current chat rejects completion");

    TGChatItem *first = TGForumTopic(11);
    TGChatItem *selected = TGForumTopic(22);
    TGChatItem *invalid = TGForumTopic(0);
    TGChatItem *ordinaryChat = [[[TGChatItem alloc] init] autorelease];
    [ordinaryChat setMessageThreadID:[selected messageThreadID]];
    NSArray *topics = [NSArray arrayWithObjects:[NSNull null], ordinaryChat, invalid, first, selected, nil];
    TGForumAssert(TGForumTopicItemForPreferredThreadID(topics, [selected messageThreadID]) == selected, @"refresh keeps a non-first selected topic despite invalid rows");
    NSArray *reordered = [NSArray arrayWithObjects:selected, first, nil];
    TGForumAssert(TGForumTopicItemForPreferredThreadID(reordered, [first messageThreadID]) == first, @"pin/reorder preserves topic identity");
    TGForumAssert(TGForumTopicItemForPreferredThreadID(topics, [NSNumber numberWithInt:33]) == first, @"deleted selected topic falls back to first valid topic");
    TGForumAssert(TGForumTopicItemForPreferredThreadID(topics, nil) == first, @"missing selection chooses first valid topic");
    TGForumAssert(TGForumTopicItemForPreferredThreadID([NSArray arrayWithObjects:ordinaryChat, invalid, nil], nil) == nil, @"no valid topic leaves no selection");
    printf("Forum topic refresh probe passed.\n");
    [pool drain];
    return 0;
}
