#import "TGTDLibClient+Files.h"
#include <limits.h>

static BOOL TGDownloadIdentityHasValidNumericValue(id value, long long maximum) {
    if (![value isKindOfClass:[NSNumber class]]) { return NO; }
    long long number = [value longLongValue];
    return number > 0 && number <= maximum && [value doubleValue] == (double)number;
}

@interface TGTDLibClient (FilesPrivate)
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error;
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code;
- (NSString *)completedLocalPathFromFileObject:(id)fileObject;
@end

@implementation TGTDLibClient (Files)

- (NSNumber *)downloadAccountIDWithError:(NSError **)error {
    if (error) { *error = nil; }
    NSError *requestError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:
        [NSDictionary dictionaryWithObject:@"getMe" forKey:@"@type"]
        extraPrefix:@"telegraphica-download-account" timeout:3.0 errorCode:56 error:&requestError];
    id accountID = [response isKindOfClass:[NSDictionary class]] ? [response objectForKey:@"id"] : nil;
    if (![response isKindOfClass:[NSDictionary class]] || ![[response objectForKey:@"@type"] isEqual:@"user"] ||
        !TGDownloadIdentityHasValidNumericValue(accountID, 9007199254740991LL)) {
        if (error) { *error = [self errorWithDescription:@"TDLib could not confirm the download account. Please retry after signing in."
            code:requestError ? [requestError code] : 56]; }
        return nil;
    }
    return [NSNumber numberWithLongLong:[accountID longLongValue]];
}

- (NSDictionary *)downloadFileIdentityForFileID:(NSNumber *)fileID
                                  remoteFileID:(NSString *)remoteID
                                         error:(NSError **)error {
    if (error) { *error = nil; }
    if (remoteID && ![remoteID isKindOfClass:[NSString class]]) {
        if (error) { *error = [self errorWithDescription:@"Remote file identity is invalid." code:56]; }
        return nil;
    }
    BOOL resolvingRemote = [remoteID length] > 0;
    if (!resolvingRemote && !TGDownloadIdentityHasValidNumericValue(fileID, INT_MAX)) {
        if (error) { *error = [self errorWithDescription:@"File identifier is missing or invalid." code:56]; }
        return nil;
    }
    NSDictionary *request = resolvingRemote ? [NSDictionary dictionaryWithObjectsAndKeys:
        @"getRemoteFile", @"@type", remoteID, @"remote_file_id",
        [NSDictionary dictionaryWithObject:@"fileTypeUnknown" forKey:@"@type"], @"file_type", nil] :
        [NSDictionary dictionaryWithObjectsAndKeys:@"getFile", @"@type", fileID, @"file_id", nil];
    NSError *requestError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
        extraPrefix:@"telegraphica-file-identity" timeout:3.0 errorCode:56 error:&requestError];
    if (!response) {
        // Protocol descriptions can contain the remote identifier; expose only
        // a fixed explanation and the failure code to download presentation.
        if (error) { *error = [self errorWithDescription:@"TDLib could not resolve this file. Retry or reopen its source message."
            code:requestError ? [requestError code] : 56]; }
        return nil;
    }
    id responseID = [response isKindOfClass:[NSDictionary class]] ? [response objectForKey:@"id"] : nil;
    NSDictionary *local = [response isKindOfClass:[NSDictionary class]] ? [response objectForKey:@"local"] : nil;
    NSDictionary *remote = [response isKindOfClass:[NSDictionary class]] ? [response objectForKey:@"remote"] : nil;
    BOOL valid = [response isKindOfClass:[NSDictionary class]] &&
        [[response objectForKey:@"@type"] isEqual:@"file"] && TGDownloadIdentityHasValidNumericValue(responseID, INT_MAX) &&
        (resolvingRemote || [responseID longLongValue] == [fileID longLongValue]) &&
        [local isKindOfClass:[NSDictionary class]] && [[local objectForKey:@"path"] isKindOfClass:[NSString class]] &&
        [remote isKindOfClass:[NSDictionary class]] && [[remote objectForKey:@"id"] isKindOfClass:[NSString class]];
    if (valid && resolvingRemote) { valid = [[remote objectForKey:@"id"] length] > 0; }
    if (valid && [remote objectForKey:@"unique_id"]) {
        valid = [[remote objectForKey:@"unique_id"] isKindOfClass:[NSString class]];
    }
    if (!valid) {
        if (error) { *error = [self errorWithDescription:@"TDLib returned invalid file identity information." code:56]; }
        return nil;
    }
    // getRemoteFile is correlated by the request helper. Do not compare its
    // canonical remote ID with the input: one file can have multiple aliases.
    return response;
}

- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID
                                          cancelled:(TGFileDownloadCancellationBlock)cancelled
                                           progress:(TGFileDownloadProgressBlock)progress
                                              error:(NSError **)error {
    return TGPersistentFileDownload(fileID, 3.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            return [self sendTDLibRequestAndWaitForExtra:request extraPrefix:@"telegraphica-persistent-file"
                                               timeout:timeout errorCode:56 error:requestError];
        }, cancelled, progress,
        ^NSTimeInterval { return [[NSProcessInfo processInfo] systemUptime]; },
        ^(NSTimeInterval seconds) { [NSThread sleepForTimeInterval:seconds]; }, error);
}

- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error {
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"File identifier is missing." code:56];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"downloadFile" forKey:@"@type"];
    [request setObject:fileID forKey:@"file_id"];
    [request setObject:[NSNumber numberWithInt:16] forKey:@"priority"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"limit"];
    [request setObject:[NSNumber numberWithBool:YES] forKey:@"synchronous"];

    NSError *downloadError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-download-file"
                                                           timeout:timeout
                                                         errorCode:56
                                                             error:&downloadError];
    if (![response isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = downloadError ? downloadError :
                [self errorWithDescription:@"TDLib did not return a file download response." code:56];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"file"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned an unexpected file download response." code:56];
        }
        return nil;
    }
    NSString *path = [self completedLocalPathFromFileObject:response];
    if ([path length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not finish the file download." code:56];
        }
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:path, @"local_path", fileID, @"file_id", nil];
}

- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout {
    return [self downloadedFileInfoForFileID:fileID timeout:timeout error:NULL];
}

- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSDictionary *info = [self downloadedFileInfoForFileID:fileID timeout:timeout error:error];
    NSString *path = [info objectForKey:@"local_path"];
    return ([path isKindOfClass:[NSString class]] && [path length] > 0) ? path : nil;
}

- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID
                        timeout:(NSTimeInterval)timeout
                          error:(NSError **)error {
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"File identifier is missing." code:182];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"cancelDownloadFile", @"@type",
                             fileID, @"file_id",
                             [NSNumber numberWithBool:NO], @"only_if_pending",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-cancel-download"
                                                           timeout:timeout
                                                         errorCode:182
                                                             error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

- (BOOL)deleteCachedFileForFileID:(NSNumber *)fileID
                          timeout:(NSTimeInterval)timeout
                            error:(NSError **)error {
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"File identifier is missing." code:183];
        }
        return NO;
    }
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"deleteFile", @"@type",
                             fileID, @"file_id",
                             nil];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-delete-cached-file"
                                                           timeout:timeout
                                                         errorCode:183
                                                             error:error];
    return [[response objectForKey:@"@type"] isEqualToString:@"ok"];
}

@end
