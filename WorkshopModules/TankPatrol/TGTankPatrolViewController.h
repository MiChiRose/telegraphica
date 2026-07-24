#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@class TGTankPatrolEngine;
@class TGTankPatrolBoardView;

@interface TGTankPatrolViewController : NSViewController {
@private
    TGTankPatrolEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    TGTankPatrolBoardView *_boardView;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSButton *_newGameButton;
    NSTimer *_gameTimer;
}

- (id)initWithEngine:(TGTankPatrolEngine *)engine
         hostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)refreshFromEngine;
- (void)stopSimulation;

@end
