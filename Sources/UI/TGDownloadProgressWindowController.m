#import "TGDownloadProgressWindowController.h"
#import "../Services/TGDownloadManager.h"
#import "TGLocalization.h"
#import "TGTheme.h"

NSRect TGDownloadProgressPanelFrame(NSRect mainFrame, NSRect visibleFrame, CGFloat panelHeight) {
    const CGFloat margin = 8.0;
    CGFloat rightX = MAX(NSMaxX(mainFrame) + margin, NSMinX(visibleFrame) + margin);
    CGFloat leftMaxX = MIN(NSMinX(mainFrame) - margin, NSMaxX(visibleFrame) - margin);
    CGFloat rightRoom = NSMaxX(visibleFrame) - margin - rightX;
    CGFloat leftRoom = leftMaxX - NSMinX(visibleFrame) - margin;
    CGFloat height = panelHeight;
    if (height <= 0.0 || height > NSHeight(visibleFrame) - 2.0 * margin) { return NSZeroRect; }
    CGFloat y = MAX(NSMinY(visibleFrame) + margin,
                    MIN(NSMaxY(mainFrame) - height, NSMaxY(visibleFrame) - margin - height));
    if (rightRoom >= 128.0 || leftRoom >= 128.0) {
        BOOL right = rightRoom >= 128.0;
        CGFloat width = MIN(224.0, right ? rightRoom : leftRoom);
        CGFloat x = right ? rightX : leftMaxX - width;
        return NSMakeRect(x, y, width, height);
    }
    CGFloat width = MIN(224.0, NSWidth(visibleFrame) - 2.0 * margin);
    CGFloat x = MAX(NSMinX(visibleFrame) + margin,
                    MIN(NSMaxX(mainFrame) - width, NSMaxX(visibleFrame) - margin - width));
    if (width < 128.0) { return NSZeroRect; }
    if (NSMinY(mainFrame) - NSMinY(visibleFrame) >= height + 2.0 * margin) {
        return NSMakeRect(x, NSMinY(mainFrame) - margin - height, width, height);
    }
    if (NSMaxY(visibleFrame) - NSMaxY(mainFrame) >= height + 2.0 * margin) {
        return NSMakeRect(x, NSMaxY(mainFrame) + margin, width, height);
    }
    return NSZeroRect;
}

double TGDownloadProgressFraction(NSDictionary *record) {
    long long total = [[record objectForKey:@"total_bytes"] longLongValue];
    long long downloaded = [[record objectForKey:@"downloaded_bytes"] longLongValue];
    if ([[record objectForKey:@"state"] isEqualToString:@"completed"]) { return 1.0; }
    if (total <= 0 || downloaded <= 0) { return 0.0; }
    return MIN(1.0, (double)downloaded / (double)total);
}

@implementation TGDownloadProgressPresentation
@synthesize displayedRecord = _displayedRecord, activeCount = _activeCount, hidden = _hidden;
- (id)init {
    self = [super init];
    if (self) { _knownIdentifiers = [[NSSet alloc] init]; _hidden = YES; }
    return self;
}
- (void)dealloc { [_knownIdentifiers release]; [_displayedRecord release]; [super dealloc]; }
- (void)hide { _hidden = YES; }
- (void)show { if (_displayedRecord) { _hidden = NO; } }
- (BOOL)updateWithRecords:(NSArray *)records {
    NSMutableSet *identifiers = [NSMutableSet set];
    NSDictionary *selected = nil;
    NSDictionary *previous = nil;
    BOOL newActive = NO;
    _activeCount = 0;
    for (id value in records) {
        if (![value isKindOfClass:[NSDictionary class]]) { continue; }
        NSDictionary *record = value;
        NSString *identifier = [record objectForKey:@"identifier"];
        if (![identifier isKindOfClass:[NSString class]] || ![identifier length]) { continue; }
        [identifiers addObject:identifier];
        if ([identifier isEqual:[_displayedRecord objectForKey:@"identifier"]]) { previous = record; }
        NSString *state = [record objectForKey:@"state"];
        if ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"]) {
            _activeCount++;
            if (!selected) { selected = record; }
            if (![_knownIdentifiers containsObject:identifier]) { newActive = YES; }
        }
    }
    [_knownIdentifiers release]; _knownIdentifiers = [identifiers copy];
    NSDictionary *displayed = selected ? selected : previous;
    [_displayedRecord release]; _displayedRecord = [displayed copy];
    if (newActive) { _hidden = NO; }
    if (!_displayedRecord) { _hidden = YES; }
    return newActive;
}
@end

