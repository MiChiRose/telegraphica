#import <Foundation/Foundation.h>
#import "../../WorkshopModules/Common/TGGameSaveStore.h"
#import "../../WorkshopModules/TicTacToe/TGTicTacToeEngine.h"
#import "../../WorkshopModules/Minesweeper/TGMinesweeperEngine.h"
#import "../../WorkshopModules/Checkers/TGCheckersEngine.h"
#import "../../WorkshopModules/Solitaire/TGSolitaireEngine.h"
#import "../../WorkshopModules/PacMan/TGPacManEngine.h"

static NSUInteger TGTestsRun = 0;
static NSUInteger TGTestsFailed = 0;

static void TGAssert(BOOL condition, NSString *message) {
    TGTestsRun++;
    if (!condition) {
        TGTestsFailed++;
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
    }
}

static NSMutableArray *TGEmptyCheckersBoard(void) {
    NSMutableArray *board = [NSMutableArray arrayWithCapacity:64];
    NSUInteger index;
    for (index = 0; index < 64; index++) [board addObject:@0];
    return board;
}

static void TGSetCheckersPiece(NSMutableArray *board, NSInteger piece, NSInteger row, NSInteger column) {
    [board replaceObjectAtIndex:(NSUInteger)(row * 8 + column)
                     withObject:[NSNumber numberWithInteger:piece]];
}

static NSDictionary *TGCheckersState(NSArray *board, TGCheckersMode mode,
                                     TGCheckersPlayer currentPlayer) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema",
            board, @"board",
            [NSNumber numberWithInteger:mode], @"mode",
            [NSNumber numberWithInteger:currentPlayer], @"currentPlayer",
            @-1, @"forcedRow",
            @-1, @"forcedColumn",
            @NO, @"finished",
            @0, @"winner",
            @0, @"redWins",
            @0, @"blackWins", nil];
}

static NSMutableArray *TGCardsExcluding(NSSet *excluded) {
    NSMutableArray *cards = [NSMutableArray array];
    NSInteger card;
    for (card = 0; card < 52; card++) {
        NSNumber *number = [NSNumber numberWithInteger:card];
        if (![excluded containsObject:number]) [cards addObject:number];
    }
    return cards;
}

static NSDictionary *TGSolitaireState(NSArray *stock, NSArray *waste,
                                      NSArray *tableau, NSArray *foundations,
                                      NSArray *faceUp, BOOL won) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @1, @"schema",
            stock, @"stock",
            waste, @"waste",
            tableau, @"tableau",
            foundations, @"foundations",
            faceUp, @"faceUp",
            [NSNumber numberWithBool:won], @"won",
            @1, @"gamesStarted",
            @0, @"gamesWon", nil];
}

static NSArray *TGEmptyTableau(void) {
    return [NSArray arrayWithObjects:
            [NSArray array], [NSArray array], [NSArray array], [NSArray array],
            [NSArray array], [NSArray array], [NSArray array], nil];
}

static NSArray *TGEmptyFoundations(void) {
    return [NSArray arrayWithObjects:
            [NSArray array], [NSArray array], [NSArray array], [NSArray array], nil];
}

