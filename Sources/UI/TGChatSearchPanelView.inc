@interface TGChatSearchPanelView : NSView {
    id _target;
    SEL _queryChangedAction;
    SEL _commitAction;
    SEL _closeAction;
    NSString *_query;
    NSString *_statusText;
    NSArray *_results;
    NSInteger _selectedIndex;
}
@property (nonatomic, assign) id target;
@property (nonatomic, assign) SEL queryChangedAction;
@property (nonatomic, assign) SEL commitAction;
@property (nonatomic, assign) SEL closeAction;
@property (nonatomic, copy) NSString *query;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, retain) NSArray *results;
@property (nonatomic, assign) NSInteger selectedIndex;
- (TGSearchResultItem *)selectedResult;
@end

@implementation TGChatSearchPanelView

@synthesize target = _target;
@synthesize queryChangedAction = _queryChangedAction;
@synthesize commitAction = _commitAction;
@synthesize closeAction = _closeAction;
@synthesize query = _query;
@synthesize statusText = _statusText;
@synthesize results = _results;
@synthesize selectedIndex = _selectedIndex;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _query = [@"" copy];
        _statusText = [@"Start typing to find a chat" copy];
        _results = [[NSArray alloc] init];
        _selectedIndex = -1;
    }
    return self;
}

- (void)dealloc {
    [_query release];
    [_statusText release];
    [_results release];
    [super dealloc];
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)setQuery:(NSString *)query {
    if (_query == query || [_query isEqualToString:query]) {
        return;
    }
    [_query release];
    _query = [query copy];
    [self setNeedsDisplay:YES];
}

- (void)setStatusText:(NSString *)statusText {
    if (_statusText == statusText || [_statusText isEqualToString:statusText]) {
        return;
    }
    [_statusText release];
    _statusText = [statusText copy];
    [self setNeedsDisplay:YES];
}

- (void)setResults:(NSArray *)results {
    if (_results == results) {
        return;
    }
    [_results release];
    _results = [results retain];
    if (_selectedIndex >= (NSInteger)[_results count]) {
        _selectedIndex = [_results count] > 0 ? 0 : -1;
    }
    [self setNeedsDisplay:YES];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    _selectedIndex = selectedIndex;
    [self setNeedsDisplay:YES];
}

- (NSRect)searchFieldRect {
    NSRect bounds = [self bounds];
    return NSMakeRect(22.0, 58.0, MAX(120.0, NSWidth(bounds) - 44.0), 30.0);
}

- (NSRect)resultsRect {
    NSRect bounds = [self bounds];
    return NSMakeRect(20.0, 116.0, MAX(120.0, NSWidth(bounds) - 40.0), MAX(80.0, NSHeight(bounds) - 136.0));
}

- (void)sendAction:(SEL)selector {
    if (_target && selector && [_target respondsToSelector:selector]) {
        [_target performSelector:selector withObject:self];
    }
}

- (TGSearchResultItem *)selectedResult {
    if (_selectedIndex < 0 || (NSUInteger)_selectedIndex >= [_results count]) {
        return nil;
    }
    id candidate = [_results objectAtIndex:(NSUInteger)_selectedIndex];
    return [candidate isKindOfClass:[TGSearchResultItem class]] ? (TGSearchResultItem *)candidate : nil;
}

- (void)notifyQueryChanged {
    [self sendAction:_queryChangedAction];
}

