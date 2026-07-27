#import "TGRetroConsoleViewController.h"
#import "../Common/TGGameUI.h"

@interface TGRetroConsoleRootView : TGWorkshopGameSurfaceView {
    TGRetroConsoleViewController *_layoutOwner;
}
@property(nonatomic, assign) TGRetroConsoleViewController *layoutOwner;
@end

@interface TGRetroConsoleViewController ()
- (void)layoutConsole;
- (void)insertCartridge:(id)sender;
- (void)togglePause:(id)sender;
- (void)resetConsole:(id)sender;
- (void)frameTimerFired:(NSTimer *)timer;
- (void)openROMAtPath:(NSString *)path;
- (NSString *)corePathForROMPath:(NSString *)path systemName:(NSString **)systemName;
@end

@implementation TGRetroConsoleRootView
@synthesize layoutOwner = _layoutOwner;
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    [_layoutOwner layoutConsole];
}
@end

@implementation TGRetroConsoleViewController

- (id)initWithHostContext:(id<TGWorkshopHostContext>)context {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _hostContext = [context retain];
        _core = [[TGRetroLibretroCore alloc] init];
        [_core setDelegate:self];
    }
    return self;
}

- (void)loadView {
    TGRetroConsoleRootView *root = [[[TGRetroConsoleRootView alloc] initWithFrame:NSMakeRect(0, 0, 700, 520)] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root setLayoutOwner:self];
    [self setView:root];

    _titleField = [TGGameLabel(NSZeroRect, 18.0, YES, _hostContext) retain];
    [_titleField setAlignment:NSCenterTextAlignment];
    [_titleField setStringValue:[_hostContext localizedStringForKey:@"retro.title"
                                                           fallback:@"Ретро-консоль"]];
    [root addSubview:_titleField];

    _statusField = [TGGameLabel(NSZeroRect, 12.0, NO, _hostContext) retain];
    [_statusField setAlignment:NSCenterTextAlignment];
    [_statusField setStringValue:[_hostContext localizedStringForKey:@"retro.insertHint"
                                                            fallback:@"Вставьте картридж или перетащите ROM на экран"]];
    [root addSubview:_statusField];

    _displayView = [[TGRetroDisplayView alloc] initWithFrame:NSZeroRect];
    [_displayView setDelegate:self];
    [root addSubview:_displayView];

    _controlsField = [TGGameLabel(NSZeroRect, 10.0, NO, _hostContext) retain];
    [_controlsField setAlignment:NSCenterTextAlignment];
    [_controlsField setStringValue:[_hostContext localizedStringForKey:@"retro.controls"
                                                              fallback:@"Стрелки: движение   Z/X: B/A   A/S: Y/X   Enter: Start   Shift: Select"]];
    [root addSubview:_controlsField];

    _insertButton = [TGGameThemedButton(NSZeroRect,
                                        [_hostContext localizedStringForKey:@"retro.insert"
                                                                   fallback:@"Вставить картридж"],
                                        nil,
                                        _hostContext) retain];
    [_insertButton setTarget:self];
    [_insertButton setAction:@selector(insertCartridge:)];
    [root addSubview:_insertButton];

    _pauseButton = [TGGameThemedButton(NSZeroRect,
                                       [_hostContext localizedStringForKey:@"game.pause" fallback:@"Пауза"],
                                       @"pause",
                                       _hostContext) retain];
    [_pauseButton setTarget:self];
    [_pauseButton setAction:@selector(togglePause:)];
    [_pauseButton setEnabled:NO];
    [root addSubview:_pauseButton];

    _resetButton = [TGGameThemedButton(NSZeroRect,
                                       [_hostContext localizedStringForKey:@"retro.reset" fallback:@"Сброс"],
                                       @"refresh",
                                       _hostContext) retain];
    [_resetButton setTarget:self];
    [_resetButton setAction:@selector(resetConsole:)];
    [_resetButton setEnabled:NO];
    [root addSubview:_resetButton];

    [self layoutConsole];
}

- (void)layoutConsole {
    if (!_displayView) return;
    NSRect bounds = [[self view] bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat contentWidth = MIN(780.0, MAX(340.0, width - 28.0));
    CGFloat contentX = floor((width - contentWidth) / 2.0);
    [_titleField setFrame:NSMakeRect(contentX, height - 38.0, contentWidth, 24.0)];
    [_statusField setFrame:NSMakeRect(contentX, height - 60.0, contentWidth, 18.0)];
    [_controlsField setFrame:NSMakeRect(contentX, 52.0, contentWidth, 17.0)];
    [_displayView setFrame:NSMakeRect(contentX, 76.0, contentWidth, MAX(190.0, height - 148.0))];

    CGFloat gap = 10.0;
    CGFloat insertWidth = MIN(220.0, MAX(150.0, contentWidth * 0.42));
    CGFloat smallWidth = floor((contentWidth - insertWidth - gap * 2.0) / 2.0);
    [_insertButton setFrame:NSMakeRect(contentX, 14.0, insertWidth, 32.0)];
    [_pauseButton setFrame:NSMakeRect(NSMaxX([_insertButton frame]) + gap, 14.0, smallWidth, 32.0)];
    [_resetButton setFrame:NSMakeRect(NSMaxX([_pauseButton frame]) + gap, 14.0, smallWidth, 32.0)];
}

- (void)insertCartridge:(id)sender {
    (void)sender;
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:[NSArray arrayWithObjects:@"nes", @"md", @"smd", @"gen", @"bin", @"sms", @"gg", @"sg", nil]];
    [panel setTitle:[_hostContext localizedStringForKey:@"retro.insert" fallback:@"Вставить картридж"]];
    if ([panel runModal] == NSOKButton && [[panel URLs] count] > 0) {
        [self openROMAtPath:[[[panel URLs] objectAtIndex:0] path]];
    }
}

