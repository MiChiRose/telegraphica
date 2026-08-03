#import <Foundation/Foundation.h>

/*
 * TDLib text entity offsets and lengths are UTF-16 code-unit indexes. That is
 * also the indexing model used by NSString, but all ranges still need strict
 * validation before they are applied to AppKit strings or sent back to TDLib.
 */
NSArray *TGValidatedTDLibTextEntities(NSArray *entities, NSString *text);

/*
 * Preserves entities wholly outside an edited span and expands an entity that
 * encloses the complete edit. Entities touched only on one boundary are
 * discarded instead of emitting an ambiguous or invalid TDLib range.
 */
NSArray *TGRebasedTDLibTextEntities(NSString *originalText,
                                   NSArray *originalEntities,
                                   NSString *editedText);

NSDictionary *TGTDLibFormattedTextObject(NSString *text, NSArray *entities);

