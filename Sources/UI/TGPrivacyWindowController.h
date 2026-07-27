#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGPrivacyWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (void)reloadPrivacy;

@end
