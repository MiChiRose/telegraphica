#import "TGDownloadManager.h"

#import "../Core/TGTDLibClient.h"
#import "../Core/TGTDLibClient+Files.h"
#import "../Media/TGMediaFileActions.h"
#import "../UI/TGStatusSupport.h"
#import "TGResourcePolicy.h"
#import "TGDownloadQueueStore.h"

NSString * const TGDownloadManagerDidChangeNotification = @"TGDownloadManagerDidChangeNotification";

@interface TGDownloadManager () {
    NSOperationQueue *_downloadQueue;
    NSObject *_exportLock;
    NSMutableDictionary *_fileOperations;
    NSMutableDictionary *_completedPathsByFileID;
    NSNumber *_clientAccountID;
    NSUInteger _identifierCounter;
    BOOL _didResumePersistedRecords;
}
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, retain) NSMutableArray *records;
@end

@implementation TGDownloadManager

@synthesize client = _client;
@synthesize records = _records;

+ (TGDownloadManager *)sharedManager {
    static TGDownloadManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[TGDownloadManager alloc] init];
    });
    return manager;
}

- (id)init {
    self = [super init];
    if (self) {
        NSArray *storedRecords = [[NSUserDefaults standardUserDefaults] objectForKey:TGDownloadQueueRecordsDefaultsKey];
        self.records = [NSMutableArray arrayWithArray:TGDownloadQueueNormalizedRecords(storedRecords)];
        _downloadQueue = [[NSOperationQueue alloc] init];
        [_downloadQueue setMaxConcurrentOperationCount:2];
        _exportLock = [[NSObject alloc] init];
        _fileOperations = [[NSMutableDictionary alloc] init];
        _completedPathsByFileID = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_records release];
    [_downloadQueue release];
    [_exportLock release];
    [_fileOperations release];
    [_completedPathsByFileID release];
    [_clientAccountID release];
    [super dealloc];
}

- (void)setClient:(TGTDLibClient *)client {
    BOOL changed = NO;
    @synchronized(self) {
        if (_client != client) {
            changed = YES;
            for (NSMutableDictionary *record in self.records) {
                if (_client && [[record objectForKey:@"file_id"] longLongValue] > 0) {
                    [record setObject:[NSNumber numberWithBool:YES] forKey:@"requires_remote_resolution"];
                }
                NSString *state = [record objectForKey:@"state"];
                BOOL unfinished = [state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"] ||
                                  [state isEqualToString:@"paused"] || [state isEqualToString:@"interrupted"];
                // Restored paused records have no live owner yet. First ready
                // client attachment keeps them paused; subsequent detaches do not.
                if (unfinished && (_client || [record objectForKey:@"client"] || [record objectForKey:@"attempt"])) {
                    [self stopRecord:record state:@"cancelled"];
                    [self deliverRecordCompletions:record savedPath:nil error:nil cancelled:YES];
                    [record removeObjectForKey:@"client"];
                }
            }
            [_client release];
            _client = [client retain];
            [_clientAccountID release]; _clientAccountID = nil;
            [_completedPathsByFileID removeAllObjects];
            _didResumePersistedRecords = NO;
        }
    }
    if (changed) { [self postChange]; }
}

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Capture at delivery, not on the posting worker. Otherwise an older
        // downloading snapshot can overwrite a newer persisted Pause decision.
        NSArray *snapshot = nil;
        @synchronized(self) {
            snapshot = [[NSArray alloc] initWithArray:TGDownloadQueueSerializableRecords(self.records)];
        }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:snapshot forKey:TGDownloadQueueRecordsDefaultsKey];
        [defaults synchronize];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGDownloadManagerDidChangeNotification
                                                            object:self];
        [snapshot release];
    });
}

