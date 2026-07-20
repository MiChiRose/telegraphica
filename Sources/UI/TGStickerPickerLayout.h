#import <Cocoa/Cocoa.h>

@interface TGStickerPickerBackgroundView : NSView
@end

@interface TGStickerPickerPanelView : NSView
@end

@interface TGStickerPickerLoadingView : NSView
- (void)startAnimation:(id)sender;
- (void)stopAnimation:(id)sender;
@end

NSRect TGStickerPickerContentRectForButtonFrame(NSRect buttonFrame);
NSButton *TGStickerPickerButtonWithFrame(NSRect frame, NSDictionary *item, NSInteger index, id target, SEL action);
BOOL TGStickerPickerItemNeedsLoadingIndicator(NSDictionary *item);
