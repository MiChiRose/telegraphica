#import "TGCallWindowController.h"

#import "../UI/TGIconAssets.h"
#import "../UI/TGLocalization.h"
#import "../UI/TGStatusButtonCells.h"
#import "../UI/TGStatusViewComponents.h"
#import "../UI/TGTheme.h"

@interface TGCallActionButtonCell : NSButtonCell
@property (nonatomic, retain) NSColor *actionColor;
@end

@implementation TGCallActionButtonCell

@synthesize actionColor = _actionColor;

- (id)copyWithZone:(NSZone *)zone {
    TGCallActionButtonCell *cell = [super copyWithZone:zone];
    /*
     * Legacy NSCell copies subclass ivars without retaining them.  Retain the
     * bit-copied color directly so both the prototype and rendered copy own it.
     */
    cell->_actionColor = [_actionColor retain];
    return cell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSRect circleRect = NSInsetRect(cellFrame, 2.0, 2.0);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];
    NSColor *base = self.actionColor ? self.actionColor : TGClassicNavigationSelectedColor(1.0);
    CGFloat alpha = [self isEnabled] ? ([self isHighlighted] ? 0.72 : 1.0) : 0.42;
    [[base colorWithAlphaComponent:alpha] set];
    [circle fill];
    NSImage *image = [self image];
    if (image) {
        CGFloat side = MIN(26.0, NSWidth(circleRect) - 16.0);
        NSRect iconRect = NSMakeRect(floor(NSMidX(circleRect) - side / 2.0),
                                     floor(NSMidY(circleRect) - side / 2.0),
                                     side,
                                     side);
        [image drawInRect:iconRect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0
           respectFlipped:[controlView isFlipped]
                    hints:nil];
    }
}

- (void)dealloc {
    [_actionColor release];
    [super dealloc];
}

@end

@interface TGCallWindowController ()
@property (nonatomic, retain) NSDictionary *profile;
@property (nonatomic, assign) BOOL outgoing;
@property (nonatomic, assign) BOOL microphoneMuted;
@property (nonatomic, assign) BOOL speakerMuted;
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, retain) NSDate *connectedAt;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, retain) NSSound *ringSound;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextField *timerField;
@property (nonatomic, retain) NSTextField *qualityField;
@property (nonatomic, retain) NSImageView *qualityImageView;
@property (nonatomic, retain) TGProfileAvatarView *avatarView;
@property (nonatomic, retain) NSTextField *nameField;
@property (nonatomic, retain) NSButton *answerButton;
@property (nonatomic, retain) NSButton *muteButton;
@property (nonatomic, retain) NSButton *speakerButton;
@property (nonatomic, retain) NSButton *hangupButton;
@property (nonatomic, retain) NSTextField *muteLabel;
@property (nonatomic, retain) NSTextField *speakerLabel;
@property (nonatomic, retain) NSTextField *answerLabel;
@property (nonatomic, retain) NSTextField *hangupLabel;
@end

@implementation TGCallWindowController

@synthesize delegate = _delegate;
@synthesize profile = _profile;
@synthesize outgoing = _outgoing;
@synthesize microphoneMuted = _microphoneMuted;
@synthesize speakerMuted = _speakerMuted;
@synthesize finished = _finished;
@synthesize connectedAt = _connectedAt;
@synthesize timer = _timer;
@synthesize ringSound = _ringSound;
@synthesize statusField = _statusField;
@synthesize timerField = _timerField;
@synthesize qualityField = _qualityField;
@synthesize qualityImageView = _qualityImageView;
@synthesize avatarView = _avatarView;
@synthesize nameField = _nameField;
@synthesize answerButton = _answerButton;
@synthesize muteButton = _muteButton;
@synthesize speakerButton = _speakerButton;
@synthesize hangupButton = _hangupButton;
@synthesize muteLabel = _muteLabel;
@synthesize speakerLabel = _speakerLabel;
@synthesize answerLabel = _answerLabel;
@synthesize hangupLabel = _hangupLabel;

