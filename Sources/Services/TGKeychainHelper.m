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

- (BOOL)saveData:(NSData *)value forAccount:(NSString *)account {
    if ([account length] == 0) {
        return NO;
    }
    if (!value) {
        [self deleteForAccount:account];
        return YES;
    }

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];

    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    [attributes setObject:value forKey:(__bridge id)kSecValueData];

    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:query];
        [item addEntriesFromDictionary:attributes];
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
    return (status == errSecSuccess);
}

- (NSData *)readDataForAccount:(NSString *)account {
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
        return CFBridgingRelease(result);
#else
        return [(NSData *)result autorelease];
#endif
    }
    return nil;
}

- (BOOL)saveString:(NSString *)value forAccount:(NSString *)account {
    if (!value) {
        return [self saveData:nil forAccount:account];
    }
    NSData *valueData = [value dataUsingEncoding:NSUTF8StringEncoding];
    return [self saveData:valueData forAccount:account];
}

- (NSString *)readStringForAccount:(NSString *)account {
    NSData *data = [self readDataForAccount:account];
    if (!data) {
        return nil;
    }
#if __has_feature(objc_arc)
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
#else
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
#endif
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
