#import <Foundation/Foundation.h>
#import "TGChatOpenState.h"
#include <stdio.h>

static void TGAssert(BOOL value, const char *description) {
    if (!value) { fprintf(stderr, "Chat open state probe: %s\n", description); exit(1); }
}

static void TGAssertRequest(NSArray *requests, NSUInteger index, NSString *type, long long chatID) {
    TGAssert(index < [requests count], "expected chat visibility request is missing");
    NSDictionary *request = [requests objectAtIndex:index];
    TGAssert([[request objectForKey:@"@type"] isEqual:type] &&
        [[request objectForKey:@"chat_id"] longLongValue] == chatID, "request type, identifier or ordering is wrong");
}

static NSDictionary *TGResponse(NSDictionary *openRequest, NSInteger code) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        (code ? @"error" : @"ok"), @"@type", [NSNumber numberWithInteger:code], @"code",
        [openRequest objectForKey:@"@extra"], @"@extra", nil];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGChatOpenState *state = [[[TGChatOpenState alloc] init] autorelease];
    TGAssert([[state requestsForCurrentSelection] count] == 0, "an unselected or unauthenticated client must never implicitly open a chat");
    [state setDesiredChatID:@1];
    NSArray *requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "first selection must open exactly one chat");
    TGAssertRequest(requests, 0, @"openChat", 1);
    [state handleOpenResponse:TGResponse([requests objectAtIndex:0], 0)];
    [state setDesiredChatID:@2];
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 2, "switching conversations must close the previous owner before opening the next");
    TGAssertRequest(requests, 0, @"closeChat", 1);
    TGAssertRequest(requests, 1, @"openChat", 2);
    [state setDesiredChatID:nil];
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "closing conversation must release its live update subscription");
    TGAssertRequest(requests, 0, @"closeChat", 2);

    // The dispatch queue reads the current desired selection, rather than the
    // identifier captured when an earlier navigation enqueued its work.
    [state setDesiredChatID:@1];
    [state setDesiredChatID:@2];
    [state setDesiredChatID:@3];
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "rapid navigation must coalesce to its current selection");
    TGAssertRequest(requests, 0, @"openChat", 3);
    TGAssert([[state requestsForCurrentSelection] count] == 0, "topic changes or duplicate layout refresh must not close/reopen the same parent chat");

    [state setDesiredChatID:nil]; [state requestsForCurrentSelection];
    TGAssert([[state requestsForCurrentSelection] count] == 0, "not-ready authorization must leave the transport without an opened conversation");
    [state setDesiredChatID:@3];
    TGAssertRequest([state requestsForCurrentSelection], 0, @"openChat", 3);
    [state resetTransport];
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "a replacement or recreated client must reopen an unchanged selection");
    TGAssertRequest(requests, 0, @"openChat", 3);
    [state setDesiredChatID:@-100123];
    requests = [state requestsForCurrentSelection];
    TGAssertRequest(requests, 0, @"closeChat", 3);
    TGAssertRequest(requests, 1, @"openChat", -100123);
    [state setDesiredChatID:@-200456]; // linked discussion destination
    requests = [state requestsForCurrentSelection];
    TGAssertRequest(requests, 0, @"closeChat", -100123);
    TGAssertRequest(requests, 1, @"openChat", -200456);
    [state setDesiredChatID:@-100123]; // return to channel
    requests = [state requestsForCurrentSelection];
    TGAssertRequest(requests, 0, @"closeChat", -200456);
    TGAssertRequest(requests, 1, @"openChat", -100123);

    NSDictionary *oldOpen = [requests objectAtIndex:1];
    [state setDesiredChatID:@2]; [state requestsForCurrentSelection];
    [state setDesiredChatID:@-100123];
    requests = [state requestsForCurrentSelection];
    NSDictionary *newOpen = [requests objectAtIndex:1];
    TGAssert(![[oldOpen objectForKey:@"@extra"] isEqual:[newOpen objectForKey:@"@extra"]], "reopening the same chat must use a fresh acknowledgement token");
    TGAssert(![state handleOpenResponse:TGResponse(oldOpen, 500)], "stale first-A error must not retry or clear a renewed A subscription");
    TGAssert([[state requestsForCurrentSelection] count] == 0, "stale acknowledgement must preserve the current opened conversation");
    TGAssert([state handleOpenResponse:TGResponse(newOpen, 500)], "transient open errors must permit a bounded retry");
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "retry must reopen the selected chat without sending an unrelated close");
    TGAssertRequest(requests, 0, @"openChat", -100123);
    TGAssert([state handleOpenResponse:TGResponse([requests objectAtIndex:0], 429)], "second transient failure must permit the final retry");
    requests = [state requestsForCurrentSelection];
    TGAssert(![state handleOpenResponse:TGResponse([requests objectAtIndex:0], 500)], "failed retries must be bounded");
    TGAssert([[state requestsForCurrentSelection] count] == 0, "exhausted retry budget must not spin on each visibility refresh");
    [state resetTransport];
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "re-authentication reset must restore the retry budget");
    TGAssert(![state handleOpenResponse:TGResponse([requests objectAtIndex:0], 400)], "permanent open failures must not automatically retry");
    TGAssert([[state requestsForCurrentSelection] count] == 0, "unsupported requests must remain blocked until selection or transport changes");

    [state setDesiredChatID:@1];
    requests = [state requestsForCurrentSelection];
    oldOpen = [requests objectAtIndex:0];
    [state setDesiredChatID:@2];
    TGAssert(![state handleOpenResponse:TGResponse(oldOpen, 400)], "old-chat permanent error must not trigger a retry for the new selection");
    requests = [state requestsForCurrentSelection];
    TGAssert([requests count] == 1, "old-chat permanent failure must not consume the new selection's retry budget");
    TGAssertRequest(requests, 0, @"openChat", 2);
    [state setDesiredChatID:@0];
    TGAssertRequest([state requestsForCurrentSelection], 0, @"closeChat", 2);
    TGAssert([[state requestsForCurrentSelection] count] == 0, "zero chat identifier must normalize to a closed conversation");

    // A replacement client owns its own subscription, while the old owner
    // closes asynchronously. Neither transition can alter the other's state.
    TGChatOpenState *replacement = [[[TGChatOpenState alloc] init] autorelease];
    [state setDesiredChatID:@7]; [state requestsForCurrentSelection];
    [state setDesiredChatID:nil];
    [replacement setDesiredChatID:@7];
    TGAssertRequest([replacement requestsForCurrentSelection], 0, @"openChat", 7);
    TGAssertRequest([state requestsForCurrentSelection], 0, @"closeChat", 7);
    TGAssert([[replacement requestsForCurrentSelection] count] == 0, "closing the old client must not close its replacement's conversation");
    [pool drain];
    puts("Chat open state probe passed: ordered ownership, coalescing, authorization, discussion navigation, reset and bounded errors.");
    return 0;
}
