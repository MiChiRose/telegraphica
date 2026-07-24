#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGMinesweeperEngine;
@class TGMinesweeperViewController;
@class TGGameSaveStore;

@interface TGMinesweeperModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGMinesweeperEngine *_engine;
    TGMinesweeperViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
