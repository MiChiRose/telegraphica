#import "TGAnimationSupport.h"

static NSTimeInterval const TGDefaultRevealDuration = 0.16;

void TGSetViewVisibleAnimated(NSView *view, BOOL visible) {
    if (!view) {
        return;
    }

    BOOL currentlyVisible = ![view isHidden];
    if (currentlyVisible == visible) {
        if (visible && [view alphaValue] < 1.0) {
            [view setAlphaValue:1.0];
        }
        return;
    }

    if (!visible) {
        [view setHidden:YES];
        [view setAlphaValue:1.0];
        return;
    }

    [view setAlphaValue:0.0];
    [view setHidden:NO];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:TGDefaultRevealDuration];
    [[view animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
}
