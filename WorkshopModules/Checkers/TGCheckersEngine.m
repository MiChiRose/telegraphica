#import "TGCheckersEngine.h"

static const NSInteger TGCheckersNoSquare = -1;

@interface TGCheckersEngine ()
- (BOOL)isInsideRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)piece:(NSInteger)piece belongsToPlayer:(TGCheckersPlayer)player;
- (NSArray *)captureMovesFromRow:(NSInteger)row column:(NSInteger)column;
- (NSArray *)simpleMovesFromRow:(NSInteger)row column:(NSInteger)column;
- (NSArray *)allLegalMovesForPlayer:(TGCheckersPlayer)player;
- (void)finishTurn;
- (void)evaluateWinner;
@end

@implementation TGCheckersEngine

- (id)init {
    self = [super init];
    if (self) {
        _board = [[NSMutableArray alloc] initWithCapacity:64];
        [self startNewGameWithMode:TGCheckersModeComputer];
    }
    return self;
}

- (void)startNewGameWithMode:(TGCheckersMode)mode {
    [_board removeAllObjects];
    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSInteger piece = 0;
            if (((row + column) % 2) == 1) {
                if (row < 3) piece = TGCheckersPlayerBlack;
                if (row > 4) piece = TGCheckersPlayerRed;
            }
            [_board addObject:[NSNumber numberWithInteger:piece]];
        }
    }
    _mode = mode;
    _currentPlayer = TGCheckersPlayerRed;
    _forcedCaptureRow = TGCheckersNoSquare;
    _forcedCaptureColumn = TGCheckersNoSquare;
    _finished = NO;
    _winner = 0;
}

- (BOOL)isInsideRow:(NSInteger)row column:(NSInteger)column {
    return row >= 0 && row < 8 && column >= 0 && column < 8;
}

- (NSInteger)pieceAtRow:(NSInteger)row column:(NSInteger)column {
    if (![self isInsideRow:row column:column]) return 0;
    return [[_board objectAtIndex:(NSUInteger)(row * 8 + column)] integerValue];
}

- (void)setPiece:(NSInteger)piece row:(NSInteger)row column:(NSInteger)column {
    if (![self isInsideRow:row column:column]) return;
    [_board replaceObjectAtIndex:(NSUInteger)(row * 8 + column)
                      withObject:[NSNumber numberWithInteger:piece]];
}

- (BOOL)piece:(NSInteger)piece belongsToPlayer:(TGCheckersPlayer)player {
    return (player == TGCheckersPlayerRed && piece > 0) ||
           (player == TGCheckersPlayerBlack && piece < 0);
}

- (NSArray *)directionsForPiece:(NSInteger)piece {
    if (labs(piece) == 2) {
        return [NSArray arrayWithObjects:
                [NSArray arrayWithObjects:@-1, @-1, nil],
                [NSArray arrayWithObjects:@-1, @1, nil],
                [NSArray arrayWithObjects:@1, @-1, nil],
                [NSArray arrayWithObjects:@1, @1, nil], nil];
    }
    NSInteger delta = piece > 0 ? -1 : 1;
    return [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:[NSNumber numberWithInteger:delta], @-1, nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInteger:delta], @1, nil], nil];
}

- (NSDictionary *)moveFromRow:(NSInteger)fromRow
                       column:(NSInteger)fromColumn
                        toRow:(NSInteger)toRow
                       column:(NSInteger)toColumn
                      capture:(BOOL)capture {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:fromRow], @"fromRow",
            [NSNumber numberWithInteger:fromColumn], @"fromColumn",
            [NSNumber numberWithInteger:toRow], @"toRow",
            [NSNumber numberWithInteger:toColumn], @"toColumn",
            [NSNumber numberWithBool:capture], @"capture", nil];
}

- (NSArray *)captureMovesFromRow:(NSInteger)row column:(NSInteger)column {
    NSInteger piece = [self pieceAtRow:row column:column];
    if (piece == 0) return [NSArray array];
    NSMutableArray *moves = [NSMutableArray array];
    NSArray *directions = [self directionsForPiece:piece];
    NSUInteger index;
    for (index = 0; index < [directions count]; index++) {
        NSArray *direction = [directions objectAtIndex:index];
        NSInteger rowDelta = [[direction objectAtIndex:0] integerValue];
        NSInteger columnDelta = [[direction objectAtIndex:1] integerValue];
        NSInteger middleRow = row + rowDelta;
        NSInteger middleColumn = column + columnDelta;
        NSInteger targetRow = row + (rowDelta * 2);
        NSInteger targetColumn = column + (columnDelta * 2);
        NSInteger middlePiece = [self pieceAtRow:middleRow column:middleColumn];
        if ([self isInsideRow:targetRow column:targetColumn] &&
            middlePiece != 0 &&
            ![self piece:middlePiece belongsToPlayer:(piece > 0 ? TGCheckersPlayerRed : TGCheckersPlayerBlack)] &&
            [self pieceAtRow:targetRow column:targetColumn] == 0) {
            [moves addObject:[self moveFromRow:row column:column
                                        toRow:targetRow column:targetColumn capture:YES]];
        }
    }
    return moves;
}

