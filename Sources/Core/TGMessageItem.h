#import <Foundation/Foundation.h>

@interface TGMessageItem : NSObject <NSCopying>

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, retain) NSNumber *date;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, assign) BOOL outgoingRead;
@property (nonatomic, assign, getter=isPinned) BOOL pinned;
@property (nonatomic, copy) NSString *preview;
@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, copy) NSString *mediaLocalPath;
@property (nonatomic, retain) NSNumber *mediaWidth;
@property (nonatomic, retain) NSNumber *mediaHeight;
@property (nonatomic, retain) NSNumber *mediaAlbumID;
@property (nonatomic, copy) NSArray *mediaItems;
@property (nonatomic, retain) NSNumber *mediaFileID;
@property (nonatomic, retain) NSNumber *mediaDuration;
@property (nonatomic, copy) NSString *mediaMimeType;
@property (nonatomic, copy) NSString *downloadFileName;
@property (nonatomic, retain) NSNumber *downloadFileSize;
@property (nonatomic, copy) NSString *reactionSummary;
@property (nonatomic, copy) NSArray *chosenReactionEmojis;
@property (nonatomic, retain) NSNumber *senderID;
@property (nonatomic, copy) NSString *senderDisplayName;
@property (nonatomic, copy) NSString *senderAvatarLocalPath;
@property (nonatomic, retain) NSNumber *replyToMessageID;
@property (nonatomic, copy) NSString *replyPreview;
@property (nonatomic, copy) NSString *replySenderDisplayName;
@property (nonatomic, copy) NSString *forwardSourceDisplayName;
@property (nonatomic, assign) BOOL capabilitiesKnown;
@property (nonatomic, assign) BOOL canBeReplied;
@property (nonatomic, assign) BOOL canBeEdited;
@property (nonatomic, assign) BOOL canBeDeletedOnlyForSelf;
@property (nonatomic, assign) BOOL canBeDeletedForAllUsers;
@property (nonatomic, retain) NSNumber *editDate;
@property (nonatomic, copy) NSString *editableText;
@property (nonatomic, assign) BOOL canGetMessageThread;
@property (nonatomic, retain) NSNumber *messageThreadReplyCount;

- (instancetype)initWithChatID:(NSNumber *)chatID
                     messageID:(NSNumber *)messageID
                          date:(NSNumber *)date
                      outgoing:(BOOL)outgoing
                       preview:(NSString *)preview;
- (BOOL)isPhotoMessage;
- (BOOL)isStickerMessage;
- (BOOL)isDocumentMessage;
- (BOOL)isVisualMediaMessage;
- (BOOL)isPlayableMediaMessage;
- (BOOL)isVoiceNoteMessage;
- (BOOL)isVideoNoteMessage;
- (BOOL)isMediaAlbumMessage;
- (NSArray *)visualMediaItems;
- (void)addVisualMediaFromMessageItem:(TGMessageItem *)item;
- (NSString *)visualMediaPlaceholderTitle;
- (NSString *)directionSummary;
- (id)valueForTableColumnIdentifier:(id)identifier;

@end
