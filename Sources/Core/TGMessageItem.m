#import "TGMessageItem.h"

@implementation TGMessageItem

@synthesize chatID = _chatID;
@synthesize messageID = _messageID;
@synthesize date = _date;
@synthesize outgoing = _outgoing;
@synthesize sending = _sending;
@synthesize preview = _preview;
@synthesize contentType = _contentType;
@synthesize mediaLocalPath = _mediaLocalPath;
@synthesize mediaWidth = _mediaWidth;
@synthesize mediaHeight = _mediaHeight;

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
        self.sending = NO;
        self.preview = ([preview length] > 0) ? preview : @"[Message]";
    }
    return self;
}

- (BOOL)isPhotoMessage {
    return [self.contentType isEqualToString:@"messagePhoto"];
}

- (BOOL)isVisualMediaMessage {
    if ([self isPhotoMessage]) {
        return YES;
    }
    return ([self.contentType isEqualToString:@"messageSticker"] ||
            [self.contentType isEqualToString:@"messageAnimation"] ||
            [self.contentType isEqualToString:@"messageVideo"]);
}

- (NSString *)visualMediaPlaceholderTitle {
    if ([self.contentType isEqualToString:@"messageSticker"]) {
        return @"Sticker";
    }
    if ([self.contentType isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([self.contentType isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    return @"Photo";
}

- (NSString *)directionSummary {
    return self.outgoing ? @"Outgoing" : @"Incoming";
}

- (id)copyWithZone:(NSZone *)zone {
    TGMessageItem *copy = [[[self class] allocWithZone:zone] initWithChatID:_chatID
                                                                  messageID:_messageID
                                                                       date:_date
                                                                   outgoing:_outgoing
                                                                    preview:_preview];
    [copy setSending:_sending];
    [copy setContentType:_contentType];
    [copy setMediaLocalPath:_mediaLocalPath];
    [copy setMediaWidth:_mediaWidth];
    [copy setMediaHeight:_mediaHeight];
    return copy;
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
    [_contentType release];
    [_mediaLocalPath release];
    [_mediaWidth release];
    [_mediaHeight release];
    [super dealloc];
}

@end
