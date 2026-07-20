#import "TGMessageActionDialogs.h"
#import "TGLocalization.h"
#include <float.h>

@implementation TGMessageActionDialogs

+ (NSString *)editedTextForCurrentText:(NSString *)currentText {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.edit.title")];
    [alert setInformativeText:TGLoc(@"message.edit.hint")];
    [alert addButtonWithTitle:TGLoc(@"message.edit.save")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 420.0, 120.0)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setAutohidesScrollers:YES];

    NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [textView setMinSize:NSMakeSize(0.0, 120.0)];
    [textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [textView setVerticallyResizable:YES];
    [textView setHorizontallyResizable:NO];
    [textView setAutoresizingMask:NSViewWidthSizable];
    [[textView textContainer] setContainerSize:NSMakeSize(420.0, FLT_MAX)];
    [[textView textContainer] setWidthTracksTextView:YES];
    [textView setString:currentText ? currentText : @""];
    [scrollView setDocumentView:textView];
    [alert setAccessoryView:scrollView];

    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        return nil;
    }

    NSString *editedText = [[textView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return ([editedText length] > 0) ? [[editedText copy] autorelease] : nil;
}

+ (TGMessageDeleteChoice)deleteChoiceWithCanDeleteOnlyForSelf:(BOOL)canDeleteOnlyForSelf
                                         canDeleteForAllUsers:(BOOL)canDeleteForAllUsers {
    if (!canDeleteOnlyForSelf && !canDeleteForAllUsers) {
        return TGMessageDeleteChoiceCancel;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.delete.title")];
    [alert setInformativeText:TGLoc(@"message.delete.hint")];

    if (canDeleteForAllUsers) {
        [alert addButtonWithTitle:TGLoc(@"message.delete.everyone")];
    }
    if (canDeleteOnlyForSelf) {
        [alert addButtonWithTitle:TGLoc(@"message.delete.self")];
    }
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSInteger result = [alert runModal];
    NSInteger buttonIndex = result - NSAlertFirstButtonReturn;
    if (buttonIndex < 0) {
        return TGMessageDeleteChoiceCancel;
    }

    NSInteger nextIndex = 0;
    if (canDeleteForAllUsers) {
        if (buttonIndex == nextIndex) {
            return TGMessageDeleteChoiceForEveryone;
        }
        nextIndex++;
    }
    if (canDeleteOnlyForSelf) {
        if (buttonIndex == nextIndex) {
            return TGMessageDeleteChoiceOnlyForSelf;
        }
    }
    return TGMessageDeleteChoiceCancel;
}

+ (BOOL)confirmPlainDeleteMessage {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"message.delete.title")];
    [alert setInformativeText:TGLoc(@"message.delete.hint")];
    [alert addButtonWithTitle:TGLoc(@"message.delete.action")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

@end
