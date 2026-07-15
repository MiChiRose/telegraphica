#import "TGStorageUsageWindowController.h"

#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"
#import "TGIconDrawing.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#include <math.h>

static NSColor *TGStorageAccentBlue(void) {
    return TGColorFromHex(0x2d9cff);
}

static NSColor *TGStorageCardColor(void) {
    return [NSColor colorWithCalibratedWhite:1.0 alpha:0.92];
}

static NSColor *TGStorageSoftBackgroundColor(void) {
    return TGClassicPanelBottomColor();
}

static NSColor *TGStorageRowSeparatorColor(void) {
    return [TGClassicPanelStrokeColor() colorWithAlphaComponent:0.38];
}

@interface TGStorageCardView : NSView
@end

@implementation TGStorageCardView

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect([self bounds], 0.5, 0.5)
                                                         xRadius:18.0
                                                         yRadius:18.0];
    [TGStorageCardColor() set];
    [path fill];
    [TGClassicPanelStrokeColor() set];
    [path setLineWidth:1.0];
    [path stroke];
}

@end

@interface TGStoragePrimaryButtonCell : NSButtonCell
@end

@implementation TGStoragePrimaryButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 0.5, 0.5);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:10.0 yRadius:10.0];
    NSColor *topColor = highlighted ? TGColorFromHex(0x1988e5) : TGColorFromHex(0x32a8ff);
    NSColor *bottomColor = highlighted ? TGColorFromHex(0x1378cb) : TGColorFromHex(0x168eea);
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[topColor colorWithAlphaComponent:alpha]
                                                          endingColor:[bottomColor colorWithAlphaComponent:alpha]] autorelease];
    [gradient drawInBezierPath:path angle:90.0];
    [[TGColorFromHex(0x0d74c7) colorWithAlphaComponent:alpha] set];
    [path setLineWidth:1.0];
    [path stroke];

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:14.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedWhite:1.0 alpha:alpha], NSForegroundColorAttributeName,
                                nil];
    NSString *title = [self title] ? [self title] : @"";
    NSSize size = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMidX(cellFrame) - (size.width / 2.0),
                                  NSMidY(cellFrame) - (size.height / 2.0) - 1.0,
                                  size.width,
                                  size.height);
    [title drawInRect:titleRect withAttributes:attributes];
}

@end

@interface TGStorageRefreshButtonCell : NSButtonCell
@end

@implementation TGStorageRefreshButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = [self isHighlighted];
    BOOL enabled = [self isEnabled];
    CGFloat alpha = enabled ? 1.0 : 0.48;
    NSRect buttonRect = NSInsetRect(cellFrame, 0.5, 0.5);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:8.0 yRadius:8.0];
    NSColor *topColor = highlighted ? TGColorFromHex(0x315f8f) : TGColorFromHex(0x446f9e);
    NSColor *bottomColor = highlighted ? TGColorFromHex(0x183756) : TGColorFromHex(0x203f62);
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:[topColor colorWithAlphaComponent:alpha]
                                                          endingColor:[bottomColor colorWithAlphaComponent:alpha]] autorelease];
    [gradient drawInBezierPath:buttonPath angle:90.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.34 * alpha] set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setAlignment:NSCenterTextAlignment];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:16.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedWhite:1.0 alpha:0.92 * alpha], NSForegroundColorAttributeName,
                                paragraph, NSParagraphStyleAttributeName,
                                nil];
    NSString *title = @"↻";
    NSSize titleSize = [title sizeWithAttributes:attributes];
    NSRect titleRect = NSMakeRect(NSMinX(buttonRect),
                                  NSMidY(buttonRect) - floor(titleSize.height / 2.0),
                                  NSWidth(buttonRect),
                                  titleSize.height + 2.0);
    [title drawInRect:titleRect withAttributes:attributes];
}

@end

@interface TGStoragePieChartView : NSView

@property (nonatomic, retain) NSArray *segments;
@property (nonatomic, copy) NSString *centerText;

@end

@implementation TGStoragePieChartView

@synthesize segments = _segments;
@synthesize centerText = _centerText;

- (BOOL)isFlipped {
    return NO;
}

- (void)dealloc {
    [_segments release];
    [_centerText release];
    [super dealloc];
}

