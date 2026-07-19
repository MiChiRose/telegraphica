@interface TGChatSearchResultsTableView : NSTableView
@end

@implementation TGChatSearchResultsTableView

- (BOOL)isOpaque {
    return NO;
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect {
    (void)clipRect;
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    NSInteger selectedRow = [self selectedRow];
    if (selectedRow < 0 || selectedRow >= [self numberOfRows]) {
        return;
    }
    NSRect rowRect = NSInsetRect([self rectOfRow:selectedRow], 4.0, 3.0);
    if (!NSIntersectsRect(rowRect, clipRect)) {
        return;
    }
    NSBezierPath *selectedPath = [NSBezierPath bezierPathWithRoundedRect:rowRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawEnamelButtonInPath(selectedPath, rowRect, NO, YES, YES, [self isFlipped]);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.30] set];
    [selectedPath setLineWidth:1.0];
    [selectedPath stroke];
}

@end

@interface TGChatSearchPanelView : NSView <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate> {
    id _target;
    SEL _queryChangedAction;
    SEL _commitAction;
    SEL _closeAction;
    NSString *_statusText;
    NSArray *_results;
    NSSearchField *_searchField;
    NSTextField *_titleField;
    NSTextField *_statusField;
    NSScrollView *_scrollView;
    NSTableView *_tableView;
    NSButton *_closeButton;
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
- (NSSearchField *)searchField;
- (void)layoutPanelSubviews;
@end

@implementation TGChatSearchPanelView

@synthesize target = _target;
@synthesize queryChangedAction = _queryChangedAction;
@synthesize commitAction = _commitAction;
@synthesize closeAction = _closeAction;
@synthesize statusText = _statusText;
@synthesize results = _results;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _statusText = [TGLoc(@"search.chats.recent") copy];
        _results = [[NSArray alloc] init];

        _titleField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [_titleField setEditable:NO];
        [_titleField setBordered:NO];
        [_titleField setDrawsBackground:NO];
        [_titleField setSelectable:NO];
        [_titleField setFont:[NSFont boldSystemFontOfSize:16.0]];
        [_titleField setTextColor:TGClassicInkColor()];
        [_titleField setStringValue:TGLoc(@"search.chats.title")];
        [self addSubview:_titleField];

        _searchField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
        [_searchField setDelegate:self];
        [_searchField setTarget:self];
        [_searchField setAction:@selector(commitSearch:)];
        [_searchField setBezeled:NO];
        [_searchField setBordered:NO];
        [_searchField setDrawsBackground:NO];
        [_searchField setFocusRingType:NSFocusRingTypeNone];
        [[_searchField cell] setPlaceholderString:TGLoc(@"search.chats.placeholder")];
        [self addSubview:_searchField];

