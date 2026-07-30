#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGQRCodeLoginWindowController : NSWindowController <NSWindowDelegate>

- (id)initWithClient:(TGTDLibClient *)client;
- (void)beginQRCodeAuthentication;
- (void)authorizationStateDidChange:(NSString *)state;
- (void)refreshQRCodeFromClient;

@end
