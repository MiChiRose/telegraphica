#import <Cocoa/Cocoa.h>
#import "TGPacManEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@class TGPacManBoardView;

@interface TGPacManViewController : NSViewController {
@private
    TGPacManEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    TGPacManBoardView *_boardView;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSButton *_newGameButton;
    NSButton *_pauseButton;
    NSTimer *_timer;
    TGPacManDirection _direction;
    TGPacManDirection _queuedDirection;
    BOOL _paused;
}

- (id)initWithEngine:(TGPacManEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)refreshFromEngine;
- (void)startAnimation;
- (void)stopAnimation;

@end
