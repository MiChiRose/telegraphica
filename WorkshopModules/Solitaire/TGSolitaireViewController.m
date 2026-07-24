#import "TGSolitaireViewController.h"
#import "TGSolitaireBoardView.h"

@implementation TGSolitaireViewController

- (id)initWithEngine:(TGSolitaireEngine *)engine hostContext:(id<TGWorkshopHostContext>)context {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _engine = [engine retain];
        _hostContext = [context retain];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame bold:(BOOL)bold {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setFont:[_hostContext interfaceFontOfSize:bold ? 14.0 : 11.0 bold:bold]];
    return field;
}

- (void)loadView {
    NSView *root = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 760, 620)] autorelease];
    [root setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [self setView:root];

    _boardView = [[TGSolitaireBoardView alloc] initWithFrame:NSMakeRect(16, 54, 728, 550)
                                                      engine:_engine themeColors:[_hostContext themeColors]];
    [_boardView setTarget:self action:@selector(boardChanged:)];
    [root addSubview:_boardView];

    _statusField = [[self labelWithFrame:NSMakeRect(18, 18, 260, 24) bold:YES] retain];
    [_statusField setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
    [root addSubview:_statusField];

    _statisticsField = [[self labelWithFrame:NSMakeRect(278, 18, 210, 22) bold:NO] retain];
    [_statisticsField setAlignment:NSCenterTextAlignment];
    [_statisticsField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin];
    [root addSubview:_statisticsField];

    _undoButton = [[NSButton alloc] initWithFrame:NSMakeRect(520, 14, 96, 30)];
    [_undoButton setTitle:[_hostContext localizedStringForKey:@"game.undo" fallback:@"Undo"]];
    [_undoButton setTarget:self];
    [_undoButton setAction:@selector(undo:)];
    [_undoButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [root addSubview:_undoButton];

    _newDealButton = [[NSButton alloc] initWithFrame:NSMakeRect(622, 14, 122, 30)];
    [_newDealButton setTitle:[_hostContext localizedStringForKey:@"solitaire.new_deal" fallback:@"New deal"]];
    [_newDealButton setTarget:self];
    [_newDealButton setAction:@selector(newDeal:)];
    [_newDealButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [root addSubview:_newDealButton];
    [self refreshFromEngine];
}

- (void)refreshFromEngine {
    if (![self isViewLoaded]) return;
    [_statusField setStringValue:[_engine isWon]
                                 ? [_hostContext localizedStringForKey:@"game.won" fallback:@"You won"]
                                 : [_hostContext localizedStringForKey:@"solitaire.hint" fallback:@"Drag cards or double-click to move home"]];
    [_statisticsField setStringValue:[NSString stringWithFormat:@"%@ %lu / %lu",
                                      [_hostContext localizedStringForKey:@"game.wins" fallback:@"Wins"],
                                      (unsigned long)[_engine gamesWon],
                                      (unsigned long)[_engine gamesStarted]]];
    [_undoButton setEnabled:[_engine canUndo]];
    [_boardView setNeedsDisplay:YES];
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
    [super dealloc];
}

@end
