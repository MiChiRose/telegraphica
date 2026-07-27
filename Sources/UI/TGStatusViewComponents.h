#import <Cocoa/Cocoa.h>

@interface TGChromeView : NSView
@end

@interface TGDropOverlayView : NSView
@end

@interface TGNotificationDotView : NSView
@end

@interface TGMessageTableView : NSTableView {
    id _dropOverlayTarget;
}
@property (nonatomic, assign) id dropOverlayTarget;
@end

@interface TGUtilityWindowView : NSView
@end

@protocol TGSidebarResizeHandleDelegate;

@interface TGSidebarResizeHandleView : NSView {
    id<TGSidebarResizeHandleDelegate> _delegate;
    CGFloat _initialWidth;
    NSPoint _initialScreenPoint;
    NSTrackingArea *_trackingArea;
    BOOL _dragging;
}
@property (nonatomic, assign) id<TGSidebarResizeHandleDelegate> delegate;
- (CGFloat)initialDragWidth;
@end

@protocol TGSidebarResizeHandleDelegate <NSObject>
- (CGFloat)sidebarResizeHandleCurrentWidth:(TGSidebarResizeHandleView *)handle;
- (void)sidebarResizeHandle:(TGSidebarResizeHandleView *)handle requestedWidth:(CGFloat)width;
- (void)sidebarResizeHandleDidRequestToggle:(TGSidebarResizeHandleView *)handle;
@end

@interface TGRailView : NSView
@end

@interface TGAccountBadgeView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
    id _target;
    SEL _action;
    BOOL _connected;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL action;
@property (nonatomic, assign) BOOL connected;
@end

@interface TGProfileAvatarView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
@end
