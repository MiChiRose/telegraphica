#import "TGStatusWindowController.h"

@interface TGStatusWindowController (TGStatusWindowStyling)
- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font;
- (void)applyPanelHeaderLabelStyle:(NSTextField *)field;
- (void)applyPanelHeaderDetailStyle:(NSTextField *)field;
- (void)applyMutedLabelStyle:(NSTextField *)field;
- (void)applySkeuomorphicButtonStyle:(NSButton *)button isPrimary:(BOOL)isPrimary;
- (void)applyUtilityButtonStyle:(NSButton *)button;
- (void)applySettingsListButtonStyle:(NSButton *)button;
- (void)applySettingsSwitchTextStyle:(NSButton *)button;
- (void)applyDestructiveSettingsButtonStyle:(NSButton *)button;
- (void)applySkeuomorphicTextFieldStyle:(NSTextField *)textField;
- (void)applyComposerTextFieldStyle:(NSTextField *)textField;
- (void)applyComposerPlaceholderStyle:(NSTextField *)textField;
- (void)applyHeaderIconButtonStyle:(NSButton *)button;
- (void)applySkeuomorphicScrollStyle:(NSScrollView *)scrollView;
- (void)applySkeuomorphicTableStyle:(NSTableView *)tableView;
- (void)applySkeuomorphicHeaderCellStyle:(NSTextFieldCell *)headerCell;
@end
