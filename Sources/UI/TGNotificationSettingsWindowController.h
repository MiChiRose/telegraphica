#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGNotificationSettingsWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (void)reloadExceptions;

@end
