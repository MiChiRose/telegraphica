#import "TGWorkshopViewController.h"
#import "TGWorkshopButtonCell.h"
#import "../Catalog/TGWorkshopCatalog.h"
#import "../Catalog/TGWorkshopCatalogEntry.h"
#import "../../UI/TGLocalization.h"
#import "../../UI/TGStatusButtonCells.h"
#import "../../UI/TGStatusViewCells.h"
#import "../../UI/TGTheme.h"

static NSString * const TGWorkshopViewModeAvailable = @"available";
static NSString * const TGWorkshopViewModeInstalled = @"installed";
static NSString * const TGWorkshopViewModeUpdates = @"updates";

@interface TGWorkshopContentDocumentView : NSView
@end

@implementation TGWorkshopContentDocumentView
- (BOOL)isFlipped { return YES; }
@end

static NSTextField *TGWorkshopViewLabel(NSRect frame, NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return field;
}

static NSButton *TGWorkshopViewButton(NSRect frame, NSString *title, NSInteger tag) {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGWorkshopSegmentButtonCell *cell = [[[TGWorkshopSegmentButtonCell alloc] initTextCell:title] autorelease];
    [cell setButtonType:NSToggleButton];
    [button setCell:cell];
    [button setTitle:title];
    [button setTag:tag];
    [button setBordered:NO];
    return button;
}

@implementation TGWorkshopViewController

@synthesize delegate = _delegate;
@synthesize coordinator = _coordinator;

- (id)initWithCoordinator:(TGWorkshopCoordinator *)coordinator {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _coordinator = [coordinator retain];
        [_coordinator setDelegate:self];
        _selectedMode = [TGWorkshopViewModeAvailable copy];
        _progressByIdentifier = [[NSMutableDictionary alloc] init];
        _errorsByIdentifier = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)loadView {
    TGPanelView *rootView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(0, 0, 720, 560)] autorelease];
    [rootView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self setView:rootView];

    _backButton = [TGWorkshopViewButton(NSMakeRect(12, 8, 66, 30), @"‹", 0) retain];
    [_backButton setAutoresizingMask:NSViewMinYMargin];
    [[_backButton cell] setButtonType:NSMomentaryPushInButton];
    [_backButton setTarget:self];
    [_backButton setAction:@selector(backAction:)];
    [rootView addSubview:_backButton];

    _titleField = [TGWorkshopViewLabel(NSMakeRect(88, 10, 350, 24), [NSFont boldSystemFontOfSize:14.0]) retain];
    [_titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [_titleField setTextColor:TGClassicHeaderTextColor(1.0)];
    [rootView addSubview:_titleField];

    NSArray *modeIdentifiers = [NSArray arrayWithObjects:
                                TGWorkshopViewModeAvailable,
                                TGWorkshopViewModeInstalled,
                                TGWorkshopViewModeUpdates,
                                nil];
    NSMutableArray *modeButtons = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [modeIdentifiers count]; index++) {
        NSButton *button = TGWorkshopViewButton(NSMakeRect(22 + index * 150, 56, 140, 38), @"", (NSInteger)index);
        [button setTarget:self];
        [button setAction:@selector(modeChanged:)];
        [button setAutoresizingMask:NSViewMinYMargin];
        [rootView addSubview:button];
        [modeButtons addObject:button];
    }
    _modeButtons = [modeButtons copy];

    _categoryField = [TGWorkshopViewLabel(NSMakeRect(24, 104, 300, 20), [NSFont boldSystemFontOfSize:12.0]) retain];
    [_categoryField setAutoresizingMask:NSViewMinYMargin];
    [rootView addSubview:_categoryField];

    _statusField = [TGWorkshopViewLabel(NSMakeRect(320, 104, 370, 20), [NSFont systemFontOfSize:10.0]) retain];
    [_statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [_statusField setAlignment:NSRightTextAlignment];
    [rootView addSubview:_statusField];

    _scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(18, 132, 684, 408)];
    [_scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_scrollView setBorderType:NSNoBorder];
    [_scrollView setDrawsBackground:NO];
    [_scrollView setHasVerticalScroller:YES];
    [_scrollView setHasHorizontalScroller:NO];
    [_scrollView setAutohidesScrollers:YES];
    _contentView = [[TGWorkshopContentDocumentView alloc] initWithFrame:NSMakeRect(0, 0, 650, 420)];
    [_scrollView setDocumentView:_contentView];
    [rootView addSubview:_scrollView];

    _moduleContainerView = [[NSView alloc] initWithFrame:NSMakeRect(12, 46, 696, 504)];
    [_moduleContainerView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_moduleContainerView setHidden:YES];
    [rootView addSubview:_moduleContainerView];

    [self refreshLocalization];
    [self refreshTheme];
    [self layoutWorkshopView];
}

