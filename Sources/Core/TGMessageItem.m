#import "TGMessageItem.h"

@implementation TGMessageItem

@synthesize chatID = _chatID;
@synthesize messageID = _messageID;
@synthesize date = _date;
@synthesize outgoing = _outgoing;
@synthesize preview = _preview;

- (instancetype)initWithChatID:(NSNumber *)chatID
                     messageID:(NSNumber *)messageID
                          date:(NSNumber *)date
                      outgoing:(BOOL)outgoing
                       preview:(NSString *)preview {
    self = [super init];
    if (self) {
        self.chatID = chatID;
        self.messageID = messageID;
        self.date = date ? date : [NSNumber numberWithInteger:0];
        self.outgoing = outgoing;
        self.preview = ([preview length] > 0) ? preview : @"[Message]";
    }
    return self;
}

- (NSString *)directionSummary {
    return self.outgoing ? @"Outgoing" : @"Incoming";
}

- (id)valueForTableColumnIdentifier:(id)identifier {
    if ([identifier isEqual:@"date"]) {
        return self.date;
    }
    if ([identifier isEqual:@"direction"]) {
        return [self directionSummary];
    }
    if ([identifier isEqual:@"preview"]) {
        return self.preview;
    }
    if ([identifier isEqual:@"message_id"]) {
        return self.messageID;
    }
    if ([identifier isEqual:@"chat_id"]) {
        return self.chatID;
    }
    return @"";
}

- (void)dealloc {
    [_chatID release];
    [_messageID release];
    [_date release];
    [_preview release];
    [super dealloc];
}

@end
