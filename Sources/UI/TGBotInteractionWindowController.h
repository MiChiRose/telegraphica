#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGBotInteractionWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client
              userID:(NSNumber *)userID
              chatID:(NSNumber *)chatID;
- (void)reloadBot;

@end
