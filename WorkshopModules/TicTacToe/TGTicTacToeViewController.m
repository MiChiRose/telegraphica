#import "TGTicTacToeViewController.h"
#import "../Common/TGGameUI.h"

@class TGTicTacToeViewController;

@interface TGTicTacToeRootView : TGWorkshopGameSurfaceView {
    TGTicTacToeViewController *_layoutOwner;
}
@property(nonatomic, assign) TGTicTacToeViewController *layoutOwner;
@end

@interface TGTicTacToeViewController ()
- (void)layoutGame;
@end

@implementation TGTicTacToeRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

@interface TGTicTacToeSquareCell : NSButtonCell
@end

@implementation TGTicTacToeSquareCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    NSRect rect = NSInsetRect(cellFrame, 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:7.0 yRadius:7.0];
    NSColor *top = [self isHighlighted]
        ? [NSColor colorWithCalibratedRed:0.36 green:0.065 blue:0.13 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.54 green:0.075 blue:0.18 alpha:1.0];
    NSGradient *gradient = [[[NSGradient alloc]
                             initWithStartingColor:top
                             endingColor:TGWorkshopBurgundyColor()] autorelease];
    [gradient drawInBezierPath:path angle:90.0];
    [TGWorkshopGoldColor() setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    NSAttributedString *title = [self attributedTitle];
    if ([[title string] length] == 0) return;
    NSSize size = [title size];
    [title drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2.0,
                                   NSMidY(rect) - size.height / 2.0)];
}

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
    TGTicTacToeRootView *root = [[[TGTicTacToeRootView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGTicTacToeLabel(NSZeroRect,
                                    [_hostContext interfaceFontOfSize:20.0 bold:YES]) retain];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"tictactoe.title" fallback:@"Tic-Tac-Toe"]];
    [_titleField setTextColor:TGWorkshopCreamColor()];
    [root addSubview:_titleField];

    _statusField = [TGTicTacToeLabel(NSZeroRect,
                                     [_hostContext interfaceFontOfSize:13.0 bold:YES]) retain];
    [_statusField setTextColor:TGWorkshopGoldColor()];
    [root addSubview:_statusField];
    _scoreField = [TGTicTacToeLabel(NSZeroRect,
                                    [_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [_scoreField setTextColor:TGWorkshopMutedCreamColor()];
    [root addSubview:_scoreField];

    NSMutableArray *buttons = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < 9; index++) {
        NSButton *button = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
        TGTicTacToeSquareCell *cell = [[[TGTicTacToeSquareCell alloc] initTextCell:@""] autorelease];
        [cell setButtonType:NSMomentaryPushInButton];
        [button setCell:cell];
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

    _modeButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_modeButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.twoPlayers" fallback:@"Two players"]];
    [_modeButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.computer" fallback:@"Computer"]];
    [_modeButton setTarget:self];
    [_modeButton setAction:@selector(settingsChanged:)];
    [root addSubview:_modeButton];

    _difficultyButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.easy" fallback:@"Easy"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.medium" fallback:@"Medium"]];
    [_difficultyButton addItemWithTitle:[_hostContext localizedStringForKey:@"game.hard" fallback:@"Hard"]];
    [_difficultyButton setTarget:self];
    [_difficultyButton setAction:@selector(settingsChanged:)];
    [root addSubview:_difficultyButton];

    _newRoundButton = [TGGameThemedButton(NSZeroRect,
                                           [_hostContext localizedStringForKey:@"game.newRound" fallback:@"New round"],
                                           @"refresh",
                                           _hostContext) retain];
    [_newRoundButton setTarget:self];
    [_newRoundButton setAction:@selector(newRound:)];
    [root addSubview:_newRoundButton];

    [self layoutGame];
    [self refreshFromEngine];
}

- (void)layoutGame {
    if (!_titleField || [_boardButtons count] != 9) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(620.0, MAX(320.0, width - 28.0));
    CGFloat contentX = floor((width - contentWidth) / 2.0);

    [_titleField setFrame:NSMakeRect(contentX, height - 42.0, contentWidth, 28.0)];
    [_statusField setFrame:NSMakeRect(contentX, height - 66.0, contentWidth, 20.0)];
    [_scoreField setFrame:NSMakeRect(contentX, height - 87.0, contentWidth, 18.0)];

    CGFloat controlsWidth = MIN(456.0, contentWidth);
    CGFloat controlsX = floor((width - controlsWidth) / 2.0);
    CGFloat modeWidth = MIN(170.0, floor(controlsWidth * 0.37));
    CGFloat difficultyWidth = MIN(150.0, floor(controlsWidth * 0.32));
    CGFloat buttonWidth = controlsWidth - modeWidth - difficultyWidth - 16.0;
    [_modeButton setFrame:NSMakeRect(controlsX, 18.0, modeWidth, 28.0)];
    [_difficultyButton setFrame:NSMakeRect(controlsX + modeWidth + 8.0, 18.0,
                                           difficultyWidth, 28.0)];
    [_newRoundButton setFrame:NSMakeRect(controlsX + modeWidth + difficultyWidth + 16.0,
                                         16.0, buttonWidth, 32.0)];

    CGFloat boardTop = height - 100.0;
    CGFloat boardBottom = 62.0;
    CGFloat availableBoardHeight = MAX(180.0, boardTop - boardBottom);
    CGFloat cellSide = floor(MIN(82.0, (availableBoardHeight - 4.0) / 3.0));
    cellSide = MAX(54.0, cellSide);
    CGFloat cellGap = 2.0;
    CGFloat boardSide = cellSide * 3.0 + cellGap * 2.0;
    CGFloat boardX = floor((width - boardSide) / 2.0);
    CGFloat boardY = floor(boardBottom + (availableBoardHeight - boardSide) / 2.0);
    NSUInteger index = 0;
    for (index = 0; index < 9; index++) {
        NSUInteger row = index / 3;
        NSUInteger column = index % 3;
        NSButton *button = [_boardButtons objectAtIndex:index];
        [button setFrame:NSMakeRect(boardX + column * (cellSide + cellGap),
                                    boardY + (2 - row) * (cellSide + cellGap),
                                    cellSide,
                                    cellSide)];
    }
}

- (void)refreshFromEngine {
    if (!_statusField) return;
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
            NSColor *markColor = [[_engine winningIndexes] containsIndex:index]
                ? TGWorkshopGoldColor()
                : TGWorkshopCreamColor();
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
    [_statusField setTextColor:TGWorkshopCreamColor()];
    [_scoreField setTextColor:TGWorkshopMutedCreamColor()];
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
    [_titleField release];
    [_statusField release];
    [_scoreField release];
    [_modeButton release];
    [_difficultyButton release];
    [_newRoundButton release];
    [super dealloc];
}

@end