- (void)drawSegmentFrom:(CGFloat)startAngle
                     to:(CGFloat)endAngle
                 center:(NSPoint)center
            outerRadius:(CGFloat)outerRadius
            innerRadius:(CGFloat)innerRadius
                  color:(NSColor *)color {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path appendBezierPathWithArcWithCenter:center radius:outerRadius startAngle:startAngle endAngle:endAngle clockwise:NO];
    NSPoint innerEnd = NSMakePoint(center.x + (cos(endAngle * M_PI / 180.0) * innerRadius),
                                   center.y + (sin(endAngle * M_PI / 180.0) * innerRadius));
    [path lineToPoint:innerEnd];
    [path appendBezierPathWithArcWithCenter:center radius:innerRadius startAngle:endAngle endAngle:startAngle clockwise:YES];
    [path closePath];
    [color set];
    [path fill];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    CGFloat side = MIN(NSWidth(bounds), NSHeight(bounds)) - 10.0;
    NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    CGFloat outerRadius = side / 2.0;
    CGFloat innerRadius = outerRadius * 0.58;

    NSBezierPath *track = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - outerRadius,
                                                                            center.y - outerRadius,
                                                                            outerRadius * 2.0,
                                                                            outerRadius * 2.0)];
    [[TGClassicPanelStrokeColor() colorWithAlphaComponent:0.22] set];
    [track fill];

    CGFloat total = 0.0;
    for (NSDictionary *segment in self.segments) {
        total += [[segment objectForKey:@"value"] doubleValue];
    }

    if (total <= 0.0) {
        [self drawSegmentFrom:-90.0
                           to:270.0
                       center:center
                  outerRadius:outerRadius
                  innerRadius:innerRadius
                        color:[TGClassicPanelStrokeColor() colorWithAlphaComponent:0.65]];
    } else {
        CGFloat startAngle = -90.0;
        for (NSDictionary *segment in self.segments) {
            CGFloat value = [[segment objectForKey:@"value"] doubleValue];
            if (value <= 0.0) {
                continue;
            }
            CGFloat sweep = MAX(2.0, (value / total) * 360.0);
            NSColor *color = [segment objectForKey:@"color"];
            [self drawSegmentFrom:startAngle
                               to:startAngle + sweep
                           center:center
                      outerRadius:outerRadius
                      innerRadius:innerRadius
                            color:color ? color : TGStorageAccentBlue()];
            startAngle += sweep;
        }
    }

    NSBezierPath *centerPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(center.x - innerRadius + 1.0,
                                                                                 center.y - innerRadius + 1.0,
                                                                                 (innerRadius - 1.0) * 2.0,
                                                                                 (innerRadius - 1.0) * 2.0)];
    [TGStorageSoftBackgroundColor() set];
    [centerPath fill];

    NSString *text = self.centerText ? self.centerText : @"";
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:22.0], NSFontAttributeName,
                                TGClassicInkColor(), NSForegroundColorAttributeName,
                                nil];
    NSSize size = [text sizeWithAttributes:attributes];
    [text drawAtPoint:NSMakePoint(center.x - (size.width / 2.0),
                                  center.y - (size.height / 2.0))
       withAttributes:attributes];
}

@end

@interface TGStorageCategoryRowView : NSView

@property (nonatomic, retain) NSColor *markerColor;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *valueText;
@property (nonatomic, copy) NSString *percentText;
@property (nonatomic, assign) BOOL drawsSeparator;

@end

@implementation TGStorageCategoryRowView

@synthesize markerColor = _markerColor;
@synthesize title = _title;
@synthesize valueText = _valueText;
@synthesize percentText = _percentText;
@synthesize drawsSeparator = _drawsSeparator;

- (BOOL)isFlipped {
    return YES;
}

