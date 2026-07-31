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

static NSFont *TGReactionDisplayFont(void) {
    static NSFont *reactionFont = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reactionFont = [[NSFont fontWithName:@"Apple Color Emoji" size:14.0] retain];
        if (!reactionFont) {
            reactionFont = [[NSFont boldSystemFontOfSize:11.0] retain];
        }
    });
    return reactionFont;
}

@implementation TGRepresentedObjectCell

@synthesize representedObject = _representedObject;

- (id)copyWithZone:(NSZone *)zone {
    TGRepresentedObjectCell *cell = [super copyWithZone:zone];
    cell->_representedObject = nil;
    [cell setRepresentedObject:self.representedObject];
    return cell;
}

- (void)setObjectValue:(id)value {
    self.representedObject = value;
    [super setObjectValue:@""];
}

- (void)dealloc {
    [_representedObject release];
    [super dealloc];
}

@end

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

    BOOL compact = (NSWidth(cellFrame) < 223.0);
    CGFloat avatarSide = compact ? 32.0 : 26.0;
    NSRect avatarRect = NSMakeRect(compact ? (NSMidX(cellFrame) - floor(avatarSide / 2.0)) : (NSMinX(cellFrame) + 8.0),
                                   NSMinY(cellFrame) + floor((NSHeight(cellFrame) - avatarSide) / 2.0),
                                   avatarSide,
                                   avatarSide);
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
    BOOL drawsMarkedUnreadDot = ([item isMarkedAsUnread] && unreadCount == 0);

    NSColor *unreadTextColor = selected ? TGClassicSelectedRowColor() : TGClassicNavigationTextColor(1.0);
    NSDictionary *unreadAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                      unreadTextColor, NSForegroundColorAttributeName,
                                      nil];
    if (compact) {
        if ([unreadString length] > 0) {
            NSString *compactUnread = unreadCount > 99 ? @"99+" : unreadString;
            NSSize compactUnreadSize = [compactUnread sizeWithAttributes:unreadAttributes];
            CGFloat compactBadgeWidth = MAX(17.0, compactUnreadSize.width + 8.0);
            NSRect compactBadgeRect = NSMakeRect(NSMaxX(avatarRect) - compactBadgeWidth + 4.0,
                                                 NSMaxY(avatarRect) - 15.0,
                                                 compactBadgeWidth,
                                                 16.0);
            NSBezierPath *compactBadgePath = [NSBezierPath bezierPathWithRoundedRect:compactBadgeRect
                                                                            xRadius:8.0
                                                                            yRadius:8.0];
            [TGClassicHeaderBottomColor() set];
            [compactBadgePath fill];
            NSMutableParagraphStyle *compactParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
            [compactParagraph setAlignment:NSCenterTextAlignment];
            NSMutableDictionary *compactAttributes = [NSMutableDictionary dictionaryWithDictionary:unreadAttributes];
            [compactAttributes setObject:compactParagraph forKey:NSParagraphStyleAttributeName];
            [compactUnread drawInRect:NSMakeRect(NSMinX(compactBadgeRect),
                                                 NSMinY(compactBadgeRect) + 1.0,
                                                 NSWidth(compactBadgeRect),
                                                 14.0)
                       withAttributes:compactAttributes];
        } else if (drawsMarkedUnreadDot) {
            NSRect compactDotRect = NSMakeRect(NSMaxX(avatarRect) - 7.0,
                                               NSMaxY(avatarRect) - 7.0,
                                               10.0,
                                               10.0);
            NSBezierPath *compactDotPath = [NSBezierPath bezierPathWithOvalInRect:compactDotRect];
            NSColor *manualUnreadColor = selected ? TGClassicSelectedRowTextColor() : TGColorFromHex(0x2D8BD4);
            [manualUnreadColor set];
            [compactDotPath fill];
        }
        return;
    }
    NSSize unreadSize = [unreadString sizeWithAttributes:unreadAttributes];
    CGFloat unreadWidth = ([unreadString length] > 0) ? MAX(unreadSize.width + 13.0, 20.0) : (drawsMarkedUnreadDot ? 10.0 : 0.0);
    CGFloat unreadHeight = ([unreadString length] > 0) ? 18.0 : (drawsMarkedUnreadDot ? 10.0 : 0.0);
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
    CGFloat titleRight = ([unreadString length] > 0 || drawsMarkedUnreadDot) ? (NSMinX(unreadRect) - 12.0) : (NSMaxX(cellFrame) - 9.0);
    CGFloat muteIconWidth = [item notificationsMuted] ? 15.0 : 0.0;
    CGFloat pinIconWidth = [item isPinned] ? 12.0 : 0.0;
    CGFloat botIconWidth = [item isBot] ? 15.0 : 0.0;
    NSString *communityBadge = [item isCommunity] ? TGLoc(@"chat.community.badge") : @"";
    NSDictionary *communityAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                         [NSFont boldSystemFontOfSize:8.0], NSFontAttributeName,
                                         selected ? TGClassicSelectedRowTextColor() : TGClassicLinkColor(), NSForegroundColorAttributeName,
                                         nil];
    CGFloat communityBadgeWidth = [communityBadge length] > 0
        ? MIN(64.0, [communityBadge sizeWithAttributes:communityAttributes].width + 12.0) : 0.0;
    CGFloat trailingIconWidth = ([item notificationsMuted] ? (muteIconWidth + 5.0) : 0.0) +
                                ([item isPinned] ? (pinIconWidth + 4.0) : 0.0) +
                                ([item isBot] ? (botIconWidth + 4.0) : 0.0) +
                                (communityBadgeWidth > 0.0 ? (communityBadgeWidth + 4.0) : 0.0);
    CGFloat titleAvailableWidth = titleRight - titleX - trailingIconWidth;
    if (titleAvailableWidth < 40.0) {
        titleAvailableWidth = 40.0;
    }
    NSRect titleRect = NSMakeRect(titleX,
                                  NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                  titleAvailableWidth,
                                  16.0);
    [displayTitle drawInRect:titleRect withAttributes:titleAttributes];
    CGFloat iconX = titleRight - trailingIconWidth;
    if (communityBadgeWidth > 0.0) {
        NSRect badgeRect = NSMakeRect(iconX,
                                     NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 16.0) / 2.0),
                                     communityBadgeWidth,
                                     16.0);
        NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:8.0 yRadius:8.0];
        [TGClassicNavigationHighlightedColor(selected ? 0.34 : 0.16) set];
        [badgePath fill];
        NSMutableParagraphStyle *badgeStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [badgeStyle setAlignment:NSCenterTextAlignment];
        NSMutableDictionary *badgeAttributes = [NSMutableDictionary dictionaryWithDictionary:communityAttributes];
        [badgeAttributes setObject:badgeStyle forKey:NSParagraphStyleAttributeName];
        [communityBadge drawInRect:NSMakeRect(NSMinX(badgeRect), NSMinY(badgeRect) + 3.0,
                                              NSWidth(badgeRect), 11.0)
                    withAttributes:badgeAttributes];
        iconX = NSMaxX(badgeRect) + 4.0;
    }
    if ([item isBot]) {
        NSRect botRect = NSMakeRect(iconX,
                                    NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                    15.0,
                                    15.0);
        NSColor *botColor = selected ? TGClassicSelectedRowTextColor() : [TGClassicLinkColor() colorWithAlphaComponent:0.9];
        TGDrawTemplateIconAsset(@"robot", botRect, botColor, 1.0, [controlView isFlipped]);
        iconX = NSMaxX(botRect) + 4.0;
    }
    if ([item isPinned]) {
        NSRect pinRect = NSMakeRect(iconX,
                                    NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 12.0) / 2.0),
                                    12.0,
                                    12.0);
        NSColor *pinColor = selected ? TGClassicSelectedRowTextColor() : [TGClassicInkColor() colorWithAlphaComponent:0.72];
        TGDrawTemplateIconAsset(@"flag-triangle", pinRect, pinColor, 0.9, [controlView isFlipped]);
        iconX = NSMaxX(pinRect) + 4.0;
    }
    if ([item notificationsMuted]) {
        NSRect muteRect = NSMakeRect(iconX,
                                     NSMinY(cellFrame) + floor((NSHeight(cellFrame) - 15.0) / 2.0),
                                     15.0,
                                     15.0);
        NSColor *muteColor = selected ? TGClassicSelectedRowTextColor() : [TGClassicInkColor() colorWithAlphaComponent:0.78];
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
    } else if (drawsMarkedUnreadDot) {
        NSBezierPath *unreadDotPath = [NSBezierPath bezierPathWithOvalInRect:unreadRect];
        NSColor *unreadFillColor = selected ? TGClassicSelectedRowTextColor() : TGColorFromHex(0x2D8BD4);
        [unreadFillColor set];
        [unreadDotPath fill];
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
    NSRect cardRect = NSInsetRect(bounds, 0.5, 0.5);
    NSBezierPath *cardPath = [NSBezierPath bezierPathWithRoundedRect:cardRect
                                                             xRadius:14.0
                                                             yRadius:14.0];
    if (self.drawsInterior) {
        TGThemeDrawGroupedCardInPath(cardPath, cardRect, [self isFlipped]);
        [TGClassicTableGridColor() set];
        [cardPath setLineWidth:1.0];
        [cardPath stroke];
    }
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

static void TGDrawMessageTopAccessories(TGMessageItem *item,
                                        NSRect cellFrame,
                                        BOOL flipped) {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    CGFloat currentY = NSMinY(cellFrame) + 3.0;
    NSString *dateTitle = [item dateSeparatorTitle];
    if ([dateTitle length] > 0) {
        NSDictionary *dateAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont boldSystemFontOfSize:11.5], NSFontAttributeName,
                                        TGClassicSelectedRowTextColor(), NSForegroundColorAttributeName,
                                        nil];
        NSSize titleSize = [dateTitle sizeWithAttributes:dateAttributes];
        CGFloat pillWidth = MIN(NSWidth(cellFrame) - 28.0, MAX(82.0, ceil(titleSize.width) + 24.0));
        NSRect pillRect = NSMakeRect(NSMidX(cellFrame) - floor(pillWidth / 2.0),
                                     currentY,
                                     pillWidth,
                                     23.0);
        NSBezierPath *pillPath = [NSBezierPath bezierPathWithRoundedRect:pillRect
                                                                 xRadius:11.5
                                                                 yRadius:11.5];
        [TGClassicSelectedRowColor() set];
        [pillPath fill];
        NSRect textRect = NSMakeRect(NSMinX(pillRect) + 10.0,
                                     NSMidY(pillRect) - floor(titleSize.height / 2.0) - 1.0,
                                     NSWidth(pillRect) - 20.0,
                                     titleSize.height + 2.0);
        NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [paragraph setAlignment:NSCenterTextAlignment];
        NSMutableDictionary *centeredAttributes = [NSMutableDictionary dictionaryWithDictionary:dateAttributes];
        [centeredAttributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
        [dateTitle drawInRect:textRect withAttributes:centeredAttributes];
        currentY += 30.0;
    }
    if ([item showsUnreadSeparator]) {
        NSRect separatorRect = NSMakeRect(NSMinX(cellFrame) + 14.0,
                                          currentY,
                                          MAX(40.0, NSWidth(cellFrame) - 28.0),
                                          23.0);
        NSBezierPath *separatorPath = [NSBezierPath bezierPathWithRoundedRect:separatorRect
                                                                      xRadius:11.5
                                                                      yRadius:11.5];
        TGThemeDrawGroupedCardInPath(separatorPath, separatorRect, flipped);
        [TGClassicPanelStrokeColor() set];
        [separatorPath setLineWidth:0.7];
        [separatorPath stroke];
        NSString *title = TGLoc(@"message.unreadSeparator");
        NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [paragraph setAlignment:NSCenterTextAlignment];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:11.5], NSFontAttributeName,
                                    TGClassicCardMutedInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
        [title drawInRect:NSInsetRect(separatorRect, 12.0, 3.0) withAttributes:attributes];
    }
}

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

    CGFloat topAccessoryHeight = TGMessageTopAccessoryHeightForItem(item);
    if (topAccessoryHeight > 0.0) {
        TGDrawMessageTopAccessories(item, cellFrame, [controlView isFlipped]);
    }

    if (TGChatMessagesAsBlocksEnabled()) {
        NSRect messageFrame = cellFrame;
        messageFrame.origin.y += topAccessoryHeight;
        messageFrame.size.height = MAX(1.0, messageFrame.size.height - topAccessoryHeight);
        [self drawListMessageItem:item withFrame:messageFrame inView:controlView];
        return;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = self.showSenderDetails;
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    BOOL nonVisualDocument = TGMessageItemIsNonVisualDocument(item);
    BOOL nonVisualPlayable = TGMessageItemIsNonVisualPlayableMedia(item);
    BOOL pollContent = TGMessageItemIsPollContent(item);
    BOOL callContent = TGMessageItemIsCallContent(item);
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    NSString *rawMessageText = TGDisplayTextForMessageItem(item);
    NSString *messageText = ([item isStickerMessage] || nonVisualPlayable || nonVisualDocument || pollContent || callContent) ? @"" : rawMessageText;
    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageBodyFont(), NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    BOOL separateMetadataFooter = TGMessageUsesSeparateMetadataFooter();
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageMetaFont(), NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageStringForItem(item, messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0 && !separateMetadataFooter) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
            NSAttributedString *statusSuffix = TGOutgoingStatusInlineAttributedStringForItem(item);
            if ([statusSuffix length] > 0) {
                [composedMessageText appendAttributedString:statusSuffix];
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
    if (pollContent) {
        bubbleWidth = TGPollBubbleWidthForItem(item, maximumBubbleWidth);
    }
    if (callContent) {
        bubbleWidth = TGCallBubbleWidthForItem(item, maximumBubbleWidth);
    }
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (TGMessageItemHasLinkPreview(item)) {
        CGFloat previewBubbleWidth = MIN(maximumBubbleWidth, 316.0);
        if (previewBubbleWidth > bubbleWidth) {
            bubbleWidth = previewBubbleWidth;
        }
    }
    if ([messageText length] > 0 && separateMetadataFooter && [timeString length] > 0) {
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        CGFloat footerWidth = ceil(timeSize.width) + TGOutgoingStatusDotsWidthForItem(item) + 29.0;
        if (footerWidth > bubbleWidth) {
            bubbleWidth = footerWidth;
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
    if (pollContent) {
        bubbleHeight = TGPollBubbleHeightForItem(item) + senderHeaderHeight + contextHeaderHeight;
    }
    if (callContent) {
        bubbleHeight = TGCallBubbleHeightForItem(item) + senderHeaderHeight + contextHeaderHeight;
    }
    if (TGMessageItemHasLinkPreview(item)) {
        bubbleHeight += TGLinkPreviewCardHeightForItem(item, bubbleWidth - 16.0) + 8.0;
    }
    if ([messageText length] > 0 && separateMetadataFooter && [timeString length] > 0) {
        bubbleHeight += 17.0;
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    CGFloat reactionBandHeight = TGReactionBandHeightForMessageItem(item);
    bubbleHeight += reactionBandHeight;
    CGFloat commentBarHeight = TGMessageCommentBarHeightForItem(item);
    bubbleHeight += commentBarHeight;

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    CGFloat blockOffset = floor(TGMessageExtraBlockVerticalPadding() / 2.0);
    NSRect bubbleRect = NSMakeRect(bubbleX,
                                   NSMinY(cellFrame) + 5.0 + blockOffset + topAccessoryHeight,
                                   bubbleWidth,
                                   bubbleHeight);
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
            contextTitle = [NSString stringWithFormat:TGLoc(@"forwarded.from"), [item forwardSourceDisplayName]];
            contextSubtitle = TGDisplayTextForMessageItem(item);
        } else {
            contextTitle = ([[item replySenderDisplayName] length] > 0) ? [item replySenderDisplayName] : TGLoc(@"reply");
            contextSubtitle = ([[item replyPreview] length] > 0) ? [item replyPreview] : TGLoc(@"message.original");
        }
        if ([contextSubtitle length] == 0) {
            contextSubtitle = TGLoc(@"media.media");
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
        playableRect.size.height -= (commentBarHeight + reactionBandHeight);
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
        documentRect.size.height -= (commentBarHeight + reactionBandHeight);
        TGDrawDocumentContentForItem(item, documentRect, outgoing, flipped);
    }

    if (pollContent) {
        NSRect pollRect = bubbleRect;
        if (senderHeaderHeight > 0.0) {
            if (flipped) {
                pollRect.origin.y += senderHeaderHeight;
            }
            pollRect.size.height -= senderHeaderHeight;
        }
        if (contextHeaderHeight > 0.0) {
            if (flipped) {
                pollRect.origin.y += contextHeaderHeight;
            }
            pollRect.size.height -= contextHeaderHeight;
        }
        pollRect.size.height -= (commentBarHeight + reactionBandHeight);
        TGDrawPollContentForItem(item, pollRect, outgoing, flipped);
    }

    if (callContent) {
        NSRect callRect = bubbleRect;
        if (senderHeaderHeight > 0.0) {
            if (flipped) {
                callRect.origin.y += senderHeaderHeight;
            }
            callRect.size.height -= senderHeaderHeight;
        }
        if (contextHeaderHeight > 0.0) {
            if (flipped) {
                callRect.origin.y += contextHeaderHeight;
            }
            callRect.size.height -= contextHeaderHeight;
        }
        callRect.size.height -= (commentBarHeight + reactionBandHeight);
        TGDrawCallContentForItem(item, callRect, outgoing, flipped);
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

    NSRect linkPreviewRect = TGLinkPreviewCardRectForItem(item,
                                                         bubbleRect,
                                                         showSenderDetails,
                                                         flipped);
    BOOL linkPreviewAboveText = (TGMessageItemHasLinkPreview(item) &&
                                 [[[item linkPreviewInfo] objectForKey:@"show_above_text"] boolValue]);
    if (linkPreviewAboveText && !NSIsEmptyRect(linkPreviewRect)) {
        contentTop += flipped ? (NSHeight(linkPreviewRect) + 8.0)
                              : -(NSHeight(linkPreviewRect) + 8.0);
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
    if (!NSIsEmptyRect(linkPreviewRect)) {
        TGDrawLinkPreviewCardForItem(item, linkPreviewRect, outgoing, flipped);
    }

    TGDrawMessageCommentBarForItem(item, bubbleRect, outgoing, flipped);

    if ([timeString length] > 0 && (([messageText length] == 0 && !nonVisualPlayable) || separateMetadataFooter)) {
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        CGFloat statusWidth = TGOutgoingStatusDotsWidthForItem(item);
        CGFloat statusGap = (statusWidth > 0.0) ? 5.0 : 0.0;
        CGFloat metaHeight = MAX(12.0, ceil(timeSize.height) + 2.0);
        CGFloat timeY = [controlView isFlipped]
            ? (NSMaxY(bubbleRect) - commentBarHeight - reactionBandHeight - metaHeight - 4.0)
            : (NSMinY(bubbleRect) + 4.0 + commentBarHeight + reactionBandHeight);
        NSRect timeRect = NSMakeRect(NSMaxX(bubbleRect) - timeSize.width - statusWidth - statusGap - 12.0,
                                     timeY,
                                     timeSize.width,
                                     metaHeight);
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
        TGDrawOutgoingStatusDotsForItem(item, timeRect, [controlView isFlipped]);
    }

    NSString *reactionSummary = [[item reactionAnimationDisplaySummary] length] > 0
        ? [item reactionAnimationDisplaySummary]
        : [item reactionSummary];
    NSFont *reactionFont = TGReactionDisplayFont();
    reactionSummary = TGStringByReplacingUnrenderableEmoji(reactionSummary, reactionFont);
    if ([reactionSummary length] > 0) {
        BOOL animatingReaction = [[item reactionAnimationDisplaySummary] length] > 0;
        CGFloat rawProgress = animatingReaction
            ? MAX(0.0, MIN(1.0, [item reactionAnimationProgress]))
            : 1.0;
        BOOL removingReaction = animatingReaction && [item reactionAnimationRemoving];
        CGFloat visualProgress = 1.0;
        if (animatingReaction) {
            if (removingReaction) {
                visualProgress = MAX(0.0, 1.0 - MIN(1.0, rawProgress / 0.55));
            } else {
                visualProgress = MAX(0.0, MIN(1.0, (rawProgress - 0.46) / 0.54));
            }
        }
        CGFloat inverseVisualProgress = 1.0 - visualProgress;
        CGFloat easedVisualProgress = 1.0 -
            (inverseVisualProgress * inverseVisualProgress * inverseVisualProgress);
        CGFloat reactionOpacity = removingReaction ? visualProgress : easedVisualProgress;
        CGFloat reactionScale = removingReaction
            ? (0.90 + (0.10 * visualProgress))
            : easedVisualProgress;
        NSDictionary *reactionAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            reactionFont, NSFontAttributeName,
                                            [TGClassicSelectedRowTextColor() colorWithAlphaComponent:reactionOpacity], NSForegroundColorAttributeName,
                                            nil];
        NSSize reactionSize = [reactionSummary sizeWithAttributes:reactionAttributes];
        CGFloat fullReactionWidth = ceil(reactionSize.width) + 16.0;
        CGFloat maximumReactionWidth = NSWidth(bubbleRect) - 24.0;
        if (fullReactionWidth > maximumReactionWidth) {
            fullReactionWidth = maximumReactionWidth;
        }
        if (fullReactionWidth > 20.0 && reactionScale > 0.01) {
            CGFloat reactionWidth = fullReactionWidth * reactionScale;
            CGFloat fullReactionHeight = 24.0;
            CGFloat reactionHeight = fullReactionHeight * reactionScale;
            CGFloat reactionY = [controlView isFlipped] ? (NSMaxY(bubbleRect) - reactionHeight - 5.0)
                                                        : (NSMinY(bubbleRect) + 5.0);
            NSRect reactionRect = NSMakeRect(NSMinX(bubbleRect) + 10.0 +
                                                 ((fullReactionWidth - reactionWidth) / 2.0),
                                             reactionY,
                                             reactionWidth,
                                             reactionHeight);
            CGFloat reactionRadius = floor(NSHeight(reactionRect) / 2.0);
            NSBezierPath *reactionPath = [NSBezierPath bezierPathWithRoundedRect:reactionRect
                                                                         xRadius:reactionRadius
                                                                         yRadius:reactionRadius];
            [[TGClassicNavigationSelectedColor(0.82) colorWithAlphaComponent:reactionOpacity] set];
            [reactionPath fill];
            [[TGClassicNavigationSelectedStrokeColor(0.72) colorWithAlphaComponent:reactionOpacity] set];
            [reactionPath setLineWidth:1.0];
            [reactionPath stroke];

            NSMutableParagraphStyle *reactionParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
            [reactionParagraph setAlignment:NSCenterTextAlignment];
            NSMutableDictionary *centeredAttributes = [NSMutableDictionary dictionaryWithDictionary:reactionAttributes];
            [centeredAttributes setObject:reactionParagraph forKey:NSParagraphStyleAttributeName];
            CGFloat opticalOffset = [controlView isFlipped] ? -4.0 : 4.0;
            CGFloat reactionTextY = NSMidY(reactionRect) - floor(reactionSize.height / 2.0) + opticalOffset;
            NSRect reactionTextRect = NSMakeRect(NSMinX(reactionRect) + 4.0,
                                                 reactionTextY,
                                                 NSWidth(reactionRect) - 8.0,
                                                 reactionSize.height + 2.0);
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
                                 NSMinY(rowRect) + 7.0,
                                 iconSide,
                                 iconSide);
    if (NSHeight(rowRect) <= 48.0) {
        iconRect.origin.y = NSMinY(rowRect) + floor((NSHeight(rowRect) - iconSide) / 2.0);
    }
    NSString *avatarTitle = nil;
    NSString *avatarPath = nil;
    if (outgoing) {
        avatarTitle = TGLoc(@"message.you");
        if ([avatarTitle isEqualToString:@"message.you"]) {
            avatarTitle = @"You";
        }
    } else {
        avatarTitle = [item senderDisplayName];
        avatarPath = [item senderAvatarLocalPath];
    }
    if ([avatarTitle length] == 0) {
        avatarTitle = outgoing ? @"You" : @"T";
    }
    TGDrawAvatarInRect(avatarPath, avatarTitle, iconRect, NO, flipped);

    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageMetaFont(), NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
    CGFloat statusWidth = TGOutgoingStatusDotsWidthForItem(item);
    CGFloat statusGap = (statusWidth > 0.0) ? 5.0 : 0.0;
    CGFloat timeRightPadding = 12.0;
    CGFloat metaHeight = MAX(12.0, ceil(timeSize.height) + 2.0);
    NSRect timeRect = NSMakeRect(NSMaxX(rowRect) - timeRightPadding - timeSize.width - statusWidth - statusGap,
                                 flipped ? (NSMinY(rowRect) + 8.0) : (NSMaxY(rowRect) - metaHeight - 6.0),
                                 timeSize.width,
                                 metaHeight);
    if ([timeString length] > 0) {
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
        TGDrawOutgoingStatusDotsForItem(item, timeRect, flipped);
    }

    CGFloat textX = NSMaxX(iconRect) + 10.0;
    CGFloat textRight = NSMinX(timeRect) - 10.0;
    if ([timeString length] == 0) {
        textRight = NSMaxX(rowRect) - 12.0;
    }
    CGFloat maximumTextRight = NSMaxX(rowRect) - 12.0;
    CGFloat textWidth = MAX(1.0, MIN(textRight, maximumTextRight) - textX);

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
        NSString *contextTitle = ([[item forwardSourceDisplayName] length] > 0) ? [NSString stringWithFormat:TGLoc(@"forwarded.from"), [item forwardSourceDisplayName]] : (([[item replySenderDisplayName] length] > 0) ? [item replySenderDisplayName] : TGLoc(@"reply"));
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

    NSRect linkPreviewRect = TGLinkPreviewCardRectForItem(item,
                                                         rowRect,
                                                         self.showSenderDetails,
                                                         flipped);
    BOOL linkPreviewAboveText = (TGMessageItemHasLinkPreview(item) &&
                                 [[[item linkPreviewInfo] objectForKey:@"show_above_text"] boolValue]);
    if (linkPreviewAboveText && !NSIsEmptyRect(linkPreviewRect)) {
        textY += flipped ? (NSHeight(linkPreviewRect) + 8.0)
                         : -(NSHeight(linkPreviewRect) + 8.0);
    }

    NSString *messageText = TGDisplayTextForMessageItem(item);
    BOOL messageTextIsPlaceholder = NO;
    if ([messageText length] == 0) {
        if ([item isVisualMediaMessage]) {
            messageText = [item visualMediaPlaceholderTitle];
            messageTextIsPlaceholder = YES;
        } else if (TGMessageItemIsNonVisualPlayableMedia(item)) {
            messageText = TGPlayableMediaTitleForMessageItem(item);
            messageTextIsPlaceholder = YES;
        } else if (TGMessageItemIsNonVisualDocument(item)) {
            messageText = @"Document";
            messageTextIsPlaceholder = YES;
        }
    }
    NSMutableParagraphStyle *paragraph = TGMessageTextParagraphStyle();
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    TGChatMessageBodyFont(), NSFontAttributeName,
                                    messageTextIsPlaceholder ? TGClassicMutedInkColor() : TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSAttributedString *attributedText = TGAttributedMessageStringForItem(item, messageText, textAttributes);
    NSRect textRect = NSZeroRect;
    if ([item isVisualMediaMessage]) {
        NSRect mediaRect = TGListMessageMediaRectForItem(item, cellFrame, self.showSenderDetails);
        NSArray *mediaItems = [item visualMediaItems];
        NSArray *tileRects = TGMediaTileRectsForMessageItem(item, mediaRect);
        NSUInteger tileIndex = 0;
        for (tileIndex = 0; tileIndex < [tileRects count] && tileIndex < [mediaItems count]; tileIndex++) {
            id mediaObject = [mediaItems objectAtIndex:tileIndex];
            if (![mediaObject isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSUInteger overflowCount = 0;
            if (tileIndex == [tileRects count] - 1 && [mediaItems count] > [tileRects count]) {
                overflowCount = [mediaItems count] - [tileRects count];
            }
            NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
            tileRect = TGStickerAdjustedMediaRect((NSDictionary *)mediaObject, tileRect, flipped);
            TGDrawMediaItemInRect((NSDictionary *)mediaObject, tileRect, outgoing, flipped, [mediaItems count] > 1, overflowCount);
        }
        CGFloat captionY = NSMaxY(mediaRect) + 6.0;
        if ([messageText length] > 0 && !NSIsEmptyRect(mediaRect)) {
            CGFloat captionWidth = MIN(textWidth, NSWidth(rowRect) - textX - 14.0);
            NSRect measuredRect = [attributedText boundingRectWithSize:NSMakeSize(captionWidth, 12000.0)
                                                               options:NSStringDrawingUsesLineFragmentOrigin];
            CGFloat textHeight = MAX(15.0, ceil(NSHeight(measuredRect)));
            textRect = NSMakeRect(textX, captionY, captionWidth, textHeight + 2.0);
            [attributedText drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];
        } else {
            textRect = mediaRect;
        }
    } else if (TGMessageItemIsPollContent(item)) {
        CGFloat contentWidth = MAX(1.0, NSMaxX(rowRect) - textX - 14.0);
        NSRect pollRect = NSMakeRect(textX,
                                     flipped ? textY : (textY - TGPollBubbleHeightForItem(item)),
                                     MIN(TGPollBubbleWidthForItem(item, contentWidth), contentWidth),
                                     TGPollBubbleHeightForItem(item));
        TGDrawPollContentForItem(item, pollRect, outgoing, flipped);
        textRect = pollRect;
    } else if (TGMessageItemIsCallContent(item)) {
        CGFloat contentWidth = MAX(1.0, NSMaxX(rowRect) - textX - 14.0);
        CGFloat callHeight = TGCallBubbleHeightForItem(item);
        NSRect callRect = NSMakeRect(textX,
                                    flipped ? textY : (textY - callHeight),
                                    MIN(TGCallBubbleWidthForItem(item, contentWidth), contentWidth),
                                    callHeight);
        TGDrawCallContentForItem(item, callRect, outgoing, flipped);
        textRect = callRect;
    } else if (TGMessageItemIsNonVisualPlayableMedia(item)) {
        CGFloat contentWidth = MAX(1.0, NSMaxX(rowRect) - textX - 14.0);
        NSRect playableRect = NSMakeRect(textX, flipped ? textY : (textY - 50.0), MIN(260.0, contentWidth), 50.0);
        TGDrawPlayableMediaContentForItem(item, playableRect, flipped);
        textRect = playableRect;
    } else if (TGMessageItemIsNonVisualDocument(item)) {
        CGFloat contentWidth = MAX(1.0, NSMaxX(rowRect) - textX - 14.0);
        NSRect documentRect = NSMakeRect(textX, flipped ? textY : (textY - 50.0), MIN(300.0, contentWidth), 50.0);
        TGDrawDocumentContentForItem(item, documentRect, outgoing, flipped);
        textRect = documentRect;
    } else {
        NSRect measuredRect = [attributedText boundingRectWithSize:NSMakeSize(textWidth, 12000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
        CGFloat textHeight = MAX(15.0, ceil(NSHeight(measuredRect)));
        textRect = NSMakeRect(textX,
                              flipped ? textY : (textY - textHeight),
                              textWidth,
                              textHeight + 2.0);
        [attributedText drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin];
    }
    if (!NSIsEmptyRect(linkPreviewRect)) {
        TGDrawLinkPreviewCardForItem(item, linkPreviewRect, outgoing, flipped);
    }

    CGFloat footerY = flipped ? (NSMaxY(textRect) + 4.0) : (NSMinY(textRect) - 20.0);
    NSFont *reactionFont = TGReactionDisplayFont();
    NSString *reactionSummary = TGStringByReplacingUnrenderableEmoji([item reactionSummary],
                                                                     reactionFont);
    NSString *commentTitle = nil;
    if (TGMessageItemHasCommentThread(item)) {
        NSInteger replyCount = ([[item messageThreadReplyCount] respondsToSelector:@selector(integerValue)] ? [[item messageThreadReplyCount] integerValue] : 0);
        commentTitle = (replyCount > 0) ? [NSString stringWithFormat:TGLoc(replyCount == 1 ? @"message.comments.count.one" : @"message.comments.count.many"), (long)replyCount] : TGLoc(@"message.comments.add");
    }
    if ([reactionSummary length] > 0 || [commentTitle length] > 0) {
        NSString *footer = ([reactionSummary length] > 0 && [commentTitle length] > 0) ? [NSString stringWithFormat:@"%@    %@", reactionSummary, commentTitle] : (([reactionSummary length] > 0) ? reactionSummary : commentTitle);
        NSMutableParagraphStyle *footerParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [footerParagraph setLineBreakMode:NSLineBreakByTruncatingTail];
        NSDictionary *footerAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                          reactionFont, NSFontAttributeName,
                                          TGClassicNavigationSelectedColor(0.92), NSForegroundColorAttributeName,
                                          footerParagraph, NSParagraphStyleAttributeName,
                                          nil];
        CGFloat footerMaxY = NSMaxY(rowRect) - 5.0;
        if (flipped && footerY + 16.0 > footerMaxY) {
            footerY = footerMaxY - 16.0;
        } else if (!flipped && footerY < NSMinY(rowRect) + 5.0) {
            footerY = NSMinY(rowRect) + 5.0;
        }
        [footer drawInRect:NSMakeRect(textX, footerY, MAX(40.0, textWidth), 16.0) withAttributes:footerAttributes];
    }
}

- (void)dealloc {
    [_messageItem release];
    [super dealloc];
}

@end
