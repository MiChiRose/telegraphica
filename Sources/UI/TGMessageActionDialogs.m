#import "TGMessageActionDialogs.h"
#import "TGLocalization.h"
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

+ (NSDictionary *)locationToShare {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"share.location.title")];
    [alert setInformativeText:TGLoc(@"share.location.hint")];
    [alert addButtonWithTitle:TGLoc(@"send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 102.0)] autorelease];
    [accessory addSubview:[self labelWithFrame:NSMakeRect(0.0, 78.0, 185.0, 18.0)
                                          text:TGLoc(@"share.location.latitude")]];
    [accessory addSubview:[self labelWithFrame:NSMakeRect(205.0, 78.0, 185.0, 18.0)
                                          text:TGLoc(@"share.location.longitude")]];
    NSTextField *latitudeField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 51.0, 185.0, 22.0)] autorelease];
    NSTextField *longitudeField = [[[NSTextField alloc] initWithFrame:NSMakeRect(205.0, 51.0, 185.0, 22.0)] autorelease];
    [[latitudeField cell] setPlaceholderString:@"53.9006"];
    [[longitudeField cell] setPlaceholderString:@"27.5590"];
    [accessory addSubview:latitudeField];
    [accessory addSubview:longitudeField];
    [accessory addSubview:[self labelWithFrame:NSMakeRect(0.0, 8.0, 390.0, 34.0)
                                          text:TGLoc(@"share.location.ranges")]];
    [alert setAccessoryView:accessory];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }

    double latitude = 0.0;
    double longitude = 0.0;
    BOOL validLatitude = [self scanCoordinateText:[latitudeField stringValue] value:&latitude];
    BOOL validLongitude = [self scanCoordinateText:[longitudeField stringValue] value:&longitude];
    if (!validLatitude || !validLongitude || latitude < -90.0 || latitude > 90.0 ||
        longitude < -180.0 || longitude > 180.0) {
        NSRunAlertPanel(TGLoc(@"share.location.failed"),
                        @"%@",
                        TGLoc(@"ok"), nil, nil,
                        TGLoc(@"share.location.error.invalid"));
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithDouble:latitude], @"latitude",
            [NSNumber numberWithDouble:longitude], @"longitude",
            nil];
}

+ (NSDictionary *)venueToShare {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"share.venue.title")];
    [alert setInformativeText:TGLoc(@"share.venue.hint")];
    [alert addButtonWithTitle:TGLoc(@"send")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 154.0)] autorelease];
    NSArray *labels = [NSArray arrayWithObjects:TGLoc(@"share.venue.name"), TGLoc(@"share.venue.address"),
                       TGLoc(@"share.location.latitude"), TGLoc(@"share.location.longitude"), nil];
    NSMutableArray *fields = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [labels count]; index++) {
        CGFloat columnX = (index % 2 == 0) ? 0.0 : 200.0;
        CGFloat y = (index < 2) ? 126.0 : 62.0;
        [accessory addSubview:[self labelWithFrame:NSMakeRect(columnX, y, 190.0, 18.0)
                                              text:[labels objectAtIndex:index]]];
        NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(columnX, y - 26.0, 190.0, 22.0)] autorelease];
        [accessory addSubview:field];
        [fields addObject:field];
    }
    [alert setAccessoryView:accessory];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    double latitude = 0.0;
    double longitude = 0.0;
    NSString *title = [[(NSTextField *)[fields objectAtIndex:0] stringValue]
                       stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *address = [[(NSTextField *)[fields objectAtIndex:1] stringValue]
                         stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL valid = [title length] > 0 &&
        [self scanCoordinateText:[(NSTextField *)[fields objectAtIndex:2] stringValue] value:&latitude] &&
        [self scanCoordinateText:[(NSTextField *)[fields objectAtIndex:3] stringValue] value:&longitude] &&
        latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0;
    if (!valid) {
        NSRunAlertPanel(TGLoc(@"share.venue.failed"), @"%@", TGLoc(@"ok"), nil, nil,
                        TGLoc(@"share.venue.error"));
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            title, @"title", address, @"address",
            [NSNumber numberWithDouble:latitude], @"latitude",
            [NSNumber numberWithDouble:longitude], @"longitude", nil];
}

+ (NSDictionary *)liveLocationToShare {
    NSMutableDictionary *values = [[[self locationToShare] mutableCopy] autorelease];
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
