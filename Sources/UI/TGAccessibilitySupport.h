#import <Cocoa/Cocoa.h>

@class TGChatItem;
@class TGMessageItem;

void TGAccessibilityConfigureButton(NSButton *button,
                                    NSString *label,
                                    NSString *help);
void TGAccessibilityUpdateButtonState(NSButton *button);
void TGAccessibilityConfigureList(NSTableView *tableView, NSString *label);
void TGAccessibilityConfigureContent(id element, NSString *description);
NSString *TGAccessibilityDescriptionForChatItem(TGChatItem *item);
NSString *TGAccessibilityDescriptionForMessageItem(TGMessageItem *item);
