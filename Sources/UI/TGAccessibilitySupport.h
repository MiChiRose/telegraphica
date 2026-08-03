#import <Cocoa/Cocoa.h>

void TGAccessibilityConfigureButton(NSButton *button,
                                    NSString *label,
                                    NSString *help);
void TGAccessibilityUpdateButtonState(NSButton *button);
void TGAccessibilityConfigureList(NSTableView *tableView, NSString *label);
