#import <Cocoa/Cocoa.h>

@class TGProfileEditWindowController;

@protocol TGProfileEditWindowControllerDelegate <NSObject>
- (void)profileEditWindowController:(TGProfileEditWindowController *)controller
            didRequestSaveFirstName:(NSString *)firstName
                           lastName:(NSString *)lastName
                           username:(NSString *)username
                                bio:(NSString *)bio;
@end

@interface TGProfileEditWindowController : NSWindowController

@property (nonatomic, assign) id<TGProfileEditWindowControllerDelegate> delegate;

- (void)configureWithFirstName:(NSString *)firstName
                      lastName:(NSString *)lastName
                      username:(NSString *)username
                           bio:(NSString *)bio;
- (void)setSaving:(BOOL)saving;
- (void)showErrorMessage:(NSString *)message;

@end
