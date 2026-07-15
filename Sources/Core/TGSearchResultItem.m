#import "TGSearchResultItem.h"
#import "TGMessageItem.h"

@implementation TGSearchResultItem

@synthesize chatID = _chatID;
@synthesize messageID = _messageID;
@synthesize messageThreadID = _messageThreadID;
@synthesize messageTopicKind = _messageTopicKind;
@synthesize chatTitle = _chatTitle;
@synthesize senderName = _senderName;
@synthesize date = _date;
@synthesize snippet = _snippet;
@synthesize mediaType = _mediaType;
@synthesize chatTitleOnly = _chatTitleOnly;
@synthesize messageItem = _messageItem;

- (NSString *)displayTitle {
    if ([self.chatTitle length] > 0) {
        return self.chatTitle;
    }
    return self.chatTitleOnly ? @"Chat" : @"Message";
}

- (NSString *)displaySubtitle {
    NSMutableArray *parts = [NSMutableArray array];
    if ([self.senderName length] > 0) {
        [parts addObject:self.senderName];
    }
    if ([self.mediaType length] > 0 && ![self.mediaType isEqualToString:@"messageText"]) {
        [parts addObject:self.mediaType];
    }
    if ([self.snippet length] > 0) {
        [parts addObject:self.snippet];
    }
    return [parts componentsJoinedByString:@" · "];
}

- (NSString *)dateSummary {
    if (![self.date respondsToSelector:@selector(integerValue)] || [self.date integerValue] <= 0) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[self.date integerValue]];
    return [NSDateFormatter localizedStringFromDate:date
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterShortStyle];
}

- (void)dealloc {
    [_chatID release];
    [_messageID release];
    [_messageThreadID release];
    [_messageTopicKind release];
    [_chatTitle release];
    [_senderName release];
    [_date release];
    [_snippet release];
    [_mediaType release];
    [_messageItem release];
    [super dealloc];
}

@end
