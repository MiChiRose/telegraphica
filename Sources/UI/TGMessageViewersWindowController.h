#import <Cocoa/Cocoa.h>

@interface TGMessageViewersWindowController : NSWindowController

- (id)initWithMessagePreview:(NSString *)messagePreview;
- (void)setContentTitle:(NSString *)title windowTitle:(NSString *)windowTitle;
- (void)showLoading;
- (void)showErrorMessage:(NSString *)message;
- (void)showViewerSummaries:(NSArray *)viewerSummaries;

@end
