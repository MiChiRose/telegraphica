#import "TGPacManEngine.h"

static NSUInteger const TGPacManWidth = 19;
static NSUInteger const TGPacManHeight = 15;
static NSUInteger const TGPacManStartIndex = (12 * 19) + 9;
static NSUInteger const TGPacManGhostStartIndex = (8 * 19) + 9;

@interface TGPacManEngine ()
- (NSUInteger)neighborFromIndex:(NSUInteger)index direction:(TGPacManDirection)direction;
- (void)moveGhost;
- (void)handleCollision;
@end

@implementation TGPacManEngine

@synthesize pacmanIndex = _pacmanIndex;
@synthesize ghostIndex = _ghostIndex;
@synthesize score = _score;
@synthesize lives = _lives;
@synthesize finished = _finished;
@synthesize won = _won;

- (id)init {
    self = [super init];
    if (self) {
        _mazeRows = [[NSArray alloc] initWithObjects:
                     @"###################",
                     @"#........#........#",
                     @"#.###.##.#.##.###.#",
                     @"#o###.##.#.##.###o#",
                     @"#.................#",
                     @"#.###.#.#####.#.###",
                     @"#.....#...#...#...#",
                     @"#####.###...###.###",
                     @"#.................#",
                     @"###.#.#######.#.###",
                     @"#...#.....#...#...#",
                     @"#.###.##.#.##.###.#",
                     @"#o...............o#",
                     @"#...#.#######.#...#",
                     @"###################",
                     nil];
        _pellets = [[NSMutableIndexSet alloc] init];
        [self newGame];
    }
    return self;
}

- (NSUInteger)width { return TGPacManWidth; }
- (NSUInteger)height { return TGPacManHeight; }
- (NSUInteger)pelletCount { return [_pellets count]; }

- (void)newGame {
    [_pellets removeAllIndexes];
    NSUInteger row;
    for (row = 0; row < TGPacManHeight; row++) {
        NSString *mazeRow = [_mazeRows objectAtIndex:row];
        NSUInteger column;
        for (column = 0; column < TGPacManWidth; column++) {
            unichar value = [mazeRow characterAtIndex:column];
            if (value == '.' || value == 'o') {
                [_pellets addIndex:(row * TGPacManWidth) + column];
            }
        }
    }
    [_pellets removeIndex:TGPacManStartIndex];
    [_pellets removeIndex:TGPacManGhostStartIndex];
    _pacmanIndex = TGPacManStartIndex;
    _ghostIndex = TGPacManGhostStartIndex;
    _score = 0;
    _lives = 3;
    _tickCount = 0;
    _finished = NO;
    _won = NO;
}

- (BOOL)isWallAtIndex:(NSUInteger)index {
    if (index >= TGPacManWidth * TGPacManHeight) return YES;
    NSUInteger row = index / TGPacManWidth;
    NSUInteger column = index % TGPacManWidth;
    return [[_mazeRows objectAtIndex:row] characterAtIndex:column] == '#';
}

- (BOOL)hasPelletAtIndex:(NSUInteger)index {
    return [_pellets containsIndex:index];
}

- (NSUInteger)neighborFromIndex:(NSUInteger)index direction:(TGPacManDirection)direction {
    NSInteger row = (NSInteger)(index / TGPacManWidth);
    NSInteger column = (NSInteger)(index % TGPacManWidth);
    if (direction == TGPacManDirectionLeft) column--;
    if (direction == TGPacManDirectionRight) column++;
    if (direction == TGPacManDirectionUp) row--;
    if (direction == TGPacManDirectionDown) row++;
    if (row < 0 || column < 0 || row >= (NSInteger)TGPacManHeight ||
        column >= (NSInteger)TGPacManWidth) return NSNotFound;
    return (NSUInteger)row * TGPacManWidth + (NSUInteger)column;
}