static void TGTestTicTacToe(void) {
    TGTicTacToeEngine *engine = [[[TGTicTacToeEngine alloc] init] autorelease];
    [engine setMode:TGTicTacToeModeTwoPlayers];
    TGAssert([engine playAtIndex:0], @"Tic-Tac-Toe accepts the first move.");
    TGAssert([engine playAtIndex:3], @"Tic-Tac-Toe alternates players.");
    [engine playAtIndex:1];
    [engine playAtIndex:4];
    [engine playAtIndex:2];
    TGAssert([[engine winner] isEqualToString:@"X"], @"Tic-Tac-Toe detects a winner.");
    TGAssert([[engine winningIndexes] containsIndex:0] &&
             [[engine winningIndexes] containsIndex:1] &&
             [[engine winningIndexes] containsIndex:2],
             @"Tic-Tac-Toe reports the complete winning line.");
    TGAssert([engine xWins] == 1, @"Tic-Tac-Toe updates series statistics.");
    TGAssert(![engine playAtIndex:5], @"Tic-Tac-Toe rejects moves after a win.");

    NSDictionary *saved = [engine dictionaryRepresentation];
    TGTicTacToeEngine *restored = [[[TGTicTacToeEngine alloc] init] autorelease];
    TGAssert([restored restoreFromDictionary:saved] &&
             [[restored winner] isEqualToString:@"X"] &&
             [restored xWins] == 1,
             @"Tic-Tac-Toe restores a saved series.");

    NSDictionary *blocking = [NSDictionary dictionaryWithObjectsAndKeys:
                              @1, @"schema_version",
                              [NSArray arrayWithObjects:@"X", @"X", @"", @"O", @"", @"", @"", @"", @"", nil], @"board",
                              @"O", @"current_player",
                              @1, @"mode",
                              @2, @"difficulty",
                              @0, @"x_wins", @0, @"o_wins", @0, @"draws", nil];
    TGAssert([restored restoreFromDictionary:blocking] && [restored performComputerMove],
             @"Tic-Tac-Toe hard computer performs a move.");
    TGAssert([[[restored board] objectAtIndex:2] isEqualToString:@"O"],
             @"Tic-Tac-Toe hard computer blocks an immediate loss.");
    TGAssert(![restored restoreFromDictionary:
               [NSDictionary dictionaryWithObject:[NSArray array] forKey:@"board"]],
             @"Tic-Tac-Toe rejects malformed saves.");
}

