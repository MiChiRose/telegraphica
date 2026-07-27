#import "TGMessageActionDialogs.h"
#import "TGLocalization.h"
#import "TGLocationPickerWindowController.h"
#include <float.h>

@implementation TGMessageActionDialogs

+ (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setFont:[NSFont systemFontOfSize:12.0]];
    [label setStringValue:text ? text : @""];
    return label;
}

+ (BOOL)scanCoordinateText:(NSString *)text value:(double *)value {
    NSString *normalized = [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                            stringByReplacingOccurrencesOfString:@"," withString:@"."];
    if ([normalized length] == 0) {
        return NO;
    }
    NSScanner *scanner = [NSScanner scannerWithString:normalized];
    double scannedValue = 0.0;
    if (![scanner scanDouble:&scannedValue] || ![scanner isAtEnd]) {
        return NO;
    }
    if (value) {
        *value = scannedValue;
    }
    return YES;
}

+ (NSDictionary *)contactToShare {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"share.contact.title")];
    [alert setInformativeText:TGLoc(@"share.contact.hint")];
    [alert addButtonWithTitle:TGLoc(@"send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 150.0)] autorelease];
    NSArray *labels = [NSArray arrayWithObjects:
                       TGLoc(@"share.contact.firstName"),
                       TGLoc(@"share.contact.lastName"),
                       TGLoc(@"share.contact.phone"),
                       nil];
    NSMutableArray *fields = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [labels count]; index++) {
        CGFloat y = 126.0 - (CGFloat)index * 48.0;
        [accessory addSubview:[self labelWithFrame:NSMakeRect(0.0, y, 390.0, 18.0)
                                              text:[labels objectAtIndex:index]]];
        NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, y - 25.0, 390.0, 22.0)] autorelease];
        [accessory addSubview:field];
        [fields addObject:field];
    }
    [alert setAccessoryView:accessory];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }

    NSString *firstName = [[(NSTextField *)[fields objectAtIndex:0] stringValue]
                           stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *lastName = [[(NSTextField *)[fields objectAtIndex:1] stringValue]
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *phone = [[(NSTextField *)[fields objectAtIndex:2] stringValue]
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([firstName length] == 0 || [phone length] == 0) {
        NSRunAlertPanel(TGLoc(@"share.contact.failed"),
                        @"%@",
                        TGLoc(@"ok"), nil, nil,
                        TGLoc(@"share.contact.error.required"));
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            firstName, @"first_name",
            lastName, @"last_name",
            phone, @"phone_number",
            nil];
}

+ (NSDictionary *)locationToShareWithClient:(TGTDLibClient *)client {
    TGLocationPickerWindowController *picker = [[[TGLocationPickerWindowController alloc] initWithClient:client] autorelease];
    NSDictionary *values = [picker runModal];
    double latitude = [[values objectForKey:@"latitude"] doubleValue];
    double longitude = [[values objectForKey:@"longitude"] doubleValue];
    if (values && (latitude < -90.0 || latitude > 90.0 ||
                   longitude < -180.0 || longitude > 180.0)) {
        return nil;
    }
    return values;
}

+ (NSDictionary *)venueToShareWithClient:(TGTDLibClient *)client {
    return [self locationToShareWithClient:client];
}

+ (NSDictionary *)liveLocationToShareWithClient:(TGTDLibClient *)client {
    NSMutableDictionary *values = [[[self locationToShareWithClient:client] mutableCopy] autorelease];
    if (!values) {
        return nil;
    }
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"share.liveLocation.duration")];
    [alert setInformativeText:TGLoc(@"share.liveLocation.warning")];
    [alert addButtonWithTitle:TGLoc(@"send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSPopUpButton *popup = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 300.0, 28.0) pullsDown:NO] autorelease];
    NSArray *periods = [NSArray arrayWithObjects:@900, @3600, @28800, @86400, nil];
    NSArray *keys = [NSArray arrayWithObjects:@"15m", @"1h", @"8h", @"24h", nil];
    NSUInteger index = 0;
    for (index = 0; index < [periods count]; index++) {
        [popup addItemWithTitle:TGLoc([@"share.liveLocation." stringByAppendingString:[keys objectAtIndex:index]])];
        [[popup lastItem] setRepresentedObject:[periods objectAtIndex:index]];
    }
    [alert setAccessoryView:popup];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    [values setObject:[[popup selectedItem] representedObject] forKey:@"live_period"];
    return values;
}

+ (NSString *)editedTextForCurrentText:(NSString *)currentText {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.edit.title")];
    [alert setInformativeText:TGLoc(@"message.edit.hint")];
    [alert addButtonWithTitle:TGLoc(@"message.edit.save")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 420.0, 120.0)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setAutohidesScrollers:YES];

    NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [textView setMinSize:NSMakeSize(0.0, 120.0)];
    [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [[textView textContainer] setContainerSize:NSMakeSize(420.0, FLT_MAX)];
    [[textView textContainer] setWidthTracksTextView:YES];
    [textView setString:currentText ? currentText : @""];
    [scrollView setDocumentView:textView];
    [alert setAccessoryView:scrollView];

    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        return nil;
    }

    NSString *editedText = [[textView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return ([editedText length] > 0) ? [[editedText copy] autorelease] : nil;
}

+ (TGMessageDeleteChoice)deleteChoiceWithCanDeleteOnlyForSelf:(BOOL)canDeleteOnlyForSelf
                                         canDeleteForAllUsers:(BOOL)canDeleteForAllUsers {
    if (!canDeleteOnlyForSelf && !canDeleteForAllUsers) {
        return TGMessageDeleteChoiceCancel;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.delete.title")];
    [alert setInformativeText:TGLoc(@"message.delete.hint")];

    if (canDeleteForAllUsers) {
        [alert addButtonWithTitle:TGLoc(@"message.delete.everyone")];
    }
    if (canDeleteOnlyForSelf) {
        [alert addButtonWithTitle:TGLoc(@"message.delete.self")];
    }
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSInteger result = [alert runModal];
    NSInteger buttonIndex = result - NSAlertFirstButtonReturn;
    if (buttonIndex < 0) {
        return TGMessageDeleteChoiceCancel;
    }

    NSInteger nextIndex = 0;
    if (canDeleteForAllUsers) {
        if (buttonIndex == nextIndex) {
            return TGMessageDeleteChoiceForEveryone;
        }
        nextIndex++;
    }
    if (canDeleteOnlyForSelf) {
        if (buttonIndex == nextIndex) {
            return TGMessageDeleteChoiceOnlyForSelf;
        }
    }
    return TGMessageDeleteChoiceCancel;
}

+ (BOOL)confirmPlainDeleteMessage {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.delete.title")];
    [alert setInformativeText:TGLoc(@"message.delete.hint")];
    [alert addButtonWithTitle:TGLoc(@"message.delete.action")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

@end
