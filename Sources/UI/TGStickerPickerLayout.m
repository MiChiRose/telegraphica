#import "TGStickerPickerLayout.h"
#import "TGStatusButtonCells.h"
#import "TGTheme.h"
#import "../Media/TGMediaImageLoader.h"
#import "../Media/TGMediaItemSupport.h"

@implementation TGStickerPickerBackgroundView

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    TGThemeDrawWindowBackgroundInRect([self bounds], [self isFlipped]);
}

@end

@implementation TGStickerPickerPanelView

- (BOOL)isOpaque {
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect([self bounds], 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:8.0 yRadius:8.0];
    TGThemeDrawGroupedCardInPath(path, bounds, [self isFlipped]);
}

@end

@interface TGStickerPickerLoadingView ()
@property (nonatomic, retain) NSProgressIndicator *spinner;
@end

@implementation TGStickerPickerLoadingView

@synthesize spinner = _spinner;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSRect bounds = [self bounds];
        CGFloat side = MIN(NSWidth(bounds), NSHeight(bounds));
        NSRect spinnerFrame = NSMakeRect(NSMidX(bounds) - floor(side / 2.0),
                                         NSMidY(bounds) - floor(side / 2.0),
                                         side,
                                         side);
        _spinner = [[NSProgressIndicator alloc] initWithFrame:spinnerFrame];
        [_spinner setStyle:NSProgressIndicatorSpinningStyle];
        [_spinner setIndeterminate:YES];
        [_spinner setDisplayedWhenStopped:NO];
        [_spinner setControlSize:(side <= 18.0 ? NSSmallControlSize : NSRegularControlSize)];
        if ([_spinner respondsToSelector:@selector(setUsesThreadedAnimation:)]) {
            [_spinner setUsesThreadedAnimation:YES];
        }
        [_spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:_spinner];
    }
    return self;
}

- (void)dealloc {
    [_spinner release];
    [super dealloc];
}

- (BOOL)isOpaque {
    return NO;
}

- (NSView *)hitTest:(NSPoint)aPoint {
    (void)aPoint;
    return nil;
}

- (void)startAnimation:(id)sender {
    [self.spinner startAnimation:sender];
}

- (void)stopAnimation:(id)sender {
    [self.spinner stopAnimation:sender];
}

@end

NSRect TGStickerPickerContentRectForButtonFrame(NSRect buttonFrame) {
    return NSInsetRect(NSInsetRect(buttonFrame, 1.0, 1.0), 5.0, 5.0);
}

BOOL TGStickerPickerItemNeedsLoadingIndicator(NSDictionary *item) {
    id loading = [item objectForKey:@"sticker_loading"];
    return ([loading respondsToSelector:@selector(boolValue)] && [loading boolValue]);
}

NSButton *TGStickerPickerButtonWithFrame(NSRect frame, NSDictionary *item, NSInteger index, id target, SEL action) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGStickerPickerButtonCell *cell = [[[TGStickerPickerButtonCell alloc] init] autorelease];
    [button setCell:cell];
    [button setButtonType:NSMomentaryPushInButton];
    [button setBordered:NO];
    [button setTarget:target];
    [button setAction:action];
    [button setTag:index];

    BOOL loading = TGStickerPickerItemNeedsLoadingIndicator(item);
    NSString *localPath = loading ? nil : TGMediaItemLocalPath(item);
    NSImage *image = nil;
    if ([localPath length] > 0) {
        image = TGImageWithCorrectOrientationFromFile(localPath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:localPath] autorelease];
        }
    }
    if (!image) {
        NSData *miniThumbnailData = TGMediaItemMiniThumbnailData(item);
        if ([miniThumbnailData length] > 0) {
            image = [[[NSImage alloc] initWithData:miniThumbnailData] autorelease];
        }
    }
    if (image) {
        [button setImage:image];
        [button setImageScaling:NSImageScaleProportionallyUpOrDown];
        [button setImagePosition:NSImageOnly];
    } else if (loading) {
        [button setTitle:@""];
    } else {
        NSString *emoji = [item objectForKey:@"emoji"];
        [button setTitle:([emoji length] > 0 ? emoji : @"☺")];
        [button setFont:[NSFont systemFontOfSize:28.0]];
    }
    return button;
}
