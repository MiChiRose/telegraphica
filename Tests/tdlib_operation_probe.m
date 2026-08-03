#import <Foundation/Foundation.h>
#import "../Sources/Core/TGTDLibOperation.h"
#include <unistd.h>

static void TGAssert(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "TDLib operation probe failed: %s\n", message);
        exit(1);
    }
}

static void TGRunMainLoop(NSTimeInterval duration) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:duration];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    __block NSUInteger completionCount = 0U;
    TGTDLibOperation *success = [[[TGTDLibOperation alloc]
        initWithGeneration:7U timeout:1.0 idempotent:YES maximumRetryCount:0U
        work:^id(NSError **error) { (void)error; return @"ok"; }
        generationCheck:^BOOL(NSUInteger generation) { return generation == 7U; }
        completion:^(id result, NSError *error) {
            TGAssert([result isEqual:@"ok"] && error == nil, "success result must be delivered on main");
            TGAssert([NSThread isMainThread], "completion must run on main thread");
            completionCount++;
        }] autorelease];
    [success start];
    [success start];
    TGRunMainLoop(0.15);
    TGAssert(completionCount == 1U, "starting twice must still complete exactly once");

    __block NSUInteger retryAttempts = 0U;
    __block BOOL retryDelivered = NO;
    TGTDLibOperation *retry = [[[TGTDLibOperation alloc]
        initWithGeneration:1U timeout:1.0 idempotent:YES maximumRetryCount:1U
        work:^id(NSError **error) {
            retryAttempts++;
            if (retryAttempts == 1U) {
                *error = [TGTDLibOperation retryableErrorWithDescription:@"temporary" code:9];
                return nil;
            }
            return @"retried";
        }
        generationCheck:nil
        completion:^(id result, NSError *error) {
            retryDelivered = ([result isEqual:@"retried"] && error == nil);
        }] autorelease];
    [retry start];
    TGRunMainLoop(0.15);
    TGAssert(retryAttempts == 2U && retryDelivered, "idempotent retry must be bounded to one retry");

    __block NSUInteger nonIdempotentAttempts = 0U;
    __block BOOL nonIdempotentFinished = NO;
    TGTDLibOperation *nonIdempotent = [[[TGTDLibOperation alloc]
        initWithGeneration:1U timeout:1.0 idempotent:NO maximumRetryCount:1U
        work:^id(NSError **error) {
            nonIdempotentAttempts++;
            *error = [TGTDLibOperation retryableErrorWithDescription:@"do not retry" code:10];
            return nil;
        }
        generationCheck:nil
        completion:^(id result, NSError *error) {
            nonIdempotentFinished = (result == nil && error != nil);
        }] autorelease];
    [nonIdempotent start];
    TGRunMainLoop(0.15);
    TGAssert(nonIdempotentAttempts == 1U && nonIdempotentFinished,
             "non-idempotent work must never retry automatically");

    __block BOOL cancelledCallback = NO;
    TGTDLibOperation *cancelled = [[[TGTDLibOperation alloc]
        initWithGeneration:1U timeout:0.5 idempotent:YES maximumRetryCount:0U
        work:^id(NSError **error) { (void)error; usleep(60000); return @"late"; }
        generationCheck:nil
        completion:^(id result, NSError *error) { (void)result; (void)error; cancelledCallback = YES; }] autorelease];
    [cancelled start];
    [cancelled cancel];
    TGRunMainLoop(0.15);
    TGAssert(!cancelledCallback, "cancelled owner must not receive callbacks");

    __block BOOL staleCallback = NO;
    TGTDLibOperation *stale = [[[TGTDLibOperation alloc]
        initWithGeneration:4U timeout:0.5 idempotent:YES maximumRetryCount:0U
        work:^id(NSError **error) { (void)error; return @"stale"; }
        generationCheck:^BOOL(NSUInteger generation) { return generation == 5U; }
        completion:^(id result, NSError *error) { (void)result; (void)error; staleCallback = YES; }] autorelease];
    [stale start];
    TGRunMainLoop(0.15);
    TGAssert(!staleCallback, "stale generation must suppress completion");

    __block NSUInteger timeoutCallbackCount = 0U;
    TGTDLibOperation *timedOut = [[[TGTDLibOperation alloc]
        initWithGeneration:1U timeout:0.5 idempotent:YES maximumRetryCount:0U
        work:^id(NSError **error) { (void)error; usleep(700000); return @"too late"; }
        generationCheck:nil
        completion:^(id result, NSError *error) {
            TGAssert(result == nil, "timed-out operation must not deliver a late result");
            TGAssert([[error domain] isEqualToString:TGTDLibOperationErrorDomain] && [error code] == 2,
                     "timed-out operation must deliver its normalized timeout error");
            timeoutCallbackCount++;
        }] autorelease];
    [timedOut start];
    TGRunMainLoop(0.62);
    TGAssert(timeoutCallbackCount == 1U, "timeout and worker completion must share one completion gate");

    fprintf(stdout, "TDLib operation probe passed.\n");
    [pool drain];
    return 0;
}
