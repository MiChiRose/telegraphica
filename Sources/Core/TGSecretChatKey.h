#import <Foundation/Foundation.h>

@interface TGSecretChatKey : NSObject

+ (NSArray *)colorIndexesForKeyHashData:(NSData *)keyHashData;
+ (NSString *)fingerprintForKeyHashData:(NSData *)keyHashData;

@end
