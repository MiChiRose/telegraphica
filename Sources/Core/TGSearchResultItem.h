#import <Foundation/Foundation.h>

@class TGMessageItem;

@interface TGSearchResultItem : NSObject

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, retain) NSNumber *messageThreadID;
@property (nonatomic, copy) NSString *messageTopicKind;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *senderName;
@property (nonatomic, retain) NSNumber *date;
@property (nonatomic, copy) NSString *snippet;
@property (nonatomic, copy) NSString *mediaType;
@property (nonatomic, assign) BOOL chatTitleOnly;
@property (nonatomic, retain) TGMessageItem *messageItem;

- (NSString *)displayTitle;
- (NSString *)displaySubtitle;
- (NSString *)dateSummary;

@end
