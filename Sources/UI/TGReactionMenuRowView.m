#import "TGReactionMenuRowView.h"
#import "../Core/TGMessageItem.h"

static BOOL TGReactionEmojiCanRender(NSString *emoji) {
    if (![emoji isKindOfClass:[NSString class]] || [emoji length] == 0) {
        return NO;
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
    CGFloat buttonWidth = 36.0;
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, buttonWidth * [emojis count], 34.0)];
    if (self) {
        _reactionTarget = target;
        _reactionAction = action;
        NSUInteger index = 0;
        for (index = 0; index < [emojis count]; index++) {
            NSString *emoji = [emojis objectAtIndex:index];
            NSString *displayEmoji = TGReactionEmojiCanRender(emoji) ? emoji : @"?";
            TGReactionMenuButton *button = [[[TGReactionMenuButton alloc]
                initWithFrame:NSMakeRect(index * buttonWidth, 2.0, buttonWidth, 30.0)] autorelease];
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
            [self addSubview:button];
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
