#import <Cocoa/Cocoa.h>

@class TGChatItem;
@class TGMessageItem;

@interface TGChatListCell : NSTextFieldCell {
    TGChatItem *_chatItem;
}
@property (nonatomic, retain) TGChatItem *chatItem;
@end

@interface TGPanelView : NSView
@end

@interface TGScrollSurfaceView : NSView
@end

@interface TGComposerInputBackgroundView : NSView
@end

@interface TGAuthInputBackgroundView : NSView {
    BOOL _errorState;
}
@property (nonatomic, assign) BOOL errorState;
@end

@interface TGGroupedCardView : NSView
@end

@interface TGFlippedDocumentView : NSView
@end

@protocol TGMediaPreviewMagnificationTarget
- (void)mediaPreviewView:(id)sender didMagnifyBy:(NSNumber *)magnificationNumber;
@end

@interface TGMediaPreviewScrollView : NSScrollView {
    id<TGMediaPreviewMagnificationTarget> _magnificationTarget;
}
@property (nonatomic, assign) id<TGMediaPreviewMagnificationTarget> magnificationTarget;
@end

@interface TGMediaPreviewImageView : NSImageView {
    id<TGMediaPreviewMagnificationTarget> _magnificationTarget;
}
@property (nonatomic, assign) id<TGMediaPreviewMagnificationTarget> magnificationTarget;
@end

@interface TGMessageBubbleCell : NSTextFieldCell {
    TGMessageItem *_messageItem;
    BOOL _showSenderDetails;
}
@property (nonatomic, retain) TGMessageItem *messageItem;
@property (nonatomic, assign) BOOL showSenderDetails;
@end