- (void)dealloc {
    [_markerColor release];
    [_title release];
    [_valueText release];
    [_percentText release];
    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    if (self.drawsSeparator) {
        [TGStorageRowSeparatorColor() set];
        NSRectFill(NSMakeRect(46.0, NSMaxY(bounds) - 1.0, NSWidth(bounds) - 58.0, 1.0));
    }

    NSRect markerRect = NSMakeRect(18.0, floor((NSHeight(bounds) - 18.0) / 2.0), 18.0, 18.0);
    NSBezierPath *markerPath = [NSBezierPath bezierPathWithOvalInRect:markerRect];
    [(self.markerColor ? self.markerColor : TGStorageAccentBlue()) set];
    [markerPath fill];

    NSString *titleText = self.title ? self.title : @"";
    NSString *percentText = self.percentText ? self.percentText : @"";
    NSString *leftText = [percentText length] > 0 ? [NSString stringWithFormat:@"%@ %@", titleText, percentText] : titleText;
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                                     TGClassicInkColor(), NSForegroundColorAttributeName,
                                     nil];
    [leftText drawInRect:NSMakeRect(48.0, 9.0, NSWidth(bounds) - 190.0, 20.0) withAttributes:titleAttributes];

    NSString *value = self.valueText ? self.valueText : @"";
    NSDictionary *valueAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont systemFontOfSize:14.0], NSFontAttributeName,
                                     TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                     nil];
    NSSize valueSize = [value sizeWithAttributes:valueAttributes];
    [value drawInRect:NSMakeRect(NSWidth(bounds) - valueSize.width - 18.0,
                                 9.0,
                                 valueSize.width,
                                 20.0)
       withAttributes:valueAttributes];
}

@end

@interface TGStorageUsageWindowController ()

@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *subtitleField;
@property (nonatomic, retain) TGStoragePieChartView *chartView;
@property (nonatomic, retain) NSArray *categoryRows;
@property (nonatomic, retain) NSTextField *hintField;
@property (nonatomic, retain) NSButton *clearButton;
@property (nonatomic, retain) NSButton *refreshButton;
@property (nonatomic, retain) NSProgressIndicator *progressIndicator;

@end

@implementation TGStorageUsageWindowController

@synthesize client = _client;
@synthesize titleField = _titleField;
@synthesize subtitleField = _subtitleField;
@synthesize chartView = _chartView;
@synthesize categoryRows = _categoryRows;
@synthesize hintField = _hintField;
@synthesize clearButton = _clearButton;
@synthesize refreshButton = _refreshButton;
@synthesize progressIndicator = _progressIndicator;

+ (NSString *)displayStringForBytes:(long long)bytes {
    double value = (double)bytes;
    NSArray *units = [NSArray arrayWithObjects:@"B", @"KB", @"MB", @"GB", nil];
    NSUInteger index = 0;
    while (value >= 1024.0 && index + 1 < [units count]) {
        value = value / 1024.0;
        index++;
    }
    if (index == 0) {
        return [NSString stringWithFormat:@"%lld %@", bytes, [units objectAtIndex:index]];
    }
    return [NSString stringWithFormat:@"%.1f %@", value, [units objectAtIndex:index]];
}

+ (NSString *)percentStringForValue:(long long)value total:(long long)total {
    if (total <= 0 || value <= 0) {
        return @"0%";
    }
    CGFloat percent = ((CGFloat)value / (CGFloat)total) * 100.0;
    if (percent < 1.0) {
        return @"<1%";
    }
    return [NSString stringWithFormat:@"%.0f%%", percent];
}

+ (NSArray *)storageColors {
    return [NSArray arrayWithObjects:
            TGColorFromHex(0xff9900),
            TGColorFromHex(0x35c85a),
            TGColorFromHex(0x3b7df2),
            TGColorFromHex(0x65c7ee),
            nil];
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setBordered:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setDrawsBackground:NO];
    [label setFont:font];
    [label setTextColor:TGClassicInkColor()];
    return label;
}

