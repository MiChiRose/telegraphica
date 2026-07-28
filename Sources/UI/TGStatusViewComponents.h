#import <Cocoa/Cocoa.h>

@interface TGChromeView : NSView
@end

@interface TGDropOverlayView : NSView
@end

@interface TGNotificationDotView : NSView
@end

@class TGMessageTableView;

@protocol TGMessageTextSelectionDelegate <NSObject>
- (NSDictionary *)messageTableView:(TGMessageTableView *)tableView selectableTextDescriptorAtPoint:(NSPoint)point;
@end

@interface TGMessageTableView : NSTableView {
    id _dropOverlayTarget;
    NSTextView *_selectableTextView;
}
@property (nonatomic, assign) id dropOverlayTarget;
- (void)clearSelectableMessageText;
@end

@interface TGUtilityWindowView : NSView
@end

@interface TGUtilityPanelView : NSView
@end

@interface TGActiveSessionCell : NSTextFieldCell {
    NSDictionary *_sessionPresentation;
}
@property (nonatomic, retain) NSDictionary *sessionPresentation;
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
