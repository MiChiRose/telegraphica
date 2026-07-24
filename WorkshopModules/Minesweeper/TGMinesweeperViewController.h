#import <Cocoa/Cocoa.h>
#import "TGMinesweeperEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@interface TGMinesweeperViewController : NSViewController {
@private
    TGMinesweeperEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    NSMutableArray *_cellButtons;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSTextField *_mineField;
    NSTextField *_timerField;
    NSPopUpButton *_difficultyButton;
    NSButton *_restartButton;
    NSTimer *_timer;
}

- (id)initWithEngine:(TGMinesweeperEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)startUpdating;
- (void)stopUpdating;
- (void)refreshFromEngine;

@end
