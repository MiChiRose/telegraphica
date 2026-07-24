#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@interface TGDiagnosticCenterViewController : NSViewController {
@private
    id<TGWorkshopHostContext> _hostContext;
    NSTextField *_titleField;
    NSTextField *_summaryField;
    NSTextField *_telegramTitleField;
    NSTextField *_telegramValueField;
    NSTextField *_storageTitleField;
    NSTextField *_storageValueField;
    NSTextField *_applicationTitleField;
    NSTextField *_applicationValueField;
    NSArray *_cardViews;
    NSButton *_refreshButton;
    NSProgressIndicator *_spinner;
    BOOL _refreshing;
}

- (id)initWithHostContext:(id<TGWorkshopHostContext>)hostContext;
- (void)refreshDiagnostics;

@end
