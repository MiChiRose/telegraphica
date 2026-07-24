#import "TGMinesweeperViewController.h"

@protocol TGMinesweeperCellButtonDelegate <NSObject>
- (void)mineCellButtonRightClicked:(NSButton *)button;
@end

@interface TGMinesweeperCellButton : NSButton
@property(nonatomic, assign) id<TGMinesweeperCellButtonDelegate> rightClickDelegate;
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
    NSView *root = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self setView:root];

    NSTextField *title = TGMinesweeperLabel(NSMakeRect(220, 474, 260, 28),
                                            [_hostContext interfaceFontOfSize:19.0 bold:YES]);
    [title setStringValue:[_hostContext localizedStringForKey:@"minesweeper.title" fallback:@"Minesweeper"]];
    [root addSubview:title];
    _statusField = [TGMinesweeperLabel(NSMakeRect(235, 446, 230, 20),
                                       [_hostContext interfaceFontOfSize:12.0 bold:YES]) retain];
    [root addSubview:_statusField];
    _mineField = [TGMinesweeperLabel(NSMakeRect(72, 446, 150, 20),
                                     [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [root addSubview:_mineField];
    _timerField = [TGMinesweeperLabel(NSMakeRect(478, 446, 150, 20),
                                      [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [root addSubview:_timerField];

    _difficultyButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(170, 18, 180, 28) pullsDown:NO];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.easy" fallback:@"Easy"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.medium" fallback:@"Medium"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.hard" fallback:@"Hard"]];
    [_difficultyButton setTarget:self];
    [_difficultyButton setAction:@selector(difficultyChanged:)];
    [root addSubview:_difficultyButton];

    _restartButton = [[NSButton alloc] initWithFrame:NSMakeRect(360, 16, 150, 30)];
    [_restartButton setTitle:[_hostContext localizedStringForKey:@"game.restart" fallback:@"Restart"]];
    [_restartButton setTarget:self];
    [_restartButton setAction:@selector(restart:)];
    [root addSubview:_restartButton];

    [self rebuildGrid];
    [self refreshFromEngine];
}

- (void)rebuildGrid {
    NSButton *oldButton = nil;
    for (oldButton in _cellButtons) [oldButton removeFromSuperview];
    [_cellButtons removeAllObjects];

    CGFloat availableWidth = MAX(520.0, NSWidth([[self view] bounds]) - 50.0);
    CGFloat availableHeight = MAX(300.0, NSHeight([[self view] bounds]) - 150.0);
    CGFloat side = floor(MIN(availableWidth / [_engine width], availableHeight / [_engine height]));
    side = MAX(16.0, MIN(30.0, side));
    CGFloat boardWidth = side * [_engine width];
    CGFloat boardHeight = side * [_engine height];
    CGFloat originX = floor((NSWidth([[self view] bounds]) - boardWidth) / 2.0);
    CGFloat originY = 60.0 + floor((availableHeight - boardHeight) / 2.0);
    NSUInteger index = 0;
    for (index = 0; index < [_engine width] * [_engine height]; index++) {
        NSUInteger row = index / [_engine width];
        NSUInteger column = index % [_engine width];
        TGMinesweeperCellButton *button = [[[TGMinesweeperCellButton alloc]
                                             initWithFrame:NSMakeRect(originX + column * side,
                                                                      originY + row * side,
                                                                      side,
                                                                      side)] autorelease];
        [button setTag:(NSInteger)index];
        [button setButtonType:NSMomentaryPushInButton];
        [button setBezelStyle:NSShadowlessSquareBezelStyle];
        [button setFont:[_hostContext interfaceFontOfSize:MAX(9.0, side * 0.46) bold:YES]];
        [button setTarget:self];
        [button setAction:@selector(cellPressed:)];
        [button setRightClickDelegate:self];
        [[self view] addSubview:button];
        [_cellButtons addObject:button];
    }
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
    [_statusField release];
    [_mineField release];
    [_timerField release];
    [_difficultyButton release];
    [_restartButton release];
    [super dealloc];
}

@end
