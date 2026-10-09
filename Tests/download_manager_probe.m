#import <Cocoa/Cocoa.h>
#import "TGDownloadManager.h"
#import "TGDownloadQueueStore.h"
#import "TGTDLibClient+Files.h"
#import "TGMediaFileActions.h"
#include <stdio.h>
#include <stdlib.h>

static NSString *TGProbeDirectory;
static BOOL TGDelayCopy, TGCopyStarted, TGReleaseCopy;
static NSUInteger TGCopies;
NSString *TGConfiguredDownloadFolderPath(void) { return TGProbeDirectory; }


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TGTDLibClient
@end

@interface TGDownloadProbeClient : TGTDLibClient {
    NSString *_sourcePath;
    NSUInteger _requests, _cancellations;
    BOOL _fail;
}
@property (nonatomic, copy) NSString *sourcePath;
@property (nonatomic, assign) BOOL fail;
- (NSUInteger)requests;
- (NSUInteger)cancellations;
@end
@implementation TGDownloadProbeClient
@synthesize sourcePath = _sourcePath, fail = _fail;
- (void)dealloc { [_sourcePath release]; [super dealloc]; }
- (NSUInteger)requests { @synchronized(self) { return _requests; } }
- (NSUInteger)cancellations { @synchronized(self) { return _cancellations; } }
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID cancelled:(TGFileDownloadCancellationBlock)cancelled
                                          progress:(TGFileDownloadProgressBlock)progress error:(NSError **)error {
    @synchronized(self) { _requests++; }
    if (_fail) {
        if (error) { *error = [NSError errorWithDomain:@"Mock" code:400 userInfo:nil]; }
        return nil;
    }
    if ([fileID longLongValue] == 77) {
        while (!cancelled()) { [NSThread sleepForTimeInterval:0.01]; }
        return nil;
    }
    if (progress) { progress(5LL * 1024LL * 1024LL * 1024LL, 5LL * 1024LL * 1024LL * 1024LL, NO); }
    return _sourcePath;
}
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)fileID; (void)timeout; (void)error;
    @synchronized(self) { _cancellations++; }
    return YES;
}
@end

@implementation TGMediaFileActions
+ (NSString *)saveCopyOfFileAtPath:(NSString *)source suggestedFileName:(NSString *)fileName toDirectory:(NSString *)directory error:(NSError **)error {
    NSString *destination = nil;
    @synchronized(self) {
        TGCopies++;
        destination = [directory stringByAppendingPathComponent:fileName];
        NSUInteger suffix = 2;
        while ([[NSFileManager defaultManager] fileExistsAtPath:destination]) {
            destination = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu-%@", (unsigned long)suffix++, fileName]];
        }
        TGCopyStarted = YES;
    }
    while (YES) {
        BOOL hold = NO;
        @synchronized(self) { hold = TGDelayCopy && !TGReleaseCopy; }
        if (!hold) { break; }
        [NSThread sleepForTimeInterval:0.01];
    }
    return [[NSFileManager defaultManager] copyItemAtPath:source toPath:destination error:error] ? destination : nil;
}
@end

#pragma clang diagnostic pop

