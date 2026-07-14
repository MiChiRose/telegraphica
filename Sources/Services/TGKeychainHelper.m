#import "TGKeychainHelper.h"
#import <Security/Security.h>
#include <string.h>

static NSString * const TGKeychainServiceName = @"com.michirose.telegraphica.auth";

@interface TGKeychainHelper ()
@property (nonatomic, assign) OSStatus lastStatusValue;
- (OSStatus)legacySaveData:(NSData *)value forAccount:(NSString *)account;
- (NSData *)legacyReadDataForAccount:(NSString *)account status:(OSStatus *)statusOut;
@end

@implementation TGKeychainHelper

@synthesize lastStatusValue = _lastStatusValue;

+ (instancetype)sharedHelper {
    static TGKeychainHelper *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (BOOL)saveData:(NSData *)value forAccount:(NSString *)account {
    self.lastStatusValue = errSecSuccess;
    if ([account length] == 0) {
        self.lastStatusValue = errSecParam;
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
    if (status == errSecSuccess) {
        self.lastStatusValue = status;
        return YES;
    }

    self.lastStatusValue = [self legacySaveData:value forAccount:account];
    return (self.lastStatusValue == errSecSuccess);
}

- (NSData *)readDataForAccount:(NSString *)account {
    self.lastStatusValue = errSecSuccess;
    if ([account length] == 0) {
        self.lastStatusValue = errSecParam;
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
        self.lastStatusValue = status;
#if __has_feature(objc_arc)
        return CFBridgingRelease(result);
#else
        return [(NSData *)result autorelease];
#endif
    }
    if (result) {
        CFRelease(result);
    }
    NSData *legacyData = [self legacyReadDataForAccount:account status:&status];
    self.lastStatusValue = status;
    return legacyData;
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

- (OSStatus)lastStatus {
    return self.lastStatusValue;
}

- (OSStatus)legacySaveData:(NSData *)value forAccount:(NSString *)account {
    const char *service = [TGKeychainServiceName UTF8String];
    const char *accountName = [account UTF8String];
    if (!service || !accountName || !value) {
        return errSecParam;
    }

    UInt32 serviceLength = (UInt32)strlen(service);
    UInt32 accountLength = (UInt32)strlen(accountName);
    UInt32 valueLength = (UInt32)[value length];
    const void *valueBytes = [value bytes];

    SecKeychainItemRef item = NULL;
    OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                     serviceLength,
                                                     service,
                                                     accountLength,
                                                     accountName,
                                                     NULL,
                                                     NULL,
                                                     &item);
    if (status == errSecSuccess && item) {
        status = SecKeychainItemModifyAttributesAndData(item, NULL, valueLength, valueBytes);
        CFRelease(item);
        return status;
    }
    if (item) {
        CFRelease(item);
    }
    if (status != errSecItemNotFound) {
        return status;
    }

    return SecKeychainAddGenericPassword(NULL,
                                         serviceLength,
                                         service,
                                         accountLength,
                                         accountName,
                                         valueLength,
                                         valueBytes,
                                         NULL);
}

- (NSData *)legacyReadDataForAccount:(NSString *)account status:(OSStatus *)statusOut {
    const char *service = [TGKeychainServiceName UTF8String];
    const char *accountName = [account UTF8String];
    if (!service || !accountName) {
        if (statusOut) {
            *statusOut = errSecParam;
        }
        return nil;
    }

    UInt32 serviceLength = (UInt32)strlen(service);
    UInt32 accountLength = (UInt32)strlen(accountName);
    UInt32 passwordLength = 0;
    void *passwordData = NULL;
    OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                     serviceLength,
                                                     service,
                                                     accountLength,
                                                     accountName,
                                                     &passwordLength,
                                                     &passwordData,
                                                     NULL);
    if (statusOut) {
        *statusOut = status;
    }
    if (status != errSecSuccess || !passwordData || passwordLength == 0) {
        if (passwordData) {
            SecKeychainItemFreeContent(NULL, passwordData);
        }
        return nil;
    }

    NSData *data = [NSData dataWithBytes:passwordData length:passwordLength];
    SecKeychainItemFreeContent(NULL, passwordData);
    return data;
}

@end
