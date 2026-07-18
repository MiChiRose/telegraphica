#import <Foundation/Foundation.h>

@interface TGChatItem : NSObject

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *typeSummary;
@property (nonatomic, retain) NSNumber *unreadCount;
@property (nonatomic, retain) NSNumber *lastReadOutboxMessageID;
@property (nonatomic, retain) NSNumber *chatListOrder;
@property (nonatomic, copy) NSString *avatarLocalPath;
@property (nonatomic, assign) BOOL serverNotificationsMuted;
@property (nonatomic, assign) BOOL notificationsMuted;
@property (nonatomic, assign, getter=isPinned) BOOL pinned;
@property (nonatomic, assign, getter=isForumTopic) BOOL forumTopic;
@property (nonatomic, assign, getter=isSavedMessages) BOOL savedMessages;
@property (nonatomic, retain) NSNumber *parentChatID;
@property (nonatomic, retain) NSNumber *messageThreadID;
@property (nonatomic, copy) NSString *messageTopicKind;

- (instancetype)initWithChatID:(NSNumber *)chatID
                         title:(NSString *)title
                   typeSummary:(NSString *)typeSummary
                   unreadCount:(NSNumber *)unreadCount;
- (id)valueForTableColumnIdentifier:(id)identifier;

@end
