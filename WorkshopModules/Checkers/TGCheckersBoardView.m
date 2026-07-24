#import "TGCheckersBoardView.h"
#import "../../Sources/Workshop/UI/TGWorkshopSurfaceView.h"
#include <stdlib.h>

@interface TGCheckersBoardView ()
- (NSRect)boardRect;
- (NSRect)squareRectForRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)row:(NSInteger *)row column:(NSInteger *)column atPoint:(NSPoint)point;
- (BOOL)isLegalDestinationRow:(NSInteger)row column:(NSInteger)column;
- (void)notifyMove;
@end

@implementation TGCheckersBoardView

- (id)initWithFrame:(NSRect)frame engine:(TGCheckersEngine *)engine themeColors:(NSDictionary *)colors {
    self = [super initWithFrame:frame];
    if (self) {
        _engine = [engine retain];
        _themeColors = [colors copy];
        _selectedRow = -1;
        _selectedColumn = -1;
        _dragRow = -1;
        _dragColumn = -1;
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)setTarget:(id)target action:(SEL)action {
    _target = target;
    _action = action;
}

- (void)clearSelection {
    _selectedRow = -1;
    _selectedColumn = -1;
    _dragRow = -1;
    _dragColumn = -1;
    _dragging = NO;
    [self setNeedsDisplay:YES];
}

- (NSRect)boardRect {
    CGFloat side = floor(MIN(NSWidth([self bounds]) - 24.0, NSHeight([self bounds]) - 24.0));
    side = MIN(side, 520.0);
    side = floor(side / 8.0) * 8.0;
    return NSMakeRect(floor((NSWidth([self bounds]) - side) / 2.0),
                      floor((NSHeight([self bounds]) - side) / 2.0),
                      side,
                      side);
}

- (NSRect)squareRectForRow:(NSInteger)row column:(NSInteger)column {
    NSRect board = [self boardRect];
    CGFloat square = NSWidth(board) / 8.0;
    return NSMakeRect(NSMinX(board) + column * square,
                      NSMinY(board) + row * square,
                      square,
                      square);
}

- (BOOL)row:(NSInteger *)row column:(NSInteger *)column atPoint:(NSPoint)point {
    NSRect board = [self boardRect];
    if (!NSPointInRect(point, board)) return NO;
    CGFloat square = NSWidth(board) / 8.0;
    NSInteger foundColumn = (NSInteger)floor((point.x - NSMinX(board)) / square);
    NSInteger foundRow = (NSInteger)floor((point.y - NSMinY(board)) / square);
    if (foundRow < 0 || foundRow > 7 || foundColumn < 0 || foundColumn > 7) return NO;
    if (row) *row = foundRow;
    if (column) *column = foundColumn;
    return YES;
}

- (BOOL)isLegalDestinationRow:(NSInteger)row column:(NSInteger)column {
    if (_selectedRow < 0) return NO;
    NSArray *moves = [_engine legalMovesFromRow:_selectedRow column:_selectedColumn];
    NSDictionary *move = nil;
    for (move in moves) {
        if ([[move objectForKey:@"toRow"] integerValue] == row &&
            [[move objectForKey:@"toColumn"] integerValue] == column) {
            return YES;
        }
    }
    return NO;
}

- (void)drawPiece:(NSInteger)piece inRect:(NSRect)squareRect dragging:(BOOL)dragging {
    CGFloat inset = MAX(6.0, NSWidth(squareRect) * 0.15);
    NSRect pieceRect = NSInsetRect(squareRect, inset, inset);
    if (dragging) {
        pieceRect.origin.x = _dragPoint.x - NSWidth(pieceRect) / 2.0;
        pieceRect.origin.y = _dragPoint.y - NSHeight(pieceRect) / 2.0;
    }
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    [context saveGraphicsState];
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowBlurRadius:dragging ? 5.0 : 2.0];
    [shadow setShadowOffset:NSMakeSize(0.0, dragging ? 2.0 : 1.0)];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.42]];
    [shadow set];

    NSColor *top = piece > 0
        ? [NSColor colorWithCalibratedRed:0.89 green:0.25 blue:0.20 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.25 alpha:1.0];
    NSColor *bottom = piece > 0
        ? [NSColor colorWithCalibratedRed:0.54 green:0.06 blue:0.05 alpha:1.0]
        : [NSColor colorWithCalibratedWhite:0.04 alpha:1.0];
    NSBezierPath *piecePath = [NSBezierPath bezierPathWithOvalInRect:pieceRect];
    NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:top endingColor:bottom] autorelease];
    [gradient drawInBezierPath:piecePath angle:90.0];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.55] setStroke];
    [piecePath setLineWidth:1.2];
    [piecePath stroke];

    NSRect innerRect = NSInsetRect(pieceRect, NSWidth(pieceRect) * 0.18, NSHeight(pieceRect) * 0.18);
    NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:innerRect];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
    [inner setLineWidth:2.0];
    [inner stroke];
    if (labs(piece) == 2) {
        NSRect kingRect = NSInsetRect(innerRect, NSWidth(innerRect) * 0.22, NSHeight(innerRect) * 0.22);
        NSBezierPath *king = [NSBezierPath bezierPathWithOvalInRect:kingRect];
        [[NSColor colorWithCalibratedRed:0.96 green:0.76 blue:0.24 alpha:0.92] setStroke];
        [king setLineWidth:3.0];
        [king stroke];
    }
    [context restoreGraphicsState];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    [TGWorkshopFeltPatternColor() setFill];
    NSRectFill([self bounds]);

    NSRect board = [self boardRect];
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowBlurRadius:5.0];
    [shadow setShadowOffset:NSMakeSize(0.0, 2.0)];
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.30]];
    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [[NSColor colorWithCalibratedWhite:0.18 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(board, -7.0, -7.0) xRadius:5.0 yRadius:5.0] fill];
    [NSGraphicsContext restoreGraphicsState];

    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSRect squareRect = [self squareRectForRow:row column:column];
            BOOL dark = ((row + column) % 2) == 1;
            NSColor *squareColor = dark
                ? [NSColor colorWithCalibratedRed:0.23 green:0.12 blue:0.055 alpha:1.0]
                : [NSColor colorWithCalibratedRed:0.82 green:0.67 blue:0.40 alpha:1.0];
            [squareColor setFill];
            NSRectFill(squareRect);
            if (row == _selectedRow && column == _selectedColumn) {
                [[NSColor colorWithCalibratedRed:0.98 green:0.74 blue:0.19 alpha:0.52] setFill];
                NSRectFillUsingOperation(squareRect, NSCompositeSourceOver);
            } else if ([self isLegalDestinationRow:row column:column]) {
                NSRect marker = NSInsetRect(squareRect, NSWidth(squareRect) * 0.37, NSHeight(squareRect) * 0.37);
                [[NSColor colorWithCalibratedRed:0.20 green:0.64 blue:0.33 alpha:0.82] setFill];
                [[NSBezierPath bezierPathWithOvalInRect:marker] fill];
            }
            NSInteger piece = [_engine pieceAtRow:row column:column];
            BOOL isDraggedPiece = _dragging && row == _dragRow && column == _dragColumn;
            if (piece != 0 && !isDraggedPiece) {
                [self drawPiece:piece inRect:squareRect dragging:NO];
            }
        }
    }
    if (_dragging && _dragRow >= 0) {
        NSInteger piece = [_engine pieceAtRow:_dragRow column:_dragColumn];
        if (piece != 0) [self drawPiece:piece inRect:[self squareRectForRow:_dragRow column:_dragColumn] dragging:YES];
    }
}

- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = -1;
    NSInteger column = -1;
    if (![self row:&row column:&column atPoint:point]) return;
    if ([[_engine legalMovesFromRow:row column:column] count] > 0) {
        _selectedRow = row;
        _selectedColumn = column;
        _dragRow = row;
        _dragColumn = column;
        _dragPoint = point;
        _dragging = NO;
    } else if (_selectedRow >= 0 && [self isLegalDestinationRow:row column:column]) {
        if ([_engine moveFromRow:_selectedRow column:_selectedColumn toRow:row column:column]) {
            _selectedRow = [_engine forcedCaptureRow];
            _selectedColumn = [_engine forcedCaptureColumn];
            [self notifyMove];
        }
    } else {
        _selectedRow = -1;
        _selectedColumn = -1;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    if (_dragRow < 0) return;
    _dragging = YES;
    _dragPoint = [self convertPoint:[event locationInWindow] fromView:nil];
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (!_dragging || _dragRow < 0) {
        _dragRow = -1;
        _dragColumn = -1;
        return;
    }
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    NSInteger row = -1;
    NSInteger column = -1;
    BOOL moved = [self row:&row column:&column atPoint:point] &&
                 [_engine moveFromRow:_dragRow column:_dragColumn toRow:row column:column];
    _dragging = NO;
    _dragRow = -1;
    _dragColumn = -1;
    if (moved) {
        _selectedRow = [_engine forcedCaptureRow];
        _selectedColumn = [_engine forcedCaptureColumn];
        [self notifyMove];
    }
    [self setNeedsDisplay:YES];
}

- (void)notifyMove {
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
