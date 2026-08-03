#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

@interface TGChatFolderSharingWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

- (id)initWithClient:(TGTDLibClient *)client;
- (void)configureWithFolderDefinition:(NSDictionary *)definition;
- (void)reloadData;

@end

