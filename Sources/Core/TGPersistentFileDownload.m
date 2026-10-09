#import "TGPersistentFileDownload.h"

static NSError *TGFileDownloadError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"Telegraphica.Downloads" code:code
                          userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static NSDictionary *TGFileDownloadRequest(NSNumber *fileID, BOOL start) {
    if (!start) {
        return [NSDictionary dictionaryWithObjectsAndKeys:@"getFile", @"@type", fileID, @"file_id", nil];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"downloadFile", @"@type", fileID, @"file_id", @16, @"priority",
            [NSNumber numberWithLongLong:0], @"offset", [NSNumber numberWithLongLong:0], @"limit",
            [NSNumber numberWithBool:NO], @"synchronous", nil];
}

NSString *TGPersistentFileDownload(NSNumber *fileID, NSTimeInterval requestTimeout,
                                 TGFileDownloadRequestBlock request,
                                 TGFileDownloadCancellationBlock cancelled,
                                 TGFileDownloadProgressBlock progress,
                                 TGFileDownloadClockBlock clock,
                                 TGFileDownloadWaitBlock wait,
                                 NSError **error) {
    if (error) { *error = nil; }
    if (![fileID respondsToSelector:@selector(longLongValue)] || [fileID longLongValue] <= 0 ||
        !request || !clock || !wait) {
        if (error) { *error = TGFileDownloadError(1, @"The download is not available."); }
        return nil;
    }
    NSTimeInterval rpcTimeout = MAX(0.5, MIN(5.0, requestTimeout));
    BOOL start = YES;
    long long downloadedBytes = 0, totalBytes = 0;
    NSTimeInterval lastProgress = clock();
    NSTimeInterval lastStart = -30.0;
    NSUInteger failures = 0;
    while (!cancelled || !cancelled()) {
        NSAutoreleasePool *iterationPool = [[NSAutoreleasePool alloc] init];
        BOOL isStart = start;
        if (isStart) { lastStart = clock(); lastProgress = lastStart; }
        NSError *requestError = nil;
        NSDictionary *response = request(TGFileDownloadRequest(fileID, isStart), rpcTimeout, &requestError);
        if (cancelled && cancelled()) {
            [iterationPool drain];
            return nil;
        }
        if (!response && requestError) {
            // The production TDLib adapter returns nil for protocol errors,
            // keeping the structured response/code in NSError metadata.
            id structured = [[requestError userInfo] objectForKey:@"TelegraphicaTDLibResponse"];
            if ([structured isKindOfClass:[NSDictionary class]] &&
                [[structured objectForKey:@"@type"] isEqualToString:@"error"]) {
                response = structured;
            } else {
                id protocolCode = [[requestError userInfo] objectForKey:@"TelegraphicaTDLibCode"];
                if ([protocolCode isKindOfClass:[NSNumber class]]) {
                    response = [NSDictionary dictionaryWithObjectsAndKeys:@"error", @"@type", protocolCode, @"code", nil];
                }
            }
        }
        NSString *type = [[response objectForKey:@"@type"] isKindOfClass:[NSString class]]
            ? [response objectForKey:@"@type"] : nil;
        if ([type isEqualToString:@"error"]) {
            NSInteger code = [[response objectForKey:@"code"] integerValue];
            // Explicit protocol rejection is different from no response or
            // ordinary connection/rate-limit/server failures.
            if (code >= 400 && code < 500 && code != 408 && code != 429) {
                NSError *failure = [TGFileDownloadError(code, @"Telegram cannot download this file. Please retry or check that the message still exists.") retain];
                [iterationPool drain];
                if (error) { *error = [failure autorelease]; } else { [failure release]; }
                return nil;
            }
            response = nil;
        }
        if (!response || ![type isEqualToString:@"file"]) {
            if (response) {
                NSError *failure = [TGFileDownloadError(2, @"Telegram returned an unsupported file response.") retain];
                [iterationPool drain];
                if (error) { *error = [failure autorelease]; } else { [failure release]; }
                return nil;
            }
            (void)requestError;
            failures = MIN(failures + 1, (NSUInteger)5);
            start = YES;
            if (progress) { progress(downloadedBytes, totalBytes, YES); }
            NSTimeInterval delay = MIN(10.0, (NSTimeInterval)(1U << failures));
            [iterationPool drain];
            // Small wait slices permit prompt user cancellation while offline.
            NSTimeInterval remaining = delay;
            while (remaining > 0.0 && (!cancelled || !cancelled())) {
                NSTimeInterval slice = MIN(0.25, remaining);
                wait(slice); remaining -= slice;
            }
            continue;
        }
        id responseID = [response objectForKey:@"id"];
        id localObject = [response objectForKey:@"local"];
        if (![responseID respondsToSelector:@selector(longLongValue)] ||
            [responseID longLongValue] != [fileID longLongValue] ||
            ![localObject isKindOfClass:[NSDictionary class]]) {
            NSError *failure = [TGFileDownloadError(3, @"Telegram returned an invalid file state.") retain];
            [iterationPool drain];
            if (error) { *error = [failure autorelease]; } else { [failure release]; }
            return nil;
        }
        NSDictionary *local = localObject;
        id byteCount = [local objectForKey:@"downloaded_size"];
        long long nextBytes = [byteCount respondsToSelector:@selector(longLongValue)] ? MAX(0LL, [byteCount longLongValue]) : 0LL;
        id declaredSize = [response objectForKey:@"size"];
        long long size = [declaredSize respondsToSelector:@selector(longLongValue)] ? [declaredSize longLongValue] : 0LL;
        if (size <= 0) {
            id expectedSize = [response objectForKey:@"expected_size"];
            size = [expectedSize respondsToSelector:@selector(longLongValue)] ? [expectedSize longLongValue] : 0LL;
        }
        totalBytes = MAX(0LL, size);
        if (nextBytes != downloadedBytes) { lastProgress = clock(); }
        downloadedBytes = nextBytes;
        failures = 0;
        BOOL complete = [[local objectForKey:@"is_downloading_completed"] boolValue];
        NSString *path = [[local objectForKey:@"path"] isKindOfClass:[NSString class]] ? [local objectForKey:@"path"] : nil;
        if (complete && [path length] > 0) {
            if (progress) { progress(MAX(downloadedBytes, totalBytes), totalBytes, NO); }
            NSString *result = [path copy];
            [iterationPool drain];
            return [result autorelease];
        }
        if (complete) {
            NSError *failure = [TGFileDownloadError(5, @"Telegram completed the file without a readable local path.") retain];
            [iterationPool drain];
            if (error) { *error = [failure autorelease]; } else { [failure release]; }
            return nil;
        }
        BOOL active = [[local objectForKey:@"is_downloading_active"] boolValue];
        id canDownload = [local objectForKey:@"can_be_downloaded"];
        if (!complete && !active && [canDownload respondsToSelector:@selector(boolValue)] && ![canDownload boolValue]) {
            NSError *failure = [TGFileDownloadError(4, @"This file is no longer available to download.") retain];
            [iterationPool drain];
            if (error) { *error = [failure autorelease]; } else { [failure release]; }
            return nil;
        }
        NSTimeInterval now = clock();
        start = (!active || now - lastProgress >= 30.0) && now - lastStart >= 2.0;
        if (progress) { progress(downloadedBytes, totalBytes, start); }
        [iterationPool drain];
        NSTimeInterval remaining = 1.0;
        while (remaining > 0.0 && (!cancelled || !cancelled())) {
            NSTimeInterval slice = MIN(0.25, remaining);
            wait(slice); remaining -= slice;
        }
    }
    return nil;
}
