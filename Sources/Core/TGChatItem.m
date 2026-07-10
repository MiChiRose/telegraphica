#import "TGChatItem.h"

@implementation TGChatItem

@synthesize chatID = _chatID;
@synthesize title = _title;
@synthesize typeSummary = _typeSummary;
@synthesize unreadCount = _unreadCount;
@synthesize lastReadOutboxMessageID = _lastReadOutboxMessageID;
@synthesize avatarLocalPath = _avatarLocalPath;
@synthesize forumTopic = _forumTopic;
@synthesize parentChatID = _parentChatID;
@synthesize messageThreadID = _messageThreadID;
@synthesize messageTopicKind = _messageTopicKind;

- (instancetype)initWithChatID:(NSNumber *)chatID
                         title:(NSString *)title
                   typeSummary:(NSString *)typeSummary
                   unreadCount:(NSNumber *)unreadCount {
    self = [super init];
    if (self) {
        self.chatID = chatID;
        self.title = ([title length] > 0) ? title : @"Untitled";
        self.typeSummary = ([typeSummary length] > 0) ? typeSummary : @"Chat";
        self.unreadCount = unreadCount ? unreadCount : [NSNumber numberWithInteger:0];
    }
    return self;
}

- (id)valueForTableColumnIdentifier:(id)identifier {
    if ([identifier isEqual:@"title"]) {
        return self.title;
    }
    if ([identifier isEqual:@"type"]) {
        return self.typeSummary;
    }
    if ([identifier isEqual:@"unread_count"]) {
        return self.unreadCount;
    }
    if ([identifier isEqual:@"last_read_outbox_message_id"]) {
        return self.lastReadOutboxMessageID;
    }
    if ([identifier isEqual:@"chat_id"]) {
        return self.chatID;
    }
    if ([identifier isEqual:@"parent_chat_id"]) {
        return self.parentChatID;
    }
    if ([identifier isEqual:@"message_thread_id"]) {
        return self.messageThreadID;
    }
    if ([identifier isEqual:@"message_topic_kind"]) {
        return self.messageTopicKind;
    }
    return @"";
}

- (void)dealloc {
    [_chatID release];
    [_title release];
    [_typeSummary release];
    [_unreadCount release];
    [_lastReadOutboxMessageID release];
    [_avatarLocalPath release];
    [_parentChatID release];
    [_messageThreadID release];
    [_messageTopicKind release];
    [super dealloc];
}

@end
