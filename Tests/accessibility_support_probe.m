#import <Cocoa/Cocoa.h>
#import "TGAccessibilitySupport.h"
#import "TGChatItem.h"
#import "TGMessageItem.h"

@interface TGAccessibilityProbeButton : NSButton {
    NSMutableDictionary *_overrides;
}
@property (nonatomic, retain) NSMutableDictionary *overrides;
@end

@implementation TGAccessibilityProbeButton

@synthesize overrides = _overrides;

- (id)init {
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, 40.0, 24.0)];
    if (self) {
        self.overrides = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    [_overrides release];
    [super dealloc];
}

- (BOOL)accessibilitySetOverrideValue:(id)value forAttribute:(NSString *)attribute {
    if (value && attribute) {
        [self.overrides setObject:value forKey:attribute];
    }
    return YES;
}

@end

static void TGAccessibilityAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Accessibility support probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGAccessibilityProbeButton *button = [[[TGAccessibilityProbeButton alloc] init] autorelease];
    [button setButtonType:NSToggleButton];
    [button setEnabled:YES];
    [button setState:NSOnState];
    TGAccessibilityConfigureButton(button, @"Chats", @"Open the chat list");

    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityRoleAttribute]
                           isEqualToString:NSAccessibilityButtonRole], @"button role");
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityTitleAttribute]
                           isEqualToString:@"Chats"], @"button label");
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityHelpAttribute]
                           isEqualToString:@"Open the chat list"], @"button help");
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityEnabledAttribute] boolValue],
                          @"enabled state");
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityValueAttribute] boolValue],
                          @"selected state");

    [button setEnabled:NO];
    [button setState:NSOffState];
    TGAccessibilityUpdateButtonState(button);
    TGAccessibilityAssert(![[button.overrides objectForKey:NSAccessibilityEnabledAttribute] boolValue],
                          @"disabled state refresh");
    TGAccessibilityAssert(![[button.overrides objectForKey:NSAccessibilityValueAttribute] boolValue],
                          @"unselected state refresh");

    TGChatItem *chat = [[[TGChatItem alloc] initWithChatID:[NSNumber numberWithInteger:7]
                                                     title:@"Example"
                                               typeSummary:@"Private"
                                               unreadCount:[NSNumber numberWithInteger:3]] autorelease];
    [chat setNotificationsMuted:YES];
    [chat setPinned:YES];
    NSString *chatDescription = TGAccessibilityDescriptionForChatItem(chat);
    TGAccessibilityAssert([chatDescription rangeOfString:@"Example"].location != NSNotFound,
                          @"chat title description");
    TGAccessibilityAssert([chatDescription rangeOfString:@"3"].location != NSNotFound,
                          @"chat unread description");

    TGMessageItem *message = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInteger:7]
                                                          messageID:[NSNumber numberWithInteger:9]
                                                               date:[NSNumber numberWithInteger:1]
                                                           outgoing:YES
                                                            preview:@"Hello"] autorelease];
    [message setOutgoingRead:YES];
    [message setPinned:YES];
    [message setReactionSummary:@"🔥 2"];
    NSString *messageDescription = TGAccessibilityDescriptionForMessageItem(message);
    TGAccessibilityAssert([messageDescription rangeOfString:@"Hello"].location != NSNotFound,
                          @"message text description");
    TGAccessibilityAssert([messageDescription rangeOfString:@"🔥 2"].location != NSNotFound,
                          @"message reaction description");

    TGAccessibilityConfigureContent(button, messageDescription);
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityRoleAttribute]
                           isEqualToString:NSAccessibilityStaticTextRole], @"content role");
    TGAccessibilityAssert([[button.overrides objectForKey:NSAccessibilityValueAttribute]
                           isEqualToString:messageDescription], @"content value");

    printf("Accessibility support probe passed.\n");
    [pool drain];
    return 0;
}
