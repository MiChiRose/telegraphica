#import <Cocoa/Cocoa.h>

@interface TGChromeView : NSView
@end

@interface TGDropOverlayView : NSView
@end

@interface TGMessageTableView : NSTableView {
    id _dropOverlayTarget;
}
@property (nonatomic, assign) id dropOverlayTarget;
@end

@interface TGUtilityWindowView : NSView
@end

@interface TGRailView : NSView
@end

@interface TGAccountBadgeView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
    BOOL _connected;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
@property (nonatomic, assign) BOOL connected;
@end

@interface TGProfileAvatarView : NSView {
    NSString *_displayName;
    NSString *_avatarLocalPath;
}
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarLocalPath;
@end
