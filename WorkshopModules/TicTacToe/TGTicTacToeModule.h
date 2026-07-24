#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGTicTacToeEngine;
@class TGTicTacToeViewController;
@class TGGameSaveStore;

@interface TGTicTacToeModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGTicTacToeEngine *_engine;
    TGTicTacToeViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
