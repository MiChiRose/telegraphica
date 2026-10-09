#import <Cocoa/Cocoa.h>

@class TGMediaImageLoadToken;

// A small avatar owns its decoded image independently of the media cache.
// View ownership is assign; callers cancel by releasing the presentation.
@interface TGAvatarImagePresentation : NSObject {
    NSView *_view;
    NSString *_path;
    NSImage *_image;
    TGMediaImageLoadToken *_loadToken;
    NSTimeInterval _retryAfter;
}
- (id)initWithView:(NSView *)view;
- (void)setPath:(NSString *)path;
- (NSImage *)imageForDrawing;
@end
