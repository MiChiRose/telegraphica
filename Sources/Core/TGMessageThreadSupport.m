#import "TGMessageThreadSupport.h"
#import "TGMessageItem.h"

static NSDictionary *TGThreadReplyInfo(NSDictionary *object) {
    if (![object isKindOfClass:[NSDictionary class]]) { return nil; }
    id interaction = [object objectForKey:@"interaction_info"];
    id replyInfo = [interaction isKindOfClass:[NSDictionary class]] ? [interaction objectForKey:@"reply_info"] : nil;
    return [replyInfo isKindOfClass:[NSDictionary class]] ? replyInfo : nil;
}

NSNumber *TGMessageThreadReplyCountFromObject(NSDictionary *object) {
    id count = [TGThreadReplyInfo(object) objectForKey:@"reply_count"];
    return ([count respondsToSelector:@selector(integerValue)] && [count integerValue] >= 0)
        ? [NSNumber numberWithInteger:[count integerValue]] : nil;
}

BOOL TGMessageCanGetThreadFromObject(NSDictionary *object) {
    if (![object isKindOfClass:[NSDictionary class]]) { return NO; }
    id direct = [object objectForKey:@"can_get_message_thread"];
    if ([direct respondsToSelector:@selector(boolValue)] && [direct boolValue]) { return YES; }
    NSArray *keys = [NSArray arrayWithObjects:@"message_properties", @"messageProperties", @"properties", nil];
    NSString *key = nil;
    for (key in keys) {
        id properties = [object objectForKey:key];
        id value = [properties isKindOfClass:[NSDictionary class]] ? [properties objectForKey:@"can_get_message_thread"] : nil;
        if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) { return YES; }
    }
    id replyCapability = [TGThreadReplyInfo(object) objectForKey:@"can_get_message_thread"];
    return ([replyCapability respondsToSelector:@selector(boolValue)] && [replyCapability boolValue]) ||
        TGMessageThreadReplyCountFromObject(object) != nil;
}

void TGApplyMessageThreadMetadata(TGMessageItem *item, NSDictionary *message) {
    NSNumber *count = TGMessageThreadReplyCountFromObject(message);
    [item setMessageThreadReplyCount:count];
    [item setCanGetMessageThread:TGMessageCanGetThreadFromObject(message)];
    [item setCommentThreadMessageID:[item canGetMessageThread] ? [item messageID] : nil];
}

void TGMergeMessageThreadMetadata(TGMessageItem *albumItem, TGMessageItem *item) {
    if (![item canGetMessageThread] && ![item messageThreadReplyCount]) { return; }
    NSNumber *itemCount = [item messageThreadReplyCount];
    NSNumber *albumCount = [albumItem messageThreadReplyCount];
    // Album replies are attached to one source message; never add counts from
    // multiple photos, which can describe the same discussion.
    if (![albumItem canGetMessageThread] || !albumCount ||
        [itemCount integerValue] > [albumCount integerValue]) {
        [albumItem setMessageThreadReplyCount:itemCount];
        [albumItem setCommentThreadMessageID:[item commentThreadMessageID] ? [item commentThreadMessageID] : [item messageID]];
    }
    [albumItem setCanGetMessageThread:[albumItem canGetMessageThread] || [item canGetMessageThread]];
}

NSNumber *TGMessageChatIDFromObject(NSDictionary *message, NSNumber *fallbackChatID) {
    id value = [message isKindOfClass:[NSDictionary class]] ? [message objectForKey:@"chat_id"] : nil;
    return ([value respondsToSelector:@selector(longLongValue)] && [value longLongValue] != 0)
        ? [NSNumber numberWithLongLong:[value longLongValue]] : fallbackChatID;
}

NSDictionary *TGMessageThreadDestinationFromInfo(NSDictionary *threadInfo) {
    if (![threadInfo isKindOfClass:[NSDictionary class]] ||
        ![[threadInfo objectForKey:@"@type"] isEqual:@"messageThreadInfo"]) { return nil; }
    id chat = [threadInfo objectForKey:@"chat_id"];
    id thread = [threadInfo objectForKey:@"message_thread_id"];
    if (![chat respondsToSelector:@selector(longLongValue)] || [chat longLongValue] == 0 ||
        ![thread respondsToSelector:@selector(longLongValue)] || [thread longLongValue] <= 0) { return nil; }
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithLongLong:[chat longLongValue]], @"chat_id",
        [NSNumber numberWithLongLong:[thread longLongValue]], @"message_thread_id",
        @"thread", @"message_topic_kind", nil];
}

