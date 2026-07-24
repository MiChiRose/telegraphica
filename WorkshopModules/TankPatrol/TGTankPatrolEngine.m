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
- (void)advanceBullets;
- (void)spawnBulletFromX:(NSInteger)x
                       y:(NSInteger)y
               direction:(TGTankDirection)direction
                   enemy:(BOOL)enemy;
- (void)damagePlayer;
- (void)evaluateOutcome;
@end

@implementation TGTankPatrolEngine

- (id)init {
    self = [super init];
    if (self) {
        _terrain = [[NSMutableArray alloc] initWithCapacity:TGTankBoardSize * TGTankBoardSize];
        _enemies = [[NSMutableArray alloc] init];
        _bullets = [[NSMutableArray alloc] init];
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
- (NSArray *)bullets { return _bullets; }
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
    NSInteger steel[][2] = {
        {6, 4}, {1, 5}, {11, 5}, {4, 8}, {8, 8}
    };
    count = sizeof(steel) / sizeof(steel[0]);
    for (index = 0; index < count; index++) {
        [_terrain replaceObjectAtIndex:TGTankIndex(steel[index][0], steel[index][1])
                            withObject:[NSNumber numberWithInteger:2]];
    }
    NSInteger brush[][2] = {
        {5, 1}, {7, 1}, {6, 2}, {1, 4}, {11, 4},
        {3, 6}, {9, 6}, {5, 9}, {6, 9}, {7, 9}
    };
    count = sizeof(brush) / sizeof(brush[0]);
    for (index = 0; index < count; index++) {
        [_terrain replaceObjectAtIndex:TGTankIndex(brush[index][0], brush[index][1])
                            withObject:[NSNumber numberWithInteger:4]];
    }
    [_terrain replaceObjectAtIndex:TGTankIndex(6, 12)
                        withObject:[NSNumber numberWithInteger:3]];
}

- (void)newGame {
    [self buildTerrain];
    [_enemies removeAllObjects];
    [_bullets removeAllObjects];
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
    _simulationTicks = 0;
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
        TGTankDirection direction =
            (TGTankDirection)[[enemy objectForKey:@"direction"] integerValue];
        if (((_simulationTicks + (NSUInteger)index * 3) % 7) == 0) {
            if (labs(6 - x) > labs(12 - y)) {
                direction = (6 > x) ? TGTankDirectionRight : TGTankDirectionLeft;
            } else {
                direction = (12 > y) ? TGTankDirectionDown : TGTankDirectionUp;
            }
        } else if (((_simulationTicks + (NSUInteger)index) % 11) == 0) {
            direction = (TGTankDirection)arc4random_uniform(4);
        }
        NSInteger dx = 0;
        NSInteger dy = 0;
        TGTankDelta(direction, &dx, &dy);
        NSInteger nx = x + dx;
        NSInteger ny = y + dy;
        [enemy setObject:[NSNumber numberWithInteger:direction] forKey:@"direction"];
        NSInteger terrain = [self terrainAtX:nx y:ny];
        if ((terrain == 0 || terrain == 4) &&
                   ![self enemyOccupiesX:nx y:ny ignoringIndex:index]) {
            if (nx == _playerX && ny == _playerY) {
                [self damagePlayer];
            } else {
                [enemy setObject:[NSNumber numberWithInteger:nx] forKey:@"x"];
                [enemy setObject:[NSNumber numberWithInteger:ny] forKey:@"y"];
            }
        } else if (((_simulationTicks + (NSUInteger)index) % 5) == 0) {
            [enemy setObject:[NSNumber numberWithInteger:arc4random_uniform(4)]
                      forKey:@"direction"];
        }
        if (((_simulationTicks + (NSUInteger)index * 2) % 4) == 0) {
            [self spawnBulletFromX:[[enemy objectForKey:@"x"] integerValue]
                                 y:[[enemy objectForKey:@"y"] integerValue]
                         direction:(TGTankDirection)[[enemy objectForKey:@"direction"] integerValue]
                             enemy:YES];
        }
        index++;
        if (_finished) break;
    }
    [self evaluateOutcome];
}

- (void)spawnBulletFromX:(NSInteger)x
                       y:(NSInteger)y
               direction:(TGTankDirection)direction
                   enemy:(BOOL)enemy {
    NSInteger dx = 0;
    NSInteger dy = 0;
    TGTankDelta(direction, &dx, &dy);
    [_bullets addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                         [NSNumber numberWithInteger:x + dx], @"x",
                         [NSNumber numberWithInteger:y + dy], @"y",
                         [NSNumber numberWithInteger:direction], @"direction",
                         [NSNumber numberWithBool:enemy], @"enemy",
                         nil]];
}

