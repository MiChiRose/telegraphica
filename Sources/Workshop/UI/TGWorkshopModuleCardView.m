#import "TGWorkshopModuleCardView.h"
#import "TGWorkshopButtonCell.h"
#import "TGWorkshopSurfaceView.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../../UI/TGLocalization.h"
#import "../../UI/TGIconAssets.h"
#import "../../UI/TGStatusButtonCells.h"
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

static NSString *TGWorkshopIconNameForModuleIdentifier(NSString *identifier) {
    if ([identifier hasSuffix:@".solitaire"]) return @"solitaire";
    if ([identifier hasSuffix:@".checkers"]) return @"checkers";
    if ([identifier hasSuffix:@".minesweeper"]) return @"minesweeper";
    if ([identifier hasSuffix:@".tictactoe"]) return @"tictactoe";
    if ([identifier hasSuffix:@".pacman"] || [identifier hasSuffix:@".mazechase"]) return @"pac-man";
    return nil;
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

        _successImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(70, 5, 18, 18)];
        [_successImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [_successImageView setHidden:YES];
        [self addSubview:_successImageView];

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
    NSString *name = [_entry localizedNameForLanguageCode:TGLanguageCode()];
    NSString *initial = [name length] > 0 ? [name substringToIndex:1] : @"";
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:9.0 yRadius:9.0];
    [TGWorkshopBurgundyColor() set];
    [background fill];
    [TGWorkshopGoldColor() setStroke];
    [background setLineWidth:1.0];
    [background stroke];
    NSString *iconName = TGWorkshopIconNameForModuleIdentifier([_entry moduleIdentifier]);
    NSImage *icon = TGTemplateIconAssetImage(iconName,
                                             NSMakeSize(40.0, 40.0),
                                             TGWorkshopCreamColor(),
                                             1.0);
    if (icon) {
        NSRect iconRect = NSMakeRect(NSMidX(rect) - 20.0, NSMidY(rect) - 20.0, 40.0, 40.0);
        if ([iconName isEqualToString:@"minesweeper"]) {
            NSInteger offsetX;
            NSInteger offsetY;
            for (offsetY = -1; offsetY <= 1; offsetY++) {
                for (offsetX = -1; offsetX <= 1; offsetX++) {
                    [icon drawInRect:NSOffsetRect(iconRect, offsetX * 0.55, offsetY * 0.55)
                           fromRect:NSZeroRect
                          operation:NSCompositeSourceOver
                           fraction:0.72
                     respectFlipped:NO
                              hints:nil];
                }
            }
        } else {
            [icon drawInRect:iconRect
                    fromRect:NSZeroRect
                   operation:NSCompositeSourceOver
                    fraction:1.0
              respectFlipped:NO
                       hints:nil];
        }
        return;
    }
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:25.0], NSFontAttributeName,
                                TGWorkshopCreamColor(), NSForegroundColorAttributeName,
                                nil];
    NSSize size = [initial sizeWithAttributes:attributes];
    [initial drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2.0,
                                     NSMidY(rect) - size.height / 2.0)
          withAttributes:attributes];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect cardRect = NSInsetRect([self bounds], 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect xRadius:8.0 yRadius:8.0];
    NSGradient *gradient = [[[NSGradient alloc]
                             initWithStartingColor:[NSColor colorWithCalibratedRed:0.035 green:0.27 blue:0.18 alpha:0.98]
                             endingColor:TGWorkshopDeepGreenColor()] autorelease];
    [gradient drawInBezierPath:cardPath angle:90.0];
    [[TGWorkshopGoldColor() colorWithAlphaComponent:0.75] setStroke];
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
    if (busy) _showingSuccess = NO;
    [_errorMessage release];
    _errorMessage = [errorMessage copy];
    [self refreshLocalization];
}

- (void)refreshTheme {
    [_nameField setTextColor:TGWorkshopCreamColor()];
    [_descriptionField setTextColor:TGWorkshopMutedCreamColor()];
    [_detailsField setTextColor:TGWorkshopMutedCreamColor()];
    [_statusField setTextColor:([_errorMessage length] > 0
                                ? [NSColor colorWithCalibratedRed:0.78 green:0.16 blue:0.13 alpha:1.0]
                                : TGWorkshopMutedCreamColor())];
    [_successImageView setImage:TGTemplateIconAssetImage(@"done-mini",
                                                         NSMakeSize(18.0, 18.0),
                                                         TGWorkshopGoldColor(),
                                                         1.0)];
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
    if (_showingSuccess) {
        primaryTitle = TGLoc(@"workshop.installed");
        [_statusField setStringValue:TGLoc(@"workshop.installComplete")];
    } else if ([_errorMessage length] > 0) {
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
    [_primaryButton setEnabled:(!_busy && !_showingSuccess)];
    [_removeButton setTitle:TGLoc(@"workshop.remove")];
    [_removeButton setToolTip:TGLoc(@"workshop.remove")];
    [_removeButton setHidden:(!installed || _showingSuccess)];
    [_removeButton setEnabled:(!_busy && !_showingSuccess)];
    [_progressIndicator setHidden:(!_busy || _showingSuccess)];
    [_statusField setHidden:(_busy && !_showingSuccess)];
    [_successImageView setHidden:!_showingSuccess];
    [_statusField setFrame:NSMakeRect(_showingSuccess ? 94.0 : 70.0, 8.0,
                                      _showingSuccess ? 406.0 : 430.0, 17.0)];
    if (_busy) {
        [_progressIndicator setDoubleValue:MAX(0.0, MIN(1.0, _progress))];
    }
    [self refreshTheme];
}

- (void)updateProgress:(double)progress {
    _progress = MAX(0.0, MIN(1.0, progress));
    [_progressIndicator setDoubleValue:_progress];
}

- (void)showInstallSuccess {
    _busy = NO;
    _progress = 1.0;
    _showingSuccess = YES;
    [self refreshLocalization];
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
    [_successImageView release];
    [_primaryButton release];
    [_removeButton release];
    [_errorMessage release];
    [super dealloc];
}

@end
