#import "TGStatusViewCells.h"
#import "TGChatDisplayPreferences.h"
#import "TGIconAssets.h"
#import "TGMessageLayoutSupport.h"
#import "TGIconDrawing.h"
#import "TGStatusButtonCells.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"

static CGFloat const TGPanelCornerRadius = 8.0;
static CGFloat const TGPanelHeaderHeight = 40.0;

@implementation TGChatListCell

@synthesize chatItem = _chatItem;

- (id)copyWithZone:(NSZone *)zone {
    TGChatListCell *cell = [super copyWithZone:zone];
    cell->_chatItem = nil;
    [cell setChatItem:self.chatItem];
    return cell;
}

- (void)setObjectValue:(id)value {
    if ([value isKindOfClass:[TGChatItem class]]) {
        self.chatItem = (TGChatItem *)value;
        [super setObjectValue:@""];
        return;
    }
    self.chatItem = nil;
    [super setObjectValue:(value ? value : @"")];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGChatItem *item = self.chatItem;
    if (!item) {
        id value = [self objectValue];
        if ([value isKindOfClass:[TGChatItem class]]) {
            item = (TGChatItem *)value;
        }
    }
    if (!item) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    BOOL selected = [self isHighlighted];
    if (selected) {
        NSRect selectedRect = NSInsetRect(cellFrame, 0.0, 1.0);
        NSBezierPath *selectedPath = [NSBezierPath bezierPathWithRoundedRect:selectedRect
                                                                     xRadius:8.0
                                                                     yRadius:8.0];
        [TGClassicSelectedRowColor() set];
        [selectedPath fill];
    }

    NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + 8.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 26.0) / 2.0),
                                   26.0,
                                   26.0);
    NSString *displayTitle = [item isSavedMessages] ? TGLoc(@"savedMessages") : [item title];
    if ([item isSavedMessages]) {
        NSBezierPath *savedPath = [NSBezierPath bezierPathWithOvalInRect:avatarRect];
        NSGradient *savedGradient = [[[NSGradient alloc] initWithStartingColor:TGColorFromHex(0x49b7ff)
                                                                   endingColor:TGColorFromHex(0x1888d8)] autorelease];
        [savedGradient drawInBezierPath:savedPath angle:90.0];
        TGDrawTemplateIconAsset(@"bookmark",
                                NSInsetRect(avatarRect, 6.0, 5.0),
                                [NSColor whiteColor],
                                1.0,
                                [controlView isFlipped]);
    } else {
        TGDrawAvatarInRect([item avatarLocalPath], displayTitle, avatarRect, selected, [controlView isFlipped]);
    }

    NSInteger unreadCount = [[item unreadCount] respondsToSelector:@selector(integerValue)] ? [[item unreadCount] integerValue] : 0;
    NSString *unreadString = @"";
    if (unreadCount > 999) {
        unreadString = @"999+";
    } else if (unreadCount > 0) {
        unreadString = [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }

    NSColor *unreadTextColor = selected ? TGClassicSelectedRowColor() : TGClassicNavigationTextColor(1.0);
    NSDictionary *unreadAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                      unreadTextColor, NSForegroundColorAttributeName,
                                      nil];
    NSSize unreadSize = [unreadString sizeWithAttributes:unreadAttributes];
    CGFloat unreadWidth = ([unreadString length] > 0) ? MAX(unreadSize.width + 13.0, 20.0) : 0.0;
    CGFloat unreadHeight = ([unreadString length] > 0) ? 18.0 : 0.0;
    NSRect unreadRect = NSMakeRect(NSMaxX(cellFrame) - unreadWidth - 9.0,
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - unreadHeight) / 2.0),
                                   unreadWidth,
                                   unreadHeight);

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     selected ? TGClassicSelectedRowTextColor() : TGClassicInkColor(), NSForegroundColorAttributeName,
                                     paragraph, NSParagraphStyleAttributeName,
                                     nil];
    CGFloat titleX = NSMaxX(avatarRect) + 9.0;
    CGFloat titleRight = ([unreadString length] > 0) ? (NSMinX(unreadRect) - 12.0) : (NSMaxX(cellFrame) - 9.0);
    CGFloat muteIconWidth = [item notificationsMuted] ? 15.0 : 0.0;
    CGFloat pinIconWidth = [item isPinned] ? 12.0 : 0.0;
    CGFloat trailingIconWidth = ([item notificationsMuted] ? (muteIconWidth + 5.0) : 0.0) + ([item isPinned] ? (pinIconWidth + 4.0) : 0.0);
    CGFloat titleAvailableWidth = titleRight - titleX - trailingIconWidth;
    if (titleAvailableWidth < 40.0) {
        titleAvailableWidth = 40.0;
    }
    NSSize titleSize = [displayTitle sizeWithAttributes:titleAttributes];
    CGFloat titleDrawWidth = titleAvailableWidth;
    if (([item notificationsMuted] || [item isPinned]) && titleSize.width < titleAvailableWidth) {
        titleDrawWidth = titleSize.width;
    }
    NSRect titleRect = NSMakeRect(titleX,
                                  NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                  titleDrawWidth,
                                  16.0);
    [displayTitle drawInRect:titleRect withAttributes:titleAttributes];
    CGFloat iconX = NSMaxX(titleRect) + 4.0;
    if ([item isPinned]) {
        NSRect pinRect = NSMakeRect(iconX,
                                    NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 12.0) / 2.0),
                                    12.0,
                                    12.0);
        NSColor *pinColor = selected ? TGClassicSelectedRowTextColor() : TGClassicMutedInkColor();
        TGDrawTemplateIconAsset(@"flag-triangle", pinRect, pinColor, 0.9, [controlView isFlipped]);
        iconX = NSMaxX(pinRect) + 4.0;
    }
    if ([item notificationsMuted]) {
        NSRect muteRect = NSMakeRect(iconX,
                                     NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                     15.0,
                                     15.0);
        NSColor *muteColor = selected ? TGClassicSelectedRowTextColor() : TGClassicMutedInkColor();
        TGDrawTemplateIconAsset(@"sound-off", muteRect, muteColor, 1.0, [controlView isFlipped]);
    }
    if ([unreadString length] > 0) {
        NSBezierPath *unreadPath = [NSBezierPath bezierPathWithRoundedRect:unreadRect
                                                                    xRadius:(unreadHeight / 2.0)
                                                                    yRadius:(unreadHeight / 2.0)];
        NSColor *unreadFillColor = selected ? TGClassicSelectedRowTextColor() : TGClassicHeaderBottomColor();
        [unreadFillColor set];
        [unreadPath fill];

        NSRect unreadTextRect = NSMakeRect(NSMinX(unreadRect),
                                           NSMinY(unreadRect) + floor((NSHeight(unreadRect) - unreadSize.height) / 2.0) + 1.0,
                                           NSWidth(unreadRect),
                                           unreadSize.height + 2.0);
        NSMutableParagraphStyle *unreadParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [unreadParagraph setAlignment:NSCenterTextAlignment];
        NSMutableDictionary *centeredUnreadAttributes = [NSMutableDictionary dictionaryWithDictionary:unreadAttributes];
        [centeredUnreadAttributes setObject:unreadParagraph forKey:NSParagraphStyleAttributeName];
        [unreadString drawInRect:unreadTextRect withAttributes:centeredUnreadAttributes];
    }
}