- (NSString *)corePathForROMPath:(NSString *)path systemName:(NSString **)systemName {
    NSString *extension = [[path pathExtension] lowercaseString];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    if ([extension isEqualToString:@"nes"]) {
        if (systemName) *systemName = @"NES / Dendy";
        return [bundle pathForResource:@"quicknes_libretro" ofType:@"dylib" inDirectory:@"Cores"];
    }
    if (systemName) {
        *systemName = ([extension isEqualToString:@"sms"] ||
                       [extension isEqualToString:@"gg"] ||
                       [extension isEqualToString:@"sg"])
            ? @"Sega 8-bit"
            : @"Sega Mega Drive / Genesis";
    }
    return [bundle pathForResource:@"genesis_plus_gx_libretro" ofType:@"dylib" inDirectory:@"Cores"];
}

- (void)openROMAtPath:(NSString *)path {
    NSString *systemName = nil;
    NSString *corePath = [self corePathForROMPath:path systemName:&systemName];
    NSError *error = nil;
    if (![_core loadROMAtPath:path
                     corePath:corePath
             supportDirectory:[[_hostContext moduleDataDirectoryURL] path]
                        error:&error]) {
        [_statusField setStringValue:[error localizedDescription]];
        NSBeep();
        return;
    }
    [_currentROMPath release];
    _currentROMPath = [path copy];
    _paused = NO;
    [_pauseButton setEnabled:YES];
    [_resetButton setEnabled:YES];
    [_pauseButton setTitle:[_hostContext localizedStringForKey:@"game.pause" fallback:@"Пауза"]];
    [_statusField setStringValue:[NSString stringWithFormat:@"%@: %@",
                                  systemName ? systemName : @"ROM",
                                  [path lastPathComponent]]];
    [self startRunning];
    [[_displayView window] makeFirstResponder:_displayView];
}

- (void)togglePause:(id)sender {
    (void)sender;
    if (![_core gameLoaded]) return;
    _paused = !_paused;
    [_pauseButton setTitle:(_paused
                            ? [_hostContext localizedStringForKey:@"game.resume" fallback:@"Продолжить"]
                            : [_hostContext localizedStringForKey:@"game.pause" fallback:@"Пауза"])];
    if (!_paused) [[_displayView window] makeFirstResponder:_displayView];
}

- (void)resetConsole:(id)sender {
    (void)sender;
    [_core reset];
    _paused = NO;
    [_pauseButton setTitle:[_hostContext localizedStringForKey:@"game.pause" fallback:@"Пауза"]];
    [[_displayView window] makeFirstResponder:_displayView];
}

- (void)startRunning {
    if (_frameTimer) return;
    double FPS = [_core framesPerSecond];
    if (FPS < 20.0 || FPS > 240.0) FPS = 60.0;
    _frameTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0 / FPS)
                                                   target:self
                                                 selector:@selector(frameTimerFired:)
                                                 userInfo:nil
                                                  repeats:YES] retain];
}

- (void)stopRunning {
    [_frameTimer invalidate];
    [_frameTimer release];
    _frameTimer = nil;
}

- (void)frameTimerFired:(NSTimer *)timer {
    (void)timer;
    if (!_paused) [_core runFrame];
}

- (void)retroCore:(TGRetroLibretroCore *)core
 didProduceFrame:(NSData *)frameData
            width:(NSUInteger)width
           height:(NSUInteger)height {
    if (core == _core) {
        [_displayView updateFrameData:frameData width:width height:height];
    }
}

- (void)retroCore:(TGRetroLibretroCore *)core didReportMessage:(NSString *)message {
    if (core == _core && [message length] > 0) {
        [_statusField setStringValue:message];
    }
}

- (void)retroDisplayView:(TGRetroDisplayView *)view didReceiveROMPath:(NSString *)path {
    if (view == _displayView) [self openROMAtPath:path];
}

- (void)retroDisplayView:(TGRetroDisplayView *)view setButton:(NSUInteger)button pressed:(BOOL)pressed {
    if (view == _displayView) [_core setJoypadButton:button pressed:pressed];
}

- (NSData *)serializedState {
    return [_core serializedState];
}

- (BOOL)restoreSerializedState:(NSData *)state {
    return [_core restoreSerializedState:state];
}

- (void)dealloc {
    [self stopRunning];
    [_core unload];
    [_hostContext release];
    [_core release];
    [_displayView release];
    [_titleField release];
    [_statusField release];
    [_controlsField release];
    [_insertButton release];
    [_pauseButton release];
    [_resetButton release];
    [_currentROMPath release];
    [super dealloc];
}

@end

