#import <Cocoa/Cocoa.h>

@class TGMessageItem;

BOOL TGReactionEmojiCanRender(NSString *emoji);

@interface TGReactionMenuRowView : NSView

- (id)initWithEmojis:(NSArray *)emojis
             message:(TGMessageItem *)message
      chosenReactions:(NSArray *)chosenReactions
              target:(id)target
              action:(SEL)action;

@end