NSDictionary *TGMessageInteractionUpdateSummary(NSDictionary *update, NSDictionary *reactionInfo) {
    if (![update isKindOfClass:[NSDictionary class]] ||
        ![[update objectForKey:@"@type"] isEqual:@"updateMessageInteractionInfo"]) { return nil; }
    id chat = [update objectForKey:@"chat_id"];
    id message = [update objectForKey:@"message_id"];
    if (![chat respondsToSelector:@selector(longLongValue)] || [chat longLongValue] == 0 ||
        ![message respondsToSelector:@selector(longLongValue)] || [message longLongValue] <= 0) { return nil; }
    NSNumber *count = TGMessageThreadReplyCountFromObject(update);
    return [NSDictionary dictionaryWithObjectsAndKeys:
        @"message_interaction_update", @"kind", @"updateMessageInteractionInfo", @"type",
        [NSNumber numberWithLongLong:[chat longLongValue]], @"chat_id",
        [NSNumber numberWithLongLong:[message longLongValue]], @"message_id",
        [NSNumber numberWithBool:TGThreadReplyInfo(update) != nil], @"has_reply_info",
        count ? (id)count : (id)[NSNull null], @"reply_count",
        [NSNumber numberWithBool:TGMessageCanGetThreadFromObject(update)], @"can_get_message_thread",
        reactionInfo ? (id)reactionInfo : (id)[NSDictionary dictionary], @"reaction_info", nil];
}

static NSDictionary *TGInteractionDisplayState(TGMessageItem *item) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [item messageThreadReplyCount] ? (id)[item messageThreadReplyCount] : (id)[NSNull null], @"count",
        [item commentThreadMessageID] ? (id)[item commentThreadMessageID] : (id)[NSNull null], @"owner",
        [NSNumber numberWithBool:[item canGetMessageThread]], @"thread_available",
        [item reactionSummary] ? (id)[item reactionSummary] : (id)[NSNull null], @"reactions",
        [item chosenReactionEmojis] ? (id)[item chosenReactionEmojis] : (id)[NSNull null], @"chosen",
        [NSNumber numberWithBool:[item canGetAddedReactions]], @"reaction_available", nil];
}

BOOL TGApplyMessageInteractionSummaryToItem(TGMessageItem *item, NSDictionary *summary) {
    if (![item isKindOfClass:[TGMessageItem class]] || ![summary isKindOfClass:[NSDictionary class]] ||
        ![[summary objectForKey:@"kind"] isEqual:@"message_interaction_update"]) { return NO; }
    id chatID = [summary objectForKey:@"chat_id"];
    id messageID = [summary objectForKey:@"message_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)] || [chatID longLongValue] == 0 ||
        ![messageID respondsToSelector:@selector(longLongValue)] || [messageID longLongValue] <= 0 ||
        ![[item chatID] respondsToSelector:@selector(longLongValue)] ||
        [[item chatID] longLongValue] != [chatID longLongValue]) { return NO; }

    long long sourceID = [messageID longLongValue];
    BOOL displayMessage = ([[item messageID] respondsToSelector:@selector(longLongValue)] &&
        [[item messageID] longLongValue] == sourceID);
    BOOL commentOwner = ([[item commentThreadMessageID] respondsToSelector:@selector(longLongValue)] &&
        [[item commentThreadMessageID] longLongValue] == sourceID);
    BOOL albumMember = NO;
    id mediaItems = [item mediaItems];
    if ([mediaItems isKindOfClass:[NSArray class]]) {
        id media = nil;
        for (media in mediaItems) {
            id memberID = [media isKindOfClass:[NSDictionary class]] ? [media objectForKey:@"message_id"] : nil;
            if ([memberID respondsToSelector:@selector(longLongValue)] && [memberID longLongValue] == sourceID) {
                albumMember = YES; break;
            }
        }
    }
    if (!displayMessage && !commentOwner && !albumMember) { return NO; }
    NSDictionary *previous = TGInteractionDisplayState(item);
    BOOL hasReplyInfo = [[summary objectForKey:@"has_reply_info"] respondsToSelector:@selector(boolValue)] &&
        [[summary objectForKey:@"has_reply_info"] boolValue];
    id rawCount = [summary objectForKey:@"reply_count"];
    NSNumber *count = ([rawCount respondsToSelector:@selector(integerValue)] && [rawCount integerValue] >= 0)
        ? [NSNumber numberWithInteger:[rawCount integerValue]] : nil;
    if (hasReplyInfo && count) {
        // A newly loaded album can acquire its first thread on any member.
        // For distinct reply owners keep the same maximum-count policy used
        // while grouping history, rather than summing multiple discussions.
        if (commentOwner || ![item messageThreadReplyCount] ||
            [count integerValue] > [[item messageThreadReplyCount] integerValue]) {
            [item setMessageThreadReplyCount:count];
            [item setCommentThreadMessageID:[NSNumber numberWithLongLong:sourceID]];
            [item setCanGetMessageThread:YES];
        }
    } else if (!hasReplyInfo && (commentOwner || (displayMessage && ![item commentThreadMessageID]))) {
        [item setMessageThreadReplyCount:nil];
        // Interaction updates do not contain authoritative messageProperties.
        // Keep the capability learned from the complete legacy/modern message.
    }

    if (displayMessage) {
        id reactions = [summary objectForKey:@"reaction_info"];
        if ([reactions isKindOfClass:[NSDictionary class]]) {
            id reactionText = [reactions objectForKey:@"summary"];
            id chosen = [reactions objectForKey:@"chosen_emojis"];
            id canGet = [reactions objectForKey:@"can_get_added_reactions"];
            [item setReactionSummary:[reactionText isKindOfClass:[NSString class]] ? reactionText : nil];
            [item setChosenReactionEmojis:[chosen isKindOfClass:[NSArray class]] ? chosen : nil];
            [item setCanGetAddedReactions:[canGet respondsToSelector:@selector(boolValue)] && [canGet boolValue]];
        }
    }
    return ![previous isEqual:TGInteractionDisplayState(item)];
}

