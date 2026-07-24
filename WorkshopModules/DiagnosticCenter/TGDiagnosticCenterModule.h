#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGDiagnosticCenterViewController;

@interface TGDiagnosticCenterModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGDiagnosticCenterViewController *_viewController;
}
@end
