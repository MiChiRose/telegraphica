#import <Foundation/Foundation.h>

typedef enum {
    TGCheckersModeLocal = 0,
    TGCheckersModeComputer = 1
} TGCheckersMode;

typedef enum {
    TGCheckersPlayerRed = 1,
    TGCheckersPlayerBlack = -1
} TGCheckersPlayer;

@interface TGCheckersEngine : NSObject {
    NSMutableArray *_board;
    TGCheckersMode _mode;
    TGCheckersPlayer _currentPlayer;
    NSInteger _forcedCaptureRow;
    NSInteger _forcedCaptureColumn;
    BOOL _finished;
    TGCheckersPlayer _winner;
    NSUInteger _redWins;
    NSUInteger _blackWins;
}

- (void)startNewGameWithMode:(TGCheckersMode)mode;
- (NSInteger)pieceAtRow:(NSInteger)row column:(NSInteger)column;
- (NSArray *)legalMovesFromRow:(NSInteger)row column:(NSInteger)column;
- (BOOL)moveFromRow:(NSInteger)fromRow
             column:(NSInteger)fromColumn
              toRow:(NSInteger)toRow
             column:(NSInteger)toColumn;
- (BOOL)performComputerMove;
- (BOOL)hasAnyCaptureForCurrentPlayer;
- (TGCheckersMode)mode;
- (TGCheckersPlayer)currentPlayer;
- (BOOL)isFinished;
- (TGCheckersPlayer)winner;
- (NSInteger)forcedCaptureRow;
- (NSInteger)forcedCaptureColumn;
- (NSUInteger)redWins;
- (NSUInteger)blackWins;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