- (void)resumePendingDownloads {
    NSMutableArray *recordsToResume = [NSMutableArray array];
    @synchronized(self) {
        if (_didResumePersistedRecords || !_client) {
            return;
        }
        _didResumePersistedRecords = YES;
        NSIndexSet *interruptedIndexes = [self.records indexesOfObjectsPassingTest:
            ^BOOL(id object, NSUInteger index, BOOL *stop) {
                (void)index;
                (void)stop;
                return [[object objectForKey:@"state"] isEqualToString:@"interrupted"];
            }];
        if ([interruptedIndexes count] > 0) {
            [recordsToResume addObjectsFromArray:[self.records objectsAtIndexes:interruptedIndexes]];
            [self.records removeObjectsAtIndexes:interruptedIndexes];
        }
    }
    if ([recordsToResume count] == 0) {
        return;
    }
    [self postChange];
    NSUInteger index = 0;
    for (index = 0; index < [recordsToResume count]; index++) {
        NSDictionary *record = [recordsToResume objectAtIndex:index];
        [self enqueueFileID:[record objectForKey:@"file_id"]
          suggestedFileName:[record objectForKey:@"file_name"]
          fallbackLocalPath:[record objectForKey:@"fallback_path"]
             identityRecord:record completion:nil];
    }
}

- (NSMutableDictionary *)recordForIdentifier:(NSString *)identifier {
    NSUInteger index = 0;
    for (index = 0; index < [self.records count]; index++) {
        NSMutableDictionary *record = [self.records objectAtIndex:index];
        if ([[record objectForKey:@"identifier"] isEqualToString:identifier]) {
            return record;
        }
    }
    return nil;
}