- (void)stylePrimaryButton:(NSButton *)button {
    TGStoragePrimaryButtonCell *cell = [[[TGStoragePrimaryButtonCell alloc] initTextCell:[button title]] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [cell setAlignment:NSCenterTextAlignment];
    [button setCell:cell];
    [button setBordered:NO];
}

- (void)styleRefreshButton:(NSButton *)button {
    TGStorageRefreshButtonCell *cell = [[[TGStorageRefreshButtonCell alloc] initTextCell:@""] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setBordered:NO];
}

- (void)buildWindow {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 560)
                                                   styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO] autorelease];
    [window setTitle:TGLoc(@"storage.title")];
    [window center];
    [self setWindow:window];

    NSView *contentView = [window contentView];
    [contentView setWantsLayer:YES];
    [[contentView layer] setBackgroundColor:[TGStorageSoftBackgroundColor() CGColor]];

    self.titleField = [self labelWithFrame:NSMakeRect(34, 506, 572, 30)
                                      font:[NSFont boldSystemFontOfSize:20.0]];
    [self.titleField setStringValue:TGLoc(@"storage.title")];
    [self.titleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:self.titleField];

    self.refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(28, 500, 34, 32)] autorelease];
    [self.refreshButton setTitle:@""];
    [self.refreshButton setToolTip:TGLoc(@"storage.refresh")];
    [self styleRefreshButton:self.refreshButton];
    [self.refreshButton setTarget:self];
    [self.refreshButton setAction:@selector(refreshStorageUsage:)];
    [contentView addSubview:self.refreshButton];

    self.chartView = [[[TGStoragePieChartView alloc] initWithFrame:NSMakeRect(220, 292, 200, 200)] autorelease];
    [self.chartView setCenterText:@"—"];
    [contentView addSubview:self.chartView];

    self.subtitleField = [self labelWithFrame:NSMakeRect(54, 260, 532, 26)
                                         font:[NSFont boldSystemFontOfSize:18.0]];
    [self.subtitleField setStringValue:TGLoc(@"storage.loading")];
    [self.subtitleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:self.subtitleField];

    TGStorageCardView *cardView = [[[TGStorageCardView alloc] initWithFrame:NSMakeRect(54, 112, 532, 142)] autorelease];
    [contentView addSubview:cardView];

    NSArray *colors = [[self class] storageColors];
    NSMutableArray *rows = [NSMutableArray array];
    NSArray *titles = [NSArray arrayWithObjects:TGLoc(@"storage.files"), TGLoc(@"storage.database"), TGLoc(@"storage.language"), TGLoc(@"storage.logs"), nil];
    NSUInteger index = 0;
    CGFloat rowHeight = 35.5;
    for (NSString *title in titles) {
        TGStorageCategoryRowView *row = [[[TGStorageCategoryRowView alloc] initWithFrame:NSMakeRect(0.0, rowHeight * index, 532.0, rowHeight)] autorelease];
        [row setTitle:title];
        [row setValueText:@"—"];
        [row setPercentText:@""];
        [row setMarkerColor:[colors objectAtIndex:index]];
        [row setDrawsSeparator:(index < 3)];
        [cardView addSubview:row];
        [rows addObject:row];
        index++;
    }
    self.categoryRows = rows;

    self.clearButton = [[[NSButton alloc] initWithFrame:NSMakeRect(54, 62, 532, 36)] autorelease];
    [self.clearButton setTitle:TGLoc(@"storage.clear")];
    [self stylePrimaryButton:self.clearButton];
    [self.clearButton setTarget:self];
    [self.clearButton setAction:@selector(clearStorageCache:)];
    [contentView addSubview:self.clearButton];

    self.hintField = [self labelWithFrame:NSMakeRect(72, 22, 496, 34)
                                     font:[NSFont systemFontOfSize:12.0]];
    [[self.hintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.hintField setTextColor:TGClassicMutedInkColor()];
    [self.hintField setAlignment:NSCenterTextAlignment];
    [self.hintField setStringValue:TGLoc(@"storage.safeHint")];
    [contentView addSubview:self.hintField];

    self.progressIndicator = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(308, 384, 24, 24)] autorelease];
    [self.progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [self.progressIndicator setDisplayedWhenStopped:NO];
    [contentView addSubview:self.progressIndicator];
}

- (id)initWithClient:(TGTDLibClient *)client {
    self = [super initWithWindow:nil];
    if (self) {
        _client = [client retain];
        [self buildWindow];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_titleField release];
    [_subtitleField release];
    [_chartView release];
    [_categoryRows release];
    [_hintField release];
    [_clearButton release];
    [_refreshButton release];
    [_progressIndicator release];
    [super dealloc];
}

- (void)setBusy:(BOOL)busy {
    [self.clearButton setEnabled:!busy];
    [self.refreshButton setEnabled:!busy];
    if (busy) {
        [self.progressIndicator startAnimation:nil];
    } else {
        [self.progressIndicator stopAnimation:nil];
    }
}

