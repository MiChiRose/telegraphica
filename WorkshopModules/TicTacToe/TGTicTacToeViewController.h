#import <Cocoa/Cocoa.h>
#import "TGTicTacToeEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@interface TGTicTacToeViewController : NSViewController {
@private
    TGTicTacToeEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    NSArray *_boardButtons;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSPopUpButton *_modeButton;
    NSPopUpButton *_difficultyButton;
    NSButton *_newRoundButton;
}

- (id)initWithEngine:(TGTicTacToeEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)refreshFromEngine;

@end
