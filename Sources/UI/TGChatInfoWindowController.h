#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGChatInfoWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
               title:(NSString *)title;
- (void)reloadChatInfo;

@end
