#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

@interface TGMediaWorkbenchViewController : NSViewController {
@private
    id<TGWorkshopHostContext> _hostContext;
    NSString *_sourcePath;
    NSTextField *_titleField;
    NSTextField *_hintField;
    NSView *_panelView;
    NSImageView *_previewView;
    NSTextField *_fileField;
    NSButton *_chooseButton;
    NSPopUpButton *_formatPopup;
    NSPopUpButton *_sizePopup;
    NSSlider *_qualitySlider;
    NSTextField *_qualityField;
    NSButton *_saveButton;
    NSTextField *_statusField;
    NSProgressIndicator *_spinner;
    BOOL _processing;
}

- (id)initWithHostContext:(id<TGWorkshopHostContext>)hostContext;

@end
