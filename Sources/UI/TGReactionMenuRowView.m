#import "TGReactionMenuRowView.h"
#import "../Core/TGMessageItem.h"

BOOL TGReactionEmojiCanRender(NSString *emoji) {
    if (![emoji isKindOfClass:[NSString class]] || [emoji length] == 0) {
        return NO;
    }
    /*
     * NSLayoutManager on 10.8/10.9 can report NSNullGlyph for color emoji
     * even though NSButton correctly draws them through Apple Color Emoji.
     * Keep the stock legacy set explicit so the renderer probe cannot turn
     * familiar reactions into question marks.
     */
    static NSSet *legacySafeEmojis = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        legacySafeEmojis = [[NSSet alloc] initWithObjects:
            @"👍", @"👎", @"❤", @"🔥", @"😂", @"😢", @"😭", @"😁",
            @"👏", @"😱", @"🎉", @"💩", @"🙏", @"👌", @"😍", @"👀",
            @"⚡", @"💔", @"😐", @"🎃", @"👻", @"🎅", @"🎄", @"☃",
            nil];
    });
    if ([legacySafeEmojis containsObject:emoji]) {
        return YES;
    }
    NSTextStorage *storage = [[[NSTextStorage alloc] initWithString:emoji
                                                        attributes:[NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:17.0]
                                                                                             forKey:NSFontAttributeName]] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
    NSTextContainer *container = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(128.0, 32.0)] autorelease];
    [layoutManager addTextContainer:container];
    [storage addLayoutManager:layoutManager];
    NSRange glyphRange = [layoutManager glyphRangeForTextContainer:container];
    NSUInteger index = 0;
    for (index = glyphRange.location; index < NSMaxRange(glyphRange); index++) {
        if ([layoutManager glyphAtIndex:index] == NSNullGlyph) {
            return NO;
        }
    }
    return (glyphRange.length > 0);
}

@interface TGReactionMenuButton : NSButton {
    NSDictionary *_reactionPayload;
}
@property (nonatomic, retain) NSDictionary *reactionPayload;
- (id)representedObject;
@end

@implementation TGReactionMenuButton
@synthesize reactionPayload = _reactionPayload;
- (void)dealloc {
    [_reactionPayload release];
    [super dealloc];
}
- (id)representedObject {
    return _reactionPayload;
}
@end

@interface TGReactionMenuDocumentView : NSView
@end

@implementation TGReactionMenuDocumentView
- (BOOL)isFlipped {
    return YES;
}
@end

@interface TGReactionMenuClipView : NSClipView
@end

@implementation TGReactionMenuClipView

- (NSRect)constrainBoundsRect:(NSRect)proposedBounds {
    NSRect constrainedBounds = [super constrainBoundsRect:proposedBounds];
    NSView *documentView = [self documentView];
    if (!documentView) {
        return constrainedBounds;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat minimumX = NSMinX(documentBounds);
    CGFloat minimumY = NSMinY(documentBounds);
    CGFloat maximumX = MAX(minimumX, NSMaxX(documentBounds) - NSWidth(constrainedBounds));
    CGFloat maximumY = MAX(minimumY, NSMaxY(documentBounds) - NSHeight(constrainedBounds));
    constrainedBounds.origin.x = MAX(minimumX, MIN(constrainedBounds.origin.x, maximumX));
    constrainedBounds.origin.y = MAX(minimumY, MIN(constrainedBounds.origin.y, maximumY));
    return constrainedBounds;
}

@end

@interface TGReactionMenuRowView () {
    id _reactionTarget;
    SEL _reactionAction;
}
- (void)reactionButtonPressed:(id)sender;
@end

@implementation TGReactionMenuRowView

- (id)initWithEmojis:(NSArray *)emojis
             message:(TGMessageItem *)message
      chosenReactions:(NSArray *)chosenReactions
              target:(id)target
              action:(SEL)action {
    const NSUInteger columnCount = 8U;
    const NSUInteger maximumVisibleRows = 4U;
    CGFloat buttonWidth = 34.0;
    CGFloat rowHeight = 34.0;
    NSUInteger emojiCount = [emojis count];
    NSUInteger rowCount = MAX((NSUInteger)1U,
                              (emojiCount + columnCount - 1U) / columnCount);
    NSUInteger visibleRowCount = MIN(maximumVisibleRows, rowCount);
    CGFloat viewportWidth = buttonWidth * columnCount + 16.0;
    CGFloat documentWidth = buttonWidth * columnCount;
    CGFloat viewportHeight = rowHeight * visibleRowCount;
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, viewportWidth, viewportHeight)];
    if (self) {
        _reactionTarget = target;
        _reactionAction = action;

        NSScrollView *scrollView = [[[NSScrollView alloc]
            initWithFrame:[self bounds]] autorelease];
        TGReactionMenuClipView *clipView = [[[TGReactionMenuClipView alloc]
            initWithFrame:[[scrollView contentView] frame]] autorelease];
        [scrollView setContentView:clipView];
        [scrollView setBorderType:NSNoBorder];
        [scrollView setDrawsBackground:NO];
        [scrollView setHasHorizontalScroller:NO];
        [scrollView setHasVerticalScroller:(rowCount > maximumVisibleRows)];
        [scrollView setAutohidesScrollers:NO];
        [scrollView setHorizontalScrollElasticity:NSScrollElasticityNone];
        [scrollView setVerticalScrollElasticity:NSScrollElasticityNone];

        TGReactionMenuDocumentView *documentView = [[[TGReactionMenuDocumentView alloc]
            initWithFrame:NSMakeRect(0.0,
                                     0.0,
                                     documentWidth,
                                     rowHeight * rowCount)] autorelease];
        [scrollView setDocumentView:documentView];
        [self addSubview:scrollView];

        NSUInteger index = 0;
        for (index = 0; index < emojiCount; index++) {
            NSString *emoji = [emojis objectAtIndex:index];
            NSString *displayEmoji = TGReactionEmojiCanRender(emoji) ? emoji : @"?";
            NSUInteger column = index % columnCount;
            NSUInteger row = index / columnCount;
            TGReactionMenuButton *button = [[[TGReactionMenuButton alloc]
                initWithFrame:NSMakeRect(column * buttonWidth,
                                         row * rowHeight + 2.0,
                                         buttonWidth,
                                         30.0)] autorelease];
            [button setTitle:displayEmoji];
            [button setFont:[NSFont systemFontOfSize:17.0]];
            [button setButtonType:NSMomentaryChangeButton];
            [button setBezelStyle:NSShadowlessSquareBezelStyle];
            [button setBordered:NO];
            [button setTarget:self];
            [button setAction:@selector(reactionButtonPressed:)];
            [button setToolTip:([chosenReactions containsObject:emoji]
                                ? [NSString stringWithFormat:@"%@ ✓", emoji]
                                : emoji)];
            button.reactionPayload = [NSDictionary dictionaryWithObjectsAndKeys:
                                      message, @"message",
                                      emoji, @"emoji",
                                      nil];
            [documentView addSubview:button];
        }
    }
    return self;
}

- (void)reactionButtonPressed:(id)sender {
    if (![_reactionTarget respondsToSelector:_reactionAction]) {
        return;
    }
    [_reactionTarget performSelector:_reactionAction withObject:sender];
    if ([self respondsToSelector:@selector(enclosingMenuItem)]) {
        NSMenuItem *item = [self performSelector:@selector(enclosingMenuItem)];
        [[item menu] cancelTracking];
    }
}

@end
