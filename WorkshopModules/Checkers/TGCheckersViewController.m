#import "TGCheckersViewController.h"
#import "TGCheckersBoardView.h"
#import "../Common/TGGameUI.h"

@implementation TGCheckersViewController

- (id)initWithEngine:(TGCheckersEngine *)engine hostContext:(id<TGWorkshopHostContext>)context {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [context retain];
    }
    return self;
}

- (void)loadView {
    TGWorkshopGameSurfaceView *root = [[[TGWorkshopGameSurfaceView alloc] initWithFrame:NSMakeRect(0, 0, 720, 620)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self setView:root];

    _statusField = [TGGameLabel(NSMakeRect(24, 574, 300, 24), 15.0, YES, _hostContext) retain];
    [_statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:_statusField];

    _scoreField = [TGGameLabel(NSMakeRect(24, 550, 300, 20), 11.0, NO, _hostContext) retain];
    [_scoreField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:_scoreField];

    _modeButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(416, 570, 144, 28) pullsDown:NO];
    [_modeButton addItemsWithTitles:
     [NSArray arrayWithObjects:
      [_hostContext localizedStringForKey:@"game.computer" fallback:@"Computer"],
      [_hostContext localizedStringForKey:@"game.twoPlayers" fallback:@"Two players"], nil]];
    [_modeButton setTarget:self];
    [_modeButton setAction:@selector(modeChanged:)];
    [_modeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:_modeButton];

    _restartButton = [TGGameThemedButton(NSMakeRect(570, 568, 126, 32),
                                        [_hostContext localizedStringForKey:@"checkers.new_game" fallback:@"New game"],
                                        @"refresh",
                                        _hostContext) retain];
    [_restartButton setTarget:self];
    [_restartButton setAction:@selector(restart:)];
    [_restartButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
    [root addSubview:_restartButton];

    _boardView = [[TGCheckersBoardView alloc] initWithFrame:NSMakeRect(20, 20, 680, 520)
                                                     engine:_engine
                                                themeColors:[_hostContext themeColors]];
    [_boardView setTarget:self action:@selector(boardMoved:)];
    [root addSubview:_boardView];
    [self refreshFromEngine];
}

- (void)refreshFromEngine {
    if (!_statusField) return;
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
    [_boardView setNeedsDisplay:YES];
}

- (void)boardMoved:(id)sender {
    (void)sender;
    [self refreshFromEngine];
    if (![_engine isFinished] &&
        [_engine mode] == TGCheckersModeComputer &&
        [_engine currentPlayer] == TGCheckersPlayerBlack) {
        [_engine performComputerMove];
        [_boardView clearSelection];
        [self refreshFromEngine];
    }
}

- (void)modeChanged:(id)sender {
    (void)sender;
    TGCheckersMode mode = [_modeButton indexOfSelectedItem] == 0 ? TGCheckersModeComputer : TGCheckersModeLocal;
    [_engine startNewGameWithMode:mode];
    [_boardView clearSelection];
    [self refreshFromEngine];
}

- (void)restart:(id)sender {
    (void)sender;
    [_engine startNewGameWithMode:[_engine mode]];
    [_boardView clearSelection];
    [self refreshFromEngine];
}

- (void)dealloc {
    [_engine release];
    [_hostContext release];
    [_boardView release];
    [_modeButton release];
    [_statusField release];
    [_scoreField release];
    [_restartButton release];
    [super dealloc];
}

@end