- (NSArray *)simpleMovesFromRow:(NSInteger)row column:(NSInteger)column {
    NSInteger piece = [self pieceAtRow:row column:column];
    if (piece == 0) return [NSArray array];
    NSMutableArray *moves = [NSMutableArray array];
    NSArray *directions = [self directionsForPiece:piece];
    NSUInteger index;
    for (index = 0; index < [directions count]; index++) {
        NSArray *direction = [directions objectAtIndex:index];
        NSInteger targetRow = row + [[direction objectAtIndex:0] integerValue];
        NSInteger targetColumn = column + [[direction objectAtIndex:1] integerValue];
        if ([self isInsideRow:targetRow column:targetColumn] &&
            [self pieceAtRow:targetRow column:targetColumn] == 0) {
            [moves addObject:[self moveFromRow:row column:column
                                        toRow:targetRow column:targetColumn capture:NO]];
        }
    }
    return moves;
}

- (NSArray *)allCaptureMovesForPlayer:(TGCheckersPlayer)player {
    NSMutableArray *moves = [NSMutableArray array];
    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSInteger piece = [self pieceAtRow:row column:column];
            if ([self piece:piece belongsToPlayer:player]) {
                [moves addObjectsFromArray:[self captureMovesFromRow:row column:column]];
            }
        }
    }
    return moves;
}

- (NSArray *)allLegalMovesForPlayer:(TGCheckersPlayer)player {
    NSArray *captures = [self allCaptureMovesForPlayer:player];
    if ([captures count] > 0) return captures;
    NSMutableArray *moves = [NSMutableArray array];
    NSInteger row;
    NSInteger column;
    for (row = 0; row < 8; row++) {
        for (column = 0; column < 8; column++) {
            NSInteger piece = [self pieceAtRow:row column:column];
            if ([self piece:piece belongsToPlayer:player]) {
                [moves addObjectsFromArray:[self simpleMovesFromRow:row column:column]];
            }
        }
    }
    return moves;
}

- (BOOL)hasAnyCaptureForCurrentPlayer {
    return [[self allCaptureMovesForPlayer:_currentPlayer] count] > 0;
}

- (NSArray *)legalMovesFromRow:(NSInteger)row column:(NSInteger)column {
    if (_finished) return [NSArray array];
    NSInteger piece = [self pieceAtRow:row column:column];
    if (![self piece:piece belongsToPlayer:_currentPlayer]) return [NSArray array];
    if (_forcedCaptureRow != TGCheckersNoSquare &&
        (row != _forcedCaptureRow || column != _forcedCaptureColumn)) {
        return [NSArray array];
    }
    NSArray *captures = [self captureMovesFromRow:row column:column];
    if ([self hasAnyCaptureForCurrentPlayer]) return captures;
    return [self simpleMovesFromRow:row column:column];
}

- (BOOL)moveFromRow:(NSInteger)fromRow
             column:(NSInteger)fromColumn
              toRow:(NSInteger)toRow
             column:(NSInteger)toColumn {
    NSArray *moves = [self legalMovesFromRow:fromRow column:fromColumn];
    NSDictionary *selectedMove = nil;
    NSUInteger index;
    for (index = 0; index < [moves count]; index++) {
        NSDictionary *move = [moves objectAtIndex:index];
        if ([[move objectForKey:@"toRow"] integerValue] == toRow &&
            [[move objectForKey:@"toColumn"] integerValue] == toColumn) {
            selectedMove = move;
            break;
        }
    }
    if (!selectedMove) return NO;

    NSInteger piece = [self pieceAtRow:fromRow column:fromColumn];
    BOOL captured = [[selectedMove objectForKey:@"capture"] boolValue];
    [self setPiece:0 row:fromRow column:fromColumn];
    if (captured) {
        [self setPiece:0 row:(fromRow + toRow) / 2 column:(fromColumn + toColumn) / 2];
    }

    BOOL promoted = NO;
    if (piece == TGCheckersPlayerRed && toRow == 0) {
        piece = 2;
        promoted = YES;
    } else if (piece == TGCheckersPlayerBlack && toRow == 7) {
        piece = -2;
        promoted = YES;
    }
    [self setPiece:piece row:toRow column:toColumn];

    if (captured && !promoted && [[self captureMovesFromRow:toRow column:toColumn] count] > 0) {
        _forcedCaptureRow = toRow;
        _forcedCaptureColumn = toColumn;
    } else {
        [self finishTurn];
    }
    [self evaluateWinner];
    return YES;
}

- (void)finishTurn {
    _forcedCaptureRow = TGCheckersNoSquare;
    _forcedCaptureColumn = TGCheckersNoSquare;
    _currentPlayer = (TGCheckersPlayer)-_currentPlayer;
}

- (void)evaluateWinner {
    if (_finished) return;
    if ([[self allLegalMovesForPlayer:_currentPlayer] count] == 0) {
        _finished = YES;
        _winner = (TGCheckersPlayer)-_currentPlayer;
        if (_winner == TGCheckersPlayerRed) _redWins++;
        if (_winner == TGCheckersPlayerBlack) _blackWins++;
    }
}

