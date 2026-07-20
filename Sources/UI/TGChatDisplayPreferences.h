#import <Cocoa/Cocoa.h>

extern NSString * const TGChatDisplayPreferencesDidChangeNotification;

typedef enum {
    TGChatMessageTextSizeSmall = 0,
    TGChatMessageTextSizeNormal = 1,
    TGChatMessageTextSizeLarge = 2,
    TGChatMessageTextSizeVeryLarge = 3
} TGChatMessageTextSize;

BOOL TGChatMessagesAsBlocksEnabled(void);
void TGSetChatMessagesAsBlocksEnabled(BOOL enabled);
BOOL TGChatMessagesAsBlocksEnabledForTarget(NSNumber *chatID, NSNumber *messageThreadID);
void TGSetChatMessagesAsBlocksEnabledForTarget(NSNumber *chatID, NSNumber *messageThreadID, BOOL enabled);
void TGClearChatMessagesAsBlocksOverrideForTarget(NSNumber *chatID, NSNumber *messageThreadID);

NSInteger TGChatMessageTextSizeLevel(void);
void TGSetChatMessageTextSizeLevel(NSInteger level);
NSInteger TGChatMessageTextSizeLevelForTarget(NSNumber *chatID, NSNumber *messageThreadID);
void TGSetChatMessageTextSizeLevelForTarget(NSNumber *chatID, NSNumber *messageThreadID, NSInteger level);
void TGClearChatMessageTextSizeOverrideForTarget(NSNumber *chatID, NSNumber *messageThreadID);
NSString *TGChatMessageTextSizeLocalizationKeyForLevel(NSInteger level);

CGFloat TGChatMessageBodyFontSize(void);
CGFloat TGChatMessageSecondaryFontSize(void);
CGFloat TGChatMessageMetaFontSize(void);
NSFont *TGChatMessageBodyFont(void);
NSFont *TGChatMessageBoldBodyFont(void);
NSFont *TGChatMessageSecondaryFont(void);
NSFont *TGChatMessageBoldSecondaryFont(void);
NSFont *TGChatMessageMetaFont(void);
