#import "TGSolitaireBoardView.h"
#import "../../Sources/Workshop/UI/TGWorkshopSurfaceView.h"

static const CGFloat TGSolitaireCardWidth = 72.0;
static const CGFloat TGSolitaireCardHeight = 102.0;
static const CGFloat TGSolitaireHorizontalGap = 16.0;
static const CGFloat TGSolitaireFaceDownOffset = 15.0;
static const CGFloat TGSolitaireFaceUpOffset = 27.0;

@interface TGSolitaireBoardView ()
- (CGFloat)boardOriginX;
- (CGFloat)topRowY;
- (NSRect)topRectAtColumn:(NSInteger)column;
- (NSRect)tableauCardRectForPile:(NSInteger)pile cardIndex:(NSInteger)cardIndex;
- (void)drawCard:(NSInteger)card inRect:(NSRect)rect faceUp:(BOOL)faceUp translucent:(BOOL)translucent;
- (void)notifyChanged;
@end

@implementation TGSolitaireBoardView

- (id)initWithFrame:(NSRect)frame engine:(TGSolitaireEngine *)engine themeColors:(NSDictionary *)colors {
    self = [super initWithFrame:frame];
    if (self) {
        _engine = [engine retain];
        _themeColors = [colors copy];
        _dragSource = TGSolitaireSourceNone;
        [self setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    }
    return self;
}

- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)setTarget:(id)target action:(SEL)action {
    _target = target;
    _action = action;
}

- (CGFloat)boardOriginX {
    CGFloat totalWidth = 7.0 * TGSolitaireCardWidth + 6.0 * TGSolitaireHorizontalGap;
    return floor((NSWidth([self bounds]) - totalWidth) / 2.0);
}

- (CGFloat)topRowY {
    return NSHeight([self bounds]) - TGSolitaireCardHeight - 18.0;
}

- (NSRect)topRectAtColumn:(NSInteger)column {
    return NSMakeRect([self boardOriginX] + column * (TGSolitaireCardWidth + TGSolitaireHorizontalGap),
                      [self topRowY], TGSolitaireCardWidth, TGSolitaireCardHeight);
}

- (NSRect)tableauCardRectForPile:(NSInteger)pile cardIndex:(NSInteger)cardIndex {
    NSArray *cards = [_engine tableauCardsAtIndex:pile];
    CGFloat y = [self topRowY] - TGSolitaireCardHeight - 28.0;
    NSInteger index;
    for (index = 0; index < cardIndex; index++) {
        NSInteger card = [[cards objectAtIndex:(NSUInteger)index] integerValue];
        y -= [_engine isCardFaceUp:card] ? TGSolitaireFaceUpOffset : TGSolitaireFaceDownOffset;
    }
    return NSMakeRect([self boardOriginX] + pile * (TGSolitaireCardWidth + TGSolitaireHorizontalGap),
                      y, TGSolitaireCardWidth, TGSolitaireCardHeight);
}

- (void)drawEmptySlot:(NSRect)rect symbol:(NSString *)symbol {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:7 yRadius:7];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.16] setFill];
    [path fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.38] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    if ([symbol length]) {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:24], NSFontAttributeName,
                                    [NSColor colorWithCalibratedWhite:1.0 alpha:0.42], NSForegroundColorAttributeName, nil];
        NSSize size = [symbol sizeWithAttributes:attributes];
        [symbol drawAtPoint:NSMakePoint(NSMidX(rect) - size.width / 2.0,
                                        NSMidY(rect) - size.height / 2.0)
             withAttributes:attributes];
    }
}

