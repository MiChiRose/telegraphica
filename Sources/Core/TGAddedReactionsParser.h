#import <Foundation/Foundation.h>

extern NSString * const TGAddedReactionsItemsKey;
extern NSString * const TGAddedReactionsNextOffsetKey;
extern NSString * const TGAddedReactionSenderKey;
extern NSString * const TGAddedReactionEmojiKey;
extern NSString * const TGAddedReactionCustomEmojiIDKey;
extern NSString * const TGAddedReactionDateKey;

/* Parses getMessageAddedReactions without resolving users or touching disk. */
NSDictionary *TGAddedReactionsPageFromTDLibResponse(NSDictionary *response);

