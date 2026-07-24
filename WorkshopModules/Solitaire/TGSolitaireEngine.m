#import "TGSolitaireEngine.h"

@interface TGSolitaireEngine ()
- (NSMutableArray *)tableauPileAtIndex:(NSInteger)index;
- (NSMutableArray *)foundationAtIndex:(NSInteger)index;
- (BOOL)canPlaceCard:(NSInteger)card onTableau:(NSInteger)tableauIndex;
- (BOOL)canPlaceCardOnFoundation:(NSInteger)card;
- (void)pushUndoState;
- (void)revealTableauTop:(NSInteger)tableauIndex;
- (void)evaluateWin;
- (NSDictionary *)stateDictionary;
- (BOOL)restoreStateDictionary:(NSDictionary *)dictionary includeStatistics:(BOOL)includeStatistics;
@end

@implementation TGSolitaireEngine

- (id)init {
    self = [super init];
    if (self) {
        _stock = [[NSMutableArray alloc] init];
        _waste = [[NSMutableArray alloc] init];
        _tableau = [[NSMutableArray alloc] initWithCapacity:7];
        _foundations = [[NSMutableArray alloc] initWithCapacity:4];
        _faceUpCards = [[NSMutableSet alloc] init];
        _undoStates = [[NSMutableArray alloc] init];
        [self startNewDeal];
    }
    return self;
}

- (void)startNewDeal {
    [_stock removeAllObjects];
    [_waste removeAllObjects];
    [_tableau removeAllObjects];
    [_foundations removeAllObjects];
    [_faceUpCards removeAllObjects];
    [_undoStates removeAllObjects];
    _won = NO;
    _gamesStarted++;

    NSMutableArray *deck = [NSMutableArray arrayWithCapacity:52];
    NSInteger card;
    for (card = 0; card < 52; card++) {
        [deck addObject:[NSNumber numberWithInteger:card]];
    }
    NSInteger index;
    for (index = 51; index > 0; index--) {
        NSInteger swapIndex = (NSInteger)(arc4random_uniform((uint32_t)(index + 1)));
        [deck exchangeObjectAtIndex:(NSUInteger)index withObjectAtIndex:(NSUInteger)swapIndex];
    }

    NSInteger pileIndex;
    for (pileIndex = 0; pileIndex < 7; pileIndex++) {
        NSMutableArray *pile = [NSMutableArray array];
        NSInteger dealIndex;
        for (dealIndex = 0; dealIndex <= pileIndex; dealIndex++) {
            NSNumber *number = [deck lastObject];
            [deck removeLastObject];
            [pile addObject:number];
            if (dealIndex == pileIndex) [_faceUpCards addObject:number];
        }
        [_tableau addObject:pile];
    }
    for (pileIndex = 0; pileIndex < 4; pileIndex++) {
        [_foundations addObject:[NSMutableArray array]];
    }
    [_stock addObjectsFromArray:deck];
}

- (NSMutableArray *)tableauPileAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[_tableau count]) return nil;
    return [_tableau objectAtIndex:(NSUInteger)index];
}

- (NSMutableArray *)foundationAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)[_foundations count]) return nil;
    return [_foundations objectAtIndex:(NSUInteger)index];
}

- (NSInteger)rankForCard:(NSInteger)card { return card < 0 ? 0 : (card % 13) + 1; }
- (NSInteger)suitForCard:(NSInteger)card { return card < 0 ? -1 : card / 13; }
- (BOOL)isRedCard:(NSInteger)card {
    NSInteger suit = [self suitForCard:card];
    return suit == 1 || suit == 2;
}

- (NSString *)shortNameForCard:(NSInteger)card {
    if (card < 0) return @"";
    NSArray *ranks = [NSArray arrayWithObjects:@"A", @"2", @"3", @"4", @"5", @"6", @"7",
                      @"8", @"9", @"10", @"J", @"Q", @"K", nil];
    NSArray *suits = [NSArray arrayWithObjects:@"♠", @"♥", @"♦", @"♣", nil];
    return [NSString stringWithFormat:@"%@%@", [ranks objectAtIndex:(NSUInteger)([self rankForCard:card] - 1)],
            [suits objectAtIndex:(NSUInteger)[self suitForCard:card]]];
}

- (void)pushUndoState {
    [_undoStates addObject:[self stateDictionary]];
    if ([_undoStates count] > 50) [_undoStates removeObjectAtIndex:0];
}