- (NSArray *)segmentsForValues:(NSArray *)values colors:(NSArray *)colors {
    NSMutableArray *segments = [NSMutableArray array];
    NSUInteger count = MIN([values count], [colors count]);
    NSUInteger index = 0;
    while (index < count) {
        [segments addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                             [values objectAtIndex:index], @"value",
                             [colors objectAtIndex:index], @"color",
                             nil]];
        index++;
    }
    return segments;
}

- (void)applyStorageSummary:(NSDictionary *)summary {
    long long total = [[summary objectForKey:@"total_size"] longLongValue];
    long long files = [[summary objectForKey:@"files_size"] longLongValue];
    long long database = [[summary objectForKey:@"database_size"] longLongValue];
    long long language = [[summary objectForKey:@"language_pack_database_size"] longLongValue];
    long long logs = [[summary objectForKey:@"log_size"] longLongValue];

    [self.hintField setStringValue:TGLoc(@"storage.safeHint")];
    NSString *totalText = [[self class] displayStringForBytes:total];
    [self.chartView setCenterText:totalText];
    [self.subtitleField setStringValue:[NSString stringWithFormat:TGLoc(@"storage.total"), totalText]];

    NSArray *values = [NSArray arrayWithObjects:
                       [NSNumber numberWithLongLong:files],
                       [NSNumber numberWithLongLong:database],
                       [NSNumber numberWithLongLong:language],
                       [NSNumber numberWithLongLong:logs],
                       nil];
    NSArray *colors = [[self class] storageColors];
    [self.chartView setSegments:[self segmentsForValues:values colors:colors]];
    [self.chartView setNeedsDisplay:YES];

    NSUInteger index = 0;
    for (TGStorageCategoryRowView *row in self.categoryRows) {
        long long value = [[values objectAtIndex:index] longLongValue];
        [row setValueText:[[self class] displayStringForBytes:value]];
        [row setPercentText:[[self class] percentStringForValue:value total:total]];
        [row setNeedsDisplay:YES];
        index++;
    }
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    [[self window] makeKeyAndOrderFront:sender];
    [self refreshStorageUsage:sender];
}

- (void)refreshStorageUsage:(id)sender {
    (void)sender;
    [self setBusy:YES];
    [self.subtitleField setStringValue:TGLoc(@"storage.loading")];
    [self.chartView setCenterText:@"—"];
    [self.chartView setSegments:nil];
    [self.chartView setNeedsDisplay:YES];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client storageUsageSummaryWithTimeout:8.0 error:&error] retain];
        NSString *errorText = [[error localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if (summary) {
                [self applyStorageSummary:summary];
            } else {
                [self.subtitleField setStringValue:TGLoc(@"storage.unavailable")];
                [self.chartView setCenterText:@"—"];
                [self.hintField setStringValue:([errorText length] > 0 ? errorText : TGLoc(@"settings.sessions.unknownError"))];
                [self.chartView setNeedsDisplay:YES];
            }
            [summary release];
            [errorText release];
            [client release];
        });
        [pool drain];
    });
}

- (void)clearStorageCache:(id)sender {
    (void)sender;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"storage.confirm.title")];
    [alert setInformativeText:TGLoc(@"storage.confirm.message")];
    [alert addButtonWithTitle:TGLoc(@"storage.clear")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSInteger result = [alert runModal];
    if (result != NSAlertFirstButtonReturn) {
        return;
    }

    [self setBusy:YES];
    [self.subtitleField setStringValue:TGLoc(@"storage.clearing")];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client clearDownloadedMediaCacheWithTimeout:15.0 error:&error] retain];
        NSString *errorText = [[error localizedDescription] copy];
        if (summary) {
            [[TGLogger sharedLogger] log:@"Storage cache cleanup completed."];
        } else {
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Storage cache cleanup failed: %@", errorText ? errorText : @"unknown error"]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if (summary) {
                [self applyStorageSummary:summary];
                [self.hintField setStringValue:TGLoc(@"storage.clearDone")];
            } else {
                [self.subtitleField setStringValue:TGLoc(@"storage.clearFailed")];
                [self.hintField setStringValue:([errorText length] > 0 ? errorText : TGLoc(@"settings.sessions.unknownError"))];
            }
            [summary release];
            [errorText release];
            [client release];
        });
        [pool drain];
    });
}

@end
