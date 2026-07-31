#import "TGBotCommandPanelView.h"

#import "../Core/TGTDLibClient+Bots.h"
#import "TGLocalization.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGBotCommandCell : NSTextFieldCell
@end

@implementation TGBotCommandCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    id value = [self objectValue];
    if (![value isKindOfClass:[NSDictionary class]]) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }
    NSDictionary *command = (NSDictionary *)value;
    BOOL replyButton = [[command objectForKey:@"tg_panel_kind"] isEqualToString:@"reply"];
    NSString *name = nil;
    NSString *detail = nil;
    if (replyButton) {
        name = [[command objectForKey:@"text"] isKindOfClass:[NSString class]]
            ? [command objectForKey:@"text"] : @"";
        NSDictionary *type = [[command objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
            ? [command objectForKey:@"type"] : nil;
        NSString *typeName = [[type objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [type objectForKey:@"@type"] : @"";
        if ([typeName rangeOfString:@"RequestPhone"].location != NSNotFound) {
            detail = TGLoc(@"bot.button.phone");
        } else if ([typeName rangeOfString:@"RequestLocation"].location != NSNotFound) {
            detail = TGLoc(@"bot.button.location");
        } else if ([typeName rangeOfString:@"RequestPoll"].location != NSNotFound) {
            detail = TGLoc(@"bot.button.poll");
        } else if ([typeName rangeOfString:@"WebApp"].location != NSNotFound) {
            detail = TGLoc(@"bot.button.webApp");
        } else {
            detail = TGLoc(@"bot.button.text");
        }
    } else {
        name = [[command objectForKey:@"command"] isKindOfClass:[NSString class]]
            ? [@"/" stringByAppendingString:[command objectForKey:@"command"]] : @"";
        detail = [[command objectForKey:@"description"] isKindOfClass:[NSString class]]
            ? [command objectForKey:@"description"] : @"";
    }
    BOOL highlighted = [self isHighlighted];
    if (replyButton) {
        NSDictionary *type = [[command objectForKey:@"type"] isKindOfClass:[NSDictionary class]]
            ? [command objectForKey:@"type"] : nil;
        NSString *typeName = [[type objectForKey:@"@type"] description];
        NSColor *buttonColor = TGClassicSelectedRowColor();
        if ([typeName rangeOfString:@"Request"].location != NSNotFound) {
            buttonColor = TGClassicOutgoingBubbleBottomColor();
        } else if ([typeName rangeOfString:@"WebApp"].location != NSNotFound) {
            buttonColor = TGClassicNavigationHighlightedColor(1.0);
        }
        NSRect backgroundRect = NSInsetRect(cellFrame, 5.0, 3.0);
        NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:backgroundRect
                                                                   xRadius:8.0
                                                                   yRadius:8.0];
        [[buttonColor colorWithAlphaComponent:highlighted ? 0.95 : 0.30] set];
        [background fill];
        [TGClassicPanelStrokeColor() set];
        [background setLineWidth:1.0];
        [background stroke];
    }
    NSColor *nameColor = highlighted ? [NSColor whiteColor] : TGClassicCardInkColor();
    NSColor *detailColor = highlighted
        ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.82]
        : TGClassicCardMutedInkColor();
    NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [style setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary *nameAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:13.0], NSFontAttributeName,
                                    nameColor, NSForegroundColorAttributeName,
                                    style, NSParagraphStyleAttributeName, nil];
    NSDictionary *detailAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont systemFontOfSize:11.0], NSFontAttributeName,
                                      detailColor, NSForegroundColorAttributeName,
                                      style, NSParagraphStyleAttributeName, nil];
    NSRect nameRect = NSMakeRect(NSMinX(cellFrame) + 12.0, NSMinY(cellFrame) + 20.0,
                                 NSWidth(cellFrame) - 24.0, 18.0);
    NSRect detailRect = NSMakeRect(NSMinX(cellFrame) + 12.0, NSMinY(cellFrame) + 5.0,
                                   NSWidth(cellFrame) - 24.0, 15.0);
    [name drawInRect:nameRect withAttributes:nameAttributes];
    [detail drawInRect:detailRect withAttributes:detailAttributes];
}

@end

@interface TGBotCommandPanelView ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSTableView *tableView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSArray *commands;
@property (nonatomic, assign) NSUInteger generation;
@end

@implementation TGBotCommandPanelView

@synthesize target = _target;
@synthesize action = _action;
@synthesize client = _client;
@synthesize tableView = _tableView;
@synthesize statusField = _statusField;
@synthesize spinner = _spinner;
@synthesize commands = _commands;
@synthesize generation = _generation;

