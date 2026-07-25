#import "TGConversationCreationPrompt.h"

#import "TGLocalization.h"

@implementation TGConversationCreationPrompt

+ (NSTextField *)fieldWithFrame:(NSRect)frame placeholder:(NSString *)placeholder {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [[field cell] setPlaceholderString:placeholder];
    return field;
}

+ (BOOL)runPromptWithTitle:(NSString *)message
               information:(NSString *)information
                 titleValue:(NSString **)titleValue
           descriptionValue:(NSString **)descriptionValue {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:message];
    [alert setInformativeText:information];
    [alert addButtonWithTitle:TGLoc(@"create.confirm")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    CGFloat height = descriptionValue ? 78.0 : 30.0;
    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, height)] autorelease];
    NSTextField *titleField = [self fieldWithFrame:NSMakeRect(0, height - 30.0, 360, 24)
                                       placeholder:TGLoc(@"create.titlePlaceholder")];
    [accessory addSubview:titleField];
    NSTextField *descriptionField = nil;
    if (descriptionValue) {
        descriptionField = [self fieldWithFrame:NSMakeRect(0, 0, 360, 40)
                                     placeholder:TGLoc(@"create.descriptionPlaceholder")];
        [[descriptionField cell] setUsesSingleLineMode:NO];
        [accessory addSubview:descriptionField];
    }
    [alert setAccessoryView:accessory];

    while ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *safeTitle = [[titleField stringValue] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *safeDescription = descriptionField
            ? [[descriptionField stringValue] stringByTrimmingCharactersInSet:
               [NSCharacterSet whitespaceAndNewlineCharacterSet]]
            : @"";
        if ([safeTitle length] == 0 || [safeTitle length] > 128 || [safeDescription length] > 255) {
            [alert setInformativeText:TGLoc(@"create.validation")];
            continue;
        }
        if (titleValue) {
            *titleValue = [[safeTitle copy] autorelease];
        }
        if (descriptionValue) {
            *descriptionValue = [[safeDescription copy] autorelease];
        }
        return YES;
    }
    return NO;
}

+ (BOOL)runGroupPromptWithMemberCount:(NSUInteger)memberCount title:(NSString **)title {
    return [self runPromptWithTitle:TGLoc(@"create.groupTitle")
                        information:[NSString stringWithFormat:TGLoc(@"create.groupMembers"), (unsigned long)memberCount]
                          titleValue:title
                    descriptionValue:NULL];
}

+ (BOOL)runChannelPromptWithTitle:(NSString **)title description:(NSString **)description {
    return [self runPromptWithTitle:TGLoc(@"create.channelTitle")
                        information:TGLoc(@"create.channelInfo")
                          titleValue:title
                    descriptionValue:description];
}

@end