static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Download manager probe failed: %s\n", message); exit(1); }
}
static void TGWait(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([end timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
}
static TGDownloadManager *TGManager(TGDownloadProbeClient *client) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGDownloadQueueRecordsDefaultsKey];
    TGDownloadManager *manager = [[[TGDownloadManager alloc] init] autorelease];
    [manager setClient:client]; return manager;
}
static NSDictionary *TGRecord(TGDownloadManager *manager, NSString *identifier) {
    for (NSDictionary *record in [manager itemsSnapshot]) {
        if ([[record objectForKey:@"identifier"] isEqualToString:identifier]) { return record; }
    }
    return nil;
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGProbeDirectory = [[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"telegraphica-manager-%u", arc4random()]] copy];
    [[NSFileManager defaultManager] createDirectoryAtPath:TGProbeDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *source = [TGProbeDirectory stringByAppendingPathComponent:@"fixture.bin"];
    TGAssert([[@"fixture" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:source atomically:YES], "write source fixture");
    TGDownloadProbeClient *client = [[[TGDownloadProbeClient alloc] init] autorelease]; client.sourcePath = source;
    TGDownloadManager *manager = TGManager(client);
    __block BOOL firstCancelled = NO, secondCompleted = NO;
    NSString *first = [manager enqueueFileID:@77 suggestedFileName:@"hanging.bin" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        (void)path; (void)error; firstCancelled = cancelled;
    }];
    [manager enqueueFileID:@78 suggestedFileName:@"complete.bin" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        secondCompleted = [path length] > 0 && !error && !cancelled;
    }];
    TGWait(0.3);
    TGAssert(secondCompleted && [[TGRecord(manager, first) objectForKey:@"state"] isEqualToString:@"downloading"],
             "one stalled job must not block a second bounded-slot download");
    [manager cancelDownloadWithIdentifier:first]; TGWait(0.3);
    TGAssert(firstCancelled && [client cancellations] == 1, "cancellation must target the originating client and finish its callback");

    TGDownloadProbeClient *failing = [[[TGDownloadProbeClient alloc] init] autorelease]; failing.fail = YES; failing.sourcePath = source;
    manager = TGManager(failing);
    __block BOOL failed = NO;
    NSUInteger copiesBefore = TGCopies;
    NSString *failedID = [manager enqueueFileID:@78 suggestedFileName:@"partial.bin" fallbackLocalPath:source completion:^(NSString *path, NSError *error, BOOL cancelled) {
        failed = !path && error && !cancelled;
    }];
    TGWait(0.3);
    TGAssert(failed && TGCopies == copiesBefore && [[TGRecord(manager, failedID) objectForKey:@"state"] isEqualToString:@"failed"],
             "incomplete cached fallback must not be exported after a failed full-file request");

    manager = TGManager(nil);
    __block BOOL unavailableClientFailed = NO;
    copiesBefore = TGCopies;
    NSString *unavailableID = [manager enqueueFileID:@78 suggestedFileName:@"signed-out-partial.bin" fallbackLocalPath:source completion:^(NSString *path, NSError *error, BOOL cancelled) {
        unavailableClientFailed = !path && error && !cancelled;
    }];
    TGWait(0.3);
    TGAssert(unavailableClientFailed && TGCopies == copiesBefore &&
             [[TGRecord(manager, unavailableID) objectForKey:@"state"] isEqualToString:@"failed"],
             "a positive file ID without a ready client must never export its partial cached fallback");
    __block BOOL localCompleted = NO;
    [manager enqueueFileID:nil suggestedFileName:@"local-only.bin" fallbackLocalPath:source completion:^(NSString *path, NSError *error, BOOL cancelled) {
        localCompleted = [path length] > 0 && !error && !cancelled;
    }];
    TGWait(0.3);
    TGAssert(localCompleted && TGCopies == copiesBefore + 1, "a local-only file without a TDLib ID remains exportable");

    TGDownloadProbeClient *oldClient = [[[TGDownloadProbeClient alloc] init] autorelease]; oldClient.sourcePath = source;
    TGDownloadProbeClient *newClient = [[[TGDownloadProbeClient alloc] init] autorelease]; newClient.sourcePath = source;
    manager = TGManager(oldClient);
    __block BOOL oldCancelled = NO;
    NSString *oldID = [manager enqueueFileID:@77 suggestedFileName:@"old-account.bin" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        (void)path; (void)error; oldCancelled = cancelled;
    }];
    TGWait(0.1); [manager setClient:newClient]; [manager resumePendingDownloads]; TGWait(0.3);
    TGAssert(oldCancelled && [newClient requests] == 0 && [newClient cancellations] == 0 &&
             [[TGRecord(manager, oldID) objectForKey:@"state"] isEqualToString:@"cancelled"],
             "switching account must not resume/cancel old file IDs on the new client");

    manager = TGManager(client);
    @synchronized([TGMediaFileActions class]) { TGDelayCopy = YES; TGReleaseCopy = NO; TGCopyStarted = NO; }
    __block BOOL cancelledCopy = NO;
    NSString *copyID = [manager enqueueFileID:@78 suggestedFileName:@"cancel-during-copy.bin" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        (void)error; cancelledCopy = !path && cancelled;
    }];
    TGWait(0.1); TGAssert(TGCopyStarted, "copy fixture must reach final-export phase");
    [manager cancelDownloadWithIdentifier:copyID];
    @synchronized([TGMediaFileActions class]) { TGReleaseCopy = YES; }
    TGWait(0.3);
    TGAssert(cancelledCopy && [[TGRecord(manager, copyID) objectForKey:@"state"] isEqualToString:@"cancelled"],
             "cancellation during large-file copy must not finalize completed");
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:TGProbeDirectory error:NULL];
    for (NSString *file in files) {
        TGAssert([file rangeOfString:@"cancel-during-copy"].location == NSNotFound, "only the new cancelled export must be removed");
    }
    TGAssert([[NSFileManager defaultManager] fileExistsAtPath:source], "source/cache fixture must remain untouched");
    manager = TGManager(client);
    @synchronized([TGMediaFileActions class]) { TGDelayCopy = YES; TGReleaseCopy = NO; TGCopyStarted = NO; }
    __block NSUInteger completedTogether = 0;
    __block NSString *firstSaved = nil, *secondSaved = nil;
    copiesBefore = TGCopies;
    [manager enqueueFileID:@79 suggestedFileName:@"same-name.zip" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        if (path && !error && !cancelled) { completedTogether++; firstSaved = [path copy]; }
    }];
    [manager enqueueFileID:@80 suggestedFileName:@"same-name.zip" fallbackLocalPath:nil completion:^(NSString *path, NSError *error, BOOL cancelled) {
        if (path && !error && !cancelled) { completedTogether++; secondSaved = [path copy]; }
    }];
    TGWait(0.2);
    TGAssert(TGCopies == copiesBefore + 1, "two transfer slots must serialize final filename selection/copy only");
    @synchronized([TGMediaFileActions class]) { TGReleaseCopy = YES; }
    TGWait(0.3);
    TGAssert(completedTogether == 2 && ![firstSaved isEqualToString:secondSaved], "same-name concurrent downloads must both save distinct complete files");
    [firstSaved release]; [secondSaved release];

    [[NSFileManager defaultManager] removeItemAtPath:TGProbeDirectory error:NULL];
    [TGProbeDirectory release];
    puts("Download manager probe passed.");
    [pool drain]; return 0;
}
