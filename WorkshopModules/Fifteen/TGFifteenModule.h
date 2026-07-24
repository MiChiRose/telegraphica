#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGFifteenEngine;
@class TGFifteenViewController;
@class TGGameSaveStore;

@interface TGFifteenModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGFifteenEngine *_engine;
    TGFifteenViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
