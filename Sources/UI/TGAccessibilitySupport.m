#import "TGAccessibilitySupport.h"

static void TGAccessibilitySetOverride(id element, id value, NSString *attribute) {
    if (!element || !value || [attribute length] == 0 ||
        ![element respondsToSelector:@selector(accessibilitySetOverrideValue:forAttribute:)]) {
        return;
    }
    [element accessibilitySetOverrideValue:value forAttribute:attribute];
}

void TGAccessibilityConfigureButton(NSButton *button, NSString *label, NSString *help) {
    if (!button) {
        return;
    }
    NSString *safeLabel = [label isKindOfClass:[NSString class]] ? label : @"";
    NSString *safeHelp = [help isKindOfClass:[NSString class]] ? help : @"";
    [button setFocusRingType:NSFocusRingTypeDefault];
    TGAccessibilitySetOverride(button, NSAccessibilityButtonRole, NSAccessibilityRoleAttribute);
    if ([safeLabel length] > 0) {
        TGAccessibilitySetOverride(button, safeLabel, NSAccessibilityTitleAttribute);
    }
    if ([safeHelp length] > 0) {
        TGAccessibilitySetOverride(button, safeHelp, NSAccessibilityHelpAttribute);
    }
    TGAccessibilityUpdateButtonState(button);
}

void TGAccessibilityUpdateButtonState(NSButton *button) {
    if (!button) {
        return;
    }
    TGAccessibilitySetOverride(button,
                               [NSNumber numberWithBool:[button isEnabled]],
                               NSAccessibilityEnabledAttribute);
    TGAccessibilitySetOverride(button,
                               [NSNumber numberWithBool:([button state] == NSOnState)],
                               NSAccessibilityValueAttribute);
}

void TGAccessibilityConfigureList(NSTableView *tableView, NSString *label) {
    if (!tableView) {
        return;
    }
    TGAccessibilitySetOverride(tableView, NSAccessibilityListRole, NSAccessibilityRoleAttribute);
    if ([label isKindOfClass:[NSString class]] && [label length] > 0) {
        TGAccessibilitySetOverride(tableView, label, NSAccessibilityTitleAttribute);
    }
}