- (NSArray *)itemsSnapshot {
    @synchronized(self) {
        NSMutableArray *snapshot = [NSMutableArray arrayWithCapacity:[self.records count]];
        NSUInteger index = 0;
        for (index = 0; index < [self.records count]; index++) {
            NSMutableDictionary *record = [self.records objectAtIndex:index];
            NSMutableDictionary *visible = [NSMutableDictionary dictionaryWithDictionary:record];
            [visible removeObjectForKey:@"client"]; [visible removeObjectForKey:@"attempt"]; [visible removeObjectForKey:@"completions"]; [visible removeObjectForKey:@"operation"];
            NSString *state = [record objectForKey:@"state"];
            BOOL active = [state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"];
            BOOL paused = [state isEqualToString:@"paused"];
            BOOL hasID = [[record objectForKey:@"file_id"] longLongValue] > 0;
            TGTDLibClient *owner = [record objectForKey:@"client"];
            [visible setObject:[NSNumber numberWithBool:active] forKey:@"can_pause"];
            [visible setObject:[NSNumber numberWithBool:paused && (!hasID || (_client && (!owner || owner == _client))) ] forKey:@"can_resume"];
            [visible setObject:[NSNumber numberWithBool:active || paused || [state isEqualToString:@"interrupted"]] forKey:@"can_cancel"];
            [snapshot addObject:visible];
        }
        return [NSArray arrayWithArray:snapshot];
    }
}

- (NSString *)presentationStateForFileID:(NSNumber *)fileID
                               savedPath:(NSString **)savedPathOut {
    if (savedPathOut) {
        *savedPathOut = nil;
    }
    if (![fileID respondsToSelector:@selector(longLongValue)] || [fileID longLongValue] <= 0) {
        return nil;
    }

    NSString *state = nil;
    NSString *savedPath = nil;
    @synchronized(self) {
        NSUInteger index = 0;
        for (index = 0; index < [self.records count]; index++) {
            NSDictionary *record = [self.records objectAtIndex:index];
            if ([[record objectForKey:@"requires_remote_resolution"] boolValue] ||
                [[record objectForKey:@"file_id"] longLongValue] != [fileID longLongValue]) {
                continue;
            }
            state = [[record objectForKey:@"state"] copy];
            savedPath = [[record objectForKey:@"saved_path"] copy];
            break;
        }
    }

    if ([state isEqualToString:@"completed"] &&
        ([savedPath length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:savedPath])) {
        [state release];
        state = nil;
        [savedPath release];
        savedPath = nil;
    }
    if (!state) {
        @synchronized(self) {
            NSString *path = [_completedPathsByFileID objectForKey:[fileID stringValue]];
            if ([path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                state = [@"completed" copy]; savedPath = [path copy];
            }
        }
    }
    if (savedPathOut && [savedPath length] > 0) {
        *savedPathOut = [[savedPath copy] autorelease];
    }
    [savedPath release];
    return [state autorelease];
}

- (NSString *)nextIdentifier {
    @synchronized(self) {
        _identifierCounter++;
        return [NSString stringWithFormat:@"%lld-%lu",
                (long long)([[NSDate date] timeIntervalSince1970] * 1000.0),
                (unsigned long)_identifierCounter];
    }
}

- (void)appendCompletion:(TGDownloadCompletionBlock)completion toRecord:(NSMutableDictionary *)record {
    if (!completion) { return; }
    NSMutableArray *completions = [record objectForKey:@"completions"];
    if (!completions) {
        completions = [[NSMutableArray alloc] init];
        [record setObject:completions forKey:@"completions"];
        [completions release];
    }
    id copied = [completion copy];
    [completions addObject:copied];
    [copied release];
}

- (void)deliverRecordCompletions:(NSMutableDictionary *)record savedPath:(NSString *)savedPath
                          error:(NSError *)error cancelled:(BOOL)cancelled {
    NSArray *completions = [[NSArray alloc] initWithArray:([record objectForKey:@"completions"] ?: [NSArray array])];
    [record removeObjectForKey:@"completions"];
    if ([completions count] == 0) { [completions release]; return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (TGDownloadCompletionBlock completion in completions) { completion(savedPath, error, cancelled); }
        [completions release];
    });
}

- (void)stopRecord:(NSMutableDictionary *)record state:(NSString *)state {
    NSMutableDictionary *attempt = [record objectForKey:@"attempt"];
    [attempt setObject:[NSNumber numberWithBool:YES] forKey:@"stop"];
    [record setObject:state forKey:@"state"];
    [record setObject:[NSNumber numberWithBool:[state isEqualToString:@"cancelled"]] forKey:@"cancelled"];
    [record setObject:[NSNumber numberWithBool:NO] forKey:@"reconnecting"];
}

- (BOOL)record:(NSMutableDictionary *)record ownsAttempt:(NSDictionary *)attempt client:(TGTDLibClient *)client {
    NSString *state = [record objectForKey:@"state"];
    return record && [record objectForKey:@"attempt"] == attempt &&
           ![[attempt objectForKey:@"stop"] boolValue] && _client == client &&
           ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"]);
}

- (void)startRecord:(NSMutableDictionary *)record {
    // Caller holds the manager lock. A dependency covers observer shutdown and
    // its final TDLib cancel, so a quick Resume cannot race that old cancel.
    NSString *identifier = [[record objectForKey:@"identifier"] copy];
    NSNumber *fileID = [[record objectForKey:@"file_id"] retain];
    NSString *fileName = [[record objectForKey:@"file_name"] copy];
    NSString *fallback = [[record objectForKey:@"fallback_path"] copy];
    NSString *remoteID = [[record objectForKey:@"remote_id"] copy];
    NSString *uniqueID = [[record objectForKey:@"remote_unique_id"] copy];
    NSNumber *accountID = [[record objectForKey:@"account_id"] retain];
    BOOL needsResolution = [[record objectForKey:@"requires_remote_resolution"] boolValue];
    NSOperation *previousRecordOperation = [record objectForKey:@"operation"];
    TGTDLibClient *originClient = [_client retain];
    NSMutableDictionary *attempt = [[NSMutableDictionary alloc] init];
    [record setObject:attempt forKey:@"attempt"];
    if (originClient) { [record setObject:originClient forKey:@"client"]; }
    NSString *operationKey = nil;
    if ([remoteID length] > 0) {
        operationKey = [[NSString stringWithFormat:@"remote:%p:%@", originClient, remoteID] copy];
    } else if ([fileID longLongValue] > 0 && !needsResolution) {
        operationKey = [[NSString stringWithFormat:@"%p:%lld", originClient, [fileID longLongValue]] copy];
    } else {
        operationKey = [identifier copy];
    }
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        BOOL current = NO, startedNetwork = NO;
        @synchronized(self) {
            NSMutableDictionary *found = [self recordForIdentifier:identifier];
            current = [self record:found ownsAttempt:attempt client:originClient];
            if (current) { [found setObject:@"downloading" forKey:@"state"]; }
        }
        [self postChange];
        NSError *error = nil;
        NSString *sourcePath = nil;
        NSNumber *resolvedFileID = nil;
        if (current && [fileID longLongValue] > 0 && originClient) {
            if (needsResolution && ([remoteID length] == 0 || !accountID)) {
                error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:4 userInfo:
                         [NSDictionary dictionaryWithObject:@"Reopen this file's message and download it again. This older download has no safe identity for restoring after a restart." forKey:NSLocalizedDescriptionKey]];
            } else {
                NSNumber *readyAccount = nil;
                @synchronized(self) { readyAccount = [_clientAccountID retain]; }
                if (!readyAccount) { readyAccount = [[originClient downloadAccountIDWithError:&error] retain]; }
                @synchronized(self) {
                    current = [self record:[self recordForIdentifier:identifier] ownsAttempt:attempt client:originClient];
                    if (current && readyAccount && !_clientAccountID) { _clientAccountID = [readyAccount retain]; }
                }
                if (current && readyAccount && (!accountID || [accountID isEqual:readyAccount])) {
                    NSDictionary *identity = [originClient downloadFileIdentityForFileID:fileID remoteFileID:remoteID error:&error];
                    NSDictionary *remote = [[identity objectForKey:@"remote"] isKindOfClass:[NSDictionary class]] ?
                                            [identity objectForKey:@"remote"] : nil;
                    NSString *resolvedRemote = [[remote objectForKey:@"id"] isKindOfClass:[NSString class]] ? [remote objectForKey:@"id"] : nil;
                    NSString *resolvedUnique = [[remote objectForKey:@"unique_id"] isKindOfClass:[NSString class]] ? [remote objectForKey:@"unique_id"] : nil;
                    NSNumber *resolvedID = [[identity objectForKey:@"id"] isKindOfClass:[NSNumber class]] ? [identity objectForKey:@"id"] : nil;
                    BOOL validIdentity = [resolvedID longLongValue] > 0 &&
                        ([uniqueID length] == 0 || ([resolvedUnique length] > 0 && [uniqueID isEqualToString:resolvedUnique]));
                    @synchronized(self) {
                        NSMutableDictionary *found = [self recordForIdentifier:identifier];
                        current = [self record:found ownsAttempt:attempt client:originClient];
                        if (current && validIdentity) {
                            NSString *freshKey = [NSString stringWithFormat:@"%p:%lld", originClient, [resolvedID longLongValue]];
                            NSDictionary *other = [_fileOperations objectForKey:freshKey];
                            if (other && [other objectForKey:@"attempt"] != attempt && ![[other objectForKey:@"operation"] isFinished]) {
                                validIdentity = NO;
                                error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:6 userInfo:
                                    [NSDictionary dictionaryWithObject:@"This file already has another active download." forKey:NSLocalizedDescriptionKey]];
                            } else {
                                resolvedFileID = [resolvedID retain];
                                [found setObject:resolvedID forKey:@"file_id"];
                                [found setObject:readyAccount forKey:@"account_id"];
                                [found setObject:[NSNumber numberWithBool:NO] forKey:@"requires_remote_resolution"];
                                if ([resolvedRemote length] > 0) { [found setObject:resolvedRemote forKey:@"remote_id"]; }
                                if ([resolvedUnique length] > 0) { [found setObject:resolvedUnique forKey:@"remote_unique_id"]; }
                                [_fileOperations setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    [attempt objectForKey:@"operation"], @"operation", attempt, @"attempt", nil] forKey:freshKey];
                                if ([resolvedRemote length] > 0) {
                                    NSString *stableKey = [NSString stringWithFormat:@"remote:%p:%@", originClient, resolvedRemote];
                                    [_fileOperations setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                        [attempt objectForKey:@"operation"], @"operation", attempt, @"attempt", nil] forKey:stableKey];
                                }
                            }
                        }
                    }
                    if (!validIdentity && !error) {
                        error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:5 userInfo:
                            [NSDictionary dictionaryWithObject:@"The saved file identity no longer matches. Reopen the file's message and download it again." forKey:NSLocalizedDescriptionKey]];
                    }
                } else if (current && accountID && readyAccount) {
                    error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:7 userInfo:
                        [NSDictionary dictionaryWithObject:@"This download belongs to another Telegram account. Reopen the file's message in the current account." forKey:NSLocalizedDescriptionKey]];
                }
                [readyAccount release];
            }
        }
        if (current && resolvedFileID) {
            // Publish the restart-safe identity even if the first transfer RPC
            // times out before reporting any byte progress.
            [self postChange];
            startedNetwork = YES;
            sourcePath = [originClient persistentDownloadedLocalPathForFileID:resolvedFileID cancelled:^BOOL {
                @synchronized(self) {
                    return ![self record:[self recordForIdentifier:identifier] ownsAttempt:attempt client:originClient];
                }
            } progress:^(long long downloadedBytes, long long totalBytes, BOOL reconnecting) {
                BOOL changed = NO;
                @synchronized(self) {
                    NSMutableDictionary *found = [self recordForIdentifier:identifier];
                    if ([self record:found ownsAttempt:attempt client:originClient]) {
                        changed = [[found objectForKey:@"downloaded_bytes"] longLongValue] != downloadedBytes ||
                                  [[found objectForKey:@"total_bytes"] longLongValue] != totalBytes ||
                                  [[found objectForKey:@"reconnecting"] boolValue] != reconnecting;
                        [found setObject:[NSNumber numberWithLongLong:downloadedBytes] forKey:@"downloaded_bytes"];
                        [found setObject:[NSNumber numberWithLongLong:totalBytes] forKey:@"total_bytes"];
                        [found setObject:[NSNumber numberWithBool:reconnecting] forKey:@"reconnecting"];
                    }
                }
                if (changed) { [self postChange]; }
            } error:&error];
        }
        if (current && [fileID longLongValue] <= 0 && [fallback length] > 0 &&
            [[NSFileManager defaultManager] fileExistsAtPath:fallback]) { sourcePath = fallback; }
        if (current && [fileID longLongValue] > 0 && !originClient) {
            error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:3 userInfo:
                     [NSDictionary dictionaryWithObject:@"Sign in before downloading this file." forKey:NSLocalizedDescriptionKey]];
        }
        NSString *savedPath = nil;
        if ([sourcePath length] > 0) {
            @synchronized(_exportLock) {
                @synchronized(self) {
                    current = [self record:[self recordForIdentifier:identifier] ownsAttempt:attempt client:originClient];
                }
                if (current) {
                    savedPath = [TGMediaFileActions saveCopyOfFileAtPath:sourcePath suggestedFileName:fileName
                                                         toDirectory:TGConfiguredDownloadFolderPath() error:&error];
                }
            }
        }
        BOOL stopNetwork = NO;
        @synchronized(self) {
            NSMutableDictionary *found = [self recordForIdentifier:identifier];
            current = [self record:found ownsAttempt:attempt client:originClient];
            if (!current) {
                // Remove only this attempt's new unique export, never its cache.
                if ([savedPath length] > 0) { [[NSFileManager defaultManager] removeItemAtPath:savedPath error:NULL]; }
                savedPath = nil;
            } else {
                if ([savedPath length] > 0) {
                    [found setObject:@"completed" forKey:@"state"];
                    [found setObject:savedPath forKey:@"saved_path"];
                    [found setObject:[NSDate date] forKey:@"finished_at"];
                    if ([resolvedFileID longLongValue] > 0) {
                        [_completedPathsByFileID setObject:savedPath forKey:[resolvedFileID stringValue]];
                    }
                    [self deliverRecordCompletions:found savedPath:savedPath error:nil cancelled:NO];
                } else {
                    NSString *message = [[error localizedDescription] length] > 0 ? [error localizedDescription] : @"Download failed.";
                    [found setObject:@"failed" forKey:@"state"];
                    [found setObject:message forKey:@"error"];
                    NSError *failure = [NSError errorWithDomain:@"Telegraphica.Downloads" code:2 userInfo:
                                        [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
                    [self deliverRecordCompletions:found savedPath:nil error:failure cancelled:NO];
                }
            }
            stopNetwork = startedNetwork && [[attempt objectForKey:@"stop"] boolValue];
        }
        // This finishes before the operation dependency releases a new attempt.
        // TDLib retains its already downloaded chunks; Cancel does not delete it.
        if (stopNetwork) { [originClient cancelDownloadForFileID:resolvedFileID timeout:5.0 error:NULL]; }
        @synchronized(self) {
            NSMutableDictionary *found = [self recordForIdentifier:identifier];
            if ([found objectForKey:@"attempt"] == attempt) {
                [found removeObjectForKey:@"attempt"];
                [found removeObjectForKey:@"operation"];
                if (![[found objectForKey:@"state"] isEqualToString:@"paused"]) { [found removeObjectForKey:@"client"]; }
            }
            NSArray *operationKeys = [[_fileOperations allKeys] copy];
            for (NSString *key in operationKeys) {
                if ([[_fileOperations objectForKey:key] objectForKey:@"attempt"] == attempt) { [_fileOperations removeObjectForKey:key]; }
            }
            [operationKeys release];
            [attempt removeObjectForKey:@"operation"];
        }
        [self postChange];
        [identifier release]; [fileID release]; [fileName release]; [fallback release];
        [originClient release]; [attempt release]; [operationKey release];
        [resolvedFileID release]; [remoteID release]; [uniqueID release]; [accountID release];
        [pool drain];
    }];
    NSOperation *previous = [[_fileOperations objectForKey:operationKey] objectForKey:@"operation"];
    if (previous) { [operation addDependency:previous]; }
    if (previousRecordOperation && previousRecordOperation != previous) { [operation addDependency:previousRecordOperation]; }
    [record setObject:operation forKey:@"operation"];
    [attempt setObject:operation forKey:@"operation"];
    [_fileOperations setObject:[NSDictionary dictionaryWithObjectsAndKeys:operation, @"operation", attempt, @"attempt", nil]
                       forKey:operationKey];
    [_downloadQueue addOperation:operation];
}