- (BOOL)performComputerMove {
    if (_finished || _mode != TGCheckersModeComputer ||
        _currentPlayer != TGCheckersPlayerBlack) return NO;
    BOOL moved = NO;
    do {
        NSArray *moves = [self allLegalMovesForPlayer:_currentPlayer];
        if ([moves count] == 0) {
            [self evaluateWinner];
            return moved;
        }
        NSUInteger bestIndex = 0;
        NSUInteger index;
        for (index = 0; index < [moves count]; index++) {
            NSDictionary *move = [moves objectAtIndex:index];
            if ([[move objectForKey:@"capture"] boolValue]) {
                bestIndex = index;
                NSInteger toRow = [[move objectForKey:@"toRow"] integerValue];
                if (toRow == 7) break;
            }
        }
        NSDictionary *move = [moves objectAtIndex:bestIndex];
        moved = [self moveFromRow:[[move objectForKey:@"fromRow"] integerValue]
                          column:[[move objectForKey:@"fromColumn"] integerValue]
                           toRow:[[move objectForKey:@"toRow"] integerValue]
                          column:[[move objectForKey:@"toColumn"] integerValue]] || moved;
    } while (!_finished && _currentPlayer == TGCheckersPlayerBlack &&
             _forcedCaptureRow != TGCheckersNoSquare);
    return moved;
}

- (TGCheckersMode)mode { return _mode; }
- (TGCheckersPlayer)currentPlayer { return _currentPlayer; }
- (BOOL)isFinished { return _finished; }
- (TGCheckersPlayer)winner { return _winner; }
- (NSInteger)forcedCaptureRow { return _forcedCaptureRow; }
- (NSInteger)forcedCaptureColumn { return _forcedCaptureColumn; }
- (NSUInteger)redWins { return _redWins; }
- (NSUInteger)blackWins { return _blackWins; }

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithInteger:1], @"schema",
            _board, @"board",
            [NSNumber numberWithInteger:_mode], @"mode",
            [NSNumber numberWithInteger:_currentPlayer], @"currentPlayer",
            [NSNumber numberWithInteger:_forcedCaptureRow], @"forcedRow",
            [NSNumber numberWithInteger:_forcedCaptureColumn], @"forcedColumn",
            [NSNumber numberWithBool:_finished], @"finished",
            [NSNumber numberWithInteger:_winner], @"winner",
            [NSNumber numberWithUnsignedInteger:_redWins], @"redWins",
            [NSNumber numberWithUnsignedInteger:_blackWins], @"blackWins", nil];
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return NO;
    NSInteger schema = [dictionary objectForKey:@"schema"] ?
                       [[dictionary objectForKey:@"schema"] integerValue] : 0;
    if (schema < 0 || schema > 1) return NO;
    NSArray *board = [dictionary objectForKey:@"board"];
    if (![board isKindOfClass:[NSArray class]] || [board count] != 64) return NO;
    NSUInteger index;
    for (index = 0; index < [board count]; index++) {
        if (![[board objectAtIndex:index] isKindOfClass:[NSNumber class]]) return NO;
        NSInteger piece = [[board objectAtIndex:index] integerValue];
        if (piece < -2 || piece > 2) return NO;
    }
    TGCheckersMode mode = (TGCheckersMode)[[dictionary objectForKey:@"mode"] integerValue];
    TGCheckersPlayer currentPlayer = (TGCheckersPlayer)[[dictionary objectForKey:@"currentPlayer"] integerValue];
    NSInteger forcedRow = [[dictionary objectForKey:@"forcedRow"] integerValue];
    NSInteger forcedColumn = [[dictionary objectForKey:@"forcedColumn"] integerValue];
    BOOL finished = [[dictionary objectForKey:@"finished"] boolValue];
    TGCheckersPlayer winner = (TGCheckersPlayer)[[dictionary objectForKey:@"winner"] integerValue];
    if ((mode != TGCheckersModeLocal && mode != TGCheckersModeComputer) ||
        (currentPlayer != TGCheckersPlayerRed && currentPlayer != TGCheckersPlayerBlack) ||
        !((forcedRow == TGCheckersNoSquare && forcedColumn == TGCheckersNoSquare) ||
          ([self isInsideRow:forcedRow column:forcedColumn])) ||
        (winner != 0 && winner != TGCheckersPlayerRed && winner != TGCheckersPlayerBlack) ||
        (!finished && winner != 0) || (finished && winner == 0)) {
        return NO;
    }
    [_board setArray:board];
    _mode = mode;
    _currentPlayer = currentPlayer;
    _forcedCaptureRow = forcedRow;
    _forcedCaptureColumn = forcedColumn;
    _finished = finished;
    _winner = winner;
    _redWins = [[dictionary objectForKey:@"redWins"] unsignedIntegerValue];
    _blackWins = [[dictionary objectForKey:@"blackWins"] unsignedIntegerValue];
    return YES;
}

- (void)dealloc {
    [_board release];
    [super dealloc];
}

@end
