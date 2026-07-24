#import <Foundation/Foundation.h>

typedef enum {
    TGSolitaireSourceNone = 0,
    TGSolitaireSourceWaste = 1,
    TGSolitaireSourceTableau = 2,
    TGSolitaireSourceFoundation = 3
} TGSolitaireSource;

@interface TGSolitaireEngine : NSObject {
    NSMutableArray *_stock;
    NSMutableArray *_waste;
    NSMutableArray *_tableau;
    NSMutableArray *_foundations;
    NSMutableSet *_faceUpCards;
    NSMutableArray *_undoStates;
    NSUInteger _gamesStarted;
    NSUInteger _gamesWon;
    BOOL _won;
}

- (void)startNewDeal;
- (void)drawFromStock;
- (BOOL)moveWasteToTableau:(NSInteger)tableauIndex;
- (BOOL)moveWasteToFoundation;
- (BOOL)moveTableau:(NSInteger)sourceIndex cardIndex:(NSInteger)cardIndex toTableau:(NSInteger)targetIndex;
- (BOOL)moveTableauTopToFoundation:(NSInteger)tableauIndex;
- (BOOL)moveFoundation:(NSInteger)foundationIndex toTableau:(NSInteger)tableauIndex;
- (BOOL)autoMoveCardFromSource:(TGSolitaireSource)source pile:(NSInteger)pile cardIndex:(NSInteger)cardIndex;
- (BOOL)canUndo;
- (void)undo;

- (NSUInteger)stockCount;
- (NSInteger)wasteCard;
- (NSArray *)tableauCardsAtIndex:(NSInteger)index;
- (NSInteger)foundationTopCardForSuit:(NSInteger)suit;
- (BOOL)isCardFaceUp:(NSInteger)card;
- (BOOL)isWon;
- (NSUInteger)gamesStarted;
- (NSUInteger)gamesWon;

- (NSInteger)rankForCard:(NSInteger)card;
- (NSInteger)suitForCard:(NSInteger)card;
- (BOOL)isRedCard:(NSInteger)card;
- (NSString *)shortNameForCard:(NSInteger)card;

- (NSDictionary *)dictionaryRepresentation;
- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary;

@end
