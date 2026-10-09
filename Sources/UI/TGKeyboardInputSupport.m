#import "TGKeyboardInputSupport.h"

@implementation TGEscapeCloseWindow

- (void)cancelOperation:(id)sender {
    /* A window delegate may clear its final owner while handling windowWillClose:. */
    [self retain];
    [self performClose:sender];
    [self release];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    NSUInteger shortcutModifiers = NSCommandKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSShiftKeyMask;
    if ([event type] == NSKeyDown &&
        [[event charactersIgnoringModifiers] isEqualToString:@"\033"] &&
        ([event modifierFlags] & shortcutModifiers) == 0) {
        [self cancelOperation:self];
        return YES;
    }
    return [super performKeyEquivalent:event];
}

@end

TGComposerKeyboardCommand TGComposerCommandForSelector(SEL selector, NSUInteger modifierFlags) {
    if (selector == @selector(insertLineBreak:) ||
        selector == @selector(insertNewlineIgnoringFieldEditor:)) {
        return TGComposerKeyboardCommandLineBreak;
    }
    if (selector == @selector(insertNewline:)) {
        return ((modifierFlags & NSShiftKeyMask) != 0)
            ? TGComposerKeyboardCommandLineBreak
            : TGComposerKeyboardCommandSend;
    }
    return TGComposerKeyboardCommandUnhandled;
}

BOOL TGComposerInsertLineBreak(NSTextView *fieldEditor) {
    if (!fieldEditor || ![fieldEditor isEditable] || [fieldEditor hasMarkedText]) {
        return NO;
    }
    /* insertNewline: ends editing in an NSTextField's shared field editor.
       Text insertion bypasses that command routing, preserving the selection,
       normal change notifications, undo, and the active editing session. */
    [fieldEditor insertText:@"\n" replacementRange:[fieldEditor selectedRange]];
    return YES;
}