- (void)drawFromStock {
    if ([_stock count] == 0 && [_waste count] == 0) return;
    [self pushUndoState];
    if ([_stock count] > 0) {
        NSNumber *card = [_stock lastObject];
        [_stock removeLastObject];
        [_waste addObject:card];
        [_faceUpCards addObject:card];
    } else {
        while ([_waste count] > 0) {
            NSNumber *card = [_waste lastObject];
            [_waste removeLastObject];
            [_stock addObject:card];
            [_faceUpCards removeObject:card];
        }
    }
}

- (BOOL)canPlaceCard:(NSInteger)card onTableau:(NSInteger)tableauIndex {
    NSMutableArray *pile = [self tableauPileAtIndex:tableauIndex];
    if (!pile) return NO;
    if ([pile count] == 0) return [self rankForCard:card] == 13;
    NSInteger target = [[pile lastObject] integerValue];
    if (![self isCardFaceUp:target]) return NO;
    return [self rankForCard:target] == [self rankForCard:card] + 1 &&
           [self isRedCard:target] != [self isRedCard:card];
}

- (BOOL)canPlaceCardOnFoundation:(NSInteger)card {
    NSInteger suit = [self suitForCard:card];
    NSMutableArray *foundation = [self foundationAtIndex:suit];
    if (!foundation) return NO;
    if ([foundation count] == 0) return [self rankForCard:card] == 1;
    NSInteger topCard = [[foundation lastObject] integerValue];
    return [self rankForCard:card] == [self rankForCard:topCard] + 1;
}

- (BOOL)moveWasteToTableau:(NSInteger)tableauIndex {
    if ([_waste count] == 0) return NO;
    NSInteger card = [[_waste lastObject] integerValue];
    if (![self canPlaceCard:card onTableau:tableauIndex]) return NO;
    [self pushUndoState];
    [[self tableauPileAtIndex:tableauIndex] addObject:[_waste lastObject]];
    [_waste removeLastObject];
    return YES;
}

- (BOOL)moveWasteToFoundation {
    if ([_waste count] == 0) return NO;
    NSInteger card = [[_waste lastObject] integerValue];
    if (![self canPlaceCardOnFoundation:card]) return NO;
    [self pushUndoState];
    [[self foundationAtIndex:[self suitForCard:card]] addObject:[_waste lastObject]];
    [_waste removeLastObject];
    [self evaluateWin];
    return YES;
}

- (BOOL)sequenceIsValidInPile:(NSArray *)pile fromIndex:(NSInteger)cardIndex {
    if (cardIndex < 0 || cardIndex >= (NSInteger)[pile count]) return NO;
    NSInteger index;
    for (index = cardIndex; index < (NSInteger)[pile count]; index++) {
        NSInteger card = [[pile objectAtIndex:(NSUInteger)index] integerValue];
        if (![self isCardFaceUp:card]) return NO;
        if (index + 1 < (NSInteger)[pile count]) {
            NSInteger next = [[pile objectAtIndex:(NSUInteger)(index + 1)] integerValue];
            if ([self rankForCard:card] != [self rankForCard:next] + 1 ||
                [self isRedCard:card] == [self isRedCard:next]) return NO;
        }
    }
    return YES;
}

- (BOOL)moveTableau:(NSInteger)sourceIndex cardIndex:(NSInteger)cardIndex toTableau:(NSInteger)targetIndex {
    if (sourceIndex == targetIndex) return NO;
    NSMutableArray *source = [self tableauPileAtIndex:sourceIndex];
    NSMutableArray *target = [self tableauPileAtIndex:targetIndex];
    if (!source || !target || ![self sequenceIsValidInPile:source fromIndex:cardIndex]) return NO;
    NSInteger card = [[source objectAtIndex:(NSUInteger)cardIndex] integerValue];
    if (![self canPlaceCard:card onTableau:targetIndex]) return NO;
    [self pushUndoState];
    NSRange range = NSMakeRange((NSUInteger)cardIndex, [source count] - (NSUInteger)cardIndex);
    NSArray *moving = [source subarrayWithRange:range];
    [target addObjectsFromArray:moving];
    [source removeObjectsInRange:range];
    [self revealTableauTop:sourceIndex];
    return YES;
}

