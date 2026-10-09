#import <Cocoa/Cocoa.h>

@class TGDownloadManager;

// Zero means that showing a separate panel would cover the conversation.
NSRect TGDownloadProgressPanelFrame(NSRect mainFrame, NSRect visibleFrame, CGFloat panelHeight);
NSRect TGDownloadProgressReservedMainFrame(NSRect mainFrame, NSRect visibleFrame, NSSize minimumMainSize, CGFloat panelHeight);
NSRect TGDownloadProgressRestoredMainFrame(NSRect originalFrame, NSRect reservedFrame, NSRect currentFrame,
                                         NSRect visibleFrame, NSSize minimumMainSize);
double TGDownloadProgressFraction(NSDictionary *record);
BOOL TGDownloadProgressCanPerformAction(NSDictionary *record, NSString *action);

// Presentation state is separate from the window so hide/new-job behavior can
// be verified without a screen, timers, or a live Telegram account.
@interface TGDownloadProgressPresentation : NSObject {
    NSSet *_knownIdentifiers;
    NSDictionary *_displayedRecord;
    NSUInteger _activeCount;
    BOOL _hidden;
}
@property (nonatomic, readonly) NSDictionary *displayedRecord;
@property (nonatomic, readonly) NSUInteger activeCount;
@property (nonatomic, readonly) BOOL hidden;
- (BOOL)updateWithRecords:(NSArray *)records;
- (void)hide;
- (void)show;
@end

@interface TGDownloadProgressWindowController : NSWindowController <NSWindowDelegate> {
    TGDownloadManager *_manager;
    TGDownloadProgressPresentation *_presentation;
    NSWindow *_mainWindow; // Owner invalidates before releasing its window.
    id _downloadsTarget;  // Non-retaining target/action, like a native button.
    SEL _downloadsAction;
    NSTextField *_nameField;
    NSTextField *_statusField;
    NSTextField *_bytesField;
    NSProgressIndicator *_progressBar;
    NSButton *_collapseButton;
    NSButton *_downloadsButton;
    NSButton *_pauseButton;
    NSButton *_cancelButton;
    NSRect _originalMainFrame;
    NSRect _reservedMainFrame;
    BOOL _hasReservedMainFrame;
    BOOL _changingMainFrame;
    BOOL _mayReserveSpace;
    BOOL _collapsed;
    BOOL _invalidated;
}
- (id)initWithDownloadManager:(TGDownloadManager *)manager;
- (void)attachToWindow:(NSWindow *)window;
- (void)setDownloadsTarget:(id)target action:(SEL)action;
- (void)showProgress:(id)sender;
- (void)invalidate;
@end
