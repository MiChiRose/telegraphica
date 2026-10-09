#import <Cocoa/Cocoa.h>
#include <stdio.h>

static void TGAssert(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "Media center save probe failed: %s\n", message); exit(1); }
}
static void TGWait(NSTimeInterval seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([end timeIntervalSinceNow] > 0.0) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    }
}
static NSString *TGLoc(NSString *key) { return [key stringByAppendingString:@": %@"]; }
static NSString *TGDisplayPathForDownloadFolder(NSString *path) { return path; }
typedef NSDictionary TGMessageItem;
static NSNumber *TGMediaCenterFileIDForItem(TGMessageItem *item) { return [item objectForKey:@"id"]; }
static NSString *TGMediaCenterLocalPathForItem(TGMessageItem *item) { return [item objectForKey:@"path"]; }
static NSString *TGMediaCenterTitleForItem(TGMessageItem *item) { return @"archive.zip"; }
static NSString *TGSource;

@interface TGTDLibClient : NSObject {
    NSMutableArray *_requests;
    NSUInteger _cancellations;
}
- (NSUInteger)requestCount;
- (BOOL)wasCancelled:(NSUInteger)index;
- (void)releaseRequest:(NSUInteger)index;
- (NSUInteger)cancellations;
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID cancelled:(BOOL (^)(void))cancelled
                                          progress:(id)progress error:(NSError **)error;
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error;
@end
@implementation TGTDLibClient
- (id)init { if ((self = [super init])) { _requests = [[NSMutableArray alloc] init]; } return self; }
- (void)dealloc { [_requests release]; [super dealloc]; }
- (NSUInteger)requestCount { @synchronized(self) { return [_requests count]; } }
- (BOOL)wasCancelled:(NSUInteger)index { @synchronized(self) { return [[[_requests objectAtIndex:index] objectForKey:@"cancelled"] boolValue]; } }
- (void)releaseRequest:(NSUInteger)index { @synchronized(self) { [[_requests objectAtIndex:index] setObject:@YES forKey:@"released"]; } }
- (NSUInteger)cancellations { @synchronized(self) { return _cancellations; } }
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID cancelled:(BOOL (^)(void))cancelled
                                          progress:(id)progress error:(NSError **)error {
    (void)fileID; (void)progress; (void)error;
    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    @synchronized(self) { [_requests addObject:entry]; }
    BOOL wasCancelled = NO;
    while (YES) {
        wasCancelled = wasCancelled || cancelled();
        BOOL released = NO;
        @synchronized(self) {
            [entry setObject:[NSNumber numberWithBool:wasCancelled] forKey:@"cancelled"];
            released = [[entry objectForKey:@"released"] boolValue];
        }
        if (released) { break; }
        [NSThread sleepForTimeInterval:0.005];
    }
    return wasCancelled ? nil : TGSource;
}
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)fileID; (void)timeout; (void)error;
    @synchronized(self) { _cancellations++; } return YES;
}
@end

typedef void (^TGManagerCompletion)(NSString *, NSError *, BOOL);
static BOOL TGExistingManagerJob;
static BOOL TGRestoredManagerJob;
@interface TGDownloadManager : NSObject {
    NSMutableArray *_completions;
    NSUInteger _cancellations;
}
+ (id)sharedManager;
- (void)setClient:(TGTDLibClient *)client;
- (void)enqueueFileID:(NSNumber *)fileID suggestedFileName:(NSString *)name fallbackLocalPath:(NSString *)path completion:(TGManagerCompletion)completion;
- (void)cancelDownloadsForFileID:(NSNumber *)fileID;
- (void)finishFirst;
- (NSArray *)itemsSnapshot;
@end
@implementation TGDownloadManager
+ (id)sharedManager { static TGDownloadManager *manager; if (!manager) { manager = [[self alloc] init]; } return manager; }
- (id)init { if ((self = [super init])) { _completions = [[NSMutableArray alloc] init]; } return self; }
- (void)dealloc { [_completions release]; [super dealloc]; }
- (void)setClient:(TGTDLibClient *)client { (void)client; }
- (NSArray *)itemsSnapshot {
    return TGExistingManagerJob ? [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
           @41, @"file_id", @"downloading", @"state", [NSNumber numberWithBool:TGRestoredManagerJob], @"requires_remote_resolution", nil]] : [NSArray array];
}
- (void)enqueueFileID:(NSNumber *)fileID suggestedFileName:(NSString *)name fallbackLocalPath:(NSString *)path completion:(TGManagerCompletion)completion {
    (void)fileID; (void)name; (void)path; id copy = [completion copy]; [_completions addObject:copy]; [copy release];
}
- (void)cancelDownloadsForFileID:(NSNumber *)fileID { (void)fileID; _cancellations++; }
- (void)finishFirst { TGManagerCompletion completion = [[_completions objectAtIndex:0] retain]; [_completions removeObjectAtIndex:0]; completion(TGSource, nil, NO); [completion release]; }
@end
static NSUInteger TGSavePanels;
static void (^TGDuringModal)(void);
@interface TGMediaFileActions : NSObject
+ (NSString *)saveCopyOfFileAtPath:(NSString *)path suggestedFileName:(NSString *)name shouldContinue:(BOOL (^)(void))shouldContinue error:(NSError **)error;
@end
@implementation TGMediaFileActions
+ (NSString *)saveCopyOfFileAtPath:(NSString *)path suggestedFileName:(NSString *)name shouldContinue:(BOOL (^)(void))shouldContinue error:(NSError **)error {
    (void)name; (void)error; TGSavePanels++; if (TGDuringModal) { TGDuringModal(); }
    return shouldContinue() ? path : nil;
}
@end

