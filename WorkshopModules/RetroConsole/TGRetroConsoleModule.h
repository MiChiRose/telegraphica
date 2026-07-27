#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopModule.h"

@class TGRetroConsoleViewController;

@interface TGRetroConsoleModule : NSObject <TGWorkshopModule> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGRetroConsoleViewController *_viewController;
}
@end