- (BOOL)moveTableauTopToFoundation:(NSInteger)tableauIndex {
    NSMutableArray *pile = [self tableauPileAtIndex:tableauIndex];
    if ([pile count] == 0) return NO;
    NSInteger card = [[pile lastObject] integerValue];
    if (![self isCardFaceUp:card] || ![self canPlaceCardOnFoundation:card]) return NO;
    [self pushUndoState];
    [[self foundationAtIndex:[self suitForCard:card]] addObject:[pile lastObject]];
    [pile removeLastObject];
    [self revealTableauTop:tableauIndex];
    [self evaluateWin];
    return YES;
}

- (BOOL)moveFoundation:(NSInteger)foundationIndex toTableau:(NSInteger)tableauIndex {
    NSMutableArray *foundation = [self foundationAtIndex:foundationIndex];
    if ([foundation count] == 0) return NO;
    NSInteger card = [[foundation lastObject] integerValue];
    if (![self canPlaceCard:card onTableau:tableauIndex]) return NO;
    [self pushUndoState];
    [[self tableauPileAtIndex:tableauIndex] addObject:[foundation lastObject]];
    [foundation removeLastObject];
    _won = NO;
    return YES;
}

- (BOOL)autoMoveCardFromSource:(TGSolitaireSource)source pile:(NSInteger)pile cardIndex:(NSInteger)cardIndex {
    if (source == TGSolitaireSourceWaste) return [self moveWasteToFoundation];
    if (source == TGSolitaireSourceTableau) {
        NSArray *cards = [self tableauCardsAtIndex:pile];
        if (cardIndex == (NSInteger)[cards count] - 1) return [self moveTableauTopToFoundation:pile];
    }
    return NO;
}

- (void)revealTableauTop:(NSInteger)tableauIndex {
    NSMutableArray *pile = [self tableauPileAtIndex:tableauIndex];
    if ([pile count] > 0) [_faceUpCards addObject:[pile lastObject]];
}

- (void)evaluateWin {
    NSUInteger count = 0;
    NSUInteger index;
    for (index = 0; index < [_foundations count]; index++) {
        count += [[_foundations objectAtIndex:index] count];
    }
    if (count == 52 && !_won) {
        _won = YES;
        _gamesWon++;
    }
}

- (BOOL)canUndo { return [_undoStates count] > 0; }

- (void)undo {
    if (![self canUndo]) return;
    NSDictionary *state = [[[_undoStates lastObject] retain] autorelease];
    [_undoStates removeLastObject];
    [self restoreStateDictionary:state includeStatistics:NO];
}

- (NSUInteger)stockCount { return [_stock count]; }
- (NSInteger)wasteCard { return [_waste count] ? [[_waste lastObject] integerValue] : -1; }
- (NSArray *)tableauCardsAtIndex:(NSInteger)index {
    NSArray *pile = [self tableauPileAtIndex:index];
    return pile ? pile : [NSArray array];
}
- (NSInteger)foundationTopCardForSuit:(NSInteger)suit {
    NSArray *foundation = [self foundationAtIndex:suit];
    return [foundation count] ? [[foundation lastObject] integerValue] : -1;
}
- (BOOL)isCardFaceUp:(NSInteger)card {
    return [_faceUpCards containsObject:[NSNumber numberWithInteger:card]];
}
- (BOOL)isWon { return _won; }
- (NSUInteger)gamesStarted { return _gamesStarted; }
- (NSUInteger)gamesWon { return _gamesWon; }

- (NSDictionary *)stateDictionary {
    NSMutableArray *tableauCopies = [NSMutableArray arrayWithCapacity:7];
    NSMutableArray *foundationCopies = [NSMutableArray arrayWithCapacity:4];
    NSUInteger index;
    for (index = 0; index < [_tableau count]; index++) {
        [tableauCopies addObject:[NSArray arrayWithArray:[_tableau objectAtIndex:index]]];
    }
    for (index = 0; index < [_foundations count]; index++) {
        [foundationCopies addObject:[NSArray arrayWithArray:[_foundations objectAtIndex:index]]];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSArray arrayWithArray:_stock], @"stock",
            [NSArray arrayWithArray:_waste], @"waste",
            tableauCopies, @"tableau",
            foundationCopies, @"foundations",
            [_faceUpCards allObjects], @"faceUp",
            [NSNumber numberWithBool:_won], @"won", nil];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:[self stateDictionary]];
    [dictionary setObject:@1 forKey:@"schema"];
    [dictionary setObject:[NSNumber numberWithUnsignedInteger:_gamesStarted] forKey:@"gamesStarted"];
    [dictionary setObject:[NSNumber numberWithUnsignedInteger:_gamesWon] forKey:@"gamesWon"];
    return dictionary;
}

