#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGBotKeyboardWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
           messageID:(NSNumber *)messageID
         replyMarkup:(NSDictionary *)replyMarkup;

@end
