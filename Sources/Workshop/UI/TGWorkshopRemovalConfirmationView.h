#import <Cocoa/Cocoa.h>

@class TGWorkshopRemovalConfirmationView;

typedef enum {
    TGWorkshopRemovalConfirmationChoiceCancel = 0,
    TGWorkshopRemovalConfirmationChoiceKeepData = 1,
    TGWorkshopRemovalConfirmationChoiceRemoveData = 2
} TGWorkshopRemovalConfirmationChoice;

@protocol TGWorkshopRemovalConfirmationViewDelegate <NSObject>
- (void)workshopRemovalConfirmationView:(TGWorkshopRemovalConfirmationView *)view
                              didChoose:(TGWorkshopRemovalConfirmationChoice)choice;
@end

@interface TGWorkshopRemovalConfirmationView : NSView {
@private
    id<TGWorkshopRemovalConfirmationViewDelegate> _delegate;
    NSTextField *_titleField;
    NSTextField *_messageField;
    NSButton *_keepDataButton;
    NSButton *_removeDataButton;
    NSButton *_cancelButton;
    TGWorkshopRemovalConfirmationChoice _pendingChoice;
}

@property(nonatomic, assign) id<TGWorkshopRemovalConfirmationViewDelegate> delegate;

- (id)initWithFrame:(NSRect)frame
              title:(NSString *)title
            message:(NSString *)message
      keepDataTitle:(NSString *)keepDataTitle
    removeDataTitle:(NSString *)removeDataTitle
        cancelTitle:(NSString *)cancelTitle;
- (void)presentInView:(NSView *)parentView;

@end
