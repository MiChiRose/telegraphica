#import <Foundation/Foundation.h>

@interface TGDemoContent : NSObject

+ (BOOL)isEnabledFromEnvironment;
+ (NSDictionary *)profileSummary;
+ (NSArray *)chatItems;
+ (NSArray *)chatFolderItems;
+ (NSArray *)messageItemsForChatID:(NSNumber *)chatID;
+ (NSArray *)stickerItems;

@end
