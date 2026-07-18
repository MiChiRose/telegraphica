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

NSInteger TGChatMessageTextSizeLevel(void);
void TGSetChatMessageTextSizeLevel(NSInteger level);
NSString *TGChatMessageTextSizeLocalizationKeyForLevel(NSInteger level);

CGFloat TGChatMessageBodyFontSize(void);
CGFloat TGChatMessageSecondaryFontSize(void);
CGFloat TGChatMessageMetaFontSize(void);
NSFont *TGChatMessageBodyFont(void);
NSFont *TGChatMessageBoldBodyFont(void);
NSFont *TGChatMessageSecondaryFont(void);
NSFont *TGChatMessageBoldSecondaryFont(void);
NSFont *TGChatMessageMetaFont(void);