- (void)dealloc {
    [_chatItem release];
    [super dealloc];
}

@end

@implementation TGPanelView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect panelBounds = NSInsetRect(bounds, 1.0, 1.0);
    NSBezierPath *panelPath = [NSBezierPath bezierPathWithRoundedRect:panelBounds
                                                             xRadius:TGPanelCornerRadius
                                                             yRadius:TGPanelCornerRadius];

    TGThemeDrawPanelBackgroundInPath(panelPath, panelBounds, [self isFlipped]);

    [NSGraphicsContext saveGraphicsState];
    [panelPath addClip];
    NSRect headerRect = NSMakeRect(NSMinX(panelBounds),
                                   NSMaxY(panelBounds) - TGPanelHeaderHeight,
                                   NSWidth(panelBounds),
                                   TGPanelHeaderHeight);
    TGThemeDrawHeaderBackgroundInRect(headerRect, [self isFlipped]);
    [TGClassicHeaderSeparatorColor() set];
    NSRectFill(NSMakeRect(NSMinX(headerRect), NSMinY(headerRect), NSWidth(headerRect), 1.0));
    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(panelBounds, 1.0, 1.0)
                                                               xRadius:(TGPanelCornerRadius - 1.0)
                                                               yRadius:(TGPanelCornerRadius - 1.0)];
    [TGClassicPanelStrokeColor() set];
    [innerPath setLineWidth:1.0];
    [innerPath stroke];
}

@end

@implementation TGScrollSurfaceView

@synthesize drawsInterior = _drawsInterior;

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _drawsInterior = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect surfaceRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *surfacePath = [NSBezierPath bezierPathWithRoundedRect:surfaceRect
                                                                xRadius:8.0
                                                                yRadius:8.0];
    if (self.drawsInterior) {
        TGThemeDrawRecessedBackgroundInPath(surfacePath, surfaceRect, [self isFlipped]);
    }
    [TGClassicTableGridColor() set];
    [surfacePath setLineWidth:1.0];
    [surfacePath stroke];
}

@end

