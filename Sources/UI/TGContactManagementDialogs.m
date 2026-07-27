#import "TGContactManagementDialogs.h"

#import "TGLocalization.h"

@implementation TGContactManagementDialogs

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

+ (NSString *)trimmedStringFromField:(NSTextField *)field {
    return [[field stringValue] stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSDictionary *)contactToAdd {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"contacts.add.title")];
    [alert setInformativeText:TGLoc(@"contacts.add.hint")];
    [alert addButtonWithTitle:TGLoc(@"contacts.add.action")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 178.0)] autorelease];
    NSArray *labels = [NSArray arrayWithObjects:
                       TGLoc(@"share.contact.firstName"),
                       TGLoc(@"share.contact.lastName"),
                       TGLoc(@"share.contact.phone"),
                       nil];
    NSMutableArray *fields = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [labels count]; index++) {
        CGFloat y = 154.0 - (CGFloat)index * 48.0;
        [accessory addSubview:[self labelWithFrame:NSMakeRect(0.0, y, 390.0, 18.0)
                                              text:[labels objectAtIndex:index]]];
        NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, y - 25.0, 390.0, 22.0)] autorelease];
        [accessory addSubview:field];
        [fields addObject:field];
    }

    NSButton *sharePhoneButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 22.0)] autorelease];
    [sharePhoneButton setButtonType:NSSwitchButton];
    [sharePhoneButton setTitle:TGLoc(@"contacts.add.sharePhone")];
    [sharePhoneButton setState:NSOffState];
    [accessory addSubview:sharePhoneButton];
    [alert setAccessoryView:accessory];

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }

    NSString *firstName = [self trimmedStringFromField:[fields objectAtIndex:0]];
    NSString *lastName = [self trimmedStringFromField:[fields objectAtIndex:1]];
    NSString *phoneNumber = [self trimmedStringFromField:[fields objectAtIndex:2]];
    if ([firstName length] == 0 || [phoneNumber length] == 0) {
        NSRunAlertPanel(TGLoc(@"contacts.add.failed"),
                        @"%@",
                        TGLoc(@"ok"), nil, nil,
                        TGLoc(@"share.contact.error.required"));
        return nil;
    }

    return [NSDictionary dictionaryWithObjectsAndKeys:
            firstName, @"first_name",
            lastName, @"last_name",
            phoneNumber, @"phone_number",
            [NSNumber numberWithBool:([sharePhoneButton state] == NSOnState)], @"share_phone_number",
            nil];
}

+ (NSString *)phoneNumberForInvitation {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"contacts.invite.title")];
    [alert setInformativeText:TGLoc(@"contacts.invite.hint")];
    [alert addButtonWithTitle:TGLoc(@"contacts.invite.action")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 48.0)] autorelease];
    [accessory addSubview:[self labelWithFrame:NSMakeRect(0.0, 28.0, 390.0, 18.0)
                                          text:TGLoc(@"share.contact.phone")]];
    NSTextField *phoneField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 22.0)] autorelease];
    [accessory addSubview:phoneField];
    [alert setAccessoryView:accessory];

    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    NSString *phoneNumber = [self trimmedStringFromField:phoneField];
    if ([phoneNumber length] == 0) {
        NSRunAlertPanel(TGLoc(@"contacts.invite.failed"),
                        @"%@",
                        TGLoc(@"ok"), nil, nil,
                        TGLoc(@"contacts.invite.phoneRequired"));
        return nil;
    }
    return phoneNumber;
}

+ (BOOL)confirmRemovalOfContactNamed:(NSString *)displayName {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"contacts.remove.title")];
    NSString *safeName = [displayName length] > 0 ? displayName : TGLoc(@"contacts.section.title");
    [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"contacts.remove.hint"), safeName]];
    [alert addButtonWithTitle:TGLoc(@"contacts.remove.action")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

@end