static void TGTestMinesweeper(void) {
    TGMinesweeperEngine *engine = [[[TGMinesweeperEngine alloc] init] autorelease];
    [engine startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
    TGAssert([engine width] == 9 && [engine height] == 9 && [engine mineCount] == 10,
             @"Minesweeper configures beginner difficulty.");
    [engine startNewGameWithDifficulty:TGMinesweeperDifficultyIntermediate];
    TGAssert([engine width] == 16 && [engine height] == 16 && [engine mineCount] == 40,
             @"Minesweeper configures intermediate difficulty.");
    [engine startNewGameWithDifficulty:TGMinesweeperDifficultyExpert];
    TGAssert([engine width] == 30 && [engine height] == 16 && [engine mineCount] == 99,
             @"Minesweeper configures expert difficulty.");

    [engine startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
    TGAssert([engine toggleFlagAtIndex:80] && [engine remainingMineEstimate] == 9,
             @"Minesweeper toggles flags and updates the mine counter.");
    TGAssert([engine toggleFlagAtIndex:80] && [engine remainingMineEstimate] == 10,
             @"Minesweeper removes flags.");
    NSUInteger first = 40;
    TGAssert([engine revealCellAtIndex:first], @"Minesweeper accepts the first reveal.");
    TGAssert(![[[engine cellAtIndex:first] objectForKey:@"mine"] boolValue],
             @"Minesweeper keeps the first cell safe.");
    NSInteger row = (NSInteger)(first / [engine width]);
    NSInteger column = (NSInteger)(first % [engine width]);
    NSInteger dy;
    NSInteger dx;
    BOOL neighborsSafe = YES;
    for (dy = -1; dy <= 1; dy++) {
        for (dx = -1; dx <= 1; dx++) {
            NSInteger candidateRow = row + dy;
            NSInteger candidateColumn = column + dx;
            if (candidateRow >= 0 && candidateColumn >= 0 &&
                candidateRow < (NSInteger)[engine height] && candidateColumn < (NSInteger)[engine width]) {
                NSUInteger candidate = (NSUInteger)candidateRow * [engine width] + (NSUInteger)candidateColumn;
                if ([[[engine cellAtIndex:candidate] objectForKey:@"mine"] boolValue]) neighborsSafe = NO;
            }
        }
    }
    TGAssert(neighborsSafe, @"Minesweeper keeps all first-click neighbors safe.");

    NSDictionary *saved = [engine dictionaryRepresentation];
    TGMinesweeperEngine *restored = [[[TGMinesweeperEngine alloc] init] autorelease];
    TGAssert([restored restoreFromDictionary:saved] &&
             [restored state] == [engine state] &&
             [restored mineCount] == [engine mineCount],
             @"Minesweeper restores an unfinished game.");

    NSUInteger mineIndex = NSNotFound;
    NSUInteger index;
    for (index = 0; index < [engine width] * [engine height]; index++) {
        if ([[[engine cellAtIndex:index] objectForKey:@"mine"] boolValue]) {
            mineIndex = index;
            break;
        }
    }
    TGAssert(mineIndex != NSNotFound && [engine revealCellAtIndex:mineIndex] &&
             [engine state] == TGMinesweeperStateLost && [engine gamesLost] == 1,
             @"Minesweeper detects a loss.");

    [restored startNewGameWithDifficulty:TGMinesweeperDifficultyBeginner];
    [restored revealCellAtIndex:40];
    for (index = 0; index < [restored width] * [restored height]; index++) {
        if (![[[restored cellAtIndex:index] objectForKey:@"mine"] boolValue]) {
            [restored revealCellAtIndex:index];
        }
    }
    TGAssert([restored state] == TGMinesweeperStateWon && [restored gamesWon] == 1,
             @"Minesweeper detects a win.");
    TGAssert(![restored restoreFromDictionary:[NSDictionary dictionary]],
             @"Minesweeper rejects malformed saves.");
}

static void TGTestCheckers(void) {
    TGCheckersEngine *engine = [[[TGCheckersEngine alloc] init] autorelease];
    TGAssert([[engine legalMovesFromRow:5 column:0] count] > 0,
             @"Checkers exposes initial legal moves.");

    NSMutableArray *board = TGEmptyCheckersBoard();
    TGSetCheckersPiece(board, 1, 5, 0);
    TGSetCheckersPiece(board, 1, 5, 4);
    TGSetCheckersPiece(board, -1, 4, 1);
    TGSetCheckersPiece(board, -1, 2, 3);
    TGAssert([engine restoreFromDictionary:TGCheckersState(board, TGCheckersModeLocal,
                                                           TGCheckersPlayerRed)],
             @"Checkers restores a test position.");
    TGAssert([engine hasAnyCaptureForCurrentPlayer] &&
             [[engine legalMovesFromRow:5 column:4] count] == 0,
             @"Checkers enforces mandatory captures globally.");
    TGAssert([engine moveFromRow:5 column:0 toRow:3 column:2] &&
             [engine forcedCaptureRow] == 3 && [engine forcedCaptureColumn] == 2,
             @"Checkers requires the next step of a capture chain.");
    TGAssert([engine moveFromRow:3 column:2 toRow:1 column:4],
             @"Checkers completes chained captures.");
    TGAssert([engine pieceAtRow:4 column:1] == 0 && [engine pieceAtRow:2 column:3] == 0,
             @"Checkers removes every captured piece.");

    board = TGEmptyCheckersBoard();
    TGSetCheckersPiece(board, 1, 1, 2);
    TGSetCheckersPiece(board, -1, 2, 5);
    TGAssert([engine restoreFromDictionary:TGCheckersState(board, TGCheckersModeLocal,
                                                           TGCheckersPlayerRed)] &&
             [engine moveFromRow:1 column:2 toRow:0 column:1] &&
             [engine pieceAtRow:0 column:1] == 2,
             @"Checkers promotes a piece to king.");

    board = TGEmptyCheckersBoard();
    TGSetCheckersPiece(board, -1, 2, 1);
    TGSetCheckersPiece(board, 1, 6, 1);
    TGAssert([engine restoreFromDictionary:TGCheckersState(board, TGCheckersModeComputer,
                                                           TGCheckersPlayerBlack)] &&
             [engine performComputerMove],
             @"Checkers computer performs a legal move.");

    NSMutableDictionary *legacy = [NSMutableDictionary dictionaryWithDictionary:
                                   [engine dictionaryRepresentation]];
    [legacy removeObjectForKey:@"schema"];
    TGCheckersEngine *restored = [[[TGCheckersEngine alloc] init] autorelease];
    TGAssert([restored restoreFromDictionary:legacy] &&
             [[[restored dictionaryRepresentation] objectForKey:@"schema"] integerValue] == 1,
             @"Checkers migrates a legacy save to the current schema.");
    NSMutableDictionary *invalid = [NSMutableDictionary dictionaryWithDictionary:
                                    [engine dictionaryRepresentation]];
    [invalid setObject:@99 forKey:@"currentPlayer"];
    TGAssert(![restored restoreFromDictionary:invalid],
             @"Checkers rejects invalid save state without mutating the board.");
}

static void TGTestSolitaire(void) {
    TGSolitaireEngine *engine = [[[TGSolitaireEngine alloc] init] autorelease];
    TGAssert([engine stockCount] == 24, @"Solitaire deals 24 cards into stock.");
    NSInteger pile;
    BOOL tableauCorrect = YES;
    for (pile = 0; pile < 7; pile++) {
        NSArray *cards = [engine tableauCardsAtIndex:pile];
        if ([cards count] != (NSUInteger)pile + 1 ||
            ![engine isCardFaceUp:[[cards lastObject] integerValue]]) tableauCorrect = NO;
    }
    TGAssert(tableauCorrect, @"Solitaire builds seven readable tableau piles.");
    [engine drawFromStock];
    TGAssert([engine stockCount] == 23 && [engine wasteCard] >= 0 && [engine canUndo],
             @"Solitaire draws one card and records undo.");
    [engine undo];
    TGAssert([engine stockCount] == 24 && [engine wasteCard] == -1,
             @"Solitaire undo restores the previous state.");

    NSSet *used = [NSSet setWithObjects:@11, @25, nil];
    NSMutableArray *stock = TGCardsExcluding(used);
    NSArray *tableau = [NSArray arrayWithObjects:
                        [NSArray arrayWithObject:@25], [NSArray array], [NSArray array],
                        [NSArray array], [NSArray array], [NSArray array], [NSArray array], nil];
    NSDictionary *legalState = TGSolitaireState(stock, [NSArray arrayWithObject:@11],
                                                tableau, TGEmptyFoundations(),
                                                [NSArray arrayWithObjects:@11, @25, nil], NO);
    TGAssert([engine restoreFromDictionary:legalState] && [engine moveWasteToTableau:0],
             @"Solitaire accepts descending alternating-color tableau moves.");
    TGAssert([[engine tableauCardsAtIndex:0] count] == 2,
             @"Solitaire moves the selected card onto the tableau.");

    NSMutableArray *clubFoundation = [NSMutableArray array];
    NSInteger card;
    for (card = 39; card < 51; card++) [clubFoundation addObject:[NSNumber numberWithInteger:card]];
    NSArray *foundations = [NSArray arrayWithObjects:
                            [NSArray arrayWithObjects:@0,@1,@2,@3,@4,@5,@6,@7,@8,@9,@10,@11,@12,nil],
                            [NSArray arrayWithObjects:@13,@14,@15,@16,@17,@18,@19,@20,@21,@22,@23,@24,@25,nil],
                            [NSArray arrayWithObjects:@26,@27,@28,@29,@30,@31,@32,@33,@34,@35,@36,@37,@38,nil],
                            clubFoundation, nil];
    NSMutableArray *allFaceUp = [NSMutableArray array];
    for (card = 0; card < 52; card++) [allFaceUp addObject:[NSNumber numberWithInteger:card]];
    NSDictionary *winningState = TGSolitaireState([NSArray array], [NSArray arrayWithObject:@51],
                                                  TGEmptyTableau(), foundations, allFaceUp, NO);
    TGAssert([engine restoreFromDictionary:winningState] &&
             [engine moveWasteToFoundation] && [engine isWon] && [engine gamesWon] == 1,
             @"Solitaire detects completion of all foundations.");

    NSMutableDictionary *legacy = [NSMutableDictionary dictionaryWithDictionary:
                                   [engine dictionaryRepresentation]];
    [legacy removeObjectForKey:@"schema"];
    TGSolitaireEngine *restored = [[[TGSolitaireEngine alloc] init] autorelease];
    TGAssert([restored restoreFromDictionary:legacy] &&
             [[[restored dictionaryRepresentation] objectForKey:@"schema"] integerValue] == 1,
             @"Solitaire migrates a legacy save.");
    NSMutableDictionary *duplicate = [NSMutableDictionary dictionaryWithDictionary:
                                      [engine dictionaryRepresentation]];
    [duplicate setObject:[NSArray arrayWithObject:@0] forKey:@"stock"];
    TGAssert(![restored restoreFromDictionary:duplicate],
             @"Solitaire rejects duplicate or oversized card sets.");
}

static void TGTestSaveStore(void) {
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [[NSProcessInfo processInfo] globallyUniqueString]];
    NSURL *directoryURL = [NSURL fileURLWithPath:directory isDirectory:YES];
    TGGameSaveStore *store = [[[TGGameSaveStore alloc] initWithDataDirectoryURL:directoryURL
                                                                       fileName:@"state.plist"] autorelease];
    NSDictionary *source = [NSDictionary dictionaryWithObjectsAndKeys:@1, @"schema", @"ok", @"value", nil];
    NSError *error = nil;
    TGAssert([store saveDictionary:source error:&error], @"Game save store writes a binary property list.");
    NSDictionary *loaded = [store loadDictionaryQuarantiningCorruptFile:&error];
    TGAssert([loaded isEqualToDictionary:source], @"Game save store restores an atomic save.");

    NSString *savePath = [directory stringByAppendingPathComponent:@"state.plist"];
    [@"not a property list" writeToFile:savePath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    error = nil;
    TGAssert([store loadDictionaryQuarantiningCorruptFile:&error] == nil,
             @"Game save store refuses corrupt data.");
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
    BOOL foundQuarantine = NO;
    NSString *file = nil;
    for (file in files) {
        if ([file hasPrefix:@"state.plist.corrupt-"]) foundQuarantine = YES;
    }
    TGAssert(foundQuarantine, @"Game save store quarantines corrupt data for diagnostics.");
    TGAssert([store clearData:&error] &&
             ![[NSFileManager defaultManager] fileExistsAtPath:directory],
             @"Game save store clears only its module directory.");
}

static void TGTestPacMan(void) {
    TGPacManEngine *engine = [[[TGPacManEngine alloc] init] autorelease];
    TGAssert([engine width] == 19 && [engine height] == 15,
             @"Pac-Man builds the expected compact maze.");
    NSUInteger pellets = [engine pelletCount];
    TGAssert([engine stepInDirection:TGPacManDirectionLeft] &&
             [engine pelletCount] + 1 == pellets &&
             [engine score] == 10,
             @"Pac-Man moves through the maze and consumes a pellet.");
    TGAssert(![engine stepInDirection:TGPacManDirectionDown],
             @"Pac-Man refuses to cross a wall.");
    NSDictionary *saved = [engine dictionaryRepresentation];
    TGPacManEngine *restored = [[[TGPacManEngine alloc] init] autorelease];
    TGAssert([restored restoreFromDictionary:saved] &&
             [restored pacmanIndex] == [engine pacmanIndex] &&
             [restored pelletCount] == [engine pelletCount],
             @"Pac-Man restores saved progress.");
    TGAssert(![restored restoreFromDictionary:[NSDictionary dictionary]],
             @"Pac-Man rejects malformed saves.");
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGTestTicTacToe();
    TGTestMinesweeper();
    TGTestCheckers();
    TGTestSolitaire();
    TGTestPacMan();
    TGTestSaveStore();
    printf("Workshop game tests: %lu assertions, %lu failures\n",
           (unsigned long)TGTestsRun, (unsigned long)TGTestsFailed);
    [pool drain];
    return TGTestsFailed == 0 ? 0 : 1;
}
