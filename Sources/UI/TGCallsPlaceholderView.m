#import "TGCallsPlaceholderView.h"

#import "TGLocalization.h"
#import "TGStatusViewCells.h"
#import "TGStatusViewComponents.h"
#import "TGTheme.h"

@interface TGCallsPlaceholderView ()
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) TGGroupedCardView *cardView;
@property (nonatomic, retain) NSTextField *messageField;
@end

@implementation TGCallsPlaceholderView

@synthesize titleField = _titleField;
@synthesize cardView = _cardView;
@synthesize messageField = _messageField;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        self.titleField = [[[NSTextField alloc] initWithFrame:NSMakeRect(18, NSHeight(frame) - 42.0, 320, 24)] autorelease];
        [self.titleField setEditable:NO];
        [self.titleField setSelectable:NO];
        [self.titleField setBezeled:NO];
        [self.titleField setDrawsBackground:NO];
        [self.titleField setFont:[NSFont boldSystemFontOfSize:18.0]];
        [self.titleField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [self addSubview:self.titleField];

        self.cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(80, 180, MAX(320.0, NSWidth(frame) - 160.0), 150)] autorelease];
        [self.cardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.cardView];

        self.messageField = [[[NSTextField alloc] initWithFrame:NSMakeRect(108, 222, MAX(264.0, NSWidth(frame) - 216.0), 66)] autorelease];
        [self.messageField setEditable:NO];
        [self.messageField setSelectable:NO];
        [self.messageField setBezeled:NO];
        [self.messageField setDrawsBackground:NO];
        [self.messageField setAlignment:NSCenterTextAlignment];
        [self.messageField setFont:[NSFont systemFontOfSize:13.0]];
        [[self.messageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [self.messageField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin)];
        [self addSubview:self.messageField];

        [self refreshLocalizedText];
        [self refreshThemeAppearance];
    }
    return self;
}

- (BOOL)isFlipped {
    return NO;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    (void)oldSize;
    NSRect bounds = [self bounds];
    [self.titleField setFrame:NSMakeRect(18.0, NSHeight(bounds) - 42.0, MAX(120.0, NSWidth(bounds) - 36.0), 24.0)];
    CGFloat cardWidth = MIN(560.0, MAX(300.0, NSWidth(bounds) - 120.0));
    CGFloat cardX = floor((NSWidth(bounds) - cardWidth) / 2.0);
    CGFloat cardY = floor((NSHeight(bounds) - 150.0) / 2.0);
    [self.cardView setFrame:NSMakeRect(cardX, cardY, cardWidth, 150.0)];
    [self.messageField setFrame:NSMakeRect(cardX + 28.0, cardY + 42.0, cardWidth - 56.0, 66.0)];
}

- (void)refreshLocalizedText {
    [self.titleField setStringValue:TGLoc(@"calls")];
    [self.messageField setStringValue:TGLoc(@"calls.placeholder")];
}

- (void)refreshThemeAppearance {
    [self.titleField setTextColor:TGClassicInkColor()];
    [self.messageField setTextColor:TGClassicCardMutedInkColor()];
    [self.cardView setNeedsDisplay:YES];
    [self setNeedsDisplay:YES];
}

- (void)dealloc {
    [_titleField release];
    [_cardView release];
    [_messageField release];
    [super dealloc];
}

@end
