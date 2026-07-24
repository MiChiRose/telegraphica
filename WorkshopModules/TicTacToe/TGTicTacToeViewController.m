#import "TGTicTacToeViewController.h"

@interface TGTicTacToeBoardView : NSView {
@private
    NSDictionary *_colors;
}
@property(nonatomic, retain) NSDictionary *colors;
@end

@implementation TGTicTacToeBoardView
@synthesize colors = _colors;
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSColor *background = [_colors objectForKey:@"background"];
    [(background ? background : [NSColor colorWithCalibratedWhite:0.94 alpha:1.0]) set];
    NSRectFill([self bounds]);
}
- (void)dealloc { [_colors release]; [super dealloc]; }
@end

static NSTextField *TGTicTacToeLabel(NSRect frame, NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setAlignment:NSCenterTextAlignment];
    return field;
}

@implementation TGTicTacToeViewController

- (id)initWithEngine:(TGTicTacToeEngine *)engine hostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [hostContext retain];
    }
    return self;
}

- (void)loadView {
    TGTicTacToeBoardView *root = [[[TGTicTacToeBoardView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setColors:[_hostContext themeColors]];
    [self setView:root];

    NSTextField *title = TGTicTacToeLabel(NSMakeRect(190, 20, 320, 30),
                                          [_hostContext interfaceFontOfSize:20.0 bold:YES]);
    [title setStringValue:[_hostContext localizedStringForKey:@"tictactoe.title" fallback:@"Tic-Tac-Toe"]];
    [title setTextColor:[[_hostContext themeColors] objectForKey:@"text"]];
    [root addSubview:title];

    _statusField = [TGTicTacToeLabel(NSMakeRect(170, 55, 360, 22),
                                     [_hostContext interfaceFontOfSize:13.0 bold:YES]) retain];
    [root addSubview:_statusField];
    _scoreField = [TGTicTacToeLabel(NSMakeRect(170, 82, 360, 20),
                                    [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [root addSubview:_scoreField];

    NSMutableArray *buttons = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < 9; index++) {
        NSUInteger row = index / 3;
        NSUInteger column = index % 3;
        NSButton *button = [[[NSButton alloc] initWithFrame:NSMakeRect(220 + column * 88,
                                                                       120 + row * 88,
                                                                       80,
                                                                       80)] autorelease];
        [button setTag:(NSInteger)index];
        [button setButtonType:NSMomentaryPushInButton];
        [button setBezelStyle:NSShadowlessSquareBezelStyle];
        [button setFont:[_hostContext interfaceFontOfSize:30.0 bold:YES]];
        [button setTarget:self];
        [button setAction:@selector(squarePressed:)];
        [root addSubview:button];
        [buttons addObject:button];
    }
    _boardButtons = [buttons copy];

    _modeButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(145, 405, 170, 26) pullsDown:NO];
    [_modeButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.twoPlayers" fallback:@"Two players"]];
    [_modeButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.computer" fallback:@"Computer"]];
    [_modeButton setTarget:self];
    [_modeButton setAction:@selector(settingsChanged:)];
    [root addSubview:_modeButton];

    _difficultyButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(325, 405, 150, 26) pullsDown:NO];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.easy" fallback:@"Easy"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.medium" fallback:@"Medium"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.hard" fallback:@"Hard"]];
    [_difficultyButton setTarget:self];
    [_difficultyButton setAction:@selector(settingsChanged:)];
    [root addSubview:_difficultyButton];

    _newRoundButton = [[NSButton alloc] initWithFrame:NSMakeRect(485, 403, 120, 30)];
    [_newRoundButton setTitle:[_hostContext localizedStringForKey:@"game.newRound" fallback:@"New round"]];
    [_newRoundButton setTarget:self];
    [_newRoundButton setAction:@selector(newRound:)];
    [root addSubview:_newRoundButton];

    [self refreshFromEngine];
}

- (void)layoutBoard {
    CGFloat width = NSWidth([[self view] bounds]);
    CGFloat boardWidth = 256.0;
    CGFloat originX = floor((width - boardWidth) / 2.0);
    NSUInteger index = 0;
    for (index = 0; index < [_boardButtons count]; index++) {
        NSUInteger row = index / 3;
        NSUInteger column = index % 3;
        [[_boardButtons objectAtIndex:index] setFrame:NSMakeRect(originX + column * 88.0,
                                                                 120.0 + row * 88.0,
                                                                 80.0,
                                                                 80.0)];
    }
}

- (void)refreshFromEngine {
    if (![self isViewLoaded]) return;
    [self layoutBoard];
    [_modeButton selectItemAtIndex:[_engine mode]];
    [_difficultyButton selectItemAtIndex:[_engine difficulty]];
    [_difficultyButton setEnabled:([_engine mode] == TGTicTacToeModeComputer)];
    NSArray *board = [_engine board];
    NSUInteger index = 0;
    for (index = 0; index < 9; index++) {
        NSButton *button = [_boardButtons objectAtIndex:index];
        NSString *title = [board objectAtIndex:index];
        [button setTitle:title];
        [button setEnabled:([[_engine winner] length] == 0 && [[board objectAtIndex:index] length] == 0)];
        if ([title length] > 0) {
            NSColor *markColor = [[_hostContext themeColors] objectForKey:
                                  ([[_engine winningIndexes] containsIndex:index] ? @"accent" : @"text")];
            NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [_hostContext interfaceFontOfSize:30.0 bold:YES], NSFontAttributeName,
                                        markColor ? markColor : [NSColor controlTextColor], NSForegroundColorAttributeName,
                                        nil];
            NSAttributedString *attributedTitle = [[[NSAttributedString alloc] initWithString:title
                                                                                   attributes:attributes] autorelease];
            [button setAttributedTitle:attributedTitle];
        }
    }
    NSString *winner = [_engine winner];
    NSString *status = nil;
    if ([winner isEqualToString:@"draw"]) {
        status = [_hostContext localizedStringForKey:@"game.draw" fallback:@"Draw"];
    } else if ([winner length] > 0) {
        status = [NSString stringWithFormat:[_hostContext localizedStringForKey:@"game.winner" fallback:@"%@ wins"], winner];
    } else {
        status = [NSString stringWithFormat:[_hostContext localizedStringForKey:@"game.turn" fallback:@"%@ to move"],
                  [_engine currentPlayer]];
    }
    [_statusField setStringValue:status];
    [_scoreField setStringValue:[NSString stringWithFormat:@"X %lu  •  O %lu  •  %@ %lu",
                                 (unsigned long)[_engine xWins],
                                 (unsigned long)[_engine oWins],
                                 [_hostContext localizedStringForKey:@"game.draws" fallback:@"Draws"],
                                 (unsigned long)[_engine draws]]];
    NSColor *text = [[_hostContext themeColors] objectForKey:@"text"];
    [_statusField setTextColor:text ? text : [NSColor textColor]];
    [_scoreField setTextColor:text ? text : [NSColor secondarySelectedControlColor]];
}

- (void)squarePressed:(id)sender {
    if ([_engine playAtIndex:(NSUInteger)[sender tag]]) {
        if ([_engine mode] == TGTicTacToeModeComputer && [[_engine winner] length] == 0) {
            [_engine performComputerMove];
        }
        [self refreshFromEngine];
    }
}

- (void)newRound:(id)sender {
    (void)sender;
    [_engine newRound];
    [self refreshFromEngine];
}

- (void)settingsChanged:(id)sender {
    (void)sender;
    [_engine setMode:(TGTicTacToeMode)[_modeButton indexOfSelectedItem]];
    [_engine setDifficulty:(TGTicTacToeDifficulty)[_difficultyButton indexOfSelectedItem]];
    [_engine newRound];
    [self refreshFromEngine];
}

- (void)dealloc {
    [_engine release];
    [_hostContext release];
    [_boardButtons release];
    [_statusField release];
    [_scoreField release];
    [_modeButton release];
    [_difficultyButton release];
    [_newRoundButton release];
    [super dealloc];
}

@end
