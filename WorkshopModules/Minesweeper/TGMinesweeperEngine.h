#import <Foundation/Foundation.h>

typedef enum {
    TGMinesweeperDifficultyBeginner = 0,
    TGMinesweeperDifficultyIntermediate = 1,
    TGMinesweeperDifficultyExpert = 2
} TGMinesweeperDifficulty;

typedef enum {
    TGMinesweeperStateReady = 0,
    TGMinesweeperStatePlaying = 1,
    TGMinesweeperStateWon = 2,
    TGMinesweeperStateLost = 3
} TGMinesweeperState;

@interface TGMinesweeperEngine : NSObject {
@private
    NSUInteger _width;
    NSUInteger _height;
    NSUInteger _mineCount;
    TGMinesweeperDifficulty _difficulty;
    TGMinesweeperState _state;
    NSMutableArray *_cells;
    NSTimeInterval _elapsedSeconds;
    NSDate *_startedAt;
    NSUInteger _gamesWon;
    NSUInteger _gamesLost;
    NSMutableDictionary *_bestTimes;
}

@property(nonatomic, readonly) NSUInteger width;
@property(nonatomic, readonly) NSUInteger height;
@property(nonatomic, readonly) NSUInteger mineCount;
@property(nonatomic, readonly) NSUInteger remainingMineEstimate;
@property(nonatomic, readonly) TGMinesweeperDifficulty difficulty;
@property(nonatomic, readonly) TGMinesweeperState state;
@property(nonatomic, readonly) NSUInteger gamesWon;
@property(nonatomic, readonly) NSUInteger gamesLost;

- (void)startNewGameWithDifficulty:(TGMinesweeperDifficulty)difficulty;
- (BOOL)revealCellAtIndex:(NSUInteger)index;
- (BOOL)toggleFlagAtIndex:(NSUInteger)index;
- (NSDictionary *)cellAtIndex:(NSUInteger)index;
- (NSTimeInterval)elapsedSeconds;
- (void)pauseTiming;
- (void)resumeTiming;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
