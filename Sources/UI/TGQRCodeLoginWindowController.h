#import <Cocoa/Cocoa.h>

@class TGTDLibClient;
@class TGQRCodeLoginWindowController;

@protocol TGQRCodeLoginWindowControllerDelegate <NSObject>
- (void)qrCodeLoginWindowControllerDidCancel:(TGQRCodeLoginWindowController *)controller;
@end

@interface TGQRCodeLoginWindowController : NSWindowController <NSWindowDelegate>

@property (nonatomic, assign) id<TGQRCodeLoginWindowControllerDelegate> delegate;

- (id)initWithClient:(TGTDLibClient *)client;
- (void)beginQRCodeAuthentication;
- (void)authorizationStateDidChange:(NSString *)state;
- (void)refreshQRCodeFromClient;

@end