- (void)layoutWorkshopView {
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    [_backButton setFrame:NSMakeRect(12, height - 36, 66, 28)];
    [_titleField setFrame:NSMakeRect(88, height - 33, width - 104, 22)];
    NSUInteger index = 0;
    CGFloat tabsWidth = MIN(470.0, width - 40.0);
    CGFloat gap = 8.0;
    CGFloat buttonWidth = floor((tabsWidth - gap * 2.0) / 3.0);
    for (index = 0; index < [_modeButtons count]; index++) {
        NSButton *button = [_modeButtons objectAtIndex:index];
        [button setFrame:NSMakeRect(20 + index * (buttonWidth + gap),
                                    height - 84,
                                    buttonWidth,
                                    38)];
    }
    [_categoryField setFrame:NSMakeRect(24, height - 112, 280, 20)];
    [_statusField setFrame:NSMakeRect(310, height - 112, MAX(120.0, width - 334.0), 20)];
    [_scrollView setFrame:NSMakeRect(18, 18, width - 36, MAX(120.0, height - 142.0))];
    [_moduleContainerView setFrame:NSMakeRect(12, 12, width - 24, height - 56)];
    if (_activeModuleViewController) {
        [[_activeModuleViewController view] setFrame:[_moduleContainerView bounds]];
    }
}

- (void)startIfNeeded {
    if (_started) return;
    _started = YES;
    [_coordinator start];
    [self rebuildCards];
}

- (void)refreshLocalization {
    if (!_titleField) return;
    [_titleField setStringValue:TGLoc(@"workshop.title")];
    NSArray *titles = [NSArray arrayWithObjects:
                       TGLoc(@"workshop.available"),
                       TGLoc(@"workshop.installed"),
                       TGLoc(@"workshop.updates"),
                       nil];
    NSUInteger index = 0;
    for (index = 0; index < [_modeButtons count]; index++) {
        NSButton *button = [_modeButtons objectAtIndex:index];
        [button setTitle:[titles objectAtIndex:index]];
        [button setToolTip:[titles objectAtIndex:index]];
    }
    [_categoryField setStringValue:TGLoc(@"workshop.games")];
    [_backButton setToolTip:TGLoc(@"back")];
    [self rebuildCards];
}

- (void)refreshTheme {
    if (!_titleField) return;
    [_titleField setTextColor:TGClassicHeaderTextColor(1.0)];
    [_categoryField setTextColor:TGClassicInkColor()];
    [_statusField setTextColor:TGClassicMutedInkColor()];
    [[self view] setNeedsDisplay:YES];
    NSUInteger index = 0;
    for (index = 0; index < [_modeButtons count]; index++) {
        [[_modeButtons objectAtIndex:index] setNeedsDisplay:YES];
    }
    for (NSView *subview in [_contentView subviews]) {
        if ([subview isKindOfClass:[TGWorkshopModuleCardView class]]) {
            [(TGWorkshopModuleCardView *)subview refreshTheme];
        }
    }
}

