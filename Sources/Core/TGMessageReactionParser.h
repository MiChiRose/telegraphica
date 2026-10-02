#import <Foundation/Foundation.h>

// Parses message/update interaction metadata across TDLib reaction schemas.
// Returns summary, chosen_emojis and optional can_get_added_reactions.
// A missing capability is unknown, rather than false. No UI or I/O.
NSDictionary *TGMessageReactionInfoFromObject(NSDictionary *messageObject);
