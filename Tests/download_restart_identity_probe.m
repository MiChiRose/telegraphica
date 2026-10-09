// Reuse the account-free manager fixtures, but run focused restart scenarios.
#define main TGUnusedPauseFixtureMain
#include "download_pause_probe.m"
#undef main

@interface TGRestartIdentityClient : TGPauseProbeClient {
    NSNumber *_ownerID;
    NSString *_canonicalUnique;
    NSMutableArray *_downloadIDs, *_cancelIDs;
    NSUInteger _identityRequests, _accountRequests;
    BOOL _hangRemapped, _holdIdentity, _releaseIdentity;
}
@property (nonatomic, retain) NSNumber *ownerID;
@property (nonatomic, copy) NSString *canonicalUnique;
@property (nonatomic, assign) BOOL hangRemapped, holdIdentity, releaseIdentity;
- (NSUInteger)identityRequests;
- (NSUInteger)accountRequests;
- (NSUInteger)downloadsFor:(NSNumber *)fileID;
- (NSArray *)cancelIDs;
@end
@implementation TGRestartIdentityClient
@synthesize ownerID = _ownerID, canonicalUnique = _canonicalUnique;
- (id)init {
    if ((self = [super init])) {
        _downloadIDs = [[NSMutableArray alloc] init]; _cancelIDs = [[NSMutableArray alloc] init];
        self.ownerID = @1; self.canonicalUnique = @"unique-A";
    }
    return self;
}
- (void)dealloc { [_ownerID release]; [_canonicalUnique release]; [_downloadIDs release]; [_cancelIDs release]; [super dealloc]; }
- (BOOL)hangRemapped { @synchronized(self) { return _hangRemapped; } }
- (void)setHangRemapped:(BOOL)value { @synchronized(self) { _hangRemapped = value; } }
- (BOOL)holdIdentity { @synchronized(self) { return _holdIdentity; } }
- (void)setHoldIdentity:(BOOL)value { @synchronized(self) { _holdIdentity = value; } }
- (BOOL)releaseIdentity { @synchronized(self) { return _releaseIdentity; } }
- (void)setReleaseIdentity:(BOOL)value { @synchronized(self) { _releaseIdentity = value; } }
- (NSUInteger)identityRequests { @synchronized(self) { return _identityRequests; } }
- (NSUInteger)accountRequests { @synchronized(self) { return _accountRequests; } }
- (NSUInteger)downloadsFor:(NSNumber *)fileID {
    @synchronized(self) { NSUInteger count = 0; for (NSNumber *value in _downloadIDs) { if ([value isEqual:fileID]) { count++; } } return count; }
}
- (NSArray *)cancelIDs { @synchronized(self) { return [NSArray arrayWithArray:_cancelIDs]; } }
- (NSNumber *)downloadAccountIDWithError:(NSError **)error {
    (void)error; @synchronized(self) { _accountRequests++; } return self.ownerID;
}
- (NSDictionary *)downloadFileIdentityForFileID:(NSNumber *)fileID remoteFileID:(NSString *)remoteID error:(NSError **)error {
    (void)error; @synchronized(self) { _identityRequests++; }
    while (self.holdIdentity && !self.releaseIdentity) { [NSThread sleepForTimeInterval:0.005]; }
    NSNumber *resolved = [remoteID length] > 0 ? @900 : fileID;
    NSString *stable = [remoteID length] > 0 ? @"canonical-A" : [NSString stringWithFormat:@"fresh-%@", fileID];
    NSString *unique = [remoteID length] > 0 ? self.canonicalUnique : [NSString stringWithFormat:@"fresh-unique-%@", fileID];
    return [NSDictionary dictionaryWithObjectsAndKeys:@"file", @"@type", resolved, @"id",
            [NSDictionary dictionaryWithObjectsAndKeys:stable, @"id", unique, @"unique_id", nil], @"remote", nil];
}
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID cancelled:(TGFileDownloadCancellationBlock)cancelled
                                          progress:(TGFileDownloadProgressBlock)progress error:(NSError **)error {
    (void)error;
    @synchronized(self) { [_downloadIDs addObject:fileID]; }
    if (progress) { progress(64LL * 1024LL * 1024LL, 5LL * 1024LL * 1024LL * 1024LL, NO); }
    if ([fileID isEqual:@900] && self.hangRemapped) {
        while (!cancelled()) { [NSThread sleepForTimeInterval:0.005]; }
        return nil;
    }
    return self.sourcePath;
}
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    @synchronized(self) { [_cancelIDs addObject:fileID]; }
    return [super cancelDownloadForFileID:fileID timeout:timeout error:error];
}
@end

