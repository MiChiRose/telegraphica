#import "TGTankPatrolEngine.h"
#include <stdlib.h>

static const NSUInteger TGTankBoardSize = 13;

static NSUInteger TGTankIndex(NSInteger x, NSInteger y) {
    return (NSUInteger)y * TGTankBoardSize + (NSUInteger)x;
}

static BOOL TGTankPointInside(NSInteger x, NSInteger y) {
    return x >= 0 && y >= 0 &&
           x < (NSInteger)TGTankBoardSize && y < (NSInteger)TGTankBoardSize;
}

static void TGTankDelta(TGTankDirection direction, NSInteger *dx, NSInteger *dy) {
    if (dx) *dx = 0;
    if (dy) *dy = 0;
    if (direction == TGTankDirectionUp && dy) *dy = -1;
    if (direction == TGTankDirectionRight && dx) *dx = 1;
    if (direction == TGTankDirectionDown && dy) *dy = 1;
    if (direction == TGTankDirectionLeft && dx) *dx = -1;
}

@interface TGTankPatrolEngine ()
- (void)buildTerrain;
- (BOOL)enemyOccupiesX:(NSInteger)x y:(NSInteger)y ignoringIndex:(NSInteger)ignoredIndex;
- (void)advanceEnemies;
- (void)damagePlayer;
- (void)evaluateOutcome;
@end

@implementation TGTankPatrolEngine

- (id)init {
    self = [super init];
    if (self) {
        _terrain = [[NSMutableArray alloc] initWithCapacity:TGTankBoardSize * TGTankBoardSize];
        _enemies = [[NSMutableArray alloc] init];
        [self newGame];
    }
    return self;
}

- (NSUInteger)boardSize { return TGTankBoardSize; }
- (NSInteger)terrainAtX:(NSInteger)x y:(NSInteger)y {
    if (!TGTankPointInside(x, y)) return 2;
    return [[_terrain objectAtIndex:TGTankIndex(x, y)] integerValue];
}
- (NSInteger)playerX { return _playerX; }
- (NSInteger)playerY { return _playerY; }
- (TGTankDirection)playerDirection { return _playerDirection; }
- (NSArray *)enemies { return _enemies; }
- (NSUInteger)lives { return _lives; }
- (NSUInteger)score { return _score; }
- (NSUInteger)wins { return _wins; }
- (NSUInteger)turns { return _turns; }
- (BOOL)isFinished { return _finished; }
- (BOOL)didWin { return _won; }

- (void)buildTerrain {
    [_terrain removeAllObjects];
    NSUInteger index = 0;
    for (index = 0; index < TGTankBoardSize * TGTankBoardSize; index++) {
        [_terrain addObject:[NSNumber numberWithInteger:0]];
    }
    NSInteger walls[][2] = {
        {2, 2}, {3, 2}, {9, 2}, {10, 2},
        {2, 3}, {5, 3}, {7, 3}, {10, 3},
        {4, 5}, {5, 5}, {7, 5}, {8, 5},
        {1, 7}, {2, 7}, {5, 7}, {7, 7}, {10, 7}, {11, 7},
        {3, 9}, {4, 9}, {8, 9}, {9, 9},
        {5, 11}, {7, 11}, {5, 12}, {7, 12}
    };
    NSUInteger count = sizeof(walls) / sizeof(walls[0]);
    for (index = 0; index < count; index++) {
        [_terrain replaceObjectAtIndex:TGTankIndex(walls[index][0], walls[index][1])
                            withObject:[NSNumber numberWithInteger:1]];
    }
    [_terrain replaceObjectAtIndex:TGTankIndex(6, 12)
                        withObject:[NSNumber numberWithInteger:3]];
}

- (void)newGame {
    [self buildTerrain];
    [_enemies removeAllObjects];
    NSArray *starts = [NSArray arrayWithObjects:
                       [NSArray arrayWithObjects:@1, @0, nil],
                       [NSArray arrayWithObjects:@6, @0, nil],
                       [NSArray arrayWithObjects:@11, @0, nil],
                       [NSArray arrayWithObjects:@3, @1, nil],
                       [NSArray arrayWithObjects:@9, @1, nil],
                       nil];
    NSArray *point = nil;
    for (point in starts) {
        [_enemies addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                             [point objectAtIndex:0], @"x",
                             [point objectAtIndex:1], @"y",
                             [NSNumber numberWithInteger:TGTankDirectionDown], @"direction",
                             nil]];
    }
    _playerX = 6;
    _playerY = 11;
    _playerDirection = TGTankDirectionUp;
    _lives = 3;
    _score = 0;
    _turns = 0;
    _finished = NO;
    _won = NO;
}

