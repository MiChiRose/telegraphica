#import <Cocoa/Cocoa.h>

@interface TGWorkshopHeaderNoticeView : NSView {
@private
    NSTextField *_messageField;
}

- (void)showMessage:(NSString *)message duration:(NSTimeInterval)duration;
- (void)hideAnimated;

@end
