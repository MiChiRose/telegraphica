#import "TGMinesweeperViewController.h"
#import "../Common/TGGameUI.h"

@class TGMinesweeperViewController;

@interface TGMinesweeperRootView : TGWorkshopGameSurfaceView {
    TGMinesweeperViewController *_layoutOwner;
}
@property(nonatomic, assign) TGMinesweeperViewController *layoutOwner;
@end

@interface TGMinesweeperViewController ()
- (void)layoutGame;
- (void)layoutGrid;
@end

@implementation TGMinesweeperRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

@protocol TGMinesweeperCellButtonDelegate <NSObject>
- (void)mineCellButtonRightClicked:(NSButton *)button;
@end

@interface TGMinesweeperCellButton : NSButton
@property(nonatomic, assign) id<TGMinesweeperCellButtonDelegate> rightClickDelegate;
@end

@interface TGMinesweeperCell : NSButtonCell
@end

@implementation TGMinesweeperCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    BOOL open = ([self state] == NSOnState);
    BOOL pressed = [self isHighlighted];
    NSRect rect = NSInsetRect(cellFrame, 0.5, 0.5);
    if (open) {
        [[NSColor colorWithCalibratedWhite:0.79 alpha:1.0] setFill];
        NSRectFill(rect);
        [[NSColor colorWithCalibratedWhite:0.48 alpha:1.0] setStroke];
        NSFrameRect(rect);
    } else {
        NSColor *top = pressed ? [NSColor colorWithCalibratedWhite:0.62 alpha:1.0]
                               : [NSColor colorWithCalibratedWhite:0.92 alpha:1.0];
        NSColor *bottom = pressed ? [NSColor colorWithCalibratedWhite:0.82 alpha:1.0]
                                  : [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
        [gradient drawInRect:rect angle:90.0];
        [[NSColor colorWithCalibratedWhite:0.36 alpha:1.0] setStroke];
        NSFrameRect(rect);
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.88] setFill];
        NSRectFill(NSMakeRect(NSMinX(rect) + 1.0, NSMaxY(rect) - 2.0, NSWidth(rect) - 2.0, 1.0));
    }

    NSString *title = [self title] ? [self title] : @"";
    if ([title length] == 0) return;
    NSColor *color = [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
    if ([title isEqualToString:@"1"]) color = [NSColor colorWithCalibratedRed:0.08 green:0.20 blue:0.74 alpha:1.0];
    if ([title isEqualToString:@"2"]) color = [NSColor colorWithCalibratedRed:0.04 green:0.46 blue:0.12 alpha:1.0];
    if ([title isEqualToString:@"3"]) color = [NSColor colorWithCalibratedRed:0.72 green:0.08 blue:0.08 alpha:1.0];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [self font], NSFontAttributeName,
                                color, NSForegroundColorAttributeName,
                                nil];
    NSSize size = [title sizeWithAttributes:attributes];
    [title drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2.0,
                                   NSMidY(rect) - size.height / 2.0)
        withAttributes:attributes];
}

@end

@implementation TGMinesweeperCellButton
@synthesize rightClickDelegate = _rightClickDelegate;
- (void)rightMouseDown:(NSEvent *)event {
    (void)event;
    [_rightClickDelegate mineCellButtonRightClicked:self];
}
@end

@interface TGMinesweeperViewController () <TGMinesweeperCellButtonDelegate>
@end

static NSTextField *TGMinesweeperLabel(NSRect frame, NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setAlignment:NSCenterTextAlignment];
    [field setTextColor:TGWorkshopCreamColor()];
    return field;
}

@implementation TGMinesweeperViewController

