#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGStorageUsageWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (void)refreshStorageUsage:(id)sender;

@end
