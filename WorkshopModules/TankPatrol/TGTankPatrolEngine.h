#import <Foundation/Foundation.h>

typedef enum {
    TGTankDirectionUp = 0,
    TGTankDirectionRight = 1,
    TGTankDirectionDown = 2,
    TGTankDirectionLeft = 3
} TGTankDirection;

@interface TGTankPatrolEngine : NSObject {
@private
    NSMutableArray *_terrain;
    NSMutableArray *_enemies;
    NSMutableArray *_bullets;
    NSInteger _playerX;
    NSInteger _playerY;
    TGTankDirection _playerDirection;
    NSUInteger _lives;
    NSUInteger _score;
    NSUInteger _wins;
    NSUInteger _turns;
    NSUInteger _simulationTicks;
    BOOL _finished;
    BOOL _won;
}

- (void)newGame;
- (NSUInteger)boardSize;
- (NSInteger)terrainAtX:(NSInteger)x y:(NSInteger)y;
- (NSInteger)playerX;
- (NSInteger)playerY;
- (TGTankDirection)playerDirection;
- (NSArray *)enemies;
- (NSArray *)bullets;
- (NSUInteger)lives;
- (NSUInteger)score;
- (NSUInteger)wins;
- (NSUInteger)turns;
- (BOOL)isFinished;
- (BOOL)didWin;
- (BOOL)movePlayerInDirection:(TGTankDirection)direction;
- (BOOL)fire;
- (void)advanceSimulation;
- (NSDictionary *)saveState;
- (BOOL)restoreState:(NSDictionary *)state;

@end
