#import "TGFifteenViewController.h"
#import "TGFifteenEngine.h"
#import "../Common/TGGameUI.h"

@class TGFifteenViewController;

@interface TGFifteenRootView : TGWorkshopGameSurfaceView {
    TGFifteenViewController *_layoutOwner;
}
@property(nonatomic, assign) TGFifteenViewController *layoutOwner;
@end

@interface TGFifteenViewController ()
- (void)layoutGame;
@end

@implementation TGFifteenRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

@interface TGFifteenTileCell : NSButtonCell
@end

@implementation TGFifteenTileCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    (void)controlView;
    NSRect rect = NSInsetRect(cellFrame, 2.0, 2.0);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8.0 yRadius:8.0];
    NSColor *top = [self isHighlighted]
        ? [NSColor colorWithCalibratedRed:0.55 green:0.36 blue:0.09 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.95 green:0.83 blue:0.40 alpha:1.0];
    NSColor *bottom = [self isHighlighted]
        ? [NSColor colorWithCalibratedRed:0.68 green:0.49 blue:0.13 alpha:1.0]
        : [NSColor colorWithCalibratedRed:0.70 green:0.49 blue:0.12 alpha:1.0];
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
    [gradient drawInBezierPath:path angle:90.0];
    [[NSColor colorWithCalibratedRed:0.20 green:0.12 blue:0.035 alpha:0.92] setStroke];
    [path setLineWidth:1.0];
    [path stroke];

    NSString *title = [self title];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:22.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedRed:0.11 green:0.13 blue:0.07 alpha:1.0],
                                NSForegroundColorAttributeName,
                                nil];
    NSSize size = [title sizeWithAttributes:attributes];
    [title drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2.0,
                                   NSMidY(rect) - size.height / 2.0)
        withAttributes:attributes];
}
@end

static NSTextField *TGFifteenLabel(NSFont *font) {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setAlignment:NSCenterTextAlignment];
    return field;
}

@implementation TGFifteenViewController

- (id)initWithEngine:(TGFifteenEngine *)engine
         hostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [hostContext retain];
    }
    return self;
}

- (void)loadView {
    TGFifteenRootView *root = [[[TGFifteenRootView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGFifteenLabel([_hostContext interfaceFontOfSize:20.0 bold:YES]) retain];
    [_titleField setTextColor:TGWorkshopCreamColor()];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"fifteen.title" fallback:@"Fifteen"]];
    [root addSubview:_titleField];

    _statusField = [TGFifteenLabel([_hostContext interfaceFontOfSize:13.0 bold:YES]) retain];
    [_statusField setTextColor:TGWorkshopGoldColor()];
    [root addSubview:_statusField];

    _scoreField = [TGFifteenLabel([_hostContext interfaceFontOfSize:11.0 bold:NO]) retain];
    [_scoreField setTextColor:TGWorkshopMutedCreamColor()];
    [root addSubview:_scoreField];

    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:16];
    NSUInteger index = 0;
    for (index = 0; index < 16; index++) {
        NSButton *button = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
        TGFifteenTileCell *cell = [[[TGFifteenTileCell alloc] initTextCell:@""] autorelease];
        [cell setButtonType:NSMomentaryPushInButton];
        [button setCell:cell];
        [button setBordered:NO];
        [button setTag:(NSInteger)index];
        [button setTarget:self];
        [button setAction:@selector(tilePressed:)];
        [root addSubview:button];
        [buttons addObject:button];
    }
    _tileButtons = [buttons copy];

    _newGameButton = [TGGameThemedButton(NSZeroRect,
                                          [_hostContext localizedStringForKey:@"game.newGame" fallback:@"New game"],
                                          @"refresh",
                                          _hostContext) retain];
    [_newGameButton setTarget:self];
    [_newGameButton setAction:@selector(newGame:)];
    [root addSubview:_newGameButton];

    [self layoutGame];
    [self refreshFromEngine];
}

- (void)layoutGame {
    if ([_tileButtons count] != 16) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat boardSize = floor(MIN(340.0, MIN(width - 36.0, height - 160.0)));
    boardSize = MAX(220.0, boardSize);
    CGFloat boardX = floor((width - boardSize) / 2.0);
    CGFloat boardY = floor((height - boardSize) / 2.0) - 10.0;
    CGFloat gap = 5.0;
    CGFloat tileSize = floor((boardSize - gap * 3.0) / 4.0);

    [_titleField setFrame:NSMakeRect(18.0, height - 42.0, width - 36.0, 28.0)];
    [_statusField setFrame:NSMakeRect(18.0, height - 66.0, width - 36.0, 20.0)];
    [_scoreField setFrame:NSMakeRect(18.0, height - 87.0, width - 36.0, 18.0)];

    NSUInteger index = 0;
    for (index = 0; index < 16; index++) {
        NSUInteger row = index / 4;
        NSUInteger column = index % 4;
        NSButton *button = [_tileButtons objectAtIndex:index];
        [button setFrame:NSMakeRect(boardX + column * (tileSize + gap),
                                    boardY + (3 - row) * (tileSize + gap),
                                    tileSize,
                                    tileSize)];
    }
    [_newGameButton setFrame:NSMakeRect(floor((width - 180.0) / 2.0), 16.0, 180.0, 34.0)];
}

- (void)refreshFromEngine {
    NSArray *tiles = [_engine tiles];
    NSUInteger index = 0;
    for (index = 0; index < 16; index++) {
        NSButton *button = [_tileButtons objectAtIndex:index];
        NSUInteger value = [[tiles objectAtIndex:index] unsignedIntegerValue];
        [button setTitle:value == 0 ? @"" : [NSString stringWithFormat:@"%lu", (unsigned long)value]];
        [button setHidden:(value == 0)];
        [button setEnabled:[_engine canMoveTileAtIndex:index]];
        [button setNeedsDisplay:YES];
    }
    [_statusField setStringValue:([_engine isFinished]
                                   ? [_hostContext localizedStringForKey:@"fifteen.solved" fallback:@"Solved!"]
                                   : [_hostContext localizedStringForKey:@"fifteen.hint" fallback:@"Arrange the tiles from 1 to 15"])];
    [_scoreField setStringValue:[NSString stringWithFormat:@"%@ %lu  •  %@ %lu",
                                 [_hostContext localizedStringForKey:@"game.moves" fallback:@"Moves"],
                                 (unsigned long)[_engine moves],
                                 [_hostContext localizedStringForKey:@"game.wins" fallback:@"Wins"],
                                 (unsigned long)[_engine gamesWon]]];
}

- (void)tilePressed:(id)sender {
    if ([sender isKindOfClass:[NSButton class]] &&
        [_engine moveTileAtIndex:(NSUInteger)[sender tag]]) {
        [self refreshFromEngine];
    }
}

- (void)newGame:(id)sender {
    (void)sender;
    [_engine newGame];
    [self refreshFromEngine];
}

- (void)dealloc {
    [_engine release];
    [_hostContext release];
    [_titleField release];
    [_statusField release];
    [_scoreField release];
    [_tileButtons release];
    [_newGameButton release];
    [super dealloc];
}

@end
