#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGSavedMessagesWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (void)reloadSavedMessages;

@end
