#import <Cocoa/Cocoa.h>

/* A single, mouse-transparent presentation effect. Section visibility and input
 * remain the owning controller's immediate responsibility. */
@interface TGSectionTransitionController : NSObject {
    NSView *_contentView;
    NSView *_veilView;
    NSTimer *_timer;
    NSString *_section;
    id _context;
    NSTimeInterval _started;
}
- (id)initWithContentView:(NSView *)contentView;
- (void)presentSection:(NSString *)section
          contentRect:(NSRect)rect
      backgroundColor:(NSColor *)color
              context:(id)context;
- (void)cancelAnimation;
- (void)reset;
- (BOOL)isAnimating;
@end
