#import <Cocoa/Cocoa.h>
#import "TGSolitaireEngine.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@class TGSolitaireBoardView;

@interface TGSolitaireViewController : NSViewController {
    TGSolitaireEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    TGSolitaireBoardView *_boardView;
    NSTextField *_statusField;
    NSTextField *_statisticsField;
    NSButton *_newDealButton;
    NSButton *_undoButton;
}
- (id)initWithEngine:(TGSolitaireEngine *)engine hostContext:(id<TGWorkshopHostContext>)context;
- (void)refreshFromEngine;
@end
