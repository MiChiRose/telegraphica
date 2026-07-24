#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGCheckersEngine;
@class TGCheckersViewController;
@class TGGameSaveStore;

@interface TGCheckersModule : NSObject <TGWorkshopModule> {
    id<TGWorkshopHostContext> _hostContext;
    TGCheckersEngine *_engine;
    TGCheckersViewController *_viewController;
    TGGameSaveStore *_saveStore;
}
@end