- (void)moveGhost {
    TGPacManDirection directions[] = {
        TGPacManDirectionLeft,
        TGPacManDirectionUp,
        TGPacManDirectionRight,
        TGPacManDirectionDown
    };
    NSUInteger bestIndex = _ghostIndex;
    NSUInteger bestDistance = NSUIntegerMax;
    NSUInteger pacmanRow = _pacmanIndex / TGPacManWidth;
    NSUInteger pacmanColumn = _pacmanIndex % TGPacManWidth;
    NSUInteger index;
    for (index = 0; index < 4; index++) {
        NSUInteger candidate = [self neighborFromIndex:_ghostIndex direction:directions[index]];
        if (candidate == NSNotFound || [self isWallAtIndex:candidate]) continue;
        NSUInteger row = candidate / TGPacManWidth;
        NSUInteger column = candidate % TGPacManWidth;
        NSUInteger distance = (row > pacmanRow ? row - pacmanRow : pacmanRow - row) +
                              (column > pacmanColumn ? column - pacmanColumn : pacmanColumn - column);
        if (distance < bestDistance) {
            bestDistance = distance;
            bestIndex = candidate;
        }
    }
    _ghostIndex = bestIndex;
}

- (void)handleCollision {
    if (_pacmanIndex != _ghostIndex) return;
    if (_lives > 0) _lives--;
    if (_lives == 0) {
        _finished = YES;
        _won = NO;
    } else {
        _pacmanIndex = TGPacManStartIndex;
        _ghostIndex = TGPacManGhostStartIndex;
    }
}

- (BOOL)stepInDirection:(TGPacManDirection)direction {
    if (_finished || direction == TGPacManDirectionNone) return NO;
    NSUInteger destination = [self neighborFromIndex:_pacmanIndex direction:direction];
    if (destination == NSNotFound || [self isWallAtIndex:destination]) return NO;
    _pacmanIndex = destination;
    if ([_pellets containsIndex:_pacmanIndex]) {
        [_pellets removeIndex:_pacmanIndex];
        _score += 10;
    }
    [self handleCollision];
    if (_finished) return YES;
    _tickCount++;
    if ((_tickCount % 2) == 0) {
        [self moveGhost];
        [self handleCollision];
    }
    if ([_pellets count] == 0) {
        _finished = YES;
        _won = YES;
    }
    return YES;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *pellets = [NSMutableArray array];
    NSUInteger index = [_pellets firstIndex];
    while (index != NSNotFound) {
        [pellets addObject:[NSNumber numberWithUnsignedInteger:index]];
        index = [_pellets indexGreaterThanIndex:index];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema",
            pellets, @"pellets",
            [NSNumber numberWithUnsignedInteger:_pacmanIndex], @"pacman",
            [NSNumber numberWithUnsignedInteger:_ghostIndex], @"ghost",
            [NSNumber numberWithUnsignedInteger:_score], @"score",
            [NSNumber numberWithUnsignedInteger:_lives], @"lives",
            [NSNumber numberWithUnsignedInteger:_tickCount], @"ticks",
            [NSNumber numberWithBool:_finished], @"finished",
            [NSNumber numberWithBool:_won], @"won",
            nil];
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]] ||
        [[dictionary objectForKey:@"schema"] unsignedIntegerValue] != 1) return NO;
    NSArray *pellets = [dictionary objectForKey:@"pellets"];
    NSUInteger pacman = [[dictionary objectForKey:@"pacman"] unsignedIntegerValue];
    NSUInteger ghost = [[dictionary objectForKey:@"ghost"] unsignedIntegerValue];
    NSUInteger lives = [[dictionary objectForKey:@"lives"] unsignedIntegerValue];
    if (![pellets isKindOfClass:[NSArray class]] || lives > 3 ||
        [self isWallAtIndex:pacman] || [self isWallAtIndex:ghost]) return NO;
    NSMutableIndexSet *restoredPellets = [NSMutableIndexSet indexSet];
    NSNumber *number = nil;
    for (number in pellets) {
        if (![number isKindOfClass:[NSNumber class]]) return NO;
        NSUInteger index = [number unsignedIntegerValue];
        if (index >= TGPacManWidth * TGPacManHeight || [self isWallAtIndex:index]) return NO;
        [restoredPellets addIndex:index];
    }
    [_pellets removeAllIndexes];
    [_pellets addIndexes:restoredPellets];
    _pacmanIndex = pacman;
    _ghostIndex = ghost;
    _score = [[dictionary objectForKey:@"score"] unsignedIntegerValue];
    _lives = lives;
    _tickCount = [[dictionary objectForKey:@"ticks"] unsignedIntegerValue];
    _finished = [[dictionary objectForKey:@"finished"] boolValue];
    _won = [[dictionary objectForKey:@"won"] boolValue];
    return YES;
}

- (void)dealloc {
    [_mazeRows release];
    [_pellets release];
    [super dealloc];
}

@end
