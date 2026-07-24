#import "TGTankPatrolViewController.h"
#import "TGTankPatrolEngine.h"
#import "../Common/TGGameUI.h"

@class TGTankPatrolViewController;

@interface TGTankPatrolRootView : TGWorkshopGameSurfaceView {
    TGTankPatrolViewController *_layoutOwner;
}
@property(nonatomic, assign) TGTankPatrolViewController *layoutOwner;
@end

@interface TGTankPatrolBoardView : NSView {
    TGTankPatrolEngine *_engine;
    TGTankPatrolViewController *_owner;
}
- (id)initWithFrame:(NSRect)frame engine:(TGTankPatrolEngine *)engine;
@property(nonatomic, assign) TGTankPatrolViewController *owner;
@end

@interface TGTankPatrolViewController ()
- (void)layoutGame;
- (void)focusBoard;
- (void)newGame:(id)sender;
- (void)playerDidAct;
- (void)simulationTick:(NSTimer *)timer;
@end

@implementation TGTankPatrolRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

static void TGTankDrawTank(NSRect rect, TGTankDirection direction,
                           NSColor *bodyColor, NSColor *detailColor) {
    CGFloat pixel = MAX(1.0, floor(NSWidth(rect) / 12.0));
    NSRect inset = NSInsetRect(rect, pixel * 2.0, pixel * 2.0);
    NSBezierPath *body = [NSBezierPath bezierPathWithRect:inset];
    [bodyColor setFill];
    [body fill];

    NSRect leftTrack = NSMakeRect(NSMinX(rect) + pixel,
                                  NSMinY(rect) + pixel * 2.0,
                                  pixel * 2.0,
                                  NSHeight(rect) - pixel * 4.0);
    NSRect rightTrack = NSMakeRect(NSMaxX(rect) - pixel * 3.0,
                                   NSMinY(rect) + pixel * 2.0,
                                   pixel * 2.0,
                                   NSHeight(rect) - pixel * 4.0);
    [detailColor setFill];
    NSRectFill(leftTrack);
    NSRectFill(rightTrack);

    NSPoint center = NSMakePoint(NSMidX(rect), NSMidY(rect));
    CGFloat turret = pixel * 4.0;
    NSBezierPath *turretPath = [NSBezierPath bezierPathWithRect:
                                NSMakeRect(center.x - turret / 2.0,
                                           center.y - turret / 2.0,
                                           turret, turret)];
    [detailColor setFill];
    [turretPath fill];

    CGFloat barrelWidth = pixel * 2.0;
    NSRect barrel = NSZeroRect;
    if (direction == TGTankDirectionUp) {
        barrel = NSMakeRect(center.x - barrelWidth / 2.0,
                            center.y, barrelWidth, pixel * 5.0);
    } else if (direction == TGTankDirectionDown) {
        barrel = NSMakeRect(center.x - barrelWidth / 2.0,
                            NSMinY(rect) + pixel,
                            barrelWidth, pixel * 5.0);
    } else if (direction == TGTankDirectionLeft) {
        barrel = NSMakeRect(NSMinX(rect) + pixel,
                            center.y - barrelWidth / 2.0,
                            pixel * 5.0, barrelWidth);
    } else {
        barrel = NSMakeRect(center.x,
                            center.y - barrelWidth / 2.0,
                            pixel * 5.0, barrelWidth);
    }
    NSRectFill(barrel);
}

@implementation TGTankPatrolBoardView
@synthesize owner = _owner;

