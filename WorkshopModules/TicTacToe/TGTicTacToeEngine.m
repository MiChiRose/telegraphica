#import "TGTicTacToeEngine.h"

static NSArray *TGTicTacToeWinningLines(void) {
    static NSArray *lines = nil;
    if (!lines) {
        lines = [[NSArray alloc] initWithObjects:
                 [NSArray arrayWithObjects:@0, @1, @2, nil],
                 [NSArray arrayWithObjects:@3, @4, @5, nil],
                 [NSArray arrayWithObjects:@6, @7, @8, nil],
                 [NSArray arrayWithObjects:@0, @3, @6, nil],
                 [NSArray arrayWithObjects:@1, @4, @7, nil],
                 [NSArray arrayWithObjects:@2, @5, @8, nil],
                 [NSArray arrayWithObjects:@0, @4, @8, nil],
                 [NSArray arrayWithObjects:@2, @4, @6, nil],
                 nil];
    }
    return lines;
}

@interface TGTicTacToeEngine ()
- (void)evaluateBoardAndUpdateStatistics:(BOOL)updateStatistics;
- (NSInteger)scoreBoardForPlayer:(NSString *)player depth:(NSInteger)depth;
@end

@implementation TGTicTacToeEngine

@synthesize board = _board;
@synthesize currentPlayer = _currentPlayer;
@synthesize winner = _winner;
@synthesize winningIndexes = _winningIndexes;
@synthesize mode = _mode;
@synthesize difficulty = _difficulty;
@synthesize xWins = _xWins;
@synthesize oWins = _oWins;
@synthesize draws = _draws;

- (id)init {
    self = [super init];
    if (self) {
        _mode = TGTicTacToeModeComputer;
        _difficulty = TGTicTacToeDifficultyMedium;
        [self newRound];
    }
    return self;
}

- (void)newRound {
    [_board release];
    _board = [[NSMutableArray alloc] initWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", nil];
    [_currentPlayer release];
    _currentPlayer = [@"X" copy];
    [_winner release];
    _winner = nil;
    [_winningIndexes release];
    _winningIndexes = nil;
}

- (BOOL)boardIsFull {
    NSString *value = nil;
    for (value in _board) if ([value length] == 0) return NO;
    return YES;
}

- (void)evaluateBoardAndUpdateStatistics:(BOOL)updateStatistics {
    [_winner release];
    _winner = nil;
    [_winningIndexes release];
    _winningIndexes = nil;
    NSArray *line = nil;
    for (line in TGTicTacToeWinningLines()) {
        NSUInteger a = [[line objectAtIndex:0] unsignedIntegerValue];
        NSUInteger b = [[line objectAtIndex:1] unsignedIntegerValue];
        NSUInteger c = [[line objectAtIndex:2] unsignedIntegerValue];
        NSString *value = [_board objectAtIndex:a];
        if ([value length] > 0 && [value isEqualToString:[_board objectAtIndex:b]] &&
            [value isEqualToString:[_board objectAtIndex:c]]) {
            _winner = [value copy];
            _winningIndexes = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(a, 1)];
            NSMutableIndexSet *indexes = [NSMutableIndexSet indexSetWithIndex:a];
            [indexes addIndex:b];
            [indexes addIndex:c];
            [_winningIndexes release];
            _winningIndexes = [indexes copy];
            if (updateStatistics) {
                if ([value isEqualToString:@"X"]) _xWins++;
                else _oWins++;
            }
            return;
        }
    }
    if ([self boardIsFull]) {
        _winner = [@"draw" copy];
        if (updateStatistics) _draws++;
    }
}

- (BOOL)playAtIndex:(NSUInteger)index {
    if (index >= 9 || [_winner length] > 0 || [[_board objectAtIndex:index] length] > 0) return NO;
    [_board replaceObjectAtIndex:index withObject:_currentPlayer];
    [self evaluateBoardAndUpdateStatistics:YES];
    if (!_winner) {
        NSString *next = [_currentPlayer isEqualToString:@"X"] ? @"O" : @"X";
        [_currentPlayer release];
        _currentPlayer = [next copy];
    }
    return YES;
}

- (NSArray *)availableIndexes {
    NSMutableArray *indexes = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < 9; index++) {
        if ([[_board objectAtIndex:index] length] == 0) [indexes addObject:[NSNumber numberWithUnsignedInteger:index]];
    }
    return indexes;
}

