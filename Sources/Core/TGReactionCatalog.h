#import <Foundation/Foundation.h>

extern NSString * const TGReactionCatalogEmojiItemsKey;
extern NSString * const TGReactionCatalogCustomEmojiItemsKey;
extern NSString * const TGReactionCatalogAreTagsKey;
extern NSString * const TGReactionCatalogUnavailableKey;

/*
 * Normalizes getMessageAvailableReactions responses across TDLib revisions.
 * Paid and Premium-only reaction choices are intentionally omitted.
 */
NSDictionary *TGReactionCatalogFromTDLibResponse(NSDictionary *response);

