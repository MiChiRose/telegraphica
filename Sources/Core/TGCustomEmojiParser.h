#import <Foundation/Foundation.h>

extern NSString * const TGCustomEmojiIdentifierKey;
extern NSString * const TGCustomEmojiFileIDKey;
extern NSString * const TGCustomEmojiLocalPathKey;
extern NSString * const TGCustomEmojiFormatKey;

NSArray *TGCustomEmojiIdentifiersFromEntities(NSArray *entities);
NSDictionary *TGCustomEmojiDescriptorsFromResponse(NSDictionary *response,
                                                    NSArray *requestedIdentifiers);
NSArray *TGEntitiesByApplyingCustomEmojiDescriptors(NSArray *entities,
                                                    NSDictionary *descriptorsByIdentifier);

