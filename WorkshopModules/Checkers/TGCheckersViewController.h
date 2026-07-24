#import <Cocoa/Cocoa.h>
#import "TGCheckersEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@interface TGCheckersViewController : NSViewController {
    TGCheckersEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    NSMutableArray *_squareButtons;
    NSPopUpButton *_modeButton;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSButton *_restartButton;
    NSInteger _selectedRow;
    NSInteger _selectedColumn;
}

- (id)initWithEngine:(TGCheckersEngine *)engine hostContext:(id<TGWorkshopHostContext>)context;
- (void)refreshFromEngine;

@end
