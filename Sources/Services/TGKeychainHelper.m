#import "TGKeychainHelper.h"
#import <Security/Security.h>
#include <string.h>

static NSString * const TGKeychainServiceName = @"com.michirose.telegraphica.auth";

@interface TGKeychainHelper ()
@property (nonatomic, assign) OSStatus lastStatusValue;
- (void)prepareForKeychainInteraction;
- (BOOL)unlockDefaultKeychainAfterInteractionStatus:(OSStatus)status;
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
        return [self deleteForAccount:account];
    }
    [self prepareForKeychainInteraction];

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
    if (status == errSecInteractionNotAllowed && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
        status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:query];
            [item addEntriesFromDictionary:attributes];
            status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        }
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
    [self prepareForKeychainInteraction];

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecInteractionNotAllowed && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
        status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    }
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

- (BOOL)deleteForAccount:(NSString *)account {
    if ([account length] == 0) {
        self.lastStatusValue = errSecParam;
        return NO;
    }
    [self prepareForKeychainInteraction];

    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:TGKeychainServiceName forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    if (status == errSecSuccess || status == errSecItemNotFound) {
        self.lastStatusValue = status;
        return YES;
    }

    SecKeychainItemRef item = NULL;
    const char *service = [TGKeychainServiceName UTF8String];
    const char *accountName = [account UTF8String];
    if (!service || !accountName) {
        self.lastStatusValue = errSecParam;
        return NO;
    }
    status = SecKeychainFindGenericPassword(NULL,
                                            (UInt32)strlen(service),
                                            service,
                                            (UInt32)strlen(accountName),
                                            accountName,
                                            NULL,
                                            NULL,
                                            &item);
    if (status == errSecItemNotFound) {
        self.lastStatusValue = status;
        return YES;
    }
    if (status != errSecSuccess || item == NULL) {
        self.lastStatusValue = status;
        return NO;
    }
    status = SecKeychainItemDelete(item);
    CFRelease(item);
    self.lastStatusValue = status;
    return (status == errSecSuccess || status == errSecItemNotFound);
}

- (OSStatus)lastStatus {
    return self.lastStatusValue;
}

- (void)prepareForKeychainInteraction {
    SecKeychainSetUserInteractionAllowed(TRUE);
}

- (BOOL)unlockDefaultKeychainAfterInteractionStatus:(OSStatus)status {
    if (status != errSecInteractionNotAllowed) {
        return NO;
    }
    [self prepareForKeychainInteraction];
    return (SecKeychainUnlock(NULL, 0, NULL, TRUE) == errSecSuccess);
}

- (OSStatus)legacySaveData:(NSData *)value forAccount:(NSString *)account {
    const char *service = [TGKeychainServiceName UTF8String];
    const char *accountName = [account UTF8String];
    if (!service || !accountName || !value) {
        return errSecParam;
    }
    [self prepareForKeychainInteraction];

    UInt32 serviceLength = (UInt32)strlen(service);
    UInt32 accountLength = (UInt32)strlen(accountName);
    UInt32 valueLength = (UInt32)[value length];
    const void *valueBytes = [value bytes];

    SecKeychainItemRef item = NULL;
    BOOL didRetry = NO;
    OSStatus status = errSecSuccess;
retryLegacySave:
    status = SecKeychainFindGenericPassword(NULL,
                                            serviceLength,
                                            service,
                                            accountLength,
                                            accountName,
                                            NULL,
                                            NULL,
                                            &item);
    if (status == errSecInteractionNotAllowed && !didRetry && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
        didRetry = YES;
        goto retryLegacySave;
    }
    if (status == errSecSuccess && item) {
        status = SecKeychainItemModifyAttributesAndData(item, NULL, valueLength, valueBytes);
        if (status == errSecInteractionNotAllowed && !didRetry && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
            CFRelease(item);
            item = NULL;
            didRetry = YES;
            goto retryLegacySave;
        }
        CFRelease(item);
        return status;
    }
    if (item) {
        CFRelease(item);
    }
    if (status != errSecItemNotFound) {
        return status;
    }

    status = SecKeychainAddGenericPassword(NULL,
                                           serviceLength,
                                           service,
                                           accountLength,
                                           accountName,
                                           valueLength,
                                           valueBytes,
                                           NULL);
    if (status == errSecInteractionNotAllowed && !didRetry && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
        didRetry = YES;
        goto retryLegacySave;
    }
    return status;
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
    [self prepareForKeychainInteraction];

    UInt32 serviceLength = (UInt32)strlen(service);
    UInt32 accountLength = (UInt32)strlen(accountName);
    UInt32 passwordLength = 0;
    void *passwordData = NULL;
    BOOL didRetry = NO;
    OSStatus status = errSecSuccess;
retryLegacyRead:
    status = SecKeychainFindGenericPassword(NULL,
                                            serviceLength,
                                            service,
                                            accountLength,
                                            accountName,
                                            &passwordLength,
                                            &passwordData,
                                            NULL);
    if (status == errSecInteractionNotAllowed && !didRetry && [self unlockDefaultKeychainAfterInteractionStatus:status]) {
        didRetry = YES;
        goto retryLegacyRead;
    }
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
