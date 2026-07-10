#import "TGTDLibClient.h"
#import "TGChatItem.h"
#import "TGMessageItem.h"
#import "../Services/TGKeychainHelper.h"
#import <dlfcn.h>
#import <Security/Security.h>
#import <stdlib.h>

typedef void *(*TGTDJsonClientCreateFunction)(void);
typedef void (*TGTDJsonClientSendFunction)(void *, const char *);
typedef const char *(*TGTDJsonClientReceiveFunction)(void *, double);
typedef const char *(*TGTDJsonClientExecuteFunction)(void *, const char *);
typedef void (*TGTDJsonClientDestroyFunction)(void *);

static NSString * const TGTDLibErrorDomain = @"TelegraphicaTDLibError";
static NSString * const TGTDLibTDLibCodeErrorKey = @"TelegraphicaTDLibCode";
static NSString * const TGTDLibTDLibMessageErrorKey = @"TelegraphicaTDLibMessage";
static NSString * const TGTDLibTDLibResponseErrorKey = @"TelegraphicaTDLibResponse";
static NSString * const TGTDLibDatabaseEncryptionKeyAccount = @"tdlib_database_encryption_key";
static NSUInteger const TGTDLibMaxPendingResponses = 64;
static NSUInteger const TGTDLibMaxPendingUpdateSummaries = 200;
static NSUInteger const TGTDLibMaxMainChatPreviewLimit = 500;
static NSUInteger const TGTDLibMainChatLoadBatchSize = 40;
static NSUInteger const TGTDLibMainChatLoadAttemptLimit = 8;

@interface TGTDLibClient () {
    void *_libraryHandle;
    void *_client;
    TGTDJsonClientCreateFunction _createFunction;
    TGTDJsonClientSendFunction _sendFunction;
    TGTDJsonClientReceiveFunction _receiveFunction;
    TGTDJsonClientExecuteFunction _executeFunction;
    TGTDJsonClientDestroyFunction _destroyFunction;
    NSCondition *_responseCondition;
    NSMutableDictionary *_pendingResponsesByExtra;
    NSMutableArray *_pendingResponseExtras;
    NSMutableSet *_waitingResponseExtras;
    NSMutableArray *_pendingUpdateSummaries;
    NSArray *_chatFilterInfos;
    NSString *_latestAuthorizationStateSummary;
    NSUInteger _authorizationStateGeneration;
    NSLock *_sendLock;
    NSThread *_receiverThread;
    BOOL _receiverRunning;
    BOOL _receiverShouldStop;
    BOOL _shutdownStarted;
    BOOL _mainChatListExhausted;
    BOOL _chatFilterInfosKnown;
    NSUInteger _activeRequestCount;
}
@property (nonatomic, copy) NSString *loadedPath;
- (void)stopReceiverThread;
- (BOOL)beginActiveRequestWithError:(NSError **)error;
- (void)endActiveRequest;
- (BOOL)isShutdownStarted;
- (BOOL)startReceiverThreadIfNeededWithError:(NSError **)error;
- (void)receiverThreadMain;
- (void)handleReceivedTDLibObject:(NSDictionary *)dictionary;
- (NSArray *)chatFilterInfoItemsFromUpdateObject:(NSDictionary *)dictionary;
- (NSDictionary *)sendTDLibRequest:(NSDictionary *)request waitingForExtra:(NSString *)extra timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
- (NSDictionary *)waitForResponseWithExtra:(NSString *)extra timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
- (NSString *)waitForAuthorizationStateDifferentFromState:(NSString *)state afterGeneration:(NSUInteger)generation timeout:(NSTimeInterval)timeout;
- (NSString *)receiveAuthorizationResultForAction:(NSString *)actionName waitingState:(NSString *)waitingState afterGeneration:(NSUInteger)generation timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
- (NSString *)cachedAuthorizationStateSummary;
- (NSUInteger)authorizationStateGeneration;
- (NSString *)uniqueExtraWithPrefix:(NSString *)prefix;
- (NSArray *)chatFilterChatIDsForFilterID:(NSNumber *)filterID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout exhausted:(BOOL *)exhausted error:(NSError **)error;
- (NSError *)errorWithTDLibErrorResponse:(NSDictionary *)response code:(NSInteger)code;
- (NSInteger)tdlibErrorCodeFromError:(NSError *)error;
- (BOOL)isTDLibLoadChatsExhaustedError:(NSError *)error;
- (void)setMainChatListExhausted:(BOOL)exhausted;
- (NSDictionary *)mediaFileObjectFromContainerObject:(NSDictionary *)containerObject;
- (BOOL)isVisualDocumentObject:(NSDictionary *)documentObject;
- (NSString *)documentVisualLabelFromObject:(NSDictionary *)documentObject;
- (NSDictionary *)visualMediaInfoFromDocumentObject:(id)documentObject
                                      downloadMissing:(BOOL)downloadMissing
                                              timeout:(NSTimeInterval)timeout
                               didRequestDownload:(BOOL *)didRequestDownload;
@end

@implementation TGTDLibClient

@synthesize loadedPath = _loadedPath;

- (instancetype)init {
    self = [super init];
    if (self) {
        _responseCondition = [[NSCondition alloc] init];
        _pendingResponsesByExtra = [[NSMutableDictionary alloc] init];
        _pendingResponseExtras = [[NSMutableArray alloc] init];
        _waitingResponseExtras = [[NSMutableSet alloc] init];
        _pendingUpdateSummaries = [[NSMutableArray alloc] init];
        _sendLock = [[NSLock alloc] init];
    }
    return self;
}

- (BOOL)isShutdownStarted {
    [_responseCondition lock];
    BOOL shuttingDown = _shutdownStarted;
    [_responseCondition unlock];
    return shuttingDown;
}

- (BOOL)beginActiveRequestWithError:(NSError **)error {
    [_responseCondition lock];
    if (_shutdownStarted) {
        [_responseCondition unlock];
        if (error) {
            *error = [self errorWithDescription:@"TDLib client is shutting down." code:50];
        }
        return NO;
    }

    _activeRequestCount++;
    [_responseCondition unlock];
    return YES;
}

- (void)endActiveRequest {
    [_responseCondition lock];
    if (_activeRequestCount > 0) {
        _activeRequestCount--;
    }
    [_responseCondition broadcast];
    [_responseCondition unlock];
}

- (void)shutdownWithTimeout:(NSTimeInterval)timeout {
    if (timeout < 0.0) {
        timeout = 0.0;
    }

    void *client = NULL;
    TGTDJsonClientSendFunction sendFunction = NULL;

    [_responseCondition lock];
    if (!_shutdownStarted) {
        _shutdownStarted = YES;
        [_pendingResponsesByExtra removeAllObjects];
        [_pendingResponseExtras removeAllObjects];
        [_waitingResponseExtras removeAllObjects];
        [_pendingUpdateSummaries removeAllObjects];
        [_chatFilterInfos release];
        _chatFilterInfos = nil;
        _chatFilterInfosKnown = NO;
        [_responseCondition broadcast];
    }
    [_responseCondition unlock];

    [_sendLock lock];
    client = _client;
    sendFunction = _sendFunction;
    if (client && sendFunction) {
        sendFunction(client, "{\"@type\":\"close\"}");
    }
    [_sendLock unlock];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    [_responseCondition lock];
    while (_activeRequestCount > 0 && [[NSDate date] compare:deadline] == NSOrderedAscending) {
        [_responseCondition waitUntilDate:deadline];
    }
    [_responseCondition unlock];

    [self destroyTDLibClient];
}

- (void)destroyTDLibClient {
    [_responseCondition lock];
    _shutdownStarted = YES;
    [_pendingResponsesByExtra removeAllObjects];
    [_pendingResponseExtras removeAllObjects];
    [_waitingResponseExtras removeAllObjects];
    [_pendingUpdateSummaries removeAllObjects];
    [_chatFilterInfos release];
    _chatFilterInfos = nil;
    _chatFilterInfosKnown = NO;
    [_responseCondition broadcast];
    [_responseCondition unlock];

    [self stopReceiverThread];
    [_responseCondition lock];
    [_pendingResponsesByExtra removeAllObjects];
    [_pendingResponseExtras removeAllObjects];
    [_waitingResponseExtras removeAllObjects];
    [_pendingUpdateSummaries removeAllObjects];
    [_chatFilterInfos release];
    _chatFilterInfos = nil;
    _chatFilterInfosKnown = NO;
    [_latestAuthorizationStateSummary release];
    _latestAuthorizationStateSummary = nil;
    _mainChatListExhausted = NO;
    [_responseCondition broadcast];
    [_responseCondition unlock];

    [_sendLock lock];
    if (_client && _destroyFunction) {
        _destroyFunction(_client);
    }
    _client = NULL;
    [_sendLock unlock];
}

- (void)dealloc {
    [self shutdownWithTimeout:1.0];
    if (_libraryHandle) {
        dlclose(_libraryHandle);
        _libraryHandle = NULL;
    }
    [_responseCondition release];
    [_pendingResponsesByExtra release];
    [_pendingResponseExtras release];
    [_waitingResponseExtras release];
    [_pendingUpdateSummaries release];
    [_chatFilterInfos release];
    [_latestAuthorizationStateSummary release];
    [_sendLock release];
    [_receiverThread release];
    [_loadedPath release];
    [super dealloc];
}

- (NSString *)loadedLibraryPath {
    return _loadedPath;
}

- (BOOL)mainChatListExhausted {
    [_responseCondition lock];
    BOOL exhausted = _mainChatListExhausted;
    [_responseCondition unlock];
    return exhausted;
}

- (void)setMainChatListExhausted:(BOOL)exhausted {
    [_responseCondition lock];
    _mainChatListExhausted = exhausted;
    [_responseCondition unlock];
}

- (void)invalidateMainChatListExhaustion {
    [self setMainChatListExhausted:NO];
}