- (void)drawCard:(NSInteger)card inRect:(NSRect)rect faceUp:(BOOL)faceUp translucent:(BOOL)translucent {
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    (void)translucent;
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:2.0];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0 alpha:0.28]];
    [shadow set];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:6 yRadius:6];
    if (!faceUp) {
        [[NSColor colorWithCalibratedRed:0.18 green:0.39 blue:0.62 alpha:1.0] setFill];
        [path fill];
        [[NSColor colorWithCalibratedRed:0.77 green:0.88 blue:0.96 alpha:1.0] setStroke];
        [path setLineWidth:2.0];
        [path stroke];
        NSRect inner = NSInsetRect(rect, 7, 7);
        NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:inner xRadius:4 yRadius:4];
        [[NSColor colorWithCalibratedWhite:1 alpha:0.22] setStroke];
        [innerPath setLineWidth:1.0];
        [innerPath stroke];
    } else {
        [[NSColor colorWithCalibratedWhite:0.98 alpha:1.0] setFill];
        [path fill];
        [[NSColor colorWithCalibratedWhite:0.66 alpha:1.0] setStroke];
        [path setLineWidth:1.0];
        [path stroke];
        NSString *name = [_engine shortNameForCard:card];
        NSColor *color = [_engine isRedCard:card] ? [NSColor colorWithCalibratedRed:0.76 green:0.12 blue:0.16 alpha:1.0]
                                                  : [NSColor colorWithCalibratedWhite:0.10 alpha:1.0];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:17], NSFontAttributeName,
                                    color, NSForegroundColorAttributeName, nil];
        [name drawAtPoint:NSMakePoint(NSMinX(rect) + 6, NSMaxY(rect) - 25) withAttributes:attributes];
        NSDictionary *largeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont systemFontOfSize:30], NSFontAttributeName,
                                         color, NSForegroundColorAttributeName, nil];
        NSString *suit = [name substringFromIndex:[name length] - 1];
        NSSize suitSize = [suit sizeWithAttributes:largeAttributes];
        [suit drawAtPoint:NSMakePoint(NSMidX(rect) - suitSize.width / 2.0,
                                      NSMidY(rect) - suitSize.height / 2.0)
           withAttributes:largeAttributes];
    }
    [context restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [TGWorkshopFeltPatternColor() setFill];
    NSRectFill([self bounds]);

    NSRect stockRect = [self topRectAtColumn:0];
    if ([_engine stockCount] > 0) [self drawCard:0 inRect:stockRect faceUp:NO translucent:NO];
    else [self drawEmptySlot:stockRect symbol:@"↻"];

    NSRect wasteRect = [self topRectAtColumn:1];
    NSInteger wasteCard = [_engine wasteCard];
    if (wasteCard >= 0) [self drawCard:wasteCard inRect:wasteRect faceUp:YES translucent:NO];
    else [self drawEmptySlot:wasteRect symbol:@""];

    NSInteger suit;
    for (suit = 0; suit < 4; suit++) {
        NSRect rect = [self topRectAtColumn:suit + 3];
        NSInteger card = [_engine foundationTopCardForSuit:suit];
        if (card >= 0) [self drawCard:card inRect:rect faceUp:YES translucent:NO];
        else {
            NSArray *symbols = [NSArray arrayWithObjects:@"♠", @"♥", @"♦", @"♣", nil];
            [self drawEmptySlot:rect symbol:[symbols objectAtIndex:(NSUInteger)suit]];
        }
    }

    NSInteger pile;
    for (pile = 0; pile < 7; pile++) {
        NSArray *cards = [_engine tableauCardsAtIndex:pile];
        if ([cards count] == 0) {
            [self drawEmptySlot:[self tableauCardRectForPile:pile cardIndex:0] symbol:@"K"];
            continue;
        }
        NSInteger cardIndex;
        for (cardIndex = 0; cardIndex < (NSInteger)[cards count]; cardIndex++) {
            NSInteger card = [[cards objectAtIndex:(NSUInteger)cardIndex] integerValue];
            BOOL moving = _dragging && _dragSource == TGSolitaireSourceTableau &&
                          _dragPile == pile && cardIndex >= _dragCardIndex;
            if (!moving) {
                [self drawCard:card inRect:[self tableauCardRectForPile:pile cardIndex:cardIndex]
                           faceUp:[_engine isCardFaceUp:card] translucent:NO];
            }
        }
    }

    if (_dragging) {
        NSMutableArray *movingCards = [NSMutableArray array];
        if (_dragSource == TGSolitaireSourceWaste && [_engine wasteCard] >= 0) {
            [movingCards addObject:[NSNumber numberWithInteger:[_engine wasteCard]]];
        } else if (_dragSource == TGSolitaireSourceFoundation) {
            NSInteger card = [_engine foundationTopCardForSuit:_dragPile];
            if (card >= 0) [movingCards addObject:[NSNumber numberWithInteger:card]];
        } else if (_dragSource == TGSolitaireSourceTableau) {
            NSArray *pileCards = [_engine tableauCardsAtIndex:_dragPile];
            if (_dragCardIndex >= 0 && _dragCardIndex < (NSInteger)[pileCards count]) {
                [movingCards addObjectsFromArray:[pileCards subarrayWithRange:
                                                  NSMakeRange((NSUInteger)_dragCardIndex,
                                                              [pileCards count] - (NSUInteger)_dragCardIndex)]];
            }
        }
        NSUInteger index;
        for (index = 0; index < [movingCards count]; index++) {
            NSRect rect = NSMakeRect(_dragPoint.x - TGSolitaireCardWidth / 2.0,
                                     _dragPoint.y - TGSolitaireCardHeight / 2.0 - index * TGSolitaireFaceUpOffset,
                                     TGSolitaireCardWidth, TGSolitaireCardHeight);
            [self drawCard:[[movingCards objectAtIndex:index] integerValue]
                    inRect:rect faceUp:YES translucent:YES];
        }
    }
}

