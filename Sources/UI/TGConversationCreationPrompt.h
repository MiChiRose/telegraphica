#import <Cocoa/Cocoa.h>

@interface TGConversationCreationPrompt : NSObject

+ (BOOL)runGroupPromptWithMemberCount:(NSUInteger)memberCount title:(NSString **)title;
+ (BOOL)runChannelPromptWithTitle:(NSString **)title description:(NSString **)description;

@end
