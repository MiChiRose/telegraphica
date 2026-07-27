#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGScheduledMessagesWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
               title:(NSString *)title;
- (void)reloadMessages;

@end
