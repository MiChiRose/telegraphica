#import "TGDiagnosticCenterViewController.h"
#import "../Common/TGGameUI.h"

@class TGDiagnosticCenterViewController;
@interface TGDiagnosticCenterRootView : TGWorkshopGameSurfaceView {
    TGDiagnosticCenterViewController *_layoutOwner;
}
@property(nonatomic, assign) TGDiagnosticCenterViewController *layoutOwner;
@end

@interface TGDiagnosticCardView : NSView
@end

@implementation TGDiagnosticCardView
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = NSInsetRect([self bounds], 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:8.0 yRadius:8.0];
    [[NSColor colorWithCalibratedRed:0.055 green:0.25 blue:0.15 alpha:0.88] setFill];
    [path fill];
    [TGWorkshopGoldColor() setStroke];
    [path setLineWidth:1.0];
    [path stroke];
}
@end

static NSString *TGDiagnosticBytesString(long long bytes) {
    double value = (double)MAX(0LL, bytes);
    NSArray *units = [NSArray arrayWithObjects:@"B", @"KB", @"MB", @"GB", nil];
    NSUInteger unitIndex = 0;
    while (value >= 1024.0 && unitIndex + 1 < [units count]) {
        value /= 1024.0;
        unitIndex++;
    }
    return [NSString stringWithFormat:(unitIndex == 0 ? @"%.0f %@" : @"%.1f %@"),
            value, [units objectAtIndex:unitIndex]];
}

static NSTextField *TGDiagnosticLabel(NSFont *font, NSColor *color, NSTextAlignment alignment) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [field setEditable:NO];
    [field setSelectable:YES];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:color];
    [field setAlignment:alignment];
    [[field cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [[field cell] setWraps:YES];
    return field;
}

@interface TGDiagnosticCenterViewController ()
- (void)layoutDiagnostics;
- (void)applySnapshot:(NSDictionary *)snapshot;
- (void)refreshPressed:(id)sender;
@end

@implementation TGDiagnosticCenterRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutDiagnostics];
}
@end

@implementation TGDiagnosticCenterViewController

- (id)initWithHostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _hostContext = [hostContext retain];
    return self;
}

- (void)loadView {
    TGDiagnosticCenterRootView *root = [[[TGDiagnosticCenterRootView alloc] initWithFrame:NSMakeRect(0, 0, 720, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGDiagnosticLabel([_hostContext interfaceFontOfSize:22.0 bold:YES],
                                     TGWorkshopCreamColor(), NSCenterTextAlignment) retain];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"diagnosticCenter.title"
                                                           fallback:@"Diagnostic Center"]];
    [root addSubview:_titleField];

    _summaryField = [TGDiagnosticLabel([_hostContext interfaceFontOfSize:12.0 bold:NO],
                                       TGWorkshopMutedCreamColor(), NSCenterTextAlignment) retain];
    [_summaryField setStringValue:[_hostContext localizedStringForKey:@"diagnosticCenter.checking"
                                                              fallback:@"Checking application state..."]];
    [root addSubview:_summaryField];

    NSArray *titles = [NSArray arrayWithObjects:
                       [_hostContext localizedStringForKey:@"diagnosticCenter.telegram" fallback:@"Telegram core"],
                       [_hostContext localizedStringForKey:@"diagnosticCenter.storage" fallback:@"Cache and storage"],
                       [_hostContext localizedStringForKey:@"diagnosticCenter.application" fallback:@"Application"],
                       nil];
    NSMutableArray *titleFields = [NSMutableArray array];
    NSMutableArray *valueFields = [NSMutableArray array];
    NSMutableArray *cards = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < 3; index++) {
        TGDiagnosticCardView *card = [[[TGDiagnosticCardView alloc] initWithFrame:NSZeroRect] autorelease];
        [root addSubview:card];
        [cards addObject:card];
        NSTextField *title = TGDiagnosticLabel([_hostContext interfaceFontOfSize:14.0 bold:YES],
                                               TGWorkshopGoldColor(), NSLeftTextAlignment);
        [title setStringValue:[titles objectAtIndex:index]];
        [card addSubview:title];
        [titleFields addObject:title];
        NSTextField *value = TGDiagnosticLabel([_hostContext interfaceFontOfSize:12.0 bold:NO],
                                               TGWorkshopCreamColor(), NSLeftTextAlignment);
        [value setStringValue:@"-"];
        [card addSubview:value];
        [valueFields addObject:value];
    }
    _telegramTitleField = [[titleFields objectAtIndex:0] retain];
    _storageTitleField = [[titleFields objectAtIndex:1] retain];
    _applicationTitleField = [[titleFields objectAtIndex:2] retain];
    _telegramValueField = [[valueFields objectAtIndex:0] retain];
    _storageValueField = [[valueFields objectAtIndex:1] retain];
    _applicationValueField = [[valueFields objectAtIndex:2] retain];
    _cardViews = [cards copy];

    _refreshButton = [TGGameThemedButton(NSZeroRect,
                                          [_hostContext localizedStringForKey:@"diagnosticCenter.refresh"
                                                                      fallback:@"Run check"],
                                          @"refresh", _hostContext) retain];
    [_refreshButton setTarget:self];
    [_refreshButton setAction:@selector(refreshPressed:)];
    [root addSubview:_refreshButton];

    _spinner = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    [_spinner setStyle:NSProgressIndicatorSpinningStyle];
    [_spinner setDisplayedWhenStopped:NO];
    [root addSubview:_spinner];

    [self layoutDiagnostics];
    [self refreshDiagnostics];
}