@implementation TGComposerInputBackgroundView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect inputRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *inputPath = [NSBezierPath bezierPathWithRoundedRect:inputRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawRecessedBackgroundInPath(inputPath, inputRect, [self isFlipped]);
    [TGClassicTableGridColor() set];
    [inputPath setLineWidth:1.0];
    [inputPath stroke];
}

@end

@implementation TGAuthInputBackgroundView

@synthesize errorState = _errorState;

- (void)setErrorState:(BOOL)errorState {
    if (_errorState == errorState) {
        return;
    }
    _errorState = errorState;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect inputRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *inputPath = [NSBezierPath bezierPathWithRoundedRect:inputRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawRecessedBackgroundInPath(inputPath, inputRect, [self isFlipped]);
    NSColor *strokeColor = self.errorState ? [NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0] : TGClassicTableGridColor();
    [strokeColor set];
    [inputPath setLineWidth:(self.errorState ? 1.4 : 1.0)];
    [inputPath stroke];
}

@end

@implementation TGGroupedCardView

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSRect cardRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect
                                                             xRadius:14.0
                                                             yRadius:14.0];
    TGThemeDrawGroupedCardInPath(cardPath, cardRect, [self isFlipped]);
    [[NSColor colorWithCalibratedWhite:0.78 alpha:0.62] set];
    [cardPath setLineWidth:1.0];
    [cardPath stroke];
}

@end

@implementation TGFlippedDocumentView

- (BOOL)isFlipped {
    return YES;
}

@end

@implementation TGMediaPreviewScrollView

@synthesize magnificationTarget = _magnificationTarget;

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)magnifyWithEvent:(NSEvent *)event {
    if (self.magnificationTarget) {
        [self.magnificationTarget mediaPreviewView:self didMagnifyBy:[NSNumber numberWithDouble:[event magnification]]];
        return;
    }
    [super magnifyWithEvent:event];
}

@end

@implementation TGMediaPreviewImageView

@synthesize magnificationTarget = _magnificationTarget;

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)magnifyWithEvent:(NSEvent *)event {
    if (self.magnificationTarget) {
        [self.magnificationTarget mediaPreviewView:self didMagnifyBy:[NSNumber numberWithDouble:[event magnification]]];
        return;
    }
    [super magnifyWithEvent:event];
}

@end

@implementation TGMessageBubbleCell

@synthesize messageItem = _messageItem;
@synthesize showSenderDetails = _showSenderDetails;

- (id)copyWithZone:(NSZone *)zone {
    TGMessageBubbleCell *cell = [super copyWithZone:zone];
    cell->_messageItem = nil;
    [cell setMessageItem:self.messageItem];
    [cell setShowSenderDetails:self.showSenderDetails];
    return cell;
}