        _closeButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        [_closeButton setTitle:@"×"];
        [_closeButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"×"] autorelease]];
        [_closeButton setBordered:NO];
        [_closeButton setFocusRingType:NSFocusRingTypeNone];
        [_closeButton setFont:[NSFont boldSystemFontOfSize:15.0]];
        [_closeButton setTarget:self];
        [_closeButton setAction:@selector(closeSearch:)];
        [self addSubview:_closeButton];

        _statusField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        [_statusField setEditable:NO];
        [_statusField setBordered:NO];
        [_statusField setDrawsBackground:NO];
        [_statusField setSelectable:NO];
        [_statusField setFont:[NSFont systemFontOfSize:11.0]];
        [_statusField setTextColor:TGClassicMutedInkColor()];
        [_statusField setStringValue:_statusText ? _statusText : @""];
        [self addSubview:_statusField];

        _tableView = [[TGChatSearchResultsTableView alloc] initWithFrame:NSZeroRect];
        [_tableView setHeaderView:nil];
        [_tableView setRowHeight:46.0];
        [_tableView setDelegate:self];
        [_tableView setDataSource:self];
        [_tableView setTarget:self];
        [_tableView setDoubleAction:@selector(commitSearch:)];
        [_tableView setAllowsEmptySelection:YES];
        [_tableView setBackgroundColor:[NSColor clearColor]];
        [_tableView setUsesAlternatingRowBackgroundColors:NO];
        [_tableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
        [_tableView setGridColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.38]];
        [_tableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
        [_tableView setIntercellSpacing:NSMakeSize(0.0, 1.0)];

        NSTableColumn *titleColumn = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
        [titleColumn setWidth:178.0];
        [[titleColumn dataCell] setFont:[NSFont boldSystemFontOfSize:12.0]];
        [[titleColumn dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [_tableView addTableColumn:titleColumn];

        NSTableColumn *detailsColumn = [[[NSTableColumn alloc] initWithIdentifier:@"details"] autorelease];
        [detailsColumn setWidth:206.0];
        [[detailsColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
        [[detailsColumn dataCell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [_tableView addTableColumn:detailsColumn];

        _scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        [_scrollView setHasVerticalScroller:YES];
        [_scrollView setHasHorizontalScroller:NO];
        [_scrollView setBorderType:NSNoBorder];
        [_scrollView setDrawsBackground:NO];
        [[_scrollView contentView] setDrawsBackground:NO];
        [[_scrollView contentView] setBackgroundColor:[NSColor clearColor]];
        [_scrollView setAutohidesScrollers:YES];
        [_scrollView setDocumentView:_tableView];
        [self addSubview:_scrollView];

        [self layoutPanelSubviews];
    }
    return self;
}

- (void)dealloc {
    [_statusText release];
    [_results release];
    [_searchField release];
    [_titleField release];
    [_statusField release];
    [_scrollView release];
    [_tableView release];
    [_closeButton release];
    [super dealloc];
}

- (BOOL)isFlipped {
    return YES;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    (void)oldSize;
    [self layoutPanelSubviews];
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [self layoutPanelSubviews];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self layoutPanelSubviews];
}

- (void)layoutPanelSubviews {
    NSRect bounds = [self bounds];
    CGFloat inset = 20.0;
    CGFloat closeSide = 28.0;
    [_titleField setFrame:NSMakeRect(inset + 4.0, 18.0, MAX(80.0, NSWidth(bounds) - (inset * 2.0) - closeSide - 12.0), 22.0)];
    [_closeButton setFrame:NSMakeRect(NSWidth(bounds) - inset - closeSide, 15.0, closeSide, 26.0)];
    [_searchField setFrame:NSMakeRect(inset + 10.0, 60.0, MAX(120.0, NSWidth(bounds) - (inset * 2.0) - 20.0), 28.0)];
    [_statusField setFrame:NSMakeRect(inset + 12.0, 96.0, MAX(120.0, NSWidth(bounds) - (inset * 2.0) - 24.0), 18.0)];
    [_scrollView setFrame:NSMakeRect(inset + 10.0, 126.0, MAX(120.0, NSWidth(bounds) - (inset * 2.0) - 20.0), MAX(80.0, NSHeight(bounds) - 148.0))];

    CGFloat tableWidth = NSWidth([[_scrollView contentView] bounds]);
    NSArray *columns = [_tableView tableColumns];
    if ([columns count] >= 2) {
        NSTableColumn *titleColumn = [columns objectAtIndex:0];
        NSTableColumn *detailsColumn = [columns objectAtIndex:1];
        CGFloat titleWidth = floor(MAX(135.0, tableWidth * 0.42));
        [titleColumn setWidth:titleWidth];
        [detailsColumn setWidth:MAX(100.0, tableWidth - titleWidth - 3.0)];
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    TGThemeDrawWindowBackgroundInRect(bounds, [self isFlipped]);

    NSRect shellRect = NSInsetRect(bounds, 10.0, 10.0);
    NSBezierPath *shellPath = [NSBezierPath bezierPathWithRoundedRect:shellRect xRadius:12.0 yRadius:12.0];
    TGThemeDrawPanelBackgroundInPath(shellPath, shellRect, [self isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [shellPath setLineWidth:1.0];
    [shellPath stroke];

    NSRect searchCardRect = NSMakeRect(18.0, 49.0, MAX(120.0, NSWidth(bounds) - 36.0), 66.0);
    NSBezierPath *searchCardPath = [NSBezierPath bezierPathWithRoundedRect:searchCardRect xRadius:10.0 yRadius:10.0];
    TGThemeDrawGroupedCardInPath(searchCardPath, searchCardRect, [self isFlipped]);
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.28] set];
    [searchCardPath setLineWidth:1.0];
    [searchCardPath stroke];

    NSRect inputRect = NSInsetRect([_searchField frame], -2.0, -2.0);
    NSBezierPath *inputPath = [NSBezierPath bezierPathWithRoundedRect:inputRect xRadius:8.0 yRadius:8.0];
    TGThemeDrawRecessedBackgroundInPath(inputPath, inputRect, [self isFlipped]);
    [TGClassicTableGridColor() set];
    [inputPath setLineWidth:1.0];
    [inputPath stroke];

    NSRect resultsCardRect = NSInsetRect([_scrollView frame], -8.0, -8.0);
    NSBezierPath *resultsCardPath = [NSBezierPath bezierPathWithRoundedRect:resultsCardRect xRadius:10.0 yRadius:10.0];
    TGThemeDrawGroupedCardInPath(resultsCardPath, resultsCardRect, [self isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [resultsCardPath setLineWidth:1.0];
    [resultsCardPath stroke];
}

- (NSSearchField *)searchField {
    return _searchField;
}

- (NSString *)query {
    return [_searchField stringValue] ? [_searchField stringValue] : @"";
}

- (void)setQuery:(NSString *)query {
    [_searchField setStringValue:(query ? query : @"")];
}

- (void)setStatusText:(NSString *)statusText {
    if (_statusText == statusText || [_statusText isEqualToString:statusText]) {
        return;
    }
    [_statusText release];
    _statusText = [statusText copy];
    [_statusField setStringValue:(_statusText ? _statusText : @"")];
}

- (void)setResults:(NSArray *)results {
    if (_results == results) {
        return;
    }
    [_results release];
    _results = [results retain];
    [_tableView reloadData];
    if ([_results count] > 0) {
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    } else {
        [_tableView deselectAll:self];
    }
}

- (TGSearchResultItem *)selectedResult {
    NSInteger selectedRow = [_tableView selectedRow];
    if (selectedRow < 0 || (NSUInteger)selectedRow >= [_results count]) {
        return nil;
    }
    id candidate = [_results objectAtIndex:(NSUInteger)selectedRow];
    return [candidate isKindOfClass:[TGSearchResultItem class]] ? (TGSearchResultItem *)candidate : nil;
}

- (NSInteger)selectedIndex {
    return [_tableView selectedRow];
}

- (void)setSelectedIndex:(NSInteger)selectedIndex {
    if (selectedIndex < 0 || (NSUInteger)selectedIndex >= [_results count]) {
        [_tableView deselectAll:self];
        return;
    }
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selectedIndex] byExtendingSelection:NO];
}

- (void)sendAction:(SEL)selector {
    if (_target && selector && [_target respondsToSelector:selector]) {
        [_target performSelector:selector withObject:self];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    (void)notification;
    [self sendAction:_queryChangedAction];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    (void)control;
    (void)textView;
    if (commandSelector == @selector(cancelOperation:)) {
        [self closeSearch:self];
        return YES;
    }
    if (commandSelector == @selector(insertNewline:) ||
        commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        [self commitSearch:self];
        return YES;
    }
    return NO;
}

- (void)commitSearch:(id)sender {
    (void)sender;
    if (![self selectedResult] && [_results count] > 0) {
        [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
    if ([self selectedResult]) {
        [self sendAction:_commitAction];
    }
}

- (void)closeSearch:(id)sender {
    (void)sender;
    [self sendAction:_closeAction];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[_results count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableView;
    if (row < 0 || (NSUInteger)row >= [_results count]) {
        return @"";
    }
    id candidate = [_results objectAtIndex:(NSUInteger)row];
    TGSearchResultItem *result = [candidate isKindOfClass:[TGSearchResultItem class]] ? (TGSearchResultItem *)candidate : nil;
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"title"]) {
        return [result displayTitle] ? [result displayTitle] : TGLoc(@"search.chats.fallbackChat");
    }
    NSString *subtitle = [result displaySubtitle];
    return [subtitle length] > 0 ? subtitle : TGLoc(@"search.chats.openHint");
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableView;
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    BOOL selected = (row == [_tableView selectedRow]);
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"title"]) {
        [textCell setFont:[NSFont boldSystemFontOfSize:12.0]];
        [textCell setTextColor:(selected ? TGClassicHeaderTextColor(1.0) : TGClassicInkColor())];
    } else {
        [textCell setFont:[NSFont systemFontOfSize:11.0]];
        [textCell setTextColor:(selected ? TGClassicHeaderDetailTextColor(0.96) : TGClassicMutedInkColor())];
    }
    [textCell setDrawsBackground:NO];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
}

- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:[_closeButton frame] cursor:[NSCursor pointingHandCursor]];
    [self addCursorRect:[_scrollView frame] cursor:[NSCursor pointingHandCursor]];
}

@end