- (void)commitSelection {
    if ([self selectedResult] == nil && [_results count] > 0) {
        self.selectedIndex = 0;
    }
    if ([self selectedResult]) {
        [self sendAction:_commitAction];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [[NSColor colorWithCalibratedRed:0.93 green:0.96 blue:0.98 alpha:1.0] set];
    NSRectFill(bounds);

    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:16.0], NSFontAttributeName,
                                     TGClassicInkColor(), NSForegroundColorAttributeName,
                                     nil];
    [@"Search chats" drawInRect:NSMakeRect(22.0, 20.0, NSWidth(bounds) - 44.0, 24.0)
                 withAttributes:titleAttributes];

    NSRect searchRect = [self searchFieldRect];
    NSBezierPath *searchPath = [NSBezierPath bezierPathWithRoundedRect:searchRect xRadius:7.0 yRadius:7.0];
    [[NSColor whiteColor] set];
    [searchPath fill];
    [[NSColor colorWithCalibratedRed:0.60 green:0.70 blue:0.78 alpha:1.0] set];
    [searchPath setLineWidth:1.0];
    [searchPath stroke];

    NSString *text = [_query length] > 0 ? _query : @"Chat, group, person";
    NSColor *textColor = [_query length] > 0 ? TGClassicInkColor() : TGClassicMutedInkColor();
    NSDictionary *queryAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:13.0], NSFontAttributeName,
                                     textColor, NSForegroundColorAttributeName,
                                     nil];
    [text drawInRect:NSMakeRect(NSMinX(searchRect) + 10.0, NSMinY(searchRect) + 7.0, NSWidth(searchRect) - 20.0, 18.0)
      withAttributes:queryAttributes];
    if ([[self window] firstResponder] == self) {
        NSSize querySize = [_query sizeWithAttributes:queryAttributes];
        CGFloat caretX = MIN(NSMinX(searchRect) + 10.0 + querySize.width + 1.0, NSMaxX(searchRect) - 8.0);
        [[NSColor colorWithCalibratedWhite:0.25 alpha:0.8] set];
        NSRectFill(NSMakeRect(caretX, NSMinY(searchRect) + 7.0, 1.0, 17.0));
    }

    NSDictionary *statusAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                      TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                      nil];
    NSString *status = [_statusText length] > 0 ? _statusText : @"";
    [status drawInRect:NSMakeRect(24.0, 94.0, NSWidth(bounds) - 48.0, 16.0)
        withAttributes:statusAttributes];

    NSRect resultsRect = [self resultsRect];
    NSBezierPath *resultsPath = [NSBezierPath bezierPathWithRoundedRect:resultsRect xRadius:8.0 yRadius:8.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.92] set];
    [resultsPath fill];
    [[NSColor colorWithCalibratedRed:0.72 green:0.79 blue:0.84 alpha:1.0] set];
    [resultsPath stroke];

    if ([_results count] == 0) {
        NSString *empty = [_query length] > 0 ? @"No chats found" : @"Recent chats will appear here";
        NSDictionary *emptyAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                         TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                         nil];
        NSSize emptySize = [empty sizeWithAttributes:emptyAttributes];
        [empty drawAtPoint:NSMakePoint(NSMidX(resultsRect) - floor(emptySize.width / 2.0),
                                       NSMidY(resultsRect) - floor(emptySize.height / 2.0))
            withAttributes:emptyAttributes];
        return;
    }

    CGFloat rowHeight = 48.0;
    NSUInteger count = MIN((NSUInteger)floor(NSHeight(resultsRect) / rowHeight), [_results count]);
    NSUInteger index = 0;
    for (index = 0; index < count; index++) {
        TGSearchResultItem *result = [[_results objectAtIndex:index] isKindOfClass:[TGSearchResultItem class]] ? [_results objectAtIndex:index] : nil;
        NSRect rowRect = NSMakeRect(NSMinX(resultsRect), NSMinY(resultsRect) + ((CGFloat)index * rowHeight), NSWidth(resultsRect), rowHeight);
        if ((NSInteger)index == _selectedIndex) {
            [[NSColor colorWithCalibratedRed:0.78 green:0.87 blue:0.94 alpha:1.0] set];
            NSRectFill(NSInsetRect(rowRect, 1.0, 1.0));
        }
        if (index > 0) {
            [[NSColor colorWithCalibratedRed:0.82 green:0.87 blue:0.90 alpha:1.0] set];
            NSRectFill(NSMakeRect(NSMinX(rowRect) + 10.0, NSMinY(rowRect), NSWidth(rowRect) - 20.0, 1.0));
        }
        NSString *title = [result displayTitle] ? [result displayTitle] : @"Chat";
        NSString *subtitle = [result displaySubtitle] ? [result displaySubtitle] : @"";
        NSDictionary *rowTitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                            TGClassicInkColor(), NSForegroundColorAttributeName,
                                            nil];
        NSDictionary *rowSubtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                               TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                               nil];
        [title drawInRect:NSMakeRect(NSMinX(rowRect) + 12.0, NSMinY(rowRect) + 8.0, NSWidth(rowRect) - 24.0, 16.0)
          withAttributes:rowTitleAttributes];
        if ([subtitle length] > 0) {
            [subtitle drawInRect:NSMakeRect(NSMinX(rowRect) + 12.0, NSMinY(rowRect) + 26.0, NSWidth(rowRect) - 24.0, 14.0)
                  withAttributes:rowSubtitleAttributes];
        }
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    if (NSPointInRect(point, [self searchFieldRect])) {
        [[self window] makeFirstResponder:self];
        return;
    }
    NSRect resultsRect = [self resultsRect];
    if (NSPointInRect(point, resultsRect) && [_results count] > 0) {
        CGFloat rowHeight = 48.0;
        NSInteger index = (NSInteger)floor((point.y - NSMinY(resultsRect)) / rowHeight);
        if (index >= 0 && (NSUInteger)index < [_results count]) {
            self.selectedIndex = index;
            [self commitSelection];
        }
    }
}

- (void)keyDown:(NSEvent *)event {
    NSUInteger flags = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
    NSString *chars = [event charactersIgnoringModifiers];
    if ((flags & NSCommandKeyMask) && [chars length] > 0) {
        unichar command = [chars characterAtIndex:0];
        if (command == 'v' || command == 'V') {
            NSString *paste = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
            if ([paste length] > 0) {
                self.query = [_query stringByAppendingString:paste];
                self.selectedIndex = -1;
                [self notifyQueryChanged];
            }
        }
        return;
    }
    if ([chars length] == 0) {
        [super keyDown:event];
        return;
    }

    unichar c = [chars characterAtIndex:0];
    if (c == 27) {
        [self sendAction:_closeAction];
        return;
    }
    if (c == NSCarriageReturnCharacter || c == NSEnterCharacter || c == NSNewlineCharacter) {
        [self commitSelection];
        return;
    }
    if (c == NSUpArrowFunctionKey) {
        if ([_results count] > 0) {
            NSInteger next = (_selectedIndex <= 0) ? 0 : _selectedIndex - 1;
            self.selectedIndex = next;
        }
        return;
    }
    if (c == NSDownArrowFunctionKey) {
        if ([_results count] > 0) {
            NSInteger next = (_selectedIndex < 0) ? 0 : MIN(_selectedIndex + 1, (NSInteger)[_results count] - 1);
            self.selectedIndex = next;
        }
        return;
    }
    if (c == NSDeleteCharacter || c == 0x08) {
        if ([_query length] > 0) {
            self.query = [_query substringToIndex:[_query length] - 1];
            self.selectedIndex = -1;
            [self notifyQueryChanged];
        }
        return;
    }
    if ([[NSCharacterSet controlCharacterSet] characterIsMember:c]) {
        return;
    }
    self.query = [_query stringByAppendingString:chars];
    self.selectedIndex = -1;
    [self notifyQueryChanged];
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:[self searchFieldRect] cursor:[NSCursor IBeamCursor]];
    [self addCursorRect:[self resultsRect] cursor:[NSCursor pointingHandCursor]];
}

@end