- (NSString *)enqueueFileID:(NSNumber *)fileID suggestedFileName:(NSString *)suggestedFileName
          fallbackLocalPath:(NSString *)fallbackLocalPath completion:(TGDownloadCompletionBlock)completion {
    return [self enqueueFileID:fileID suggestedFileName:suggestedFileName fallbackLocalPath:fallbackLocalPath
                identityRecord:nil completion:completion];
}

- (NSString *)enqueueFileID:(NSNumber *)fileID suggestedFileName:(NSString *)suggestedFileName
          fallbackLocalPath:(NSString *)fallbackLocalPath identityRecord:(NSDictionary *)identityRecord
                 completion:(TGDownloadCompletionBlock)completion {
    BOOL hasID = [fileID respondsToSelector:@selector(longLongValue)] && [fileID longLongValue] > 0;
    BOOL hasLocal = [fallbackLocalPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:fallbackLocalPath];
    if (!hasID && !hasLocal) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"Telegraphica.Downloads" code:1 userInfo:
                             [NSDictionary dictionaryWithObject:@"The file is not available yet." forKey:NSLocalizedDescriptionKey]];
            completion(nil, error, NO);
        }
        return nil;
    }
    NSString *identifier = nil;
    @synchronized(self) {
        if (hasID) {
            for (NSDictionary *existing in self.records) {
                NSString *state = [existing objectForKey:@"state"];
                BOOL sameRemote = [[identityRecord objectForKey:@"remote_id"] length] > 0 &&
                    [[identityRecord objectForKey:@"remote_id"] isEqual:[existing objectForKey:@"remote_id"]] &&
                    [[identityRecord objectForKey:@"account_id"] isEqual:[existing objectForKey:@"account_id"]];
                BOOL sameCurrentID = ![[existing objectForKey:@"requires_remote_resolution"] boolValue] &&
                    ![[identityRecord objectForKey:@"requires_remote_resolution"] boolValue] &&
                    [[existing objectForKey:@"file_id"] longLongValue] == [fileID longLongValue];
                if ((sameRemote || sameCurrentID) &&
                    ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"] || [state isEqualToString:@"paused"])) {
                    return [existing objectForKey:@"identifier"];
                }
            }
        }
        identifier = [self nextIdentifier];
        NSString *name = [suggestedFileName length] > 0 ? [suggestedFileName lastPathComponent] :
                         ([fallbackLocalPath length] > 0 ? [fallbackLocalPath lastPathComponent] : @"download");
        NSMutableDictionary *record = [NSMutableDictionary dictionaryWithObjectsAndKeys:identifier, @"identifier",
            name, @"file_name", @"queued", @"state", [NSDate date], @"created_at", [NSNumber numberWithBool:NO], @"cancelled", nil];
        if (hasID) { [record setObject:fileID forKey:@"file_id"]; }
        if ([fallbackLocalPath length] > 0) { [record setObject:fallbackLocalPath forKey:@"fallback_path"]; }
        for (NSString *key in [NSArray arrayWithObjects:@"remote_id", @"remote_unique_id", @"account_id", @"requires_remote_resolution", nil]) {
            id value = [identityRecord objectForKey:key]; if (value) { [record setObject:value forKey:key]; }
        }
        [self appendCompletion:completion toRecord:record];
        [self.records insertObject:record atIndex:0];
        [self startRecord:record];
    }
    [self postChange];
    return identifier;
}

