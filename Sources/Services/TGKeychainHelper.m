#import "TGKeychainHelper.h"
#import <Security/Security.h>

static NSString * const TGKeychainServiceName = @"com.michirose.telegraphica.auth";

@implementation TGKeychainHelper

+ (instancetype)sharedHelper {
    static TGKeychainHelper *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (BOOL)saveString:(NSString *)value forAccount:(NSString *)account {
    if ([account length] == 0) {
        return NO;
    }
    if (!value) {
        [self deleteForAccount:account];
        return YES;
    }

    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    [self deleteForAccount:account];

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:valueData forKey:(__bridge id)kSecValueData];
#if defined(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    [query setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
#endif

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return (status == errSecSuccess);
}

- (NSString *)readStringForAccount:(NSString *)account {
    if ([account length] == 0) {
        return nil;
    }

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess && result != NULL) {
#if __has_feature(objc_arc)
        NSData *data = CFBridgingRelease(result);
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#else
        NSData *data = [(NSData *)result autorelease];
        return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
#endif
    }
    return nil;
}

- (void)deleteForAccount:(NSString *)account {
    if ([account length] == 0) {
        return;
    }

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@end