- (void)setObjectValue:(id)value {
    if ([value isKindOfClass:[TGMessageItem class]]) {
        self.messageItem = (TGMessageItem *)value;
        [super setObjectValue:@""];
        return;
    }
    self.messageItem = nil;
    [super setObjectValue:(value ? value : @"")];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    TGMessageItem *item = self.messageItem;
    if (!item) {
        id value = [self objectValue];
        if ([value isKindOfClass:[TGMessageItem class]]) {
            item = (TGMessageItem *)value;
        }
    }
    if (!item) {
        [super drawWithFrame:cellFrame inView:controlView];
        return;
    }

    if (TGChatMessagesAsBlocksEnabled()) {
        [self drawListMessageItem:item withFrame:cellFrame inView:controlView];
        return;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = self.showSenderDetails;
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    BOOL nonVisualDocument = TGMessageItemIsNonVisualDocument(item);
    NSString *rawMessageText = TGDisplayTextForMessageItem(item);
    NSString *messageText = ([item isStickerMessage] || TGMessageItemIsNonVisualPlayableMedia(item) || nonVisualDocument) ? @"" : rawMessageText;
    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageBodyFont(), NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageMetaFont(), NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
            NSString *statusDots = TGOutgoingStatusDotsInlineTextForItem(item);
            if ([statusDots length] > 0) {
                NSMutableDictionary *statusAttributes = [NSMutableDictionary dictionaryWithDictionary:timeAttributes];
                [statusAttributes setObject:TGChatMessageBoldBodyFont() forKey:NSFontAttributeName];
                [statusAttributes setObject:[NSColor colorWithCalibratedWhite:0.470 alpha:0.78] forKey:NSForegroundColorAttributeName];
                NSString *statusSuffix = [NSString stringWithFormat:@" %@", statusDots];
                NSAttributedString *statusSuffixText = [[[NSAttributedString alloc] initWithString:statusSuffix attributes:statusAttributes] autorelease];
                [composedMessageText appendAttributedString:statusSuffixText];
            }
        }
    }
    NSAttributedString *attributedMessageText = composedMessageText;
    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [attributedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 12000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
    }
    NSSize photoSize = NSZeroSize;
    BOOL nonVisualPlayable = TGMessageItemIsNonVisualPlayableMedia(item);
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }
    CGFloat mediaFooterHeight = TGMessageMediaFooterHeightForItem(item);

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (nonVisualPlayable) {
        bubbleWidth = TGPlayableMediaBubbleWidthForItem(item, maximumBubbleWidth);
    }
    if (nonVisualDocument) {
        bubbleWidth = TGDocumentBubbleWidthForItem(item, maximumBubbleWidth);
    }
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }
    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat contextHeaderHeight = TGMessageContextHeaderHeightForItem(item);
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0 + senderHeaderHeight + contextHeaderHeight;
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0 + mediaFooterHeight + senderHeaderHeight + contextHeaderHeight;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (nonVisualPlayable) {
        bubbleHeight = TGPlayableMediaBubbleHeightForItem(item) + senderHeaderHeight + contextHeaderHeight;
    }
    if (nonVisualDocument) {
        bubbleHeight = TGDocumentBubbleHeightForItem(item) + senderHeaderHeight + contextHeaderHeight;
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    CGFloat reactionBandHeight = TGReactionBandHeightForMessageItem(item);
    if (!nonVisualPlayable && !nonVisualDocument) {
        bubbleHeight += reactionBandHeight;
    }
    CGFloat commentBarHeight = TGMessageCommentBarHeightForItem(item);
    bubbleHeight += commentBarHeight;

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    CGFloat blockOffset = floor(TGMessageExtraBlockVerticalPadding() / 2.0);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0 + blockOffset, bubbleWidth, bubbleHeight);
    if (TGChatMessagesAsBlocksEnabled()) {
        NSRect blockRect = NSInsetRect(bubbleRect, -5.0, -4.0);
        NSBezierPath *blockPath = [NSBezierPath bezierPathWithRoundedRect:blockRect xRadius:15.0 yRadius:15.0];
        NSColor *blockColor = outgoing ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor();
        [[blockColor colorWithAlphaComponent:0.44] set];
        [blockPath fill];
        [TGClassicPanelStrokeColor() set];
        [blockPath setLineWidth:0.7];
        [blockPath stroke];
    }
    NSBezierPath *bubblePath = [NSBezierPath bezierPathWithRoundedRect:bubbleRect xRadius:13.0 yRadius:13.0];

    TGThemeDrawMessageBubbleInPath(bubblePath, bubbleRect, outgoing, [controlView isFlipped]);

    NSColor *strokeColor = outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor();
    [strokeColor set];
    [bubblePath setLineWidth:1.0];
    [bubblePath stroke];

    if ([item isPinned]) {
        NSRect pinRect = NSMakeRect(NSMinX(bubbleRect) + 9.0,
                                    [controlView isFlipped] ? (NSMinY(bubbleRect) + 7.0) : (NSMaxY(bubbleRect) - 20.0),
                                    12.0,
                                    12.0);
        TGDrawTemplateIconAsset(@"flag-triangle",
                                pinRect,
                                TGClassicNavigationSelectedColor(0.82),
                                0.92,
                                [controlView isFlipped]);
    }

    if (showSenderDetails && !outgoing) {
        NSRect avatarRect = NSMakeRect(NSMinX(cellFrame) + sidePadding,
                                       NSMaxY(bubbleRect) - 25.0,
                                       24.0,
                                       24.0);
        TGDrawAvatarInRect([item senderAvatarLocalPath], [item senderDisplayName], avatarRect, NO, [controlView isFlipped]);
    }

    BOOL flipped = [controlView isFlipped];
    CGFloat contentTop = flipped ? (NSMinY(bubbleRect) + 9.0) : (NSMaxY(bubbleRect) - 9.0);
    if (senderHeaderHeight > 0.0) {
        NSString *senderName = [item senderDisplayName];
        NSDictionary *senderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TGChatMessageBoldSecondaryFont(), NSFontAttributeName,
                                          TGClassicNavigationSelectedColor(0.90), NSForegroundColorAttributeName,
                                          nil];
        NSRect senderRect = flipped ? NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                                 contentTop,
                                                 NSWidth(bubbleRect) - 24.0,
                                                 14.0)
                                    : NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                                 contentTop - 13.0,
                                                 NSWidth(bubbleRect) - 24.0,
                                                 14.0);
        [senderName drawInRect:senderRect withAttributes:senderAttributes];
        contentTop += flipped ? senderHeaderHeight : -senderHeaderHeight;
    }

    if (contextHeaderHeight > 0.0) {
        NSString *contextTitle = nil;
        NSString *contextSubtitle = nil;
        if ([[item forwardSourceDisplayName] length] > 0) {
            contextTitle = [NSString stringWithFormat:@"Forwarded from %@", [item forwardSourceDisplayName]];
            contextSubtitle = TGDisplayTextForMessageItem(item);
        } else {
            contextTitle = ([[item replySenderDisplayName] length] > 0) ? [item replySenderDisplayName] : @"Reply";
            contextSubtitle = ([[item replyPreview] length] > 0) ? [item replyPreview] : @"Original message";
        }
        if ([contextSubtitle length] == 0) {
            contextSubtitle = @"Media";
        }
        NSRect contextRect = flipped ? NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                                  contentTop + 1.0,
                                                  NSWidth(bubbleRect) - 24.0,
                                                  contextHeaderHeight - 5.0)
                                     : NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                                  contentTop - contextHeaderHeight + 4.0,
                                                  NSWidth(bubbleRect) - 24.0,
                                                  contextHeaderHeight - 5.0);
        NSBezierPath *linePath = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(NSMinX(contextRect),
                                                                                    NSMinY(contextRect) + 2.0,
                                                                                    3.0,
                                                                                    NSHeight(contextRect) - 4.0)
                                                                 xRadius:1.5
                                                                 yRadius:1.5];
        [TGClassicNavigationSelectedColor(0.88) set];
        [linePath fill];

        NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         TGChatMessageBoldSecondaryFont(), NSFontAttributeName,
                                         TGClassicNavigationSelectedColor(0.95), NSForegroundColorAttributeName,
                                         nil];
        NSDictionary *subtitleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            TGChatMessageSecondaryFont(), NSFontAttributeName,
                                            TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                            nil];
        NSRect titleRect = NSMakeRect(NSMinX(contextRect) + 8.0,
                                      NSMinY(contextRect),
                                      NSWidth(contextRect) - 8.0,
                                      13.0);
        NSRect subtitleRect = NSMakeRect(NSMinX(contextRect) + 8.0,
                                         NSMinY(contextRect) + 13.0,
                                         NSWidth(contextRect) - 8.0,
                                         13.0);
        [contextTitle drawInRect:titleRect withAttributes:titleAttributes];
        [contextSubtitle drawInRect:subtitleRect withAttributes:subtitleAttributes];
        contentTop += flipped ? contextHeaderHeight : -contextHeaderHeight;
    }

    if (nonVisualPlayable) {
        NSRect playableRect = bubbleRect;
        if (senderHeaderHeight > 0.0) {
            if (flipped) {
                playableRect.origin.y += senderHeaderHeight;
            }
            playableRect.size.height -= senderHeaderHeight;
        }
        if (contextHeaderHeight > 0.0) {
            if (flipped) {
                playableRect.origin.y += contextHeaderHeight;
            }
            playableRect.size.height -= contextHeaderHeight;
        }
        if (commentBarHeight > 0.0) {
            playableRect.size.height -= commentBarHeight;
        }
        TGDrawPlayableMediaContentForItem(item, playableRect, flipped);
    }

    if (nonVisualDocument) {
        NSRect documentRect = bubbleRect;
        if (senderHeaderHeight > 0.0) {
            if (flipped) {
                documentRect.origin.y += senderHeaderHeight;
            }
            documentRect.size.height -= senderHeaderHeight;
        }
        if (contextHeaderHeight > 0.0) {
            if (flipped) {
                documentRect.origin.y += contextHeaderHeight;
            }
            documentRect.size.height -= contextHeaderHeight;
        }
        if (commentBarHeight > 0.0) {
            documentRect.size.height -= commentBarHeight;
        }
        TGDrawDocumentContentForItem(item, documentRect, outgoing, flipped);
    }

    if (!flipped && reactionBandHeight > 0.0) {
        contentTop -= reactionBandHeight;
    }
    if (!flipped && visualMediaMessage && [messageText length] == 0 && mediaFooterHeight > 0.0) {
        contentTop -= mediaFooterHeight;
    }
    if (visualMediaMessage) {
        NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                      flipped ? contentTop : (contentTop - photoSize.height),
                                      photoSize.width,
                                      photoSize.height);
        NSArray *mediaItems = [item visualMediaItems];
        NSArray *tileRects = TGMediaTileRectsForMessageItem(item, imageRect);
        NSUInteger tileCount = [tileRects count];
        NSUInteger mediaCount = [mediaItems count];
        if (mediaCount > 0 && tileCount > 0) {
            NSUInteger tileIndex = 0;
            for (tileIndex = 0; tileIndex < tileCount && tileIndex < mediaCount; tileIndex++) {
                id mediaObject = [mediaItems objectAtIndex:tileIndex];
                if (![mediaObject isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSUInteger overflowCount = 0;
                if (tileIndex == tileCount - 1 && mediaCount > tileCount) {
                    overflowCount = mediaCount - tileCount;
                }
                NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
                tileRect = TGStickerAdjustedMediaRect((NSDictionary *)mediaObject, tileRect, [controlView isFlipped]);
                TGDrawMediaItemInRect((NSDictionary *)mediaObject, tileRect, outgoing, [controlView isFlipped], mediaCount > 1, overflowCount);
            }
        } else {
            NSBezierPath *imagePath = [NSBezierPath bezierPathWithRoundedRect:imageRect xRadius:9.0 yRadius:9.0];
            [(outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor()) set];
            [imagePath setLineWidth:1.0];
            [imagePath stroke];
            NSDictionary *placeholderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                   TGChatMessageBoldBodyFont(), NSFontAttributeName,
                                                   TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                                   nil];
            NSString *placeholder = [item visualMediaPlaceholderTitle];
            NSSize placeholderSize = [placeholder sizeWithAttributes:placeholderAttributes];
            NSRect placeholderRect = NSMakeRect(NSMidX(imageRect) - floor(placeholderSize.width / 2.0),
                                                NSMidY(imageRect) - floor(placeholderSize.height / 2.0),
                                                placeholderSize.width,
                                                placeholderSize.height);
            [placeholder drawInRect:placeholderRect withAttributes:placeholderAttributes];
        }
        contentTop = flipped ? (NSMaxY(imageRect) + 8.0) : (NSMinY(imageRect) - 8.0);
    }

    if ([messageText length] > 0) {
        CGFloat textHeight = ceil(NSHeight(measuredRect));
        NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                     flipped ? contentTop : (contentTop - textHeight),
                                     NSWidth(bubbleRect) - 24.0,
                                     textHeight + 2.0);
        [attributedMessageText drawWithRect:textRect
                                    options:NSStringDrawingUsesLineFragmentOrigin];
    }

    TGDrawMessageCommentBarForItem(item, bubbleRect, outgoing, flipped);

    if ([timeString length] > 0 && [messageText length] == 0 && !nonVisualPlayable) {
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        CGFloat statusWidth = TGOutgoingStatusDotsWidthForItem(item);
        CGFloat statusGap = (statusWidth > 0.0) ? 5.0 : 0.0;
        CGFloat timeY = [controlView isFlipped] ? (NSMaxY(bubbleRect) - reactionBandHeight - 14.0)
                                                : (NSMinY(bubbleRect) + 4.0 + reactionBandHeight);
        NSRect timeRect = NSMakeRect(NSMaxX(bubbleRect) - timeSize.width - statusWidth - statusGap - 12.0,
                                     timeY,
                                     timeSize.width,
                                     10.0);
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
        TGDrawOutgoingStatusDotsForItem(item, timeRect, [controlView isFlipped]);
    }

    NSString *reactionSummary = [item reactionSummary];
    if ([reactionSummary length] > 0) {
        NSDictionary *reactionAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                            TGClassicSelectedRowTextColor(), NSForegroundColorAttributeName,
                                            nil];
        NSSize reactionSize = [reactionSummary sizeWithAttributes:reactionAttributes];
        CGFloat reactionWidth = ceil(reactionSize.width) + 14.0;
        CGFloat maximumReactionWidth = NSWidth(bubbleRect) - 24.0;
        if (reactionWidth > maximumReactionWidth) {
            reactionWidth = maximumReactionWidth;
        }
        if (reactionWidth > 20.0) {
            CGFloat reactionHeight = 18.0;
            CGFloat reactionY = [controlView isFlipped] ? (NSMaxY(bubbleRect) - reactionHeight - 4.0)
                                                        : (NSMinY(bubbleRect) + 4.0);
            NSRect reactionRect = NSMakeRect(NSMinX(bubbleRect) + 10.0,
                                             reactionY,
                                             reactionWidth,
                                             reactionHeight);
            NSBezierPath *reactionPath = [NSBezierPath bezierPathWithRoundedRect:reactionRect xRadius:9.0 yRadius:9.0];
            [TGClassicNavigationSelectedColor(0.82) set];
            [reactionPath fill];
            [TGClassicNavigationSelectedStrokeColor(0.72) set];
            [reactionPath setLineWidth:1.0];
            [reactionPath stroke];

            NSMutableParagraphStyle *reactionParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
            [reactionParagraph setAlignment:NSCenterTextAlignment];
            NSMutableDictionary *centeredAttributes = [NSMutableDictionary dictionaryWithDictionary:reactionAttributes];
            [centeredAttributes setObject:reactionParagraph forKey:NSParagraphStyleAttributeName];
            NSRect reactionTextRect = NSMakeRect(NSMinX(reactionRect) + 4.0,
                                                 NSMinY(reactionRect) + floor((reactionHeight - reactionSize.height) / 2.0) - 1.0,
                                                 NSWidth(reactionRect) - 8.0,
                                                 reactionSize.height + 3.0);
            [reactionSummary drawInRect:reactionTextRect withAttributes:centeredAttributes];
        }
    }
}

