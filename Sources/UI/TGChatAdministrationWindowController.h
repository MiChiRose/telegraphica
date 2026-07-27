#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGChatAdministrationWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client chatID:(NSNumber *)chatID title:(NSString *)title;
- (void)reloadAdministration;

@end
