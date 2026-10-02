#import <Cocoa/Cocoa.h>
#import "TGLogger.h"
#include <stdio.h>

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *inputs = [NSArray arrayWithObjects:
                       @"Connected", @"API_HASH=sample", @"Downloaded to /tmp/private.png",
                       @"Downloaded cached fallback to /tmp/private.png", @"Submitting Photo to TDLib: /tmp/private.png",
                       @"title: private, preview=secret", @"chat_id=1234; message id 5678",
                       @"https://example.invalid/?token=secret&hash=private", @"contact +1 234 567 8901",
                       @"abcdabcdabcdabcdabcdabcdabcdabcd", @"/Users/example/Private/file.png", @"count 12345", nil];
    NSArray *expected = [NSArray arrayWithObjects:
                         @"Connected", @"<redacted sensitive log line>", @"Downloaded to <redacted-path>",
                         @"Downloaded cached fallback to <redacted-path>", @"Submitting Photo to TDLib: <redacted-file>",
                         @"title=<redacted>, preview=<redacted>", @"chat_id=<redacted-id>; message id=<redacted-id>",
                         @"https://example.invalid/?token=<redacted>&hash=<redacted>", @"contact <redacted-number>",
                         @"<redacted-token>", @"<redacted-path>", @"count <redacted-number>", nil];
    if (![[TGLogger redactedDiagnosticMessage:nil] isEqualToString:@""]) return 1;
    __block NSUInteger failures = 0;
    dispatch_group_t group = dispatch_group_create();
    NSUInteger worker = 0;
    for (worker = 0; worker < 8; worker++) {
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSAutoreleasePool *threadPool = [[NSAutoreleasePool alloc] init];
            NSUInteger repeat = 0;
            for (repeat = 0; repeat < 100; repeat++) {
                NSUInteger index = 0;
                for (index = 0; index < [inputs count]; index++) {
                    NSString *output = [TGLogger redactedDiagnosticMessage:[inputs objectAtIndex:index]];
                    if (![output isEqualToString:[expected objectAtIndex:index]]) {
                        @synchronized(expected) { failures++; }
                    }
                }
            }
            [threadPool drain];
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
    if (failures) fprintf(stderr, "Logger redaction probe failed: %lu mismatches\n", (unsigned long)failures);
    else puts("Logger redaction probe passed (concurrent cached expressions).");
    [pool drain];
    return failures ? 1 : 0;
}
