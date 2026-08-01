#import "TGDownloadManager.h"

#import "../Core/TGTDLibClient.h"
#import "../Media/TGMediaFileActions.h"
#import "../UI/TGStatusSupport.h"
#import "TGResourcePolicy.h"

NSString * const TGDownloadManagerDidChangeNotification = @"TGDownloadManagerDidChangeNotification";
static NSString * const TGCompletedDownloadPathsDefaultsKey = @"TelegraphicaCompletedDownloadPathsByFileID";

@interface TGDownloadManager () {
    dispatch_queue_t _downloadQueue;
    NSUInteger _identifierCounter;
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
        self.records = [NSMutableArray array];
        _downloadQueue = dispatch_queue_create("org.telegraphica.downloads", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [_client release];
    [_records release];
    if (_downloadQueue) {
        dispatch_release(_downloadQueue);
    }
    [super dealloc];
}

- (void)setClient:(TGTDLibClient *)client {
    @synchronized(self) {
        if (_client != client) {
            [_client release];
            _client = [client retain];
        }
    }
}

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:TGDownloadManagerDidChangeNotification
                                                            object:self];
    });
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
            [snapshot addObject:[NSDictionary dictionaryWithDictionary:[self.records objectAtIndex:index]]];
        }
        return [NSArray arrayWithArray:snapshot];
    }
}

- (NSString *)presentationStateForFileID:(NSNumber *)fileID
                               savedPath:(NSString **)savedPathOut {
    if (savedPathOut) {
        *savedPathOut = nil;
    }
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        return nil;
    }

    NSString *state = nil;
    NSString *savedPath = nil;
    @synchronized(self) {
        NSUInteger index = 0;
        for (index = 0; index < [self.records count]; index++) {
            NSDictionary *record = [self.records objectAtIndex:index];
            if ([[record objectForKey:@"file_id"] integerValue] != [fileID integerValue]) {
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
        NSDictionary *completedPaths = [[NSUserDefaults standardUserDefaults]
            dictionaryForKey:TGCompletedDownloadPathsDefaultsKey];
        NSString *persistedPath = [completedPaths objectForKey:[fileID stringValue]];
        if ([persistedPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:persistedPath]) {
            state = [@"completed" copy];
            savedPath = [persistedPath copy];
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

- (NSString *)enqueueFileID:(NSNumber *)fileID
          suggestedFileName:(NSString *)suggestedFileName
          fallbackLocalPath:(NSString *)fallbackLocalPath
                 completion:(TGDownloadCompletionBlock)completion {
    BOOL hasFileID = ([fileID respondsToSelector:@selector(integerValue)] && [fileID integerValue] > 0);
    BOOL hasFallback = ([fallbackLocalPath length] > 0 &&
                        [[NSFileManager defaultManager] fileExistsAtPath:fallbackLocalPath]);
    if (!hasFileID && !hasFallback) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"Telegraphica.Downloads"
                                                 code:1
                                             userInfo:[NSDictionary dictionaryWithObject:@"The file is not available yet."
                                                                                  forKey:NSLocalizedDescriptionKey]];
            completion(nil, error, NO);
        }
        return nil;
    }

    if (hasFileID) {
        @synchronized(self) {
            NSUInteger existingIndex = 0;
            for (existingIndex = 0; existingIndex < [self.records count]; existingIndex++) {
                NSDictionary *existingRecord = [self.records objectAtIndex:existingIndex];
                NSString *existingState = [existingRecord objectForKey:@"state"];
                if ([[existingRecord objectForKey:@"file_id"] integerValue] == [fileID integerValue] &&
                    ([existingState isEqualToString:@"queued"] || [existingState isEqualToString:@"downloading"])) {
                    return [existingRecord objectForKey:@"identifier"];
                }
            }
        }
    }

    NSString *identifier = [self nextIdentifier];
    NSString *fileName = [suggestedFileName length] > 0
        ? [suggestedFileName lastPathComponent]
        : ([fallbackLocalPath length] > 0 ? [fallbackLocalPath lastPathComponent] : @"download");
    NSMutableDictionary *record = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   identifier, @"identifier",
                                   fileName, @"file_name",
                                   @"queued", @"state",
                                   [NSDate date], @"created_at",
                                   [NSNumber numberWithBool:NO], @"cancelled",
                                   nil];
    if (hasFileID) {
        [record setObject:[NSNumber numberWithInteger:[fileID integerValue]] forKey:@"file_id"];
    }
    if ([fallbackLocalPath length] > 0) {
        [record setObject:fallbackLocalPath forKey:@"fallback_path"];
    }
    @synchronized(self) {
        [self.records insertObject:record atIndex:0];
    }
    [self postChange];

    NSNumber *fileIDCopy = [fileID retain];
    NSString *fileNameCopy = [fileName copy];
    NSString *fallbackCopy = [fallbackLocalPath copy];
    NSString *identifierCopy = [identifier copy];
    TGDownloadCompletionBlock completionCopy = [completion copy];
    TGTDLibClient *client = nil;
    @synchronized(self) {
        client = [_client retain];
    }
    dispatch_async(_downloadQueue, ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        BOOL cancelled = NO;
        @synchronized(self) {
            NSMutableDictionary *current = [self recordForIdentifier:identifierCopy];
            cancelled = [[current objectForKey:@"cancelled"] boolValue];
            if (!cancelled) {
                [current setObject:@"downloading" forKey:@"state"];
            }
        }
        [self postChange];

        NSError *error = nil;
        NSString *sourcePath = nil;
        if (!cancelled && [fileIDCopy integerValue] > 0 && client) {
            sourcePath = [client downloadedLocalPathForFileID:fileIDCopy timeout:45.0 error:&error];
        }
        if (!cancelled && [sourcePath length] == 0 &&
            [fallbackCopy length] > 0 &&
            [[NSFileManager defaultManager] fileExistsAtPath:fallbackCopy]) {
            sourcePath = fallbackCopy;
            error = nil;
        }

        @synchronized(self) {
            NSMutableDictionary *current = [self recordForIdentifier:identifierCopy];
            cancelled = cancelled || [[current objectForKey:@"cancelled"] boolValue];
        }
        NSString *savedPath = nil;
        if (!cancelled && [sourcePath length] > 0) {
            savedPath = [TGMediaFileActions saveCopyOfFileAtPath:sourcePath
                                               suggestedFileName:fileNameCopy
                                                     toDirectory:TGConfiguredDownloadFolderPath()
                                                           error:&error];
        }

        NSString *errorMessage = [[error localizedDescription] copy];
        @synchronized(self) {
            NSMutableDictionary *current = [self recordForIdentifier:identifierCopy];
            if (cancelled) {
                [current setObject:@"cancelled" forKey:@"state"];
            } else if ([savedPath length] > 0) {
                [current setObject:@"completed" forKey:@"state"];
                [current setObject:savedPath forKey:@"saved_path"];
                [current setObject:[NSDate date] forKey:@"finished_at"];
                if ([fileIDCopy integerValue] > 0) {
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    NSMutableDictionary *completedPaths = [NSMutableDictionary dictionaryWithDictionary:
                        ([defaults dictionaryForKey:TGCompletedDownloadPathsDefaultsKey] ?: [NSDictionary dictionary])];
                    [completedPaths setObject:savedPath forKey:[fileIDCopy stringValue]];
                    [defaults setObject:completedPaths forKey:TGCompletedDownloadPathsDefaultsKey];
                    [defaults synchronize];
                }
            } else {
                [current setObject:@"failed" forKey:@"state"];
                [current setObject:([errorMessage length] > 0 ? errorMessage : @"Download failed.")
                            forKey:@"error"];
            }
        }
        [self postChange];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionCopy) {
                NSError *completionError = nil;
                if (!cancelled && [savedPath length] == 0) {
                    completionError = [NSError errorWithDomain:@"Telegraphica.Downloads"
                                                         code:2
                                                     userInfo:[NSDictionary dictionaryWithObject:
                                                               ([errorMessage length] > 0 ? errorMessage : @"Download failed.")
                                                                                                  forKey:NSLocalizedDescriptionKey]];
                }
                completionCopy(savedPath, completionError, cancelled);
            }
            [completionCopy release];
            [errorMessage release];
            [identifierCopy release];
            [fallbackCopy release];
            [fileNameCopy release];
            [fileIDCopy release];
            [client release];
        });
        [pool drain];
    });
    return identifier;
}

