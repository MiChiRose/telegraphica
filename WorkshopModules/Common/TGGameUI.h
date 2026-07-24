#import <Cocoa/Cocoa.h>
#import "../../Sources/Workshop/UI/TGWorkshopButtonCell.h"
#import "../../Sources/Workshop/UI/TGWorkshopSurfaceView.h"
#import "../../Sources/UI/TGIconAssets.h"
#import "../../Sources/Workshop/API/TGWorkshopHostContext.h"

static NSButton *TGGameThemedButton(NSRect frame,
                                    NSString *title,
                                    NSString *iconName,
                                    id<TGWorkshopHostContext> context) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGWorkshopButtonCell *cell = [[[TGWorkshopButtonCell alloc] initTextCell:title ? title : @""] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title ? title : @""];
    [button setBordered:NO];
    if ([iconName length] > 0) {
        NSColor *iconColor = [NSColor colorWithCalibratedRed:0.08 green:0.11 blue:0.075 alpha:1.0];
        [button setImage:TGTemplateIconAssetImage(iconName, NSMakeSize(16.0, 16.0), iconColor, 1.0)];
        [button setImagePosition:([title length] > 0 ? NSImageLeft : NSImageOnly)];
    }
    return button;
}

static NSTextField *TGGameLabel(NSRect frame,
                                CGFloat size,
                                BOOL bold,
                                id<TGWorkshopHostContext> context) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:[context interfaceFontOfSize:size bold:bold]];
    [field setTextColor:(bold ? TGWorkshopCreamColor() : TGWorkshopMutedCreamColor())];
    return field;
}
