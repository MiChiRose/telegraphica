#import <Foundation/Foundation.h>

typedef enum {
    TGPacManDirectionNone = 0,
    TGPacManDirectionLeft,
    TGPacManDirectionRight,
    TGPacManDirectionUp,
    TGPacManDirectionDown
} TGPacManDirection;

@interface TGPacManEngine : NSObject {
@private
    NSArray *_mazeRows;
    NSMutableIndexSet *_pellets;
    NSUInteger _pacmanIndex;
    NSUInteger _ghostIndex;
    NSUInteger _score;
    NSUInteger _lives;
    NSUInteger _tickCount;
    BOOL _finished;
    BOOL _won;
}

@property(nonatomic, readonly) NSUInteger width;
@property(nonatomic, readonly) NSUInteger height;
@property(nonatomic, readonly) NSUInteger pacmanIndex;
@property(nonatomic, readonly) NSUInteger ghostIndex;
@property(nonatomic, readonly) NSUInteger score;
@property(nonatomic, readonly) NSUInteger lives;
@property(nonatomic, readonly) NSUInteger pelletCount;
@property(nonatomic, readonly, getter=isFinished) BOOL finished;
@property(nonatomic, readonly, getter=hasWon) BOOL won;

- (void)newGame;
- (BOOL)isWallAtIndex:(NSUInteger)index;
- (BOOL)hasPelletAtIndex:(NSUInteger)index;
- (BOOL)stepInDirection:(TGPacManDirection)direction;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