- (NSTextField *)labelWithFrame:(NSRect)frame
                           text:(NSString *)text
                           font:(NSFont *)font
                          color:(NSColor *)color {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAlignment:NSCenterTextAlignment];
    [field setFont:font];
    [field setTextColor:color];
    [field setStringValue:text ? text : @""];
    return field;
}

- (NSButton *)actionButtonWithFrame:(NSRect)frame
                           iconName:(NSString *)iconName
                              color:(NSColor *)color
                             action:(SEL)action {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    TGCallActionButtonCell *cell = [[[TGCallActionButtonCell alloc] initTextCell:@""] autorelease];
    [cell setButtonType:NSMomentaryPushInButton];
    [cell setActionColor:color];
    [cell setImage:TGTemplateIconAssetImage(iconName, NSMakeSize(26.0, 26.0), [NSColor whiteColor], 1.0)];
    [button setCell:cell];
    [button setBordered:NO];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (id)initWithProfile:(NSDictionary *)profile outgoing:(BOOL)outgoing {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 420.0, 500.0)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.profile = profile;
        self.outgoing = outgoing;
        [[self window] setTitle:TGLoc(@"calls.window.title")];
        [[self window] setReleasedWhenClosed:NO];
        [[self window] setDelegate:self];
        [[self window] center];

        TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
        [[self window] setContentView:root];
        TGUtilityPanelView *card = [[[TGUtilityPanelView alloc] initWithFrame:NSMakeRect(18.0, 20.0, 384.0, 456.0)] autorelease];
        [root addSubview:card];

        self.avatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(140.0, 288.0, 140.0, 140.0)] autorelease];
        [root addSubview:self.avatarView];

        self.nameField = [self labelWithFrame:NSMakeRect(40.0, 238.0, 340.0, 34.0)
                                         text:@""
                                         font:[NSFont boldSystemFontOfSize:22.0]
                                        color:TGClassicCardInkColor()];
        [[self.nameField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [root addSubview:self.nameField];

        self.statusField = [self labelWithFrame:NSMakeRect(40.0, 211.0, 340.0, 22.0)
                                           text:@""
                                           font:[NSFont systemFontOfSize:13.0]
                                          color:TGClassicCardMutedInkColor()];
        [root addSubview:self.statusField];
        self.timerField = [self labelWithFrame:NSMakeRect(40.0, 184.0, 340.0, 22.0)
                                          text:@""
                                          font:[NSFont boldSystemFontOfSize:16.0]
                                         color:TGClassicCardInkColor()];
        [root addSubview:self.timerField];
        self.qualityField = [self labelWithFrame:NSMakeRect(88.0, 163.0, 214.0, 18.0)
                                            text:@""
                                            font:[NSFont systemFontOfSize:10.5]
                                           color:TGClassicCardMutedInkColor()];
        [self.qualityField setAlignment:NSRightTextAlignment];
        [self.qualityField setHidden:YES];
        [root addSubview:self.qualityField];
        self.qualityImageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(307.0, 163.0, 18.0, 18.0)] autorelease];
        [self.qualityImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [self.qualityImageView setHidden:YES];
        [root addSubview:self.qualityImageView];

        self.answerButton = [self actionButtonWithFrame:NSMakeRect(102.0, 78.0, 64.0, 64.0)
                                              iconName:@"call-receive"
                                                 color:[NSColor colorWithCalibratedRed:0.20 green:0.68 blue:0.34 alpha:1.0]
                                                action:@selector(answerPressed:)];
        [self.answerButton setToolTip:TGLoc(@"calls.answer")];
        [root addSubview:self.answerButton];
        self.answerLabel = [self labelWithFrame:NSMakeRect(70.0, 51.0, 128.0, 20.0)
                                           text:TGLoc(@"calls.answer")
                                           font:[NSFont systemFontOfSize:11.0]
                                          color:TGClassicCardMutedInkColor()];
        [root addSubview:self.answerLabel];

        self.muteButton = [self actionButtonWithFrame:NSMakeRect(64.0, 78.0, 64.0, 64.0)
                                            iconName:@"microphone"
                                               color:TGClassicNavigationSelectedColor(1.0)
                                              action:@selector(mutePressed:)];
        [self.muteButton setToolTip:TGLoc(@"calls.mute")];
        [root addSubview:self.muteButton];

        self.speakerButton = [self actionButtonWithFrame:NSMakeRect(178.0, 78.0, 64.0, 64.0)
                                               iconName:@"headphones"
                                                  color:TGClassicNavigationSelectedColor(1.0)
                                                 action:@selector(speakerPressed:)];
        [self.speakerButton setToolTip:TGLoc(@"calls.speakerMute")];
        [root addSubview:self.speakerButton];

        self.hangupButton = [self actionButtonWithFrame:NSMakeRect(292.0, 78.0, 64.0, 64.0)
                                              iconName:@"call-cancel"
                                                 color:[NSColor colorWithCalibratedRed:0.86 green:0.18 blue:0.17 alpha:1.0]
                                                action:@selector(hangupPressed:)];
        [self.hangupButton setToolTip:TGLoc(@"calls.hangup")];
        [root addSubview:self.hangupButton];

        self.muteLabel = [self labelWithFrame:NSMakeRect(32.0, 51.0, 128.0, 20.0)
                                         text:TGLoc(@"calls.mute")
                                         font:[NSFont systemFontOfSize:11.0]
                                        color:TGClassicCardMutedInkColor()];
        [root addSubview:self.muteLabel];
        self.speakerLabel = [self labelWithFrame:NSMakeRect(146.0, 51.0, 128.0, 20.0)
                                            text:TGLoc(@"calls.speakerMute")
                                            font:[NSFont systemFontOfSize:11.0]
                                           color:TGClassicCardMutedInkColor()];
        [root addSubview:self.speakerLabel];
        self.hangupLabel = [self labelWithFrame:NSMakeRect(260.0, 51.0, 128.0, 20.0)
                                           text:TGLoc(@"calls.hangup")
                                           font:[NSFont systemFontOfSize:11.0]
                                          color:TGClassicCardMutedInkColor()];
        [root addSubview:self.hangupLabel];

        [self updateProfile:profile];
        [self setPresentationState:(outgoing ? TGCallPresentationStateCalling : TGCallPresentationStateIncoming)
                            detail:nil];
    }
    return self;
}

