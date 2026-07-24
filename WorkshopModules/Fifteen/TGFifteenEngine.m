#import "TGFifteenEngine.h"
#include <stdlib.h>

static BOOL TGFifteenTilesAreSolved(NSArray *tiles) {
    if ([tiles count] != 16) return NO;
    NSUInteger index = 0;
    for (index = 0; index < 15; index++) {
        if ([[tiles objectAtIndex:index] unsignedIntegerValue] != index + 1) return NO;
    }
    return [[tiles objectAtIndex:15] unsignedIntegerValue] == 0;
}

static BOOL TGFifteenTilesAreValidAndSolvable(NSArray *tiles) {
    if (![tiles isKindOfClass:[NSArray class]] || [tiles count] != 16) return NO;
    BOOL seen[16] = { NO };
    NSUInteger blankIndex = NSNotFound;
    NSUInteger index = 0;
    for (index = 0; index < 16; index++) {
        id value = [tiles objectAtIndex:index];
        if (![value isKindOfClass:[NSNumber class]]) return NO;
        NSInteger tile = [value integerValue];
        if (tile < 0 || tile > 15 || seen[tile]) return NO;
        seen[tile] = YES;
        if (tile == 0) blankIndex = index;
    }
    if (blankIndex == NSNotFound) return NO;

    NSUInteger inversions = 0;
    NSUInteger left = 0;
    for (left = 0; left < 16; left++) {
        NSInteger leftValue = [[tiles objectAtIndex:left] integerValue];
        if (leftValue == 0) continue;
        NSUInteger right = 0;
        for (right = left + 1; right < 16; right++) {
            NSInteger rightValue = [[tiles objectAtIndex:right] integerValue];
            if (rightValue != 0 && leftValue > rightValue) inversions++;
        }
    }
    NSUInteger blankRowFromBottom = 4 - (blankIndex / 4);
    return ((blankRowFromBottom % 2 == 0) ? (inversions % 2 == 1) : (inversions % 2 == 0));
}

@implementation TGFifteenEngine

@synthesize tiles = _tiles;
@synthesize moves = _moves;
@synthesize gamesStarted = _gamesStarted;
@synthesize gamesWon = _gamesWon;
@synthesize finished = _finished;

- (id)init {
    self = [super init];
    if (self) [self newGame];
    return self;
}

- (NSUInteger)blankIndex {
    return [_tiles indexOfObject:@0];
}

- (NSArray *)movableIndexesForBlankIndex:(NSUInteger)blankIndex {
    NSMutableArray *indexes = [NSMutableArray arrayWithCapacity:4];
    NSUInteger row = blankIndex / 4;
    NSUInteger column = blankIndex % 4;
    if (row > 0) [indexes addObject:[NSNumber numberWithUnsignedInteger:blankIndex - 4]];
    if (row < 3) [indexes addObject:[NSNumber numberWithUnsignedInteger:blankIndex + 4]];
    if (column > 0) [indexes addObject:[NSNumber numberWithUnsignedInteger:blankIndex - 1]];
    if (column < 3) [indexes addObject:[NSNumber numberWithUnsignedInteger:blankIndex + 1]];
    return indexes;
}

- (void)newGame {
    [_tiles release];
    _tiles = [[NSMutableArray alloc] initWithCapacity:16];
    NSUInteger value = 0;
    for (value = 1; value <= 15; value++) {
        [_tiles addObject:[NSNumber numberWithUnsignedInteger:value]];
    }
    [_tiles addObject:@0];

    NSUInteger blank = 15;
    NSUInteger previousBlank = NSNotFound;
    NSUInteger step = 0;
    for (step = 0; step < 320; step++) {
        NSMutableArray *choices = [NSMutableArray arrayWithArray:[self movableIndexesForBlankIndex:blank]];
        if ([choices count] > 1 && previousBlank != NSNotFound) {
            [choices removeObject:[NSNumber numberWithUnsignedInteger:previousBlank]];
        }
        NSUInteger choiceIndex = (NSUInteger)arc4random_uniform((u_int32_t)[choices count]);
        NSUInteger tileIndex = [[choices objectAtIndex:choiceIndex] unsignedIntegerValue];
        [_tiles exchangeObjectAtIndex:blank withObjectAtIndex:tileIndex];
        previousBlank = blank;
        blank = tileIndex;
    }
    if (TGFifteenTilesAreSolved(_tiles)) {
        NSUInteger tileIndex = [[[self movableIndexesForBlankIndex:blank] objectAtIndex:0] unsignedIntegerValue];
        [_tiles exchangeObjectAtIndex:blank withObjectAtIndex:tileIndex];
    }
    _moves = 0;
    _finished = NO;
    _gamesStarted++;
}

- (BOOL)canMoveTileAtIndex:(NSUInteger)index {
    if (_finished || index >= 16) return NO;
    NSUInteger blank = [self blankIndex];
    if (blank == NSNotFound) return NO;
    NSUInteger row = index / 4;
    NSUInteger column = index % 4;
    NSUInteger blankRow = blank / 4;
    NSUInteger blankColumn = blank % 4;
    NSInteger distance = labs((NSInteger)row - (NSInteger)blankRow) +
                         labs((NSInteger)column - (NSInteger)blankColumn);
    return distance == 1;
}

- (BOOL)moveTileAtIndex:(NSUInteger)index {
    if (![self canMoveTileAtIndex:index]) return NO;
    NSUInteger blank = [self blankIndex];
    [_tiles exchangeObjectAtIndex:index withObjectAtIndex:blank];
    _moves++;
    if (TGFifteenTilesAreSolved(_tiles)) {
        _finished = YES;
        _gamesWon++;
    }
    return YES;
}

- (NSDictionary *)dictionaryRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema",
            _tiles, @"tiles",
            [NSNumber numberWithUnsignedInteger:_moves], @"moves",
            [NSNumber numberWithUnsignedInteger:_gamesStarted], @"gamesStarted",
            [NSNumber numberWithUnsignedInteger:_gamesWon], @"gamesWon",
            [NSNumber numberWithBool:_finished], @"finished",
            nil];
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    NSArray *tiles = [dictionary objectForKey:@"tiles"];
    if (!TGFifteenTilesAreValidAndSolvable(tiles)) return NO;
    BOOL finished = [[dictionary objectForKey:@"finished"] boolValue];
    if (finished != TGFifteenTilesAreSolved(tiles)) return NO;
    [_tiles release];
    _tiles = [[NSMutableArray alloc] initWithArray:tiles];
    _moves = [[dictionary objectForKey:@"moves"] unsignedIntegerValue];
    _gamesStarted = [[dictionary objectForKey:@"gamesStarted"] unsignedIntegerValue];
    _gamesWon = [[dictionary objectForKey:@"gamesWon"] unsignedIntegerValue];
    _finished = finished;
    return YES;
}

- (void)dealloc {
    [_tiles release];
    [super dealloc];
}

@end
