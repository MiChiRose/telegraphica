#import <Cocoa/Cocoa.h>

@class TGRetroDisplayView;

@protocol TGRetroDisplayViewDelegate <NSObject>
- (void)retroDisplayView:(TGRetroDisplayView *)view didReceiveROMPath:(NSString *)path;
- (void)retroDisplayView:(TGRetroDisplayView *)view setButton:(NSUInteger)button pressed:(BOOL)pressed;
@end

@interface TGRetroDisplayView : NSView {
@private
    id<TGRetroDisplayViewDelegate> _delegate;
    NSData *_frameData;
    NSUInteger _frameWidth;
    NSUInteger _frameHeight;
    BOOL _acceptingDrop;
}

@property(nonatomic, assign) id<TGRetroDisplayViewDelegate> delegate;

- (void)updateFrameData:(NSData *)data width:(NSUInteger)width height:(NSUInteger)height;
- (void)clearFrame;

@end

