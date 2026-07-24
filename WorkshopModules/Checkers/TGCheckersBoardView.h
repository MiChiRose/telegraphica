#import <Cocoa/Cocoa.h>
#import "TGCheckersEngine.h"

@interface TGCheckersBoardView : NSView {
@private
    TGCheckersEngine *_engine;
    NSDictionary *_themeColors;
    id _target;
    SEL _action;
    NSInteger _selectedRow;
    NSInteger _selectedColumn;
    NSInteger _dragRow;
    NSInteger _dragColumn;
    NSPoint _dragPoint;
    BOOL _dragging;
}

- (id)initWithFrame:(NSRect)frame engine:(TGCheckersEngine *)engine themeColors:(NSDictionary *)colors;
- (void)setTarget:(id)target action:(SEL)action;
- (void)clearSelection;

@end
