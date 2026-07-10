#import <Foundation/Foundation.h>

@interface TGMessageItem : NSObject <NSCopying>

@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, retain) NSNumber *date;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, assign) BOOL outgoingRead;
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
