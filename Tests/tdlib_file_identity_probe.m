#import <Foundation/Foundation.h>
#import "TGTDLibClient+Files.h"
#include <stdio.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TGTDLibClient
@end
#pragma clang diagnostic pop

@interface TGIdentityProbeClient : TGTDLibClient
@property (nonatomic, retain) NSMutableArray *requests;
@property (nonatomic, retain) id response;
@property (nonatomic, retain) NSError *failure;
@property (nonatomic, assign) NSTimeInterval lastTimeout;
@end
@implementation TGIdentityProbeClient
@synthesize requests, response, failure, lastTimeout;
- (id)init { if ((self = [super init])) { requests = [[NSMutableArray alloc] init]; } return self; }
- (void)dealloc { [requests release]; [response release]; [failure release]; [super dealloc]; }
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)prefix
    timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    (void)prefix; (void)errorCode; [requests addObject:request]; lastTimeout = timeout;
    if (error) { *error = failure; } return response;
}
- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    return [NSError errorWithDomain:@"TGIdentityProbe" code:code userInfo:
        [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey]];
}
@end
static void Require(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "File identity probe failed: %s\n", message); exit(1); }
}
static NSMutableDictionary *File(NSNumber *fileID, NSString *remoteID) {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"file", @"@type", fileID, @"id",
        [NSDictionary dictionaryWithObjectsAndKeys:@"localFile", @"@type", @"", @"path",
            [NSNumber numberWithBool:NO], @"is_downloading_completed", nil], @"local",
        [NSDictionary dictionaryWithObjectsAndKeys:@"remoteFile", @"@type", remoteID, @"id",
            @"synthetic-unique", @"unique_id", nil], @"remote", nil];
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGIdentityProbeClient *client = [[[TGIdentityProbeClient alloc] init] autorelease];
    NSError *error = [NSError errorWithDomain:@"stale" code:1 userInfo:nil];
    client.response = File(@77, @"synthetic-remote");
    NSDictionary *file = [client downloadFileIdentityForFileID:@77 remoteFileID:nil error:&error];
    Require(file == client.response && !error, "getFile returns initial metadata and clears stale error");
    NSDictionary *request = [client.requests lastObject];
    Require([[request objectForKey:@"@type"] isEqual:@"getFile"] &&
        [[request objectForKey:@"file_id"] isEqual:@77] && client.lastTimeout == 3.0,
        "initial lookup captures exact numeric ID with bounded 3s RPC");

    client.response = File(@901, @"synthetic-canonical-alias");
    file = [client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error];
    request = [client.requests lastObject];
    Require([[file objectForKey:@"id"] isEqual:@901] && !error, "stable remote identity resolves to new numeric ID after restart");
    Require([[request objectForKey:@"@type"] isEqual:@"getRemoteFile"] &&
        [[request objectForKey:@"remote_file_id"] isEqual:@"synthetic-remote"] &&
        [[[request objectForKey:@"file_type"] objectForKey:@"@type"] isEqual:@"fileTypeUnknown"] &&
        ![request objectForKey:@"file_id"] && client.lastTimeout == 3.0,
        "remote lookup never sends stale numeric ID and accepts canonical aliases");

    NSUInteger count = [client.requests count];
    Require(![client downloadFileIdentityForFileID:@0 remoteFileID:nil error:&error] && error,
        "missing numeric identity rejected before RPC");
    Require(![client downloadFileIdentityForFileID:@1.5 remoteFileID:@"" error:&error] && error,
        "fractional numeric identity rejected before RPC");
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:(id)@1 error:&error] && error &&
        [client.requests count] == count, "malformed remote identity cannot start request");

    client.response = File(@901, @"synthetic-remote");
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:nil error:&error] && error,
        "getFile cannot accept unrelated numeric response");
    for (NSNumber *badID in [NSArray arrayWithObjects:@0, @-1, @2147483648LL, @1.5, nil]) {
        client.response = File(badID, @"synthetic-remote");
        Require(![client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error] && error,
            "remote resolver validates positive int32 response ID");
    }
    NSMutableDictionary *bad = File(@901, @"synthetic-remote");
    [bad setObject:[NSArray array] forKey:@"local"]; client.response = bad;
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error] && error,
        "malformed local state rejected without crash");
    bad = File(@901, @""); client.response = bad;
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error] && error,
        "remote resolution must return usable stable remote metadata");
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"error", @"@type", @400, @"code", nil];
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error] && error,
        "protocol response is not a file identity");
    client.response = nil;
    client.failure = [NSError errorWithDomain:@"TDLib" code:400 userInfo:
        [NSDictionary dictionaryWithObject:@"private remote sentinel" forKey:NSLocalizedDescriptionKey]];
    Require(![client downloadFileIdentityForFileID:@77 remoteFileID:@"synthetic-remote" error:&error] &&
        [error code] == 400 && [[error localizedDescription] rangeOfString:@"sentinel"].location == NSNotFound,
        "RPC failure preserves code but never exposes raw remote identifier");
    client.failure = nil;
    client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"user", @"@type", @1234567890123LL, @"id", nil];
    NSNumber *account = [client downloadAccountIDWithError:&error];
    request = [client.requests lastObject];
    Require([account isEqual:@1234567890123LL] && !error && [[request objectForKey:@"@type"] isEqual:@"getMe"] &&
        [request count] == 1 && client.lastTimeout == 3.0, "download owner lookup is bounded getMe without profile or avatar requests");
    client.response = File(@77, @"synthetic-remote");
    Require(![client downloadAccountIDWithError:&error] && error, "getMe rejects mismatched response type");
    for (id invalid in [NSArray arrayWithObjects:@0, @-1, @1.5, @9007199254740992LL, @"123", [NSArray array], nil]) {
        client.response = [NSDictionary dictionaryWithObjectsAndKeys:@"user", @"@type", invalid, @"id", nil];
        Require(![client downloadAccountIDWithError:&error] && error, "getMe rejects nonpositive or malformed account IDs");
    }
    client.response = nil;
    Require(![client downloadAccountIDWithError:&error] && error, "getMe missing response returns explicit error");
    puts("TDLib file identity probe passed."); [pool drain]; return 0;
}