- (id)initWithFrame:(NSRect)frame client:(TGTDLibClient *)client {
    self = [super initWithFrame:frame];
    if (self) {
        self.client = client;
        self.commands = [NSArray array];

        TGGroupedCardView *card = [[[TGGroupedCardView alloc] initWithFrame:[self bounds]] autorelease];
        [card setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self addSubview:card];

        NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:NSInsetRect([self bounds], 6.0, 6.0)] autorelease];
        [scroll setBorderType:NSNoBorder];
        [scroll setDrawsBackground:NO];
        [scroll setHasVerticalScroller:YES];
        [scroll setAutohidesScrollers:YES];
        [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        self.tableView = [[[NSTableView alloc] initWithFrame:[[scroll contentView] bounds]] autorelease];
        NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"command"] autorelease];
        [column setWidth:MAX(120.0, NSWidth(frame) - 18.0)];
        [column setResizingMask:NSTableColumnAutoresizingMask];
        [column setDataCell:[[[TGBotCommandCell alloc] initTextCell:@""] autorelease]];
        [self.tableView addTableColumn:column];
        [self.tableView setHeaderView:nil];
        [self.tableView setRowHeight:44.0];
        [self.tableView setAllowsEmptySelection:YES];
        [self.tableView setDataSource:self];
        [self.tableView setDelegate:self];
        [self.tableView setTarget:self];
        [self.tableView setAction:@selector(commandPressed:)];
        [scroll setDocumentView:self.tableView];
        [self addSubview:scroll];

        self.statusField = [[[NSTextField alloc] initWithFrame:NSMakeRect(18.0, NSMidY([self bounds]) - 9.0,
                                                                         NSWidth([self bounds]) - 36.0, 18.0)] autorelease];
        [self.statusField setEditable:NO];
        [self.statusField setSelectable:NO];
        [self.statusField setBordered:NO];
        [self.statusField setDrawsBackground:NO];
        [self.statusField setAlignment:NSCenterTextAlignment];
        [self.statusField setFont:[NSFont systemFontOfSize:11.0]];
        [self.statusField setTextColor:TGClassicCardMutedInkColor()];
        [self.statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.statusField];

        self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(NSMidX([self bounds]) - 8.0,
                                                                              NSMidY([self bounds]) + 14.0,
                                                                              16.0, 16.0)] autorelease];
        [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
        [self.spinner setDisplayedWhenStopped:NO];
        [self.spinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.spinner];
        [self clearCommands];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_tableView release];
    [_statusField release];
    [_spinner release];
    [_commands release];
    [super dealloc];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return (NSInteger)[self.commands count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    (void)tableView;
    (void)column;
    return (row >= 0 && (NSUInteger)row < [self.commands count])
        ? [self.commands objectAtIndex:(NSUInteger)row] : nil;
}

- (void)commandPressed:(id)sender {
    (void)sender;
    NSInteger row = [self.tableView clickedRow];
    if (row < 0) {
        row = [self.tableView selectedRow];
    }
    if (row < 0 || (NSUInteger)row >= [self.commands count]) {
        return;
    }
    if (self.target && self.action && [self.target respondsToSelector:self.action]) {
        [self.target performSelector:self.action withObject:[self.commands objectAtIndex:(NSUInteger)row]];
    }
}

- (void)clearCommands {
    self.generation++;
    self.commands = [NSArray array];
    [self.tableView reloadData];
    [self.spinner stopAnimation:nil];
    [self.statusField setStringValue:TGLoc(@"bot.commands.empty")];
    [self.statusField setHidden:NO];
    [self.tableView setHidden:YES];
}

- (void)loadCommandsForUserID:(NSNumber *)userID {
    if (![userID respondsToSelector:@selector(longLongValue)]) {
        [self clearCommands];
        return;
    }
    self.generation++;
    NSUInteger generation = self.generation;
    [self.statusField setStringValue:TGLoc(@"bot.loading")];
    [self.statusField setHidden:NO];
    [self.tableView setHidden:YES];
    [self.spinner startAnimation:nil];
    TGTDLibClient *client = [self.client retain];
    NSNumber *botID = [userID retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSDictionary *summary = [[client botInteractionSummaryForUserID:botID timeout:8.0 error:&error] retain];
        NSArray *commands = [[[summary objectForKey:@"commands"] isKindOfClass:[NSArray class]]
            ? [summary objectForKey:@"commands"] : [NSArray array] retain];
        NSString *failure = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.generation) {
                self.commands = commands;
                [self.tableView reloadData];
                [self.spinner stopAnimation:nil];
                BOOL hasCommands = [self.commands count] > 0;
                [self.tableView setHidden:!hasCommands];
                [self.statusField setHidden:hasCommands];
                if (!hasCommands) {
                    [self.statusField setStringValue:[failure length] > 0
                        ? failure : TGLoc(@"bot.commands.empty")];
                }
            }
            [failure release];
            [commands release];
            [summary release];
            [botID release];
            [client release];
        });
        [pool drain];
    });
}

- (void)showReplyMarkup:(NSDictionary *)replyMarkup {
    self.generation++;
    NSArray *rows = [[replyMarkup objectForKey:@"rows"] isKindOfClass:[NSArray class]]
        ? [replyMarkup objectForKey:@"rows"] : [NSArray array];
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger rowIndex = 0;
    for (rowIndex = 0; rowIndex < [rows count]; rowIndex++) {
        NSArray *row = [[rows objectAtIndex:rowIndex] isKindOfClass:[NSArray class]]
            ? [rows objectAtIndex:rowIndex] : nil;
        NSUInteger columnIndex = 0;
        for (columnIndex = 0; columnIndex < [row count]; columnIndex++) {
            NSDictionary *button = [[row objectAtIndex:columnIndex] isKindOfClass:[NSDictionary class]]
                ? [row objectAtIndex:columnIndex] : nil;
            if (!button) {
                continue;
            }
            NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:button];
            [item setObject:@"reply" forKey:@"tg_panel_kind"];
            [item setObject:[NSNumber numberWithUnsignedInteger:rowIndex] forKey:@"tg_row"];
            [item setObject:[NSNumber numberWithUnsignedInteger:columnIndex] forKey:@"tg_column"];
            [items addObject:item];
        }
    }
    self.commands = items;
    [self.spinner stopAnimation:nil];
    [self.tableView reloadData];
    BOOL hasItems = ([self.commands count] > 0);
    [self.tableView setHidden:!hasItems];
    [self.statusField setHidden:hasItems];
    if (!hasItems) {
        [self.statusField setStringValue:TGLoc(@"bot.keyboard.empty")];
    }
}

@end