- (id)initWithEngine:(TGMinesweeperEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [hostContext retain];
        _cellButtons = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)loadView {
    TGMinesweeperRootView *root = [[[TGMinesweeperRootView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGMinesweeperLabel(NSZeroRect,
                                      [_hostContext interfaceFontOfSize:19.0 bold:YES]) retain];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"minesweeper.title" fallback:@"Minesweeper"]];
    [root addSubview:_titleField];
    _statusField = [TGMinesweeperLabel(NSZeroRect,
                                       [_hostContext interfaceFontOfSize:12.0 bold:YES]) retain];
    [_statusField setTextColor:TGWorkshopGoldColor()];
    [root addSubview:_statusField];
    _mineField = [TGMinesweeperLabel(NSZeroRect,
                                     [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [_mineField setTextColor:TGWorkshopMutedCreamColor()];
    [root addSubview:_mineField];
    _timerField = [TGMinesweeperLabel(NSZeroRect,
                                      [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [_timerField setTextColor:TGWorkshopMutedCreamColor()];
    [root addSubview:_timerField];

    _difficultyButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.easy" fallback:@"Easy"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.medium" fallback:@"Medium"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.hard" fallback:@"Hard"]];
    [_difficultyButton setTarget:self];
    [_difficultyButton setAction:@selector(difficultyChanged:)];
    [root addSubview:_difficultyButton];

    _restartButton = [TGGameThemedButton(NSZeroRect,
                                         [_hostContext localizedStringForKey:@"game.restart" fallback:@"Restart"],
                                         @"refresh",
                                         _hostContext) retain];
    [_restartButton setTarget:self];
    [_restartButton setAction:@selector(restart:)];
    [root addSubview:_restartButton];

    [self rebuildGrid];
    [self layoutGame];
    [self refreshFromEngine];
}

- (void)layoutGame {
    if (!_titleField) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(650.0, MAX(320.0, width - 28.0));
    CGFloat contentX = floor((width - contentWidth) / 2.0);
    [_titleField setFrame:NSMakeRect(contentX, height - 36.0, contentWidth, 26.0)];
    [_statusField setFrame:NSMakeRect(contentX + 170.0, height - 58.0,
                                      MAX(120.0, contentWidth - 340.0), 18.0)];
    [_mineField setFrame:NSMakeRect(contentX, height - 58.0, 160.0, 18.0)];
    [_timerField setFrame:NSMakeRect(NSMaxX(NSMakeRect(contentX, 0, contentWidth, 0)) - 160.0,
                                     height - 58.0, 160.0, 18.0)];

    CGFloat controlsWidth = MIN(338.0, contentWidth);
    CGFloat controlsX = floor((width - controlsWidth) / 2.0);
    [_difficultyButton setFrame:NSMakeRect(controlsX, 16.0, 180.0, 28.0)];
    [_restartButton setFrame:NSMakeRect(controlsX + 188.0, 14.0, 150.0, 32.0)];
    [self layoutGrid];
}

- (void)layoutGrid {
    if ([_cellButtons count] == 0) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat boardBottom = 58.0;
    CGFloat boardTop = height - 70.0;
    CGFloat availableWidth = MAX(280.0, width - 32.0);
    CGFloat availableHeight = MAX(220.0, boardTop - boardBottom);
    CGFloat side = floor(MIN(availableWidth / [_engine width],
                             availableHeight / [_engine height]));
    side = MAX(14.0, MIN(30.0, side));
    CGFloat boardWidth = side * [_engine width];
    CGFloat boardHeight = side * [_engine height];
    CGFloat originX = floor((width - boardWidth) / 2.0);
    CGFloat originY = floor(boardBottom + (availableHeight - boardHeight) / 2.0);
    NSUInteger index = 0;
    for (index = 0; index < [_cellButtons count]; index++) {
        NSUInteger row = index / [_engine width];
        NSUInteger column = index % [_engine width];
        NSButton *button = [_cellButtons objectAtIndex:index];
        [button setFrame:NSMakeRect(originX + column * side,
                                    originY + ([_engine height] - row - 1) * side,
                                    side,
                                    side)];
        [button setFont:[_hostContext interfaceFontOfSize:MAX(9.0, side * 0.46) bold:YES]];
    }
}

- (void)rebuildGrid {
    NSButton *oldButton = nil;
    for (oldButton in _cellButtons) [oldButton removeFromSuperview];
    [_cellButtons removeAllObjects];

    NSUInteger index = 0;
    for (index = 0; index < [_engine width] * [_engine height]; index++) {
        TGMinesweeperCellButton *button = [[[TGMinesweeperCellButton alloc]
                                             initWithFrame:NSZeroRect] autorelease];
        TGMinesweeperCell *cell = [[[TGMinesweeperCell alloc] initTextCell:@""] autorelease];
        [cell setButtonType:NSMomentaryPushInButton];
        [button setCell:cell];
        [button setTag:(NSInteger)index];
        [button setButtonType:NSMomentaryPushInButton];
        [button setBezelStyle:NSShadowlessSquareBezelStyle];
        [button setTarget:self];
        [button setAction:@selector(cellPressed:)];
        [button setRightClickDelegate:self];
        [[self view] addSubview:button];
        [_cellButtons addObject:button];
    }
    [self layoutGrid];
}

- (void)refreshTimer:(id)sender {
    (void)sender;
    [_timerField setStringValue:[NSString stringWithFormat:@"%@ %03lu",
                                 [_hostContext localizedStringForKey:@"game.time" fallback:@"Time"],
                                 (unsigned long)[_engine elapsedSeconds]]];
}

- (void)refreshFromEngine {
    if (!_statusField) return;
    if ([_cellButtons count] != [_engine width] * [_engine height]) [self rebuildGrid];
    [_difficultyButton selectItemAtIndex:[_engine difficulty]];
    NSUInteger index = 0;
    for (index = 0; index < [_cellButtons count]; index++) {
        NSButton *button = [_cellButtons objectAtIndex:index];
        NSDictionary *cell = [_engine cellAtIndex:index];
        NSString *title = @"";
        if ([[cell objectForKey:@"flag"] boolValue] && ![[cell objectForKey:@"open"] boolValue]) {
            title = @"⚑";
        } else if ([[cell objectForKey:@"open"] boolValue] && [[cell objectForKey:@"mine"] boolValue]) {
            title = @"✹";
        } else if ([[cell objectForKey:@"open"] boolValue] && [[cell objectForKey:@"adjacent"] unsignedIntegerValue] > 0) {
            title = [[cell objectForKey:@"adjacent"] stringValue];
        }
        [button setTitle:title];
        [button setState:[[cell objectForKey:@"open"] boolValue] ? NSOnState : NSOffState];
        [button setEnabled:([_engine state] < TGMinesweeperStateWon)];
    }
    NSString *status = [_hostContext localizedStringForKey:@"minesweeper.ready" fallback:@"Choose a cell"];
    if ([_engine state] == TGMinesweeperStatePlaying) status = [_hostContext localizedStringForKey:@"minesweeper.playing" fallback:@"Clear the field"];
    if ([_engine state] == TGMinesweeperStateWon) status = [_hostContext localizedStringForKey:@"game.won" fallback:@"You won"];
    if ([_engine state] == TGMinesweeperStateLost) status = [_hostContext localizedStringForKey:@"game.lost" fallback:@"Game over"];
    [_statusField setStringValue:status];
    [_mineField setStringValue:[NSString stringWithFormat:@"%@ %lu",
                                [_hostContext localizedStringForKey:@"minesweeper.mines" fallback:@"Mines"],
                                (unsigned long)[_engine remainingMineEstimate]]];
    [self refreshTimer:nil];
}

- (void)cellPressed:(id)sender {
    if ([_engine revealCellAtIndex:(NSUInteger)[sender tag]]) [self refreshFromEngine];
}

- (void)mineCellButtonRightClicked:(NSButton *)button {
    if ([_engine toggleFlagAtIndex:(NSUInteger)[button tag]]) [self refreshFromEngine];
}

- (void)difficultyChanged:(id)sender {
    (void)sender;
    [_engine startNewGameWithDifficulty:(TGMinesweeperDifficulty)[_difficultyButton indexOfSelectedItem]];
    [self rebuildGrid];
    [self refreshFromEngine];
}

- (void)restart:(id)sender {
    (void)sender;
    [_engine startNewGameWithDifficulty:[_engine difficulty]];
    [self refreshFromEngine];
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    (void)notification;
    [_engine pauseTiming];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [_engine resumeTiming];
}

- (void)startUpdating {
    if (_timer) return;
    [_engine resumeTiming];
    _timer = [[NSTimer scheduledTimerWithTimeInterval:1.0
                                               target:self
                                             selector:@selector(refreshTimer:)
                                             userInfo:nil
                                              repeats:YES] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidResignActive:)
                                                 name:NSApplicationDidResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:)
                                                 name:NSApplicationDidBecomeActiveNotification object:nil];
}

- (void)stopUpdating {
    [_engine pauseTiming];
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)dealloc {
    [self stopUpdating];
    [_engine release];
    [_hostContext release];
    [_cellButtons release];
    [_titleField release];
    [_statusField release];
    [_mineField release];
    [_timerField release];
    [_difficultyButton release];
    [_restartButton release];
    [super dealloc];
}

@end
