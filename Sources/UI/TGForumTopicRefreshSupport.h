#import <Foundation/Foundation.h>
#import "../Core/TGChatItem.h"

/* Refreshes may complete after closing/reopening the same forum or after a
 * newer refresh. Chat identity alone cannot distinguish those presentations. */
static inline BOOL TGForumTopicRefreshMatchesContext(NSUInteger requestGeneration,
                                                     NSUInteger currentGeneration,
                                                     NSNumber *requestChatID,
                                                     NSNumber *currentChatID,
                                                     BOOL topicsVisible,
                                                     BOOL navigationClosed) {
    return (topicsVisible && !navigationClosed &&
            requestGeneration == currentGeneration &&
            [requestChatID respondsToSelector:@selector(longLongValue)] &&
            [currentChatID respondsToSelector:@selector(longLongValue)] &&
            [requestChatID longLongValue] == [currentChatID longLongValue]);
}

/* Keep the current topic even if the server reorders the list. A deleted topic
 * falls back to the first valid topic, never to an unrelated/malformed row. */
static inline TGChatItem *TGForumTopicItemForPreferredThreadID(NSArray *items,
                                                              NSNumber *preferredThreadID) {
    TGChatItem *fallback = nil;
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]] ||
            ![(TGChatItem *)candidate isForumTopic] ||
            ![[(TGChatItem *)candidate messageThreadID] respondsToSelector:@selector(longLongValue)] ||
            [[(TGChatItem *)candidate messageThreadID] longLongValue] <= 0) {
            continue;
        }
        if (!fallback) {
            fallback = candidate;
        }
        if ([preferredThreadID respondsToSelector:@selector(longLongValue)] &&
            [[(TGChatItem *)candidate messageThreadID] longLongValue] == [preferredThreadID longLongValue]) {
            return candidate;
        }
    }
    return fallback;
}
