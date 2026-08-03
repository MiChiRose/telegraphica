#import <Cocoa/Cocoa.h>

extern NSString * const TGCustomEmojiImageDidLoadNotification;
extern NSString * const TGCustomEmojiImageIdentifierUserInfoKey;

NSImage *TGCustomEmojiCachedImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize);
void TGCustomEmojiRequestImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize);
void TGCustomEmojiImageLoaderClearCache(void);

