#import "TGWorkshopModuleCardView.h"
#import "TGWorkshopButtonCell.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../../UI/TGLocalization.h"
#import "../../UI/TGStatusButtonCells.h"
#import "../../UI/TGTheme.h"
#import "../../UI/TGStatusSupport.h"
#include <math.h>

static NSString *TGWorkshopReadableSize(unsigned long long bytes) {
    if (bytes >= (1024ULL * 1024ULL)) {
        return [NSString stringWithFormat:@"%.1f MB", (double)bytes / (1024.0 * 1024.0)];
    }
    if (bytes >= 1024ULL) {
        return [NSString stringWithFormat:@"%.0f KB", (double)bytes / 1024.0];
    }
    return [NSString stringWithFormat:@"%llu B", bytes];
}

static NSTextField *TGWorkshopCardLabel(NSRect frame, NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return field;
}

static NSButton *TGWorkshopCardButton(NSRect frame, NSString *title) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGWorkshopButtonCell *cell = [[[TGWorkshopButtonCell alloc] initTextCell:title] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setBordered:NO];
    return button;
}

@implementation TGWorkshopModuleCardView

@synthesize delegate = _delegate;
@synthesize entry = _entry;

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _nameField = [TGWorkshopCardLabel(NSMakeRect(70, 82, 330, 20), [NSFont boldSystemFontOfSize:14.0]) retain];
        [self addSubview:_nameField];

        _descriptionField = [TGWorkshopCardLabel(NSMakeRect(70, 50, 430, 32), [NSFont systemFontOfSize:11.0]) retain];
        [[_descriptionField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [[_descriptionField cell] setWraps:YES];
        [self addSubview:_descriptionField];

        _detailsField = [TGWorkshopCardLabel(NSMakeRect(70, 28, 430, 17), [NSFont systemFontOfSize:10.0]) retain];
        [self addSubview:_detailsField];

        _statusField = [TGWorkshopCardLabel(NSMakeRect(70, 8, 430, 17), [NSFont systemFontOfSize:10.0]) retain];
        [self addSubview:_statusField];

        _progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(70, 7, 280, 12)];
        [_progressIndicator setIndeterminate:NO];
        [_progressIndicator setMinValue:0.0];
        [_progressIndicator setMaxValue:1.0];
        [_progressIndicator setDisplayedWhenStopped:YES];
        [_progressIndicator setHidden:YES];
        [self addSubview:_progressIndicator];

        _primaryButton = [TGWorkshopCardButton(NSMakeRect(510, 56, 112, 42), @"") retain];
        [_primaryButton setAutoresizingMask:NSViewMinXMargin];
        [_primaryButton setTarget:self];
        [_primaryButton setAction:@selector(primaryAction:)];
        [self addSubview:_primaryButton];

        _removeButton = [TGWorkshopCardButton(NSMakeRect(510, 12, 112, 36), @"") retain];
        [_removeButton setAutoresizingMask:NSViewMinXMargin];
        [_removeButton setTarget:self];
        [_removeButton setAction:@selector(removeAction:)];
        [self addSubview:_removeButton];
    }
    return self;
}

- (BOOL)isFlipped {
    return NO;
}

