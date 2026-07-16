#import <Cocoa/Cocoa.h>

@interface TGMessageViewersWindowController : NSWindowController

- (id)initWithMessagePreview:(NSString *)messagePreview;
- (void)showLoading;
- (void)showErrorMessage:(NSString *)message;
- (void)showViewerSummaries:(NSArray *)viewerSummaries;

@end