- (NSArray *)chatFilterInfoItemsWithTimeout:(NSTimeInterval)timeout {
    if (timeout < 0.0) {
        timeout = 0.0;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    [_responseCondition lock];
    while (!_chatFilterInfosKnown && [[NSDate date] compare:deadline] == NSOrderedAscending) {
        [_responseCondition waitUntilDate:deadline];
    }
    NSArray *filters = [_chatFilterInfos copy];
    [_responseCondition unlock];

    if (!filters) {
        return [NSArray array];
    }
    return [filters autorelease];
}

- (NSString *)receiverStatusSummary {
    [_responseCondition lock];
    BOOL active = _receiverRunning;
    NSUInteger pendingResponses = [_pendingResponsesByExtra count];
    NSUInteger waitingResponses = [_waitingResponseExtras count];
    NSUInteger pendingUpdates = [_pendingUpdateSummaries count];
    NSString *state = [_latestAuthorizationStateSummary copy];
    [_responseCondition unlock];

    NSString *summary = [NSString stringWithFormat:@"receiver %@; pending responses: %lu; waiting responses: %lu; queued safe updates: %lu%@%@",
                         active ? @"active" : @"idle",
                         (unsigned long)pendingResponses,
                         (unsigned long)waitingResponses,
                         (unsigned long)pendingUpdates,
                         [state length] > 0 ? @"; auth state: " : @"",
                         [state length] > 0 ? state : @""];
    [state release];
    return summary;
}

- (NSArray *)drainSafeUpdateSummaries {
    [_responseCondition lock];
    NSArray *updates = [_pendingUpdateSummaries copy];
    [_pendingUpdateSummaries removeAllObjects];
    [_responseCondition unlock];

    if (!updates) {
        return [NSArray array];
    }
    return [updates autorelease];
}

- (void)stopReceiverThread {
    NSThread *thread = nil;

    [_responseCondition lock];
    _receiverShouldStop = YES;
    thread = [_receiverThread retain];
    [_responseCondition broadcast];
    [_responseCondition unlock];

    if (thread && [NSThread currentThread] != thread) {
        while (![thread isFinished]) {
            [NSThread sleepForTimeInterval:0.05];
        }
    }

    [_responseCondition lock];
    if (_receiverThread == thread && (!thread || [thread isFinished])) {
        [_receiverThread release];
        _receiverThread = nil;
    }
    if (!_receiverThread) {
        _receiverRunning = NO;
        _receiverShouldStop = NO;
    }
    [_responseCondition unlock];

    [thread release];
}

- (BOOL)startReceiverThreadIfNeededWithError:(NSError **)error {
    (void)error;

    [_responseCondition lock];
    if (_shutdownStarted) {
        [_responseCondition unlock];
        if (error) {
            *error = [self errorWithDescription:@"TDLib client is shutting down." code:50];
        }
        return NO;
    }

    if (_receiverRunning || _receiverThread) {
        [_responseCondition unlock];
        return YES;
    }

    _receiverShouldStop = NO;
    _receiverRunning = YES;
    _receiverThread = [[NSThread alloc] initWithTarget:self selector:@selector(receiverThreadMain) object:nil];
    [_receiverThread start];
    [_responseCondition unlock];
    return YES;
}

- (NSArray *)chatFilterInfoItemsFromUpdateObject:(NSDictionary *)dictionary {
    id typeObject = [dictionary objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]] || ![(NSString *)typeObject isEqualToString:@"updateChatFilters"]) {
        return nil;
    }

    id filterObjects = [dictionary objectForKey:@"chat_filters"];
    if (![filterObjects isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *filters = [NSMutableArray arrayWithCapacity:[(NSArray *)filterObjects count]];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)filterObjects count]; index++) {
        id filterObject = [(NSArray *)filterObjects objectAtIndex:index];
        if (![filterObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *filterDictionary = (NSDictionary *)filterObject;
        id identifier = [filterDictionary objectForKey:@"id"];
        id titleObject = [filterDictionary objectForKey:@"title"];
        id iconObject = [filterDictionary objectForKey:@"icon_name"];
        if (![identifier respondsToSelector:@selector(integerValue)] || ![titleObject isKindOfClass:[NSString class]]) {
            continue;
        }

        NSString *title = (NSString *)titleObject;
        if ([title length] == 0) {
            continue;
        }

        NSMutableDictionary *safeFilter = [NSMutableDictionary dictionary];
        [safeFilter setObject:[NSNumber numberWithInteger:[identifier integerValue]] forKey:@"id"];
        [safeFilter setObject:title forKey:@"title"];
        if ([iconObject isKindOfClass:[NSString class]] && [(NSString *)iconObject length] > 0) {
            [safeFilter setObject:iconObject forKey:@"icon_name"];
        }
        [filters addObject:safeFilter];
    }

    return filters;
}

- (NSDictionary *)safeUpdateSummaryForObject:(NSDictionary *)dictionary {
    id typeObject = [dictionary objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *type = (NSString *)typeObject;
    NSString *authorizationSummary = [self summaryForAuthorizationStateObject:dictionary];
    if ([authorizationSummary length] > 0) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"authorization" forKey:@"kind"];
        [summary setObject:authorizationSummary forKey:@"state"];
        return summary;
    }

    if ([type isEqualToString:@"updateNewMessage"]) {
        id messageObject = [dictionary objectForKey:@"message"];
        if (![messageObject isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        NSDictionary *message = (NSDictionary *)messageObject;
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"new_message" forKey:@"kind"];

        id chatID = [message objectForKey:@"chat_id"];
        if ([chatID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        }

        id date = [message objectForKey:@"date"];
        if ([date respondsToSelector:@selector(integerValue)]) {
            [summary setObject:[NSNumber numberWithInteger:[date integerValue]] forKey:@"date"];
        }

        id isOutgoing = [message objectForKey:@"is_outgoing"];
        NSString *direction = ([isOutgoing respondsToSelector:@selector(boolValue)] && [isOutgoing boolValue]) ? @"Outgoing" : @"Incoming";
        [summary setObject:direction forKey:@"direction"];

        return summary;
    }

    if ([type isEqualToString:@"updateChatFilters"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"chat_filters" forKey:@"kind"];
        id filterObjects = [dictionary objectForKey:@"chat_filters"];
        if ([filterObjects isKindOfClass:[NSArray class]]) {
            [summary setObject:[NSNumber numberWithUnsignedInteger:[(NSArray *)filterObjects count]] forKey:@"count"];
        }
        return summary;
    }

    if ([type hasPrefix:@"update"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        id chatID = [dictionary objectForKey:@"chat_id"];
        if (![chatID respondsToSelector:@selector(longLongValue)] && [type isEqualToString:@"updateNewChat"]) {
            id chatObject = [dictionary objectForKey:@"chat"];
            if ([chatObject isKindOfClass:[NSDictionary class]]) {
                chatID = [(NSDictionary *)chatObject objectForKey:@"id"];
            }
        }
        if ([chatID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:@"chat_update" forKey:@"kind"];
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        } else {
            [summary setObject:@"update" forKey:@"kind"];
        }
        [summary setObject:type forKey:@"type"];
        return summary;
    }

    return nil;
}

- (void)enqueueSafeUpdateSummaryLocked:(NSDictionary *)summary {
    if (!summary) {
        return;
    }

    [_pendingUpdateSummaries addObject:summary];
    while ([_pendingUpdateSummaries count] > TGTDLibMaxPendingUpdateSummaries) {
        [_pendingUpdateSummaries removeObjectAtIndex:0];
    }
}

- (void)handleReceivedTDLibObject:(NSDictionary *)dictionary {
    NSString *authorizationSummary = [self summaryForAuthorizationStateObject:dictionary];
    id extraObject = [dictionary objectForKey:@"@extra"];
    NSArray *chatFilterInfos = [self chatFilterInfoItemsFromUpdateObject:dictionary];
    NSDictionary *updateSummary = nil;
    if (![extraObject isKindOfClass:[NSString class]]) {
        updateSummary = [self safeUpdateSummaryForObject:dictionary];
    }

    [_responseCondition lock];
    if ([authorizationSummary length] > 0) {
        [_latestAuthorizationStateSummary release];
        _latestAuthorizationStateSummary = [authorizationSummary copy];
        _authorizationStateGeneration++;
    }

    if (chatFilterInfos) {
        [_chatFilterInfos release];
        _chatFilterInfos = [chatFilterInfos copy];
        _chatFilterInfosKnown = YES;
    }

    if ([extraObject isKindOfClass:[NSString class]] && [_waitingResponseExtras containsObject:extraObject]) {
        NSString *extra = (NSString *)extraObject;
        if (![_pendingResponsesByExtra objectForKey:extra]) {
            [_pendingResponseExtras addObject:extra];
        }
        [_pendingResponsesByExtra setObject:dictionary forKey:extra];
        while ([_pendingResponseExtras count] > TGTDLibMaxPendingResponses) {
            NSString *oldExtra = [[_pendingResponseExtras objectAtIndex:0] retain];
            [_pendingResponseExtras removeObjectAtIndex:0];
            [_pendingResponsesByExtra removeObjectForKey:oldExtra];
            [_waitingResponseExtras removeObject:oldExtra];
            [oldExtra release];
        }
    } else if (updateSummary) {
        [self enqueueSafeUpdateSummaryLocked:updateSummary];
    }

    [_responseCondition broadcast];
    [_responseCondition unlock];
}

- (void)receiverThreadMain {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    for (;;) {
        [_responseCondition lock];
        BOOL shouldStop = _receiverShouldStop;
        [_responseCondition unlock];
        if (shouldStop) {
            break;
        }

        NSAutoreleasePool *loopPool = [[NSAutoreleasePool alloc] init];
        if (!_client || !_receiveFunction) {
            [NSThread sleepForTimeInterval:0.05];
            [loopPool drain];
            continue;
        }

        const char *raw = _receiveFunction(_client, 0.25);
        if (raw) {
            NSString *jsonString = [NSString stringWithUTF8String:raw];
            NSError *jsonError = nil;
            id object = [self JSONObjectFromJSONString:jsonString error:&jsonError];
            if ([object isKindOfClass:[NSDictionary class]]) {
                [self handleReceivedTDLibObject:(NSDictionary *)object];
            }
        }
        [loopPool drain];
    }

    [_responseCondition lock];
    _receiverRunning = NO;
    [_responseCondition broadcast];
    [_responseCondition unlock];

    [pool drain];
}

- (NSString *)cachedAuthorizationStateSummary {
    [_responseCondition lock];
    NSString *summary = [_latestAuthorizationStateSummary copy];
    [_responseCondition unlock];
    return [summary autorelease];
}

- (NSUInteger)authorizationStateGeneration {
    [_responseCondition lock];
    NSUInteger generation = _authorizationStateGeneration;
    [_responseCondition unlock];
    return generation;
}

- (NSString *)uniqueExtraWithPrefix:(NSString *)prefix {
    return [NSString stringWithFormat:@"%@-%@-%u",
            prefix ? prefix : @"telegraphica-request",
            [[NSProcessInfo processInfo] globallyUniqueString],
            (unsigned int)arc4random()];
}

- (void)beginWaitingForExtra:(NSString *)extra {
    if ([extra length] == 0) {
        return;
    }

    [_responseCondition lock];
    [_pendingResponsesByExtra removeObjectForKey:extra];
    [_pendingResponseExtras removeObject:extra];
    [_waitingResponseExtras addObject:extra];
    [_responseCondition unlock];
}

- (NSDictionary *)waitForResponseWithExtra:(NSString *)extra timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    if ([extra length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib request is missing an @extra correlation id." code:errorCode];
        }
        return nil;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    [_responseCondition lock];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        if (_shutdownStarted) {
            [_pendingResponsesByExtra removeObjectForKey:extra];
            [_pendingResponseExtras removeObject:extra];
            [_waitingResponseExtras removeObject:extra];
            [_responseCondition unlock];
            if (error) {
                *error = [self errorWithDescription:@"TDLib client is shutting down." code:errorCode];
            }
            return nil;
        }

        NSDictionary *response = [_pendingResponsesByExtra objectForKey:extra];
        if (response) {
            NSDictionary *retainedResponse = [response retain];
            [_pendingResponsesByExtra removeObjectForKey:extra];
            [_pendingResponseExtras removeObject:extra];
            [_waitingResponseExtras removeObject:extra];
            [_responseCondition unlock];
            return [retainedResponse autorelease];
        }

        [_responseCondition waitUntilDate:deadline];
    }

    [_pendingResponsesByExtra removeObjectForKey:extra];
    [_pendingResponseExtras removeObject:extra];
    [_waitingResponseExtras removeObject:extra];
    [_responseCondition unlock];

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not return the requested response before the probe timed out." code:errorCode];
    }
    return nil;
}

- (NSString *)waitForAuthorizationStateDifferentFromState:(NSString *)state afterGeneration:(NSUInteger)generation timeout:(NSTimeInterval)timeout {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    [_responseCondition lock];
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        if (_authorizationStateGeneration > generation && [_latestAuthorizationStateSummary length] > 0 && ![_latestAuthorizationStateSummary isEqualToString:state]) {
            NSString *summary = [_latestAuthorizationStateSummary copy];
            [_responseCondition unlock];
            return [summary autorelease];
        }
        [_responseCondition waitUntilDate:deadline];
    }
    [_responseCondition unlock];
    return nil;
}

- (NSDictionary *)sendTDLibRequest:(NSDictionary *)request waitingForExtra:(NSString *)extra timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    if (![self beginActiveRequestWithError:error]) {
        return nil;
    }

    @try {
        if (![self ensureClientWithError:error]) {
            return nil;
        }

        if (timeout < 0.5) {
            timeout = 0.5;
        } else if (timeout > 15.0) {
            timeout = 15.0;
        }

        [self beginWaitingForExtra:extra];

        NSString *requestJSON = [self JSONStringFromObject:request error:error];
        if (!requestJSON) {
            [_responseCondition lock];
            [_waitingResponseExtras removeObject:extra];
            [_responseCondition unlock];
            return nil;
        }

        [_sendLock lock];
        if (_client && _sendFunction && ![self isShutdownStarted]) {
            _sendFunction(_client, [requestJSON UTF8String]);
        }
        [_sendLock unlock];

        NSDictionary *response = [self waitForResponseWithExtra:extra timeout:timeout errorCode:errorCode error:error];
        if (!response) {
            return nil;
        }

        id type = [response objectForKey:@"@type"];
        if ([type isKindOfClass:[NSString class]] && [(NSString *)type isEqualToString:@"error"]) {
            if (error) {
                *error = [self errorWithTDLibErrorResponse:response code:errorCode];
            }
            return nil;
        }

        return response;
    }
    @finally {
        [self endActiveRequest];
    }
}

- (NSArray *)candidateLibraryPaths {
    NSMutableArray *paths = [NSMutableArray array];
    NSString *environmentPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"TELEGRAPHICA_TDJSON_PATH"];
    if ([environmentPath length] > 0) {
        [paths addObject:environmentPath];
    }

    NSString *frameworksPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Frameworks/libtdjson.dylib"];
    [paths addObject:frameworksPath];
    [paths addObject:@"/usr/local/lib/libtdjson.dylib"];
    [paths addObject:@"/opt/homebrew/lib/libtdjson.dylib"];
    [paths addObject:@"libtdjson.dylib"];
    return paths;
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"Unknown TDLib error")
                                                     forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:TGTDLibErrorDomain code:code userInfo:info];
}

- (NSError *)errorWithTDLibErrorResponse:(NSDictionary *)response code:(NSInteger)code {
    NSString *summary = [self summaryForAuthorizationStateObject:response];
    NSString *message = [NSString stringWithFormat:@"TDLib request failed: %@", summary ? summary : @"error"];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];

    id tdlibCode = [response objectForKey:@"code"];
    if ([tdlibCode respondsToSelector:@selector(integerValue)]) {
        [info setObject:[NSNumber numberWithInteger:[tdlibCode integerValue]] forKey:TGTDLibTDLibCodeErrorKey];
    }

    id tdlibMessage = [response objectForKey:@"message"];
    if ([tdlibMessage isKindOfClass:[NSString class]]) {
        [info setObject:tdlibMessage forKey:TGTDLibTDLibMessageErrorKey];
    }

    [info setObject:response forKey:TGTDLibTDLibResponseErrorKey];
    return [NSError errorWithDomain:TGTDLibErrorDomain code:code userInfo:info];
}

- (NSInteger)tdlibErrorCodeFromError:(NSError *)error {
    id value = [[error userInfo] objectForKey:TGTDLibTDLibCodeErrorKey];
    if ([value respondsToSelector:@selector(integerValue)]) {
        return [value integerValue];
    }
    return 0;
}

- (BOOL)isTDLibLoadChatsExhaustedError:(NSError *)error {
    return [self tdlibErrorCodeFromError:error] == 404;
}

- (NSString *)authorizationErrorDescriptionForSummary:(NSString *)summary actionName:(NSString *)actionName {
    NSString *message = [NSString stringWithFormat:@"TDLib rejected %@: %@", actionName, summary];
    if ([summary rangeOfString:@"UPDATE_APP_TO_LOGIN"].location != NSNotFound) {
        message = [message stringByAppendingString:@". Telegram requires a newer client for login; try rebuilding with a newer TDLib/API layer."];
    }
    return message;
}

- (NSString *)applicationSupportPathWithError:(NSError **)error {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *path = [basePath stringByAppendingPathComponent:@"Telegraphica"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }
    return path;
}

- (NSString *)cachePathWithError:(NSError **)error {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"];
    NSString *path = [basePath stringByAppendingPathComponent:@"Telegraphica"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        return nil;
    }
    return path;
}

- (NSString *)localTDLibConfigurationPathWithError:(NSError **)error {
    NSString *supportPath = [self applicationSupportPathWithError:error];
    if (!supportPath) {
        return nil;
    }
    return [supportPath stringByAppendingPathComponent:@"tdlib-config.plist"];
}

- (NSDictionary *)localTDLibConfigurationWithError:(NSError **)error {
    NSString *configPath = [self localTDLibConfigurationPathWithError:error];
    if (!configPath) {
        return nil;
    }

    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (![configuration isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Local TDLib config was not found or is not a plist dictionary: %@", configPath];
            *error = [self errorWithDescription:message code:12];
        }
        return nil;
    }

    return configuration;
}

- (NSString *)stringValueForKey:(NSString *)key inConfiguration:(NSDictionary *)configuration required:(BOOL)required error:(NSError **)error {
    id value = [configuration objectForKey:key];
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return value;
    }

    if (required && error) {
        NSString *message = [NSString stringWithFormat:@"Local TDLib config is missing required key '%@'.", key];
        *error = [self errorWithDescription:message code:13];
    }
    return nil;
}

- (NSNumber *)apiIDFromConfiguration:(NSDictionary *)configuration error:(NSError **)error {
    id value = [configuration objectForKey:@"api_id"];
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        NSInteger integerValue = [(NSString *)value integerValue];
        if (integerValue > 0) {
            return [NSNumber numberWithInteger:integerValue];
        }
    }

    if (error) {
        *error = [self errorWithDescription:@"Local TDLib config is missing numeric required key 'api_id'." code:14];
    }
    return nil;
}

