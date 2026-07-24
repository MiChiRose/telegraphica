#import <Cocoa/Cocoa.h>
#import "TGPacManEngine.h"

@interface TGPacManBoardView : NSView {
@private
    TGPacManEngine *_engine;
    id _target;
    SEL _action;
    TGPacManDirection _pendingDirection;
    TGPacManDirection _facingDirection;
    NSUInteger _previousPacmanIndex;
    NSUInteger _previousGhostIndex;
    CGFloat _movementProgress;
    BOOL _animatingMovement;
    BOOL _mouthOpen;
}

@property(nonatomic, readonly) TGPacManDirection pendingDirection;

- (id)initWithFrame:(NSRect)frame engine:(TGPacManEngine *)engine;
- (void)setTarget:(id)target action:(SEL)action;
- (void)setFacingDirection:(TGPacManDirection)direction;
- (void)beginMovementFromPacmanIndex:(NSUInteger)pacmanIndex
                         ghostIndex:(NSUInteger)ghostIndex
                          direction:(TGPacManDirection)direction;
- (BOOL)advanceMovementAnimation;
- (BOOL)isAnimatingMovement;
- (void)resetMovementAnimation;

@end
