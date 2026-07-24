#import "TGPacManBoardView.h"
#import "../../Sources/Workshop/UI/TGWorkshopSurfaceView.h"
#include <math.h>

@implementation TGPacManBoardView

@synthesize pendingDirection = _pendingDirection;

- (id)initWithFrame:(NSRect)frame engine:(TGPacManEngine *)engine {
    self = [super initWithFrame:frame];
    if (self) {
        _engine = [engine retain];
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)isFlipped { return YES; }

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if ([self window]) [[self window] makeFirstResponder:self];
}

- (void)setTarget:(id)target action:(SEL)action {
    _target = target;
    _action = action;
}

- (void)keyDown:(NSEvent *)event {
    TGPacManDirection direction = TGPacManDirectionNone;
    NSString *characters = [event charactersIgnoringModifiers];
    unichar key = [characters length] ? [characters characterAtIndex:0] : 0;
    if (key == NSLeftArrowFunctionKey || key == 'a' || key == 'A') direction = TGPacManDirectionLeft;
    if (key == NSRightArrowFunctionKey || key == 'd' || key == 'D') direction = TGPacManDirectionRight;
    if (key == NSUpArrowFunctionKey || key == 'w' || key == 'W') direction = TGPacManDirectionUp;
    if (key == NSDownArrowFunctionKey || key == 's' || key == 'S') direction = TGPacManDirectionDown;
    if (direction != TGPacManDirectionNone && _target && _action) {
        _pendingDirection = direction;
        [NSApp sendAction:_action to:_target from:self];
        return;
    }
    [super keyDown:event];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [TGWorkshopFeltPatternColor() setFill];
    NSRectFill([self bounds]);
    CGFloat cellSide = floor(MIN(NSWidth([self bounds]) / (CGFloat)[_engine width],
                                 NSHeight([self bounds]) / (CGFloat)[_engine height]));
    cellSide = MAX(8.0, cellSide);
    CGFloat mazeWidth = cellSide * [_engine width];
    CGFloat mazeHeight = cellSide * [_engine height];
    NSRect mazeRect = NSMakeRect(floor((NSWidth([self bounds]) - mazeWidth) / 2.0),
                                 floor((NSHeight([self bounds]) - mazeHeight) / 2.0),
                                 mazeWidth,
                                 mazeHeight);
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(mazeRect, -7.0, -7.0)
                                                               xRadius:9.0 yRadius:9.0];
    [[NSColor colorWithCalibratedWhite:0.015 alpha:0.96] setFill];
    [background fill];

    NSUInteger index;
    for (index = 0; index < [_engine width] * [_engine height]; index++) {
        NSUInteger row = index / [_engine width];
        NSUInteger column = index % [_engine width];
        NSRect cellRect = NSMakeRect(NSMinX(mazeRect) + column * cellSide,
                                     NSMinY(mazeRect) + row * cellSide,
                                     cellSide,
                                     cellSide);
        if ([_engine isWallAtIndex:index]) {
            NSRect wallRect = NSInsetRect(cellRect, 1.0, 1.0);
            NSBezierPath *wall = [NSBezierPath bezierPathWithRoundedRect:wallRect xRadius:2.0 yRadius:2.0];
            [[NSColor colorWithCalibratedRed:0.10 green:0.32 blue:0.90 alpha:1.0] setFill];
            [wall fill];
            [[NSColor colorWithCalibratedRed:0.24 green:0.62 blue:1.0 alpha:0.86] setStroke];
            [wall setLineWidth:1.0];
            [wall stroke];
        } else if ([_engine hasPelletAtIndex:index]) {
            CGFloat pelletSide = MAX(2.0, floor(cellSide * 0.18));
            NSRect pelletRect = NSMakeRect(NSMidX(cellRect) - pelletSide / 2.0,
                                           NSMidY(cellRect) - pelletSide / 2.0,
                                           pelletSide,
                                           pelletSide);
            [[NSColor colorWithCalibratedRed:1.0 green:0.82 blue:0.56 alpha:0.96] setFill];
            [[NSBezierPath bezierPathWithOvalInRect:pelletRect] fill];
        }
    }

    NSUInteger pacmanRow = [_engine pacmanIndex] / [_engine width];
    NSUInteger pacmanColumn = [_engine pacmanIndex] % [_engine width];
    NSRect pacmanCell = NSMakeRect(NSMinX(mazeRect) + pacmanColumn * cellSide,
                                   NSMinY(mazeRect) + pacmanRow * cellSide,
                                   cellSide,
                                   cellSide);
    NSRect pacmanRect = NSInsetRect(pacmanCell, cellSide * 0.14, cellSide * 0.14);
    NSBezierPath *pacman = [NSBezierPath bezierPath];
    NSPoint center = NSMakePoint(NSMidX(pacmanRect), NSMidY(pacmanRect));
    [pacman moveToPoint:center];
    [pacman appendBezierPathWithArcWithCenter:center
                                       radius:NSWidth(pacmanRect) / 2.0
                                   startAngle:30.0
                                     endAngle:330.0];
    [pacman closePath];
    [[NSColor colorWithCalibratedRed:1.0 green:0.82 blue:0.05 alpha:1.0] setFill];
    [pacman fill];

    NSUInteger ghostRow = [_engine ghostIndex] / [_engine width];
    NSUInteger ghostColumn = [_engine ghostIndex] % [_engine width];
    NSRect ghostCell = NSMakeRect(NSMinX(mazeRect) + ghostColumn * cellSide,
                                  NSMinY(mazeRect) + ghostRow * cellSide,
                                  cellSide,
                                  cellSide);
    NSRect ghostRect = NSInsetRect(ghostCell, cellSide * 0.14, cellSide * 0.14);
    NSBezierPath *ghost = [NSBezierPath bezierPathWithRoundedRect:ghostRect
                                                         xRadius:NSWidth(ghostRect) / 2.0
                                                         yRadius:NSWidth(ghostRect) / 2.0];
    [[NSColor colorWithCalibratedRed:0.92 green:0.12 blue:0.18 alpha:1.0] setFill];
    [ghost fill];
    CGFloat eyeSide = MAX(2.0, cellSide * 0.15);
    [[NSColor whiteColor] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMidX(ghostRect) - eyeSide * 1.2,
                                                       NSMinY(ghostRect) + eyeSide,
                                                       eyeSide, eyeSide)] fill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMidX(ghostRect) + eyeSide * 0.2,
                                                       NSMinY(ghostRect) + eyeSide,
                                                       eyeSide, eyeSide)] fill];
}

- (void)dealloc {
    [_engine release];
    [super dealloc];
}

@end