@implementation TGDownloadProgressWindowController
- (id)initWithDownloadManager:(TGDownloadManager *)manager {
    NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 224, 148)
            styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask | NSNonactivatingPanelMask)
            backing:NSBackingStoreBuffered defer:NO] autorelease];
    self = [super initWithWindow:panel];
    if (self) {
        _manager = [manager retain];
        _presentation = [[TGDownloadProgressPresentation alloc] init];
        [panel setTitle:TGLoc(@"downloads.title")];
        [panel setFloatingPanel:YES];
        [panel setHidesOnDeactivate:YES];
        [panel setBecomesKeyOnlyIfNeeded:YES];
        [panel setReleasedWhenClosed:NO];
        [panel setDelegate:self];
        [self buildViews];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadsChanged:)
            name:TGDownloadManagerDidChangeNotification object:manager];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadsChanged:)
            name:NSUserDefaultsDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainWindowChanged:)
            name:NSApplicationDidChangeScreenParametersNotification object:nil];
        [self refresh];
    }
    return self;
}
- (void)invalidate {
    if (_invalidated) { return; }
    _invalidated = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
    [[self window] orderOut:nil];
    _mainWindow = nil; _downloadsTarget = nil; _downloadsAction = NULL;
}
- (void)dealloc {
    [self invalidate];
    [_manager release]; [_presentation release];
    [_nameField release]; [_statusField release]; [_bytesField release];
    [_progressBar release]; [_collapseButton release]; [_downloadsButton release];
    [super dealloc];
}
- (NSTextField *)newLabelWithSize:(CGFloat)fontSize {
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [field setEditable:NO]; [field setSelectable:NO]; [field setBezeled:NO]; [field setDrawsBackground:NO];
    [field setFont:[NSFont systemFontOfSize:fontSize]];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [[[self window] contentView] addSubview:field];
    return field;
}
- (void)buildViews {
    _nameField = [self newLabelWithSize:11.0];
    [_nameField setFont:[NSFont boldSystemFontOfSize:11.0]];
    _statusField = [self newLabelWithSize:10.0];
    _bytesField = [self newLabelWithSize:10.0];
    _progressBar = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    [_progressBar setStyle:NSProgressIndicatorBarStyle];
    [_progressBar setIndeterminate:NO]; [_progressBar setMinValue:0.0]; [_progressBar setMaxValue:1.0];
    [[[self window] contentView] addSubview:_progressBar];
    _collapseButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_collapseButton setBezelStyle:NSRoundedBezelStyle]; [_collapseButton setFont:[NSFont systemFontOfSize:10.0]];
    [_collapseButton setTarget:self]; [_collapseButton setAction:@selector(toggleCollapsed:)];
    [[[self window] contentView] addSubview:_collapseButton];
    _downloadsButton = [[NSButton alloc] initWithFrame:NSZeroRect];
    [_downloadsButton setBezelStyle:NSRoundedBezelStyle]; [_downloadsButton setFont:[NSFont systemFontOfSize:10.0]];
    [_downloadsButton setTitle:TGLoc(@"downloads.title")];
    [_downloadsButton setTarget:self]; [_downloadsButton setAction:@selector(openDownloads:)];
    [[[self window] contentView] addSubview:_downloadsButton];
}
- (void)setDownloadsTarget:(id)target action:(SEL)action { _downloadsTarget = target; _downloadsAction = action; }
- (void)attachToWindow:(NSWindow *)window {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (_mainWindow) { [center removeObserver:self name:nil object:_mainWindow]; }
    _mainWindow = window;
    if (window) {
        [center addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidMoveNotification object:window];
        [center addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidResizeNotification object:window];
        [center addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidBecomeMainNotification object:window];
        [center addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidMiniaturizeNotification object:window];
        [center addObserver:self selector:@selector(mainWindowChanged:) name:NSWindowDidDeminiaturizeNotification object:window];
        [center addObserver:self selector:@selector(mainWindowClosing:) name:NSWindowWillCloseNotification object:window];
    }
    [self placeAndShow];
}
- (void)downloadsChanged:(NSNotification *)notification {
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self refresh]; });
        return;
    }
    [self refresh];
}
- (void)mainWindowChanged:(NSNotification *)notification { (void)notification; [self placeAndShow]; }
- (void)mainWindowClosing:(NSNotification *)notification { (void)notification; [[self window] orderOut:nil]; }
- (void)refresh {
    if (_invalidated) { return; }
    [_presentation updateWithRecords:[_manager itemsSnapshot]];
    [[self window] setTitle:TGLoc(@"downloads.title")];
    [[self window] setBackgroundColor:TGClassicPanelBottomColor()];
    [_nameField setTextColor:TGClassicInkColor()];
    [_statusField setTextColor:TGClassicMutedInkColor()];
    [_bytesField setTextColor:TGClassicMutedInkColor()];
    [_downloadsButton setTitle:TGLoc(@"downloads.title")];
    NSDictionary *record = [_presentation displayedRecord];
    NSString *name = [record objectForKey:@"file_name"];
    [_nameField setStringValue:name ? name : @""];
    [_nameField setToolTip:name];
    NSString *state = [record objectForKey:@"state"];
    NSString *status = state ? TGLoc([@"downloads.state." stringByAppendingString:state]) : @"";
    if ([[record objectForKey:@"reconnecting"] boolValue] && [state isEqualToString:@"downloading"]) {
        status = TGLoc(@"downloads.waitingNetwork");
    }
    if ([_presentation activeCount] > 1) {
        status = [NSString stringWithFormat:@"%@ (%lu)", status, (unsigned long)[_presentation activeCount]];
    }
    [_statusField setStringValue:status]; [_statusField setToolTip:status];
    long long downloaded = MAX(0LL, [[record objectForKey:@"downloaded_bytes"] longLongValue]);
    long long total = MAX(0LL, [[record objectForKey:@"total_bytes"] longLongValue]);
    NSString *bytes = [NSByteCountFormatter stringFromByteCount:downloaded countStyle:NSByteCountFormatterCountStyleFile];
    if (total > 0) {
        bytes = [NSString stringWithFormat:@"%@ / %@", bytes,
            [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile]];
    }
    [_bytesField setStringValue:bytes]; [_bytesField setToolTip:bytes];
    [_progressBar setDoubleValue:TGDownloadProgressFraction(record)];
    [self placeAndShow];
}
- (void)placeAndShow {
    if (_invalidated || !_mainWindow || ![_mainWindow isVisible] || [_mainWindow isMiniaturized] || [_presentation hidden]) {
        [[self window] orderOut:nil]; return;
    }
    NSScreen *screen = [_mainWindow screen];
    if (!screen) { [[self window] orderOut:nil]; return; }
    CGFloat contentHeight = _collapsed ? 94.0 : 148.0;
    CGFloat frameHeight = [[self window] frameRectForContentRect:NSMakeRect(0, 0, 224.0, contentHeight)].size.height;
    NSRect frame = TGDownloadProgressPanelFrame([_mainWindow frame], [screen visibleFrame], frameHeight);
    if (NSIsEmptyRect(frame)) { [[self window] orderOut:nil]; return; }
    if (!NSEqualRects([[self window] frame], frame)) { [[self window] setFrame:frame display:YES]; }
    CGFloat width = NSWidth([[[self window] contentView] bounds]) - 16.0;
    [_nameField setFrame:NSMakeRect(8.0, contentHeight - 25.0, width, 16.0)];
    [_statusField setFrame:NSMakeRect(8.0, contentHeight - 44.0, width, 15.0)];
    [_bytesField setHidden:_collapsed];
    [_bytesField setFrame:NSMakeRect(8.0, contentHeight - 63.0, width, 15.0)];
    [_progressBar setFrame:NSMakeRect(8.0, _collapsed ? 30.0 : 65.0, width, 12.0)];
    [_collapseButton setTitle:TGLoc(_collapsed ? @"downloads.progress.expand" : @"downloads.progress.collapse")];
    [_collapseButton setFrame:NSMakeRect(5.0, 4.0, width + 6.0, 24.0)];
    [_downloadsButton setHidden:_collapsed];
    [_downloadsButton setFrame:NSMakeRect(5.0, 33.0, width + 6.0, 24.0)];
    if ([NSApp isActive] && ![[self window] isVisible]) { [[self window] orderFront:nil]; }
}
- (void)showProgress:(id)sender { (void)sender; [_presentation show]; [self placeAndShow]; }
- (void)toggleCollapsed:(id)sender { (void)sender; _collapsed = !_collapsed; [self placeAndShow]; }
- (void)openDownloads:(id)sender {
    (void)sender;
    if (_downloadsTarget && _downloadsAction) { [NSApp sendAction:_downloadsAction to:_downloadsTarget from:self]; }
}
- (BOOL)windowShouldClose:(id)sender {
    (void)sender; [_presentation hide]; [[self window] orderOut:nil]; return NO;
}
@end
