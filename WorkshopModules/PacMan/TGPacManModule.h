#import <Foundation/Foundation.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGPacManEngine;
@class TGPacManViewController;
@class TGGameSaveStore;

@interface TGPacManModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGPacManEngine *_engine;
    TGPacManViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
