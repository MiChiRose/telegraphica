#import "TGQRCodeLoginWindowController.h"
#import "TGQRCodeImageGenerator.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"
#import "../Core/TGTDLibClient.h"

@interface TGQRCodeLoginBackgroundView : NSView
@end

@implementation TGQRCodeLoginBackgroundView
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    TGThemeDrawWindowBackgroundInRect([self bounds], [self isFlipped]);
}
@end

@interface TGQRCodeLoginWindowController () {
    TGTDLibClient *_client;
    NSImageView *_qrImageView;
    NSTextField *_statusField;
    NSProgressIndicator *_spinner;
    NSButton *_closeButton;
    BOOL _requestInFlight;
}
- (void)closeQRCodeWindow:(id)sender;
- (void)showQRCodeLink:(NSString *)link;
- (void)showError:(NSString *)message;
@end

@implementation TGQRCodeLoginWindowController

static NSTextField *TGQRCodeLoginLabel(NSString *text, NSRect frame, NSFont *font) {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [label setAlignment:NSCenterTextAlignment];
    [label setFont:font];
    [label setStringValue:text ? text : @""];
    return label;
}

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 480.0, 570.0)
                                                   styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO] autorelease];
    [window setTitle:TGLoc(@"login.qr.windowTitle")];
    [window setReleasedWhenClosed:NO];
    self = [super initWithWindow:window];
    if (self) {
        _client = [client retain];
        [window setDelegate:self];

        TGQRCodeLoginBackgroundView *contentView = [[[TGQRCodeLoginBackgroundView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 480.0, 570.0)] autorelease];
        [window setContentView:contentView];

        NSTextField *title = TGQRCodeLoginLabel(TGLoc(@"login.qr.title"),
                                               NSMakeRect(28.0, 524.0, 424.0, 28.0),
                                               [NSFont boldSystemFontOfSize:20.0]);
        [title setTextColor:TGClassicHeaderTextColor(1.0)];
        [contentView addSubview:title];

        NSTextField *hint = TGQRCodeLoginLabel(TGLoc(@"login.qr.hint"),
                                              NSMakeRect(42.0, 466.0, 396.0, 48.0),
                                              [NSFont systemFontOfSize:12.0]);
        [hint setTextColor:TGClassicHeaderDetailTextColor(1.0)];
        [[hint cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [contentView addSubview:hint];

        TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(48.0, 96.0, 384.0, 358.0)] autorelease];
        [contentView addSubview:card];

        _qrImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(90.0, 146.0, 300.0, 300.0)];
        [_qrImageView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [contentView addSubview:_qrImageView];

        _spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(227.0, 283.0, 26.0, 26.0)];
        [_spinner setStyle:NSProgressIndicatorSpinningStyle];
        [_spinner setDisplayedWhenStopped:NO];
        [contentView addSubview:_spinner];

        _statusField = [TGQRCodeLoginLabel(TGLoc(@"login.qr.loading"),
                                          NSMakeRect(70.0, 108.0, 340.0, 26.0),
                                          [NSFont systemFontOfSize:12.0]) retain];
        [_statusField setTextColor:TGClassicCardMutedInkColor()];
        [[_statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
        [contentView addSubview:_statusField];

        _closeButton = [[NSButton alloc] initWithFrame:NSMakeRect(178.0, 40.0, 124.0, 32.0)];
        [_closeButton setTitle:TGLoc(@"close")];
        [_closeButton setCell:[[[TGSecondaryTextButtonCell alloc] initTextCell:TGLoc(@"close")] autorelease]];
        [_closeButton setTarget:self];
        [_closeButton setAction:@selector(closeQRCodeWindow:)];
        [contentView addSubview:_closeButton];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_qrImageView release];
    [_statusField release];
    [_spinner release];
    [_closeButton release];
    [super dealloc];
}

- (void)beginQRCodeAuthentication {
    if (_requestInFlight) {
        return;
    }
    _requestInFlight = YES;
    [_spinner startAnimation:self];
    [_statusField setStringValue:TGLoc(@"login.qr.loading")];

    TGTDLibClient *client = [_client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *link = [[client requestQRCodeAuthenticationWithTimeout:8.0 error:&error] copy];
        NSString *message = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            _requestInFlight = NO;
            [_spinner stopAnimation:self];
            if ([link length] > 0) {
                [self showQRCodeLink:link];
            } else {
                [self showError:([message length] > 0 ? message : TGLoc(@"login.qr.failed"))];
            }
            [link release];
            [message release];
            [client release];
        });
        [pool drain];
    });
}

- (void)showQRCodeLink:(NSString *)link {
    NSImage *image = [TGQRCodeImageGenerator imageForString:link maximumSide:300.0];
    if (!image) {
        [self showError:TGLoc(@"login.qr.failed")];
        return;
    }
    [_qrImageView setImage:image];
    [_statusField setStringValue:TGLoc(@"login.qr.ready")];
}

- (void)showError:(NSString *)message {
    [_qrImageView setImage:nil];
    [_statusField setTextColor:[NSColor colorWithCalibratedRed:0.72 green:0.12 blue:0.10 alpha:1.0]];
    [_statusField setStringValue:message ? message : TGLoc(@"login.qr.failed")];
}

- (void)refreshQRCodeFromClient {
    NSString *link = [_client currentAuthenticationQRCodeLink];
    if ([link length] > 0) {
        [_statusField setTextColor:TGClassicCardMutedInkColor()];
        [self showQRCodeLink:link];
    }
}

- (void)authorizationStateDidChange:(NSString *)state {
    if ([state isEqualToString:@"waitOtherDeviceConfirmation"]) {
        [self refreshQRCodeFromClient];
        return;
    }
    if ([state isEqualToString:@"waitPassword"] || [state isEqualToString:@"ready"]) {
        [[self window] close];
    }
}

- (void)closeQRCodeWindow:(id)sender {
    (void)sender;
    [[self window] close];
}

- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;
    [_spinner stopAnimation:self];
}

@end