- (BOOL)enemyOccupiesX:(NSInteger)x y:(NSInteger)y ignoringIndex:(NSInteger)ignoredIndex {
    NSInteger index = 0;
    for (NSDictionary *enemy in _enemies) {
        if (index != ignoredIndex &&
            [[enemy objectForKey:@"x"] integerValue] == x &&
            [[enemy objectForKey:@"y"] integerValue] == y) {
            return YES;
        }
        index++;
    }
    return NO;
}

- (void)damagePlayer {
    if (_lives > 0) _lives--;
    if (_lives == 0) {
        _finished = YES;
        _won = NO;
        return;
    }
    _playerX = 6;
    _playerY = 11;
    _playerDirection = TGTankDirectionUp;
}

- (void)evaluateOutcome {
    if ([_enemies count] == 0) {
        _finished = YES;
        _won = YES;
        _wins++;
    }
    if ([self terrainAtX:6 y:12] != 3) {
        _finished = YES;
        _won = NO;
    }
}

- (void)advanceEnemies {
    if (_finished) return;
    NSInteger index = 0;
    for (NSMutableDictionary *enemy in _enemies) {
        NSInteger x = [[enemy objectForKey:@"x"] integerValue];
        NSInteger y = [[enemy objectForKey:@"y"] integerValue];
        NSInteger dx = 0;
        NSInteger dy = 0;
        if (labs(6 - x) > labs(12 - y)) {
            dx = (6 > x) ? 1 : -1;
        } else {
            dy = (12 > y) ? 1 : -1;
        }
        NSInteger nx = x + dx;
        NSInteger ny = y + dy;
        TGTankDirection direction = dy > 0 ? TGTankDirectionDown :
                                     dy < 0 ? TGTankDirectionUp :
                                     dx > 0 ? TGTankDirectionRight : TGTankDirectionLeft;
        [enemy setObject:[NSNumber numberWithInteger:direction] forKey:@"direction"];
        NSInteger terrain = [self terrainAtX:nx y:ny];
        if (terrain == 1) {
            [_terrain replaceObjectAtIndex:TGTankIndex(nx, ny)
                                withObject:[NSNumber numberWithInteger:0]];
        } else if (terrain == 3) {
            [_terrain replaceObjectAtIndex:TGTankIndex(nx, ny)
                                withObject:[NSNumber numberWithInteger:0]];
        } else if (terrain == 0 &&
                   ![self enemyOccupiesX:nx y:ny ignoringIndex:index]) {
            if (nx == _playerX && ny == _playerY) {
                [self damagePlayer];
            } else {
                [enemy setObject:[NSNumber numberWithInteger:nx] forKey:@"x"];
                [enemy setObject:[NSNumber numberWithInteger:ny] forKey:@"y"];
            }
        }
        index++;
        if (_finished) break;
    }
    [self evaluateOutcome];
}

- (BOOL)movePlayerInDirection:(TGTankDirection)direction {
    if (_finished) return NO;
    _playerDirection = direction;
    NSInteger dx = 0;
    NSInteger dy = 0;
    TGTankDelta(direction, &dx, &dy);
    NSInteger nx = _playerX + dx;
    NSInteger ny = _playerY + dy;
    BOOL moved = NO;
    if (TGTankPointInside(nx, ny) &&
        [self terrainAtX:nx y:ny] == 0 &&
        ![self enemyOccupiesX:nx y:ny ignoringIndex:-1]) {
        _playerX = nx;
        _playerY = ny;
        moved = YES;
    }
    _turns++;
    [self advanceEnemies];
    return moved;
}