- (id)initWithFrame:(NSRect)frame engine:(TGTankPatrolEngine *)engine {
    self = [super initWithFrame:frame];
    if (self) {
        _engine = [engine retain];
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
    [self setNeedsDisplay:YES];
    return YES;
}

- (void)drawBrickInRect:(NSRect)rect {
    [[NSColor colorWithCalibratedRed:0.74 green:0.24 blue:0.09 alpha:1.0] setFill];
    NSRectFill(NSInsetRect(rect, 1.0, 1.0));
    [[NSColor colorWithCalibratedRed:0.98 green:0.49 blue:0.16 alpha:0.92] setStroke];
    NSBezierPath *lines = [NSBezierPath bezierPath];
    [lines setLineWidth:1.0];
    CGFloat middleY = NSMidY(rect);
    [lines moveToPoint:NSMakePoint(NSMinX(rect) + 1.0, middleY)];
    [lines lineToPoint:NSMakePoint(NSMaxX(rect) - 1.0, middleY)];
    [lines moveToPoint:NSMakePoint(NSMidX(rect), NSMinY(rect) + 1.0)];
    [lines lineToPoint:NSMakePoint(NSMidX(rect), middleY)];
    [lines moveToPoint:NSMakePoint(NSMinX(rect) + NSWidth(rect) * 0.25, middleY)];
    [lines lineToPoint:NSMakePoint(NSMinX(rect) + NSWidth(rect) * 0.25, NSMaxY(rect) - 1.0)];
    [lines moveToPoint:NSMakePoint(NSMinX(rect) + NSWidth(rect) * 0.75, middleY)];
    [lines lineToPoint:NSMakePoint(NSMinX(rect) + NSWidth(rect) * 0.75, NSMaxY(rect) - 1.0)];
    [lines stroke];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    [[NSColor colorWithCalibratedWhite:0.035 alpha:1.0] setFill];
    NSRectFill(bounds);
    NSUInteger size = [_engine boardSize];
    CGFloat cell = floor(MIN(NSWidth(bounds), NSHeight(bounds)) / (CGFloat)size);
    CGFloat boardWidth = cell * size;
    CGFloat originX = floor((NSWidth(bounds) - boardWidth) / 2.0);
    CGFloat originY = floor((NSHeight(bounds) - boardWidth) / 2.0);
    NSInteger y;
    NSInteger x;

    [[NSColor colorWithCalibratedWhite:0.16 alpha:0.28] setStroke];
    NSBezierPath *grid = [NSBezierPath bezierPath];
    [grid setLineWidth:0.5];
    for (x = 0; x <= (NSInteger)size; x++) {
        [grid moveToPoint:NSMakePoint(originX + x * cell, originY)];
        [grid lineToPoint:NSMakePoint(originX + x * cell, originY + boardWidth)];
    }
    for (y = 0; y <= (NSInteger)size; y++) {
        [grid moveToPoint:NSMakePoint(originX, originY + y * cell)];
        [grid lineToPoint:NSMakePoint(originX + boardWidth, originY + y * cell)];
    }
    [grid stroke];

    for (y = 0; y < (NSInteger)size; y++) {
        for (x = 0; x < (NSInteger)size; x++) {
            NSRect tile = NSMakeRect(originX + x * cell, originY + y * cell, cell, cell);
            NSInteger terrain = [_engine terrainAtX:x y:y];
            if (terrain == 1) {
                [self drawBrickInRect:tile];
            } else if (terrain == 2) {
                [[NSColor colorWithCalibratedWhite:0.70 alpha:1.0] setFill];
                NSRectFill(NSInsetRect(tile, 1.0, 1.0));
                [[NSColor colorWithCalibratedWhite:0.96 alpha:0.76] setFill];
                NSRectFill(NSMakeRect(NSMinX(tile) + 2.0, NSMinY(tile) + 2.0,
                                      NSWidth(tile) - 4.0, 2.0));
            } else if (terrain == 3) {
                [[NSColor colorWithCalibratedRed:0.82 green:0.71 blue:0.22 alpha:1.0] setFill];
                NSBezierPath *base = [NSBezierPath bezierPath];
                [base moveToPoint:NSMakePoint(NSMidX(tile), NSMinY(tile) + 3.0)];
                [base lineToPoint:NSMakePoint(NSMaxX(tile) - 3.0, NSMidY(tile))];
                [base lineToPoint:NSMakePoint(NSMidX(tile), NSMaxY(tile) - 3.0)];
                [base lineToPoint:NSMakePoint(NSMinX(tile) + 3.0, NSMidY(tile))];
                [base closePath];
                [base fill];
                [[NSColor colorWithCalibratedRed:0.24 green:0.12 blue:0.04 alpha:1.0] setStroke];
                [base setLineWidth:2.0];
                [base stroke];
            }
        }
    }

    for (NSDictionary *enemy in [_engine enemies]) {
        NSInteger enemyX = [[enemy objectForKey:@"x"] integerValue];
        NSInteger enemyY = [[enemy objectForKey:@"y"] integerValue];
        TGTankDirection direction = (TGTankDirection)[[enemy objectForKey:@"direction"] integerValue];
        NSRect tile = NSMakeRect(originX + enemyX * cell, originY + enemyY * cell, cell, cell);
        TGTankDrawTank(tile, direction,
                       [NSColor colorWithCalibratedRed:0.67 green:0.13 blue:0.12 alpha:1.0],
                       [NSColor colorWithCalibratedRed:0.96 green:0.54 blue:0.16 alpha:1.0]);
    }

    NSRect playerTile = NSMakeRect(originX + [_engine playerX] * cell,
                                   originY + [_engine playerY] * cell,
                                   cell, cell);
    TGTankDrawTank(playerTile, [_engine playerDirection],
                   [NSColor colorWithCalibratedRed:0.92 green:0.76 blue:0.24 alpha:1.0],
                   [NSColor colorWithCalibratedRed:0.98 green:0.94 blue:0.72 alpha:1.0]);

    for (NSDictionary *bullet in [_engine bullets]) {
        NSInteger bulletX = [[bullet objectForKey:@"x"] integerValue];
        NSInteger bulletY = [[bullet objectForKey:@"y"] integerValue];
        if (bulletX < 0 || bulletY < 0 ||
            bulletX >= (NSInteger)size || bulletY >= (NSInteger)size) continue;
        NSRect tile = NSMakeRect(originX + bulletX * cell, originY + bulletY * cell, cell, cell);
        CGFloat bulletSize = MAX(4.0, floor(cell * 0.22));
        NSRect bulletRect = NSMakeRect(NSMidX(tile) - bulletSize / 2.0,
                                       NSMidY(tile) - bulletSize / 2.0,
                                       bulletSize, bulletSize);
        NSColor *bulletColor = [[bullet objectForKey:@"enemy"] boolValue]
            ? [NSColor colorWithCalibratedRed:1.0 green:0.28 blue:0.12 alpha:1.0]
            : [NSColor colorWithCalibratedRed:1.0 green:0.95 blue:0.52 alpha:1.0];
        [bulletColor setFill];
        NSRectFill(bulletRect);
    }

    for (y = 0; y < (NSInteger)size; y++) {
        for (x = 0; x < (NSInteger)size; x++) {
            if ([_engine terrainAtX:x y:y] != 4) continue;
            NSRect tile = NSMakeRect(originX + x * cell, originY + y * cell, cell, cell);
            [[NSColor colorWithCalibratedRed:0.25 green:0.70 blue:0.13 alpha:0.86] setFill];
            CGFloat leaf = MAX(2.0, floor(cell / 4.0));
            NSInteger leafIndex = 0;
            for (leafIndex = 0; leafIndex < 8; leafIndex++) {
                CGFloat leafX = NSMinX(tile) + (leafIndex % 3) * leaf * 1.25;
                CGFloat leafY = NSMinY(tile) + (leafIndex / 3) * leaf * 1.15;
                NSRectFill(NSMakeRect(leafX, leafY, leaf, leaf));
            }
        }
    }

    [[NSColor colorWithCalibratedRed:0.88 green:0.74 blue:0.25 alpha:0.70] setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:
                            NSMakeRect(originX - 1.0, originY - 1.0,
                                       boardWidth + 2.0, boardWidth + 2.0)];
    [border setLineWidth:2.0];
    [border stroke];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    [[self window] makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)event {
    unsigned short keyCode = [event keyCode];
    NSString *characters = [[event charactersIgnoringModifiers] lowercaseString];
    BOOL handled = YES;
    if (keyCode == 126 || [characters isEqualToString:@"w"]) {
        [_engine movePlayerInDirection:TGTankDirectionUp];
    } else if (keyCode == 124 || [characters isEqualToString:@"d"]) {
        [_engine movePlayerInDirection:TGTankDirectionRight];
    } else if (keyCode == 125 || [characters isEqualToString:@"s"]) {
        [_engine movePlayerInDirection:TGTankDirectionDown];
    } else if (keyCode == 123 || [characters isEqualToString:@"a"]) {
        [_engine movePlayerInDirection:TGTankDirectionLeft];
    } else if (keyCode == 49 || [characters isEqualToString:@" "]) {
        [_engine fire];
    } else {
        handled = NO;
    }
    if (handled) {
        [_owner playerDidAct];
        [self setNeedsDisplay:YES];
    } else {
        [super keyDown:event];
    }
}

- (void)dealloc {
    [_engine release];
    [super dealloc];
}
@end

@implementation TGTankPatrolViewController

- (id)initWithEngine:(TGTankPatrolEngine *)engine
         hostContext:(id<TGWorkshopHostContext>)hostContext {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [hostContext retain];
    }
    return self;
}

- (void)loadView {
    TGTankPatrolRootView *root = [[[TGTankPatrolRootView alloc]
                                  initWithFrame:NSMakeRect(0, 0, 760, 590)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGGameLabel(NSZeroRect, 20.0, YES, _hostContext) retain];
    [_titleField setAlignment:NSCenterTextAlignment];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"tankpatrol.title"
                                                            fallback:@"Tank Patrol"]];
    [root addSubview:_titleField];

    _statusField = [TGGameLabel(NSZeroRect, 13.0, YES, _hostContext) retain];
    [_statusField setAlignment:NSCenterTextAlignment];
    [root addSubview:_statusField];

    _scoreField = [TGGameLabel(NSZeroRect, 11.0, NO, _hostContext) retain];
    [_scoreField setAlignment:NSCenterTextAlignment];
    [root addSubview:_scoreField];

    _boardView = [[TGTankPatrolBoardView alloc] initWithFrame:NSZeroRect engine:_engine];
    [_boardView setOwner:self];
    [root addSubview:_boardView];

    _newGameButton = [TGGameThemedButton(NSZeroRect,
                                         [_hostContext localizedStringForKey:@"game.newGame"
                                                                    fallback:@"New game"],
                                         @"refresh",
                                         _hostContext) retain];
    [_newGameButton setTarget:self];
    [_newGameButton setAction:@selector(newGame:)];
    [root addSubview:_newGameButton];
    [self layoutGame];
    [self refreshFromEngine];
    _gameTimer = [[NSTimer scheduledTimerWithTimeInterval:0.12
                                                    target:self
                                                  selector:@selector(simulationTick:)
                                                  userInfo:nil
                                                   repeats:YES] retain];
    [self performSelector:@selector(focusBoard) withObject:nil afterDelay:0.0];
}

