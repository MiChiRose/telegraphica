#import <Cocoa/Cocoa.h>

@interface TGStatusWindowController : NSWindowController

- (instancetype)initWithDemoMode:(BOOL)demoMode;
- (void)prepareForApplicationTermination;

@end
