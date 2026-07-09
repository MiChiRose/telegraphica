#import <Foundation/Foundation.h>

@interface TGChatItem : NSObject

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *typeSummary;
@property (nonatomic, retain) NSNumber *unreadCount;
@property (nonatomic, copy) NSString *avatarLocalPath;

- (instancetype)initWithChatID:(NSNumber *)chatID
                         title:(NSString *)title
                   typeSummary:(NSString *)typeSummary
                   unreadCount:(NSNumber *)unreadCount;
- (id)valueForTableColumnIdentifier:(id)identifier;

@end
