#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGSolitaireEngine;
@class TGSolitaireViewController;
@class TGGameSaveStore;

@interface TGSolitaireModule : NSObject <TGWorkshopModule> {
    id<TGWorkshopHostContext> _hostContext;
    TGSolitaireEngine *_engine;
    TGSolitaireViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
