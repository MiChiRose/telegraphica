#import <Cocoa/Cocoa.h>

@class TGTDLibClient;
@class TGContactsViewController;

@protocol TGContactsViewControllerDelegate <NSObject>

- (void)contactsViewController:(TGContactsViewController *)controller
                 didOpenChatID:(NSNumber *)chatID
                         title:(NSString *)title;
- (void)contactsViewControllerDidRequestNewConversation:(TGContactsViewController *)controller;

@end

@interface TGContactsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

@property (nonatomic, assign) id<TGContactsViewControllerDelegate> delegate;

- (id)initWithClient:(TGTDLibClient *)client;
- (void)refreshContactsIfNeeded;
- (void)refreshLocalizedText;
- (void)refreshThemeAppearance;

@end