- (void)updateProfile:(NSDictionary *)profile {
    if (![profile isKindOfClass:[NSDictionary class]]) {
        return;
    }
    self.profile = profile;
    NSString *displayName = [profile objectForKey:@"display_name"];
    [self.avatarView setDisplayName:displayName];
    [self.avatarView setAvatarLocalPath:[profile objectForKey:@"avatar_local_path"]];
    [self.avatarView setNeedsDisplay:YES];
    [self.nameField setStringValue:([displayName length] > 0 ? displayName : TGLoc(@"calls.unknown"))];
}

- (void)startRinging {
    if (self.ringSound) {
        return;
    }
    NSSound *sound = [NSSound soundNamed:@"Marimba"];
    if (!sound) {
        NSMutableArray *paths = [NSMutableArray array];
        NSString *bundledPath = [[NSBundle mainBundle] pathForResource:@"Marimba"
                                                                ofType:@"m4r"
                                                           inDirectory:@"Sounds"];
        if ([bundledPath length] > 0) {
            [paths addObject:bundledPath];
        }
        [paths addObjectsFromArray:[NSArray arrayWithObjects:
                                    [@"~/Library/Application Support/Telegraphica/Sounds/Marimba.m4r" stringByExpandingTildeInPath],
                                    [@"~/Library/Sounds/Marimba.m4r" stringByExpandingTildeInPath],
                                    [@"~/Library/Sounds/Marimba.aiff" stringByExpandingTildeInPath],
                                    @"/Library/Sounds/Marimba.m4r",
                                    @"/Library/Sounds/Marimba.aiff",
                                    @"/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/Ringtones/Marimba.m4r",
                                    @"/System/Library/Sounds/Marimba.aiff",
                                    nil]];
        for (NSString *path in paths) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                sound = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
                if (sound) {
                    break;
                }
            }
        }
    }
    self.ringSound = sound;
    [self.ringSound setLoops:YES];
    [self.ringSound play];
}