- (NSNumber *)boolValueForKey:(NSString *)key inConfiguration:(NSDictionary *)configuration defaultValue:(BOOL)defaultValue {
    id value = [configuration objectForKey:key];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [NSNumber numberWithBool:[value boolValue]];
    }
    return [NSNumber numberWithBool:defaultValue];
}

- (NSString *)defaultSystemLanguageCode {
    NSArray *languages = [NSLocale preferredLanguages];
    if ([languages count] > 0 && [[languages objectAtIndex:0] length] > 0) {
        return [languages objectAtIndex:0];
    }
    return @"en";
}

- (NSString *)applicationVersionString {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if ([version length] == 0) {
        return @"0.1.0";
    }
    return version;
}

- (NSString *)tdlibParametersSchemaFromConfiguration:(NSDictionary *)configuration {
    NSString *schema = [self stringValueForKey:@"tdlib_parameters_schema" inConfiguration:configuration required:NO error:NULL];
    if ([schema length] == 0) {
        return @"legacy";
    }

    NSString *lowercaseSchema = [schema lowercaseString];
    if ([lowercaseSchema isEqualToString:@"flat"]) {
        return @"current";
    }
    if ([lowercaseSchema isEqualToString:@"nested"]) {
        return @"legacy";
    }
    if ([lowercaseSchema isEqualToString:@"current"] || [lowercaseSchema isEqualToString:@"legacy"] || [lowercaseSchema isEqualToString:@"auto"]) {
        return lowercaseSchema;
    }
    return @"auto";
}

- (BOOL)ensureDirectoryAtPath:(NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error];
}

- (NSDictionary *)localTDLibParametersWithError:(NSError **)error {
    NSDictionary *configuration = [self localTDLibConfigurationWithError:error];
    if (!configuration) {
        return nil;
    }

    NSNumber *apiID = [self apiIDFromConfiguration:configuration error:error];
    NSString *apiHash = [self stringValueForKey:@"api_hash" inConfiguration:configuration required:YES error:error];
    if (!apiID || [apiHash length] == 0) {
        return nil;
    }

    NSString *supportPath = [self applicationSupportPathWithError:error];
    NSString *cachePath = [self cachePathWithError:error];
    if (!supportPath || !cachePath) {
        return nil;
    }

    NSString *databasePath = [supportPath stringByAppendingPathComponent:@"tdlib"];
    NSString *filesPath = [cachePath stringByAppendingPathComponent:@"tdlib-files"];
    if (![self ensureDirectoryAtPath:databasePath error:error] || ![self ensureDirectoryAtPath:filesPath error:error]) {
        return nil;
    }

    NSString *systemLanguageCode = [self stringValueForKey:@"system_language_code" inConfiguration:configuration required:NO error:NULL];
    if ([systemLanguageCode length] == 0) {
        systemLanguageCode = [self defaultSystemLanguageCode];
    }

    NSString *deviceModel = [self stringValueForKey:@"device_model" inConfiguration:configuration required:NO error:NULL];
    if ([deviceModel length] == 0) {
        deviceModel = @"Mac";
    }

    NSString *systemVersion = [self stringValueForKey:@"system_version" inConfiguration:configuration required:NO error:NULL];
    if ([systemVersion length] == 0) {
        systemVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
    }

    NSString *applicationVersion = [self stringValueForKey:@"application_version" inConfiguration:configuration required:NO error:NULL];
    if ([applicationVersion length] == 0) {
        applicationVersion = [self applicationVersionString];
    }

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setObject:[self boolValueForKey:@"use_test_dc" inConfiguration:configuration defaultValue:NO] forKey:@"use_test_dc"];
    [parameters setObject:databasePath forKey:@"database_directory"];
    [parameters setObject:filesPath forKey:@"files_directory"];
    [parameters setObject:[self boolValueForKey:@"use_file_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_file_database"];
    [parameters setObject:[self boolValueForKey:@"use_chat_info_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_chat_info_database"];
    [parameters setObject:[self boolValueForKey:@"use_message_database" inConfiguration:configuration defaultValue:YES] forKey:@"use_message_database"];
    [parameters setObject:[self boolValueForKey:@"use_secret_chats" inConfiguration:configuration defaultValue:NO] forKey:@"use_secret_chats"];
    [parameters setObject:apiID forKey:@"api_id"];
    [parameters setObject:apiHash forKey:@"api_hash"];
    [parameters setObject:systemLanguageCode forKey:@"system_language_code"];
    [parameters setObject:deviceModel forKey:@"device_model"];
    [parameters setObject:systemVersion forKey:@"system_version"];
    [parameters setObject:applicationVersion forKey:@"application_version"];
    [parameters setObject:[self boolValueForKey:@"enable_storage_optimizer" inConfiguration:configuration defaultValue:YES] forKey:@"enable_storage_optimizer"];
    [parameters setObject:[self boolValueForKey:@"ignore_file_names" inConfiguration:configuration defaultValue:NO] forKey:@"ignore_file_names"];
    return parameters;
}

- (NSString *)JSONStringFromObject:(id)object error:(NSError **)error {
    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&jsonError];
    if (!data) {
        if (error) {
            *error = [self errorWithDescription:@"Could not serialize TDLib JSON request." code:15];
        }
        return nil;
    }
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}

- (NSData *)databaseEncryptionKeyDataWithError:(NSError **)error {
    TGKeychainHelper *keychain = [TGKeychainHelper sharedHelper];
    NSData *existingKey = [keychain readDataForAccount:TGTDLibDatabaseEncryptionKeyAccount];
    if ([existingKey length] > 0) {
        return existingKey;
    }

    NSMutableData *keyData = [NSMutableData dataWithLength:32];
    OSStatus randomStatus = SecRandomCopyBytes(kSecRandomDefault, [keyData length], [keyData mutableBytes]);
    if (randomStatus != errSecSuccess) {
        if (error) {
            *error = [self errorWithDescription:@"Could not generate TDLib database encryption key." code:18];
        }
        return nil;
    }

    if (![keychain saveData:keyData forAccount:TGTDLibDatabaseEncryptionKeyAccount]) {
        if (error) {
            *error = [self errorWithDescription:@"Could not store TDLib database encryption key in Keychain." code:19];
        }
        return nil;
    }

    return keyData;
}

- (NSString *)databaseEncryptionKeyStringWithError:(NSError **)error {
    NSData *encryptionKeyData = [self databaseEncryptionKeyDataWithError:error];
    if ([encryptionKeyData length] == 0) {
        return nil;
    }

    NSString *encryptionKey = [encryptionKeyData base64EncodedStringWithOptions:0];
    if ([encryptionKey length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Could not encode TDLib database encryption key." code:20];
        }
        return nil;
    }
    return encryptionKey;
}

- (BOOL)loadLibraryWithError:(NSError **)error {
    if (_libraryHandle && _createFunction && _sendFunction && _receiveFunction && _executeFunction) {
        return YES;
    }

    NSArray *paths = [self candidateLibraryPaths];
    NSString *lastDLError = nil;
    NSUInteger index = 0;
    for (index = 0; index < [paths count]; index++) {
        NSString *path = [paths objectAtIndex:index];
        const char *fileSystemPath = [path fileSystemRepresentation];
        void *handle = dlopen(fileSystemPath, RTLD_NOW | RTLD_LOCAL);
        if (!handle) {
            const char *dlError = dlerror();
            if (dlError) {
                lastDLError = [NSString stringWithUTF8String:dlError];
            }
            continue;
        }

        _libraryHandle = handle;
        self.loadedPath = path;
        break;
    }

    if (!_libraryHandle) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Could not load libtdjson.dylib. Last loader error: %@",
                                 lastDLError ? lastDLError : @"not found"];
            *error = [self errorWithDescription:message code:1];
        }
        return NO;
    }

    _createFunction = (TGTDJsonClientCreateFunction)dlsym(_libraryHandle, "td_json_client_create");
    _sendFunction = (TGTDJsonClientSendFunction)dlsym(_libraryHandle, "td_json_client_send");
    _receiveFunction = (TGTDJsonClientReceiveFunction)dlsym(_libraryHandle, "td_json_client_receive");
    _executeFunction = (TGTDJsonClientExecuteFunction)dlsym(_libraryHandle, "td_json_client_execute");
    _destroyFunction = (TGTDJsonClientDestroyFunction)dlsym(_libraryHandle, "td_json_client_destroy");

    if (!_createFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_create was not exported." code:2];
        }
        return NO;
    }

    if (!_executeFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_execute was not exported." code:3];
        }
        return NO;
    }

    if (!_sendFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_send was not exported." code:4];
        }
        return NO;
    }

    if (!_receiveFunction) {
        if (error) {
            *error = [self errorWithDescription:@"Loaded TDLib, but td_json_client_receive was not exported." code:5];
        }
        return NO;
    }

    return YES;
}

- (BOOL)ensureClientWithError:(NSError **)error {
    if ([self isShutdownStarted]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib client is shutting down." code:50];
        }
        return NO;
    }

    if (![self loadLibraryWithError:error]) {
        return NO;
    }

    if (!_client) {
        _client = _createFunction();
    }

    if (!_client) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not create a JSON client." code:6];
        }
        return NO;
    }

    if (![self startReceiverThreadIfNeededWithError:error]) {
        return NO;
    }

    return YES;
}

- (id)JSONObjectFromJSONString:(NSString *)jsonString error:(NSError **)error {
    NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!object) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib returned unparseable JSON: %@", jsonString];
            *error = [self errorWithDescription:message code:7];
        }
        return nil;
    }
    return object;
}

- (NSString *)summaryForAuthorizationStateObject:(id)object {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *dictionary = (NSDictionary *)object;
    id type = [dictionary objectForKey:@"@type"];
    if ([type isKindOfClass:[NSString class]]) {
        if ([type isEqualToString:@"updateAuthorizationState"]) {
            id state = [dictionary objectForKey:@"authorization_state"];
            return [self summaryForAuthorizationStateObject:state];
        }
        if ([type hasPrefix:@"authorizationState"]) {
            NSString *prefix = @"authorizationState";
            if ([type length] > [prefix length]) {
                NSString *shortName = [type substringFromIndex:[prefix length]];
                NSString *first = [[shortName substringToIndex:1] lowercaseString];
                NSString *rest = [shortName substringFromIndex:1];
                return [first stringByAppendingString:rest];
            }
            return type;
        }
        if ([type isEqualToString:@"error"]) {
            id message = [dictionary objectForKey:@"message"];
            if ([message isKindOfClass:[NSString class]]) {
                return [NSString stringWithFormat:@"error: %@", message];
            }
            return @"error";
        }
    }

    return nil;
}

- (NSString *)tdlibProbeSummaryWithError:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    const char *request = "{\"@type\":\"getTextEntities\",\"text\":\"Telegraphica TDLib smoke https://telegram.org @telegraphica\"}";
    const char *result = _executeFunction(_client, request);
    if (!result) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned no response for synchronous getTextEntities probe." code:8];
        }
        return nil;
    }

    NSString *jsonString = [NSString stringWithUTF8String:result];
    id object = [self JSONObjectFromJSONString:jsonString error:error];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib returned an unparseable response: %@", jsonString];
            *error = [self errorWithDescription:message code:9];
        }
        return nil;
    }

    NSDictionary *dictionary = (NSDictionary *)object;
    id type = [dictionary objectForKey:@"@type"];
    if ([type isKindOfClass:[NSString class]] && [type isEqualToString:@"textEntities"]) {
        id entities = [dictionary objectForKey:@"entities"];
        if ([entities isKindOfClass:[NSArray class]]) {
            return [NSString stringWithFormat:@"sync execute OK (%lu text entities)", (unsigned long)[entities count]];
        }
        return @"sync execute OK";
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib synchronous probe returned unexpected response: %@", jsonString];
        *error = [self errorWithDescription:message code:10];
    }
    return nil;
}

- (NSDictionary *)currentTDLibParametersRequestWithParameters:(NSDictionary *)parameters error:(NSError **)error {
    NSString *encryptionKey = [self databaseEncryptionKeyStringWithError:error];
    if ([encryptionKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [request setObject:@"setTdlibParameters" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-tdlib-parameters-current"] forKey:@"@extra"];
    [request setObject:encryptionKey forKey:@"database_encryption_key"];
    [request removeObjectForKey:@"enable_storage_optimizer"];
    [request removeObjectForKey:@"ignore_file_names"];
    return request;
}

- (NSDictionary *)legacyTDLibParametersRequestWithParameters:(NSDictionary *)parameters {
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setTdlibParameters" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-tdlib-parameters-legacy"] forKey:@"@extra"];
    [request setObject:parameters forKey:@"parameters"];
    return request;
}

- (NSString *)sendTDLibParametersRequest:(NSDictionary *)request schemaName:(NSString *)schemaName timeout:(NSTimeInterval)timeout error:(NSError **)error {
    id extraObject = [request objectForKey:@"@extra"];
    if (![extraObject isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib parameters request is missing an @extra correlation id." code:16];
        }
        return nil;
    }

    NSUInteger generation = [self authorizationStateGeneration];
    NSError *responseError = nil;
    NSDictionary *response = [self sendTDLibRequest:request waitingForExtra:(NSString *)extraObject timeout:timeout errorCode:16 error:&responseError];
    if (!response) {
        if (error) {
            NSString *message = responseError ? [responseError localizedDescription] : [NSString stringWithFormat:@"TDLib did not acknowledge %@ local parameters before the probe timed out.", schemaName];
            *error = [self errorWithDescription:message code:16];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    BOOL receivedOK = ([responseType isKindOfClass:[NSString class]] && [(NSString *)responseType isEqualToString:@"ok"]);
    NSString *summary = [self summaryForAuthorizationStateObject:response];
    if ([summary hasPrefix:@"error"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib rejected %@ local parameters: %@", schemaName, summary];
            *error = [self errorWithDescription:message code:16];
        }
        return nil;
    }
    if ([summary length] > 0 && ![summary isEqualToString:@"waitTdlibParameters"]) {
        return receivedOK ? [NSString stringWithFormat:@"%@ set OK; auth state: %@", schemaName, summary] : [NSString stringWithFormat:@"%@ auth state: %@", schemaName, summary];
    }

    NSString *nextSummary = [self waitForAuthorizationStateDifferentFromState:@"waitTdlibParameters" afterGeneration:generation timeout:timeout];
    if ([nextSummary length] > 0) {
        if ([nextSummary hasPrefix:@"error"]) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib rejected %@ local parameters: %@", schemaName, nextSummary];
                *error = [self errorWithDescription:message code:16];
            }
            return nil;
        }
        return receivedOK ? [NSString stringWithFormat:@"%@ set OK; auth state: %@", schemaName, nextSummary] : [NSString stringWithFormat:@"%@ auth state: %@", schemaName, nextSummary];
    }

    if (receivedOK) {
        return [NSString stringWithFormat:@"%@ set OK; waiting for next auth state", schemaName];
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib did not acknowledge %@ local parameters before the probe timed out.", schemaName];
        *error = [self errorWithDescription:message code:17];
    }
    return nil;
}

- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *extra = [self uniqueExtraWithPrefix:@"telegraphica-auth-state"];
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getAuthorizationState" forKey:@"@type"];
    [request setObject:extra forKey:@"@extra"];

    NSError *requestError = nil;
    NSDictionary *response = [self sendTDLibRequest:request waitingForExtra:extra timeout:timeout errorCode:11 error:&requestError];
    NSString *summary = [self summaryForAuthorizationStateObject:response];
    if ([summary length] > 0) {
        return summary;
    }

    NSString *cachedSummary = [self cachedAuthorizationStateSummary];
    if ([cachedSummary length] > 0) {
        return cachedSummary;
    }

    if (error) {
        *error = requestError ? requestError : [self errorWithDescription:@"TDLib did not return authorization state before the probe timed out." code:11];
    }
    return nil;
}

- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitTdlibParameters"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSDictionary *parameters = [self localTDLibParametersWithError:error];
    if (!parameters) {
        return nil;
    }

    NSDictionary *configuration = [self localTDLibConfigurationWithError:NULL];
    NSString *schema = [self tdlibParametersSchemaFromConfiguration:configuration];

    if ([schema isEqualToString:@"legacy"]) {
        NSDictionary *legacyRequest = [self legacyTDLibParametersRequestWithParameters:parameters];
        return [self sendTDLibParametersRequest:legacyRequest schemaName:@"legacy" timeout:timeout error:error];
    }

    NSError *currentError = nil;
    NSError *currentRequestError = nil;
    NSDictionary *currentRequest = [self currentTDLibParametersRequestWithParameters:parameters error:&currentRequestError];
    if (!currentRequest) {
        if (error) {
            *error = currentRequestError;
        }
        return nil;
    }

    NSString *currentResult = [self sendTDLibParametersRequest:currentRequest schemaName:@"current" timeout:timeout error:&currentError];
    if ([currentResult length] > 0) {
        return currentResult;
    }

    if ([schema isEqualToString:@"current"]) {
        if (error) {
            *error = currentError;
        }
        return nil;
    }

    NSString *stateAfterCurrentError = [self authorizationStateSummaryWithTimeout:1.0 error:NULL];
    if ([stateAfterCurrentError length] == 0 || [stateAfterCurrentError hasPrefix:@"error"]) {
        stateAfterCurrentError = [self cachedAuthorizationStateSummary];
    }
    if (![stateAfterCurrentError isEqualToString:@"waitTdlibParameters"]) {
        if (error) {
            *error = currentError;
        }
        return nil;
    }

    NSError *legacyError = nil;
    NSDictionary *legacyRequest = [self legacyTDLibParametersRequestWithParameters:parameters];
    NSString *legacyResult = [self sendTDLibParametersRequest:legacyRequest schemaName:@"legacy" timeout:timeout error:&legacyError];
    if ([legacyResult length] > 0) {
        return legacyResult;
    }

    if (error) {
        NSString *currentMessage = currentError ? [currentError localizedDescription] : @"current schema failed";
        NSString *legacyMessage = legacyError ? [legacyError localizedDescription] : @"legacy schema failed";
        NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
        *error = [self errorWithDescription:message code:16];
    }
    return nil;
}

- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    NSString *authorizationState = nil;
    NSDate *stateDeadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while ([[NSDate date] compare:stateDeadline] == NSOrderedAscending) {
        NSTimeInterval remaining = [stateDeadline timeIntervalSinceNow];
        NSTimeInterval stateTimeout = remaining < 1.0 ? remaining : 1.0;
        NSError *stateError = nil;
        authorizationState = [self authorizationStateSummaryWithTimeout:stateTimeout error:&stateError];
        if ([authorizationState isEqualToString:@"waitEncryptionKey"]) {
            break;
        }
        if ([authorizationState length] > 0 && ![authorizationState isEqualToString:@"waitTdlibParameters"]) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
    }

    if (![authorizationState isEqualToString:@"waitEncryptionKey"]) {
        if ([authorizationState length] > 0) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib did not reach waitEncryptionKey before the probe timed out. Last auth state: %@", authorizationState];
                *error = [self errorWithDescription:message code:23];
            }
            return nil;
        }
        if (error) {
            *error = [self errorWithDescription:@"TDLib did not reach waitEncryptionKey before the probe timed out." code:23];
        }
        return nil;
    }

    NSString *encryptionKey = [self databaseEncryptionKeyStringWithError:error];
    if ([encryptionKey length] == 0) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkDatabaseEncryptionKey" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-db-key"] forKey:@"@extra"];
    [request setObject:encryptionKey forKey:@"encryption_key"];

    NSString *extra = [request objectForKey:@"@extra"];
    NSUInteger generation = [self authorizationStateGeneration];
    NSError *responseError = nil;
    NSDictionary *response = [self sendTDLibRequest:request waitingForExtra:extra timeout:timeout errorCode:21 error:&responseError];
    if (!response) {
        if (error) {
            *error = responseError ? responseError : [self errorWithDescription:@"TDLib did not acknowledge database encryption key before the probe timed out." code:22];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    BOOL receivedOK = ([responseType isKindOfClass:[NSString class]] && [(NSString *)responseType isEqualToString:@"ok"]);
    NSString *summary = [self summaryForAuthorizationStateObject:response];
    if ([summary hasPrefix:@"error"]) {
        if (error) {
            *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib rejected database encryption key: %@", summary] code:21];
        }
        return nil;
    }
    if ([summary length] > 0 && ![summary isEqualToString:@"waitEncryptionKey"]) {
        return receivedOK ? [NSString stringWithFormat:@"check OK; auth state: %@", summary] : [NSString stringWithFormat:@"auth state: %@", summary];
    }

    NSString *nextSummary = [self waitForAuthorizationStateDifferentFromState:@"waitEncryptionKey" afterGeneration:generation timeout:timeout];
    if ([nextSummary length] > 0) {
        if ([nextSummary hasPrefix:@"error"]) {
            if (error) {
                *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib rejected database encryption key: %@", nextSummary] code:21];
            }
            return nil;
        }
        return receivedOK ? [NSString stringWithFormat:@"check OK; auth state: %@", nextSummary] : [NSString stringWithFormat:@"auth state: %@", nextSummary];
    }

    if (receivedOK) {
        return @"check OK; waiting for next auth state";
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib did not acknowledge database encryption key before the probe timed out." code:22];
    }
    return nil;
}

- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    if ([authorizationState isEqualToString:@"closed"]) {
        [self destroyTDLibClient];
        authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    }

    if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
        if (![self setLocalTDLibParametersWithTimeout:timeout error:error]) {
            return nil;
        }
        authorizationState = [self authorizationStateSummaryWithTimeout:1.0 error:NULL];
        if ([authorizationState length] == 0) {
            authorizationState = @"waitTdlibParameters";
        }
    }

    if ([authorizationState isEqualToString:@"waitTdlibParameters"] || [authorizationState isEqualToString:@"waitEncryptionKey"]) {
        if (![self checkDatabaseEncryptionKeyWithTimeout:timeout error:error]) {
            return nil;
        }
        authorizationState = [self authorizationStateSummaryWithTimeout:timeout error:error];
    }

    return authorizationState;
}

- (NSString *)receiveAuthorizationResultForAction:(NSString *)actionName waitingState:(NSString *)waitingState afterGeneration:(NSUInteger)generation timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    NSString *summary = [self waitForAuthorizationStateDifferentFromState:waitingState afterGeneration:generation timeout:timeout];
    if ([summary length] > 0) {
        if ([summary hasPrefix:@"error"]) {
            if (error) {
                NSString *message = [self authorizationErrorDescriptionForSummary:summary actionName:actionName];
                *error = [self errorWithDescription:message code:errorCode];
            }
            return nil;
        }
        return [NSString stringWithFormat:@"%@ accepted; auth state: %@", actionName, summary];
    }

    if (error) {
        NSString *message = [NSString stringWithFormat:@"TDLib did not acknowledge %@ before the probe timed out.", actionName];
        *error = [self errorWithDescription:message code:errorCode];
    }
    return nil;
}

- (NSString *)sendAuthorizationRequest:(NSDictionary *)request actionName:(NSString *)actionName waitingState:(NSString *)waitingState timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    id extraObject = [request objectForKey:@"@extra"];
    if (![extraObject isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib authorization request is missing an @extra correlation id." code:errorCode];
        }
        return nil;
    }

    NSUInteger generation = [self authorizationStateGeneration];
    NSError *responseError = nil;
    NSDictionary *response = [self sendTDLibRequest:request waitingForExtra:(NSString *)extraObject timeout:timeout errorCode:errorCode error:&responseError];
    if (!response) {
        if (error) {
            NSString *summary = responseError ? [responseError localizedDescription] : @"TDLib returned no authorization response.";
            NSString *message = [self authorizationErrorDescriptionForSummary:summary actionName:actionName];
            *error = [self errorWithDescription:message code:errorCode];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if ([responseType isKindOfClass:[NSString class]] && [(NSString *)responseType isEqualToString:@"ok"]) {
        NSString *summary = [self waitForAuthorizationStateDifferentFromState:waitingState afterGeneration:generation timeout:timeout];
        if ([summary length] > 0) {
            if ([summary hasPrefix:@"error"]) {
                if (error) {
                    NSString *message = [self authorizationErrorDescriptionForSummary:summary actionName:actionName];
                    *error = [self errorWithDescription:message code:errorCode];
                }
                return nil;
            }
            return [NSString stringWithFormat:@"%@ accepted; auth state: %@", actionName, summary];
        }
        return [NSString stringWithFormat:@"%@ accepted; waiting for next auth state", actionName];
    }

    return [self receiveAuthorizationResultForAction:actionName waitingState:waitingState afterGeneration:generation timeout:timeout errorCode:errorCode error:error];
}

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)extraPrefix timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error {
    if (![self ensureClientWithError:error]) {
        return nil;
    }

    if (timeout < 0.5) {
        timeout = 0.5;
    } else if (timeout > 15.0) {
        timeout = 15.0;
    }

    NSMutableDictionary *taggedRequest = [NSMutableDictionary dictionaryWithDictionary:request];
    NSString *extra = [self uniqueExtraWithPrefix:(extraPrefix ? extraPrefix : @"telegraphica-request")];
    [taggedRequest setObject:extra forKey:@"@extra"];

    NSDictionary *response = [self sendTDLibRequest:taggedRequest waitingForExtra:extra timeout:timeout errorCode:errorCode error:error];
    if (!response) {
        return nil;
    }

    NSString *summary = [self summaryForAuthorizationStateObject:response];
    if ([summary isEqualToString:@"closed"]) {
        [self destroyTDLibClient];
        if (error) {
            *error = [self errorWithDescription:@"TDLib authorization state closed while waiting for a response." code:errorCode];
        }
        return nil;
    }

    return response;
}

- (NSString *)prepareAuthorizationFlowWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if ([authorizationState length] == 0) {
        return nil;
    }
    return [NSString stringWithFormat:@"auth state: %@", authorizationState];
}