- (void)beginSourceAtPoint:(NSPoint)point event:(NSEvent *)event {
    _dragSource = TGSolitaireSourceNone;
    _dragPile = -1;
    _dragCardIndex = -1;
    if (NSPointInRect(point, [self topRectAtColumn:0])) {
        [_engine drawFromStock];
        [self notifyChanged];
        return;
    }
    if (NSPointInRect(point, [self topRectAtColumn:1]) && [_engine wasteCard] >= 0) {
        _dragSource = TGSolitaireSourceWaste;
        if ([event clickCount] == 2 && [_engine moveWasteToFoundation]) {
            _dragSource = TGSolitaireSourceNone;
            [self notifyChanged];
        }
        return;
    }
    NSInteger suit;
    for (suit = 0; suit < 4; suit++) {
        if (NSPointInRect(point, [self topRectAtColumn:suit + 3]) &&
            [_engine foundationTopCardForSuit:suit] >= 0) {
            _dragSource = TGSolitaireSourceFoundation;
            _dragPile = suit;
            return;
        }
    }
    NSInteger pile;
    for (pile = 0; pile < 7; pile++) {
        NSArray *cards = [_engine tableauCardsAtIndex:pile];
        NSInteger cardIndex;
        for (cardIndex = (NSInteger)[cards count] - 1; cardIndex >= 0; cardIndex--) {
            NSInteger card = [[cards objectAtIndex:(NSUInteger)cardIndex] integerValue];
            if (NSPointInRect(point, [self tableauCardRectForPile:pile cardIndex:cardIndex]) &&
                [_engine isCardFaceUp:card]) {
                _dragSource = TGSolitaireSourceTableau;
                _dragPile = pile;
                _dragCardIndex = cardIndex;
                if ([event clickCount] == 2 &&
                    [_engine autoMoveCardFromSource:TGSolitaireSourceTableau pile:pile cardIndex:cardIndex]) {
                    _dragSource = TGSolitaireSourceNone;
                    [self notifyChanged];
                }
                return;
            }
        }
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    _dragPoint = point;
    _dragging = NO;
    [self beginSourceAtPoint:point event:event];
}

- (void)mouseDragged:(NSEvent *)event {
    if (_dragSource == TGSolitaireSourceNone) return;
    _dragging = YES;
    _dragPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (!_dragging || _dragSource == TGSolitaireSourceNone) {
        _dragSource = TGSolitaireSourceNone;
        return;
    }
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    BOOL changed = NO;
    NSInteger pile;
    for (pile = 0; pile < 7 && !changed; pile++) {
        CGFloat xMin = NSMinX([self topRectAtColumn:pile]) - TGSolitaireHorizontalGap / 2.0;
        CGFloat xMax = NSMaxX([self topRectAtColumn:pile]) + TGSolitaireHorizontalGap / 2.0;
        if (point.x >= xMin && point.x <= xMax && point.y < [self topRowY]) {
            if (_dragSource == TGSolitaireSourceWaste) changed = [_engine moveWasteToTableau:pile];
            else if (_dragSource == TGSolitaireSourceFoundation) changed = [_engine moveFoundation:_dragPile toTableau:pile];
            else if (_dragSource == TGSolitaireSourceTableau) {
                changed = [_engine moveTableau:_dragPile cardIndex:_dragCardIndex toTableau:pile];
            }
        }
    }
    if (!changed) {
        for (pile = 0; pile < 4 && !changed; pile++) {
            if (NSPointInRect(point, [self topRectAtColumn:pile + 3])) {
                if (_dragSource == TGSolitaireSourceWaste) changed = [_engine moveWasteToFoundation];
                else if (_dragSource == TGSolitaireSourceTableau) {
                    changed = [_engine moveTableauTopToFoundation:_dragPile];
                }
            }
        }
    }
    _dragging = NO;
    _dragSource = TGSolitaireSourceNone;
    [self notifyChanged];
}

- (void)notifyChanged {
    [self setNeedsDisplay:YES];
    if (_target && _action && [_target respondsToSelector:_action]) {
        [NSApp sendAction:_action to:_target from:self];
    }
}

- (void)dealloc {
    [_engine release];
    [_themeColors release];
    [super dealloc];
}

@end