- (void)stopRinging {
    [self.ringSound stop];
    self.ringSound = nil;
}

- (void)updateTimer:(NSTimer *)timer {
    (void)timer;
    NSUInteger elapsed = (NSUInteger)floor([self connectedDuration]);
    [self.timerField setStringValue:[NSString stringWithFormat:@"%02lu:%02lu",
                                     (unsigned long)(elapsed / 60U),
                                     (unsigned long)(elapsed % 60U)]];
}

- (void)updateSignalBars:(NSUInteger)signalBars {
    NSUInteger safeBars = MIN(5U, signalBars);
    [self.qualityField setStringValue:[NSString stringWithFormat:TGLoc(@"calls.quality"),
                                       (unsigned long)safeBars]];
    NSArray *iconNames = [NSArray arrayWithObjects:
                          @"signal-weak",
                          @"signal-fair",
                          @"signal-good",
                          @"signal-strong",
                          @"signal",
                          nil];
    if (safeBars == 0U) {
        [self.qualityImageView setImage:nil];
    } else {
        NSString *iconName = [iconNames objectAtIndex:(safeBars - 1U)];
        [self.qualityImageView setImage:TGTemplateIconAssetImage(iconName,
                                                                 NSMakeSize(18.0, 18.0),
                                                                 TGClassicCardMutedInkColor(),
                                                                 1.0)];
    }
}