- (void)pauseDownloadWithIdentifier:(NSString *)identifier {
    @synchronized(self) {
        NSMutableDictionary *record = [self recordForIdentifier:identifier];
        NSString *state = [record objectForKey:@"state"];
        if (![state isEqualToString:@"queued"] && ![state isEqualToString:@"downloading"]) { return; }
        [self stopRecord:record state:@"paused"];
    }
    [self postChange];
}

- (void)resumeDownloadWithIdentifier:(NSString *)identifier completion:(TGDownloadCompletionBlock)completion {
    @synchronized(self) {
        NSMutableDictionary *record = [self recordForIdentifier:identifier];
        if (![[record objectForKey:@"state"] isEqualToString:@"paused"]) { return; }
        BOOL hasID = [[record objectForKey:@"file_id"] longLongValue] > 0;
        TGTDLibClient *owner = [record objectForKey:@"client"];
        if (hasID && (!_client || (owner && owner != _client))) { return; }
        [self appendCompletion:completion toRecord:record];
        [record setObject:@"queued" forKey:@"state"];
        [record setObject:[NSNumber numberWithBool:NO] forKey:@"cancelled"];
        [record removeObjectForKey:@"error"];
        [self startRecord:record];
    }
    [self postChange];
}

- (void)cancelDownloadWithIdentifier:(NSString *)identifier {
    @synchronized(self) {
        NSMutableDictionary *record = [self recordForIdentifier:identifier];
        NSString *state = [record objectForKey:@"state"];
        if (!record || [state isEqualToString:@"completed"] || [state isEqualToString:@"failed"] || [state isEqualToString:@"cancelled"]) { return; }
        [self stopRecord:record state:@"cancelled"];
        [self deliverRecordCompletions:record savedPath:nil error:nil cancelled:YES];
        [record removeObjectForKey:@"client"];
    }
    [self postChange];
}