- (NSInteger)scoreBoardForPlayer:(NSString *)player depth:(NSInteger)depth {
    [self evaluateBoardAndUpdateStatistics:NO];
    if (_winner) {
        if ([_winner isEqualToString:player]) return 10 - depth;
        if ([_winner isEqualToString:@"draw"]) return 0;
        return depth - 10;
    }
    NSString *opponent = [player isEqualToString:@"X"] ? @"O" : @"X";
    BOOL maximizing = [_currentPlayer isEqualToString:player];
    NSInteger best = maximizing ? -100 : 100;
    NSArray *available = [self availableIndexes];
    NSNumber *number = nil;
    for (number in available) {
        NSUInteger index = [number unsignedIntegerValue];
        [_board replaceObjectAtIndex:index withObject:_currentPlayer];
        NSString *previousPlayer = [_currentPlayer retain];
        NSString *next = [_currentPlayer isEqualToString:player] ? opponent : player;
        [_currentPlayer release];
        _currentPlayer = [next copy];
        NSInteger score = [self scoreBoardForPlayer:player depth:depth + 1];
        [_currentPlayer release];
        _currentPlayer = previousPlayer;
        [_board replaceObjectAtIndex:index withObject:@""];
        [_winner release];
        _winner = nil;
        [_winningIndexes release];
        _winningIndexes = nil;
        best = maximizing ? MAX(best, score) : MIN(best, score);
    }
    return best;
}

- (NSUInteger)winningOrBlockingIndexForPlayer:(NSString *)player {
    NSNumber *number = nil;
    for (number in [self availableIndexes]) {
        NSUInteger index = [number unsignedIntegerValue];
        [_board replaceObjectAtIndex:index withObject:player];
        [self evaluateBoardAndUpdateStatistics:NO];
        BOOL wins = [_winner isEqualToString:player];
        [_board replaceObjectAtIndex:index withObject:@""];
        [_winner release];
        _winner = nil;
        [_winningIndexes release];
        _winningIndexes = nil;
        if (wins) return index;
    }
    return NSNotFound;
}

- (BOOL)performComputerMove {
    if (_mode != TGTicTacToeModeComputer || ![_currentPlayer isEqualToString:@"O"] || _winner) return NO;
    NSArray *available = [self availableIndexes];
    if ([available count] == 0) return NO;
    NSUInteger selected = NSNotFound;
    if (_difficulty >= TGTicTacToeDifficultyMedium) {
        selected = [self winningOrBlockingIndexForPlayer:@"O"];
        if (selected == NSNotFound) selected = [self winningOrBlockingIndexForPlayer:@"X"];
    }
    if (_difficulty == TGTicTacToeDifficultyHard && selected == NSNotFound) {
        NSInteger bestScore = -100;
        NSNumber *number = nil;
        for (number in available) {
            NSUInteger index = [number unsignedIntegerValue];
            [_board replaceObjectAtIndex:index withObject:@"O"];
            [_currentPlayer release];
            _currentPlayer = [@"X" copy];
            NSInteger score = [self scoreBoardForPlayer:@"O" depth:0];
            [_currentPlayer release];
            _currentPlayer = [@"O" copy];
            [_board replaceObjectAtIndex:index withObject:@""];
            [_winner release];
            _winner = nil;
            [_winningIndexes release];
            _winningIndexes = nil;
            if (score > bestScore) {
                bestScore = score;
                selected = index;
            }
        }
    }
    if (selected == NSNotFound) {
        selected = [[available objectAtIndex:(NSUInteger)(arc4random_uniform((u_int32_t)[available count]))] unsignedIntegerValue];
    }
    return [self playAtIndex:selected];
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema_version",
            _board, @"board",
            _currentPlayer, @"current_player",
            [NSNumber numberWithInteger:_mode], @"mode",
            [NSNumber numberWithInteger:_difficulty], @"difficulty",
            [NSNumber numberWithUnsignedInteger:_xWins], @"x_wins",
            [NSNumber numberWithUnsignedInteger:_oWins], @"o_wins",
            [NSNumber numberWithUnsignedInteger:_draws], @"draws",
            nil];
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    NSArray *board = [dictionary objectForKey:@"board"];
    NSString *current = [dictionary objectForKey:@"current_player"];
    if (![board isKindOfClass:[NSArray class]] || [board count] != 9 ||
        !([current isEqualToString:@"X"] || [current isEqualToString:@"O"])) return NO;
    NSString *value = nil;
    for (value in board) {
        if (![value isKindOfClass:[NSString class]] ||
            !([value length] == 0 || [value isEqualToString:@"X"] || [value isEqualToString:@"O"])) return NO;
    }
    [_board release];
    _board = [[NSMutableArray alloc] initWithArray:board];
    [_currentPlayer release];
    _currentPlayer = [current copy];
    _mode = (TGTicTacToeMode)[[dictionary objectForKey:@"mode"] integerValue];
    _difficulty = (TGTicTacToeDifficulty)[[dictionary objectForKey:@"difficulty"] integerValue];
    _xWins = [[dictionary objectForKey:@"x_wins"] unsignedIntegerValue];
    _oWins = [[dictionary objectForKey:@"o_wins"] unsignedIntegerValue];
    _draws = [[dictionary objectForKey:@"draws"] unsignedIntegerValue];
    [self evaluateBoardAndUpdateStatistics:NO];
    return YES;
}

- (void)dealloc {
    [_board release];
    [_currentPlayer release];
    [_winner release];
    [_winningIndexes release];
    [super dealloc];
}

@end