- (void)drawListMessageItem:(TGMessageItem *)item withFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL outgoing = [item outgoing];
    BOOL flipped = [controlView isFlipped];
    NSRect rowRect = NSInsetRect(cellFrame, 6.0, 2.0);
    NSBezierPath *rowPath = [NSBezierPath bezierPathWithRoundedRect:rowRect xRadius:7.0 yRadius:7.0];
    NSColor *rowColor = outgoing ? TGClassicOutgoingBubbleBottomColor() : TGClassicIncomingBubbleBottomColor();
    [[rowColor colorWithAlphaComponent:(outgoing ? 0.50 : 0.62)] set];
    [rowPath fill];
    [TGClassicTableGridColor() set];
    [rowPath setLineWidth:0.8];
    [rowPath stroke];

    NSRect accentRect = NSMakeRect(NSMinX(rowRect), NSMinY(rowRect) + 1.0, 3.0, NSHeight(rowRect) - 2.0);
    NSBezierPath *accentPath = [NSBezierPath bezierPathWithRoundedRect:accentRect xRadius:1.5 yRadius:1.5];
    [(outgoing ? TGClassicNavigationSelectedColor(0.82) : TGClassicMutedInkColor()) set];
    [accentPath fill];

    CGFloat left = NSMinX(rowRect) + 12.0;
    CGFloat top = flipped ? (NSMinY(rowRect) + 7.0) : (NSMaxY(rowRect) - 7.0);
    CGFloat iconSide = 28.0;
    NSRect iconRect = NSMakeRect(left,
                                 NSMinY(rowRect) + floor((NSHeight(rowRect) - iconSide) / 2.0),
                                 iconSide,
                                 iconSide);
    BOOL drewMediaIcon = NO;
    if ([item isVisualMediaMessage]) {
        NSArray *mediaItems = [item visualMediaItems];
        NSDictionary *mediaItem = ([mediaItems count] > 0 && [[mediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) ? [mediaItems objectAtIndex:0] : nil;
        if (mediaItem) {
            TGDrawMediaItemInRect(mediaItem, iconRect, outgoing, flipped, YES, 0);
            drewMediaIcon = YES;
        }
    }
    if (!drewMediaIcon) {
        if (TGMessageItemIsNonVisualPlayableMedia(item)) {
            NSBezierPath *mediaCircle = [NSBezierPath bezierPathWithOvalInRect:iconRect];
            [TGClassicNavigationSelectedColor(0.86) set];
            [mediaCircle fill];
            TGDrawTemplateIconAsset(@"play", NSInsetRect(iconRect, 8.0, 8.0), [NSColor whiteColor], 0.95, flipped);
        } else if (TGMessageItemIsNonVisualDocument(item)) {
            NSBezierPath *mediaCircle = [NSBezierPath bezierPathWithOvalInRect:iconRect];
            [[NSColor colorWithCalibratedRed:0.05 green:0.67 blue:0.17 alpha:1.0] set];
            [mediaCircle fill];
            TGDrawTemplateIconAsset(@"document", NSInsetRect(iconRect, 7.0, 7.0), [NSColor whiteColor], 0.92, flipped);
        } else if (self.showSenderDetails && !outgoing) {
            TGDrawAvatarInRect([item senderAvatarLocalPath], [item senderDisplayName], iconRect, NO, flipped);
        } else {
            NSBezierPath *dotPath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(iconRect, 7.0, 7.0)];
            [(outgoing ? TGClassicNavigationSelectedColor(0.80) : TGClassicMutedInkColor()) set];
            [dotPath fill];
        }
    }

    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageMetaFont(), NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
    CGFloat statusWidth = TGOutgoingStatusDotsWidthForItem(item);
    CGFloat statusGap = (statusWidth > 0.0) ? 5.0 : 0.0;
    CGFloat timeRightPadding = 12.0;
    NSRect timeRect = NSMakeRect(NSMaxX(rowRect) - timeRightPadding - timeSize.width - statusWidth - statusGap,
                                 flipped ? (NSMinY(rowRect) + 8.0) : (NSMaxY(rowRect) - 18.0),
                                 timeSize.width,
                                 12.0);
    if ([timeString length] > 0) {
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
        TGDrawOutgoingStatusDotsForItem(item, timeRect, flipped);
    }

    CGFloat textX = NSMaxX(iconRect) + 10.0;
    CGFloat textRight = NSMinX(timeRect) - 10.0;
    if ([timeString length] == 0) {
        textRight = NSMaxX(rowRect) - 12.0;
    }
    CGFloat textWidth = textRight - textX;
    if (textWidth < 120.0) {
        textWidth = MAX(120.0, NSMaxX(rowRect) - textX - 12.0);
    }

    NSString *senderTitle = nil;
    if (self.showSenderDetails && [[item senderDisplayName] length] > 0 && !outgoing) {
        senderTitle = [item senderDisplayName];
    } else if (outgoing) {
        senderTitle = TGLoc(@"message.you");
        if ([senderTitle isEqualToString:@"message.you"]) {
            senderTitle = @"You";
        }
    }
    CGFloat textY = top;
    if ([senderTitle length] > 0) {
        NSDictionary *senderAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TGChatMessageBoldSecondaryFont(), NSFontAttributeName,
                                          TGClassicNavigationSelectedColor(0.92), NSForegroundColorAttributeName,
                                          nil];
        NSRect senderRect = NSMakeRect(textX,
                                       flipped ? textY : (textY - 14.0),
                                       textWidth,
                                       14.0);
        [senderTitle drawInRect:senderRect withAttributes:senderAttributes];
        textY += flipped ? 15.0 : -15.0;
    }

    CGFloat contextHeight = TGMessageContextHeaderHeightForItem(item);
    if (contextHeight > 0.0) {
        NSString *contextTitle = ([[item forwardSourceDisplayName] length] > 0) ? [NSString stringWithFormat:@"Forwarded from %@", [item forwardSourceDisplayName]] : (([[item replySenderDisplayName] length] > 0) ? [item replySenderDisplayName] : @"Reply");
        NSDictionary *contextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           TGChatMessageSecondaryFont(), NSFontAttributeName,
                                           TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                           nil];
        NSRect contextRect = NSMakeRect(textX,
                                        flipped ? textY : (textY - 14.0),
                                        textWidth,
                                        14.0);
        [contextTitle drawInRect:contextRect withAttributes:contextAttributes];
        textY += flipped ? 15.0 : -15.0;
    }

    NSString *messageText = TGDisplayTextForMessageItem(item);
    if ([messageText length] == 0) {
        if ([item isVisualMediaMessage]) {
            messageText = [item visualMediaPlaceholderTitle];
        } else if (TGMessageItemIsNonVisualPlayableMedia(item)) {
            messageText = TGPlayableMediaTitleForMessageItem(item);
        } else if (TGMessageItemIsNonVisualDocument(item)) {
            messageText = @"Document";
        }
    }
    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageBodyFont(), NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSAttributedString *attributedText = TGAttributedMessageString(messageText, textAttributes);
    NSRect measuredRect = [attributedText boundingRectWithSize:NSMakeSize(textWidth, 12000.0)
                                                       options:NSStringDrawingUsesLineFragmentOrigin];
    CGFloat textHeight = MAX(15.0, ceil(NSHeight(measuredRect)));
    NSRect textRect = NSMakeRect(textX,
                                 flipped ? textY : (textY - textHeight),
                                 textWidth,
                                 textHeight + 2.0);
    [attributedText drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];

    CGFloat footerY = flipped ? (NSMaxY(textRect) + 4.0) : (NSMinY(textRect) - 20.0);
    NSString *reactionSummary = [item reactionSummary];
    NSString *commentTitle = nil;
    if (TGMessageItemHasCommentThread(item)) {
        NSInteger replyCount = ([[item messageThreadReplyCount] respondsToSelector:@selector(integerValue)] ? [[item messageThreadReplyCount] integerValue] : 0);
        commentTitle = (replyCount > 0) ? [NSString stringWithFormat:TGLoc(replyCount == 1 ? @"message.comments.count.one" : @"message.comments.count.many"), (long)replyCount] : TGLoc(@"message.comments.add");
    }
    if ([reactionSummary length] > 0 || [commentTitle length] > 0) {
        NSString *footer = ([reactionSummary length] > 0 && [commentTitle length] > 0) ? [NSString stringWithFormat:@"%@    %@", reactionSummary, commentTitle] : (([reactionSummary length] > 0) ? reactionSummary : commentTitle);
        NSDictionary *footerAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          TGChatMessageBoldSecondaryFont(), NSFontAttributeName,
                                          TGClassicNavigationSelectedColor(0.92), NSForegroundColorAttributeName,
                                          nil];
        [footer drawInRect:NSMakeRect(textX, footerY, textWidth, 16.0) withAttributes:footerAttributes];
    }
}

- (void)dealloc {
    [_messageItem release];
    [super dealloc];
}

@end
