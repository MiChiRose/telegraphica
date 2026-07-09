#import "TGChatItem.h"

@implementation TGChatItem

@synthesize chatID = _chatID;
@synthesize title = _title;
@synthesize typeSummary = _typeSummary;
@synthesize unreadCount = _unreadCount;

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
    if ([identifier isEqual:@"chat_id"]) {
        return self.chatID;
    }
    return @"";
}

- (void)dealloc {
    [_chatID release];
    [_title release];
    [_typeSummary release];
    [_unreadCount release];
    [super dealloc];
}

@end
