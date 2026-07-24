#import <Cocoa/Cocoa.h>
#import "TGCheckersEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@class TGCheckersBoardView;

@interface TGCheckersViewController : NSViewController {
    TGCheckersEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    TGCheckersBoardView *_boardView;
    NSPopUpButton *_modeButton;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSButton *_restartButton;
}

- (id)initWithEngine:(TGCheckersEngine *)engine hostContext:(id<TGWorkshopHostContext>)context;
- (void)refreshFromEngine;

@end
