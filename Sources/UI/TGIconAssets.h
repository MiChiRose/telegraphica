#import <Cocoa/Cocoa.h>

NSImage *TGIconAssetImageNamed(NSString *name);
NSImage *TGTemplateIconAssetImage(NSString *name, NSSize size, NSColor *color, CGFloat alpha);
void TGDrawTemplateIconAsset(NSString *name, NSRect rect, NSColor *color, CGFloat alpha, BOOL flipped);
