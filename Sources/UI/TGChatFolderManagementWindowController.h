#import <Cocoa/Cocoa.h>

@class TGTDLibClient;
@class TGChatFolderManagementWindowController;

@protocol TGChatFolderManagementWindowControllerDelegate <NSObject>
- (void)chatFolderManagementWindowControllerDidChangeFolders:(TGChatFolderManagementWindowController *)controller;
@end

@interface TGChatFolderManagementWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

@property (nonatomic, assign) id<TGChatFolderManagementWindowControllerDelegate> delegate;

- (id)initWithClient:(TGTDLibClient *)client;
- (void)reloadFolders;

@end
