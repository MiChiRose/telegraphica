#import <Foundation/Foundation.h>
#import "TGPersistentFileDownload.h"
#include <stdio.h>
#include <stdlib.h>

static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Persistent download probe failed: %s\n", message); exit(1); }
}

static NSDictionary *TGFile(long long downloaded, long long total, BOOL active, BOOL complete) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"file", @"@type", @77, @"id", [NSNumber numberWithLongLong:total], @"size",
            [NSDictionary dictionaryWithObjectsAndKeys:
             @"/private/tmp/mock-complete-file", @"path",
             [NSNumber numberWithLongLong:downloaded], @"downloaded_size",
             [NSNumber numberWithBool:YES], @"can_be_downloaded",
             [NSNumber numberWithBool:active], @"is_downloading_active",
             [NSNumber numberWithBool:complete], @"is_downloading_completed", nil], @"local", nil];
}

static void TGAssertFullRequest(NSDictionary *request) {
    if ([[request objectForKey:@"@type"] isEqualToString:@"downloadFile"]) {
        TGAssert(![[request objectForKey:@"synchronous"] boolValue], "start must return immediate file state");
        TGAssert([[request objectForKey:@"offset"] longLongValue] == 0 && [[request objectForKey:@"limit"] longLongValue] == 0,
                 "resumption must request the full file and leave cached chunks to TDLib");
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    __block NSTimeInterval now = 0.0;
    __block NSUInteger requests = 0, starts = 0;
    __block long long lastBytes = 0;
    long long total = 5LL * 1024LL * 1024LL * 1024LL;
    NSError *error = nil;
    NSString *result = TGPersistentFileDownload(@77, 45.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            (void)requestError;
            TGAssert(timeout <= 5.0, "RPC timeout must remain bounded independently of transfer size");
            TGAssertFullRequest(request);
            requests++;
            if ([[request objectForKey:@"@type"] isEqualToString:@"downloadFile"]) { starts++; }
            long long bytes = MIN(total, (long long)now * 64LL * 1024LL * 1024LL);
            return TGFile(bytes, total, bytes < total, bytes == total);
        }, nil,
        ^(long long bytes, long long size, BOOL reconnecting) {
            (void)reconnecting; TGAssert(size == total, "5GB total must retain all 64bit bytes"); lastBytes = bytes;
        }, ^NSTimeInterval { return now; }, ^(NSTimeInterval seconds) { now += seconds; }, &error);
    TGAssert(result != nil && error == nil && now >= 80.0 && requests > 15 && starts == 1,
             "healthy transfer longer than old 15/45-second limits must complete without repeated restarts");
    TGAssert(lastBytes == total, "5GB completion progress must not overflow or round through int32");

    now = 0; requests = 0; starts = 0;
    result = TGPersistentFileDownload(@77, 3.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            (void)timeout; requests++; TGAssertFullRequest(request);
            if ([[request objectForKey:@"@type"] isEqualToString:@"downloadFile"]) { starts++; }
            if (requests <= 2) {
                if (requestError) { *requestError = [NSError errorWithDomain:@"Mock" code:56 userInfo:nil]; }
                return nil;
            }
            if (starts < 4) { return TGFile(512LL * 1024LL * 1024LL, total, NO, NO); }
            return TGFile(total, total, NO, YES);
        }, nil, nil, ^NSTimeInterval { return now; }, ^(NSTimeInterval seconds) { now += seconds; }, &error);
    TGAssert(result != nil && error == nil && starts == 4,
             "RPC timeouts and inactive partial downloads must resume to completion");

    now = 0; requests = 0; starts = 0;
    result = TGPersistentFileDownload(@77, 3.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            (void)timeout; (void)requestError; requests++; TGAssertFullRequest(request);
            if ([[request objectForKey:@"@type"] isEqualToString:@"downloadFile"]) { starts++; }
            return starts >= 2 ? TGFile(total, total, NO, YES) : TGFile(4096, total, YES, NO);
        }, nil, nil, ^NSTimeInterval { return now; }, ^(NSTimeInterval seconds) { now += seconds; }, &error);
    TGAssert(result != nil && now >= 30.0 && starts == 2,
             "active transfer with no progress must reassert its full-file request after stall");

    now = 0; requests = 0;
    result = TGPersistentFileDownload(@77, 3.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            (void)request; (void)timeout; (void)requestError; requests++; return nil;
        }, ^BOOL { return now >= 0.75; }, nil, ^NSTimeInterval { return now; },
        ^(NSTimeInterval seconds) { now += seconds; }, &error);
    TGAssert(result == nil && error == nil && requests == 1 && now <= 1.0,
             "cancellation during reconnect backoff must stop before another request");

    now = 0; requests = 0;
    result = TGPersistentFileDownload(@77, 3.0,
        ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
            (void)request; (void)timeout; (void)requestError; requests++;
            return [NSDictionary dictionaryWithObjectsAndKeys:@"error", @"@type", @400, @"code", nil];
        }, nil, nil, ^NSTimeInterval { return now; }, ^(NSTimeInterval seconds) { now += seconds; }, &error);
    TGAssert(result == nil && error != nil && requests == 1, "permanent protocol rejection must fail without an infinite retry");
    // Production request adapter returns nil and embeds Telegram errors.
    for (NSNumber *code in [NSArray arrayWithObjects:@400, @408, @429, @500, nil]) {
        now = 0; requests = 0;
        result = TGPersistentFileDownload(@77, 3.0,
            ^NSDictionary *(NSDictionary *request, NSTimeInterval timeout, NSError **requestError) {
                (void)request; (void)timeout; requests++;
                if (requests > 1) { return TGFile(total, total, NO, YES); }
                NSDictionary *protocolError = [NSDictionary dictionaryWithObjectsAndKeys:@"error", @"@type", code, @"code", nil];
                if (requestError) {
                    *requestError = [NSError errorWithDomain:@"TelegraphicaTDLib" code:56 userInfo:
                        [NSDictionary dictionaryWithObjectsAndKeys:code, @"TelegraphicaTDLibCode", protocolError, @"TelegraphicaTDLibResponse", nil]];
                }
                return nil;
            }, nil, nil, ^NSTimeInterval { return now; }, ^(NSTimeInterval seconds) { now += seconds; }, &error);
        if ([code integerValue] == 400) {
            TGAssert(!result && error && requests == 1, "nil+structured permanent error must not retry forever");
        } else {
            TGAssert(result && !error && requests == 2, "nil+structured transient protocol error must recover");
        }
    }
    puts("Persistent file download probe passed.");
    [pool drain]; return 0;
}