- (void)drawModuleIconInRect:(NSRect)rect {
    NSString *identifier = [_entry moduleIdentifier];
    NSColor *accent = TGClassicSelectedRowColor();
    NSColor *ink = TGClassicSelectedRowTextColor();
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:9.0 yRadius:9.0];
    [accent set];
    [background fill];
    [TGClassicPanelStrokeColor() set];
    [background setLineWidth:1.0];
    [background stroke];

    [ink set];
    if ([identifier rangeOfString:@"mine" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSBezierPath *mine = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(rect, 13.0, 13.0)];
        [mine fill];
        NSInteger ray = 0;
        for (ray = 0; ray < 8; ray++) {
            CGFloat angle = ((CGFloat)ray / 8.0) * (CGFloat)M_PI * 2.0;
            NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
            NSPoint inner = NSMakePoint(center.x + cos(angle) * 16.0, center.y + sin(angle) * 16.0);
            NSPoint outer = NSMakePoint(center.x + cos(angle) * 23.0, center.y + sin(angle) * 23.0);
            NSBezierPath *line = [NSBezierPath bezierPath];
            [line setLineWidth:3.0];
            [line moveToPoint:inner];
            [line lineToPoint:outer];
            [line stroke];
        }
    } else if ([identifier rangeOfString:@"solitaire" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSRect backRect = NSMakeRect(NSMinX(rect) + 13.0, NSMinY(rect) + 10.0, 28.0, 38.0);
        NSRect frontRect = NSMakeRect(NSMinX(rect) + 23.0, NSMinY(rect) + 16.0, 28.0, 38.0);
        [[NSBezierPath bezierPathWithRoundedRect:backRect xRadius:3.0 yRadius:3.0] stroke];
        [[NSBezierPath bezierPathWithRoundedRect:frontRect xRadius:3.0 yRadius:3.0] fill];
    } else if ([identifier rangeOfString:@"check" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        NSInteger row = 0;
        NSInteger column = 0;
        CGFloat side = 9.0;
        for (row = 0; row < 4; row++) {
            for (column = 0; column < 4; column++) {
                if (((row + column) % 2) == 0) {
                    NSRect square = NSMakeRect(NSMinX(rect) + 14.0 + column * side,
                                               NSMinY(rect) + 14.0 + row * side,
                                               side,
                                               side);
                    NSRectFill(square);
                }
            }
        }
    } else {
        NSRect board = NSMakeRect(NSMinX(rect) + 13.0, NSMinY(rect) + 13.0, 38.0, 38.0);
        [[NSBezierPath bezierPathWithRoundedRect:board xRadius:3.0 yRadius:3.0] stroke];
        NSBezierPath *lines = [NSBezierPath bezierPath];
        [lines setLineWidth:2.0];
        [lines moveToPoint:NSMakePoint(NSMinX(board) + 12.7, NSMinY(board))];
        [lines lineToPoint:NSMakePoint(NSMinX(board) + 12.7, NSMaxY(board))];
        [lines moveToPoint:NSMakePoint(NSMinX(board) + 25.3, NSMinY(board))];
        [lines lineToPoint:NSMakePoint(NSMinX(board) + 25.3, NSMaxY(board))];
        [lines moveToPoint:NSMakePoint(NSMinX(board), NSMinY(board) + 12.7)];
        [lines lineToPoint:NSMakePoint(NSMaxX(board), NSMinY(board) + 12.7)];
        [lines moveToPoint:NSMakePoint(NSMinX(board), NSMinY(board) + 25.3)];
        [lines lineToPoint:NSMakePoint(NSMaxX(board), NSMinY(board) + 25.3)];
        [lines stroke];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect cardRect = NSInsetRect([self bounds], 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:8.0 yRadius:8.0];
    TGThemeDrawGroupedCardInPath(cardPath, cardRect, [self isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];
    [self drawModuleIconInRect:NSMakeRect(10, NSHeight([self bounds]) - 68, 54, 54)];
}

- (void)setEntry:(TGWorkshopCatalogEntry *)entry {
    if (_entry == entry) return;
    [_entry release];
    _entry = [entry retain];
    [self refreshLocalization];
    [self setNeedsDisplay:YES];
}

- (void)configureWithInstalledRecord:(NSDictionary *)installedRecord
                                busy:(BOOL)busy
                            progress:(double)progress
                        errorMessage:(NSString *)errorMessage {
    [_installedRecord release];
    _installedRecord = [installedRecord retain];
    _busy = busy;
    _progress = progress;
    [_errorMessage release];
    _errorMessage = [errorMessage copy];
    [self refreshLocalization];
}

- (void)refreshTheme {
    [_nameField setTextColor:TGClassicCardInkColor()];
    [_descriptionField setTextColor:TGClassicCardMutedInkColor()];
    [_detailsField setTextColor:TGClassicCardMutedInkColor()];
    [_statusField setTextColor:([_errorMessage length] > 0
                                ? [NSColor colorWithCalibratedRed:0.78 green:0.16 blue:0.13 alpha:1.0]
                                : TGClassicCardMutedInkColor())];
    [self setNeedsDisplay:YES];
    [_primaryButton setNeedsDisplay:YES];
    [_removeButton setNeedsDisplay:YES];
}

- (void)refreshLocalization {
    if (!_entry) return;
    NSString *language = TGLanguageCode();
    NSString *name = [_entry localizedNameForLanguageCode:language];
    NSString *description = [_entry localizedDescriptionForLanguageCode:language];
    [_nameField setStringValue:name ? name : [_entry name]];
    [_descriptionField setStringValue:description ? description : @""];
    [_detailsField setStringValue:[NSString stringWithFormat:@"%@ %@  •  %@  •  OS X %@+  •  x86_64",
                                   TGLoc(@"workshop.version"),
                                   [_entry version],
                                   TGWorkshopReadableSize([_entry archiveSize]),
                                   [_entry minimumOSVersion]]];

    NSString *installedVersion = [_installedRecord objectForKey:@"active_version"];
    BOOL installed = ([installedVersion length] > 0 && ![[_installedRecord objectForKey:@"pending_removal"] boolValue]);
    BOOL updateAvailable = installed && TGVersionStringIsNewer([_entry version], installedVersion);
    TGWorkshopModuleCardAction action = TGWorkshopModuleCardActionInstall;
    NSString *primaryTitle = TGLoc(@"workshop.install");
    if ([_errorMessage length] > 0) {
        action = TGWorkshopModuleCardActionRetry;
        primaryTitle = TGLoc(@"workshop.retry");
        [_statusField setStringValue:_errorMessage];
    } else if (_busy) {
        primaryTitle = TGLoc(@"workshop.installing");
        [_statusField setStringValue:@""];
    } else if (updateAvailable) {
        action = TGWorkshopModuleCardActionUpdate;
        primaryTitle = TGLoc(@"workshop.update");
        [_statusField setStringValue:[NSString stringWithFormat:@"%@ %@",
                                      TGLoc(@"workshop.installedVersion"),
                                      installedVersion]];
    } else if (installed) {
        action = TGWorkshopModuleCardActionOpen;
        primaryTitle = TGLoc(@"workshop.open");
        [_statusField setStringValue:[NSString stringWithFormat:@"%@ %@",
                                      TGLoc(@"workshop.installedVersion"),
                                      installedVersion]];
    } else {
        [_statusField setStringValue:TGLoc(@"workshop.notInstalled")];
    }

    [_primaryButton setTag:action];
    [_primaryButton setTitle:primaryTitle];
    [_primaryButton setToolTip:primaryTitle];
    [_primaryButton setEnabled:!_busy];
    [_removeButton setTitle:TGLoc(@"workshop.remove")];
    [_removeButton setToolTip:TGLoc(@"workshop.remove")];
    [_removeButton setHidden:!installed];
    [_removeButton setEnabled:!_busy];
    [_progressIndicator setHidden:!_busy];
    [_statusField setHidden:_busy];
    if (_busy) {
        [_progressIndicator setDoubleValue:MAX(0.0, MIN(1.0, _progress))];
    }
    [self refreshTheme];
}

- (void)primaryAction:(id)sender {
    (void)sender;
    if ([_delegate respondsToSelector:@selector(workshopModuleCardView:requestedAction:entry:)]) {
        [_delegate workshopModuleCardView:self
                          requestedAction:(TGWorkshopModuleCardAction)[_primaryButton tag]
                                    entry:_entry];
    }
}

- (void)removeAction:(id)sender {
    (void)sender;
    if ([_delegate respondsToSelector:@selector(workshopModuleCardView:requestedAction:entry:)]) {
        [_delegate workshopModuleCardView:self requestedAction:TGWorkshopModuleCardActionRemove entry:_entry];
    }
}

- (void)dealloc {
    [_entry release];
    [_installedRecord release];
    [_nameField release];
    [_descriptionField release];
    [_detailsField release];
    [_statusField release];
    [_progressIndicator release];
    [_primaryButton release];
    [_removeButton release];
    [_errorMessage release];
    [super dealloc];
}

@end
