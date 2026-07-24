#import "TGCheckersViewController.h"

static const CGFloat TGCheckersBoardSize = 480.0;

@implementation TGCheckersViewController

- (id)initWithEngine:(TGCheckersEngine *)engine hostContext:(id<TGWorkshopHostContext>)context {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [context retain];
        _squareButtons = [[NSMutableArray alloc] initWithCapacity:64];
        _selectedRow = -1;
        _selectedColumn = -1;
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame size:(CGFloat)size bold:(BOOL)bold {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setFont:bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size]];
    return label;
}

- (void)loadView {
    NSView *root = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 720, 620)] autorelease];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self setView:root];

    _statusField = [[self labelWithFrame:NSMakeRect(30, 572, 410, 24) size:16 bold:YES] retain];
    [_statusField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
    [_statusField setTextColor:[[_hostContext themeColors] objectForKey:@"text"]];
    [root addSubview:_statusField];

    _scoreField = [[self labelWithFrame:NSMakeRect(30, 548, 410, 20) size:12 bold:NO] retain];
    [_scoreField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
    [_scoreField setTextColor:[[_hostContext themeColors] objectForKey:@"muted_text"]];
    [root addSubview:_scoreField];

    _modeButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(466, 570, 120, 26) pullsDown:NO];
    [_modeButton addItemsWithTitles:
     [NSArray arrayWithObjects:
      [_hostContext localizedStringForKey:@"game.computer" fallback:@"Computer"],
      [_hostContext localizedStringForKey:@"game.twoPlayers" fallback:@"Two players"], nil]];
    [_modeButton setTarget:self];
    [_modeButton setAction:@selector(modeChanged:)];
    [_modeButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [root addSubview:_modeButton];

    _restartButton = [[NSButton alloc] initWithFrame:NSMakeRect(592, 570, 96, 26)];
    [_restartButton setTitle:[_hostContext localizedStringForKey:@"checkers.new_game"
                                                        fallback:@"New game"]];
    [_restartButton setTarget:self];
    [_restartButton setAction:@selector(restart:)];
    [_restartButton setAutoresizingMask:NSViewMinXMargin | NSViewMinYMargin];
    [root addSubview:_restartButton];

    CGFloat squareSize = TGCheckersBoardSize / 8.0;
    CGFloat originX = (720.0 - TGCheckersBoardSize) / 2.0;
    CGFloat originY = 46.0;
    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSButton *button = [[[NSButton alloc] initWithFrame:
                                 NSMakeRect(originX + column * squareSize,
                                            originY + (7 - row) * squareSize,
                                            squareSize, squareSize)] autorelease];
            [button setTag:row * 8 + column];
            [button setButtonType:NSMomentaryChangeButton];
            [button setBezelStyle:NSShadowlessSquareBezelStyle];
            [button setTarget:self];
            [button setAction:@selector(squareClicked:)];
            [button setFont:[NSFont boldSystemFontOfSize:25]];
            [button setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin];
            [root addSubview:button];
            [_squareButtons addObject:button];
        }
    }
    [self refreshFromEngine];
}

- (NSString *)titleForPiece:(NSInteger)piece {
    if (piece == 1) return @"●";
    if (piece == 2) return @"♛";
    if (piece == -1) return @"●";
    if (piece == -2) return @"♛";
    return @"";
}

- (BOOL)isDestinationRow:(NSInteger)row column:(NSInteger)column {
    if (_selectedRow < 0) return NO;
    NSArray *moves = [_engine legalMovesFromRow:_selectedRow column:_selectedColumn];
    NSUInteger index;
    for (index = 0; index < [moves count]; index++) {
        NSDictionary *move = [moves objectAtIndex:index];
        if ([[move objectForKey:@"toRow"] integerValue] == row &&
            [[move objectForKey:@"toColumn"] integerValue] == column) return YES;
    }
    return NO;
}

