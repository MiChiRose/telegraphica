#import "TGStatusWindowStyling.h"
#import "TGIconAssets.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGTheme.h"

@implementation TGStatusWindowController (TGStatusWindowStyling)

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setTextColor:TGClassicInkColor()];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)applyPanelHeaderLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicHeaderTextColor(1.0)];
    [field setFont:[NSFont boldSystemFontOfSize:12.0]];
}

- (void)applyPanelHeaderDetailStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicHeaderDetailTextColor(1.0)];
    [field setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applyMutedLabelStyle:(NSTextField *)field {
    if (!field) {
        return;
    }
    [field setTextColor:TGClassicMutedInkColor()];
}

- (void)applySkeuomorphicButtonStyle:(NSButton *)button isPrimary:(BOOL)isPrimary {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSTexturedRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    if (isPrimary) {
        [button setFont:[NSFont boldSystemFontOfSize:12.0]];
    } else {
        [button setFont:[NSFont systemFontOfSize:11.0]];
    }
}

- (void)applyUtilityButtonStyle:(NSButton *)button {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSRoundedBezelStyle];
    [button setBordered:YES];
    [button setImagePosition:NSNoImage];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [button setFont:[NSFont systemFontOfSize:12.0]];
}

- (void)applySettingsListButtonStyle:(NSButton *)button {
    id target = [button target];
    SEL action = [button action];
    NSString *title = [[button title] copy];
    TGSettingsListButtonCell *cell = [[[TGSettingsListButtonCell alloc] initTextCell:[button title]] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:target];
    [button setAction:action];
    [button setBordered:NO];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [title release];
}

- (void)applySettingsSwitchTextStyle:(NSButton *)button {
    if (!button) {
        return;
    }
    NSString *title = [button title];
    if (!title) {
        title = @"";
    }
    NSFont *font = [button font];
    if (!font) {
        font = [NSFont systemFontOfSize:13.0];
    }
    NSColor *titleColor = [button isEnabled] ? TGClassicCardInkColor() : TGClassicCardMutedInkColor();
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                titleColor, NSForegroundColorAttributeName,
                                nil];
    NSAttributedString *attributedTitle = [[[NSAttributedString alloc] initWithString:title attributes:attributes] autorelease];
    [button setAttributedTitle:attributedTitle];
    [button setAttributedAlternateTitle:attributedTitle];
    [button setNeedsDisplay:YES];
}

- (void)applyDestructiveSettingsButtonStyle:(NSButton *)button {
    [button setButtonType:NSMomentaryPushInButton];
    [button setBezelStyle:NSRegularSquareBezelStyle];
    [button setBordered:NO];
    [button setImagePosition:NSImageLeft];
    [button setImage:TGTemplateIconAssetImage(@"log-out",
                                              NSMakeSize(16.0, 16.0),
                                              [NSColor colorWithCalibratedRed:0.920 green:0.140 blue:0.140 alpha:1.0],
                                              1.0)];
    [button setFocusRingType:NSFocusRingTypeExterior];
    [button setFont:[NSFont systemFontOfSize:14.0]];
    [[button cell] setAlignment:NSLeftTextAlignment];

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedRed:0.920 green:0.140 blue:0.140 alpha:1.0], NSForegroundColorAttributeName,
                                nil];
    NSAttributedString *title = [[[NSAttributedString alloc] initWithString:TGLoc(@"profile.logout") attributes:attributes] autorelease];
    [button setAttributedTitle:title];
}

- (void)applySkeuomorphicTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:YES];
    [textField setBordered:YES];
    [textField setBackgroundColor:TGClassicTablePaperColor()];
    [textField setTextColor:TGClassicInkColor()];
    [textField setDrawsBackground:YES];
    [textField setFocusRingType:NSFocusRingTypeExterior];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
    if ([[textField cell] isKindOfClass:[NSTextFieldCell class]]) {
        NSTextFieldCell *textFieldCell = (NSTextFieldCell *)[textField cell];
        [textFieldCell setBezelStyle:NSTextFieldRoundedBezel];
    }
}

- (void)applyComposerTextFieldStyle:(NSTextField *)textField {
    [textField setBezeled:NO];
    [textField setBordered:NO];
    [textField setBackgroundColor:[NSColor clearColor]];
    [textField setTextColor:TGClassicInkColor()];
    [textField setDrawsBackground:NO];
    [textField setFocusRingType:NSFocusRingTypeNone];
    [textField setFont:[NSFont systemFontOfSize:12.0]];
    if ([[textField cell] isKindOfClass:[NSTextFieldCell class]]) {
        NSTextFieldCell *textFieldCell = (NSTextFieldCell *)[textField cell];
        [textFieldCell setBezelStyle:NSTextFieldSquareBezel];
    }
    [self applyComposerPlaceholderStyle:textField];
}

- (void)applyComposerPlaceholderStyle:(NSTextField *)textField {
    if (![[textField cell] isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textFieldCell = (NSTextFieldCell *)[textField cell];
    NSString *placeholder = [textFieldCell placeholderString];
    if ([placeholder length] == 0 || ![textFieldCell respondsToSelector:@selector(setPlaceholderAttributedString:)]) {
        return;
    }
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                TGClassicCardMutedInkColor(), NSForegroundColorAttributeName,
                                [textField font] ? [textField font] : [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                nil];
    NSAttributedString *attributedPlaceholder = [[[NSAttributedString alloc] initWithString:placeholder attributes:attributes] autorelease];
    [textFieldCell setPlaceholderAttributedString:attributedPlaceholder];
}

- (void)applyHeaderIconButtonStyle:(NSButton *)button {
    NSString *title = [[button title] copy];
    id target = [button target];
    SEL action = [button action];
    NSInteger tag = [button tag];
    NSInteger state = [button state];
    BOOL enabled = [button isEnabled];
    NSString *toolTip = [[button toolTip] copy];
    TGHeaderIconButtonCell *cell = [[[TGHeaderIconButtonCell alloc] initTextCell:(title ? title : @"")] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:(title ? title : @"")];
    [button setTarget:target];
    [button setAction:action];
    [button setTag:tag];
    [button setState:state];
    [button setEnabled:enabled];
    [button setToolTip:toolTip];
    [button setBordered:NO];
    [button setFocusRingType:NSFocusRingTypeNone];
    [toolTip release];
    [title release];
}

- (void)applySkeuomorphicScrollStyle:(NSScrollView *)scrollView {
    [scrollView setBorderType:NSNoBorder];
    [[scrollView contentView] setDrawsBackground:YES];
    [[scrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];
    [scrollView setHasVerticalScroller:YES];
}

- (void)applySkeuomorphicTableStyle:(NSTableView *)tableView {
    [tableView setBackgroundColor:TGClassicTablePaperColor()];
    [tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [tableView setGridColor:TGClassicTableGridColor()];
    [tableView setUsesAlternatingRowBackgroundColors:NO];
    [tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];
    [tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleRegular];
}

- (void)applySkeuomorphicHeaderCellStyle:(NSTextFieldCell *)headerCell {
    if (!headerCell) {
        return;
    }
    [headerCell setFont:[NSFont boldSystemFontOfSize:11.0]];
    [headerCell setTextColor:TGClassicMutedInkColor()];
    [headerCell setAlignment:NSLeftTextAlignment];
    [headerCell setDrawsBackground:YES];
    [headerCell setBackgroundColor:TGClassicTableHeaderColor()];
}

@end
