#import <Foundation/Foundation.h>

@interface TGMessageItem : NSObject

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, retain) NSNumber *date;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, copy) NSString *preview;

- (instancetype)initWithChatID:(NSNumber *)chatID
                     messageID:(NSNumber *)messageID
                          date:(NSNumber *)date
                      outgoing:(BOOL)outgoing
                       preview:(NSString *)preview;
- (NSString *)directionSummary;
- (id)valueForTableColumnIdentifier:(id)identifier;

@end
