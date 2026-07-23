#import <Foundation/Foundation.h>

@class TGMessageItem;

@interface TGDemoSession : NSObject

@property (nonatomic, retain, readonly) NSArray *chatItems;
@property (nonatomic, retain, readonly) NSDictionary *profileSummary;

- (NSArray *)messagesForChatID:(NSNumber *)chatID;
- (NSArray *)chatItemsForFolderID:(NSNumber *)folderID;
- (NSArray *)searchMessagesForChatID:(NSNumber *)chatID query:(NSString *)query;
- (NSUInteger)deleteMessageIDs:(NSArray *)messageIDs chatID:(NSNumber *)chatID;
- (BOOL)deleteChatID:(NSNumber *)chatID;
- (TGMessageItem *)appendTextMessage:(NSString *)text
                            chatID:(NSNumber *)chatID
                     replyMessage:(TGMessageItem *)replyMessage;
- (TGMessageItem *)appendDocumentMessageWithFileName:(NSString *)fileName
                                            fileSize:(unsigned long long)fileSize
                                           typeLabel:(NSString *)typeLabel
                                             caption:(NSString *)caption
                                              chatID:(NSNumber *)chatID;
- (TGMessageItem *)appendStickerMessageWithLocalPath:(NSString *)localPath
                                               emoji:(NSString *)emoji
                                               width:(NSNumber *)width
                                              height:(NSNumber *)height
                                              chatID:(NSNumber *)chatID;
- (TGMessageItem *)appendVoiceMessageWithLocalPath:(NSString *)localPath
                                          duration:(NSNumber *)duration
                                            chatID:(NSNumber *)chatID;

@end
