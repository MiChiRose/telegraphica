#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface TGKeychainHelper : NSObject

+ (instancetype)sharedHelper;
- (BOOL)saveData:(NSData *)value forAccount:(NSString *)account;
- (NSData *)readDataForAccount:(NSString *)account;
- (BOOL)saveString:(NSString *)value forAccount:(NSString *)account;
- (NSString *)readStringForAccount:(NSString *)account;
- (BOOL)deleteForAccount:(NSString *)account;
- (OSStatus)lastStatus;

@end