- (NSArray *)mainChatIDsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = TGTDLibMainChatLoadBatchSize;
    } else if (safeLimit > TGTDLibMaxMainChatPreviewLimit) {
        safeLimit = TGTDLibMaxMainChatPreviewLimit;
    }

    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    [chatList setObject:@"chatListMain" forKey:@"@type"];

    NSTimeInterval loadChatsTimeout = timeout;
    if (loadChatsTimeout > 1.0) {
        loadChatsTimeout = 1.0;
    }

    NSMutableDictionary *getChatsRequest = [NSMutableDictionary dictionary];
    [getChatsRequest setObject:@"getChats" forKey:@"@type"];
    [getChatsRequest setObject:chatList forKey:@"chat_list"];
    [getChatsRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *currentChatsError = nil;
    NSDictionary *chatsResponse = nil;
    NSUInteger lastChatIDCount = 0;
    NSUInteger attempt = 0;
    NSUInteger stagnantAttemptCount = 0;
    BOOL reachedEndOfMainChatList = [self mainChatListExhausted];
    for (attempt = 0; attempt < TGTDLibMainChatLoadAttemptLimit; attempt++) {
        currentChatsError = nil;
        chatsResponse = [self sendTDLibRequestAndWaitForExtra:getChatsRequest
                                                  extraPrefix:@"telegraphica-main-chats"
                                                      timeout:timeout
                                                    errorCode:33
                                                        error:&currentChatsError];
        if (!chatsResponse) {
            break;
        }

        id currentChatIDs = [chatsResponse objectForKey:@"chat_ids"];
        NSUInteger currentChatIDCount = [currentChatIDs isKindOfClass:[NSArray class]] ? [(NSArray *)currentChatIDs count] : 0;
        if (currentChatIDCount >= safeLimit || reachedEndOfMainChatList) {
            break;
        }
        if (attempt > 0 && currentChatIDCount == lastChatIDCount) {
            stagnantAttemptCount++;
            if (stagnantAttemptCount >= 2) {
                break;
            }
        } else {
            stagnantAttemptCount = 0;
        }

        NSUInteger requestedBatchSize = safeLimit - currentChatIDCount;
        if (requestedBatchSize > TGTDLibMainChatLoadBatchSize) {
            requestedBatchSize = TGTDLibMainChatLoadBatchSize;
        }
        if (requestedBatchSize == 0) {
            requestedBatchSize = TGTDLibMainChatLoadBatchSize;
        }

        NSMutableDictionary *loadChatsRequest = [NSMutableDictionary dictionary];
        [loadChatsRequest setObject:@"loadChats" forKey:@"@type"];
        [loadChatsRequest setObject:chatList forKey:@"chat_list"];
        [loadChatsRequest setObject:[NSNumber numberWithInt:(int)requestedBatchSize] forKey:@"limit"];

        NSError *loadChatsError = nil;
        NSDictionary *loadResponse = [self sendTDLibRequestAndWaitForExtra:loadChatsRequest
                                                                extraPrefix:@"telegraphica-load-main-chats"
                                                                    timeout:loadChatsTimeout
                                                                  errorCode:32
                                                                      error:&loadChatsError];
        if (!loadResponse) {
            if ([self isTDLibLoadChatsExhaustedError:loadChatsError]) {
                reachedEndOfMainChatList = YES;
                [self setMainChatListExhausted:YES];
            }
            break;
        }
        lastChatIDCount = currentChatIDCount;
    }

    if (!chatsResponse) {
        NSError *legacyChatsError = nil;
        NSMutableDictionary *legacyGetChatsRequest = [NSMutableDictionary dictionary];
        [legacyGetChatsRequest setObject:@"getChats" forKey:@"@type"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_order"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_chat_id"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

        chatsResponse = [self sendTDLibRequestAndWaitForExtra:legacyGetChatsRequest
                                                  extraPrefix:@"telegraphica-main-chats-legacy"
                                                      timeout:timeout
                                                    errorCode:33
                                                        error:&legacyChatsError];
        if (!chatsResponse && error) {
            NSString *currentMessage = currentChatsError ? [currentChatsError localizedDescription] : @"current getChats schema failed";
            NSString *legacyMessage = legacyChatsError ? [legacyChatsError localizedDescription] : @"legacy getChats schema failed";
            NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
            *error = [self errorWithDescription:message code:33];
        }
    }

    if (!chatsResponse) {
        return nil;
    }

    id chatsType = [chatsResponse objectForKey:@"@type"];
    id chatIDs = [chatsResponse objectForKey:@"chat_ids"];
    if (![chatsType isKindOfClass:[NSString class]] || ![(NSString *)chatsType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChats returned an unexpected response." code:34];
        }
        return nil;
    }

    return chatIDs;
}

- (NSString *)chatTypeSummaryForChatTypeObject:(id)chatTypeObject {
    if (![chatTypeObject isKindOfClass:[NSDictionary class]]) {
        return @"Chat";
    }

    NSDictionary *chatTypeDictionary = (NSDictionary *)chatTypeObject;
    id type = [chatTypeDictionary objectForKey:@"@type"];
    if (![type isKindOfClass:[NSString class]]) {
        return @"Chat";
    }

    if ([(NSString *)type isEqualToString:@"chatTypePrivate"]) {
        return @"Private";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeBasicGroup"]) {
        return @"Group";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeSupergroup"]) {
        id isChannel = [chatTypeDictionary objectForKey:@"is_channel"];
        if ([isChannel respondsToSelector:@selector(boolValue)] && [isChannel boolValue]) {
            return @"Channel";
        }
        return @"Supergroup";
    }
    if ([(NSString *)type isEqualToString:@"chatTypeSecret"]) {
        return @"Secret";
    }

    return @"Chat";
}

- (NSArray *)mainChatPreviewItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load chats. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:35];
        }
        return nil;
    }

    NSArray *chatIDs = [self mainChatIDsWithLimit:limit timeout:timeout error:error];
    if (!chatIDs) {
        return nil;
    }

    NSUInteger returnedChatIDCount = [chatIDs count];
    NSMutableArray *items = [NSMutableArray array];
    NSTimeInterval chatTimeout = timeout;
    if (chatTimeout > 1.0) {
        chatTimeout = 1.0;
    }

    NSUInteger index = 0;
    NSUInteger avatarDownloadsRemaining = 12;
    for (index = 0; index < [chatIDs count]; index++) {
        id chatID = [chatIDs objectAtIndex:index];
        if (!chatID) {
            continue;
        }

        NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
        [getChatRequest setObject:@"getChat" forKey:@"@type"];
        [getChatRequest setObject:chatID forKey:@"chat_id"];

        NSError *chatError = nil;
        NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                               extraPrefix:@"telegraphica-get-chat"
                                                                   timeout:chatTimeout
                                                                 errorCode:36
                                                                     error:&chatError];
        if (!chatResponse) {
            continue;
        }

        id responseType = [chatResponse objectForKey:@"@type"];
        if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chat"]) {
            continue;
        }

        id titleValue = [chatResponse objectForKey:@"title"];
        NSString *title = ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) ? (NSString *)titleValue : @"Untitled";
        NSString *typeSummary = [self chatTypeSummaryForChatTypeObject:[chatResponse objectForKey:@"type"]];
        id unreadValue = [chatResponse objectForKey:@"unread_count"];
        NSNumber *unreadCount = nil;
        if ([unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadCount = [NSNumber numberWithInteger:[unreadValue integerValue]];
        } else {
            unreadCount = [NSNumber numberWithInteger:0];
        }

        TGChatItem *item = [[[TGChatItem alloc] initWithChatID:chatID
                                                         title:title
                                                   typeSummary:typeSummary
                                                   unreadCount:unreadCount] autorelease];
        BOOL didRequestAvatarDownload = NO;
        NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[chatResponse objectForKey:@"photo"]
                                                      downloadMissing:(avatarDownloadsRemaining > 0)
                                                              timeout:0.9
                                                   didRequestDownload:&didRequestAvatarDownload];
        if (didRequestAvatarDownload && avatarDownloadsRemaining > 0) {
            avatarDownloadsRemaining--;
        }
        NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
        if ([avatarPath length] > 0) {
            [item setAvatarLocalPath:avatarPath];
        }
        [items addObject:item];
    }

    if (returnedChatIDCount > 0 && [items count] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned chat IDs, but no chat previews could be loaded." code:37];
        }
        return nil;
    }

    return items;
}

- (NSArray *)chatFilterChatIDsForFilterID:(NSNumber *)filterID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout exhausted:(BOOL *)exhausted error:(NSError **)error {
    if (exhausted) {
        *exhausted = NO;
    }
    if (![filterID respondsToSelector:@selector(integerValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat filter identifier is missing." code:70];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = TGTDLibMainChatLoadBatchSize;
    } else if (safeLimit > TGTDLibMaxMainChatPreviewLimit) {
        safeLimit = TGTDLibMaxMainChatPreviewLimit;
    }

    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    [chatList setObject:@"chatListFilter" forKey:@"@type"];
    [chatList setObject:[NSNumber numberWithInteger:[filterID integerValue]] forKey:@"chat_filter_id"];

    NSTimeInterval loadChatsTimeout = timeout;
    if (loadChatsTimeout > 1.0) {
        loadChatsTimeout = 1.0;
    }

    NSMutableDictionary *getChatsRequest = [NSMutableDictionary dictionary];
    [getChatsRequest setObject:@"getChats" forKey:@"@type"];
    [getChatsRequest setObject:chatList forKey:@"chat_list"];
    [getChatsRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *currentChatsError = nil;
    NSDictionary *chatsResponse = nil;
    NSUInteger lastChatIDCount = 0;
    NSUInteger attempt = 0;
    NSUInteger stagnantAttemptCount = 0;
    BOOL reachedEndOfChatList = NO;
    for (attempt = 0; attempt < TGTDLibMainChatLoadAttemptLimit; attempt++) {
        currentChatsError = nil;
        chatsResponse = [self sendTDLibRequestAndWaitForExtra:getChatsRequest
                                                  extraPrefix:@"telegraphica-filter-chats"
                                                      timeout:timeout
                                                    errorCode:71
                                                        error:&currentChatsError];
        if (!chatsResponse) {
            break;
        }

        id currentChatIDs = [chatsResponse objectForKey:@"chat_ids"];
        NSUInteger currentChatIDCount = [currentChatIDs isKindOfClass:[NSArray class]] ? [(NSArray *)currentChatIDs count] : 0;
        if (currentChatIDCount >= safeLimit || reachedEndOfChatList) {
            break;
        }
        if (attempt > 0 && currentChatIDCount == lastChatIDCount) {
            stagnantAttemptCount++;
            if (stagnantAttemptCount >= 2) {
                break;
            }
        } else {
            stagnantAttemptCount = 0;
        }

        NSUInteger requestedBatchSize = safeLimit - currentChatIDCount;
        if (requestedBatchSize > TGTDLibMainChatLoadBatchSize) {
            requestedBatchSize = TGTDLibMainChatLoadBatchSize;
        }
        if (requestedBatchSize == 0) {
            requestedBatchSize = TGTDLibMainChatLoadBatchSize;
        }

        NSMutableDictionary *loadChatsRequest = [NSMutableDictionary dictionary];
        [loadChatsRequest setObject:@"loadChats" forKey:@"@type"];
        [loadChatsRequest setObject:chatList forKey:@"chat_list"];
        [loadChatsRequest setObject:[NSNumber numberWithInt:(int)requestedBatchSize] forKey:@"limit"];

        NSError *loadChatsError = nil;
        NSDictionary *loadResponse = [self sendTDLibRequestAndWaitForExtra:loadChatsRequest
                                                                extraPrefix:@"telegraphica-load-filter-chats"
                                                                    timeout:loadChatsTimeout
                                                                  errorCode:72
                                                                      error:&loadChatsError];
        if (!loadResponse) {
            if ([self isTDLibLoadChatsExhaustedError:loadChatsError]) {
                reachedEndOfChatList = YES;
                if (exhausted) {
                    *exhausted = YES;
                }
            }
            break;
        }
        lastChatIDCount = currentChatIDCount;
    }

    if (!chatsResponse) {
        if (error) {
            NSString *message = currentChatsError ? [currentChatsError localizedDescription] : @"TDLib filter getChats failed.";
            *error = [self errorWithDescription:message code:71];
        }
        return nil;
    }

    id chatsType = [chatsResponse objectForKey:@"@type"];
    id chatIDs = [chatsResponse objectForKey:@"chat_ids"];
    if (![chatsType isKindOfClass:[NSString class]] || ![(NSString *)chatsType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib filter getChats returned an unexpected response." code:73];
        }
        return nil;
    }

    return chatIDs;
}

- (NSArray *)chatPreviewItemsForChatFilterID:(NSNumber *)filterID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout exhausted:(BOOL *)exhausted error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load folder chats. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:74];
        }
        return nil;
    }

    NSArray *chatIDs = [self chatFilterChatIDsForFilterID:filterID limit:limit timeout:timeout exhausted:exhausted error:error];
    if (!chatIDs) {
        return nil;
    }

    NSUInteger returnedChatIDCount = [chatIDs count];
    NSMutableArray *items = [NSMutableArray array];
    NSTimeInterval chatTimeout = timeout;
    if (chatTimeout > 1.0) {
        chatTimeout = 1.0;
    }

    NSUInteger index = 0;
    NSUInteger avatarDownloadsRemaining = 12;
    for (index = 0; index < [chatIDs count]; index++) {
        id chatID = [chatIDs objectAtIndex:index];
        if (!chatID) {
            continue;
        }

        NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
        [getChatRequest setObject:@"getChat" forKey:@"@type"];
        [getChatRequest setObject:chatID forKey:@"chat_id"];

        NSError *chatError = nil;
        NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                               extraPrefix:@"telegraphica-get-filter-chat"
                                                                   timeout:chatTimeout
                                                                 errorCode:75
                                                                     error:&chatError];
        if (!chatResponse) {
            continue;
        }

        id responseType = [chatResponse objectForKey:@"@type"];
        if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chat"]) {
            continue;
        }

        id titleValue = [chatResponse objectForKey:@"title"];
        NSString *title = ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) ? (NSString *)titleValue : @"Untitled";
        NSString *typeSummary = [self chatTypeSummaryForChatTypeObject:[chatResponse objectForKey:@"type"]];
        id unreadValue = [chatResponse objectForKey:@"unread_count"];
        NSNumber *unreadCount = nil;
        if ([unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadCount = [NSNumber numberWithInteger:[unreadValue integerValue]];
        } else {
            unreadCount = [NSNumber numberWithInteger:0];
        }

        TGChatItem *item = [[[TGChatItem alloc] initWithChatID:chatID
                                                         title:title
                                                   typeSummary:typeSummary
                                                   unreadCount:unreadCount] autorelease];
        BOOL didRequestAvatarDownload = NO;
        NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[chatResponse objectForKey:@"photo"]
                                                      downloadMissing:(avatarDownloadsRemaining > 0)
                                                              timeout:0.9
                                                   didRequestDownload:&didRequestAvatarDownload];
        if (didRequestAvatarDownload && avatarDownloadsRemaining > 0) {
            avatarDownloadsRemaining--;
        }
        NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
        if ([avatarPath length] > 0) {
            [item setAvatarLocalPath:avatarPath];
        }
        [items addObject:item];
    }

    if (returnedChatIDCount > 0 && [items count] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned folder chat IDs, but no chat previews could be loaded." code:76];
        }
        return nil;
    }

    return items;
}