- (void)refreshFromEngine {
    if (![self isViewLoaded]) return;
    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSButton *button = [_squareButtons objectAtIndex:(NSUInteger)(row * 8 + column)];
            NSInteger piece = [_engine pieceAtRow:row column:column];
            BOOL dark = ((row + column) % 2) == 1;
            NSColor *background = dark ? [NSColor colorWithCalibratedRed:0.31 green:0.43 blue:0.52 alpha:1.0]
                                       : [NSColor colorWithCalibratedRed:0.84 green:0.82 blue:0.72 alpha:1.0];
            if (row == _selectedRow && column == _selectedColumn) {
                background = [NSColor colorWithCalibratedRed:0.95 green:0.72 blue:0.24 alpha:1.0];
            } else if ([self isDestinationRow:row column:column]) {
                background = [NSColor colorWithCalibratedRed:0.43 green:0.72 blue:0.45 alpha:1.0];
            }
            [button setWantsLayer:YES];
            [[button layer] setBackgroundColor:[background CGColor]];
            [button setTitle:[self titleForPiece:piece]];
            NSColor *pieceColor = piece > 0 ? [NSColor colorWithCalibratedRed:0.72 green:0.12 blue:0.13 alpha:1.0]
                                           : [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
            NSMutableAttributedString *title = [[[NSMutableAttributedString alloc]
                                                  initWithString:[button title]
                                                  attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              pieceColor, NSForegroundColorAttributeName,
                                                              [NSFont boldSystemFontOfSize:28], NSFontAttributeName, nil]]
                                                 autorelease];
            [button setAttributedTitle:title];
        }
    }
    NSString *status = nil;
    if ([_engine isFinished]) {
        status = [_hostContext localizedStringForKey:
                  ([_engine winner] == TGCheckersPlayerRed ? @"checkers.red_wins" : @"checkers.black_wins")
                                                   fallback:
                  ([_engine winner] == TGCheckersPlayerRed ? @"Red wins" : @"Black wins")];
    } else if ([_engine forcedCaptureRow] >= 0) {
        status = [_hostContext localizedStringForKey:@"checkers.continue_capture"
                                             fallback:@"Continue capturing"];
    } else {
        status = [_hostContext localizedStringForKey:
                  ([_engine currentPlayer] == TGCheckersPlayerRed ? @"checkers.red_turn" : @"checkers.black_turn")
                                                   fallback:
                  ([_engine currentPlayer] == TGCheckersPlayerRed ? @"Red to move" : @"Black to move")];
    }
    [_statusField setStringValue:status];
    [_scoreField setStringValue:[NSString stringWithFormat:@"%@ %lu  •  %@ %lu",
                                 [_hostContext localizedStringForKey:@"checkers.red" fallback:@"Red"],
                                 (unsigned long)[_engine redWins],
                                 [_hostContext localizedStringForKey:@"checkers.black" fallback:@"Black"],
                                 (unsigned long)[_engine blackWins]]];
    [_modeButton selectItemAtIndex:[_engine mode] == TGCheckersModeComputer ? 0 : 1];
}

- (void)squareClicked:(id)sender {
    NSInteger tag = [sender tag];
    NSInteger row = tag / 8;
    NSInteger column = tag % 8;
    if (_selectedRow >= 0 &&
        [_engine moveFromRow:_selectedRow column:_selectedColumn toRow:row column:column]) {
        _selectedRow = [_engine forcedCaptureRow];
        _selectedColumn = [_engine forcedCaptureColumn];
        [self refreshFromEngine];
        if (![_engine isFinished] && [_engine mode] == TGCheckersModeComputer &&
            [_engine currentPlayer] == TGCheckersPlayerBlack) {
            [_engine performComputerMove];
            _selectedRow = -1;
            _selectedColumn = -1;
            [self refreshFromEngine];
        }
        return;
    }
    if ([[_engine legalMovesFromRow:row column:column] count] > 0) {
        _selectedRow = row;
        _selectedColumn = column;
    } else {
        _selectedRow = -1;
        _selectedColumn = -1;
    }
    [self refreshFromEngine];
}

- (void)modeChanged:(id)sender {
    (void)sender;
    TGCheckersMode mode = [_modeButton indexOfSelectedItem] == 0 ? TGCheckersModeComputer : TGCheckersModeLocal;
    [_engine startNewGameWithMode:mode];
    _selectedRow = -1;
    _selectedColumn = -1;
    [self refreshFromEngine];
}

- (void)restart:(id)sender {
    (void)sender;
    [_engine startNewGameWithMode:[_engine mode]];
    _selectedRow = -1;
    _selectedColumn = -1;
    [self refreshFromEngine];
}

- (void)dealloc {
    [_engine release];
    [_hostContext release];
    [_squareButtons release];
    [_modeButton release];
    [_statusField release];
    [_scoreField release];
    [_restartButton release];
    [super dealloc];
}

@end
