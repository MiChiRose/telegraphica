#import "TGPacManViewController.h"
#import "TGPacManBoardView.h"
#import "../Common/TGGameUI.h"

@class TGPacManViewController;

@interface TGPacManRootView : TGWorkshopGameSurfaceView {
    TGPacManViewController *_layoutOwner;
}
@property(nonatomic, assign) TGPacManViewController *layoutOwner;
@end

@interface TGPacManViewController ()
- (void)layoutGame;
- (void)directionChanged:(id)sender;
- (void)timerFired:(NSTimer *)timer;
@end

@implementation TGPacManRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

@implementation TGPacManViewController

- (id)initWithEngine:(TGPacManEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [hostContext retain];
    }
    return self;
}

- (void)loadView {
    TGPacManRootView *root = [[[TGPacManRootView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGGameLabel(NSZeroRect, 20.0, YES, _hostContext) retain];
    [_titleField setAlignment:NSCenterTextAlignment];
    [_titleField setStringValue:@"Pac-Man"];
    [root addSubview:_titleField];
    _statusField = [TGGameLabel(NSZeroRect, 12.0, YES, _hostContext) retain];
    [_statusField setAlignment:NSCenterTextAlignment];
    [root addSubview:_statusField];
    _scoreField = [TGGameLabel(NSZeroRect, 11.0, NO, _hostContext) retain];
    [_scoreField setAlignment:NSCenterTextAlignment];
    [root addSubview:_scoreField];

    _boardView = [[TGPacManBoardView alloc] initWithFrame:NSZeroRect engine:_engine];
    [_boardView setTarget:self action:@selector(directionChanged:)];
    [root addSubview:_boardView];

    _newGameButton = [TGGameThemedButton(NSZeroRect,
                                          [_hostContext localizedStringForKey:@"game.newGame" fallback:@"New game"],
                                          @"refresh", _hostContext) retain];
    [_newGameButton setTarget:self];
    [_newGameButton setAction:@selector(newGame:)];
    [root addSubview:_newGameButton];
    _pauseButton = [TGGameThemedButton(NSZeroRect,
                                       [_hostContext localizedStringForKey:@"game.pause" fallback:@"Pause"],
                                       @"pause", _hostContext) retain];
    [_pauseButton setTarget:self];
    [_pauseButton setAction:@selector(togglePause:)];
    [root addSubview:_pauseButton];

    [self layoutGame];
    [self refreshFromEngine];
    [self startAnimation];
}

- (void)layoutGame {
    if (!_titleField) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(660.0, MAX(320.0, width - 28.0));
    CGFloat contentX = floor((width - contentWidth) / 2.0);
    [_titleField setFrame:NSMakeRect(contentX, height - 40.0, contentWidth, 28.0)];
    [_statusField setFrame:NSMakeRect(contentX, height - 62.0, contentWidth, 18.0)];
    [_scoreField setFrame:NSMakeRect(contentX, height - 82.0, contentWidth, 18.0)];
    [_boardView setFrame:NSMakeRect(contentX, 60.0, contentWidth, MAX(180.0, height - 150.0))];
    CGFloat controlsWidth = MIN(300.0, contentWidth);
    CGFloat controlsX = floor((width - controlsWidth) / 2.0);
    [_newGameButton setFrame:NSMakeRect(controlsX, 16.0, 142.0, 32.0)];
    [_pauseButton setFrame:NSMakeRect(NSMaxX([_newGameButton frame]) + 16.0, 16.0,
                                      controlsWidth - 158.0, 32.0)];
}

- (void)refreshFromEngine {
    if (!_statusField) return;
    NSString *status = [_hostContext localizedStringForKey:@"pacman.hint"
                                                   fallback:@"Use arrow keys or WASD"];
    if ([_engine isFinished]) {
        status = [_engine hasWon]
            ? [_hostContext localizedStringForKey:@"game.won" fallback:@"You won"]
            : [_hostContext localizedStringForKey:@"game.lost" fallback:@"Game over"];
    } else if (_paused) {
        status = [_hostContext localizedStringForKey:@"game.paused" fallback:@"Paused"];
    }
    [_statusField setStringValue:status];
    [_scoreField setStringValue:[NSString stringWithFormat:@"%@ %lu  •  %@ %lu  •  %@ %lu",
                                 [_hostContext localizedStringForKey:@"game.score" fallback:@"Score"],
                                 (unsigned long)[_engine score],
                                 [_hostContext localizedStringForKey:@"game.lives" fallback:@"Lives"],
                                 (unsigned long)[_engine lives],
                                 [_hostContext localizedStringForKey:@"pacman.pellets" fallback:@"Pellets"],
                                 (unsigned long)[_engine pelletCount]]];
    [_pauseButton setTitle:(_paused
                            ? [_hostContext localizedStringForKey:@"game.resume" fallback:@"Resume"]
                            : [_hostContext localizedStringForKey:@"game.pause" fallback:@"Pause"])];
    [_boardView setNeedsDisplay:YES];
}

- (void)directionChanged:(id)sender {
    if (![sender isKindOfClass:[TGPacManBoardView class]]) return;
    _queuedDirection = [(TGPacManBoardView *)sender pendingDirection];
    _paused = NO;
    if (![_boardView isAnimatingMovement]) {
        [self timerFired:nil];
    }
    [self refreshFromEngine];
}

- (void)timerFired:(NSTimer *)timer {
    (void)timer;
    if (_paused || [_engine isFinished]) return;
    if ([_boardView isAnimatingMovement]) {
        [_boardView advanceMovementAnimation];
        return;
    }
    if (_queuedDirection != TGPacManDirectionNone &&
        [_engine canStepInDirection:_queuedDirection]) {
        _direction = _queuedDirection;
        _queuedDirection = TGPacManDirectionNone;
    }
    if (_direction == TGPacManDirectionNone ||
        ![_engine canStepInDirection:_direction]) {
        return;
    }
    NSUInteger previousPacman = [_engine pacmanIndex];
    NSUInteger previousGhost = [_engine ghostIndex];
    if ([_engine stepInDirection:_direction]) {
        [_boardView beginMovementFromPacmanIndex:previousPacman
                                     ghostIndex:previousGhost
                                      direction:_direction];
    }
    [self refreshFromEngine];
}

- (void)newGame:(id)sender {
    (void)sender;
    [_engine newGame];
    _direction = TGPacManDirectionNone;
    _queuedDirection = TGPacManDirectionNone;
    _paused = NO;
    [_boardView setFacingDirection:TGPacManDirectionRight];
    [_boardView resetMovementAnimation];
    [self refreshFromEngine];
    if ([[_boardView window] firstResponder] != _boardView) {
        [[_boardView window] makeFirstResponder:_boardView];
    }
}

- (void)togglePause:(id)sender {
    (void)sender;
    _paused = !_paused;
    [self refreshFromEngine];
}

- (void)startAnimation {
    if (_timer) return;
    _timer = [[NSTimer scheduledTimerWithTimeInterval:0.04
                                               target:self
                                             selector:@selector(timerFired:)
                                             userInfo:nil
                                              repeats:YES] retain];
}

- (void)stopAnimation {
    [_timer invalidate];
    [_timer release];
    _timer = nil;
}

- (void)dealloc {
    [self stopAnimation];
    [_engine release];
    [_hostContext release];
    [_boardView release];
    [_titleField release];
    [_statusField release];
    [_scoreField release];
    [_newGameButton release];
    [_pauseButton release];
    [super dealloc];
}

@end
