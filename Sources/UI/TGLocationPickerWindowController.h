#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGLocationPickerWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (NSDictionary *)runModal;

@end
