#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@class TGFifteenEngine;

@interface TGFifteenViewController : NSViewController {
@private
    TGFifteenEngine *_engine;
    id<TGWorkshopHostContext> _hostContext;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSTextField *_scoreField;
    NSView *_guideView;
    NSArray *_tileButtons;
    NSButton *_newGameButton;
}

- (id)initWithEngine:(TGFifteenEngine *)engine
         hostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)refreshFromEngine;

@end
