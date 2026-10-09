#import <Cocoa/Cocoa.h>
#import "TGDownloadManager.h"
#import "TGDownloadQueueStore.h"
#import "TGTDLibClient+Files.h"
#import "TGMediaFileActions.h"
#include <stdio.h>
#include <stdlib.h>

static NSString *TGProbeDirectory;
static BOOL TGCopyHeld, TGCopyStarted, TGCopyReleased;
NSString *TGConfiguredDownloadFolderPath(void) { return TGProbeDirectory; }
static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Download pause probe failed: %s\n", message); exit(1); }
}
static void TGWait(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([end timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TGTDLibClient
@end
@interface TGPauseProbeClient : TGTDLibClient {
    NSMutableDictionary *_requests;
    NSUInteger _cancellations;
    BOOL _holdCancel, _cancelEntered, _releaseCancel, _hangAll, _completeResume;
    NSString *_sourcePath;
}
@property (nonatomic, copy) NSString *sourcePath;
@property (nonatomic, assign) BOOL holdCancel, releaseCancel, hangAll, completeResume;
- (NSUInteger)requestsForFile:(NSNumber *)fileID;
- (NSUInteger)cancellations;
- (BOOL)cancelEntered;
@end
@implementation TGPauseProbeClient
@synthesize sourcePath = _sourcePath;
- (id)init { if ((self = [super init])) { _requests = [[NSMutableDictionary alloc] init]; } return self; }
- (void)dealloc { [_requests release]; [_sourcePath release]; [super dealloc]; }
- (BOOL)holdCancel { @synchronized(self) { return _holdCancel; } }
- (void)setHoldCancel:(BOOL)value { @synchronized(self) { _holdCancel = value; } }
- (BOOL)releaseCancel { @synchronized(self) { return _releaseCancel; } }
- (void)setReleaseCancel:(BOOL)value { @synchronized(self) { _releaseCancel = value; } }
- (BOOL)hangAll { @synchronized(self) { return _hangAll; } }
- (void)setHangAll:(BOOL)value { @synchronized(self) { _hangAll = value; } }
- (BOOL)completeResume { @synchronized(self) { return _completeResume; } }
- (void)setCompleteResume:(BOOL)value { @synchronized(self) { _completeResume = value; } }
- (NSUInteger)requestsForFile:(NSNumber *)fileID { @synchronized(self) { return [[_requests objectForKey:fileID] unsignedIntegerValue]; } }
- (NSUInteger)cancellations { @synchronized(self) { return _cancellations; } }
- (BOOL)cancelEntered { @synchronized(self) { return _cancelEntered; } }
- (NSNumber *)downloadAccountIDWithError:(NSError **)error { (void)error; return @1; }
- (NSDictionary *)downloadFileIdentityForFileID:(NSNumber *)fileID remoteFileID:(NSString *)remoteID error:(NSError **)error {
    (void)error;
    NSString *stableID = [remoteID length] > 0 ? remoteID : [NSString stringWithFormat:@"remote-%lld", [fileID longLongValue]];
    return [NSDictionary dictionaryWithObjectsAndKeys:@"file", @"@type", fileID, @"id",
            [NSDictionary dictionaryWithObjectsAndKeys:stableID, @"id", [NSString stringWithFormat:@"unique-%lld", [fileID longLongValue]], @"unique_id", nil], @"remote", nil];
}
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID cancelled:(TGFileDownloadCancellationBlock)cancelled
                                          progress:(TGFileDownloadProgressBlock)progress error:(NSError **)error {
    (void)error;
    NSUInteger number = 0; BOOL hang = NO;
    @synchronized(self) {
        number = [[_requests objectForKey:fileID] unsignedIntegerValue] + 1;
        [_requests setObject:[NSNumber numberWithUnsignedInteger:number] forKey:fileID];
        hang = _hangAll || ([fileID longLongValue] == 77 && !(_completeResume && number > 1));
    }
    if (progress) { progress(number * 64LL * 1024LL * 1024LL, 5LL * 1024LL * 1024LL * 1024LL, NO); }
    if (hang) {
        while (!cancelled()) { [NSThread sleepForTimeInterval:0.005]; }
        // Adversarial late progress must never replace the new attempt's bytes.
        if (progress) { progress(999, 0, YES); }
        return nil;
    }
    return _sourcePath;
}
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)fileID; (void)timeout; (void)error;
    @synchronized(self) { _cancellations++; _cancelEntered = YES; }
    while (YES) {
        BOOL waiting = NO;
        @synchronized(self) { waiting = _holdCancel && !_releaseCancel; }
        if (!waiting) { break; }
        [NSThread sleepForTimeInterval:0.005];
    }
    return YES;
}
@end
@implementation TGMediaFileActions
+ (NSString *)saveCopyOfFileAtPath:(NSString *)source suggestedFileName:(NSString *)name toDirectory:(NSString *)directory error:(NSError **)error {
    NSString *destination = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", [[NSProcessInfo processInfo] globallyUniqueString], name]];
    @synchronized(self) { TGCopyStarted = YES; }
    while (YES) {
        BOOL waiting = NO;
        @synchronized(self) { waiting = TGCopyHeld && !TGCopyReleased; }
        if (!waiting) { break; }
        [NSThread sleepForTimeInterval:0.005];
    }
    return [[NSFileManager defaultManager] copyItemAtPath:source toPath:destination error:error] ? destination : nil;
}
@end
#pragma clang diagnostic pop

static BOOL TGLifetimeReleased;
@interface TGPauseLifetime : NSObject
@end
@implementation TGPauseLifetime
- (void)dealloc { TGLifetimeReleased = YES; [super dealloc]; }
@end
static TGDownloadManager *TGManager(TGPauseProbeClient *client) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGDownloadQueueRecordsDefaultsKey];
    TGDownloadManager *manager = [[[TGDownloadManager alloc] init] autorelease]; [manager setClient:client]; return manager;
}
static NSDictionary *TGRecord(TGDownloadManager *manager, NSString *identifier) {
    for (NSDictionary *record in [manager itemsSnapshot]) { if ([[record objectForKey:@"identifier"] isEqual:identifier]) { return record; } }
    return nil;
}
static void TGWaitRequest(TGPauseProbeClient *client, NSNumber *fileID, NSUInteger count) {
    for (NSUInteger n = 0; n < 200 && [client requestsForFile:fileID] < count; n++) { TGWait(0.005); }
    TGAssert([client requestsForFile:fileID] == count, "expected attempt starts");
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGProbeDirectory = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] copy];
    [[NSFileManager defaultManager] createDirectoryAtPath:TGProbeDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *source = [TGProbeDirectory stringByAppendingPathComponent:@"source.bin"];
    [@"full file" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    TGPauseProbeClient *client = [[[TGPauseProbeClient alloc] init] autorelease]; client.sourcePath = source;
    client.holdCancel = YES; client.completeResume = YES;
    TGDownloadManager *manager = TGManager(client);
    __block NSUInteger originalCallbacks = 0, resumeCallbacks = 0;
    NSString *identifier = [manager enqueueFileID:@77 suggestedFileName:@"resume.zip" fallbackLocalPath:nil
                                      completion:^(NSString *path, NSError *error, BOOL cancelled) {
        TGAssert([path length] > 0 && !error && !cancelled, "Pause must not terminally cancel original callback"); originalCallbacks++;
    }];
    TGWaitRequest(client, @77, 1);
    [manager pauseDownloadWithIdentifier:identifier];
    TGWait(0.05);
    TGAssert([client cancelEntered] && originalCallbacks == 0 && [[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"paused"],
             "Pause stops observer and cancels origin network without terminal callback");
    TGAssert([[TGRecord(manager, identifier) objectForKey:@"downloaded_bytes"] longLongValue] == 64LL * 1024LL * 1024LL,
             "paused progress preserves chunks and ignores late stale progress");
    NSString *duplicate = [manager enqueueFileID:@77 suggestedFileName:@"duplicate.zip" fallbackLocalPath:nil completion:nil];
    TGAssert([duplicate isEqual:identifier] && [[manager itemsSnapshot] count] == 1, "paused file cannot create duplicate active job");
    [manager resumeDownloadWithIdentifier:identifier completion:^(NSString *path, NSError *error, BOOL cancelled) {
        TGAssert(path && !error && !cancelled, "Resume completes new attempt"); resumeCallbacks++;
    }];
    TGWait(0.05);
    TGAssert([client requestsForFile:@77] == 1 && [[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"queued"],
             "quick Resume waits until old origin cancel RPC finishes");
    client.releaseCancel = YES; TGWaitRequest(client, @77, 2); TGWait(0.05);
    TGAssert(originalCallbacks == 1 && resumeCallbacks == 1 && [[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"completed"],
             "same identifier resumes once and preserves original completion");
    TGAssert([[TGRecord(manager, identifier) objectForKey:@"downloaded_bytes"] longLongValue] == 128LL * 1024LL * 1024LL,
             "late old attempt cannot overwrite resumed progress");

    TGPauseProbeClient *pausedClient = [[[TGPauseProbeClient alloc] init] autorelease]; pausedClient.sourcePath = source;
    manager = TGManager(pausedClient);
    TGPauseLifetime *lifetime = [[TGPauseLifetime alloc] init];
    __block NSUInteger cancelledCallbacks = 0;
    identifier = [manager enqueueFileID:@77 suggestedFileName:@"paused.zip" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        (void)[lifetime description]; TGAssert(!path && !error && cancelled, "Cancel paused job delivers terminal cancellation"); cancelledCallbacks++;
    }];
    [lifetime release]; TGWaitRequest(pausedClient, @77, 1);
    [manager pauseDownloadWithIdentifier:identifier]; TGWait(0.05);
    TGAssert(!TGLifetimeReleased && cancelledCallbacks == 0, "Pause retains original callback until terminal decision");
    NSArray *stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGDownloadQueueRecordsDefaultsKey];
    TGAssert([[[stored objectAtIndex:0] objectForKey:@"state"] isEqual:@"paused"], "latest persisted snapshot remains paused");
    TGDownloadManager *restored = [[[TGDownloadManager alloc] init] autorelease];
    TGPauseProbeClient *restoredClient = [[[TGPauseProbeClient alloc] init] autorelease]; restoredClient.sourcePath = source;
    [restored setClient:restoredClient]; [restored resumePendingDownloads]; TGWait(0.03);
    TGAssert([restoredClient requestsForFile:@77] == 0 && [[TGRecord(restored, identifier) objectForKey:@"state"] isEqual:@"paused"],
             "restored Pause survives initial account attach and does not auto-resume");
    restoredClient.completeResume = YES; restoredClient.hangAll = NO;
    // A restored attempt has no live previous operation; explicitly Resume it.
    [restored resumeDownloadWithIdentifier:identifier completion:nil]; TGWaitRequest(restoredClient, @77, 1);
    [restored cancelDownloadWithIdentifier:identifier]; TGWait(0.05);
    [manager cancelDownloadWithIdentifier:identifier]; TGWait(0.05);
    TGAssert(cancelledCallbacks == 1 && TGLifetimeReleased && [[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"cancelled"],
             "Cancel paused job drains callback ownership exactly once");
    [manager resumeDownloadWithIdentifier:identifier completion:nil]; TGWait(0.02);
    TGAssert([pausedClient requestsForFile:@77] == 1, "terminally cancelled paused job cannot Resume");

    TGPauseProbeClient *account = [[[TGPauseProbeClient alloc] init] autorelease]; account.sourcePath = source;
    TGPauseProbeClient *otherAccount = [[[TGPauseProbeClient alloc] init] autorelease]; otherAccount.sourcePath = source;
    manager = TGManager(account);
    identifier = [manager enqueueFileID:@77 suggestedFileName:@"account.zip" fallbackLocalPath:nil completion:nil];
    TGWaitRequest(account, @77, 1); [manager pauseDownloadWithIdentifier:identifier]; TGWait(0.05);
    [manager setClient:nil]; [manager setClient:otherAccount]; [manager resumeDownloadWithIdentifier:identifier completion:nil]; TGWait(0.05);
    TGAssert([[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"cancelled"] && [otherAccount requestsForFile:@77] == 0 && [otherAccount cancellations] == 0,
             "account detach cannot resume old paused file IDs on new account");

    TGPauseProbeClient *queuedClient = [[[TGPauseProbeClient alloc] init] autorelease]; queuedClient.sourcePath = source; queuedClient.hangAll = YES;
    manager = TGManager(queuedClient);
    NSString *first = [manager enqueueFileID:@81 suggestedFileName:@"slot1.zip" fallbackLocalPath:nil completion:nil];
    NSString *second = [manager enqueueFileID:@82 suggestedFileName:@"slot2.zip" fallbackLocalPath:nil completion:nil];
    TGWaitRequest(queuedClient, @81, 1); TGWaitRequest(queuedClient, @82, 1);
    NSString *queued = [manager enqueueFileID:@83 suggestedFileName:@"queued.zip" fallbackLocalPath:nil completion:nil];
    [manager pauseDownloadWithIdentifier:queued];
    [manager cancelDownloadWithIdentifier:first]; [manager cancelDownloadWithIdentifier:second]; TGWait(0.05);
    TGAssert([queuedClient requestsForFile:@83] == 0 && [[TGRecord(manager, queued) objectForKey:@"state"] isEqual:@"paused"],
             "pausing queued job never starts transfer and frees queue slots");
    queuedClient.hangAll = NO;
    [manager enqueueFileID:@84 suggestedFileName:@"later.zip" fallbackLocalPath:nil completion:nil]; TGWaitRequest(queuedClient, @84, 1); TGWait(0.03);
    [manager cancelDownloadWithIdentifier:queued];

    TGPauseProbeClient *copyClient = [[[TGPauseProbeClient alloc] init] autorelease]; copyClient.sourcePath = source;
    manager = TGManager(copyClient);
    @synchronized([TGMediaFileActions class]) { TGCopyHeld = YES; TGCopyReleased = NO; TGCopyStarted = NO; }
    __block NSUInteger copyCallbacks = 0;
    identifier = [manager enqueueFileID:@91 suggestedFileName:@"copy.zip" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        TGAssert(path && !error && !cancelled, "Pause during export must not complete obsolete copy"); copyCallbacks++;
    }];
    TGWait(0.03); TGAssert(TGCopyStarted, "export fixture reaches disk-copy phase");
    [manager pauseDownloadWithIdentifier:identifier]; [manager resumeDownloadWithIdentifier:identifier completion:nil];
    @synchronized([TGMediaFileActions class]) { TGCopyReleased = YES; }
    TGWait(0.08);
    TGAssert(copyCallbacks == 1 && [copyClient requestsForFile:@91] == 2 && [[TGRecord(manager, identifier) objectForKey:@"state"] isEqual:@"completed"],
             "pause/resume during copy discards stale export and completes only new attempt");
    NSUInteger exports = 0;
    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TGProbeDirectory error:NULL]) {
        if ([name hasSuffix:@"copy.zip"]) { exports++; }
    }
    TGAssert(exports == 1 && [[NSFileManager defaultManager] fileExistsAtPath:source], "only new completed export survives; cached source preserved");

    [[NSFileManager defaultManager] removeItemAtPath:TGProbeDirectory error:NULL]; [TGProbeDirectory release];
    puts("Download pause/resume probe passed."); [pool drain]; return 0;
}