- (void)cancelDownloadWithIdentifier:(NSString *)identifier {
    NSNumber *fileID = nil;
    TGTDLibClient *client = nil;
    @synchronized(self) {
        NSMutableDictionary *record = [self recordForIdentifier:identifier];
        NSString *state = [record objectForKey:@"state"];
        if (!record || [state isEqualToString:@"completed"] ||
            [state isEqualToString:@"failed"] || [state isEqualToString:@"cancelled"]) {
            return;
        }
        [record setObject:[NSNumber numberWithBool:YES] forKey:@"cancelled"];
        [record setObject:@"cancelled" forKey:@"state"];
        fileID = [[record objectForKey:@"file_id"] retain];
        client = [_client retain];
    }
    [self postChange];
    if ([fileID integerValue] > 0 && client) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            [client cancelDownloadForFileID:fileID timeout:5.0 error:NULL];
            [fileID release];
            [client release];
            [pool drain];
        });
    } else {
        [fileID release];
        [client release];
    }
}

- (void)cancelDownloadsForFileID:(NSNumber *)fileID {
    if (![fileID respondsToSelector:@selector(integerValue)]) {
        return;
    }
    NSMutableArray *identifiers = [NSMutableArray array];
    @synchronized(self) {
        NSUInteger index = 0;
        for (index = 0; index < [self.records count]; index++) {
            NSDictionary *record = [self.records objectAtIndex:index];
            NSString *state = [record objectForKey:@"state"];
            if ([[record objectForKey:@"file_id"] integerValue] == [fileID integerValue] &&
                ([state isEqualToString:@"queued"] || [state isEqualToString:@"downloading"])) {
                [identifiers addObject:[record objectForKey:@"identifier"]];
            }
        }
    }
    NSUInteger index = 0;
    for (index = 0; index < [identifiers count]; index++) {
        [self cancelDownloadWithIdentifier:[identifiers objectAtIndex:index]];
    }
}

- (void)retryDownloadWithIdentifier:(NSString *)identifier
                         completion:(TGDownloadCompletionBlock)completion {
    NSDictionary *record = nil;
    @synchronized(self) {
        NSMutableDictionary *found = [self recordForIdentifier:identifier];
        if (found) {
            record = [[NSDictionary alloc] initWithDictionary:found];
        }
    }
    if (!record) {
        return;
    }
    [self enqueueFileID:[record objectForKey:@"file_id"]
      suggestedFileName:[record objectForKey:@"file_name"]
      fallbackLocalPath:[record objectForKey:@"fallback_path"]
             completion:completion];
    [record release];
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
