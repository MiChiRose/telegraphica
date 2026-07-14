#import "TGStickerPickerLayout.h"
#import "TGStatusButtonCells.h"
#import "../Media/TGMediaImageLoader.h"
#import "../Media/TGMediaItemSupport.h"

NSRect TGStickerPickerContentRectForButtonFrame(NSRect buttonFrame) {
    return NSInsetRect(NSInsetRect(buttonFrame, 1.0, 1.0), 6.0, 6.0);
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

    NSString *localPath = TGMediaItemLocalPath(item);
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
    } else {
        NSString *emoji = [item objectForKey:@"emoji"];
        [button setTitle:([emoji length] > 0 ? emoji : @"☺")];
        [button setFont:[NSFont systemFontOfSize:28.0]];
    }
    return button;
}