- (void)modeChanged:(id)sender {
    NSInteger tag = [sender tag];
    NSString *mode = TGWorkshopViewModeAvailable;
    if (tag == 1) mode = TGWorkshopViewModeInstalled;
    if (tag == 2) mode = TGWorkshopViewModeUpdates;
    [_selectedMode release];
    _selectedMode = [mode copy];
    [self rebuildCards];
}

- (void)updateModeButtonStates {
    NSInteger selected = 0;
    if ([_selectedMode isEqualToString:TGWorkshopViewModeInstalled]) selected = 1;
    if ([_selectedMode isEqualToString:TGWorkshopViewModeUpdates]) selected = 2;
    NSUInteger index = 0;
    for (index = 0; index < [_modeButtons count]; index++) {
        [[_modeButtons objectAtIndex:index] setState:((NSInteger)index == selected) ? NSOnState : NSOffState];
    }
}

- (void)rebuildCards {
    if (!_contentView) return;
    NSArray *existing = [[_contentView subviews] copy];
    for (NSView *view in existing) {
        [view removeFromSuperview];
    }
    [existing release];
    [self updateModeButtonStates];

    NSArray *entries = [_coordinator entriesForMode:_selectedMode];
    CGFloat width = MAX(520.0, NSWidth([_scrollView contentView].bounds) - 12.0);
    CGFloat cardHeight = 116.0;
    CGFloat gap = 10.0;
    CGFloat y = 8.0;
    TGWorkshopCatalogEntry *entry = nil;
    for (entry in entries) {
        TGWorkshopModuleCardView *card = [[[TGWorkshopModuleCardView alloc] initWithFrame:NSMakeRect(6, y, width - 12.0, cardHeight)] autorelease];
        [card setDelegate:self];
        [card setEntry:entry];
        NSString *identifier = [entry moduleIdentifier];
        NSNumber *progress = [_progressByIdentifier objectForKey:identifier];
        [card configureWithInstalledRecord:[_coordinator installedRecordForModuleIdentifier:identifier]
                                      busy:[_coordinator isModuleBusy:identifier]
                                  progress:progress ? [progress doubleValue] : 0.0
                              errorMessage:[_errorsByIdentifier objectForKey:identifier]];
        [_contentView addSubview:card];
        y += cardHeight + gap;
    }

    if ([entries count] == 0) {
        NSTextField *empty = TGWorkshopViewLabel(NSMakeRect(18, 26, width - 36.0, 44), [NSFont systemFontOfSize:12.0]);
        [empty setAlignment:NSCenterTextAlignment];
        [empty setTextColor:TGClassicMutedInkColor()];
        [empty setStringValue:([_coordinator catalog] ? TGLoc(@"workshop.empty") : TGLoc(@"workshop.catalogUnavailable"))];
        [[empty cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [_contentView addSubview:empty];
        y = 94.0;
    }

    [_contentView setFrame:NSMakeRect(0, 0, width, MAX(y + 8.0, NSHeight([_scrollView contentView].bounds)))];
    [_statusField setStringValue:([_coordinator catalog]
                                  ? [NSString stringWithFormat:TGLoc(@"workshop.itemsCount"), (unsigned long)[entries count]]
                                  : TGLoc(@"workshop.offlineHint"))];
    [self refreshTheme];
}

- (void)backAction:(id)sender {
    (void)sender;
    if (_activeModuleViewController) {
        [_coordinator closeActiveModule];
        [[_activeModuleViewController view] removeFromSuperview];
        [_activeModuleViewController release];
        _activeModuleViewController = nil;
        [_moduleContainerView setHidden:YES];
        [_scrollView setHidden:NO];
        [_categoryField setHidden:NO];
        [_statusField setHidden:NO];
        for (NSButton *button in _modeButtons) [button setHidden:NO];
        [self rebuildCards];
        return;
    }
    if ([_delegate respondsToSelector:@selector(workshopViewControllerDidRequestClose:)]) {
        [_delegate workshopViewControllerDidRequestClose:self];
    }
}

- (void)requestCloseActiveModuleOrWorkshop {
    [self backAction:nil];
}

- (void)confirmRemovalForEntry:(TGWorkshopCatalogEntry *)entry {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"workshop.removeConfirmTitle")];
    [alert setInformativeText:TGLoc(@"workshop.removeConfirmMessage")];
    [alert addButtonWithTitle:TGLoc(@"workshop.removeKeepData")];
    [alert addButtonWithTitle:TGLoc(@"workshop.removeWithData")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [_coordinator removeEntry:entry removeData:NO];
    } else if (response == NSAlertSecondButtonReturn) {
        [_coordinator removeEntry:entry removeData:YES];
    }
}

