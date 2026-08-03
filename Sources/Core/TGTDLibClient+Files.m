#import "TGTDLibClient+Files.h"

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