@interface TGMediaCenterSaveProbe : NSObject
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSNumber *selectedChatID;
@property (nonatomic, retain) NSNumber *selectedMessageThreadID;
@property (nonatomic, copy) NSString *currentAuthState;
@property (nonatomic, assign) BOOL mediaCenterVisible;
@property (nonatomic, assign) NSUInteger mediaCenterGeneration;
@property (nonatomic, retain) NSMutableDictionary *mediaCenterSaveRequests;
@property (nonatomic, retain) NSMutableSet *mediaCenterDownloadingFileIDs;
@property (nonatomic, retain) NSMutableDictionary *mediaCenterSavedPathsByFileID;
@property (nonatomic, retain) NSTextField *mediaCenterStatusField;
- (TGMessageItem *)mediaCenterItemForSender:(id)sender;
- (void)rebuildMediaCenterRowsPreservingScroll:(BOOL)preserve;
@end
@implementation TGMediaCenterSaveProbe
@synthesize client, selectedChatID, selectedMessageThreadID, currentAuthState, mediaCenterVisible, mediaCenterGeneration;
@synthesize mediaCenterSaveRequests, mediaCenterDownloadingFileIDs, mediaCenterSavedPathsByFileID, mediaCenterStatusField;
- (void)dealloc {
    [client release]; [selectedChatID release]; [selectedMessageThreadID release]; [currentAuthState release];
    [mediaCenterSaveRequests release]; [mediaCenterDownloadingFileIDs release];
    [mediaCenterSavedPathsByFileID release]; [mediaCenterStatusField release]; [super dealloc];
}
- (TGMessageItem *)mediaCenterItemForSender:(id)sender { return sender; }
- (void)rebuildMediaCenterRowsPreservingScroll:(BOOL)preserve { (void)preserve; }
#include "TGStatusWindowController+MediaCenterSave.inc"
@end

