#import "TGBotKeyboardWindowController.h"

#import "../Core/TGTDLibClient+Bots.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGBotKeyboardWindowController () <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *chatID;
@property (nonatomic, retain) NSNumber *messageID;
@property (nonatomic, copy) NSDictionary *replyMarkup;
@property (nonatomic, copy) NSArray *buttons;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSButton *activateButton;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, assign) BOOL loading;
@end

@implementation TGBotKeyboardWindowController

@synthesize client = _client;
@synthesize chatID = _chatID;
@synthesize messageID = _messageID;
@synthesize replyMarkup = _replyMarkup;
@synthesize buttons = _buttons;
@synthesize tableView = _tableView;
@synthesize activateButton = _activateButton;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize loading = _loading;

- (id)initWithClient:(TGTDLibClient *)client
              chatID:(NSNumber *)chatID
           messageID:(NSNumber *)messageID
         replyMarkup:(NSDictionary *)replyMarkup {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 520, 430)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.chatID = chatID;
        self.messageID = messageID;
        self.replyMarkup = replyMarkup;
        self.buttons = [self flattenedButtonsFromMarkup:replyMarkup];
        [[self window] setTitle:TGLoc(@"bot.keyboard.title")];
        [[self window] setMinSize:NSMakeSize(460.0, 340.0)];
        [[self window] setMaxSize:NSMakeSize(760.0, 620.0)];
        [[self window] setReleasedWhenClosed:NO];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_chatID release];
    [_messageID release];
    [_replyMarkup release];
    [_buttons release];
    [_tableView release];
    [_activateButton release];
    [_statusField release];
    [_spinner release];
    [super dealloc];
}