- (NSArray *)forumTopicPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load forum topics. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:82];
        }
        return nil;
    }
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Forum topic request requires a chat id." code:82];
        }
        return nil;
    }

    NSInteger safeLimit = (NSInteger)limit;
    if (safeLimit <= 0) {
        safeLimit = 20;
    } else if (safeLimit > 50) {
        safeLimit = 50;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getForumTopics" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:@"" forKey:@"query"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"offset_date"];
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_message_id"];
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_message_thread_id"];
    [request setObject:[NSNumber numberWithInteger:safeLimit] forKey:@"limit"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-forum-topics"
                                                           timeout:timeout
                                                         errorCode:82
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"forumTopics"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getForumTopics returned an unexpected response." code:82];
        }
        return nil;
    }

    id topicsObject = [response objectForKey:@"topics"];
    if (![topicsObject isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *topics = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)topicsObject count]; index++) {
        id topicObject = [(NSArray *)topicsObject objectAtIndex:index];
        if (![topicObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *topic = (NSDictionary *)topicObject;
        id infoObject = [topic objectForKey:@"info"];
        NSDictionary *info = [infoObject isKindOfClass:[NSDictionary class]] ? (NSDictionary *)infoObject : topic;
        id threadID = [info objectForKey:@"message_thread_id"];
        if (![threadID respondsToSelector:@selector(longLongValue)]) {
            threadID = [topic objectForKey:@"message_thread_id"];
        }
        if (![threadID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }

        id nameValue = [info objectForKey:@"name"];
        if (![nameValue isKindOfClass:[NSString class]] || [(NSString *)nameValue length] == 0) {
            nameValue = [topic objectForKey:@"name"];
        }
        NSString *name = ([nameValue isKindOfClass:[NSString class]] && [(NSString *)nameValue length] > 0) ? (NSString *)nameValue : @"Topic";

        id unreadValue = [info objectForKey:@"unread_count"];
        if (![unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadValue = [info objectForKey:@"unread_message_count"];
        }
        if (![unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadValue = [topic objectForKey:@"unread_count"];
        }
        if (![unreadValue respondsToSelector:@selector(integerValue)]) {
            unreadValue = [topic objectForKey:@"unread_message_count"];
        }
        NSNumber *unreadCount = [unreadValue respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[unreadValue integerValue]] : [NSNumber numberWithInteger:0];

        NSMutableDictionary *topicInfo = [NSMutableDictionary dictionary];
        [topicInfo setObject:name forKey:@"title"];
        [topicInfo setObject:[NSNumber numberWithLongLong:[threadID longLongValue]] forKey:@"message_thread_id"];
        [topicInfo setObject:unreadCount forKey:@"unread_count"];
        [topics addObject:topicInfo];
    }

    return topics;
}

- (NSString *)singleLineTrimmedString:(NSString *)string maximumLength:(NSUInteger)maximumLength {
    if (![string isKindOfClass:[NSString class]]) {
        return @"";
    }

    NSMutableString *mutable = [NSMutableString stringWithString:string];
    [mutable replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [mutable length])];
    NSString *trimmed = [mutable stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (maximumLength > 0 && [trimmed length] > maximumLength) {
        NSString *prefix = [trimmed substringToIndex:maximumLength];
        return [prefix stringByAppendingString:@"..."];
    }
    return trimmed;
}

- (NSString *)textFromFormattedTextObject:(id)object {
    if ([object isKindOfClass:[NSString class]]) {
        return [self singleLineTrimmedString:(NSString *)object maximumLength:300];
    }
    if (![object isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    id text = [(NSDictionary *)object objectForKey:@"text"];
    if (![text isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [self singleLineTrimmedString:(NSString *)text maximumLength:300];
}

- (NSNumber *)fileIDFromFileObject:(id)fileObject {
    if (![fileObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id fileID = [(NSDictionary *)fileObject objectForKey:@"id"];
    if (![fileID respondsToSelector:@selector(integerValue)]) {
        return nil;
    }
    return [NSNumber numberWithInteger:[fileID integerValue]];
}

- (NSString *)completedLocalPathFromFileObject:(id)fileObject {
    if (![fileObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id local = [(NSDictionary *)fileObject objectForKey:@"local"];
    if (![local isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id completed = [(NSDictionary *)local objectForKey:@"is_downloading_completed"];
    id path = [(NSDictionary *)local objectForKey:@"path"];
    if (![completed respondsToSelector:@selector(boolValue)] || ![completed boolValue]) {
        return nil;
    }
    if (![path isKindOfClass:[NSString class]] || [(NSString *)path length] == 0) {
        return nil;
    }
    return (NSString *)path;
}

- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout {
    if (![fileID respondsToSelector:@selector(integerValue)] || [fileID integerValue] <= 0) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"downloadFile" forKey:@"@type"];
    [request setObject:fileID forKey:@"file_id"];
    [request setObject:[NSNumber numberWithInt:16] forKey:@"priority"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"limit"];
    [request setObject:[NSNumber numberWithBool:YES] forKey:@"synchronous"];

    NSError *downloadError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-download-file"
                                                           timeout:timeout
                                                         errorCode:56
                                                             error:&downloadError];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"file"]) {
        return nil;
    }
    NSString *path = [self completedLocalPathFromFileObject:response];
    if ([path length] == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:path, @"local_path", fileID, @"file_id", nil];
}

- (NSDictionary *)photoInfoFromFileObject:(id)fileObject
                                    width:(NSNumber *)width
                                   height:(NSNumber *)height
                          downloadMissing:(BOOL)downloadMissing
                                  timeout:(NSTimeInterval)timeout
                       didRequestDownload:(BOOL *)didRequestDownload {
    NSNumber *fileID = [self fileIDFromFileObject:fileObject];
    NSString *localPath = [self completedLocalPathFromFileObject:fileObject];
    if ([localPath length] == 0 && downloadMissing && fileID) {
        if (didRequestDownload) {
            *didRequestDownload = YES;
        }
        NSDictionary *downloadedInfo = [self downloadedFileInfoForFileID:fileID timeout:timeout];
        localPath = [downloadedInfo objectForKey:@"local_path"];
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (fileID) {
        [info setObject:fileID forKey:@"file_id"];
    }
    if ([localPath length] > 0) {
        [info setObject:localPath forKey:@"local_path"];
    }
    if (width) {
        [info setObject:width forKey:@"width"];
    }
    if (height) {
        [info setObject:height forKey:@"height"];
    }
    return ([info count] > 0) ? info : nil;
}

- (NSDictionary *)photoInfoFromPhotoSizes:(NSArray *)sizes
                          downloadMissing:(BOOL)downloadMissing
                                  timeout:(NSTimeInterval)timeout
                       didRequestDownload:(BOOL *)didRequestDownload {
    if (![sizes isKindOfClass:[NSArray class]] || [sizes count] == 0) {
        return nil;
    }

    NSDictionary *bestDownloadedSize = nil;
    NSDictionary *bestDownloadableSize = nil;
    NSInteger bestDownloadedScore = NSIntegerMax;
    NSInteger bestDownloadableScore = NSIntegerMax;
    NSUInteger index = 0;
    for (index = 0; index < [sizes count]; index++) {
        id sizeObject = [sizes objectAtIndex:index];
        if (![sizeObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *size = (NSDictionary *)sizeObject;
        id widthObject = [size objectForKey:@"width"];
        id heightObject = [size objectForKey:@"height"];
        NSInteger width = [widthObject respondsToSelector:@selector(integerValue)] ? [widthObject integerValue] : 0;
        NSInteger height = [heightObject respondsToSelector:@selector(integerValue)] ? [heightObject integerValue] : 0;
        if (width <= 0 || height <= 0) {
            continue;
        }
        NSInteger longestSide = (width > height) ? width : height;
        NSInteger score = (longestSide > 300) ? (longestSide - 300) : (300 - longestSide);
        id fileObject = [size objectForKey:@"photo"];
        NSString *localPath = [self completedLocalPathFromFileObject:fileObject];
        NSNumber *fileID = [self fileIDFromFileObject:fileObject];
        if ([localPath length] > 0) {
            if (!bestDownloadedSize || score < bestDownloadedScore) {
                bestDownloadedSize = size;
                bestDownloadedScore = score;
            }
        } else if (fileID) {
            if (!bestDownloadableSize || score < bestDownloadableScore) {
                bestDownloadableSize = size;
                bestDownloadableScore = score;
            }
        }
    }

    NSDictionary *selectedSize = bestDownloadedSize ? bestDownloadedSize : bestDownloadableSize;
    if (!selectedSize) {
        return nil;
    }
    id widthObject = [selectedSize objectForKey:@"width"];
    id heightObject = [selectedSize objectForKey:@"height"];
    NSNumber *width = [widthObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[widthObject integerValue]] : nil;
    NSNumber *height = [heightObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[heightObject integerValue]] : nil;
    return [self photoInfoFromFileObject:[selectedSize objectForKey:@"photo"]
                                   width:width
                                  height:height
                         downloadMissing:(downloadMissing && !bestDownloadedSize)
                                 timeout:timeout
                      didRequestDownload:didRequestDownload];
}

- (NSDictionary *)mediaFileObjectFromContainerObject:(NSDictionary *)containerObject {
    if (![containerObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id fileObject = [containerObject objectForKey:@"file"];
    if ([fileObject isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)fileObject;
    }
    id documentFileObject = [containerObject objectForKey:@"document"];
    if ([documentFileObject isKindOfClass:[NSDictionary class]]) {
        return (NSDictionary *)documentFileObject;
    }
    return nil;
}

- (BOOL)isVisualDocumentObject:(NSDictionary *)documentObject {
    if (![documentObject isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id mimeTypeObject = [documentObject objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
    if ([mimeType hasPrefix:@"image/"]) {
        return YES;
    }
    if ([mimeType isEqualToString:@"video/mp4"] || [mimeType hasPrefix:@"video/"]) {
        id fileNameObject = [documentObject objectForKey:@"file_name"];
        if ([fileNameObject isKindOfClass:[NSString class]]) {
            NSString *extension = [(NSString *)fileNameObject pathExtension];
            if ([extension length] > 0) {
                extension = [extension lowercaseString];
                if ([extension isEqualToString:@"gif"] || [extension isEqualToString:@"mp4"] || [extension isEqualToString:@"mov"] || [extension isEqualToString:@"webm"]) {
                    return YES;
                }
                if ([extension isEqualToString:@"png"] || [extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"] || [extension isEqualToString:@"webp"]) {
                    return YES;
                }
            }
        }
        if ([[documentObject objectForKey:@"thumbnail"] isKindOfClass:[NSDictionary class]]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)documentVisualLabelFromObject:(NSDictionary *)documentObject {
    if (![documentObject isKindOfClass:[NSDictionary class]]) {
        return @"[Document]";
    }

    id mimeTypeObject = [documentObject objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
    id fileNameObject = [documentObject objectForKey:@"file_name"];
    NSString *fileName = [fileNameObject isKindOfClass:[NSString class]] ? (NSString *)fileNameObject : nil;
    NSString *extension = [fileName pathExtension];
    if ([extension length] > 0) {
        extension = [extension lowercaseString];
    }

    if ([mimeType isEqualToString:@"image/gif"] || [extension isEqualToString:@"gif"]) {
        return @"[GIF]";
    }
    if ([mimeType hasPrefix:@"video/"]) {
        return @"[Video]";
    }
    if ([mimeType hasPrefix:@"image/"]) {
        return @"[Photo]";
    }
    return @"[Document]";
}

- (NSDictionary *)visualMediaInfoFromDocumentObject:(id)documentObject
                                   downloadMissing:(BOOL)downloadMissing
                                           timeout:(NSTimeInterval)timeout
                                didRequestDownload:(BOOL *)didRequestDownload {
    if (![self isVisualDocumentObject:documentObject]) {
        return nil;
    }
    return [self visualMediaInfoFromContainerObject:documentObject
                                   downloadMissing:downloadMissing
                                           timeout:timeout
                                didRequestDownload:didRequestDownload];
}

- (NSDictionary *)photoInfoFromMessageContentObject:(id)contentObject
                                   downloadMissing:(BOOL)downloadMissing
                                           timeout:(NSTimeInterval)timeout
                                didRequestDownload:(BOOL *)didRequestDownload {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id typeObject = [(NSDictionary *)contentObject objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]] || ![(NSString *)typeObject isEqualToString:@"messagePhoto"]) {
        return nil;
    }
    id photo = [(NSDictionary *)contentObject objectForKey:@"photo"];
    if (![photo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    return [self photoInfoFromPhotoSizes:[(NSDictionary *)photo objectForKey:@"sizes"]
                         downloadMissing:downloadMissing
                                 timeout:timeout
                      didRequestDownload:didRequestDownload];
}

- (NSDictionary *)visualMediaInfoFromContainerObject:(id)containerObject
                                   downloadMissing:(BOOL)downloadMissing
                                           timeout:(NSTimeInterval)timeout
                                didRequestDownload:(BOOL *)didRequestDownload {
    if (![containerObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *container = (NSDictionary *)containerObject;
    id widthObject = [container objectForKey:@"width"];
    id heightObject = [container objectForKey:@"height"];
    NSNumber *width = [widthObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[widthObject integerValue]] : nil;
    NSNumber *height = [heightObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[heightObject integerValue]] : nil;

    id thumbnail = [container objectForKey:@"thumbnail"];
    if ([thumbnail isKindOfClass:[NSDictionary class]]) {
        id thumbnailFile = [(NSDictionary *)thumbnail objectForKey:@"file"];
        NSDictionary *thumbnailPhotoInfo = [self photoInfoFromFileObject:thumbnailFile
                                                                  width:width
                                                                 height:height
                                                        downloadMissing:downloadMissing
                                                                timeout:timeout
                                                     didRequestDownload:didRequestDownload];
        if (thumbnailPhotoInfo) {
            return thumbnailPhotoInfo;
        }
    }

    NSDictionary *mediaFile = [self mediaFileObjectFromContainerObject:container];
    if (mediaFile) {
        return [self photoInfoFromFileObject:mediaFile
                                       width:width
                                      height:height
                             downloadMissing:downloadMissing
                                     timeout:timeout
                          didRequestDownload:didRequestDownload];
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (width) {
        [info setObject:width forKey:@"width"];
    }
    if (height) {
        [info setObject:height forKey:@"height"];
    }
    return ([info count] > 0) ? info : nil;
}

- (NSDictionary *)visualMediaInfoFromMessageContentObject:(id)contentObject
                                          downloadMissing:(BOOL)downloadMissing
                                                  timeout:(NSTimeInterval)timeout
                                       didRequestDownload:(BOOL *)didRequestDownload {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *content = (NSDictionary *)contentObject;
    id typeObject = [content objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *type = (NSString *)typeObject;
    if ([type isEqualToString:@"messagePhoto"]) {
        return [self photoInfoFromMessageContentObject:contentObject
                                       downloadMissing:downloadMissing
                                               timeout:timeout
                                    didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageSticker"]) {
        return [self visualMediaInfoFromContainerObject:[content objectForKey:@"sticker"]
                                        downloadMissing:downloadMissing
                                                timeout:timeout
                                     didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageAnimation"]) {
        return [self visualMediaInfoFromContainerObject:[content objectForKey:@"animation"]
                                        downloadMissing:downloadMissing
                                                timeout:timeout
                                     didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageVideo"]) {
        return [self visualMediaInfoFromContainerObject:[content objectForKey:@"video"]
                                        downloadMissing:downloadMissing
                                                timeout:timeout
                                     didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageDocument"]) {
        return [self visualMediaInfoFromDocumentObject:[content objectForKey:@"document"]
                                      downloadMissing:downloadMissing
                                              timeout:timeout
                                   didRequestDownload:didRequestDownload];
    }
    return nil;
}

- (NSDictionary *)photoInfoFromChatPhotoObject:(id)photoObject
                               downloadMissing:(BOOL)downloadMissing
                                       timeout:(NSTimeInterval)timeout
                            didRequestDownload:(BOOL *)didRequestDownload {
    if (![photoObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id smallFile = [(NSDictionary *)photoObject objectForKey:@"small"];
    return [self photoInfoFromFileObject:smallFile
                                   width:nil
                                  height:nil
                         downloadMissing:downloadMissing
                                 timeout:timeout
                      didRequestDownload:didRequestDownload];
}

- (NSString *)messageContentPreviewForObject:(id)contentObject {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return @"[Message]";
    }

    NSDictionary *content = (NSDictionary *)contentObject;
    id typeObject = [content objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]]) {
        return @"[Message]";
    }

    NSString *type = (NSString *)typeObject;
    if ([type isEqualToString:@"messageText"]) {
        NSString *text = [self textFromFormattedTextObject:[content objectForKey:@"text"]];
        return ([text length] > 0) ? text : @"[Text]";
    }

    NSDictionary *labels = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"[Photo]", @"messagePhoto",
                            @"[Video]", @"messageVideo",
                            @"[Animation]", @"messageAnimation",
                            @"[Document]", @"messageDocument",
                            @"[Audio]", @"messageAudio",
                            @"[Voice]", @"messageVoiceNote",
                            @"[Video note]", @"messageVideoNote",
                            @"[Sticker]", @"messageSticker",
                            @"[Contact]", @"messageContact",
                            @"[Location]", @"messageLocation",
                            @"[Poll]", @"messagePoll",
                            @"[Call]", @"messageCall",
                            @"[Invoice]", @"messageInvoice",
                            @"[Unsupported]", @"messageUnsupported",
                            nil];
    NSString *label = [labels objectForKey:type];
    if ([label length] == 0) {
        label = @"[Service message]";
    }

    if ([type isEqualToString:@"messageSticker"]) {
        id sticker = [content objectForKey:@"sticker"];
        if ([sticker isKindOfClass:[NSDictionary class]]) {
            id emoji = [(NSDictionary *)sticker objectForKey:@"emoji"];
            if ([emoji isKindOfClass:[NSString class]] && [(NSString *)emoji length] > 0) {
                label = [NSString stringWithFormat:@"%@ %@", label, emoji];
            }
        }
    }
    if ([type isEqualToString:@"messageDocument"]) {
        NSDictionary *document = [content objectForKey:@"document"];
        if ([document isKindOfClass:[NSDictionary class]] && [self isVisualDocumentObject:document]) {
            label = [self documentVisualLabelFromObject:document];
        }
    }

    NSString *caption = [self textFromFormattedTextObject:[content objectForKey:@"caption"]];
    if ([caption length] > 0) {
        return [NSString stringWithFormat:@"%@ %@", label, caption];
    }
    return label;
}

- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID {
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    NSUInteger visualMediaDownloadsRemaining = 30;
    for (index = 0; index < [messages count]; index++) {
        id messageObject = [messages objectAtIndex:index];
        if (![messageObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *message = (NSDictionary *)messageObject;
        id messageType = [message objectForKey:@"@type"];
        if (![messageType isKindOfClass:[NSString class]] || ![(NSString *)messageType isEqualToString:@"message"]) {
            continue;
        }

        id messageID = [message objectForKey:@"id"];
        id date = [message objectForKey:@"date"];
        id isOutgoing = [message objectForKey:@"is_outgoing"];
        BOOL outgoing = ([isOutgoing respondsToSelector:@selector(boolValue)] && [isOutgoing boolValue]);
        id contentObject = [message objectForKey:@"content"];
        NSString *preview = [self messageContentPreviewForObject:contentObject];
        if ([preview length] == 0) {
            preview = @"[Message]";
        }
        NSString *contentType = nil;
        if ([contentObject isKindOfClass:[NSDictionary class]]) {
            id contentTypeObject = [(NSDictionary *)contentObject objectForKey:@"@type"];
            if ([contentTypeObject isKindOfClass:[NSString class]]) {
                contentType = (NSString *)contentTypeObject;
            }
        }

        NSNumber *safeMessageID = nil;
        if ([messageID respondsToSelector:@selector(longLongValue)]) {
            safeMessageID = [NSNumber numberWithLongLong:[messageID longLongValue]];
        }
        NSNumber *safeDate = nil;
        if ([date respondsToSelector:@selector(integerValue)]) {
            safeDate = [NSNumber numberWithInteger:[date integerValue]];
        } else {
            safeDate = [NSNumber numberWithInteger:0];
        }

        TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:chatID
                                                           messageID:safeMessageID
                                                                date:safeDate
                                                            outgoing:outgoing
                                                             preview:preview] autorelease];
        [item setContentType:contentType];
        [item setSending:([[message objectForKey:@"sending_state"] isKindOfClass:[NSDictionary class]])];
        BOOL didRequestMediaDownload = NO;
        NSDictionary *photoInfo = [self visualMediaInfoFromMessageContentObject:contentObject
                                                                downloadMissing:(visualMediaDownloadsRemaining > 0)
                                                                        timeout:1.5
                                                             didRequestDownload:&didRequestMediaDownload];
        if (didRequestMediaDownload && visualMediaDownloadsRemaining > 0) {
            visualMediaDownloadsRemaining--;
        }
        NSString *mediaPath = [photoInfo objectForKey:@"local_path"];
        if ([mediaPath length] > 0) {
            [item setMediaLocalPath:mediaPath];
        }
        [item setMediaWidth:[photoInfo objectForKey:@"width"]];
        [item setMediaHeight:[photoInfo objectForKey:@"height"]];
        [items addObject:item];
    }
    return items;
}

- (NSString *)threadTitleFromMessages:(NSArray *)messages fallback:(NSString *)fallback {
    NSUInteger index = 0;
    for (index = 0; index < [messages count]; index++) {
        id messageObject = [messages objectAtIndex:index];
        if (![messageObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *message = (NSDictionary *)messageObject;
        NSString *preview = [self messageContentPreviewForObject:[message objectForKey:@"content"]];
        if ([preview length] == 0 || [preview isEqualToString:@"[Message]"] || [preview isEqualToString:@"[Service message]"]) {
            continue;
        }
        return [self singleLineTrimmedString:preview maximumLength:80];
    }
    return ([fallback length] > 0) ? fallback : @"Topic";
}

- (TGChatItem *)threadItemFromThreadInfo:(NSDictionary *)threadInfo
                                  chatID:(NSNumber *)chatID
                         fallbackTitle:(NSString *)fallbackTitle
                        fallbackThreadID:(NSNumber *)fallbackThreadID {
    id threadID = [threadInfo objectForKey:@"message_thread_id"];
    if (![threadID respondsToSelector:@selector(longLongValue)]) {
        threadID = fallbackThreadID;
    }
    if (![threadID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    id unreadValue = [threadInfo objectForKey:@"unread_message_count"];
    NSNumber *unreadCount = [unreadValue respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[unreadValue integerValue]] : [NSNumber numberWithInteger:0];
    id messagesObject = [threadInfo objectForKey:@"messages"];
    NSArray *messages = [messagesObject isKindOfClass:[NSArray class]] ? (NSArray *)messagesObject : [NSArray array];
    NSString *title = [self threadTitleFromMessages:messages fallback:fallbackTitle];
    TGChatItem *item = [[[TGChatItem alloc] initWithChatID:chatID
                                                     title:title
                                               typeSummary:@"Message thread"
                                               unreadCount:unreadCount] autorelease];
    [item setForumTopic:YES];
    [item setParentChatID:chatID];
    [item setMessageThreadID:[NSNumber numberWithLongLong:[threadID longLongValue]]];
    return item;
}

- (NSArray *)threadPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSError *forumTopicError = nil;
    NSArray *forumTopics = [self forumTopicPreviewItemsForChatID:chatID limit:limit timeout:timeout error:&forumTopicError];
    if ([forumTopics count] > 0) {
        NSMutableArray *topicItems = [NSMutableArray array];
        NSUInteger topicIndex = 0;
        for (topicIndex = 0; topicIndex < [forumTopics count]; topicIndex++) {
            id topicObject = [forumTopics objectAtIndex:topicIndex];
            if (![topicObject isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSDictionary *topic = (NSDictionary *)topicObject;
            NSString *topicTitle = [topic objectForKey:@"title"];
            NSNumber *threadID = [topic objectForKey:@"message_thread_id"];
            NSNumber *unreadCount = [topic objectForKey:@"unread_count"];
            if (![unreadCount respondsToSelector:@selector(integerValue)]) {
                unreadCount = [topic objectForKey:@"unread_message_count"];
            }
            if (![unreadCount respondsToSelector:@selector(integerValue)]) {
                unreadCount = [NSNumber numberWithInteger:0];
            }
            if (![threadID respondsToSelector:@selector(longLongValue)]) {
                continue;
            }
            TGChatItem *topicItem = [[[TGChatItem alloc] initWithChatID:chatID
                                                                  title:([topicTitle length] > 0 ? topicTitle : @"Topic")
                                                            typeSummary:@"Forum topic"
                                                            unreadCount:(unreadCount ? unreadCount : [NSNumber numberWithInteger:0])] autorelease];
            [topicItem setForumTopic:YES];
            [topicItem setParentChatID:chatID];
            [topicItem setMessageThreadID:[NSNumber numberWithLongLong:[threadID longLongValue]]];
            [topicItems addObject:topicItem];
        }
        return topicItems;
    }

    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Thread preview request requires a chat id." code:83];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 24;
    } else if (safeLimit > 50) {
        safeLimit = 50;
    }

    NSMutableDictionary *historyRequest = [NSMutableDictionary dictionary];
    [historyRequest setObject:@"getChatHistory" forKey:@"@type"];
    [historyRequest setObject:chatID forKey:@"chat_id"];
    [historyRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"from_message_id"];
    [historyRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [historyRequest setObject:[NSNumber numberWithInt:100] forKey:@"limit"];
    [historyRequest setObject:[NSNumber numberWithBool:NO] forKey:@"only_local"];

    NSError *historyError = nil;
    NSDictionary *historyResponse = [self sendTDLibRequestAndWaitForExtra:historyRequest
                                                               extraPrefix:@"telegraphica-thread-seed-history"
                                                                   timeout:timeout
                                                                 errorCode:83
                                                                     error:&historyError];
    id responseType = [historyResponse objectForKey:@"@type"];
    id messagesObject = [historyResponse objectForKey:@"messages"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"messages"] || ![messagesObject isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = historyError ? historyError : forumTopicError;
        }
        return nil;
    }

    NSMutableArray *threads = [NSMutableArray array];
    NSMutableSet *seenThreadIDs = [NSMutableSet set];
    NSArray *messages = (NSArray *)messagesObject;
    NSUInteger messageIndex = 0;
    for (messageIndex = 0; messageIndex < [messages count] && [threads count] < safeLimit; messageIndex++) {
        id messageObject = [messages objectAtIndex:messageIndex];
        if (![messageObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *message = (NSDictionary *)messageObject;
        id messageID = [message objectForKey:@"id"];
        id threadIDObject = [message objectForKey:@"message_thread_id"];
        NSNumber *threadID = nil;
        if ([threadIDObject respondsToSelector:@selector(longLongValue)] && [threadIDObject longLongValue] > 0) {
            threadID = [NSNumber numberWithLongLong:[threadIDObject longLongValue]];
        } else {
            id canGetThread = [message objectForKey:@"can_get_message_thread"];
            if ([canGetThread respondsToSelector:@selector(boolValue)] && [canGetThread boolValue] && [messageID respondsToSelector:@selector(longLongValue)]) {
                threadID = [NSNumber numberWithLongLong:[messageID longLongValue]];
            }
        }
        if (![threadID respondsToSelector:@selector(longLongValue)] || [threadID longLongValue] <= 0) {
            continue;
        }
        NSString *threadKey = [NSString stringWithFormat:@"%lld", [threadID longLongValue]];
        if ([seenThreadIDs containsObject:threadKey]) {
            continue;
        }
        [seenThreadIDs addObject:threadKey];

        NSNumber *messageIDForThreadRequest = [messageID respondsToSelector:@selector(longLongValue)] ? [NSNumber numberWithLongLong:[messageID longLongValue]] : threadID;
        NSMutableDictionary *threadRequest = [NSMutableDictionary dictionary];
        [threadRequest setObject:@"getMessageThread" forKey:@"@type"];
        [threadRequest setObject:chatID forKey:@"chat_id"];
        [threadRequest setObject:messageIDForThreadRequest forKey:@"message_id"];
        NSDictionary *threadResponse = [self sendTDLibRequestAndWaitForExtra:threadRequest
                                                                  extraPrefix:@"telegraphica-message-thread-info"
                                                                      timeout:1.5
                                                                    errorCode:84
                                                                        error:NULL];
        TGChatItem *threadItem = nil;
        id threadResponseType = [threadResponse objectForKey:@"@type"];
        if ([threadResponseType isKindOfClass:[NSString class]] && [(NSString *)threadResponseType isEqualToString:@"messageThreadInfo"]) {
            NSString *fallbackTitle = [self messageContentPreviewForObject:[message objectForKey:@"content"]];
            threadItem = [self threadItemFromThreadInfo:threadResponse
                                                 chatID:chatID
                                          fallbackTitle:fallbackTitle
                                       fallbackThreadID:threadID];
        }
        if (!threadItem) {
            NSString *fallbackTitle = [self messageContentPreviewForObject:[message objectForKey:@"content"]];
            threadItem = [[[TGChatItem alloc] initWithChatID:chatID
                                                       title:([fallbackTitle length] > 0 ? fallbackTitle : @"Topic")
                                                 typeSummary:@"Message thread"
                                                 unreadCount:[NSNumber numberWithInteger:0]] autorelease];
            [threadItem setForumTopic:YES];
            [threadItem setParentChatID:chatID];
            [threadItem setMessageThreadID:threadID];
        }
        [threads addObject:threadItem];
    }

    return threads;
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self recentMessagePreviewItemsForChatID:chatID messageThreadID:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:nil fromMessageID:fromMessageID limit:limit timeout:timeout error:error];
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:messageThreadID fromMessageID:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:38];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:39];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 20;
    } else if (safeLimit > 50) {
        safeLimit = 50;
    }

    long long anchorMessageID = 0;
    if ([fromMessageID respondsToSelector:@selector(longLongValue)]) {
        anchorMessageID = [fromMessageID longLongValue];
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    BOOL threadHistory = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    if (threadHistory) {
        [request setObject:@"getMessageThreadHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    } else {
        [request setObject:@"getChatHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [request setObject:[NSNumber numberWithBool:NO] forKey:@"only_local"];
    }

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:(threadHistory ? @"telegraphica-thread-history" : @"telegraphica-chat-history")
                                                           timeout:timeout
                                                         errorCode:40
                                                             error:error];
    if (!response && threadHistory) {
        NSMutableDictionary *searchRequest = [NSMutableDictionary dictionary];
        [searchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [searchRequest setObject:chatID forKey:@"chat_id"];
        [searchRequest setObject:@"" forKey:@"query"];
        [searchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [searchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [searchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [searchRequest setObject:[NSNull null] forKey:@"filter"];
        [searchRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:searchRequest
                                             extraPrefix:@"telegraphica-thread-search-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:error];
    }
    if (!response) {
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id messages = [response objectForKey:@"messages"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"messages"] || ![messages isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChatHistory returned an unexpected response." code:41];
        }
        return nil;
    }

    return [self messagePreviewItemsFromMessages:(NSArray *)messages chatID:chatID];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self markMessagesAsReadForChatID:chatID messageThreadID:nil messageIDs:messageIDs timeout:timeout error:error];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:57];
        }
        return NO;
    }
    if (![messageIDs isKindOfClass:[NSArray class]] || [messageIDs count] == 0) {
        return YES;
    }

    NSMutableArray *safeMessageIDs = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [messageIDs count]; index++) {
        id messageID = [messageIDs objectAtIndex:index];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            [safeMessageIDs addObject:[NSNumber numberWithLongLong:[messageID longLongValue]]];
        }
    }
    if ([safeMessageIDs count] == 0) {
        return YES;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to mark messages read. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:58];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"viewMessages" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:safeMessageIDs forKey:@"message_ids"];
    [request setObject:[NSDictionary dictionaryWithObject:@"messageSourceChatHistory" forKey:@"@type"] forKey:@"source"];
    if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
    }
    [request setObject:[NSNumber numberWithBool:YES] forKey:@"force_read"];

    NSError *currentSchemaError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-view-messages"
                                                           timeout:timeout
                                                         errorCode:59
                                                             error:&currentSchemaError];
    if (!response) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest removeObjectForKey:@"source"];
        NSNumber *safeThreadID = [NSNumber numberWithLongLong:0];
        if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
            safeThreadID = [NSNumber numberWithLongLong:[messageThreadID longLongValue]];
        }
        [legacyRequest setObject:safeThreadID forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:@"telegraphica-view-messages-legacy"
                                                 timeout:timeout
                                               errorCode:59
                                                   error:error];
        if (!response) {
            if (error && *error == nil) {
                *error = currentSchemaError;
            }
            return NO;
        }
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib viewMessages returned an unexpected response." code:60];
        }
        return NO;
    }
    return YES;
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendTextMessageToChatID:chatID messageThreadID:nil text:text timeout:timeout error:error];
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:42];
        }
        return nil;
    }

    if (![text isKindOfClass:[NSString class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Message text is missing." code:43];
        }
        return nil;
    }

    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedText length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Message text is empty." code:43];
        }
        return nil;
    }
    if ([text length] > 4096) {
        if (error) {
            *error = [self errorWithDescription:@"Message text is too long for this spike." code:44];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:45];
        }
        return nil;
    }

    NSMutableDictionary *formattedText = [NSMutableDictionary dictionary];
    [formattedText setObject:@"formattedText" forKey:@"@type"];
    [formattedText setObject:text forKey:@"text"];
    [formattedText setObject:[NSArray array] forKey:@"entities"];

    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setObject:@"inputMessageText" forKey:@"@type"];
    [content setObject:formattedText forKey:@"text"];
    [content setObject:[NSNumber numberWithBool:YES] forKey:@"clear_draft"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
    }
    [request setObject:content forKey:@"input_message_content"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-send-text"
                                                           timeout:timeout
                                                         errorCode:46
                                                             error:error];
    if (!response) {
        if (error && !*error) {
            *error = [self errorWithDescription:@"TDLib did not confirm sendMessage before timeout. The message may or may not have been sent." code:46];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib sendMessage returned an unexpected response." code:47];
        }
        return nil;
    }

    return @"message submitted";
}

- (NSString *)logOutWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to log out. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:51];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"logOut" forKey:@"@type"];
    NSString *extra = [self uniqueExtraWithPrefix:@"telegraphica-logout"];
    [request setObject:extra forKey:@"@extra"];
    NSUInteger generation = [self authorizationStateGeneration];
    NSError *responseError = nil;
    NSDictionary *response = [self sendTDLibRequest:request
                                    waitingForExtra:extra
                                            timeout:timeout
                                          errorCode:52
                                              error:&responseError];
    if (!response) {
        if (error) {
            *error = responseError ? responseError : [self errorWithDescription:@"TDLib did not acknowledge logout before timeout." code:52];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib logOut returned an unexpected response." code:53];
        }
        return nil;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSString *waitingState = @"ready";
    NSUInteger waitingGeneration = generation;
    while ([[NSDate date] compare:deadline] == NSOrderedAscending) {
        NSString *cachedSummary = [self cachedAuthorizationStateSummary];
        if ([cachedSummary isEqualToString:@"closed"]) {
            [self destroyTDLibClient];
            return @"logged out; auth state: closed";
        }

        NSTimeInterval remaining = [deadline timeIntervalSinceNow];
        if (remaining <= 0.0) {
            break;
        }

        NSString *summary = [self waitForAuthorizationStateDifferentFromState:waitingState
                                                              afterGeneration:waitingGeneration
                                                                      timeout:remaining];
        if ([summary length] == 0) {
            break;
        }
        if ([summary hasPrefix:@"error"]) {
            if (error) {
                *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib rejected logout: %@", summary] code:54];
            }
            return nil;
        }
        if ([summary isEqualToString:@"closed"]) {
            [self destroyTDLibClient];
            return @"logged out; auth state: closed";
        }

        cachedSummary = [self cachedAuthorizationStateSummary];
        if ([cachedSummary isEqualToString:@"closed"]) {
            [self destroyTDLibClient];
            return @"logged out; auth state: closed";
        }

        waitingState = summary;
        waitingGeneration = [self authorizationStateGeneration];
    }

    if (error) {
        *error = [self errorWithDescription:@"TDLib accepted logout, but did not reach authorizationStateClosed before timeout." code:55];
    }
    return nil;
}

- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load profile. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:48];
        }
        return nil;
    }

    NSMutableDictionary *getMeRequest = [NSMutableDictionary dictionary];
    [getMeRequest setObject:@"getMe" forKey:@"@type"];
    NSDictionary *userResponse = [self sendTDLibRequestAndWaitForExtra:getMeRequest
                                                           extraPrefix:@"telegraphica-profile-get-me"
                                                               timeout:timeout
                                                             errorCode:49
                                                                 error:error];
    if (!userResponse) {
        return nil;
    }

    id userType = [userResponse objectForKey:@"@type"];
    if (![userType isKindOfClass:[NSString class]] || ![(NSString *)userType isEqualToString:@"user"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getMe returned an unexpected profile response." code:49];
        }
        return nil;
    }

    id firstName = [userResponse objectForKey:@"first_name"];
    id lastName = [userResponse objectForKey:@"last_name"];
    id username = [userResponse objectForKey:@"username"];
    if (![username isKindOfClass:[NSString class]] || [(NSString *)username length] == 0) {
        id usernames = [userResponse objectForKey:@"usernames"];
        if ([usernames isKindOfClass:[NSDictionary class]]) {
            id activeUsernames = [(NSDictionary *)usernames objectForKey:@"active_usernames"];
            if ([activeUsernames isKindOfClass:[NSArray class]] && [(NSArray *)activeUsernames count] > 0) {
                id firstUsername = [(NSArray *)activeUsernames objectAtIndex:0];
                if ([firstUsername isKindOfClass:[NSString class]]) {
                    username = firstUsername;
                }
            }
        }
    }

    NSMutableArray *nameParts = [NSMutableArray array];
    if ([firstName isKindOfClass:[NSString class]] && [(NSString *)firstName length] > 0) {
        [nameParts addObject:firstName];
    }
    if ([lastName isKindOfClass:[NSString class]] && [(NSString *)lastName length] > 0) {
        [nameParts addObject:lastName];
    }
    NSString *displayName = ([nameParts count] > 0) ? [nameParts componentsJoinedByString:@" "] : @"Telegram account";

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:displayName forKey:@"display_name"];
    if ([firstName isKindOfClass:[NSString class]] && [(NSString *)firstName length] > 0) {
        [summary setObject:firstName forKey:@"first_name"];
    }
    if ([lastName isKindOfClass:[NSString class]] && [(NSString *)lastName length] > 0) {
        [summary setObject:lastName forKey:@"last_name"];
    }
    if ([username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
        [summary setObject:username forKey:@"username"];
    }
    id phoneNumber = [userResponse objectForKey:@"phone_number"];
    if ([phoneNumber isKindOfClass:[NSString class]] && [(NSString *)phoneNumber length] > 0) {
        [summary setObject:phoneNumber forKey:@"phone_number"];
    }
    id userID = [userResponse objectForKey:@"id"];
    if ([userID respondsToSelector:@selector(longLongValue)]) {
        NSNumber *safeUserID = [NSNumber numberWithLongLong:[userID longLongValue]];
        [summary setObject:safeUserID forKey:@"id"];

        NSMutableDictionary *fullInfoRequest = [NSMutableDictionary dictionary];
        [fullInfoRequest setObject:@"getUserFullInfo" forKey:@"@type"];
        [fullInfoRequest setObject:safeUserID forKey:@"user_id"];
        NSDictionary *fullInfoResponse = [self sendTDLibRequestAndWaitForExtra:fullInfoRequest
                                                                    extraPrefix:@"telegraphica-profile-full-info"
                                                                        timeout:2.0
                                                                      errorCode:61
                                                                          error:NULL];
        id fullInfoType = [fullInfoResponse objectForKey:@"@type"];
        if ([fullInfoType isKindOfClass:[NSString class]] && [(NSString *)fullInfoType isEqualToString:@"userFullInfo"]) {
            NSString *bio = [self textFromFormattedTextObject:[fullInfoResponse objectForKey:@"bio"]];
            if ([bio length] > 0) {
                [summary setObject:bio forKey:@"bio"];
            }
        }
    }
    BOOL didRequestAvatarDownload = NO;
    NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[userResponse objectForKey:@"profile_photo"]
                                                  downloadMissing:YES
                                                          timeout:1.5
                                               didRequestDownload:&didRequestAvatarDownload];
    NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
    if ([avatarPath length] > 0) {
        [summary setObject:avatarPath forKey:@"avatar_path"];
    }
    return summary;
}

- (NSString *)postLoginProbeSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready for post-login probe. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:30];
        }
        return nil;
    }

    NSMutableDictionary *getMeRequest = [NSMutableDictionary dictionary];
    [getMeRequest setObject:@"getMe" forKey:@"@type"];
    NSDictionary *userResponse = [self sendTDLibRequestAndWaitForExtra:getMeRequest
                                                           extraPrefix:@"telegraphica-get-me"
                                                               timeout:timeout
                                                             errorCode:31
                                                                 error:error];
    if (!userResponse) {
        return nil;
    }

    id userType = [userResponse objectForKey:@"@type"];
    if (![userType isKindOfClass:[NSString class]] || ![(NSString *)userType isEqualToString:@"user"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getMe returned an unexpected response." code:32];
        }
        return nil;
    }

    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    [chatList setObject:@"chatListMain" forKey:@"@type"];

    NSMutableDictionary *getChatsRequest = [NSMutableDictionary dictionary];
    [getChatsRequest setObject:@"getChats" forKey:@"@type"];
    [getChatsRequest setObject:chatList forKey:@"chat_list"];
    [getChatsRequest setObject:[NSNumber numberWithInt:20] forKey:@"limit"];

    NSError *currentChatsError = nil;
    NSDictionary *chatsResponse = [self sendTDLibRequestAndWaitForExtra:getChatsRequest
                                                            extraPrefix:@"telegraphica-get-chats"
                                                                timeout:timeout
                                                              errorCode:33
                                                                  error:&currentChatsError];
    if (!chatsResponse) {
        NSError *legacyChatsError = nil;
        NSMutableDictionary *legacyGetChatsRequest = [NSMutableDictionary dictionary];
        [legacyGetChatsRequest setObject:@"getChats" forKey:@"@type"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_order"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_chat_id"];
        [legacyGetChatsRequest setObject:[NSNumber numberWithInt:20] forKey:@"limit"];

        chatsResponse = [self sendTDLibRequestAndWaitForExtra:legacyGetChatsRequest
                                                          extraPrefix:@"telegraphica-get-chats-legacy"
                                                              timeout:timeout
                                                            errorCode:33
                                                                 error:&legacyChatsError];
        if (!chatsResponse && error) {
            NSString *currentMessage = currentChatsError ? [currentChatsError localizedDescription] : @"current getChats schema failed";
            NSString *legacyMessage = legacyChatsError ? [legacyChatsError localizedDescription] : @"legacy getChats schema failed";
            NSString *message = [NSString stringWithFormat:@"%@; fallback also failed: %@", currentMessage, legacyMessage];
            *error = [self errorWithDescription:message code:33];
        }
    }
    if (!chatsResponse) {
        return nil;
    }

    id chatsType = [chatsResponse objectForKey:@"@type"];
    id chatIDs = [chatsResponse objectForKey:@"chat_ids"];
    if (![chatsType isKindOfClass:[NSString class]] || ![(NSString *)chatsType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChats returned an unexpected response." code:34];
        }
        return nil;
    }

    return [NSString stringWithFormat:@"getMe OK (authorized user object received); getChats OK (%lu chat ids received)", (unsigned long)[(NSArray *)chatIDs count]];
}

- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *trimmedPhone = [phoneNumber stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedPhone length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Phone number is empty." code:24];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitPhoneNumber"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setAuthenticationPhoneNumber" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-auth-phone"] forKey:@"@extra"];
    [request setObject:trimmedPhone forKey:@"phone_number"];
    [request setObject:[NSNull null] forKey:@"settings"];
    return [self sendAuthorizationRequest:request actionName:@"phone number" waitingState:@"waitPhoneNumber" timeout:timeout errorCode:25 error:error];
}

- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *trimmedCode = [code stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedCode length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Authentication code is empty." code:26];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitCode"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkAuthenticationCode" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-auth-code"] forKey:@"@extra"];
    [request setObject:trimmedCode forKey:@"code"];
    return [self sendAuthorizationRequest:request actionName:@"authentication code" waitingState:@"waitCode" timeout:timeout errorCode:27 error:error];
}

- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if ([password length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Authentication password is empty." code:28];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"waitPassword"]) {
        if ([authorizationState length] > 0) {
            return [NSString stringWithFormat:@"skipped; auth state is %@", authorizationState];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"checkAuthenticationPassword" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-auth-password"] forKey:@"@extra"];
    [request setObject:password forKey:@"password"];
    return [self sendAuthorizationRequest:request actionName:@"authentication password" waitingState:@"waitPassword" timeout:timeout errorCode:29 error:error];
}

@end
