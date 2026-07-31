#import "TGLinkPreviewOptionsDialog.h"
#import "TGLocalization.h"

@implementation TGLinkPreviewOptionsDialog

+ (NSDictionary *)sendOptionsForMessageText:(NSString *)messageText {
    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 144.0)] autorelease];

    NSTextField *urlLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 118.0, 390.0, 18.0)] autorelease];
    [urlLabel setEditable:NO];
    [urlLabel setBordered:NO];
    [urlLabel setDrawsBackground:NO];
    [urlLabel setStringValue:TGLoc(@"composer.linkPreview.url")];
    [accessory addSubview:urlLabel];

    NSTextField *urlField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 88.0, 390.0, 26.0)] autorelease];
    [urlField setPlaceholderString:TGLoc(@"composer.linkPreview.urlPlaceholder")];
    if ([messageText length] > 0) {
        NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:NULL];
        NSTextCheckingResult *match = [detector firstMatchInString:messageText
                                                          options:0
                                                            range:NSMakeRange(0, [messageText length])];
        if ([match URL]) {
            [urlField setStringValue:[[match URL] absoluteString]];
        }
    }
    [accessory addSubview:urlField];

    NSTextField *sizeLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 58.0, 138.0, 22.0)] autorelease];
    [sizeLabel setEditable:NO];
    [sizeLabel setBordered:NO];
    [sizeLabel setDrawsBackground:NO];
    [sizeLabel setStringValue:TGLoc(@"composer.linkPreview.mediaSize")];
    [accessory addSubview:sizeLabel];

    NSPopUpButton *sizePopup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(146.0, 54.0, 244.0, 28.0)
                                                          pullsDown:NO] autorelease];
    [sizePopup addItemWithTitle:TGLoc(@"composer.linkPreview.mediaAuto")];
    [sizePopup addItemWithTitle:TGLoc(@"composer.linkPreview.mediaLarge")];
    [sizePopup addItemWithTitle:TGLoc(@"composer.linkPreview.mediaSmall")];
    [accessory addSubview:sizePopup];

    NSButton *aboveCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 28.0, 390.0, 24.0)] autorelease];
    [aboveCheckbox setButtonType:NSSwitchButton];
    [aboveCheckbox setTitle:TGLoc(@"composer.previewAbove")];
    [accessory addSubview:aboveCheckbox];

    NSButton *disableCheckbox = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 2.0, 390.0, 24.0)] autorelease];
    [disableCheckbox setButtonType:NSSwitchButton];
    [disableCheckbox setTitle:TGLoc(@"composer.noLinkPreview")];
    [accessory addSubview:disableCheckbox];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"composer.linkPreview.title")];
    [alert setInformativeText:TGLoc(@"composer.linkPreview.help")];
    [alert setAccessoryView:accessory];
    [alert addButtonWithTitle:TGLoc(@"composer.linkPreview.send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }

    BOOL disabled = ([disableCheckbox state] == NSOnState);
    NSInteger sizeIndex = [sizePopup indexOfSelectedItem];
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    [options setObject:[NSNumber numberWithBool:disabled] forKey:@"disable_link_preview"];
    [options setObject:[NSNumber numberWithBool:([aboveCheckbox state] == NSOnState)]
                forKey:@"preview_above_text"];
    [options setObject:[NSNumber numberWithBool:(!disabled && sizeIndex == 1)]
                forKey:@"preview_large_media"];
    [options setObject:[NSNumber numberWithBool:(!disabled && sizeIndex == 2)]
                forKey:@"preview_small_media"];
    NSString *url = [[urlField stringValue] stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!disabled && [url length] > 0) {
        [options setObject:url forKey:@"link_preview_url"];
    }
    return options;
}

@end
