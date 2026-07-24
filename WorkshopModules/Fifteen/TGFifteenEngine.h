#import <Foundation/Foundation.h>

@interface TGFifteenEngine : NSObject {
@private
    NSMutableArray *_tiles;
    NSUInteger _moves;
    NSUInteger _gamesStarted;
    NSUInteger _gamesWon;
    BOOL _finished;
}

@property(nonatomic, readonly) NSArray *tiles;
@property(nonatomic, readonly) NSUInteger moves;
@property(nonatomic, readonly) NSUInteger gamesStarted;
@property(nonatomic, readonly) NSUInteger gamesWon;
@property(nonatomic, readonly, getter=isFinished) BOOL finished;

- (void)newGame;
- (NSUInteger)blankIndex;
- (BOOL)canMoveTileAtIndex:(NSUInteger)index;
- (BOOL)moveTileAtIndex:(NSUInteger)index;
- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
