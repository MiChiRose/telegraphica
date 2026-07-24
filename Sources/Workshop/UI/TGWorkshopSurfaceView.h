#import <Cocoa/Cocoa.h>

#pragma GCC visibility push(default)

NSColor *TGWorkshopFeltBaseColor(void);
NSColor *TGWorkshopFeltPatternColor(void);
NSColor *TGWorkshopWoodPatternColor(void);
NSColor *TGWorkshopGoldColor(void);
NSColor *TGWorkshopCreamColor(void);
NSColor *TGWorkshopMutedCreamColor(void);
NSColor *TGWorkshopBurgundyColor(void);
NSColor *TGWorkshopDeepGreenColor(void);
NSImage *TGWorkshopUprightTemplateIcon(NSString *name,
                                       NSSize size,
                                       NSColor *color,
                                       CGFloat alpha);

__attribute__((visibility("default")))
@interface TGWorkshopSurfaceView : NSView
@end

__attribute__((visibility("default")))
@interface TGWorkshopGameSurfaceView : NSView
@end

#pragma GCC visibility pop
