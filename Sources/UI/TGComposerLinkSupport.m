#import "TGComposerLinkSupport.h"

#import "TGLocalization.h"

NSString * const TGComposerLinkRangeKey = @"range";
NSString * const TGComposerLinkLabelRangeKey = @"label_range";
NSString * const TGComposerLinkLabelKey = @"label";
NSString * const TGComposerLinkURLKey = @"url";

static BOOL TGComposerCharacterIsEscaped(NSString *text, NSUInteger index) {
    if (![text isKindOfClass:[NSString class]] || index == 0 || index > [text length]) {
        return NO;
    }
    NSUInteger slashCount = 0;
    NSUInteger cursor = index;
    while (cursor > 0 && [text characterAtIndex:cursor - 1] == '\\') {
        slashCount++;
        cursor--;
    }
    return ((slashCount % 2) != 0);
}

static NSUInteger TGComposerClosingParenthesis(NSString *text, NSUInteger start) {
    NSUInteger length = [text length];
    NSUInteger index = start;
    for (index = start; index < length; index++) {
        if ([text characterAtIndex:index] == ')' && !TGComposerCharacterIsEscaped(text, index)) {
            return index;
        }
    }
    return NSNotFound;
}

NSString *TGComposerPlainTextFromMarkdownLabel(NSString *label) {
    if (![label isKindOfClass:[NSString class]] || [label length] == 0) {
        return @"";
    }
    NSMutableString *plain = [NSMutableString stringWithCapacity:[label length]];
    NSUInteger index = 0;
    for (index = 0; index < [label length]; index++) {
        unichar character = [label characterAtIndex:index];
        if (character == '\\' && index + 1 < [label length]) {
            index++;
            character = [label characterAtIndex:index];
        }
        [plain appendFormat:@"%C", character];
    }
    return plain;
}

static NSString *TGComposerPlainURLFromMarkdownTarget(NSString *target) {
    return TGComposerPlainTextFromMarkdownLabel(target);
}

NSDictionary *TGComposerLinkInfoForTextSelection(NSString *text, NSRange selection) {
    if (![text isKindOfClass:[NSString class]] || [text length] == 0 ||
        selection.location == NSNotFound || selection.location > [text length] ||
        selection.length > [text length] - selection.location) {
        return nil;
    }

    NSUInteger searchStart = MIN(selection.location + (selection.location < [text length] ? 1 : 0),
                                 [text length]);
    NSUInteger opening = searchStart;
    while (opening > 0) {
        opening--;
        if ([text characterAtIndex:opening] != '[' || TGComposerCharacterIsEscaped(text, opening)) {
            continue;
        }

        NSRange suffixSearch = NSMakeRange(opening + 1, [text length] - opening - 1);
        NSRange divider = [text rangeOfString:@"](" options:0 range:suffixSearch];
        if (divider.location == NSNotFound || TGComposerCharacterIsEscaped(text, divider.location)) {
            continue;
        }
        NSUInteger closing = TGComposerClosingParenthesis(text, NSMaxRange(divider));
        if (closing == NSNotFound) {
            continue;
        }

        NSRange linkRange = NSMakeRange(opening, closing - opening + 1);
        NSRange labelRange = NSMakeRange(opening + 1, divider.location - opening - 1);
        BOOL cursorInsideLabel = (selection.length == 0 &&
                                  selection.location >= labelRange.location &&
                                  selection.location <= NSMaxRange(labelRange));
        BOOL selectionInsideLink = (selection.length > 0 &&
                                    selection.location >= linkRange.location &&
                                    NSMaxRange(selection) <= NSMaxRange(linkRange));
        if (!cursorInsideLabel && !selectionInsideLink) {
            continue;
        }

        NSRange targetRange = NSMakeRange(NSMaxRange(divider), closing - NSMaxRange(divider));
        NSString *label = [text substringWithRange:labelRange];
        NSString *target = [text substringWithRange:targetRange];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                [NSValue valueWithRange:linkRange], TGComposerLinkRangeKey,
                [NSValue valueWithRange:labelRange], TGComposerLinkLabelRangeKey,
                label, TGComposerLinkLabelKey,
                TGComposerPlainURLFromMarkdownTarget(target), TGComposerLinkURLKey,
                nil];
    }
    return nil;
}

