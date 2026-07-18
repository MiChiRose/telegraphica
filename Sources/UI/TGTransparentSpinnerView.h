#import <Cocoa/Cocoa.h>

@interface TGTransparentSpinnerView : NSView

@property (nonatomic, assign, getter=isDisplayedWhenStopped) BOOL displayedWhenStopped;

- (void)startAnimation:(id)sender;
- (void)stopAnimation:(id)sender;

@end
