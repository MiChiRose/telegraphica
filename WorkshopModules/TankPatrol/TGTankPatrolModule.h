#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGTankPatrolEngine;
@class TGTankPatrolViewController;
@class TGGameSaveStore;

@interface TGTankPatrolModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGTankPatrolEngine *_engine;
    TGTankPatrolViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