static NSString *TGComposerEscapedMarkdownText(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *specialCharacters = @"\\_*[]()~`>#+-=|{}.!";
    NSMutableString *escaped = [NSMutableString stringWithCapacity:[text length]];
    NSUInteger index = 0;
    for (index = 0; index < [text length]; index++) {
        unichar character = [text characterAtIndex:index];
        if ([specialCharacters rangeOfString:[NSString stringWithFormat:@"%C", character]].location != NSNotFound) {
            [escaped appendString:@"\\"];
        }
        [escaped appendFormat:@"%C", character];
    }
    return escaped;
}

static NSString *TGComposerEscapedMarkdownURL(NSString *URLString) {
    NSMutableString *escaped = [NSMutableString stringWithCapacity:[URLString length]];
    NSUInteger index = 0;
    for (index = 0; index < [URLString length]; index++) {
        unichar character = [URLString characterAtIndex:index];
        if (character == '\\' || character == '(' || character == ')') {
            [escaped appendString:@"\\"];
        }
        [escaped appendFormat:@"%C", character];
    }
    return escaped;
}

NSString *TGComposerMarkdownLinkString(NSString *label, NSString *URLString) {
    NSString *safeLabel = TGComposerEscapedMarkdownText(label ? label : @"");
    NSString *safeURL = TGComposerEscapedMarkdownURL(URLString ? URLString : @"");
    return [NSString stringWithFormat:@"[%@](%@)", safeLabel, safeURL];
}

static NSString *TGComposerNormalizedLinkURL(NSString *input) {
    NSString *candidate = [input stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([candidate length] == 0 ||
        [candidate rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        return nil;
    }
    if ([candidate rangeOfString:@"://"].location == NSNotFound) {
        candidate = [@"https://" stringByAppendingString:candidate];
    }
    NSURL *URL = [NSURL URLWithString:candidate];
    NSString *scheme = [[URL scheme] lowercaseString];
    BOOL supportedScheme = ([scheme isEqualToString:@"http"] ||
                            [scheme isEqualToString:@"https"] ||
                            [scheme isEqualToString:@"tg"]);
    if (!URL || !supportedScheme || [[URL host] length] == 0) {
        return nil;
    }
    return candidate;
}

NSString *TGComposerPromptForLinkURL(NSString *selectedText, NSString *currentURL) {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:([currentURL length] > 0
                           ? TGLoc(@"composer.link.edit")
                           : TGLoc(@"composer.link.add"))];
    [alert setInformativeText:TGLoc(@"composer.link.hint")];
    [alert addButtonWithTitle:TGLoc(@"composer.link.apply")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];

    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 390.0, 58.0)] autorelease];
    NSTextField *selectionLabel = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 36.0, 390.0, 18.0)] autorelease];
    [selectionLabel setEditable:NO];
    [selectionLabel setSelectable:NO];
    [selectionLabel setBordered:NO];
    [selectionLabel setDrawsBackground:NO];
    [selectionLabel setFont:[NSFont systemFontOfSize:11.0]];
    NSString *plainSelection = TGComposerPlainTextFromMarkdownLabel(selectedText);
    [selectionLabel setStringValue:[NSString stringWithFormat:TGLoc(@"composer.link.selection"),
                                    plainSelection ? plainSelection : @""]];
    [accessory addSubview:selectionLabel];

    NSTextField *URLField = [[[NSTextField alloc] initWithFrame:NSMakeRect(0.0, 4.0, 390.0, 24.0)] autorelease];
    [[URLField cell] setPlaceholderString:@"https://example.com"];
    [URLField setStringValue:currentURL ? currentURL : @""];
    [accessory addSubview:URLField];
    [alert setAccessoryView:accessory];

    while ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *normalizedURL = TGComposerNormalizedLinkURL([URLField stringValue]);
        if ([normalizedURL length] > 0) {
            return [[normalizedURL copy] autorelease];
        }
        [alert setInformativeText:TGLoc(@"composer.link.invalid")];
    }
    return nil;
}