BOOL TGMessageThreadHistoryResponseIsScoped(NSDictionary *response, NSNumber *chatID, NSNumber *threadID, NSString *topicKind) {
    if (![response isKindOfClass:[NSDictionary class]] ||
        ![chatID respondsToSelector:@selector(longLongValue)] || [chatID longLongValue] == 0 ||
        ![threadID respondsToSelector:@selector(longLongValue)] || [threadID longLongValue] <= 0) { return NO; }
    id responseType = [response objectForKey:@"@type"];
    id messages = [response objectForKey:@"messages"];
    if ((![@"messages" isEqual:responseType] && ![@"foundChatMessages" isEqual:responseType]) ||
        ![messages isKindOfClass:[NSArray class]]) { return NO; }
    BOOL wantsThread = [topicKind isEqualToString:@"thread"];
    BOOL wantsForum = [topicKind isEqualToString:@"forum"] || [topicKind isEqualToString:@"forum_legacy"];
    id message = nil;
    for (message in messages) {
        if (![message isKindOfClass:[NSDictionary class]] || ![@"message" isEqual:[message objectForKey:@"@type"]]) { return NO; }
        id messageChat = [message objectForKey:@"chat_id"];
        if (![messageChat respondsToSelector:@selector(longLongValue)] ||
            [messageChat longLongValue] != [chatID longLongValue]) { return NO; }
        id messageID = [message objectForKey:@"id"];
        // The thread's root can have topic/thread ID zero in older TDLib.
        if ([messageID respondsToSelector:@selector(longLongValue)] &&
            [messageID longLongValue] == [threadID longLongValue]) { continue; }
        id topic = [message objectForKey:@"topic_id"];
        if ([topic isKindOfClass:[NSDictionary class]]) {
            id type = [topic objectForKey:@"@type"];
            BOOL threadTopic = [@"messageTopicThread" isEqual:type];
            BOOL forumTopic = [@"messageTopicForum" isEqual:type];
            if ((!threadTopic && !forumTopic) || (wantsThread && !threadTopic) || (wantsForum && !forumTopic)) { return NO; }
            id topicID = [topic objectForKey:threadTopic ? @"message_thread_id" : @"forum_topic_id"];
            if (![topicID respondsToSelector:@selector(longLongValue)] ||
                [topicID longLongValue] != [threadID longLongValue]) { return NO; }
        } else {
            id legacyThreadID = [message objectForKey:@"message_thread_id"];
            if (![legacyThreadID respondsToSelector:@selector(longLongValue)] ||
                [legacyThreadID longLongValue] != [threadID longLongValue]) { return NO; }
        }
    }
    return YES;
}