static void TGWaitRequests(TGTDLibClient *client, NSUInteger count) {
    for (NSUInteger n = 0; n < 200 && [client requestCount] < count; n++) { TGWait(0.005); }
    TGAssert([client requestCount] == count, "background request starts");
}
int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [NSApplication sharedApplication];
    TGSource = [[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] copy];
    [@"complete" writeToFile:TGSource atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    TGTDLibClient *origin = [[[TGTDLibClient alloc] init] autorelease];
    TGMediaCenterSaveProbe *view = [[[TGMediaCenterSaveProbe alloc] init] autorelease];
    view.client = origin; view.currentAuthState = @"ready"; view.mediaCenterVisible = YES;
    view.selectedChatID = @1; view.mediaCenterSaveRequests = [NSMutableDictionary dictionary];
    view.mediaCenterDownloadingFileIDs = [NSMutableSet set]; view.mediaCenterSavedPathsByFileID = [NSMutableDictionary dictionary];
    view.mediaCenterStatusField = [[[NSTextField alloc] init] autorelease];
    NSDictionary *item = [NSDictionary dictionaryWithObject:@41 forKey:@"id"];

    TGExistingManagerJob = YES;
    [view downloadMediaCenterItem:item];
    TGAssert([view.mediaCenterSaveRequests count] == 0 && [view.mediaCenterDownloadingFileIDs count] == 0,
             "existing global manager job cannot create stuck callback identity");
    TGRestoredManagerJob = YES;
    [view downloadMediaCenterItem:item];
    TGAssert([view.mediaCenterSaveRequests count] == 1, "restored numeric identity cannot block fresh file");
    [[TGDownloadManager sharedManager] finishFirst];
    TGAssert([view.mediaCenterSaveRequests count] == 0, "fresh file completes despite restored collision");
    TGRestoredManagerJob = NO;
    TGExistingManagerJob = NO;

    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 1);
    view.mediaCenterGeneration++; TGWait(0.03);
    TGAssert(![origin wasCancelled:0], "page append must not cancel Save As");
    [origin releaseRequest:0]; TGWait(0.05);
    TGAssert(TGSavePanels == 1 && [view.mediaCenterSaveRequests count] == 0, "page append completes Save As");

    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 2);
    [view cancelMediaCenterDownload:item]; [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 3); TGWait(0.03);
    id retry = [view.mediaCenterSaveRequests objectForKey:@41];
    TGAssert([origin wasCancelled:1], "Cancel invalidates direct Save As request");
    [origin releaseRequest:1]; TGWait(0.05);
    TGAssert([view.mediaCenterSaveRequests objectForKey:@41] == retry && [view.mediaCenterDownloadingFileIDs containsObject:@41], "late cancellation must preserve retry marker");
    [origin releaseRequest:2]; TGWait(0.05); TGAssert(TGSavePanels == 2, "retry gets exactly one Save panel");

    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 4);
    view.client = [[[TGTDLibClient alloc] init] autorelease]; TGWait(0.03);
    [origin releaseRequest:3]; TGWait(0.05);
    TGAssert(TGSavePanels == 2 && [view.mediaCenterSaveRequests count] == 0, "origin client flip cancels without modal");
    view.client = origin;

    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 5);
    view.selectedChatID = @2; TGWait(0.03); [origin releaseRequest:4]; TGWait(0.05);
    TGAssert(TGSavePanels == 2, "chat change suppresses stale Save panel"); view.selectedChatID = @1;
    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 6);
    view.selectedMessageThreadID = @7; TGWait(0.03); [origin releaseRequest:5]; TGWait(0.05);
    TGAssert(TGSavePanels == 2, "thread change suppresses stale Save panel"); view.selectedMessageThreadID = nil;

    [view downloadMediaCenterItem:item]; [view cancelMediaCenterDownload:item];
    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 7);
    retry = [view.mediaCenterSaveRequests objectForKey:@41]; [[TGDownloadManager sharedManager] finishFirst];
    TGAssert([view.mediaCenterSaveRequests objectForKey:@41] == retry && [view.mediaCenterDownloadingFileIDs containsObject:@41], "late manager completion cannot erase new Save As");
    [origin releaseRequest:6]; TGWait(0.05);

    TGDuringModal = [^{
        [view cancelMediaCenterDownload:item];
        [view saveMediaCenterItemAs:item];
        [view.mediaCenterStatusField setStringValue:@"new request status"];
    } copy];
    NSDictionary *localItem = [NSDictionary dictionaryWithObjectsAndKeys:@41, @"id", TGSource, @"path", nil];
    [view saveMediaCenterItemAs:localItem]; TGWaitRequests(origin, 8);
    TGAssert([[view.mediaCenterStatusField stringValue] isEqualToString:@"new request status"] && [view.mediaCenterSaveRequests objectForKey:@41] != nil, "modal reentry preserves new status and identity");
    [TGDuringModal release]; TGDuringModal = nil;
    [origin releaseRequest:7]; TGWait(0.05);

    NSUInteger before = [origin cancellations];
    [view saveMediaCenterItemAs:item]; TGWaitRequests(origin, 9); [view cancelMediaCenterDownload:item]; TGWait(0.05);
    TGAssert([origin cancellations] == before && [origin wasCancelled:8], "direct Save As stops observation without cancelling shared retry network file");
    [origin releaseRequest:8]; TGWait(0.05);
    TGAssert([view.mediaCenterSaveRequests count] == 0 && ![view.mediaCenterDownloadingFileIDs containsObject:@41], "cancelled completion leaves no marker");
    view.currentAuthState = @"closed";
    [view downloadMediaCenterItem:item]; [view saveMediaCenterItemAs:item];
    TGAssert([view.mediaCenterSaveRequests count] == 0 && [origin requestCount] == 9, "signed-out actions cannot reattach manager or start Save As");
    [[NSFileManager defaultManager] removeItemAtPath:TGSource error:NULL]; [TGSource release];
    printf("Media center save production adapter probe: PASS\n"); [pool drain]; return 0;
}