- (NSArray *)flattenedButtonsFromMarkup:(NSDictionary *)markup {
    NSArray *rows = [[markup objectForKey:@"rows"] isKindOfClass:[NSArray class]]
        ? [markup objectForKey:@"rows"] : [NSArray array];
    NSMutableArray *buttons = [NSMutableArray array];
    NSUInteger rowIndex = 0;
    for (rowIndex = 0; rowIndex < [rows count]; rowIndex++) {
        NSArray *row = [[rows objectAtIndex:rowIndex] isKindOfClass:[NSArray class]]
            ? [rows objectAtIndex:rowIndex] : [NSArray array];
        NSUInteger columnIndex = 0;
        for (columnIndex = 0; columnIndex < [row count]; columnIndex++) {
            NSDictionary *button = [[row objectAtIndex:columnIndex] isKindOfClass:[NSDictionary class]]
                ? [row objectAtIndex:columnIndex] : nil;
            if (!button) {
                continue;
            }
            NSMutableDictionary *summary = [NSMutableDictionary dictionaryWithDictionary:button];
            [summary setObject:[NSNumber numberWithUnsignedInteger:rowIndex] forKey:@"tg_row"];
            [summary setObject:[NSNumber numberWithUnsignedInteger:columnIndex] forKey:@"tg_column"];
            [buttons addObject:summary];
        }
    }
    return buttons;
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBezeled:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:color];
    [[field cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return field;
}

- (void)buildViews {
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [root setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:root];

    NSTextField *title = [self labelWithFrame:NSMakeRect(24, 380, 472, 26)
                                         font:[NSFont boldSystemFontOfSize:20.0]
                                        color:TGClassicHeaderTextColor(1.0)];
    [title setStringValue:TGLoc(@"bot.keyboard.title")];
    [title setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:title];
    NSTextField *hint = [self labelWithFrame:NSMakeRect(26, 350, 466, 22)
                                        font:[NSFont systemFontOfSize:11.0]
                                       color:TGClassicHeaderTextColor(0.82)];
    [hint setStringValue:TGLoc(@"bot.keyboard.hint")];
    [hint setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [root addSubview:hint];

    TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 62, 484, 278)] autorelease];
    [card setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [root addSubview:card];
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 106, 460, 220)] autorelease];
    [scroll setBorderType:NSNoBorder];
    [scroll setHasVerticalScroller:YES];
    [scroll setDrawsBackground:NO];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    self.tableView = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"button"] autorelease];
    [column setWidth:440.0];
    [self.tableView addTableColumn:column];
    [self.tableView setHeaderView:nil];
    [self.tableView setRowHeight:34.0];
    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setTarget:self];
    [self.tableView setDoubleAction:@selector(activatePressed:)];
    [scroll setDocumentView:self.tableView];
    [root addSubview:scroll];

    self.activateButton = [[[NSButton alloc] initWithFrame:NSMakeRect(338, 70, 152, 28)] autorelease];
    [self.activateButton setCell:[[[TGPrimaryTextButtonCell alloc] initTextCell:TGLoc(@"bot.keyboard.activate")] autorelease]];
    [self.activateButton setTitle:TGLoc(@"bot.keyboard.activate")];
    [self.activateButton setTarget:self];
    [self.activateButton setAction:@selector(activatePressed:)];
    [self.activateButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.activateButton];
    self.statusField = [self labelWithFrame:NSMakeRect(26, 30, 430, 18)
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicHeaderTextColor(0.82)];
    [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(470, 30, 16, 16)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [root addSubview:self.spinner];
    [self updateControls];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.buttons count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;
    (void)column;
    if (row < 0 || (NSUInteger)row >= [self.buttons count]) {
        return @"";
    }
    NSDictionary *button = [self.buttons objectAtIndex:(NSUInteger)row];
    NSDictionary *type = [[button objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [button objectForKey:@"type"] : [NSDictionary dictionary];
    NSString *typeName = [type objectForKey:@"@type"];
    NSString *kind = TGLoc(@"bot.button.text");
    if ([typeName rangeOfString:@"Callback"].location != NSNotFound) {
        kind = TGLoc(@"bot.button.callback");
    } else if ([typeName rangeOfString:@"LoginUrl"].location != NSNotFound) {
        kind = TGLoc(@"bot.button.login");
    } else if ([typeName rangeOfString:@"Url"].location != NSNotFound) {
        kind = TGLoc(@"bot.button.link");
    } else if ([typeName rangeOfString:@"SwitchInline"].location != NSNotFound) {
        kind = TGLoc(@"bot.button.inline");
    } else if ([typeName rangeOfString:@"Buy"].location != NSNotFound) {
        kind = TGLoc(@"bot.button.paid");
    }
    return [NSString stringWithFormat:@"%@  ·  %@", [button objectForKey:@"text"], kind];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateControls];
}

- (void)updateControls {
    [self.activateButton setEnabled:(!self.loading && [self.tableView selectedRow] >= 0)];
}

- (void)setLoading:(BOOL)loading status:(NSString *)status {
    self.loading = loading;
    [self.statusField setStringValue:status ? status : @""];
    if (loading) {
        [self.spinner startAnimation:nil];
    } else {
        [self.spinner stopAnimation:nil];
    }
    [self updateControls];
}

- (BOOL)confirmWithTitle:(NSString *)title message:(NSString *)message allowTitle:(NSString *)allowTitle {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title ? title : TGLoc(@"bot.keyboard.title")];
    [alert setInformativeText:message ? message : @""];
    [alert addButtonWithTitle:allowTitle ? allowTitle : TGLoc(@"open")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

- (void)openURLString:(NSString *)urlString requiringConfirmation:(BOOL)confirmation {
    NSURL *url = [NSURL URLWithString:urlString ? urlString : @""];
    if (!url || ![[NSArray arrayWithObjects:@"http", @"https", nil] containsObject:[[url scheme] lowercaseString]]) {
        [self setLoading:NO status:TGLoc(@"bot.link.invalid")];
        return;
    }
    if (confirmation && ![self confirmWithTitle:TGLoc(@"bot.link.confirmTitle")
                                        message:[NSString stringWithFormat:TGLoc(@"bot.link.confirmMessage"), [url host]]
                                     allowTitle:TGLoc(@"open")]) {
        [self setLoading:NO status:TGLoc(@"bot.cancelled")];
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:url];
    [self setLoading:NO status:TGLoc(@"bot.link.opened")];
}

- (void)activatePressed:(id)sender {
    (void)sender;
    NSInteger row = [self.tableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.buttons count] || self.loading) {
        return;
    }
    NSDictionary *button = [self.buttons objectAtIndex:(NSUInteger)row];
    NSDictionary *type = [[button objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
        ? [button objectForKey:@"type"] : [NSDictionary dictionary];
    NSString *typeName = [type objectForKey:@"@type"];
    NSString *buttonText = [button objectForKey:@"text"];

    if ([typeName isEqualToString:@"inlineKeyboardButtonTypeUrl"]) {
        [self openURLString:[type objectForKey:@"url"] requiringConfirmation:YES];
        return;
    }
    if ([typeName isEqualToString:@"inlineKeyboardButtonTypeLoginUrl"]) {
        [self resolveLoginButton:type];
        return;
    }
    if ([typeName isEqualToString:@"inlineKeyboardButtonTypeCallback"] ||
        [typeName isEqualToString:@"inlineKeyboardButtonTypeCallbackGame"]) {
        [self runCallbackButton:type];
        return;
    }
    if ([typeName rangeOfString:@"Buy"].location != NSNotFound) {
        [self setLoading:NO status:TGLoc(@"bot.paid.officialOnly")];
        return;
    }
    if ([typeName rangeOfString:@"SwitchInline"].location != NSNotFound) {
        NSString *query = [type objectForKey:@"query"];
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        [pasteboard setString:(query ? query : @"") forType:NSStringPboardType];
        [self setLoading:NO status:TGLoc(@"bot.inline.copied")];
        return;
    }
    if ([typeName isEqualToString:@"keyboardButtonTypeText"] || [typeName length] == 0) {
        [self sendTextButton:buttonText];
        return;
    }
    if ([typeName rangeOfString:@"RequestPhoneNumber"].location != NSNotFound ||
        [typeName rangeOfString:@"RequestLocation"].location != NSNotFound) {
        [self setLoading:NO status:TGLoc(@"bot.personalData.manualOnly")];
        return;
    }
    if ([typeName rangeOfString:@"WebApp"].location != NSNotFound) {
        [self setLoading:NO status:TGLoc(@"bot.webApp.officialOnly")];
        return;
    }
    [self setLoading:NO status:TGLoc(@"bot.button.unsupported")];
}

- (void)sendTextButton:(NSString *)text {
    if ([text length] == 0) {
        return;
    }
    [self setLoading:YES status:TGLoc(@"bot.command.sending")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSString *textCopy = [text copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *result = [[client sendTextMessageToChatID:chatID text:textCopy timeout:8.0 error:&error] copy];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO status:([result length] > 0 ? TGLoc(@"bot.command.sent") :
                                         ([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable")))];
            [result release];
            [errorMessage release];
            [client release];
            [chatID release];
            [textCopy release];
        });
        [pool drain];
    });
}

- (void)runCallbackButton:(NSDictionary *)type {
    [self setLoading:YES status:TGLoc(@"bot.callback.loading")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *messageID = [self.messageID retain];
    NSDictionary *typeCopy = [type copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *answer = [[client callbackQueryAnswerForChatID:chatID messageID:messageID
                                                          buttonType:typeCopy timeout:10.0 error:&error] retain];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *text = [answer objectForKey:@"text"];
            NSString *url = [answer objectForKey:@"url"];
            if ([url length] > 0) {
                [self openURLString:url requiringConfirmation:YES];
            } else {
                [self setLoading:NO status:([text length] > 0 ? text :
                                             (answer ? TGLoc(@"bot.callback.done") :
                                              ([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable"))))];
                if ([[answer objectForKey:@"show_alert"] boolValue] && [text length] > 0) {
                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert setMessageText:TGLoc(@"bot.keyboard.title")];
                    [alert setInformativeText:text];
                    [alert addButtonWithTitle:TGLoc(@"ok")];
                    [alert runModal];
                }
            }
            [answer release];
            [errorMessage release];
            [client release];
            [chatID release];
            [messageID release];
            [typeCopy release];
        });
        [pool drain];
    });
}

- (void)resolveLoginButton:(NSDictionary *)type {
    NSNumber *buttonID = [type objectForKey:@"id"];
    if (![buttonID respondsToSelector:@selector(longLongValue)]) {
        [self setLoading:NO status:TGLoc(@"bot.button.unsupported")];
        return;
    }
    [self setLoading:YES status:TGLoc(@"bot.login.checking")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *messageID = [self.messageID retain];
    NSNumber *buttonIDCopy = [buttonID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *info = [[client loginURLInfoForChatID:chatID messageID:messageID
                                                   buttonID:buttonIDCopy timeout:10.0 error:&error] retain];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *infoType = [info objectForKey:@"@type"];
            if ([infoType isEqualToString:@"loginUrlInfoOpen"]) {
                BOOL skip = [[info objectForKey:@"skip_confirmation"] boolValue];
                [self openURLString:[info objectForKey:@"url"] requiringConfirmation:!skip];
            } else if ([infoType isEqualToString:@"loginUrlInfoRequestConfirmation"]) {
                NSString *domain = [info objectForKey:@"domain"];
                BOOL wantsWrite = [[info objectForKey:@"request_write_access"] boolValue];
                if (wantsWrite) {
                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert setMessageText:TGLoc(@"bot.login.confirmTitle")];
                    [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"bot.login.writePrompt"), domain]];
                    [alert addButtonWithTitle:TGLoc(@"bot.login.allowMessages")];
                    [alert addButtonWithTitle:TGLoc(@"bot.login.signInOnly")];
                    [alert addButtonWithTitle:TGLoc(@"cancel")];
                    NSInteger response = [alert runModal];
                    if (response == NSAlertFirstButtonReturn) {
                        [self requestResolvedLoginURLForButtonID:buttonIDCopy allowWriteAccess:YES];
                    } else if (response == NSAlertSecondButtonReturn) {
                        [self requestResolvedLoginURLForButtonID:buttonIDCopy allowWriteAccess:NO];
                    } else {
                        [self setLoading:NO status:TGLoc(@"bot.cancelled")];
                    }
                } else if ([self confirmWithTitle:TGLoc(@"bot.login.confirmTitle")
                                          message:[NSString stringWithFormat:TGLoc(@"bot.login.openPrompt"), domain]
                                       allowTitle:TGLoc(@"continue")]) {
                    [self requestResolvedLoginURLForButtonID:buttonIDCopy allowWriteAccess:NO];
                } else {
                    [self setLoading:NO status:TGLoc(@"bot.cancelled")];
                }
            } else {
                [self setLoading:NO status:([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable"))];
            }
            [info release];
            [errorMessage release];
            [client release];
            [chatID release];
            [messageID release];
            [buttonIDCopy release];
        });
        [pool drain];
    });
}

- (void)requestResolvedLoginURLForButtonID:(NSNumber *)buttonID allowWriteAccess:(BOOL)allowWriteAccess {
    [self setLoading:YES status:TGLoc(@"bot.login.resolving")];
    TGTDLibClient *client = [self.client retain];
    NSNumber *chatID = [self.chatID retain];
    NSNumber *messageID = [self.messageID retain];
    NSNumber *buttonIDCopy = [buttonID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *url = [[client resolvedLoginURLForChatID:chatID messageID:messageID buttonID:buttonIDCopy
                                          allowWriteAccess:allowWriteAccess timeout:10.0 error:&error] copy];
        NSString *errorMessage = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([url length] > 0) {
                [self openURLString:url requiringConfirmation:NO];
            } else {
                [self setLoading:NO status:([errorMessage length] > 0 ? errorMessage : TGLoc(@"bot.unavailable"))];
            }
            [url release];
            [errorMessage release];
            [client release];
            [chatID release];
            [messageID release];
            [buttonIDCopy release];
        });
        [pool drain];
    });
}

@end
