#import <Cocoa/Cocoa.h>
#import "TGAccessibilitySupport.h"

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

    printf("Accessibility support probe passed.\n");
    [pool drain];
    return 0;
}
