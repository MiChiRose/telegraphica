#import <Cocoa/Cocoa.h>
#import "TGPacManEngine.h"

@interface TGPacManBoardView : NSView {
@private
    TGPacManEngine *_engine;
    id _target;
    SEL _action;
    TGPacManDirection _pendingDirection;
}

@property(nonatomic, readonly) TGPacManDirection pendingDirection;

- (id)initWithFrame:(NSRect)frame engine:(TGPacManEngine *)engine;
- (void)setTarget:(id)target action:(SEL)action;

@end
