#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGMediaWorkbenchViewController;

@interface TGMediaWorkbenchModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGMediaWorkbenchViewController *_viewController;
}
@end
