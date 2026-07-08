#import "TGStatusWindowController.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSTextField *authLabel;
@property (nonatomic, retain) NSTextField *authStateField;
@property (nonatomic, retain) NSTextField *authTextField;
@property (nonatomic, retain) NSSecureTextField *authSecureField;
@property (nonatomic, retain) NSButton *authButton;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState;
@end

@implementation TGStatusWindowController

@synthesize statusField = _statusField;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize authLabel = _authLabel;
@synthesize authStateField = _authStateField;
@synthesize authTextField = _authTextField;
@synthesize authSecureField = _authSecureField;
@synthesize authButton = _authButton;
@synthesize chatTableView = _chatTableView;
@synthesize chatItems = _chatItems;
@synthesize client = _client;
@synthesize currentAuthState = _currentAuthState;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 760, 560);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        self.chatItems = [NSMutableArray array];
        [self buildContentView];
    }
    return self;
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setStringValue:(text ? text : @"")];
    [field setFont:font];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    return field;
}

- (void)buildContentView {
    NSView *contentView = [[self window] contentView];
    [contentView setAutoresizesSubviews:YES];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 508, 712, 28)
                                         text:@"Telegraphica core spike"
                                         font:[NSFont boldSystemFontOfSize:18.0]];
    [contentView addSubview:title];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 476, 712, 22)
                                       text:@"TDLib status: not checked"
                                       font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.statusField];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 252, 712, 208)] autorelease];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setString:@"Ready. Place libtdjson.dylib in Contents/Frameworks or set TELEGRAPHICA_TDJSON_PATH, then check the core.\n"];
    [scrollView setDocumentView:self.detailsView];
    [contentView addSubview:scrollView];

    self.authLabel = [self labelWithFrame:NSMakeRect(24, 212, 76, 22)
                                     text:@"Auth:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.authLabel];

    self.authStateField = [self labelWithFrame:NSMakeRect(104, 212, 560, 22)
                                          text:@"not checked"
                                          font:[NSFont systemFontOfSize:13.0]];
    [[self.authStateField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.authStateField];

    self.authTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(104, 208, 240, 24)] autorelease];
    [self.authTextField setEnabled:NO];
    [self.authTextField setHidden:YES];
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 208, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 204, 116, 32)] autorelease];
    [self.authButton setTitle:@"Send"];
    [self.authButton setBezelStyle:NSRoundedBezelStyle];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    NSTextField *chatsLabel = [self labelWithFrame:NSMakeRect(24, 178, 76, 22)
                                              text:@"Chats:"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 172, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"Load Chats"];
    [self.loadChatsButton setBezelStyle:NSRoundedBezelStyle];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    NSScrollView *chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 96)] autorelease];
    [chatScrollView setBorderType:NSBezelBorder];
    [chatScrollView setHasVerticalScroller:YES];
    [chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"title"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Chat"];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    NSTableColumn *typeColumn = [[[NSTableColumn alloc] initWithIdentifier:@"type"] autorelease];
    [[typeColumn headerCell] setStringValue:@"Type"];
    [typeColumn setWidth:130.0];
    [self.chatTableView addTableColumn:typeColumn];

    NSTableColumn *unreadColumn = [[[NSTableColumn alloc] initWithIdentifier:@"unread_count"] autorelease];
    [[unreadColumn headerCell] setStringValue:@"Unread"];
    [unreadColumn setWidth:80.0];
    [self.chatTableView addTableColumn:unreadColumn];

    [chatScrollView setDocumentView:self.chatTableView];
    [contentView addSubview:chatScrollView];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Check TDLib"];
    [self.checkButton setBezelStyle:NSRoundedBezelStyle];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    NSButton *quitButton = [[[NSButton alloc] initWithFrame:NSMakeRect(176, 28, 96, 32)] autorelease];
    [quitButton setTitle:@"Quit"];
    [quitButton setBezelStyle:NSRoundedBezelStyle];
    [quitButton setTarget:NSApp];
    [quitButton setAction:@selector(terminate:)];
    [quitButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:quitButton];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (void)updateAuthControlsForState:(NSString *)state {
    self.currentAuthState = state;
    [self.authTextField setStringValue:@""];
    [self.authSecureField setStringValue:@""];
    [self.loadChatsButton setEnabled:NO];

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.authLabel setStringValue:@"Phone:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:YES];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:@"Send Phone"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.authLabel setStringValue:@"Code:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Verify"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.authLabel setStringValue:@"Password:"];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:YES];
        [self.authButton setTitle:@"Unlock"];
        [self.authButton setEnabled:YES];
        [self.authButton setHidden:NO];
        return;
    }

    [self.authLabel setStringValue:@"Auth:"];
    if ([state isEqualToString:@"ready"]) {
        [self.authStateField setStringValue:@"ready"];
    } else if ([state length] > 0) {
        [self.authStateField setStringValue:state];
    } else {
        [self.authStateField setStringValue:@"not checked"];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [self.authButton setTitle:@"Send"];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
}

- (void)setControlsBusy:(BOOL)busy {
    [self.checkButton setEnabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
    } else {
        [self updateAuthControlsForState:self.currentAuthState];
    }
}

- (void)appendDetail:(NSString *)detail {
    NSString *current = [self.detailsView string];
    NSString *line = [detail stringByAppendingString:@"\n"];
    [self.detailsView setString:[current stringByAppendingString:line]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.chatItems count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableView;
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        return @"";
    }

    NSDictionary *item = [self.chatItems objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = [item objectForKey:identifier];
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)] && [value integerValue] == 0) {
        return @"";
    }
    return value ? value : @"";
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib status: checking..."];
    [self appendDetail:@"Checking TDLib JSON interface..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *parametersError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:&parametersError];
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (probeSummary) {
                [self.statusField setStringValue:@"TDLib status: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", [parametersError localizedDescription]]];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self.statusField setStringValue:@"TDLib status: unavailable"];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Auth input is not available for the current TDLib state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPhoneNumber"] ? self.authTextField : self.authSecureField;
    NSString *input = [[inputField stringValue] copy];
    [inputField setStringValue:@""];
    if ([input length] == 0) {
        [input release];
        [state release];
        [self appendDetail:@"Auth input is empty."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib auth: submitting..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (authSummary) {
                [self.statusField setStringValue:@"TDLib auth: submitted"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"TDLib auth: needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
            } else {
                [self updateAuthControlsForState:state];
            }
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Chats are available only after TDLib auth state is ready."];
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"TDLib chats: loading..."];
    [self appendDetail:@"Loading main chat previews from TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        NSArray *items = [client mainChatPreviewItemsWithLimit:10 timeout:5.0 error:&chatError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (itemsCopy) {
                [self.chatItems removeAllObjects];
                [self.chatItems addObjectsFromArray:itemsCopy];
                [self.chatTableView reloadData];
                [self.statusField setStringValue:@"TDLib chats: loaded"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu chat previews", (unsigned long)[itemsCopy count]]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
            } else {
                NSString *message = chatErrorMessage ? @"Chat preview request failed. Check TDLib state and try again." : @"Chat list did not return a result.";
                [self.statusField setStringValue:@"TDLib chats: unavailable"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
        });

        [client release];
        [pool drain];
    });
}

- (void)dealloc {
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_statusField release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_authLabel release];
    [_authStateField release];
    [_authTextField release];
    [_authSecureField release];
    [_authButton release];
    [_chatTableView release];
    [_chatItems release];
    [_client release];
    [_currentAuthState release];
    [super dealloc];
}

@end