- (void)layoutDiagnostics {
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(650.0, width - 36.0);
    CGFloat x = floor((width - contentWidth) / 2.0);
    [_titleField setFrame:NSMakeRect(x, height - 48.0, contentWidth, 30.0)];
    [_summaryField setFrame:NSMakeRect(x, height - 75.0, contentWidth, 22.0)];

    CGFloat cardHeight = 100.0;
    CGFloat cardGap = 12.0;
    CGFloat cardY = height - 190.0;
    NSUInteger index = 0;
    for (index = 0; index < 3; index++) {
        NSView *card = [_cardViews objectAtIndex:index];
        [card setFrame:NSMakeRect(x, cardY - index * (cardHeight + cardGap), contentWidth, cardHeight)];
        NSArray *subviews = [card subviews];
        if ([subviews count] >= 2) {
            [[subviews objectAtIndex:0] setFrame:NSMakeRect(18.0, 68.0, contentWidth - 36.0, 20.0)];
            [[subviews objectAtIndex:1] setFrame:NSMakeRect(18.0, 14.0, contentWidth - 36.0, 50.0)];
        }
    }
    [_refreshButton setFrame:NSMakeRect(floor((width - 190.0) / 2.0), 18.0, 190.0, 34.0)];
    [_spinner setFrame:NSMakeRect(NSMaxX([_refreshButton frame]) + 10.0, 25.0, 18.0, 18.0)];
}

- (void)refreshPressed:(id)sender {
    (void)sender;
    [self refreshDiagnostics];
}

- (void)refreshDiagnostics {
    if (_refreshing || !_refreshButton) return;
    _refreshing = YES;
    [_refreshButton setEnabled:NO];
    [_spinner startAnimation:nil];
    [_summaryField setStringValue:[_hostContext localizedStringForKey:@"diagnosticCenter.checking"
                                                              fallback:@"Checking application state..."]];
    id<TGWorkshopHostContext> context = [_hostContext retain];
    __block TGDiagnosticCenterViewController *blockSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *snapshot = [[context diagnosticSnapshot] retain];
        dispatch_async(dispatch_get_main_queue(), ^{
            [blockSelf applySnapshot:snapshot];
            [snapshot release];
            [context release];
        });
        [pool drain];
    });
}

- (void)applySnapshot:(NSDictionary *)snapshot {
    NSString *auth = [snapshot objectForKey:@"authorization_state"];
    BOOL loaded = [[snapshot objectForKey:@"tdlib_loaded"] boolValue];
    NSString *receiver = [snapshot objectForKey:@"receiver_status"];
    BOOL ready = loaded && [auth isEqualToString:@"ready"];
    [_telegramValueField setStringValue:[NSString stringWithFormat:@"%@: %@\nTDLib: %@\n%@",
        [_hostContext localizedStringForKey:@"diagnosticCenter.connection" fallback:@"Connection"],
        (ready
         ? [_hostContext localizedStringForKey:@"diagnosticCenter.ok" fallback:@"OK"]
         : [_hostContext localizedStringForKey:@"diagnosticCenter.problem" fallback:@"Needs attention"]),
        (loaded ? @"loaded" : @"not loaded"),
        ([receiver length] > 0 ? receiver : @"-")]];

    NSDictionary *storage = [snapshot objectForKey:@"storage"];
    if ([storage isKindOfClass:[NSDictionary class]]) {
        [_storageValueField setStringValue:[NSString stringWithFormat:@"%@: %@\nDatabase: %@  •  Logs: %@",
            [_hostContext localizedStringForKey:@"diagnosticCenter.total" fallback:@"Total"],
            TGDiagnosticBytesString([[storage objectForKey:@"total_size"] longLongValue]),
            TGDiagnosticBytesString([[storage objectForKey:@"database_size"] longLongValue]),
            TGDiagnosticBytesString([[storage objectForKey:@"log_size"] longLongValue])]];
    } else {
        NSString *storageError = [snapshot objectForKey:@"storage_error"];
        [_storageValueField setStringValue:([storageError length] > 0
            ? storageError
            : [_hostContext localizedStringForKey:@"diagnosticCenter.storageUnavailable"
                                          fallback:@"Storage information is unavailable."])];
    }

    [_applicationValueField setStringValue:[NSString stringWithFormat:@"Telegraphica %@ (%@)\n%@  •  %@\nSection: %@",
        [snapshot objectForKey:@"app_version"] ?: @"-",
        [snapshot objectForKey:@"app_build"] ?: @"-",
        [snapshot objectForKey:@"os_version"] ?: @"-",
        [snapshot objectForKey:@"architecture"] ?: @"-",
        [snapshot objectForKey:@"active_section"] ?: @"-"]];
    [_summaryField setStringValue:(ready
        ? [_hostContext localizedStringForKey:@"diagnosticCenter.allGood"
                                      fallback:@"Telegram core is connected and the application is responsive."]
        : [_hostContext localizedStringForKey:@"diagnosticCenter.review"
                                      fallback:@"One or more checks need attention."])];
    _refreshing = NO;
    [_spinner stopAnimation:nil];
    [_refreshButton setEnabled:YES];
}

- (void)dealloc {
    [_hostContext release];
    [_titleField release];
    [_summaryField release];
    [_telegramTitleField release];
    [_telegramValueField release];
    [_storageTitleField release];
    [_storageValueField release];
    [_applicationTitleField release];
    [_applicationValueField release];
    [_cardViews release];
    [_refreshButton release];
    [_spinner release];
    [super dealloc];
}

@end
