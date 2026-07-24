#import "TGMinesweeperEngine.h"

static NSDictionary *TGMinesweeperNewCell(void) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @NO, @"mine", @NO, @"open", @NO, @"flag", @0, @"adjacent", nil];
}

@implementation TGMinesweeperEngine

@synthesize width = _width;
@synthesize height = _height;
@synthesize mineCount = _mineCount;
@synthesize difficulty = _difficulty;
@synthesize state = _state;
@synthesize gamesWon = _gamesWon;
@synthesize gamesLost = _gamesLost;

- (id)init {
    self = [super init];
    if (self) {
        _bestTimes = [[NSMutableDictionary alloc] init];
        [self startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
    }
    return self;
}

- (void)configureDifficulty:(TGMinesweeperDifficulty)difficulty {
    _difficulty = difficulty;
    if (difficulty == TGMinesweeperDifficultyIntermediate) {
        _width = 16; _height = 16; _mineCount = 40;
    } else if (difficulty == TGMinesweeperDifficultyExpert) {
        _width = 30; _height = 16; _mineCount = 99;
    } else {
        _width = 9; _height = 9; _mineCount = 10;
    }
}

- (void)startNewGameWithDifficulty:(TGMinesweeperDifficulty)difficulty {
    [self configureDifficulty:difficulty];
    [_cells release];
    _cells = [[NSMutableArray alloc] initWithCapacity:_width * _height];
    NSUInteger index = 0;
    for (index = 0; index < _width * _height; index++) {
        [_cells addObject:[NSMutableDictionary dictionaryWithDictionary:TGMinesweeperNewCell()]];
    }
    _state = TGMinesweeperStateReady;
    _elapsedSeconds = 0.0;
    [_startedAt release];
    _startedAt = nil;
}

- (BOOL)indexIsValid:(NSUInteger)index { return index < [_cells count]; }
- (NSInteger)rowForIndex:(NSUInteger)index { return (NSInteger)(index / _width); }
- (NSInteger)columnForIndex:(NSUInteger)index { return (NSInteger)(index % _width); }
- (NSUInteger)indexForRow:(NSInteger)row column:(NSInteger)column {
    return (NSUInteger)row * _width + (NSUInteger)column;
}

- (NSArray *)neighborIndexesForIndex:(NSUInteger)index {
    NSMutableArray *neighbors = [NSMutableArray array];
    NSInteger row = [self rowForIndex:index];
    NSInteger column = [self columnForIndex:index];
    NSInteger dy = 0;
    NSInteger dx = 0;
    for (dy = -1; dy <= 1; dy++) {
        for (dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            NSInteger candidateRow = row + dy;
            NSInteger candidateColumn = column + dx;
            if (candidateRow >= 0 && candidateColumn >= 0 &&
                candidateRow < (NSInteger)_height && candidateColumn < (NSInteger)_width) {
                [neighbors addObject:[NSNumber numberWithUnsignedInteger:
                                      [self indexForRow:candidateRow column:candidateColumn]]];
            }
        }
    }
    return neighbors;
}

- (void)placeMinesExcludingIndex:(NSUInteger)safeIndex {
    NSMutableSet *excluded = [NSMutableSet setWithObject:[NSNumber numberWithUnsignedInteger:safeIndex]];
    [excluded addObjectsFromArray:[self neighborIndexesForIndex:safeIndex]];
    NSUInteger placed = 0;
    while (placed < _mineCount) {
        NSUInteger candidate = (NSUInteger)arc4random_uniform((u_int32_t)[_cells count]);
        if ([excluded containsObject:[NSNumber numberWithUnsignedInteger:candidate]]) continue;
        NSMutableDictionary *cell = [_cells objectAtIndex:candidate];
        if ([[cell objectForKey:@"mine"] boolValue]) continue;
        [cell setObject:@YES forKey:@"mine"];
        placed++;
    }
    NSUInteger index = 0;
    for (index = 0; index < [_cells count]; index++) {
        NSUInteger adjacent = 0;
        NSNumber *neighbor = nil;
        for (neighbor in [self neighborIndexesForIndex:index]) {
            if ([[[_cells objectAtIndex:[neighbor unsignedIntegerValue]] objectForKey:@"mine"] boolValue]) adjacent++;
        }
        [[_cells objectAtIndex:index] setObject:[NSNumber numberWithUnsignedInteger:adjacent] forKey:@"adjacent"];
    }
}

- (void)openEmptyRegionFromIndex:(NSUInteger)index {
    NSMutableArray *queue = [NSMutableArray arrayWithObject:[NSNumber numberWithUnsignedInteger:index]];
    NSMutableSet *visited = [NSMutableSet set];
    while ([queue count] > 0) {
        NSNumber *number = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        if ([visited containsObject:number]) continue;
        [visited addObject:number];
        NSMutableDictionary *cell = [_cells objectAtIndex:[number unsignedIntegerValue]];
        if ([[cell objectForKey:@"flag"] boolValue] || [[cell objectForKey:@"mine"] boolValue]) continue;
        [cell setObject:@YES forKey:@"open"];
        if ([[cell objectForKey:@"adjacent"] unsignedIntegerValue] == 0) {
            NSNumber *neighbor = nil;
            for (neighbor in [self neighborIndexesForIndex:[number unsignedIntegerValue]]) {
                if (![visited containsObject:neighbor]) [queue addObject:neighbor];
            }
        }
    }
}

- (void)updateWinState {
    NSUInteger closedSafeCells = 0;
    NSDictionary *cell = nil;
    for (cell in _cells) {
        if (![[cell objectForKey:@"mine"] boolValue] && ![[cell objectForKey:@"open"] boolValue]) closedSafeCells++;
    }
    if (closedSafeCells == 0 && _state == TGMinesweeperStatePlaying) {
        _elapsedSeconds = [self elapsedSeconds];
        [_startedAt release];
        _startedAt = nil;
        _state = TGMinesweeperStateWon;
        _gamesWon++;
        NSString *key = [NSString stringWithFormat:@"%ld", (long)_difficulty];
        NSNumber *best = [_bestTimes objectForKey:key];
        if (!best || _elapsedSeconds < [best doubleValue]) {
            [_bestTimes setObject:[NSNumber numberWithDouble:_elapsedSeconds] forKey:key];
        }
    }
}

- (BOOL)revealCellAtIndex:(NSUInteger)index {
    if (![self indexIsValid:index] || _state == TGMinesweeperStateWon || _state == TGMinesweeperStateLost) return NO;
    NSMutableDictionary *cell = [_cells objectAtIndex:index];
    if ([[cell objectForKey:@"flag"] boolValue] || [[cell objectForKey:@"open"] boolValue]) return NO;
    if (_state == TGMinesweeperStateReady) {
        [self placeMinesExcludingIndex:index];
        _state = TGMinesweeperStatePlaying;
        [_startedAt release];
        _startedAt = [[NSDate date] retain];
        cell = [_cells objectAtIndex:index];
    }
    if ([[cell objectForKey:@"mine"] boolValue]) {
        [cell setObject:@YES forKey:@"open"];
        _elapsedSeconds = [self elapsedSeconds];
        [_startedAt release];
        _startedAt = nil;
        _state = TGMinesweeperStateLost;
        _gamesLost++;
        NSMutableDictionary *candidate = nil;
        for (candidate in _cells) if ([[candidate objectForKey:@"mine"] boolValue]) [candidate setObject:@YES forKey:@"open"];
    } else {
        [self openEmptyRegionFromIndex:index];
        [self updateWinState];
    }
    return YES;
}

- (BOOL)toggleFlagAtIndex:(NSUInteger)index {
    if (![self indexIsValid:index] || _state == TGMinesweeperStateWon || _state == TGMinesweeperStateLost) return NO;
    NSMutableDictionary *cell = [_cells objectAtIndex:index];
    if ([[cell objectForKey:@"open"] boolValue]) return NO;
    [cell setObject:[NSNumber numberWithBool:![[cell objectForKey:@"flag"] boolValue]] forKey:@"flag"];
    return YES;
}

- (NSDictionary *)cellAtIndex:(NSUInteger)index {
    return [self indexIsValid:index] ? [_cells objectAtIndex:index] : nil;
}

- (NSUInteger)remainingMineEstimate {
    NSUInteger flags = 0;
    NSDictionary *cell = nil;
    for (cell in _cells) if ([[cell objectForKey:@"flag"] boolValue]) flags++;
    return flags >= _mineCount ? 0 : _mineCount - flags;
}

- (NSTimeInterval)elapsedSeconds {
    if (_state == TGMinesweeperStatePlaying && _startedAt) {
        return _elapsedSeconds + [[NSDate date] timeIntervalSinceDate:_startedAt];
    }
    return _elapsedSeconds;
}

- (void)pauseTiming {
    if (_state != TGMinesweeperStatePlaying || !_startedAt) return;
    _elapsedSeconds += [[NSDate date] timeIntervalSinceDate:_startedAt];
    [_startedAt release];
    _startedAt = nil;
}

- (void)resumeTiming {
    if (_state != TGMinesweeperStatePlaying || _startedAt) return;
    _startedAt = [[NSDate date] retain];
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema_version",
            [NSNumber numberWithInteger:_difficulty], @"difficulty",
            [NSNumber numberWithInteger:_state], @"state",
            _cells, @"cells",
            [NSNumber numberWithDouble:[self elapsedSeconds]], @"elapsed",
            [NSNumber numberWithUnsignedInteger:_gamesWon], @"games_won",
            [NSNumber numberWithUnsignedInteger:_gamesLost], @"games_lost",
            _bestTimes, @"best_times",
            nil];
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    NSInteger difficulty = [[dictionary objectForKey:@"difficulty"] integerValue];
    if (difficulty < 0 || difficulty > 2) return NO;
    [self configureDifficulty:(TGMinesweeperDifficulty)difficulty];
    NSArray *cells = [dictionary objectForKey:@"cells"];
    if (![cells isKindOfClass:[NSArray class]] || [cells count] != _width * _height) return NO;
    NSDictionary *cell = nil;
    for (cell in cells) {
        if (![cell isKindOfClass:[NSDictionary class]] ||
            ![cell objectForKey:@"mine"] || ![cell objectForKey:@"open"] ||
            ![cell objectForKey:@"flag"] || ![cell objectForKey:@"adjacent"]) return NO;
    }
    [_cells release];
    _cells = [[NSMutableArray alloc] initWithCapacity:[cells count]];
    for (cell in cells) [_cells addObject:[NSMutableDictionary dictionaryWithDictionary:cell]];
    _state = (TGMinesweeperState)[[dictionary objectForKey:@"state"] integerValue];
    if (_state < TGMinesweeperStateReady || _state > TGMinesweeperStateLost) return NO;
    _elapsedSeconds = [[dictionary objectForKey:@"elapsed"] doubleValue];
    _gamesWon = [[dictionary objectForKey:@"games_won"] unsignedIntegerValue];
    _gamesLost = [[dictionary objectForKey:@"games_lost"] unsignedIntegerValue];
    [_bestTimes release];
    NSDictionary *best = [dictionary objectForKey:@"best_times"];
    _bestTimes = [[NSMutableDictionary alloc] initWithDictionary:
                  [best isKindOfClass:[NSDictionary class]] ? best : [NSDictionary dictionary]];
    [_startedAt release];
    _startedAt = (_state == TGMinesweeperStatePlaying) ? [[NSDate date] retain] : nil;
    return YES;
}

- (void)dealloc {
    [_cells release];
    [_startedAt release];
    [_bestTimes release];
    [super dealloc];
}

@end