- (void)cancelDownloadsForFileID:(NSNumber *)fileID {
    if (![fileID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    NSMutableArray *identifiers = [NSMutableArray array];
    @synchronized(self) {
        NSUInteger index = 0;
        for (index = 0; index < [self.records count]; index++) {
            NSDictionary *record = [self.records objectAtIndex:index];
            NSString *state = [record objectForKey:@"state"];
            if (![[record objectForKey:@"requires_remote_resolution"] boolValue] &&
                [[record objectForKey:@"file_id"] longLongValue] == [fileID longLongValue] &&
                ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"] || [state isEqualToString:@"paused"])) {
                [identifiers addObject:[record objectForKey:@"identifier"]];
            }
        }
    }
    NSUInteger index = 0;
    for (index = 0; index < [identifiers count]; index++) {
        [self cancelDownloadWithIdentifier:[identifiers objectAtIndex:index]];
    }
}

- (NSString *)enqueueRetryDownloadWithIdentifier:(NSString *)identifier completion:(TGDownloadCompletionBlock)completion {
    NSDictionary *record = nil;
    @synchronized(self) {
        NSMutableDictionary *found = [self recordForIdentifier:identifier];
        if (found) { record = [[NSDictionary alloc] initWithDictionary:found]; }
    }
    if (!record) { return nil; }
    NSString *result = [self enqueueFileID:[record objectForKey:@"file_id"]
                       suggestedFileName:[record objectForKey:@"file_name"]
                       fallbackLocalPath:[record objectForKey:@"fallback_path"]
                          identityRecord:record completion:completion];
    [record release]; return result;
}

- (void)retryDownloadWithIdentifier:(NSString *)identifier completion:(TGDownloadCompletionBlock)completion {
    [self enqueueRetryDownloadWithIdentifier:identifier completion:completion];
}

- (void)clearFinishedDownloads {
    @synchronized(self) {
        NSIndexSet *indexes = [self.records indexesOfObjectsPassingTest:
            ^BOOL(id object, NSUInteger index, BOOL *stop) {
                (void)index;
                (void)stop;
                NSString *state = [object objectForKey:@"state"];
                return [state isEqualToString:@"completed"] ||
                       [state isEqualToString:@"failed"] ||
                       [state isEqualToString:@"cancelled"];
            }];
        if ([indexes count] > 0) {
            [self.records removeObjectsAtIndexes:indexes];
        }
    }
    [self postChange];
}

@end
