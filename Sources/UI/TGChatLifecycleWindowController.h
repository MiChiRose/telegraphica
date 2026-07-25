#import <Cocoa/Cocoa.h>

@class TGTDLibClient;
@protocol TGChatLifecycleWindowControllerDelegate;

@interface TGChatLifecycleWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

@property (nonatomic, assign) id<TGChatLifecycleWindowControllerDelegate> delegate;

- (id)initWithClient:(TGTDLibClient *)client;
- (void)refreshContacts;
- (void)focusInviteLink;

@end

@protocol TGChatLifecycleWindowControllerDelegate <NSObject>

- (void)chatLifecycleWindowController:(TGChatLifecycleWindowController *)controller
                        didOpenChatID:(NSNumber *)chatID
                                title:(NSString *)title;

@end
