#import <Cocoa/Cocoa.h>
#import "TGSolitaireEngine.h"

@interface TGSolitaireBoardView : NSView {
    TGSolitaireEngine *_engine;
    NSDictionary *_themeColors;
    id _target;
    SEL _action;
    TGSolitaireSource _dragSource;
    NSInteger _dragPile;
    NSInteger _dragCardIndex;
    NSPoint _dragPoint;
    BOOL _dragging;
    NSImage *_cardBackImage;
}

- (id)initWithFrame:(NSRect)frame engine:(TGSolitaireEngine *)engine themeColors:(NSDictionary *)colors;
- (void)setTarget:(id)target action:(SEL)action;

@end