- (void)advanceBullets {
    if (_finished || [_bullets count] == 0) return;
    NSArray *current = [[_bullets copy] autorelease];
    NSMutableArray *survivors = [NSMutableArray arrayWithCapacity:[current count]];
    for (NSDictionary *bullet in current) {
        NSInteger x = [[bullet objectForKey:@"x"] integerValue];
        NSInteger y = [[bullet objectForKey:@"y"] integerValue];
        TGTankDirection direction =
            (TGTankDirection)[[bullet objectForKey:@"direction"] integerValue];
        BOOL enemyBullet = [[bullet objectForKey:@"enemy"] boolValue];
        if (!TGTankPointInside(x, y)) continue;

        NSInteger terrain = [self terrainAtX:x y:y];
        if (terrain == 1) {
            [_terrain replaceObjectAtIndex:TGTankIndex(x, y)
                                withObject:[NSNumber numberWithInteger:0]];
            continue;
        }
        if (terrain == 2) continue;
        if (terrain == 3) {
            if (enemyBullet) {
                [_terrain replaceObjectAtIndex:TGTankIndex(x, y)
                                    withObject:[NSNumber numberWithInteger:0]];
            }
            continue;
        }

        if (enemyBullet) {
            if (x == _playerX && y == _playerY) {
                [self damagePlayer];
                continue;
            }
        } else {
            NSUInteger enemyIndex = 0;
            BOOL hitEnemy = NO;
            for (NSDictionary *enemy in [[_enemies copy] autorelease]) {
                if ([[enemy objectForKey:@"x"] integerValue] == x &&
                    [[enemy objectForKey:@"y"] integerValue] == y) {
                    [_enemies removeObjectAtIndex:enemyIndex];
                    _score += 100;
                    hitEnemy = YES;
                    break;
                }
                enemyIndex++;
            }
            if (hitEnemy) continue;
        }

        NSInteger dx = 0;
        NSInteger dy = 0;
        TGTankDelta(direction, &dx, &dy);
        NSMutableDictionary *advanced = [NSMutableDictionary dictionaryWithDictionary:bullet];
        [advanced setObject:[NSNumber numberWithInteger:x + dx] forKey:@"x"];
        [advanced setObject:[NSNumber numberWithInteger:y + dy] forKey:@"y"];
        [survivors addObject:advanced];
    }
    [_bullets setArray:survivors];
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
    NSInteger terrain = [self terrainAtX:nx y:ny];
    if (TGTankPointInside(nx, ny) &&
        (terrain == 0 || terrain == 4) &&
        ![self enemyOccupiesX:nx y:ny ignoringIndex:-1]) {
        _playerX = nx;
        _playerY = ny;
        moved = YES;
    }
    _turns++;
    return moved;
}

- (BOOL)fire {
    if (_finished) return NO;
    [self spawnBulletFromX:_playerX y:_playerY direction:_playerDirection enemy:NO];
    _turns++;
    return YES;
}

- (void)advanceSimulation {
    if (_finished) return;
    _simulationTicks++;
    [self advanceBullets];
    if (!_finished && (_simulationTicks % 3) == 0) {
        [self advanceEnemies];
    }
    [self evaluateOutcome];
}

- (NSDictionary *)saveState {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            _terrain, @"terrain",
            _enemies, @"enemies",
            _bullets, @"bullets",
            [NSNumber numberWithInteger:_playerX], @"player_x",
            [NSNumber numberWithInteger:_playerY], @"player_y",
            [NSNumber numberWithInteger:_playerDirection], @"player_direction",
            [NSNumber numberWithUnsignedInteger:_lives], @"lives",
            [NSNumber numberWithUnsignedInteger:_score], @"score",
            [NSNumber numberWithUnsignedInteger:_wins], @"wins",
            [NSNumber numberWithUnsignedInteger:_turns], @"turns",
            [NSNumber numberWithUnsignedInteger:_simulationTicks], @"simulation_ticks",
            [NSNumber numberWithBool:_finished], @"finished",
            [NSNumber numberWithBool:_won], @"won",
            nil];
}

- (BOOL)restoreState:(NSDictionary *)state {
    if (![state isKindOfClass:[NSDictionary class]]) return NO;
    NSArray *terrain = [state objectForKey:@"terrain"];
    NSArray *enemies = [state objectForKey:@"enemies"];
    NSArray *bullets = [state objectForKey:@"bullets"];
    if (![terrain isKindOfClass:[NSArray class]] ||
        [terrain count] != TGTankBoardSize * TGTankBoardSize ||
        ![enemies isKindOfClass:[NSArray class]] ||
        [enemies count] > 12) {
        return NO;
    }
    if (bullets && (![bullets isKindOfClass:[NSArray class]] || [bullets count] > 64)) {
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
        if (![value respondsToSelector:@selector(integerValue)] || tile < 0 || tile > 4) return NO;
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
    [_bullets removeAllObjects];
    for (NSDictionary *bullet in bullets) {
        if (![bullet isKindOfClass:[NSDictionary class]]) return NO;
        NSInteger x = [[bullet objectForKey:@"x"] integerValue];
        NSInteger y = [[bullet objectForKey:@"y"] integerValue];
        if (x < -1 || y < -1 ||
            x > (NSInteger)TGTankBoardSize || y > (NSInteger)TGTankBoardSize) return NO;
        [_bullets addObject:[NSMutableDictionary dictionaryWithDictionary:bullet]];
    }
    _playerX = playerX;
    _playerY = playerY;
    _playerDirection = (TGTankDirection)direction;
    _lives = [[state objectForKey:@"lives"] unsignedIntegerValue];
    _score = [[state objectForKey:@"score"] unsignedIntegerValue];
    _wins = [[state objectForKey:@"wins"] unsignedIntegerValue];
    _turns = [[state objectForKey:@"turns"] unsignedIntegerValue];
    _simulationTicks = [[state objectForKey:@"simulation_ticks"] unsignedIntegerValue];
    _finished = [[state objectForKey:@"finished"] boolValue];
    _won = [[state objectForKey:@"won"] boolValue];
    return _lives <= 3;
}

- (void)dealloc {
    [_terrain release];
    [_enemies release];
    [_bullets release];
    [super dealloc];
}

@end
