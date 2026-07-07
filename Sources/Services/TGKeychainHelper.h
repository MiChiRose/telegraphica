#import <Foundation/Foundation.h>

@interface TGKeychainHelper : NSObject

+ (instancetype)sharedHelper;
- (BOOL)saveData:(NSData *)value forAccount:(NSString *)account;
- (NSData *)readDataForAccount:(NSString *)account;
- (BOOL)saveString:(NSString *)value forAccount:(NSString *)account;
- (NSString *)readStringForAccount:(NSString *)account;
- (void)deleteForAccount:(NSString *)account;

@end