- (void)setPresentationState:(TGCallPresentationState)state detail:(NSString *)detail {
    BOOL incoming = (state == TGCallPresentationStateIncoming);
    BOOL connected = (state == TGCallPresentationStateConnected ||
                      state == TGCallPresentationStateReconnecting);
    BOOL ended = (state == TGCallPresentationStateEnded ||
                  state == TGCallPresentationStateFailed);
    [self.answerButton setHidden:!incoming];
    [self.answerLabel setHidden:!incoming];
    [self.muteButton setHidden:!connected];
    [self.muteLabel setHidden:!connected];
    [self.speakerButton setHidden:!connected];
    [self.speakerLabel setHidden:!connected];
    [self.hangupButton setHidden:ended];
    [self.hangupLabel setHidden:ended];
    [self.qualityField setHidden:!connected];
    [self.qualityImageView setHidden:!connected];
    if (incoming) {
        [self.answerButton setFrameOrigin:NSMakePoint(102.0, 78.0)];
        [self.answerLabel setFrameOrigin:NSMakePoint(70.0, 51.0)];
        [self.hangupButton setFrameOrigin:NSMakePoint(254.0, 78.0)];
        [self.hangupLabel setFrameOrigin:NSMakePoint(222.0, 51.0)];
    } else if (connected) {
        [self.hangupButton setFrameOrigin:NSMakePoint(292.0, 78.0)];
        [self.hangupLabel setFrameOrigin:NSMakePoint(260.0, 51.0)];
    } else {
        [self.hangupButton setFrameOrigin:NSMakePoint(178.0, 78.0)];
        [self.hangupLabel setFrameOrigin:NSMakePoint(146.0, 51.0)];
    }

    NSString *status = detail;
    if ([status length] == 0) {
        if (state == TGCallPresentationStateCalling) {
            status = TGLoc(@"calls.calling");
        } else if (state == TGCallPresentationStateIncoming) {
            status = TGLoc(@"calls.incoming");
        } else if (state == TGCallPresentationStateConnecting) {
            status = TGLoc(@"calls.connecting");
        } else if (state == TGCallPresentationStateConnected) {
            status = TGLoc(@"calls.connected");
        } else if (state == TGCallPresentationStateReconnecting) {
            status = TGLoc(@"calls.reconnecting");
        } else if (state == TGCallPresentationStateFailed) {
            status = TGLoc(@"calls.failed");
        } else {
            status = TGLoc(@"calls.ended");
        }
    }
    [self.statusField setStringValue:status];

    if (state == TGCallPresentationStateIncoming) {
        [self startRinging];
    } else {
        [self stopRinging];
    }
    if (state == TGCallPresentationStateConnected && !self.connectedAt) {
        self.connectedAt = [NSDate date];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                     target:self
                                                   selector:@selector(updateTimer:)
                                                   userInfo:nil
                                                    repeats:YES];
        [self updateTimer:nil];
    }
    if (ended) {
        self.finished = YES;
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (NSTimeInterval)connectedDuration {
    return self.connectedAt ? MAX(0.0, -[self.connectedAt timeIntervalSinceNow]) : 0.0;
}

- (void)answerPressed:(id)sender {
    (void)sender;
    [self.delegate callWindowControllerDidRequestAnswer:self];
}

- (void)mutePressed:(id)sender {
    (void)sender;
    self.microphoneMuted = !self.microphoneMuted;
    NSString *iconName = self.microphoneMuted ? @"microphone-off" : @"microphone";
    [[self.muteButton cell] setImage:TGTemplateIconAssetImage(iconName, NSMakeSize(26.0, 26.0), [NSColor whiteColor], 1.0)];
    [self.muteLabel setStringValue:(self.microphoneMuted ? TGLoc(@"calls.unmute") : TGLoc(@"calls.mute"))];
    [self.muteButton setToolTip:(self.microphoneMuted ? TGLoc(@"calls.unmute") : TGLoc(@"calls.mute"))];
    [self.delegate callWindowController:self didRequestMicrophoneMuted:self.microphoneMuted];
}

- (void)speakerPressed:(id)sender {
    (void)sender;
    self.speakerMuted = !self.speakerMuted;
    NSString *iconName = self.speakerMuted ? @"headphones-off" : @"headphones";
    [[self.speakerButton cell] setImage:TGTemplateIconAssetImage(iconName, NSMakeSize(26.0, 26.0), [NSColor whiteColor], 1.0)];
    NSString *label = self.speakerMuted ? TGLoc(@"calls.speakerUnmute") : TGLoc(@"calls.speakerMute");
    [self.speakerLabel setStringValue:label];
    [self.speakerButton setToolTip:label];
    [self.delegate callWindowController:self didRequestSpeakerMuted:self.speakerMuted];
}

- (void)hangupPressed:(id)sender {
    (void)sender;
    [self.delegate callWindowControllerDidRequestHangUp:self];
}

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    if (!self.finished) {
        [self.delegate callWindowControllerDidRequestHangUp:self];
        return NO;
    }
    return YES;
}

- (void)closeAfterDelay:(NSTimeInterval)delay {
    [self performSelector:@selector(close) withObject:nil afterDelay:MAX(0.0, delay)];
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_timer invalidate];
    [_ringSound stop];
    [_profile release];
    [_connectedAt release];
    [_timer release];
    [_ringSound release];
    [_statusField release];
    [_timerField release];
    [_qualityField release];
    [_qualityImageView release];
    [_avatarView release];
    [_nameField release];
    [_answerButton release];
    [_muteButton release];
    [_speakerButton release];
    [_hangupButton release];
    [_muteLabel release];
    [_speakerLabel release];
    [_answerLabel release];
    [_hangupLabel release];
    [super dealloc];
}

@end
