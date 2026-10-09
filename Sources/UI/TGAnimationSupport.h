#import <Cocoa/Cocoa.h>

BOOL TGInterfaceAnimationsEnabledForView(NSView *view);
void TGSetViewVisibleAnimated(NSView *view, BOOL visible);
void TGCancelViewVisibilityAnimation(NSView *view);