- (void)layoutGame {
    if (!_boardView) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat boardSide = floor(MIN(500.0, MIN(width - 36.0, height - 132.0)));
    boardSide = MAX(286.0, boardSide);
    CGFloat boardX = floor((width - boardSide) / 2.0);
    CGFloat boardY = floor(58.0 + (height - 132.0 - boardSide) / 2.0);
    [_titleField setFrame:NSMakeRect(18.0, height - 37.0, width - 36.0, 25.0)];
    [_statusField setFrame:NSMakeRect(18.0, height - 60.0, width - 36.0, 18.0)];
    [_scoreField setFrame:NSMakeRect(18.0, height - 81.0, width - 36.0, 18.0)];
    [_boardView setFrame:NSMakeRect(boardX, boardY, boardSide, boardSide)];
    [_newGameButton setFrame:NSMakeRect(floor((width - 180.0) / 2.0), 14.0, 180.0, 34.0)];
}

- (void)focusBoard {
    if ([[_boardView window] isVisible]) {
        [[_boardView window] makeFirstResponder:_boardView];
    }
}

- (void)refreshFromEngine {
    NSString *statusKey = @"tankpatrol.hint";
    NSString *fallback = @"Arrows or WASD move. Space fires. Protect the base.";
    if ([_engine isFinished]) {
        statusKey = [_engine didWin] ? @"tankpatrol.won" : @"tankpatrol.lost";
        fallback = [_engine didWin] ? @"Sector secured!" : @"The base was lost.";
    }
    [_statusField setStringValue:[_hostContext localizedStringForKey:statusKey fallback:fallback]];
    [_scoreField setStringValue:
     [NSString stringWithFormat:@"%@ %lu  •  %@ %lu  •  %@ %lu",
      [_hostContext localizedStringForKey:@"game.score" fallback:@"Score"],
      (unsigned long)[_engine score],
      [_hostContext localizedStringForKey:@"game.lives" fallback:@"Lives"],
      (unsigned long)[_engine lives],
      [_hostContext localizedStringForKey:@"tankpatrol.enemies" fallback:@"Enemies"],
      (unsigned long)[[_engine enemies] count]]];
    [_boardView setNeedsDisplay:YES];
}

- (void)playerDidAct {
    [self refreshFromEngine];
}

- (void)simulationTick:(NSTimer *)timer {
    (void)timer;
    if (![[self view] window] || [[self view] isHidden]) return;
    [_engine advanceSimulation];
    [self refreshFromEngine];
}

- (void)stopSimulation {
    [_gameTimer invalidate];
    [_gameTimer release];
    _gameTimer = nil;
}

- (void)newGame:(id)sender {
    (void)sender;
    [_engine newGame];
    [self refreshFromEngine];
    [self focusBoard];
}

- (void)dealloc {
    [self stopSimulation];
    [_engine release];
    [_hostContext release];
    [_boardView release];
    [_titleField release];
    [_statusField release];
    [_scoreField release];
    [_newGameButton release];
    [super dealloc];
}

@end