- (BOOL)fire {
    if (_finished) return NO;
    NSInteger dx = 0;
    NSInteger dy = 0;
    TGTankDelta(_playerDirection, &dx, &dy);
    NSInteger x = _playerX + dx;
    NSInteger y = _playerY + dy;
    BOOL hit = NO;
    while (TGTankPointInside(x, y)) {
        NSInteger terrain = [self terrainAtX:x y:y];
        if (terrain == 1) {
            [_terrain replaceObjectAtIndex:TGTankIndex(x, y)
                                withObject:[NSNumber numberWithInteger:0]];
            hit = YES;
            break;
        }
        if (terrain == 2 || terrain == 3) break;
        NSUInteger index = 0;
        for (NSDictionary *enemy in [[_enemies copy] autorelease]) {
            if ([[enemy objectForKey:@"x"] integerValue] == x &&
                [[enemy objectForKey:@"y"] integerValue] == y) {
                [_enemies removeObjectAtIndex:index];
                _score += 100;
                hit = YES;
                break;
            }
            index++;
        }
        if (hit) break;
        x += dx;
        y += dy;
    }
    _turns++;
    [self evaluateOutcome];
    if (!_finished) [self advanceEnemies];
    return hit;
}

- (NSDictionary *)saveState {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            _terrain, @"terrain",
            _enemies, @"enemies",
            [NSNumber numberWithInteger:_playerX], @"player_x",
            [NSNumber numberWithInteger:_playerY], @"player_y",
            [NSNumber numberWithInteger:_playerDirection], @"player_direction",
            [NSNumber numberWithUnsignedInteger:_lives], @"lives",
            [NSNumber numberWithUnsignedInteger:_score], @"score",
            [NSNumber numberWithUnsignedInteger:_wins], @"wins",
            [NSNumber numberWithUnsignedInteger:_turns], @"turns",
            [NSNumber numberWithBool:_finished], @"finished",
            [NSNumber numberWithBool:_won], @"won",
            nil];
}

- (BOOL)restoreState:(NSDictionary *)state {
    if (![state isKindOfClass:[NSDictionary class]]) return NO;
    NSArray *terrain = [state objectForKey:@"terrain"];
    NSArray *enemies = [state objectForKey:@"enemies"];
    if (![terrain isKindOfClass:[NSArray class]] ||
        [terrain count] != TGTankBoardSize * TGTankBoardSize ||
        ![enemies isKindOfClass:[NSArray class]] ||
        [enemies count] > 12) {
        return NO;
    }
    NSInteger playerX = [[state objectForKey:@"player_x"] integerValue];
    NSInteger playerY = [[state objectForKey:@"player_y"] integerValue];
    NSInteger direction = [[state objectForKey:@"player_direction"] integerValue];
    if (!TGTankPointInside(playerX, playerY) ||
        direction < TGTankDirectionUp || direction > TGTankDirectionLeft) {
        return NO;
    }
    for (id value in terrain) {
        NSInteger tile = [value integerValue];
        if (![value respondsToSelector:@selector(integerValue)] || tile < 0 || tile > 3) return NO;
    }
    for (id value in enemies) {
        if (![value isKindOfClass:[NSDictionary class]]) return NO;
        NSInteger x = [[value objectForKey:@"x"] integerValue];
        NSInteger y = [[value objectForKey:@"y"] integerValue];
        if (!TGTankPointInside(x, y)) return NO;
    }
    [_terrain setArray:terrain];
    [_enemies removeAllObjects];
    for (NSDictionary *enemy in enemies) {
        [_enemies addObject:[NSMutableDictionary dictionaryWithDictionary:enemy]];
    }
    _playerX = playerX;
    _playerY = playerY;
    _playerDirection = (TGTankDirection)direction;
    _lives = [[state objectForKey:@"lives"] unsignedIntegerValue];
    _score = [[state objectForKey:@"score"] unsignedIntegerValue];
    _wins = [[state objectForKey:@"wins"] unsignedIntegerValue];
    _turns = [[state objectForKey:@"turns"] unsignedIntegerValue];
    _finished = [[state objectForKey:@"finished"] boolValue];
    _won = [[state objectForKey:@"won"] boolValue];
    return _lives <= 3;
}

- (void)dealloc {
    [_terrain release];
    [_enemies release];
    [super dealloc];
}

@end
