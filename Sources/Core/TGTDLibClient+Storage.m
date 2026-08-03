#import "TGTDLibClient+Storage.h"

#import "../Services/TGStorageCleanupPolicy.h"

@interface TGTDLibClient (StoragePrivate)
- (NSString *)uniqueExtraWithPrefix:(NSString *)prefix;
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
@end

@implementation TGTDLibClient (Storage)

- (NSNumber *)storageLongLongNumberFromDictionary:(NSDictionary *)dictionary key:(NSString *)key {
    id value = [dictionary objectForKey:key];
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [NSNumber numberWithLongLong:[value longLongValue]];
    }
    return [NSNumber numberWithLongLong:0];
}

- (NSDictionary *)storageUsageSummaryFromFastStatistics:(NSDictionary *)statistics {
    if (![statistics isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    long long filesSize = [[self storageLongLongNumberFromDictionary:statistics key:@"files_size"] longLongValue];
    long long databaseSize = [[self storageLongLongNumberFromDictionary:statistics key:@"database_size"] longLongValue];
    long long languagePackSize = [[self storageLongLongNumberFromDictionary:statistics key:@"language_pack_database_size"] longLongValue];
    long long logSize = [[self storageLongLongNumberFromDictionary:statistics key:@"log_size"] longLongValue];
    long long totalSize = filesSize + databaseSize + languagePackSize + logSize;

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:[NSNumber numberWithLongLong:filesSize] forKey:@"files_size"];
    [summary setObject:[NSNumber numberWithLongLong:databaseSize] forKey:@"database_size"];
    [summary setObject:[NSNumber numberWithLongLong:languagePackSize] forKey:@"language_pack_database_size"];
    [summary setObject:[NSNumber numberWithLongLong:logSize] forKey:@"log_size"];
    [summary setObject:[NSNumber numberWithLongLong:totalSize] forKey:@"total_size"];
    return summary;
}

- (NSDictionary *)storageUsageSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getStorageStatisticsFast" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-storage-fast"] forKey:@"@extra"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-storage-fast"
                                                           timeout:timeout
                                                         errorCode:72
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *summary = [self storageUsageSummaryFromFastStatistics:response];
    if (!summary && error) {
        *error = [self errorWithDescription:@"TDLib returned an invalid storage statistics response." code:72];
    }
    return summary;
}

- (NSDictionary *)clearDownloadedMediaCacheForFileTypes:(NSArray *)fileTypes
                                                 chatIDs:(NSArray *)chatIDs
                                                 timeout:(NSTimeInterval)timeout
                                                   error:(NSError **)error {
    NSArray *safeFileTypes = [fileTypes isKindOfClass:[NSArray class]] ? fileTypes : [NSArray array];
    NSArray *safeChatIDs = TGStorageCleanupNormalizedChatIDs(chatIDs);
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"optimizeStorage" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-storage-clear"] forKey:@"@extra"];
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"size"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"ttl"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"count"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"immunity_delay"];
    [request setObject:safeFileTypes forKey:@"file_types"];
    [request setObject:safeChatIDs forKey:@"chat_ids"];
    [request setObject:[NSArray array] forKey:@"exclude_chat_ids"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"return_deleted_file_statistics"];
    [request setObject:[NSNumber numberWithUnsignedInteger:[safeChatIDs count]] forKey:@"chat_limit"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-storage-clear"
                                                           timeout:timeout
                                                         errorCode:73
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSError *refreshError = nil;
    NSDictionary *summary = [self storageUsageSummaryWithTimeout:timeout error:&refreshError];
    if (summary) {
        return summary;
    }
    return response;
}

- (NSDictionary *)clearDownloadedMediaCacheWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self clearDownloadedMediaCacheForFileTypes:[NSArray array]
                                               chatIDs:[NSArray array]
                                               timeout:timeout
                                                 error:error];
}

@end
