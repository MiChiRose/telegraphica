#import <Cocoa/Cocoa.h>
#import "TGKeyboardInputSupport.h"

static void TGAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Keyboard input probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

@interface TGKeyboardProbeWindow : TGEscapeCloseWindow {
    NSUInteger _closeCount;
}
@property (nonatomic, assign) NSUInteger closeCount;
@end
@implementation TGKeyboardProbeWindow
@synthesize closeCount = _closeCount;
- (void)performClose:(id)sender {
    (void)sender;
    self.closeCount++;
}
@end

@interface TGKeyboardProbeObserver : NSObject {
    NSUInteger _changeCount;
}
@property (nonatomic, assign) NSUInteger changeCount;
@end
@implementation TGKeyboardProbeObserver
@synthesize changeCount = _changeCount;
- (void)textChanged:(NSNotification *)notification {
    (void)notification;
    self.changeCount++;
}
@end

static NSEvent *TGKeyEvent(NSString *characters, NSUInteger flags, unsigned short keyCode) {
    return [NSEvent keyEventWithType:NSKeyDown location:NSZeroPoint modifierFlags:flags
                         timestamp:0.0 windowNumber:0 context:nil characters:characters
       charactersIgnoringModifiers:characters isARepeat:NO keyCode:keyCode];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    TGAssert(TGComposerCommandForSelector(@selector(insertNewline:), 0) == TGComposerKeyboardCommandSend,
             @"plain Return keeps sending");
    TGAssert(TGComposerCommandForSelector(@selector(insertNewline:), NSShiftKeyMask) == TGComposerKeyboardCommandLineBreak,
             @"Shift Return inserts a line break");
    TGAssert(TGComposerCommandForSelector(@selector(insertNewline:), NSCommandKeyMask) == TGComposerKeyboardCommandSend,
             @"Command Return keeps sending");
    TGAssert(TGComposerCommandForSelector(@selector(insertLineBreak:), 0) == TGComposerKeyboardCommandLineBreak,
             @"explicit line-break binding");
    TGAssert(TGComposerCommandForSelector(@selector(insertNewlineIgnoringFieldEditor:), NSAlternateKeyMask) == TGComposerKeyboardCommandLineBreak,
             @"Option Return bypasses field-editor submission");
    TGAssert(TGComposerCommandForSelector(@selector(paste:), NSShiftKeyMask) == TGComposerKeyboardCommandUnhandled,
             @"unrelated input remains with its owner");

    NSTextView *editor = [[[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 240, 90)] autorelease];
    [editor setFieldEditor:YES];
    [editor setAllowsUndo:YES];
    [editor setString:@"first second"];
    [editor setSelectedRange:NSMakeRange(5, 1)];
    TGKeyboardProbeObserver *observer = [[[TGKeyboardProbeObserver alloc] init] autorelease];
    [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(textChanged:)
                                                 name:NSTextDidChangeNotification object:editor];
    TGAssert(TGComposerInsertLineBreak(editor), @"editable field editor accepts insertion");
    TGAssert([[editor string] isEqualToString:@"first\nsecond"], @"newline replaces selection without ending editing");
    TGAssert(NSEqualRanges([editor selectedRange], NSMakeRange(6, 0)), @"caret follows inserted newline");
    TGAssert([editor isFieldEditor], @"shared field-editor role survives insertion");
    TGAssert(observer.changeCount == 1, @"draft/layout delegates receive a normal text change");
    [editor setSelectedRange:NSMakeRange([[editor string] length], 0)];
    TGComposerInsertLineBreak(editor);
    TGAssert([[editor string] isEqualToString:@"first\nsecond\n"], @"empty final line is retained");
    [editor setEditable:NO];
    TGAssert(!TGComposerInsertLineBreak(editor), @"read-only editor is untouched");
    TGAssert(!TGComposerInsertLineBreak(nil), @"missing editor is untouched");
    [editor setEditable:YES];
    [editor setMarkedText:@"pending" selectedRange:NSMakeRange(7, 0) replacementRange:[editor selectedRange]];
    NSString *markedString = [[editor string] copy];
    TGAssert(!TGComposerInsertLineBreak(editor), @"IME composition is left to the input method");
    TGAssert([[editor string] isEqualToString:markedString], @"IME composition is preserved");
    [markedString release];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];

    TGKeyboardProbeWindow *window = [[[TGKeyboardProbeWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 240, 180) styleMask:NSTitledWindowMask | NSClosableWindowMask
        backing:NSBackingStoreBuffered defer:NO] autorelease];
    [window setReleasedWhenClosed:NO];
    TGAssert([window performKeyEquivalent:TGKeyEvent(@"\033", 0, 53)], @"Escape is consumed by preview window");
    TGAssert(window.closeCount == 1, @"Escape closes preview locally");
    TGAssert([window performKeyEquivalent:TGKeyEvent(@"\033", NSAlphaShiftKeyMask, 53)], @"Caps Lock does not disable Escape");
    TGAssert(window.closeCount == 2, @"Caps Lock Escape closes preview");
    [window performKeyEquivalent:TGKeyEvent(@"\033", NSCommandKeyMask, 53)];
    TGAssert(window.closeCount == 2, @"modified Escape keeps system shortcut behavior");
    [window cancelOperation:nil];
    TGAssert(window.closeCount == 3, @"responder-chain cancellation closes the same preview");

    NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 220, 80)] autorelease];
    [[field cell] setUsesSingleLineMode:NO];
    [[field cell] setWraps:YES];
    [[field cell] setScrollable:NO];
    [field setStringValue:@"bound composer"];
    [[window contentView] addSubview:field];
    TGAssert([window makeFirstResponder:field], @"composer begins editing");
    NSTextView *boundEditor = (NSTextView *)[field currentEditor];
    TGAssert(boundEditor && [boundEditor isFieldEditor], @"test uses the NSTextField shared editor");
    [boundEditor setSelectedRange:NSMakeRange(5, 1)];
    TGAssert(TGComposerInsertLineBreak(boundEditor), @"bound composer accepts the newline");
    TGAssert([[boundEditor string] isEqualToString:@"bound\ncomposer"], @"bound editor has a real multiline draft");
    TGAssert([[field stringValue] isEqualToString:@"bound\ncomposer"], @"field value is current during editing for draft/layout readers");
    TGAssert([field currentEditor] == boundEditor && [window firstResponder] == boundEditor,
             @"Shift Return keeps composer focus and editing session");
    [window makeFirstResponder:nil];
    TGAssert([[field stringValue] isEqualToString:@"bound\ncomposer"], @"committed field preserves newline");
    fprintf(stdout, "Keyboard input probe PASS\n");
    [pool drain];
    return 0;
}
