#import "TGSolitaireViewController.h"
#import "TGSolitaireBoardView.h"
#import "../Common/TGGameUI.h"

@class TGSolitaireViewController;

@interface TGSolitaireRootView : TGWorkshopGameSurfaceView {
    TGSolitaireViewController *_layoutOwner;
}
@property(nonatomic, assign) TGSolitaireViewController *layoutOwner;
@end

@interface TGSolitaireViewController ()
- (void)layoutGame;
@end

@implementation TGSolitaireRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutGame];
}
@end

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
    TGSolitaireRootView *root = [[[TGSolitaireRootView alloc] initWithFrame:NSMakeRect(0, 0, 760, 620)] autorelease];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [root setLayoutOwner:self];
    [self setView:root];

    _boardView = [[TGSolitaireBoardView alloc] initWithFrame:NSZeroRect
                                                      engine:_engine themeColors:[_hostContext themeColors]];
    [_boardView setTarget:self action:@selector(boardChanged:)];
    [root addSubview:_boardView];

    _rulesButton = [TGGameThemedButton(NSZeroRect,
                                      @"",
                                      @"info",
                                      _hostContext) retain];
    [_rulesButton setToolTip:[_hostContext localizedStringForKey:@"game.rules" fallback:@"Rules"]];
    [_rulesButton setTarget:self];
    [_rulesButton setAction:@selector(showRules:)];
    [root addSubview:_rulesButton];

    _statusField = [TGGameLabel(NSZeroRect, 12.0, YES, _hostContext) retain];
    [_statusField setAlignment:NSCenterTextAlignment];
    [root addSubview:_statusField];

    _statisticsField = [TGGameLabel(NSZeroRect, 11.0, NO, _hostContext) retain];
    [_statisticsField setAlignment:NSCenterTextAlignment];
    [root addSubview:_statisticsField];

    _undoButton = [TGGameThemedButton(NSZeroRect,
                                     [_hostContext localizedStringForKey:@"game.undo" fallback:@"Undo"],
                                     @"restore",
                                     _hostContext) retain];
    [_undoButton setTarget:self];
    [_undoButton setAction:@selector(undo:)];
    [root addSubview:_undoButton];

    _newDealButton = [TGGameThemedButton(NSZeroRect,
                                        [_hostContext localizedStringForKey:@"solitaire.new_deal" fallback:@"New deal"],
                                        @"refresh",
                                        _hostContext) retain];
    [_newDealButton setTarget:self];
    [_newDealButton setAction:@selector(newDeal:)];
    [root addSubview:_newDealButton];
    [self layoutGame];
    [self refreshFromEngine];
}

- (void)layoutGame {
    if (!_boardView) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    [_boardView setFrame:NSMakeRect(14.0, 58.0,
                                    MAX(420.0, width - 28.0),
                                    MAX(300.0, height - 72.0))];

    CGFloat controlsWidth = MIN(680.0, MAX(520.0, width - 28.0));
    CGFloat controlsX = floor((width - controlsWidth) / 2.0);
    [_rulesButton setFrame:NSMakeRect(controlsX, 14.0, 38.0, 32.0)];
    [_statusField setFrame:NSMakeRect(controlsX + 46.0, 19.0, 150.0, 20.0)];
    [_statisticsField setFrame:NSMakeRect(controlsX + 202.0, 19.0, 172.0, 20.0)];
    [_undoButton setFrame:NSMakeRect(NSMaxX(NSMakeRect(controlsX, 0.0, controlsWidth, 0.0)) - 274.0,
                                     14.0, 118.0, 32.0)];
    [_newDealButton setFrame:NSMakeRect(NSMaxX(NSMakeRect(controlsX, 0.0, controlsWidth, 0.0)) - 148.0,
                                        14.0, 148.0, 32.0)];
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
