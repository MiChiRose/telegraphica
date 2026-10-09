#import <Foundation/Foundation.h>
#import "TGChatItem.h"

static void Require(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Notification enrichment failure: %s\n", message); exit(1); }
}

@interface TGTDLibClient : NSObject
@property (nonatomic, retain) NSMutableArray *chats;
- (NSDictionary *)chatSummaryForChatID:(NSNumber *)chatID downloadAvatar:(BOOL)avatar timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end
@implementation TGTDLibClient
@synthesize chats = _chats;
- (id)init { if ((self=[super init])) _chats=[[NSMutableArray alloc] init]; return self; }
- (void)dealloc { [_chats release]; [super dealloc]; }
- (NSDictionary *)chatSummaryForChatID:(NSNumber *)chatID downloadAvatar:(BOOL)avatar timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)error;
    Require(avatar && timeout == 1.2, "existing bounded enrichment behavior is preserved");
    [_chats addObject:chatID];
    return [NSDictionary dictionaryWithObjectsAndKeys:@"synthetic title", @"title", @NO, @"notifications_muted", nil];
}
@end

@interface NotificationProbeController : NSObject
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSMutableDictionary *notificationChatInfoByChatID;
@property (nonatomic, retain) NSDictionary *request, *result;
- (void)appendDetail:(NSString *)detail;
- (void)requestNotificationChatInfoFetchForChatID:(NSNumber *)chatID cacheKey:(NSString *)cacheKey;
- (void)fetchNotificationChatInfoInBackground:(NSDictionary *)request;
- (void)applyFetchedNotificationChatInfo:(NSDictionary *)result;
- (NSString *)notificationCacheKeyForChatID:(NSNumber *)chatID;
- (TGChatItem *)chatItemForNotificationChatID:(NSNumber *)chatID;
- (NSDictionary *)notificationChatInfoForChatID:(NSNumber *)chatID;
@end
@implementation NotificationProbeController
@synthesize client = _client, notificationChatInfoByChatID = _notificationChatInfoByChatID;
@synthesize request = _request, result = _result;
- (id)init {
    if ((self=[super init])) {
        _client=[[TGTDLibClient alloc] init]; _notificationChatInfoByChatID=[[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc { [_client release]; [_notificationChatInfoByChatID release]; [_request release]; [_result release]; [super dealloc]; }
- (void)setClient:(TGTDLibClient *)client {
    if (_client != client) {
        // The source-routing probe checks this lifecycle reset in the real
        // controller; exercise its effect on the production method group here.
        [self.notificationChatInfoByChatID removeAllObjects];
        [_client release]; _client = [client retain];
    }
}
- (void)appendDetail:(NSString *)detail { (void)detail; }
- (NSString *)notificationCacheKeyForChatID:(NSNumber *)chatID { return [chatID stringValue]; }
- (TGChatItem *)chatItemForNotificationChatID:(NSNumber *)chatID { (void)chatID; return nil; }
- (void)performSelectorInBackground:(SEL)selector withObject:(id)object {
    Require(selector == @selector(fetchNotificationChatInfoInBackground:), "unexpected background selector");
    self.request = object;
}
- (void)performSelectorOnMainThread:(SEL)selector withObject:(id)object waitUntilDone:(BOOL)wait {
    Require(selector == @selector(applyFetchedNotificationChatInfo:) && !wait, "enrichment completion must remain asynchronous");
    self.result = object;
}
#include "../Sources/UI/TGStatusWindowController+NotificationChatInfo.inc"
@end

static NotificationProbeController *Controller(void) {
    return [[[NotificationProbeController alloc] init] autorelease];
}

int main(void) {
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    NotificationProbeController *c=Controller();
    [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    NSDictionary *first=[[[c request] copy] autorelease];
    [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    Require([first isEqual:c.request], "duplicate pending enrichment does not replace request");
    [c fetchNotificationChatInfoInBackground:first]; [c applyFetchedNotificationChatInfo:c.result];
    NSDictionary *cached=[c.notificationChatInfoByChatID objectForKey:@"-100"];
    Require([[cached objectForKey:@"fetch_complete"] boolValue] &&
        [[cached objectForKey:@"title"] isEqual:@"synthetic title"] && ![cached objectForKey:@"fetch_request_id"],
        "matching live request updates cache and releases pending identity");

    c=Controller();
    [c.notificationChatInfoByChatID setObject:[NSDictionary dictionaryWithObject:@"existing title" forKey:@"title"] forKey:@"-100"];
    [c notificationChatInfoForChatID:@-100];
    first=[[[c request] copy] autorelease];
    Require([[[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"fetch_request_id"]
        isEqual:[first objectForKey:@"requestID"]], "presentation cache merge retains pending fetch identity");
    [c notificationChatInfoForChatID:@-100];
    [c fetchNotificationChatInfoInBackground:first]; [c applyFetchedNotificationChatInfo:c.result];
    Require([[[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"fetch_complete"] boolValue],
        "real presentation lookup does not strand pending avatar/chat enrichment");

    c=Controller(); [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    first=[[[c request] copy] autorelease]; TGTDLibClient *oldClient=[[[c client] retain] autorelease];
    c.client=[[[TGTDLibClient alloc] init] autorelease];
    [c fetchNotificationChatInfoInBackground:first]; [c applyFetchedNotificationChatInfo:c.result];
    Require([oldClient.chats count] == 1 && [c.client.chats count] == 0,
        "queued background fetch uses original owner without querying replacement account");
    Require(![[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"title"],
        "old client completion cannot populate replacement-account notification cache");
    [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    NSDictionary *replacementRequest=[[[c request] copy] autorelease];
    Require([replacementRequest objectForKey:@"client"] == c.client &&
        ![[replacementRequest objectForKey:@"requestID"] isEqual:[first objectForKey:@"requestID"]],
        "replacement client can fetch again without a stranded old-owner pending token");
    [c applyFetchedNotificationChatInfo:c.result];
    Require([[[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"fetch_request_id"]
        isEqual:[replacementRequest objectForKey:@"requestID"]],
        "late old-client completion cannot clear replacement-owner pending token");
    [c fetchNotificationChatInfoInBackground:replacementRequest]; [c applyFetchedNotificationChatInfo:c.result];
    Require([c.client.chats count] == 1 &&
        [[[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"fetch_complete"] boolValue],
        "replacement owner successfully completes fresh enrichment after the lifecycle reset");

    c=Controller(); [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    first=[[[c request] copy] autorelease];
    [c.notificationChatInfoByChatID removeAllObjects];
    [c fetchNotificationChatInfoInBackground:first]; [c applyFetchedNotificationChatInfo:c.result];
    Require([c.notificationChatInfoByChatID count] == 0,
        "explicit logout cache clear cannot be undone by a late in-flight fetch");
    [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    NSDictionary *second=[[[c request] copy] autorelease];
    [c applyFetchedNotificationChatInfo:c.result];
    Require(![[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"title"],
        "old same-client result cannot replace a new pending request after reset");
    [c fetchNotificationChatInfoInBackground:second]; [c applyFetchedNotificationChatInfo:c.result];
    Require([[[c.notificationChatInfoByChatID objectForKey:@"-100"] objectForKey:@"fetch_complete"] boolValue],
        "new pending request remains usable after stale result was ignored");

    c=Controller(); c.client=nil;
    [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    Require(!c.request && [c.notificationChatInfoByChatID count] == 0,
        "detached controller cannot enqueue notification account work");

    c=Controller(); [c requestNotificationChatInfoFetchForChatID:@-100 cacheKey:@"-100"];
    NSMutableDictionary *failure=[NSMutableDictionary dictionaryWithDictionary:c.request];
    [failure setObject:@"synthetic failure" forKey:@"error"];
    [c applyFetchedNotificationChatInfo:failure];
    cached=[c.notificationChatInfoByChatID objectForKey:@"-100"];
    Require(![cached objectForKey:@"fetch_pending"] && ![cached objectForKey:@"fetch_request_id"] &&
        ![cached objectForKey:@"fetch_complete"] && [cached objectForKey:@"fetch_retry_after"],
        "current-owner failure releases pending identity and preserves bounded retry behavior");
    puts("Notification enrichment production integration probe passed: captured owner, request identity, logout clear and replacement rejection.");
    [pool drain]; return 0;
}
