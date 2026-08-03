#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGStorageUsageWindowController : NSWindowController

- (id)initWithClient:(TGTDLibClient *)client;
- (void)setSelectedChatID:(NSNumber *)chatID title:(NSString *)title;
- (void)refreshStorageUsage:(id)sender;

@end