- (void)workshopModuleCardView:(TGWorkshopModuleCardView *)cardView
                requestedAction:(TGWorkshopModuleCardAction)action
                          entry:(TGWorkshopCatalogEntry *)entry {
    (void)cardView;
    NSString *identifier = [entry moduleIdentifier];
    if (action == TGWorkshopModuleCardActionInstall ||
        action == TGWorkshopModuleCardActionUpdate ||
        action == TGWorkshopModuleCardActionRetry) {
        [_errorsByIdentifier removeObjectForKey:identifier];
        [_progressByIdentifier setObject:[NSNumber numberWithDouble:0.0] forKey:identifier];
        [_coordinator installOrUpdateEntry:entry];
    } else if (action == TGWorkshopModuleCardActionOpen) {
        [_coordinator openEntry:entry];
    } else if (action == TGWorkshopModuleCardActionRemove) {
        [self confirmRemovalForEntry:entry];
    }
}

- (void)workshopCoordinatorDidReload {
    [self rebuildCards];
}

- (void)workshopCoordinatorDidUpdateProgress:(double)progress moduleIdentifier:(NSString *)identifier {
    if (identifier) {
        [_progressByIdentifier setObject:[NSNumber numberWithDouble:progress] forKey:identifier];
    }
    [self rebuildCards];
}

- (void)workshopCoordinatorDidFailWithError:(NSError *)error moduleIdentifier:(NSString *)identifier {
    NSString *message = [error localizedDescription];
    if ([message length] == 0) message = TGLoc(@"workshop.unknownError");
    if (identifier) {
        [_errorsByIdentifier setObject:message forKey:identifier];
    } else {
        [_statusField setStringValue:message];
    }
    [self rebuildCards];
}

- (void)workshopCoordinatorDidOpenModuleViewController:(NSViewController *)viewController
                                      moduleIdentifier:(NSString *)identifier {
    (void)identifier;
    if (_activeModuleViewController) {
        [[_activeModuleViewController view] removeFromSuperview];
        [_activeModuleViewController release];
    }
    _activeModuleViewController = [viewController retain];
    NSView *moduleView = [_activeModuleViewController view];
    [moduleView setFrame:[_moduleContainerView bounds]];
    [moduleView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_moduleContainerView addSubview:moduleView];
    [_moduleContainerView setHidden:NO];
    [_scrollView setHidden:YES];
    [_categoryField setHidden:YES];
    [_statusField setHidden:YES];
    for (NSButton *button in _modeButtons) [button setHidden:YES];
}

- (void)dealloc {
    [_coordinator setDelegate:nil];
    [_coordinator closeActiveModule];
    [_coordinator release];
    [_backButton release];
    [_titleField release];
    [_categoryField release];
    [_statusField release];
    [_modeButtons release];
    [_scrollView release];
    [_contentView release];
    [_moduleContainerView release];
    [_activeModuleViewController release];
    [_selectedMode release];
    [_progressByIdentifier release];
    [_errorsByIdentifier release];
    [super dealloc];
}

@end
