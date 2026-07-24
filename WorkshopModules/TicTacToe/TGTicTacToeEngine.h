#import <Foundation/Foundation.h>

typedef enum {
    TGTicTacToeModeTwoPlayers = 0,
    TGTicTacToeModeComputer = 1
} TGTicTacToeMode;

typedef enum {
    TGTicTacToeDifficultyEasy = 0,
    TGTicTacToeDifficultyMedium = 1,
    TGTicTacToeDifficultyHard = 2
} TGTicTacToeDifficulty;

@interface TGTicTacToeEngine : NSObject {
@private
    NSMutableArray *_board;
    NSString *_currentPlayer;
    NSString *_winner;
    NSIndexSet *_winningIndexes;
    TGTicTacToeMode _mode;
    TGTicTacToeDifficulty _difficulty;
    NSUInteger _xWins;
    NSUInteger _oWins;
    NSUInteger _draws;
}

@property(nonatomic, readonly) NSArray *board;
@property(nonatomic, copy, readonly) NSString *currentPlayer;
@property(nonatomic, copy, readonly) NSString *winner;
@property(nonatomic, retain, readonly) NSIndexSet *winningIndexes;
@property(nonatomic, assign) TGTicTacToeMode mode;
@property(nonatomic, assign) TGTicTacToeDifficulty difficulty;
@property(nonatomic, readonly) NSUInteger xWins;
@property(nonatomic, readonly) NSUInteger oWins;
@property(nonatomic, readonly) NSUInteger draws;

- (void)newRound;
- (BOOL)playAtIndex:(NSUInteger)index;
- (BOOL)performComputerMove;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
