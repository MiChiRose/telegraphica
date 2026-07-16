#import "TGMessageViewersWindowController.h"

@interface TGMessageViewersWindowController ()
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *subtitleField;
@property (nonatomic, retain) NSScrollView *scrollView;
@property (nonatomic, retain) NSView *contentView;
@property (nonatomic, copy) NSString *messagePreview;
@end

@implementation TGMessageViewersWindowController

@synthesize titleField = _titleField;
@synthesize subtitleField = _subtitleField;
@synthesize scrollView = _scrollView;
@synthesize contentView = _contentView;
@synthesize messagePreview = _messagePreview;

- (id)initWithMessagePreview:(NSString *)messagePreview {
    NSRect frame = NSMakeRect(0, 0, 420, 340);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.messagePreview = messagePreview;
        [[self window] setTitle:@"Who read"];
        [self buildViews];
        [self showLoading];
    }
    return self;
}

- (void)dealloc {
    [_titleField release];
    [_subtitleField release];
    [_scrollView release];
    [_contentView release];
    [_messagePreview release];
    [super dealloc];
}

- (NSTextField *)labelWithFrame:(NSRect)frame font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setFont:font];
    [label setTextColor:color];
    [[label cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    return label;
}

- (void)buildViews {
    NSView *root = [[self window] contentView];
    [root setWantsLayer:YES];
    [[root layer] setBackgroundColor:[[NSColor colorWithCalibratedRed:0.91 green:0.95 blue:0.98 alpha:1.0] CGColor]];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 294, 372, 24)
                                      font:[NSFont boldSystemFontOfSize:18.0]
                                     color:[NSColor colorWithCalibratedWhite:0.08 alpha:1.0]];
    [self.titleField setAlignment:NSCenterTextAlignment];
    [self.titleField setStringValue:@"Who read this message"];
    [root addSubview:self.titleField];

    self.subtitleField = [self labelWithFrame:NSMakeRect(34, 268, 352, 18)
                                         font:[NSFont systemFontOfSize:12.0]
                                        color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];
    [self.subtitleField setAlignment:NSCenterTextAlignment];
    [self.subtitleField setStringValue:([self.messagePreview length] > 0 ? self.messagePreview : @"Message")];
    [root addSubview:self.subtitleField];

    self.scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 24, 372, 232)] autorelease];
    [self.scrollView setHasVerticalScroller:YES];
    [self.scrollView setBorderType:NSNoBorder];
    [self.scrollView setDrawsBackground:NO];
    self.contentView = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 352, 232)] autorelease];
    [self.scrollView setDocumentView:self.contentView];
    [root addSubview:self.scrollView];
}

- (void)clearContent {
    NSArray *subviews = [[self.contentView subviews] copy];
    NSUInteger index = 0;
    for (index = 0; index < [subviews count]; index++) {
        [[subviews objectAtIndex:index] removeFromSuperview];
    }
    [subviews release];
}

- (void)setSingleMessage:(NSString *)message color:(NSColor *)color {
    [self clearContent];
    [self.contentView setFrame:NSMakeRect(0, 0, 352, 232)];
    NSTextField *label = [self labelWithFrame:NSMakeRect(18, 100, 316, 24)
                                         font:[NSFont systemFontOfSize:13.0]
                                        color:color];
    [label setAlignment:NSCenterTextAlignment];
    [label setStringValue:([message length] > 0 ? message : @"No data")];
    [self.contentView addSubview:label];
}

- (void)showLoading {
    [self setSingleMessage:@"Loading readers..." color:[NSColor colorWithCalibratedWhite:0.38 alpha:1.0]];
}

- (void)showErrorMessage:(NSString *)message {
    [self setSingleMessage:([message length] > 0 ? message : @"Readers are unavailable for this message.")
                     color:[NSColor colorWithCalibratedRed:0.62 green:0.12 blue:0.10 alpha:1.0]];
}

- (void)showViewerSummaries:(NSArray *)viewerSummaries {
    [self clearContent];
    if ([viewerSummaries count] == 0) {
        [self setSingleMessage:@"Nobody has read it yet." color:[NSColor colorWithCalibratedWhite:0.38 alpha:1.0]];
        return;
    }

    CGFloat rowHeight = 46.0;
    CGFloat totalHeight = MAX(232.0, rowHeight * [viewerSummaries count]);
    [self.contentView setFrame:NSMakeRect(0, 0, 352, totalHeight)];

    NSUInteger index = 0;
    for (index = 0; index < [viewerSummaries count]; index++) {
        NSDictionary *summary = [viewerSummaries objectAtIndex:index];
        CGFloat y = totalHeight - ((CGFloat)index + 1.0) * rowHeight;
        NSView *row = [[[NSView alloc] initWithFrame:NSMakeRect(0, y, 352, rowHeight)] autorelease];

        NSString *avatarPath = [summary objectForKey:@"avatar_local_path"];
        NSImageView *avatarView = [[[NSImageView alloc] initWithFrame:NSMakeRect(10, 7, 32, 32)] autorelease];
        if ([avatarPath length] > 0) {
            NSImage *avatar = [[[NSImage alloc] initWithContentsOfFile:avatarPath] autorelease];
            if (avatar) {
                [avatarView setImage:avatar];
            }
        }
        [avatarView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [row addSubview:avatarView];

        NSTextField *name = [self labelWithFrame:NSMakeRect(54, 16, 220, 18)
                                            font:[NSFont boldSystemFontOfSize:13.0]
                                           color:[NSColor colorWithCalibratedWhite:0.12 alpha:1.0]];
        NSString *displayName = [summary objectForKey:@"display_name"];
        [name setStringValue:([displayName length] > 0 ? displayName : @"Unknown")];
        [row addSubview:name];

        id viewDate = [summary objectForKey:@"view_date"];
        if ([viewDate respondsToSelector:@selector(integerValue)] && [viewDate integerValue] > 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[viewDate integerValue]];
            NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
            [formatter setDateStyle:NSDateFormatterNoStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
            NSTextField *time = [self labelWithFrame:NSMakeRect(278, 16, 62, 18)
                                                font:[NSFont systemFontOfSize:12.0]
                                               color:[NSColor colorWithCalibratedWhite:0.50 alpha:1.0]];
            [time setAlignment:NSRightTextAlignment];
            [time setStringValue:[formatter stringFromDate:date]];
            [row addSubview:time];
        }

        if (index + 1 < [viewerSummaries count]) {
            NSBox *line = [[[NSBox alloc] initWithFrame:NSMakeRect(54, 0, 286, 1)] autorelease];
            [line setBoxType:NSBoxSeparator];
            [row addSubview:line];
        }

        [self.contentView addSubview:row];
    }
}

@end