static NSMutableDictionary *TGRestartRecord(NSString *state) {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:@"old-job", @"identifier", @"fixture.zip", @"file_name",
            state, @"state", @77, @"file_id", @"alias-A", @"remote_id", @"unique-A", @"remote_unique_id", @1, @"account_id", nil];
}
static TGDownloadManager *TGRestore(NSDictionary *record, TGRestartIdentityClient *client) {
    [[NSUserDefaults standardUserDefaults] setObject:TGDownloadQueueSerializableRecords([NSArray arrayWithObject:record])
                                             forKey:TGDownloadQueueRecordsDefaultsKey];
    TGDownloadManager *manager = [[[TGDownloadManager alloc] init] autorelease]; [manager setClient:client]; return manager;
}
static void TGWaitDownloads(TGRestartIdentityClient *client, NSNumber *fileID, NSUInteger count) {
    for (NSUInteger n = 0; n < 200 && [client downloadsFor:fileID] < count; n++) { TGWait(0.005); }
    TGAssert([client downloadsFor:fileID] == count, "expected fresh resolved file transfer starts");
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGProbeDirectory = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] copy];
    [[NSFileManager defaultManager] createDirectoryAtPath:TGProbeDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *source = [TGProbeDirectory stringByAppendingPathComponent:@"cache.bin"];
    [@"full source" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];

    TGRestartIdentityClient *client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source;
    TGDownloadManager *manager = TGRestore(TGRestartRecord(@"cancelled"), client);
    __block NSUInteger completions = 0;
    NSString *retry = [manager enqueueRetryDownloadWithIdentifier:@"old-job" completion:^(NSString *path, NSError *error, BOOL cancelled) {
        TGAssert(path && !error && !cancelled, "restored stable-identity Retry completes"); completions++;
    }];
    TGWaitDownloads(client, @900, 1); TGWait(0.04);
    NSDictionary *record = TGRecord(manager, retry);
    TGAssert(completions == 1 && [[record objectForKey:@"file_id"] isEqual:@900] && [client downloadsFor:@77] == 0,
             "Retry resolves stale77 to fresh900 without downloading old ID");
    TGAssert([[record objectForKey:@"remote_id"] isEqual:@"canonical-A"] && [[record objectForKey:@"remote_unique_id"] isEqual:@"unique-A"] &&
             [[record objectForKey:@"account_id"] isEqual:@1], "canonical remote alias and account owner persist before transfer");
    NSString *saved = nil;
    TGAssert([manager presentationStateForFileID:@77 savedPath:&saved] == nil &&
             [[manager presentationStateForFileID:@900 savedPath:&saved] isEqual:@"completed"], "presentation only matches fresh verified session ID");
    TGDownloadManager *restarted = TGRestore(record, client);
    [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObject:source forKey:@"900"]
                                             forKey:@"TelegraphicaCompletedDownloadPathsByFileID"];
    TGAssert([restarted presentationStateForFileID:@900 savedPath:&saved] == nil, "persisted completed numeric ID cannot match another session file");
    [client setSourcePath:source];

    NSMutableDictionary *legacy = TGRestartRecord(@"paused");
    [legacy removeObjectForKey:@"remote_id"]; [legacy removeObjectForKey:@"remote_unique_id"]; [legacy removeObjectForKey:@"account_id"];
    [legacy setObject:source forKey:@"fallback_path"];
    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source;
    manager = TGRestore(legacy, client);
    [manager resumeDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.04);
    TGAssert([[TGRecord(manager, @"old-job") objectForKey:@"state"] isEqual:@"failed"] && [client identityRequests] == 0 &&
             [client accountRequests] == 0 && [client downloadsFor:@77] == 0 && [[client cancelIDs] count] == 0,
             "legacy restored numeric-only job fails before any unsafe file or account RPC/fallback export");
    retry = [manager enqueueRetryDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.03);
    TGAssert([[TGRecord(manager, retry) objectForKey:@"state"] isEqual:@"failed"] && [client identityRequests] == 0,
             "Retry preserves untrusted marker and cannot bypass legacy identity rejection");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source; client.ownerID = @2;
    manager = TGRestore(TGRestartRecord(@"paused"), client);
    [manager resumeDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.04);
    TGAssert([[TGRecord(manager, @"old-job") objectForKey:@"state"] isEqual:@"failed"] && [client identityRequests] == 0 &&
             [client downloadsFor:@900] == 0 && [[client cancelIDs] count] == 0, "persisted account mismatch rejects private file before lookup/download/cancel");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source; client.canonicalUnique = @"different-file";
    manager = TGRestore(TGRestartRecord(@"paused"), client);
    [manager resumeDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.04);
    TGAssert([[TGRecord(manager, @"old-job") objectForKey:@"state"] isEqual:@"failed"] && [client identityRequests] == 1 &&
             [client downloadsFor:@900] == 0 && [[client cancelIDs] count] == 0, "remote unique-id mismatch cannot download/cancel wrong remapped file");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source; client.holdIdentity = YES;
    manager = TGRestore(TGRestartRecord(@"paused"), client); [manager resumeDownloadWithIdentifier:@"old-job" completion:nil];
    TGWait(0.03); TGAssert([client identityRequests] == 1, "cancellation fixture reaches identity lookup");
    [manager cancelDownloadWithIdentifier:@"old-job"]; client.releaseIdentity = YES; TGWait(0.04);
    TGAssert([client downloadsFor:@900] == 0 && [[client cancelIDs] count] == 0 &&
             [[TGRecord(manager, @"old-job") objectForKey:@"state"] isEqual:@"cancelled"], "cancelling unresolved identity never sends cancel against stale77 or resolved900");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source; client.hangRemapped = YES;
    manager = TGRestore(TGRestartRecord(@"paused"), client); [manager resumeDownloadWithIdentifier:@"old-job" completion:nil];
    TGWaitDownloads(client, @900, 1);
    NSString *independent = [manager enqueueFileID:@77 suggestedFileName:@"unrelated.zip" fallbackLocalPath:nil completion:nil];
    TGWaitDownloads(client, @77, 1); TGWait(0.03);
    TGAssert([[TGRecord(manager, independent) objectForKey:@"state"] isEqual:@"completed"], "remapped900 transfer cannot block unrelated current77 in second slot");
    client.holdCancel = YES; [manager pauseDownloadWithIdentifier:@"old-job"]; TGWait(0.03);
    [manager resumeDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.03);
    TGAssert([client downloadsFor:@900] == 1 && [[client cancelIDs] isEqual:[NSArray arrayWithObject:@900]],
             "quick remapped Resume waits old cancellation and always cancels fresh900");
    client.hangRemapped = NO; client.releaseCancel = YES; TGWaitDownloads(client, @900, 2); TGWait(0.04);
    TGAssert([[TGRecord(manager, @"old-job") objectForKey:@"state"] isEqual:@"completed"], "remapped Resume completes after cancellation barrier");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source; client.hangRemapped = YES; client.holdCancel = YES;
    manager = TGRestore(TGRestartRecord(@"paused"), client); [manager resumeDownloadWithIdentifier:@"old-job" completion:nil]; TGWaitDownloads(client, @900, 1);
    [manager cancelDownloadWithIdentifier:@"old-job"]; TGWait(0.03);
    retry = [manager enqueueRetryDownloadWithIdentifier:@"old-job" completion:nil]; TGWait(0.03);
    TGAssert([client downloadsFor:@900] == 1 && [[client cancelIDs] isEqual:[NSArray arrayWithObject:@900]],
             "cancel then new Retry identifier shares resolved cancellation barrier");
    client.hangRemapped = NO; client.releaseCancel = YES; TGWaitDownloads(client, @900, 2); TGWait(0.04);
    TGAssert([[TGRecord(manager, retry) objectForKey:@"state"] isEqual:@"completed"], "new Retry starts after old remapped cancellation completes");

    client = [[[TGRestartIdentityClient alloc] init] autorelease]; client.sourcePath = source;
    manager = TGRestore(TGRestartRecord(@"queued"), client); [manager resumePendingDownloads]; TGWaitDownloads(client, @900, 1); TGWait(0.03);
    TGAssert([client downloadsFor:@77] == 0, "automatic interrupted restoration preserves remote identity provenance");
    [[NSFileManager defaultManager] removeItemAtPath:TGProbeDirectory error:NULL]; [TGProbeDirectory release];
    puts("Download restart identity probe passed."); [pool drain]; return 0;
}
