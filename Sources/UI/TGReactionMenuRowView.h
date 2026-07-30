#import <Cocoa/Cocoa.h>

@class TGMessageItem;

@interface TGReactionMenuRowView : NSView

- (id)initWithEmojis:(NSArray *)emojis
             message:(TGMessageItem *)message
      chosenReactions:(NSArray *)chosenReactions
              target:(id)target
              action:(SEL)action;

@end
