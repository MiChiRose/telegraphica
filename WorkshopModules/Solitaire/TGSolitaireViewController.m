#import "TGSolitaireViewController.h"
#import "TGSolitaireBoardView.h"
#import "../Common/TGGameUI.h"

@implementation TGSolitaireViewController

- (id)initWithEngine:(TGSolitaireEngine *)engine hostContext:(id<TGWorkshopHostContext>)context {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [context retain];
    }
    return self;
}

- (void)loadView {
    TGWorkshopGameSurfaceView *root = [[[TGWorkshopGameSurfaceView alloc] initWithFrame:NSMakeRect(0, 0, 760, 620)] autorelease];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self setView:root];

    _boardView = [[TGSolitaireBoardView alloc] initWithFrame:NSMakeRect(18, 62, 724, 540)
                                                      engine:_engine themeColors:[_hostContext themeColors]];
    [_boardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_boardView setTarget:self action:@selector(boardChanged:)];
    [root addSubview:_boardView];

    _rulesButton = [TGGameThemedButton(NSMakeRect(16, 16, 38, 30),
                                      @"",
                                      @"info",
                                      _hostContext) retain];
    [_rulesButton setToolTip:[_hostContext localizedStringForKey:@"game.rules" fallback:@"Rules"]];
    [_rulesButton setTarget:self];
    [_rulesButton setAction:@selector(showRules:)];
    [_rulesButton setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [root addSubview:_rulesButton];

    _statusField = [TGGameLabel(NSMakeRect(64, 19, 176, 22), 12.0, YES, _hostContext) retain];
    [_statusField setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [root addSubview:_statusField];

    _statisticsField = [TGGameLabel(NSMakeRect(244, 19, 196, 22), 11.0, NO, _hostContext) retain];
    [_statisticsField setAlignment:NSCenterTextAlignment];
    [_statisticsField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
    [root addSubview:_statisticsField];

    _undoButton = [TGGameThemedButton(NSMakeRect(470, 14, 116, 32),
                                     [_hostContext localizedStringForKey:@"game.undo" fallback:@"Undo"],
                                     @"restore",
                                     _hostContext) retain];
    [_undoButton setTarget:self];
    [_undoButton setAction:@selector(undo:)];
    [_undoButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [root addSubview:_undoButton];

    _newDealButton = [TGGameThemedButton(NSMakeRect(594, 14, 150, 32),
                                        [_hostContext localizedStringForKey:@"solitaire.new_deal" fallback:@"New deal"],
                                        @"refresh",
                                        _hostContext) retain];
    [_newDealButton setTarget:self];
    [_newDealButton setAction:@selector(newDeal:)];
    [_newDealButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [root addSubview:_newDealButton];
    [self refreshFromEngine];
}

- (void)refreshFromEngine {
    if (!_statusField) return;
    [_statusField setStringValue:[_engine isWon]
                                 ? [_hostContext localizedStringForKey:@"game.won" fallback:@"You won"]
                                 : [_hostContext localizedStringForKey:@"solitaire.ready" fallback:@"Klondike"]];
    [_statisticsField setStringValue:[NSString stringWithFormat:@"%@ %lu / %lu",
                                      [_hostContext localizedStringForKey:@"game.wins" fallback:@"Wins"],
                                      (unsigned long)[_engine gamesWon],
                                      (unsigned long)[_engine gamesStarted]]];
    [_undoButton setEnabled:[_engine canUndo]];
    [_boardView setNeedsDisplay:YES];
}

- (void)showRules:(id)sender {
    (void)sender;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:[_hostContext localizedStringForKey:@"solitaire.rules_title"
                                                     fallback:@"How to play"]];
    [alert setInformativeText:[_hostContext localizedStringForKey:@"solitaire.rules"
                                                          fallback:@"Move cards by dragging them. Build tableau columns in descending order with alternating colors. Build each foundation from Ace to King. Double-click a face-up card to send it to a foundation."]];
    [alert addButtonWithTitle:[_hostContext localizedStringForKey:@"ok" fallback:@"OK"]];
    [alert runModal];
}

- (void)boardChanged:(id)sender {
    (void)sender;
    [self refreshFromEngine];
}

- (void)undo:(id)sender {
    (void)sender;
    [_engine undo];
    [self refreshFromEngine];
}

- (void)newDeal:(id)sender {
    (void)sender;
    [_engine startNewDeal];
    [self refreshFromEngine];
}

- (void)dealloc {
    [_engine release];
    [_hostContext release];
    [_boardView release];
    [_statusField release];
    [_statisticsField release];
    [_newDealButton release];
    [_undoButton release];
    [_rulesButton release];
    [super dealloc];
}

@end