- (BOOL)validateCardArray:(id)value {
    if (![value isKindOfClass:[NSArray class]]) return NO;
    NSUInteger index;
    for (index = 0; index < [value count]; index++) {
        id card = [value objectAtIndex:index];
        if (![card isKindOfClass:[NSNumber class]] ||
            [card integerValue] < 0 || [card integerValue] >= 52) return NO;
    }
    return YES;
}

- (BOOL)restoreStateDictionary:(NSDictionary *)dictionary includeStatistics:(BOOL)includeStatistics {
    NSArray *stock = [dictionary objectForKey:@"stock"];
    NSArray *waste = [dictionary objectForKey:@"waste"];
    NSArray *tableau = [dictionary objectForKey:@"tableau"];
    NSArray *foundations = [dictionary objectForKey:@"foundations"];
    NSArray *faceUp = [dictionary objectForKey:@"faceUp"];
    if (![self validateCardArray:stock] || ![self validateCardArray:waste] ||
        ![tableau isKindOfClass:[NSArray class]] || [tableau count] != 7 ||
        ![foundations isKindOfClass:[NSArray class]] || [foundations count] != 4 ||
        ![self validateCardArray:faceUp]) return NO;
    NSUInteger index;
    for (index = 0; index < [tableau count]; index++) {
        if (![self validateCardArray:[tableau objectAtIndex:index]]) return NO;
    }
    for (index = 0; index < [foundations count]; index++) {
        if (![self validateCardArray:[foundations objectAtIndex:index]]) return NO;
    }
    NSMutableArray *allCards = [NSMutableArray arrayWithArray:stock];
    [allCards addObjectsFromArray:waste];
    for (index = 0; index < [tableau count]; index++) {
        [allCards addObjectsFromArray:[tableau objectAtIndex:index]];
    }
    for (index = 0; index < [foundations count]; index++) {
        NSArray *foundation = [foundations objectAtIndex:index];
        [allCards addObjectsFromArray:foundation];
        NSUInteger foundationIndex;
        for (foundationIndex = 0; foundationIndex < [foundation count]; foundationIndex++) {
            NSInteger card = [[foundation objectAtIndex:foundationIndex] integerValue];
            if ([self suitForCard:card] != (NSInteger)index ||
                [self rankForCard:card] != (NSInteger)foundationIndex + 1) return NO;
        }
    }
    NSSet *uniqueCards = [NSSet setWithArray:allCards];
    NSSet *faceUpSet = [NSSet setWithArray:faceUp];
    if ([allCards count] != 52 || [uniqueCards count] != 52 ||
        ![faceUpSet isSubsetOfSet:uniqueCards]) return NO;

    [_stock setArray:stock];
    [_waste setArray:waste];
    [_tableau removeAllObjects];
    [_foundations removeAllObjects];
    for (index = 0; index < [tableau count]; index++) {
        [_tableau addObject:[NSMutableArray arrayWithArray:[tableau objectAtIndex:index]]];
    }
    for (index = 0; index < [foundations count]; index++) {
        [_foundations addObject:[NSMutableArray arrayWithArray:[foundations objectAtIndex:index]]];
    }
    [_faceUpCards setSet:[NSSet setWithArray:faceUp]];
    _won = [[dictionary objectForKey:@"won"] boolValue];
    if (includeStatistics) {
        _gamesStarted = [[dictionary objectForKey:@"gamesStarted"] unsignedIntegerValue];
        _gamesWon = [[dictionary objectForKey:@"gamesWon"] unsignedIntegerValue];
    }
    return YES;
}

- (BOOL)restoreFromDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:[NSDictionary class]]) return NO;
    NSInteger schema = [dictionary objectForKey:@"schema"] ?
                       [[dictionary objectForKey:@"schema"] integerValue] : 0;
    if (schema < 0 || schema > 1) return NO;
    if (![self restoreStateDictionary:dictionary includeStatistics:YES]) return NO;
    [_undoStates removeAllObjects];
    return YES;
}

- (void)dealloc {
    [_stock release];
    [_waste release];
    [_tableau release];
    [_foundations release];
    [_faceUpCards release];
    [_undoStates release];
    [super dealloc];
}

@end
