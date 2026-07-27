#import <Cocoa/Cocoa.h>

@interface TGLocationPickerWindowController : NSWindowController

- (id)initForVenue:(BOOL)venue;
- (NSDictionary *)runModal;

@end
