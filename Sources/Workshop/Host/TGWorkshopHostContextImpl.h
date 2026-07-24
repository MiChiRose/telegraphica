#import <Cocoa/Cocoa.h>
#import "../API/TGWorkshopHostContext.h"

@protocol TGWorkshopHostContextDelegate <NSObject>
- (void)workshopHostContextRequestedClose;
- (void)workshopHostContextRequestedNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (NSDictionary *)workshopHostContextDiagnosticSnapshot;
@end

@interface TGWorkshopHostContextImpl : NSObject <TGWorkshopHostContext> {
@private
    NSString *_moduleIdentifier;
    id<TGWorkshopHostContextDelegate> _delegate;
}

- (id)initWithModuleIdentifier:(NSString *)moduleIdentifier
                       delegate:(id<TGWorkshopHostContextDelegate>)delegate;

@end
