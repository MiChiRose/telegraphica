#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"
#import "TGRetroLibretroCore.h"
#import "TGRetroDisplayView.h"

@interface TGRetroConsoleViewController : NSViewController <TGRetroLibretroCoreDelegate, TGRetroDisplayViewDelegate> {
@private
    id<TGWorkshopHostContext> _hostContext;
    TGRetroLibretroCore *_core;
    TGRetroDisplayView *_displayView;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSTextField *_controlsField;
    NSButton *_insertButton;
    NSButton *_pauseButton;
    NSButton *_resetButton;
    NSTimer *_frameTimer;
    NSString *_currentROMPath;
    BOOL _paused;
}

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context;
- (void)startRunning;
- (void)stopRunning;
- (NSData *)serializedState;
- (BOOL)restoreSerializedState:(NSData *)state;

@end

