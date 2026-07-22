#import "TGTDLibClient.h"
#import "TGTDLibBundledCredentials.h"
#import "TGChatItem.h"
#import "TGMessageItem.h"
#import "TGMessagePollSupport.h"
#import "../Services/TGKeychainHelper.h"
#import "../Services/TGLogger.h"
#import "../Services/TGResourcePolicy.h"
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
static NSString * const TGTDLibRemoteConfigurationURLInfoKey = @"TelegraphicaRemoteTDLibConfigURL";
static NSString * const TGTDLibRemoteConfigurationURLEnvironmentKey = @"TELEGRAPHICA_REMOTE_TDLIB_CONFIG_URL";
static NSTimeInterval const TGTDLibRemoteConfigurationTimeout = 8.0;
static NSUInteger const TGTDLibMaxPendingResponses = 64;
static NSUInteger const TGTDLibMaxPendingUpdateSummaries = 200;
static NSUInteger const TGTDLibMaxMainChatPreviewLimit = 500;
static NSUInteger const TGTDLibMainChatLoadBatchSize = 40;
static NSUInteger const TGTDLibMainChatLoadAttemptLimit = 8;
NSString * const TGTDLibChatFiltersDidChangeNotification = @"TGTDLibChatFiltersDidChangeNotification";

static BOOL TGTDLibObjectIsBoolean(id object) {
    return object && CFGetTypeID((CFTypeRef)object) == CFBooleanGetTypeID();
}

static BOOL TGTDLibCapabilityBoolFromDictionary(NSDictionary *dictionary, NSString *key) {
    id value = [dictionary objectForKey:key];
    return ([value respondsToSelector:@selector(boolValue)] && [value boolValue]);
}

static BOOL TGTDLibDictionaryHasKey(NSDictionary *dictionary, NSString *key) {
    return ([dictionary isKindOfClass:[NSDictionary class]] && [dictionary objectForKey:key] != nil);
}

static BOOL TGTDLibCanGetMessageThreadFromObject(NSDictionary *object) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    id directValue = [object objectForKey:@"can_get_message_thread"];
    if ([directValue respondsToSelector:@selector(boolValue)] && [directValue boolValue]) {
        return YES;
    }

    NSDictionary *interactionInfo = [[object objectForKey:@"interaction_info"] isKindOfClass:[NSDictionary class]] ? [object objectForKey:@"interaction_info"] : nil;
    NSDictionary *replyInfo = [[interactionInfo objectForKey:@"reply_info"] isKindOfClass:[NSDictionary class]] ? [interactionInfo objectForKey:@"reply_info"] : nil;
    id replyInfoCanGetThread = [replyInfo objectForKey:@"can_get_message_thread"];
    if ([replyInfoCanGetThread respondsToSelector:@selector(boolValue)] && [replyInfoCanGetThread boolValue]) {
        return YES;
    }

    NSArray *nestedKeys = [NSArray arrayWithObjects:@"message_properties", @"messageProperties", @"properties", nil];
    NSUInteger index = 0;
    for (index = 0; index < [nestedKeys count]; index++) {
        id nested = [object objectForKey:[nestedKeys objectAtIndex:index]];
        if (![nested isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        id nestedValue = [(NSDictionary *)nested objectForKey:@"can_get_message_thread"];
        if ([nestedValue respondsToSelector:@selector(boolValue)] && [nestedValue boolValue]) {
            return YES;
        }
    }
    return NO;
}

static NSComparisonResult TGTDLibCompareChatItemsByPinnedOrder(id leftObject, id rightObject, void *context) {
    (void)context;
    if (![leftObject isKindOfClass:[TGChatItem class]] || ![rightObject isKindOfClass:[TGChatItem class]]) {
        return NSOrderedSame;
    }

    TGChatItem *left = (TGChatItem *)leftObject;
    TGChatItem *right = (TGChatItem *)rightObject;
    if ([left isPinned] != [right isPinned]) {
        return [left isPinned] ? NSOrderedAscending : NSOrderedDescending;
    }

    long long leftOrder = [[left chatListOrder] respondsToSelector:@selector(longLongValue)] ? [[left chatListOrder] longLongValue] : 0;
    long long rightOrder = [[right chatListOrder] respondsToSelector:@selector(longLongValue)] ? [[right chatListOrder] longLongValue] : 0;
    if (leftOrder != rightOrder) {
        return (leftOrder > rightOrder) ? NSOrderedAscending : NSOrderedDescending;
    }

    return [[left title] localizedCaseInsensitiveCompare:[right title]];
}

static NSDictionary *TGTDLibMessageCapabilitiesFromObject(NSDictionary *object) {
    if (![object isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    BOOL hasReply = TGTDLibDictionaryHasKey(object, @"can_be_replied");
    BOOL hasEdit = TGTDLibDictionaryHasKey(object, @"can_be_edited");
    BOOL hasDeleteSelf = TGTDLibDictionaryHasKey(object, @"can_be_deleted_only_for_self");
    BOOL hasDeleteAll = TGTDLibDictionaryHasKey(object, @"can_be_deleted_for_all_users");
    if (!hasReply && !hasEdit && !hasDeleteSelf && !hasDeleteAll) {
        return nil;
    }

    NSMutableDictionary *capabilities = [NSMutableDictionary dictionary];
    [capabilities setObject:[NSNumber numberWithBool:YES] forKey:@"known"];
    BOOL canReply = YES;
    if (TGTDLibDictionaryHasKey(object, @"can_be_replied")) {
        canReply = TGTDLibCapabilityBoolFromDictionary(object, @"can_be_replied");
    }
    [capabilities setObject:[NSNumber numberWithBool:canReply] forKey:@"can_be_replied"];
    [capabilities setObject:[NSNumber numberWithBool:TGTDLibCapabilityBoolFromDictionary(object, @"can_be_edited")] forKey:@"can_be_edited"];
    [capabilities setObject:[NSNumber numberWithBool:TGTDLibCapabilityBoolFromDictionary(object, @"can_be_deleted_only_for_self")] forKey:@"can_be_deleted_only_for_self"];
    [capabilities setObject:[NSNumber numberWithBool:TGTDLibCapabilityBoolFromDictionary(object, @"can_be_deleted_for_all_users")] forKey:@"can_be_deleted_for_all_users"];
    id editDate = [object objectForKey:@"edit_date"];
    if ([editDate respondsToSelector:@selector(integerValue)]) {
        [capabilities setObject:[NSNumber numberWithInteger:[editDate integerValue]] forKey:@"edit_date"];
    }
    return capabilities;
}

static BOOL TGPreviewLooksLikePlainMediaLabel(NSString *preview) {
    if (![preview isKindOfClass:[NSString class]] || [preview length] == 0) {
        return YES;
    }
    NSArray *labels = [NSArray arrayWithObjects:
                       @"[Photo]",
                       @"Image",
                       @"[Video]",
                       @"Video",
                       @"[Animation]",
                       @"Animation",
                       @"[GIF]",
                       @"GIF",
                       @"[Document]",
                       @"Document",
                       @"[Sticker]",
                       @"Sticker",
                       @"[Media]",
                       @"Media",
                       nil];
    NSUInteger index = 0;
    for (index = 0; index < [labels count]; index++) {
        if ([preview isEqualToString:[labels objectAtIndex:index]]) {
            return YES;
        }
    }
    return NO;
}

static BOOL TGTDLibPhotoSendErrorLooksLikeSchemaMismatch(NSError *error) {
    NSString *message = [[error localizedDescription] lowercaseString];
    if ([message length] == 0) {
        return NO;
    }
    NSArray *markers = [NSArray arrayWithObjects:
                        @"inputmessagephoto",
                        @"inputphoto",
                        @"can't parse",
                        @"cannot parse",
                        @"unexpected field",
                        @"unknown class",
                        @"inputfile is not specified",
                        @"input file is not specified",
                        @"thumbnail",
                        @"self_destruct_type",
                        @"show_caption_above_media",
                        nil];
    NSUInteger index = 0;
    for (index = 0; index < [markers count]; index++) {
        if ([message rangeOfString:[markers objectAtIndex:index]].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

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
    NSMutableDictionary *_senderSummaryCache;
    NSMutableDictionary *_syntheticMediaAlbumIDByMessageKey;
    NSString *_latestAuthorizationStateSummary;
    NSUInteger _authorizationStateGeneration;
    NSLock *_sendLock;
    NSThread *_receiverThread;
    BOOL _receiverRunning;
    BOOL _receiverShouldStop;
    BOOL _shutdownStarted;
    BOOL _mainChatListExhausted;
    BOOL _chatFilterInfosKnown;
    BOOL _chatFilterFallbackProbeFinished;
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
- (NSArray *)chatFilterInfoItemsByProbingChatFoldersWithTimeout:(NSTimeInterval)timeout;
- (NSDictionary *)safeChatFilterInfoFromDictionary:(NSDictionary *)filterDictionary identifier:(NSNumber *)identifier apiKind:(NSString *)apiKind;
- (NSString *)safeChatFolderTitleFromObject:(id)titleObject;
- (NSString *)chatFilterAPIKindForFilterID:(NSNumber *)filterID;
- (NSDictionary *)chatListObjectForChatFilterID:(NSNumber *)filterID;
- (NSString *)chatListIDKeyForType:(NSString *)chatListType;
- (NSDictionary *)sendTDLibRequest:(NSDictionary *)request waitingForExtra:(NSString *)extra timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request extraPrefix:(NSString *)extraPrefix timeout:(NSTimeInterval)timeout errorCode:(NSInteger)errorCode error:(NSError **)error;
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
- (NSDictionary *)reactionInfoFromMessageObject:(NSDictionary *)messageObject;
- (BOOL)chatNotificationsMutedFromObject:(NSDictionary *)chatObject;
- (NSDictionary *)chatPositionFromChatObject:(NSDictionary *)chatObject chatListType:(NSString *)chatListType filterID:(NSNumber *)filterID;
- (void)applyChatPositionFromChatObject:(NSDictionary *)chatObject toChatItem:(TGChatItem *)item chatListType:(NSString *)chatListType filterID:(NSNumber *)filterID;
- (TGChatItem *)chatPreviewItemFromChatObject:(NSDictionary *)chatResponse
                                  chatListType:(NSString *)chatListType
                                      filterID:(NSNumber *)filterID
                                downloadAvatar:(BOOL)downloadAvatar
                         avatarDownloadCounter:(NSUInteger *)avatarDownloadsRemaining
                                      timeout:(NSTimeInterval)timeout;
- (NSDictionary *)downloadableInfoFromMessageContentObject:(id)contentObject;
- (BOOL)shouldAutoDownloadMessageContentObject:(id)contentObject downloadableInfo:(NSDictionary *)downloadableInfo;
- (NSDictionary *)senderSummaryFromMessageObject:(NSDictionary *)messageObject timeout:(NSTimeInterval)timeout;
- (NSDictionary *)replyContextForMessageObject:(NSDictionary *)messageObject chatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout;
- (NSString *)messageContentPreviewForObject:(id)contentObject;
- (NSDictionary *)userSenderSummaryForUserID:(NSNumber *)userID timeout:(NSTimeInterval)timeout;
- (NSDictionary *)photoInfoFromChatPhotoObject:(id)photoObject
                               downloadMissing:(BOOL)downloadMissing
                                       timeout:(NSTimeInterval)timeout
                            didRequestDownload:(BOOL *)didRequestDownload;
- (NSDictionary *)stickerPreviewInfoFromStickerObject:(id)stickerObject
                                      downloadMissing:(BOOL)downloadMissing
                                              timeout:(NSTimeInterval)timeout
                                   didRequestDownload:(BOOL *)didRequestDownload;
- (NSNumber *)forumTopicIDFromTopicObject:(NSDictionary *)topicObject;
- (NSNumber *)messageThreadIDFromMessageObject:(NSDictionary *)messageObject;
- (NSString *)messageTopicKindFromMessageObject:(NSDictionary *)messageObject;
- (NSArray *)messagePreviewItemsByGroupingMediaAlbums:(NSArray *)items;
- (NSString *)syntheticMediaAlbumMessageKeyForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID;
- (void)rememberSyntheticMediaAlbumForMessages:(NSArray *)messages chatID:(NSNumber *)chatID;
- (NSNumber *)syntheticMediaAlbumIDForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID;
- (NSDictionary *)sendMessageRequest:(NSDictionary *)request
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                          extraPrefix:(NSString *)extraPrefix
                              timeout:(NSTimeInterval)timeout
                            errorCode:(NSInteger)errorCode
                                error:(NSError **)error;
- (NSDictionary *)formattedCaptionForSendCaption:(NSString *)caption;
- (NSDictionary *)inputFileLocalForPath:(NSString *)path;
- (NSDictionary *)photoInputMessageContentForInputFile:(NSDictionary *)inputFile caption:(NSDictionary *)formattedCaption width:(NSNumber *)width height:(NSNumber *)height currentSchema:(BOOL)currentSchema;
- (NSDictionary *)genericInputMessageContentForInputFile:(NSDictionary *)inputFile contentType:(NSString *)contentType caption:(NSDictionary *)formattedCaption currentSchema:(BOOL)currentSchema;
- (BOOL)validateLocalSendFilePath:(NSString *)localPath label:(NSString *)label outPath:(NSString **)outPath error:(NSError **)error code:(NSInteger)code;
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
        _senderSummaryCache = [[NSMutableDictionary alloc] init];
        _syntheticMediaAlbumIDByMessageKey = [[NSMutableDictionary alloc] init];
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
        [_senderSummaryCache removeAllObjects];
        [_chatFilterInfos release];
        _chatFilterInfos = nil;
        _chatFilterInfosKnown = NO;
        _chatFilterFallbackProbeFinished = NO;
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
    [_senderSummaryCache removeAllObjects];
    [_chatFilterInfos release];
    _chatFilterInfos = nil;
    _chatFilterInfosKnown = NO;
    _chatFilterFallbackProbeFinished = NO;
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
    _chatFilterFallbackProbeFinished = NO;
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
    [_senderSummaryCache release];
    [_syntheticMediaAlbumIDByMessageKey release];
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
    BOOL known = _chatFilterInfosKnown;
    BOOL fallbackProbeFinished = _chatFilterFallbackProbeFinished;
    NSArray *filters = [_chatFilterInfos copy];
    [_responseCondition unlock];

    if ((!known || [filters count] == 0) && !fallbackProbeFinished) {
        NSArray *probedFilters = [self chatFilterInfoItemsByProbingChatFoldersWithTimeout:timeout];
        [_responseCondition lock];
        if (!_chatFilterInfosKnown || [_chatFilterInfos count] == 0) {
            [_chatFilterInfos release];
            _chatFilterInfos = [probedFilters copy];
            _chatFilterInfosKnown = YES;
            [filters release];
            filters = [_chatFilterInfos copy];
            [_responseCondition broadcast];
        }
        _chatFilterFallbackProbeFinished = YES;
        [_responseCondition unlock];
    }

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

- (NSString *)safeChatFolderTitleFromObject:(id)titleObject {
    if ([titleObject isKindOfClass:[NSString class]]) {
        NSString *title = (NSString *)titleObject;
        return ([title length] > 0) ? title : nil;
    }
    if (![titleObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *titleDictionary = (NSDictionary *)titleObject;
    NSArray *candidateKeys = [NSArray arrayWithObjects:@"text", @"title", @"name", nil];
    NSUInteger index = 0;
    for (index = 0; index < [candidateKeys count]; index++) {
        id value = [titleDictionary objectForKey:[candidateKeys objectAtIndex:index]];
        if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
            return (NSString *)value;
        }
        if ([value isKindOfClass:[NSDictionary class]]) {
            NSString *nestedTitle = [self safeChatFolderTitleFromObject:value];
            if ([nestedTitle length] > 0) {
                return nestedTitle;
            }
        }
    }
    return nil;
}

- (NSDictionary *)safeChatFilterInfoFromDictionary:(NSDictionary *)filterDictionary identifier:(NSNumber *)identifier apiKind:(NSString *)apiKind {
    if (![filterDictionary isKindOfClass:[NSDictionary class]] ||
        ![identifier respondsToSelector:@selector(integerValue)] ||
        [apiKind length] == 0) {
        return nil;
    }

    id titleObject = [filterDictionary objectForKey:@"title"];
    if (!titleObject) {
        titleObject = [filterDictionary objectForKey:@"name"];
    }
    NSString *title = [self safeChatFolderTitleFromObject:titleObject];
    if ([title length] == 0) {
        return nil;
    }

    id iconObject = [filterDictionary objectForKey:@"icon_name"];
    if (![iconObject isKindOfClass:[NSString class]]) {
        id iconDictionary = [filterDictionary objectForKey:@"icon"];
        if ([iconDictionary isKindOfClass:[NSDictionary class]]) {
            iconObject = [(NSDictionary *)iconDictionary objectForKey:@"name"];
        }
    }

    NSMutableDictionary *safeFilter = [NSMutableDictionary dictionary];
    [safeFilter setObject:[NSNumber numberWithInteger:[identifier integerValue]] forKey:@"id"];
    [safeFilter setObject:title forKey:@"title"];
    [safeFilter setObject:apiKind forKey:@"api_kind"];
    if ([iconObject isKindOfClass:[NSString class]] && [(NSString *)iconObject length] > 0) {
        [safeFilter setObject:iconObject forKey:@"icon_name"];
    }
    return safeFilter;
}

- (NSArray *)chatFilterInfoItemsByProbingChatFoldersWithTimeout:(NSTimeInterval)timeout {
    if (timeout <= 0.0) {
        timeout = 1.5;
    }
    if (timeout > 3.0) {
        timeout = 3.0;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSMutableArray *folders = [NSMutableArray array];
    NSMutableArray *missSamples = [NSMutableArray array];
    NSUInteger missingAfterLastHit = 0;
    NSInteger folderID = 1;
    for (folderID = 1; folderID <= 64; folderID++) {
        if ([[NSDate date] compare:deadline] != NSOrderedAscending) {
            break;
        }

        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        [request setObject:@"getChatFolder" forKey:@"@type"];
        [request setObject:[NSNumber numberWithInteger:folderID] forKey:@"chat_folder_id"];

        NSError *folderError = nil;
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                            extraPrefix:@"telegraphica-get-chat-folder"
                                                                timeout:0.25
                                                              errorCode:98
                                                                  error:&folderError];
        id responseType = [response objectForKey:@"@type"];
        if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chatFolder"]) {
            if ([missSamples count] < 10) {
                NSString *sample = nil;
                if (folderError) {
                    sample = [NSString stringWithFormat:@"id=%ld error=%@", (long)folderID, [folderError localizedDescription]];
                } else if ([responseType isKindOfClass:[NSString class]]) {
                    id code = [response objectForKey:@"code"];
                    id message = [response objectForKey:@"message"];
                    sample = [NSString stringWithFormat:@"id=%ld type=%@ code=%@ message=%@",
                              (long)folderID,
                              responseType,
                              code ? code : @"?",
                              message ? message : @"?"];
                } else {
                    sample = [NSString stringWithFormat:@"id=%ld no response", (long)folderID];
                }
                [missSamples addObject:sample];
            }
            if ([folders count] > 0) {
                missingAfterLastHit++;
                if (missingAfterLastHit >= 8) {
                    break;
                }
            }
            continue;
        }

        NSDictionary *safeFolder = [self safeChatFilterInfoFromDictionary:response
                                                                identifier:[NSNumber numberWithInteger:folderID]
                                                                   apiKind:@"folder"];
        if (safeFolder) {
            [folders addObject:safeFolder];
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Chat folders: probed folder id=%ld title=%@.",
                                           (long)folderID,
                                           [safeFolder objectForKey:@"title"]]];
            missingAfterLastHit = 0;
        }
    }

    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Chat folders: fallback probe loaded %lu folder(s); samples: %@",
                                   (unsigned long)[folders count],
                                   [missSamples componentsJoinedByString:@"; "]]];
    return folders;
}

- (NSString *)chatFilterAPIKindForFilterID:(NSNumber *)filterID {
    if (![filterID respondsToSelector:@selector(longLongValue)]) {
        return @"filter";
    }

    [_responseCondition lock];
    NSArray *filters = [_chatFilterInfos copy];
    [_responseCondition unlock];

    NSString *apiKind = nil;
    NSUInteger index = 0;
    for (index = 0; index < [filters count]; index++) {
        id filterObject = [filters objectAtIndex:index];
        if (![filterObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *filterDictionary = (NSDictionary *)filterObject;
        id identifier = [filterDictionary objectForKey:@"id"];
        if (![identifier respondsToSelector:@selector(longLongValue)] ||
            [identifier longLongValue] != [filterID longLongValue]) {
            continue;
        }
        id kind = [filterDictionary objectForKey:@"api_kind"];
        if ([kind isKindOfClass:[NSString class]] && [(NSString *)kind length] > 0) {
            apiKind = [(NSString *)kind retain];
        }
        break;
    }
    [filters release];

    if (!apiKind) {
        return @"filter";
    }
    return [apiKind autorelease];
}

- (NSDictionary *)chatListObjectForChatFilterID:(NSNumber *)filterID {
    NSMutableDictionary *chatList = [NSMutableDictionary dictionary];
    if (![filterID respondsToSelector:@selector(longLongValue)]) {
        [chatList setObject:@"chatListMain" forKey:@"@type"];
        return chatList;
    }

    NSString *apiKind = [self chatFilterAPIKindForFilterID:filterID];
    if ([apiKind isEqualToString:@"folder"]) {
        [chatList setObject:@"chatListFolder" forKey:@"@type"];
        [chatList setObject:[NSNumber numberWithLongLong:[filterID longLongValue]] forKey:@"chat_folder_id"];
    } else {
        [chatList setObject:@"chatListFilter" forKey:@"@type"];
        [chatList setObject:[NSNumber numberWithLongLong:[filterID longLongValue]] forKey:@"chat_filter_id"];
    }
    return chatList;
}

- (NSString *)chatListIDKeyForType:(NSString *)chatListType {
    if ([chatListType isEqualToString:@"chatListFolder"]) {
        return @"chat_folder_id";
    }
    if ([chatListType isEqualToString:@"chatListFilter"]) {
        return @"chat_filter_id";
    }
    return nil;
}

- (NSArray *)chatFilterInfoItemsFromUpdateObject:(NSDictionary *)dictionary {
    id typeObject = [dictionary objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *apiKind = nil;
    id filterObjects = nil;
    if ([(NSString *)typeObject isEqualToString:@"updateChatFilters"]) {
        apiKind = @"filter";
        filterObjects = [dictionary objectForKey:@"chat_filters"];
    } else if ([(NSString *)typeObject isEqualToString:@"updateChatFolders"]) {
        apiKind = @"folder";
        filterObjects = [dictionary objectForKey:@"chat_folders"];
    } else {
        return nil;
    }

    if (![filterObjects isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *filters = [NSMutableArray arrayWithCapacity:[(NSArray *)filterObjects count]];
    NSMutableArray *titles = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)filterObjects count]; index++) {
        id filterObject = [(NSArray *)filterObjects objectAtIndex:index];
        if (![filterObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *filterDictionary = (NSDictionary *)filterObject;
        id identifier = [filterDictionary objectForKey:@"id"];
        NSDictionary *safeFilter = [self safeChatFilterInfoFromDictionary:filterDictionary
                                                                identifier:identifier
                                                                   apiKind:apiKind];
        if (safeFilter) {
            [filters addObject:safeFilter];
            [titles addObject:[safeFilter objectForKey:@"title"]];
        }
    }

    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Chat folders: update %@ raw=%lu parsed=%lu titles=%@.",
                                   typeObject,
                                   (unsigned long)[(NSArray *)filterObjects count],
                                   (unsigned long)[filters count],
                                   [titles componentsJoinedByString:@", "]]];
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

        id messageID = [message objectForKey:@"id"];
        if ([messageID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
        }

        NSNumber *threadID = [self messageThreadIDFromMessageObject:message];
        if ([threadID respondsToSelector:@selector(longLongValue)] && [threadID longLongValue] > 0) {
            [summary setObject:[NSNumber numberWithLongLong:[threadID longLongValue]] forKey:@"message_thread_id"];
        }

        id date = [message objectForKey:@"date"];
        if ([date respondsToSelector:@selector(integerValue)]) {
            [summary setObject:[NSNumber numberWithInteger:[date integerValue]] forKey:@"date"];
        }

        id isOutgoing = [message objectForKey:@"is_outgoing"];
        NSString *direction = ([isOutgoing respondsToSelector:@selector(boolValue)] && [isOutgoing boolValue]) ? @"Outgoing" : @"Incoming";
        [summary setObject:direction forKey:@"direction"];

        id contentObject = [message objectForKey:@"content"];
        if ([contentObject isKindOfClass:[NSDictionary class]]) {
            NSString *preview = [self messageContentPreviewForObject:(NSDictionary *)contentObject];
            if ([preview length] > 0) {
                [summary setObject:[self singleLineTrimmedString:preview maximumLength:96] forKey:@"preview"];
            }
        }

        return summary;
    }

    if ([type isEqualToString:@"updateChatAction"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"chat_action" forKey:@"kind"];
        id chatID = [dictionary objectForKey:@"chat_id"];
        if ([chatID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        }
        id threadID = [dictionary objectForKey:@"message_thread_id"];
        if ([threadID respondsToSelector:@selector(longLongValue)] && [threadID longLongValue] > 0) {
            [summary setObject:[NSNumber numberWithLongLong:[threadID longLongValue]] forKey:@"message_thread_id"];
        }
        id senderObject = [dictionary objectForKey:@"sender_id"];
        if ([senderObject isKindOfClass:[NSDictionary class]]) {
            id senderType = [(NSDictionary *)senderObject objectForKey:@"@type"];
            id senderID = [(NSDictionary *)senderObject objectForKey:@"user_id"];
            if (![senderID respondsToSelector:@selector(longLongValue)]) {
                senderID = [(NSDictionary *)senderObject objectForKey:@"chat_id"];
            }
            if ([senderType isKindOfClass:[NSString class]]) {
                [summary setObject:senderType forKey:@"sender_type"];
            }
            if ([senderID respondsToSelector:@selector(longLongValue)]) {
                [summary setObject:[NSNumber numberWithLongLong:[senderID longLongValue]] forKey:@"sender_id"];
            }
        }
        id actionObject = [dictionary objectForKey:@"action"];
        NSString *actionType = nil;
        if ([actionObject isKindOfClass:[NSDictionary class]]) {
            id actionTypeObject = [(NSDictionary *)actionObject objectForKey:@"@type"];
            if ([actionTypeObject isKindOfClass:[NSString class]]) {
                actionType = (NSString *)actionTypeObject;
            }
        }
        if ([actionType length] == 0) {
            actionType = @"chatActionCancel";
        }
        [summary setObject:actionType forKey:@"action_type"];
        [summary setObject:[NSNumber numberWithBool:![actionType isEqualToString:@"chatActionCancel"]] forKey:@"active"];
        return summary;
    }

    if ([type isEqualToString:@"updateChatFilters"] || [type isEqualToString:@"updateChatFolders"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"chat_filters" forKey:@"kind"];
        id filterObjects = [dictionary objectForKey:[type isEqualToString:@"updateChatFolders"] ? @"chat_folders" : @"chat_filters"];
        if ([filterObjects isKindOfClass:[NSArray class]]) {
            [summary setObject:[NSNumber numberWithUnsignedInteger:[(NSArray *)filterObjects count]] forKey:@"count"];
        }
        return summary;
    }

    if ([type isEqualToString:@"updateChatDraftMessage"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"draft_update" forKey:@"kind"];
        id chatID = [dictionary objectForKey:@"chat_id"];
        if ([chatID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        }
        id messageThreadID = [dictionary objectForKey:@"message_thread_id"];
        if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
            [summary setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        }

        id draftObject = [dictionary objectForKey:@"draft_message"];
        NSString *text = nil;
        if ([draftObject isKindOfClass:[NSDictionary class]]) {
            id inputMessageText = [(NSDictionary *)draftObject objectForKey:@"input_message_text"];
            if ([inputMessageText isKindOfClass:[NSDictionary class]]) {
                id formattedText = [(NSDictionary *)inputMessageText objectForKey:@"text"];
                if ([formattedText isKindOfClass:[NSDictionary class]]) {
                    id textObject = [(NSDictionary *)formattedText objectForKey:@"text"];
                    if ([textObject isKindOfClass:[NSString class]]) {
                        text = (NSString *)textObject;
                    }
                }
            }
            id replyToObject = [(NSDictionary *)draftObject objectForKey:@"reply_to"];
            if ([replyToObject isKindOfClass:[NSDictionary class]]) {
                id replyMessageID = [(NSDictionary *)replyToObject objectForKey:@"message_id"];
                if ([replyMessageID respondsToSelector:@selector(longLongValue)] && [replyMessageID longLongValue] > 0) {
                    [summary setObject:[NSNumber numberWithLongLong:[replyMessageID longLongValue]] forKey:@"reply_to_message_id"];
                }
            }
        }
        if ([text length] > 0) {
            [summary setObject:text forKey:@"text"];
            [summary setObject:[NSNumber numberWithBool:YES] forKey:@"has_draft"];
        } else {
            [summary setObject:@"" forKey:@"text"];
            [summary setObject:[NSNumber numberWithBool:NO] forKey:@"has_draft"];
        }
        return summary;
    }

    if ([type isEqualToString:@"updateMessageIsPinned"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"pinned_message_update" forKey:@"kind"];
        [summary setObject:type forKey:@"type"];
        id chatID = [dictionary objectForKey:@"chat_id"];
        if ([chatID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        }
        id messageID = [dictionary objectForKey:@"message_id"];
        if ([messageID respondsToSelector:@selector(longLongValue)]) {
            [summary setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
        }
        id isPinned = [dictionary objectForKey:@"is_pinned"];
        if ([isPinned respondsToSelector:@selector(boolValue)]) {
            [summary setObject:[NSNumber numberWithBool:[isPinned boolValue]] forKey:@"is_pinned"];
        }
        return summary;
    }

    if ([type isEqualToString:@"updateUnreadMessageCount"]) {
        id chatListObject = [dictionary objectForKey:@"chat_list"];
        NSString *chatListType = [chatListObject isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)chatListObject objectForKey:@"@type"] : nil;
        if ([chatListType length] == 0 || [chatListType isEqualToString:@"chatListMain"]) {
            id unreadValue = [dictionary objectForKey:@"unread_unmuted_count"];
            if (![unreadValue respondsToSelector:@selector(unsignedIntegerValue)]) {
                unreadValue = [dictionary objectForKey:@"unread_count"];
            }
            if ([unreadValue respondsToSelector:@selector(unsignedIntegerValue)]) {
                return [NSDictionary dictionaryWithObjectsAndKeys:
                        @"account_unread", @"kind",
                        [NSNumber numberWithUnsignedInteger:[unreadValue unsignedIntegerValue]], @"count",
                        nil];
            }
        }
    }

    if ([type isEqualToString:@"updatePoll"]) {
        NSMutableDictionary *summary = [NSMutableDictionary dictionary];
        [summary setObject:@"poll_update" forKey:@"kind"];
        [summary setObject:type forKey:@"type"];
        id pollObject = [dictionary objectForKey:@"poll"];
        if ([pollObject isKindOfClass:[NSDictionary class]]) {
            id pollID = [(NSDictionary *)pollObject objectForKey:@"id"];
            if ([pollID respondsToSelector:@selector(longLongValue)]) {
                [summary setObject:[NSNumber numberWithLongLong:[pollID longLongValue]] forKey:@"poll_id"];
            }
            id total = [(NSDictionary *)pollObject objectForKey:@"total_voter_count"];
            if ([total respondsToSelector:@selector(integerValue)]) {
                [summary setObject:[NSNumber numberWithInteger:[total integerValue]] forKey:@"total_voter_count"];
            }
        }
        return summary;
    }

    if ([type isEqualToString:@"updateMessageSendSucceeded"] || [type isEqualToString:@"updateMessageSendFailed"]) {
        id messageObject = [dictionary objectForKey:@"message"];
        if ([messageObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *message = (NSDictionary *)messageObject;
            id chatID = [message objectForKey:@"chat_id"];
            if ([chatID respondsToSelector:@selector(longLongValue)]) {
                NSMutableDictionary *summary = [NSMutableDictionary dictionary];
                [summary setObject:@"message_update" forKey:@"kind"];
                [summary setObject:type forKey:@"type"];
                [summary setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
                id messageID = [message objectForKey:@"id"];
                if ([messageID respondsToSelector:@selector(longLongValue)]) {
                    [summary setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
                }
                id oldMessageID = [dictionary objectForKey:@"old_message_id"];
                if ([oldMessageID respondsToSelector:@selector(longLongValue)]) {
                    [summary setObject:[NSNumber numberWithLongLong:[oldMessageID longLongValue]] forKey:@"old_message_id"];
                }
                id messageThreadID = [message objectForKey:@"message_thread_id"];
                if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
                    [summary setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
                }
                return summary;
            }
        }
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
        _chatFilterFallbackProbeFinished = NO;
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
    if (chatFilterInfos) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:chatFilterInfos forKey:@"chatFilterInfos"];
        [[NSNotificationCenter defaultCenter] postNotificationName:TGTDLibChatFiltersDidChangeNotification object:self userInfo:userInfo];
    }
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

- (NSDictionary *)tdLibConfigurationAtPath:(NSString *)configPath label:(NSString *)label error:(NSError **)error {
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configPath];
    if (![configuration isKindOfClass:[NSDictionary class]]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"%@ TDLib config was not found or is not a plist dictionary: %@", label, configPath];
            *error = [self errorWithDescription:message code:12];
        }
        return nil;
    }

    return configuration;
}

- (NSString *)remoteTDLibConfigurationURLString {
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *environmentURL = [environment objectForKey:TGTDLibRemoteConfigurationURLEnvironmentKey];
    if ([environmentURL isKindOfClass:[NSString class]] && [[environmentURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0) {
        return [environmentURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    NSString *bundleURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:TGTDLibRemoteConfigurationURLInfoKey];
    if ([bundleURL isKindOfClass:[NSString class]] && [[bundleURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0) {
        return [bundleURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    NSError *supportError = nil;
    NSString *supportPath = [self applicationSupportPathWithError:&supportError];
    if ([supportPath length] == 0) {
        return nil;
    }
    NSString *overridePath = [supportPath stringByAppendingPathComponent:@"remote-tdlib-config-url.txt"];
    NSString *overrideURL = [NSString stringWithContentsOfFile:overridePath encoding:NSUTF8StringEncoding error:NULL];
    overrideURL = [overrideURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return ([overrideURL length] > 0) ? overrideURL : nil;
}

- (NSDictionary *)sanitizedTDLibConfigurationFromRemoteDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Remote TDLib config response is not a dictionary." code:61];
        }
        return nil;
    }

    NSMutableDictionary *configuration = [NSMutableDictionary dictionary];
    NSArray *allowedKeys = [NSArray arrayWithObjects:
                            @"api_id",
                            @"api_hash",
                            @"tdlib_parameters_schema",
                            @"use_test_dc",
                            @"use_file_database",
                            @"use_chat_info_database",
                            @"use_message_database",
                            @"use_secret_chats",
                            @"enable_storage_optimizer",
                            @"ignore_file_names",
                            nil];
    NSUInteger index = 0;
    for (index = 0; index < [allowedKeys count]; index++) {
        NSString *key = [allowedKeys objectAtIndex:index];
        id value = [dictionary objectForKey:key];
        if (value) {
            [configuration setObject:value forKey:key];
        }
    }

    if (![self configurationContainsValidAPICredentials:configuration]) {
        if (error) {
            *error = [self errorWithDescription:@"Remote TDLib config is missing valid app credentials." code:62];
        }
        return nil;
    }

    return configuration;
}

- (NSDictionary *)downloadRemoteTDLibConfigurationWithError:(NSError **)error {
    NSString *urlString = [self remoteTDLibConfigurationURLString];
    if ([urlString length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Remote TDLib config URL is not configured." code:60];
        }
        [[TGLogger sharedLogger] log:@"Remote TDLib config URL is not configured."];
        return nil;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url || ![[[url scheme] lowercaseString] isEqualToString:@"https"]) {
        if (error) {
            *error = [self errorWithDescription:@"Remote TDLib config URL must be a valid HTTPS URL." code:60];
        }
        [[TGLogger sharedLogger] log:@"Remote TDLib config URL is invalid."];
        return nil;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:TGTDLibRemoteConfigurationTimeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:@"application/json, application/x-plist" forHTTPHeaderField:@"Accept"];
    [request setValue:[self applicationVersionString] forHTTPHeaderField:@"X-Telegraphica-Version"];

    NSURLResponse *response = nil;
    NSError *requestError = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    if ([data length] == 0 || requestError) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Remote TDLib config download failed: %@", [requestError localizedDescription] ? [requestError localizedDescription] : @"empty response"];
            *error = [self errorWithDescription:message code:63];
        }
        [[TGLogger sharedLogger] log:@"Remote TDLib config download failed."];
        return nil;
    }

    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode < 200 || statusCode >= 300) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Remote TDLib config server returned HTTP %ld.", (long)statusCode];
                *error = [self errorWithDescription:message code:63];
            }
            [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Remote TDLib config HTTP status: %ld", (long)statusCode]];
            return nil;
        }
    }

    id object = nil;
    NSError *jsonError = nil;
    object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!object) {
        NSError *plistError = nil;
        object = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&plistError];
        if (!object) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"Remote TDLib config response could not be parsed: %@", [jsonError localizedDescription] ? [jsonError localizedDescription] : [plistError localizedDescription]];
                *error = [self errorWithDescription:message code:64];
            }
            [[TGLogger sharedLogger] log:@"Remote TDLib config parse failed."];
            return nil;
        }
    }

    NSDictionary *configuration = [self sanitizedTDLibConfigurationFromRemoteDictionary:object error:error];
    if (!configuration) {
        [[TGLogger sharedLogger] log:@"Remote TDLib config validation failed."];
        return nil;
    }

    [[TGLogger sharedLogger] log:@"Remote TDLib config downloaded and validated."];
    return configuration;
}

- (NSDictionary *)downloadAndStoreRemoteTDLibConfigurationWithLocalPath:(NSString *)configPath error:(NSError **)error {
    NSDictionary *configuration = [self downloadRemoteTDLibConfigurationWithError:error];
    if (!configuration) {
        return nil;
    }

    NSString *parentPath = [configPath stringByDeletingLastPathComponent];
    NSError *directoryError = nil;
    if (![self ensureDirectoryAtPath:parentPath error:&directoryError]) {
        if (error) {
            *error = directoryError;
        }
        return nil;
    }

    if (![configuration writeToFile:configPath atomically:YES]) {
        if (error) {
            *error = [self errorWithDescription:@"Remote TDLib config was downloaded but could not be saved locally." code:65];
        }
        [[TGLogger sharedLogger] log:@"Remote TDLib config save failed."];
        return nil;
    }

    [[TGLogger sharedLogger] log:@"Remote TDLib config saved locally."];
    return configuration;
}

- (BOOL)configurationContainsValidAPICredentials:(NSDictionary *)configuration {
    if (![configuration isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id apiIDValue = [configuration objectForKey:@"api_id"];
    NSInteger apiID = [apiIDValue respondsToSelector:@selector(integerValue)] ? [apiIDValue integerValue] : 0;
    id apiHashValue = [configuration objectForKey:@"api_hash"];
    if (apiID <= 0 || ![apiHashValue isKindOfClass:[NSString class]]) {
        return NO;
    }

    NSString *apiHash = [(NSString *)apiHashValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSCharacterSet *nonHexadecimalCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    return [apiHash length] == 32 && [apiHash rangeOfCharacterFromSet:nonHexadecimalCharacters].location == NSNotFound;
}

- (NSDictionary *)localTDLibConfigurationWithError:(NSError **)error {
    NSString *configPath = [self localTDLibConfigurationPathWithError:error];
    if (!configPath) {
        return nil;
    }

    NSDictionary *configuration = [self tdLibConfigurationAtPath:configPath label:@"Local" error:NULL];
    if ([self configurationContainsValidAPICredentials:configuration]) {
        return configuration;
    }

    NSDictionary *bundledConfiguration = TGTDLibRuntimeBundledConfiguration();
    if ([self configurationContainsValidAPICredentials:bundledConfiguration]) {
        return bundledConfiguration;
    }

    NSError *remoteError = nil;
    NSDictionary *remoteConfiguration = [self downloadAndStoreRemoteTDLibConfigurationWithLocalPath:configPath error:&remoteError];
    if ([self configurationContainsValidAPICredentials:remoteConfiguration]) {
        return remoteConfiguration;
    }

    if (error) {
        NSString *remoteMessage = [remoteError localizedDescription];
        NSString *message = [NSString stringWithFormat:@"TDLib config was not found locally, in the app runtime configuration, or from remote bootstrap. Local path: %@%@%@",
                             configPath,
                             [remoteMessage length] > 0 ? @"; remote: " : @"",
                             [remoteMessage length] > 0 ? remoteMessage : @""];
        *error = [self errorWithDescription:message code:12];
    }
    return nil;
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

- (NSData *)databaseEncryptionKeyDataFromKeychainWithError:(NSError **)error {
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
            OSStatus keychainStatus = [keychain lastStatus];
            *error = [self errorWithDescription:[NSString stringWithFormat:@"Could not store TDLib database encryption key in Keychain (OSStatus %ld).", (long)keychainStatus] code:19];
        }
        return nil;
    }

    return keyData;
}

- (NSData *)databaseEncryptionKeyDataWithError:(NSError **)error {
    if ([NSThread isMainThread]) {
        return [self databaseEncryptionKeyDataFromKeychainWithError:error];
    }

    __block NSData *result = nil;
    __block NSError *mainThreadError = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSData *keyData = [self databaseEncryptionKeyDataFromKeychainWithError:&mainThreadError];
#if __has_feature(objc_arc)
        result = keyData;
#else
        result = [keyData retain];
#endif
    });

    if (!result && error) {
        *error = mainThreadError;
    }
#if __has_feature(objc_arc)
    return result;
#else
    return [result autorelease];
#endif
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
        return authorizationState;
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

- (NSDictionary *)chatPositionFromChatObject:(NSDictionary *)chatObject chatListType:(NSString *)chatListType filterID:(NSNumber *)filterID {
    if (![chatObject isKindOfClass:[NSDictionary class]] || [chatListType length] == 0) {
        return nil;
    }

    id positionsObject = [chatObject objectForKey:@"positions"];
    if (![positionsObject isKindOfClass:[NSArray class]]) {
        return nil;
    }

    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)positionsObject count]; index++) {
        id positionObject = [(NSArray *)positionsObject objectAtIndex:index];
        if (![positionObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *position = (NSDictionary *)positionObject;
        id listObject = [position objectForKey:@"list"];
        if (![listObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSDictionary *list = (NSDictionary *)listObject;
        id typeObject = [list objectForKey:@"@type"];
        if (![typeObject isKindOfClass:[NSString class]] || ![(NSString *)typeObject isEqualToString:chatListType]) {
            continue;
        }

        NSString *listIDKey = [self chatListIDKeyForType:chatListType];
        if ([listIDKey length] > 0) {
            id candidateFilterID = [list objectForKey:listIDKey];
            if (![candidateFilterID respondsToSelector:@selector(longLongValue)] ||
                ![filterID respondsToSelector:@selector(longLongValue)] ||
                [candidateFilterID longLongValue] != [filterID longLongValue]) {
                continue;
            }
        }

        return position;
    }

    return nil;
}

- (void)applyChatPositionFromChatObject:(NSDictionary *)chatObject toChatItem:(TGChatItem *)item chatListType:(NSString *)chatListType filterID:(NSNumber *)filterID {
    if (!item) {
        return;
    }

    NSDictionary *position = [self chatPositionFromChatObject:chatObject chatListType:chatListType filterID:filterID];
    id orderObject = [position objectForKey:@"order"];
    if ([orderObject respondsToSelector:@selector(longLongValue)]) {
        [item setChatListOrder:[NSNumber numberWithLongLong:[orderObject longLongValue]]];
    } else {
        [item setChatListOrder:nil];
    }

    id pinnedObject = [position objectForKey:@"is_pinned"];
    [item setPinned:([pinnedObject respondsToSelector:@selector(boolValue)] && [pinnedObject boolValue])];
}

- (TGChatItem *)chatPreviewItemFromChatObject:(NSDictionary *)chatResponse
                                  chatListType:(NSString *)chatListType
                                      filterID:(NSNumber *)filterID
                                downloadAvatar:(BOOL)downloadAvatar
                         avatarDownloadCounter:(NSUInteger *)avatarDownloadsRemaining
                                      timeout:(NSTimeInterval)timeout {
    if (![chatResponse isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id responseType = [chatResponse objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chat"]) {
        return nil;
    }

    id chatID = [chatResponse objectForKey:@"id"];
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    id titleValue = [chatResponse objectForKey:@"title"];
    NSString *title = ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) ? (NSString *)titleValue : @"Untitled";
    NSString *typeSummary = [self chatTypeSummaryForChatTypeObject:[chatResponse objectForKey:@"type"]];
    id unreadValue = [chatResponse objectForKey:@"unread_count"];
    NSNumber *unreadCount = [NSNumber numberWithInteger:0];
    if ([unreadValue respondsToSelector:@selector(integerValue)]) {
        unreadCount = [NSNumber numberWithInteger:[unreadValue integerValue]];
    }

    TGChatItem *item = [[[TGChatItem alloc] initWithChatID:[NSNumber numberWithLongLong:[chatID longLongValue]]
                                                     title:title
                                               typeSummary:typeSummary
                                               unreadCount:unreadCount] autorelease];
    [self applyChatPositionFromChatObject:chatResponse toChatItem:item chatListType:chatListType filterID:filterID];
    BOOL serverMuted = [self chatNotificationsMutedFromObject:chatResponse];
    [item setServerNotificationsMuted:serverMuted];
    [item setNotificationsMuted:serverMuted];
    id lastReadOutboxValue = [chatResponse objectForKey:@"last_read_outbox_message_id"];
    if ([lastReadOutboxValue respondsToSelector:@selector(longLongValue)]) {
        [item setLastReadOutboxMessageID:[NSNumber numberWithLongLong:[lastReadOutboxValue longLongValue]]];
    }

    BOOL shouldDownloadAvatar = downloadAvatar;
    if (avatarDownloadsRemaining && *avatarDownloadsRemaining == 0) {
        shouldDownloadAvatar = NO;
    }
    BOOL didRequestAvatarDownload = NO;
    NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[chatResponse objectForKey:@"photo"]
                                                  downloadMissing:shouldDownloadAvatar
                                                          timeout:timeout
                                               didRequestDownload:&didRequestAvatarDownload];
    if (didRequestAvatarDownload && avatarDownloadsRemaining && *avatarDownloadsRemaining > 0) {
        (*avatarDownloadsRemaining)--;
    }
    NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
    if ([avatarPath length] > 0) {
        [item setAvatarLocalPath:avatarPath];
    }

    return item;
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
        [self applyChatPositionFromChatObject:chatResponse toChatItem:item chatListType:@"chatListMain" filterID:nil];
        BOOL serverMuted = [self chatNotificationsMutedFromObject:chatResponse];
        [item setServerNotificationsMuted:serverMuted];
        [item setNotificationsMuted:serverMuted];
        id lastReadOutboxValue = [chatResponse objectForKey:@"last_read_outbox_message_id"];
        if ([lastReadOutboxValue respondsToSelector:@selector(longLongValue)]) {
            [item setLastReadOutboxMessageID:[NSNumber numberWithLongLong:[lastReadOutboxValue longLongValue]]];
        }
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

    [items sortUsingFunction:TGTDLibCompareChatItemsByPinnedOrder context:NULL];
    return items;
}

- (NSDictionary *)chatSummaryForChatID:(NSNumber *)chatID downloadAvatar:(BOOL)downloadAvatar timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:82];
        }
        return nil;
    }

    NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
    [getChatRequest setObject:@"getChat" forKey:@"@type"];
    [getChatRequest setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];

    NSTimeInterval safeTimeout = timeout;
    if (safeTimeout <= 0.0 || safeTimeout > 1.5) {
        safeTimeout = 1.5;
    }

    NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                            extraPrefix:@"telegraphica-notification-chat"
                                                                timeout:safeTimeout
                                                              errorCode:83
                                                                  error:error];
    if (!chatResponse) {
        return nil;
    }

    id responseType = [chatResponse objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chat"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChat returned an unexpected response." code:84];
        }
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    id titleValue = [chatResponse objectForKey:@"title"];
    if ([titleValue isKindOfClass:[NSString class]] && [(NSString *)titleValue length] > 0) {
        [info setObject:titleValue forKey:@"title"];
    }

    BOOL didRequestAvatarDownload = NO;
    NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[chatResponse objectForKey:@"photo"]
                                                  downloadMissing:downloadAvatar
                                                          timeout:0.9
                                               didRequestDownload:&didRequestAvatarDownload];
    NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
    if ([avatarPath length] > 0) {
        [info setObject:avatarPath forKey:@"avatar_local_path"];
    }

    if ([self chatNotificationsMutedFromObject:chatResponse]) {
        [info setObject:[NSNumber numberWithBool:YES] forKey:@"notifications_muted"];
    }

    return ([info count] > 0) ? info : nil;
}

- (NSArray *)commonGroupChatPreviewItemsForUserID:(NSNumber *)userID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![userID respondsToSelector:@selector(longLongValue)] || [userID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"User identifier is missing for common groups." code:187];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load common groups. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:188];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getGroupsInCommon" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[userID longLongValue]] forKey:@"user_id"];
    [request setObject:[NSNumber numberWithLongLong:0LL] forKey:@"offset_chat_id"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *groupsError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-common-groups"
                                                           timeout:timeout
                                                         errorCode:189
                                                             error:&groupsError];
    if (!response) {
        if (error) {
            *error = groupsError;
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id chatIDs = [response objectForKey:@"chat_ids"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib common groups returned an unexpected response." code:190];
        }
        return nil;
    }

    NSMutableArray *items = [NSMutableArray array];
    NSTimeInterval chatTimeout = timeout;
    if (chatTimeout > 1.0) {
        chatTimeout = 1.0;
    }
    NSUInteger avatarDownloadsRemaining = 10;
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)chatIDs count] && [items count] < safeLimit; index++) {
        id chatID = [(NSArray *)chatIDs objectAtIndex:index];
        if (![chatID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
        [getChatRequest setObject:@"getChat" forKey:@"@type"];
        [getChatRequest setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];

        NSError *chatError = nil;
        NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                               extraPrefix:@"telegraphica-common-group-chat"
                                                                   timeout:chatTimeout
                                                                 errorCode:191
                                                                     error:&chatError];
        TGChatItem *item = [self chatPreviewItemFromChatObject:chatResponse
                                                   chatListType:@"chatListMain"
                                                       filterID:nil
                                                 downloadAvatar:YES
                                          avatarDownloadCounter:&avatarDownloadsRemaining
                                                       timeout:0.75];
        if (item) {
            [items addObject:item];
        }
    }

    [items sortUsingFunction:TGTDLibCompareChatItemsByPinnedOrder context:NULL];
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

    NSDictionary *chatList = [self chatListObjectForChatFilterID:filterID];

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
    NSString *chatListType = [[self chatListObjectForChatFilterID:filterID] objectForKey:@"@type"];
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
        [self applyChatPositionFromChatObject:chatResponse toChatItem:item chatListType:chatListType filterID:filterID];
        BOOL serverMuted = [self chatNotificationsMutedFromObject:chatResponse];
        [item setServerNotificationsMuted:serverMuted];
        [item setNotificationsMuted:serverMuted];
        id lastReadOutboxValue = [chatResponse objectForKey:@"last_read_outbox_message_id"];
        if ([lastReadOutboxValue respondsToSelector:@selector(longLongValue)]) {
            [item setLastReadOutboxMessageID:[NSNumber numberWithLongLong:[lastReadOutboxValue longLongValue]]];
        }
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

    [items sortUsingFunction:TGTDLibCompareChatItemsByPinnedOrder context:NULL];
    return items;
}

- (NSArray *)searchChatPreviewItemsWithQuery:(NSString *)query limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to search chats. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:77];
        }
        return nil;
    }

    NSString *safeQuery = [query isKindOfClass:[NSString class]] ? [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }
    if ([safeQuery length] == 0) {
        return [self mainChatPreviewItemsWithLimit:safeLimit timeout:timeout error:error];
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchChats" forKey:@"@type"];
    [request setObject:safeQuery forKey:@"query"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *searchError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-search-chats"
                                                           timeout:timeout
                                                         errorCode:77
                                                             error:&searchError];
    if (!response) {
        NSMutableDictionary *serverRequest = [NSMutableDictionary dictionary];
        [serverRequest setObject:@"searchChatsOnServer" forKey:@"@type"];
        [serverRequest setObject:safeQuery forKey:@"query"];
        [serverRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        response = [self sendTDLibRequestAndWaitForExtra:serverRequest
                                             extraPrefix:@"telegraphica-search-chats-server"
                                                 timeout:timeout
                                               errorCode:78
                                                   error:&searchError];
    }
    if (!response) {
        if (error) {
            *error = searchError;
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id chatIDs = [response objectForKey:@"chat_ids"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"chats"] || ![chatIDs isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib chat search returned an unexpected response." code:79];
        }
        return nil;
    }

    NSMutableArray *items = [NSMutableArray array];
    NSTimeInterval chatTimeout = timeout;
    if (chatTimeout > 1.0) {
        chatTimeout = 1.0;
    }
    NSUInteger avatarDownloadsRemaining = 8;
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)chatIDs count] && [items count] < safeLimit; index++) {
        id chatID = [(NSArray *)chatIDs objectAtIndex:index];
        if (![chatID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        NSMutableDictionary *getChatRequest = [NSMutableDictionary dictionary];
        [getChatRequest setObject:@"getChat" forKey:@"@type"];
        [getChatRequest setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        NSError *chatError = nil;
        NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:getChatRequest
                                                               extraPrefix:@"telegraphica-search-get-chat"
                                                                   timeout:chatTimeout
                                                                 errorCode:80
                                                                     error:&chatError];
        TGChatItem *item = [self chatPreviewItemFromChatObject:chatResponse
                                                   chatListType:@"chatListMain"
                                                       filterID:nil
                                                 downloadAvatar:YES
                                          avatarDownloadCounter:&avatarDownloadsRemaining
                                                       timeout:0.75];
        if (item) {
            [items addObject:item];
        }
    }
    [items sortUsingFunction:TGTDLibCompareChatItemsByPinnedOrder context:NULL];
    return items;
}

- (id)publicChatPreviewItemForUsername:(NSString *)username timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to open public chat. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:193];
        }
        return nil;
    }

    NSString *safeUsername = [username isKindOfClass:[NSString class]] ? [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if ([safeUsername hasPrefix:@"@"]) {
        safeUsername = [safeUsername substringFromIndex:1];
    }
    if ([safeUsername length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Public chat username is empty." code:194];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchPublicChat" forKey:@"@type"];
    [request setObject:safeUsername forKey:@"username"];

    NSError *searchError = nil;
    NSDictionary *chatResponse = [self sendTDLibRequestAndWaitForExtra:request
                                                            extraPrefix:@"telegraphica-public-chat"
                                                                timeout:timeout
                                                              errorCode:195
                                                                  error:&searchError];
    if (!chatResponse) {
        if (error) {
            *error = searchError;
        }
        return nil;
    }

    NSUInteger avatarDownloadsRemaining = 1;
    TGChatItem *item = [self chatPreviewItemFromChatObject:chatResponse
                                               chatListType:@"chatListMain"
                                                   filterID:nil
                                             downloadAvatar:YES
                                      avatarDownloadCounter:&avatarDownloadsRemaining
                                                   timeout:1.0];
    if (!item && error) {
        *error = [self errorWithDescription:@"TDLib public chat lookup returned an unexpected response." code:196];
    }
    return item;
}

- (NSNumber *)forumTopicIDFromTopicObject:(NSDictionary *)topicObject {
    if (![topicObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id infoObject = [topicObject objectForKey:@"info"];
    NSDictionary *info = [infoObject isKindOfClass:[NSDictionary class]] ? (NSDictionary *)infoObject : topicObject;
    id topicID = [info objectForKey:@"forum_topic_id"];
    if (![topicID respondsToSelector:@selector(longLongValue)]) {
        topicID = [topicObject objectForKey:@"forum_topic_id"];
    }
    if (![topicID respondsToSelector:@selector(longLongValue)]) {
        topicID = [info objectForKey:@"message_thread_id"];
    }
    if (![topicID respondsToSelector:@selector(longLongValue)]) {
        topicID = [topicObject objectForKey:@"message_thread_id"];
    }
    if (![topicID respondsToSelector:@selector(longLongValue)] || [topicID longLongValue] <= 0) {
        return nil;
    }
    return [NSNumber numberWithLongLong:[topicID longLongValue]];
}

- (NSNumber *)messageThreadIDFromMessageObject:(NSDictionary *)messageObject {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id threadIDObject = [messageObject objectForKey:@"message_thread_id"];
    if ([threadIDObject respondsToSelector:@selector(longLongValue)] && [threadIDObject longLongValue] > 0) {
        return [NSNumber numberWithLongLong:[threadIDObject longLongValue]];
    }

    id topicObject = [messageObject objectForKey:@"topic_id"];
    if ([topicObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *topic = (NSDictionary *)topicObject;
        id topicType = [topic objectForKey:@"@type"];
        if ([topicType isKindOfClass:[NSString class]] && [(NSString *)topicType isEqualToString:@"messageTopicForum"]) {
            id forumTopicID = [topic objectForKey:@"forum_topic_id"];
            if ([forumTopicID respondsToSelector:@selector(longLongValue)] && [forumTopicID longLongValue] > 0) {
                return [NSNumber numberWithLongLong:[forumTopicID longLongValue]];
            }
        }
        if ([topicType isKindOfClass:[NSString class]] && [(NSString *)topicType isEqualToString:@"messageTopicThread"]) {
            id messageThreadID = [topic objectForKey:@"message_thread_id"];
            if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
                return [NSNumber numberWithLongLong:[messageThreadID longLongValue]];
            }
        }
    }

    return nil;
}

- (NSString *)messageTopicKindFromMessageObject:(NSDictionary *)messageObject {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id topicObject = [messageObject objectForKey:@"topic_id"];
    if ([topicObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *topic = (NSDictionary *)topicObject;
        id topicType = [topic objectForKey:@"@type"];
        if ([topicType isKindOfClass:[NSString class]] && [(NSString *)topicType isEqualToString:@"messageTopicForum"]) {
            return @"forum";
        }
        if ([topicType isKindOfClass:[NSString class]] && [(NSString *)topicType isEqualToString:@"messageTopicThread"]) {
            return @"thread";
        }
    }

    id threadIDObject = [messageObject objectForKey:@"message_thread_id"];
    if ([threadIDObject respondsToSelector:@selector(longLongValue)] && [threadIDObject longLongValue] > 0) {
        return @"thread";
    }

    return nil;
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
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_forum_topic_id"];
    [request setObject:[NSNumber numberWithInteger:safeLimit] forKey:@"limit"];

    BOOL usingLegacyForumTopicSchema = NO;
    NSError *freshSchemaError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-forum-topics"
                                                           timeout:timeout
                                                         errorCode:82
                                                             error:&freshSchemaError];
    if (!response) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest removeObjectForKey:@"offset_forum_topic_id"];
        [legacyRequest setObject:[NSNumber numberWithLongLong:0] forKey:@"offset_message_thread_id"];
        NSError *legacySchemaError = nil;
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:@"telegraphica-forum-topics-legacy"
                                                 timeout:timeout
                                               errorCode:82
                                                   error:&legacySchemaError];
        if (response) {
            usingLegacyForumTopicSchema = YES;
        }
        if (!response && error) {
            *error = legacySchemaError ? legacySchemaError : freshSchemaError;
        }
    }
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
        NSNumber *topicID = [self forumTopicIDFromTopicObject:topic];
        if (![topicID respondsToSelector:@selector(longLongValue)]) {
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
        [topicInfo setObject:[NSNumber numberWithLongLong:[topicID longLongValue]] forKey:@"message_thread_id"];
        [topicInfo setObject:[NSNumber numberWithLongLong:[topicID longLongValue]] forKey:@"forum_topic_id"];
        [topicInfo setObject:(usingLegacyForumTopicSchema ? @"forum_legacy" : @"forum") forKey:@"message_topic_kind"];
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

- (NSString *)multilineTrimmedString:(NSString *)string maximumLength:(NSUInteger)maximumLength {
    if (![string isKindOfClass:[NSString class]]) {
        return @"";
    }

    NSMutableString *mutable = [NSMutableString stringWithString:string];
    [mutable replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0, [mutable length])];
    [mutable replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0, [mutable length])];
    NSString *trimmed = [mutable stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (maximumLength > 0 && [trimmed length] > maximumLength) {
        NSString *prefix = [trimmed substringToIndex:maximumLength];
        return [prefix stringByAppendingString:@"..."];
    }
    return trimmed;
}

- (NSString *)textFromFormattedTextObject:(id)object {
    if ([object isKindOfClass:[NSString class]]) {
        return [self multilineTrimmedString:(NSString *)object maximumLength:4060];
    }
    if (![object isKindOfClass:[NSDictionary class]]) {
        return @"";
    }

    id text = [(NSDictionary *)object objectForKey:@"text"];
    if (![text isKindOfClass:[NSString class]]) {
        return @"";
    }
    return [self multilineTrimmedString:(NSString *)text maximumLength:4060];
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

- (void)addMiniThumbnailFromContainerObject:(NSDictionary *)containerObject toMediaInfo:(NSMutableDictionary *)info {
    if (![containerObject isKindOfClass:[NSDictionary class]] || ![info isKindOfClass:[NSMutableDictionary class]]) {
        return;
    }

    id miniThumbnailObject = [containerObject objectForKey:@"minithumbnail"];
    if (![miniThumbnailObject isKindOfClass:[NSDictionary class]]) {
        return;
    }

    id dataObject = [(NSDictionary *)miniThumbnailObject objectForKey:@"data"];
    if ([dataObject isKindOfClass:[NSString class]] && [(NSString *)dataObject length] > 0) {
        NSData *data = [[[NSData alloc] initWithBase64EncodedString:(NSString *)dataObject options:0] autorelease];
        if ([data length] > 0) {
            [info setObject:data forKey:@"minithumbnail_data"];
        }
    }

    id widthObject = [(NSDictionary *)miniThumbnailObject objectForKey:@"width"];
    id heightObject = [(NSDictionary *)miniThumbnailObject objectForKey:@"height"];
    if ([widthObject respondsToSelector:@selector(integerValue)] && [widthObject integerValue] > 0) {
        [info setObject:[NSNumber numberWithInteger:[widthObject integerValue]] forKey:@"minithumbnail_width"];
    }
    if ([heightObject respondsToSelector:@selector(integerValue)] && [heightObject integerValue] > 0) {
        [info setObject:[NSNumber numberWithInteger:[heightObject integerValue]] forKey:@"minithumbnail_height"];
    }
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

- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)error;
    NSDictionary *info = [self downloadedFileInfoForFileID:fileID timeout:timeout];
    NSString *path = [info objectForKey:@"local_path"];
    return ([path isKindOfClass:[NSString class]] && [path length] > 0) ? path : nil;
}

- (NSNumber *)longLongNumberFromDictionary:(NSDictionary *)dictionary key:(NSString *)key {
    id value = [dictionary objectForKey:key];
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [NSNumber numberWithLongLong:[value longLongValue]];
    }
    return [NSNumber numberWithLongLong:0];
}

- (NSDictionary *)storageUsageSummaryFromFastStatistics:(NSDictionary *)statistics {
    if (![statistics isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    long long filesSize = [[self longLongNumberFromDictionary:statistics key:@"files_size"] longLongValue];
    long long databaseSize = [[self longLongNumberFromDictionary:statistics key:@"database_size"] longLongValue];
    long long languagePackSize = [[self longLongNumberFromDictionary:statistics key:@"language_pack_database_size"] longLongValue];
    long long logSize = [[self longLongNumberFromDictionary:statistics key:@"log_size"] longLongValue];
    long long totalSize = filesSize + databaseSize + languagePackSize + logSize;

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:[NSNumber numberWithLongLong:filesSize] forKey:@"files_size"];
    [summary setObject:[NSNumber numberWithLongLong:databaseSize] forKey:@"database_size"];
    [summary setObject:[NSNumber numberWithLongLong:languagePackSize] forKey:@"language_pack_database_size"];
    [summary setObject:[NSNumber numberWithLongLong:logSize] forKey:@"log_size"];
    [summary setObject:[NSNumber numberWithLongLong:totalSize] forKey:@"total_size"];
    return summary;
}

- (NSDictionary *)storageUsageSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getStorageStatisticsFast" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-storage-fast"] forKey:@"@extra"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-storage-fast"
                                                           timeout:timeout
                                                         errorCode:72
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *summary = [self storageUsageSummaryFromFastStatistics:response];
    if (!summary && error) {
        *error = [self errorWithDescription:@"TDLib returned an invalid storage statistics response." code:72];
    }
    return summary;
}

- (NSDictionary *)clearDownloadedMediaCacheWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"optimizeStorage" forKey:@"@type"];
    [request setObject:[self uniqueExtraWithPrefix:@"telegraphica-storage-clear"] forKey:@"@extra"];
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"size"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"ttl"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"count"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"immunity_delay"];
    [request setObject:[NSArray array] forKey:@"file_types"];
    [request setObject:[NSArray array] forKey:@"chat_ids"];
    [request setObject:[NSArray array] forKey:@"exclude_chat_ids"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"return_deleted_file_statistics"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"chat_limit"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-storage-clear"
                                                           timeout:timeout
                                                         errorCode:73
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSError *refreshError = nil;
    NSDictionary *summary = [self storageUsageSummaryWithTimeout:timeout error:&refreshError];
    if (summary) {
        return summary;
    }
    return response;
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

    NSDictionary *bestDisplayDownloadedSize = nil;
    NSDictionary *bestDisplayDownloadableSize = nil;
    NSDictionary *largestSize = nil;
    NSInteger bestDisplayScore = NSIntegerMax;
    NSInteger bestDisplayDownloadableScore = NSIntegerMax;
    long long largestArea = 0;
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
        long long area = (long long)width * (long long)height;
        id fileObject = [size objectForKey:@"photo"];
        NSString *localPath = [self completedLocalPathFromFileObject:fileObject];
        NSNumber *fileID = [self fileIDFromFileObject:fileObject];
        if ([localPath length] > 0) {
            if (!bestDisplayDownloadedSize || score < bestDisplayScore) {
                bestDisplayDownloadedSize = size;
                bestDisplayScore = score;
            }
        } else if (fileID) {
            if (!bestDisplayDownloadableSize || score < bestDisplayDownloadableScore) {
                bestDisplayDownloadableSize = size;
                bestDisplayDownloadableScore = score;
            }
        }
        if (!largestSize || area > largestArea) {
            largestSize = size;
            largestArea = area;
        }
    }

    NSDictionary *displaySize = bestDisplayDownloadedSize ? bestDisplayDownloadedSize : (bestDisplayDownloadableSize ? bestDisplayDownloadableSize : largestSize);
    if (!displaySize) {
        return nil;
    }

    id widthObject = [displaySize objectForKey:@"width"];
    id heightObject = [displaySize objectForKey:@"height"];
    NSNumber *width = [widthObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[widthObject integerValue]] : nil;
    NSNumber *height = [heightObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[heightObject integerValue]] : nil;
    NSDictionary *displayInfo = [self photoInfoFromFileObject:[displaySize objectForKey:@"photo"]
                                                        width:width
                                                       height:height
                                              downloadMissing:(downloadMissing && !bestDisplayDownloadedSize)
                                                      timeout:timeout
                                           didRequestDownload:didRequestDownload];
    NSMutableDictionary *info = displayInfo ? [NSMutableDictionary dictionaryWithDictionary:displayInfo] : [NSMutableDictionary dictionary];

    id fullWidthObject = [largestSize objectForKey:@"width"];
    id fullHeightObject = [largestSize objectForKey:@"height"];
    NSNumber *fullWidth = [fullWidthObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[fullWidthObject integerValue]] : nil;
    NSNumber *fullHeight = [fullHeightObject respondsToSelector:@selector(integerValue)] ? [NSNumber numberWithInteger:[fullHeightObject integerValue]] : nil;
    id fullFileObject = [largestSize objectForKey:@"photo"];
    NSNumber *fullFileID = [self fileIDFromFileObject:fullFileObject];
    NSString *fullLocalPath = [self completedLocalPathFromFileObject:fullFileObject];
    if (fullFileID) {
        [info setObject:fullFileID forKey:@"full_file_id"];
    }
    if ([fullLocalPath length] > 0) {
        [info setObject:fullLocalPath forKey:@"full_local_path"];
        if ([[info objectForKey:@"local_path"] length] == 0) {
            [info setObject:fullLocalPath forKey:@"local_path"];
        }
    }
    if (fullWidth) {
        [info setObject:fullWidth forKey:@"full_width"];
    }
    if (fullHeight) {
        [info setObject:fullHeight forKey:@"full_height"];
    }
    return ([info count] > 0) ? info : nil;
}

- (NSDictionary *)mediaFileObjectFromContainerObject:(NSDictionary *)containerObject {
    if (![containerObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSArray *fileKeys = [NSArray arrayWithObjects:@"file", @"document", @"sticker", @"animation", @"video", @"voice", @"audio", nil];
    NSUInteger index = 0;
    for (index = 0; index < [fileKeys count]; index++) {
        id fileObject = [containerObject objectForKey:[fileKeys objectAtIndex:index]];
        if ([fileObject isKindOfClass:[NSDictionary class]]) {
            return (NSDictionary *)fileObject;
        }
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
        return @"Document";
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
        return @"GIF";
    }
    if ([mimeType hasPrefix:@"video/"]) {
        return @"Video";
    }
    if ([mimeType hasPrefix:@"image/"]) {
        return @"Image";
    }
    return @"Document";
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
    NSDictionary *mediaFile = [self mediaFileObjectFromContainerObject:container];

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
            NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:thumbnailPhotoInfo];
            NSNumber *fullFileID = [self fileIDFromFileObject:mediaFile];
            NSString *fullLocalPath = [self completedLocalPathFromFileObject:mediaFile];
            if (fullFileID) {
                [info setObject:fullFileID forKey:@"full_file_id"];
            }
            if ([fullLocalPath length] > 0) {
                [info setObject:fullLocalPath forKey:@"full_local_path"];
            }
            [self addMiniThumbnailFromContainerObject:container toMediaInfo:info];
            return info;
        }
    }

    if (mediaFile) {
        NSDictionary *fileInfo = [self photoInfoFromFileObject:mediaFile
                                                         width:width
                                                        height:height
                                               downloadMissing:downloadMissing
                                                       timeout:timeout
                                            didRequestDownload:didRequestDownload];
        if (fileInfo) {
            NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:fileInfo];
            [self addMiniThumbnailFromContainerObject:container toMediaInfo:info];
            return info;
        }
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (width) {
        [info setObject:width forKey:@"width"];
    }
    if (height) {
        [info setObject:height forKey:@"height"];
    }
    [self addMiniThumbnailFromContainerObject:container toMediaInfo:info];
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
        return [self stickerPreviewInfoFromStickerObject:[content objectForKey:@"sticker"]
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
    if ([type isEqualToString:@"messageVideoNote"]) {
        return [self visualMediaInfoFromContainerObject:[content objectForKey:@"video_note"]
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

- (NSDictionary *)playableMediaInfoFromContainerObject:(id)containerObject
                                      downloadMissing:(BOOL)downloadMissing
                                              timeout:(NSTimeInterval)timeout
                                   didRequestDownload:(BOOL *)didRequestDownload {
    if (![containerObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *container = (NSDictionary *)containerObject;
    NSDictionary *mediaFile = [self mediaFileObjectFromContainerObject:container];
    NSNumber *fileID = [self fileIDFromFileObject:mediaFile];
    NSString *localPath = [self completedLocalPathFromFileObject:mediaFile];
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

    id durationObject = [container objectForKey:@"duration"];
    if ([durationObject respondsToSelector:@selector(integerValue)]) {
        [info setObject:[NSNumber numberWithInteger:[durationObject integerValue]] forKey:@"duration"];
    }

    id mimeTypeObject = [container objectForKey:@"mime_type"];
    if ([mimeTypeObject isKindOfClass:[NSString class]] && [(NSString *)mimeTypeObject length] > 0) {
        [info setObject:mimeTypeObject forKey:@"mime_type"];
    }

    return ([info count] > 0) ? info : nil;
}

- (NSDictionary *)playableMediaInfoFromMessageContentObject:(id)contentObject
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
    if ([type isEqualToString:@"messageVoiceNote"]) {
        return [self playableMediaInfoFromContainerObject:[content objectForKey:@"voice_note"]
                                          downloadMissing:downloadMissing
                                                  timeout:timeout
                                       didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageAudio"]) {
        return [self playableMediaInfoFromContainerObject:[content objectForKey:@"audio"]
                                          downloadMissing:downloadMissing
                                                  timeout:timeout
                                       didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageVideoNote"]) {
        return [self playableMediaInfoFromContainerObject:[content objectForKey:@"video_note"]
                                          downloadMissing:downloadMissing
                                                  timeout:timeout
                                       didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageVideo"]) {
        return [self playableMediaInfoFromContainerObject:[content objectForKey:@"video"]
                                          downloadMissing:NO
                                                  timeout:timeout
                                       didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageAnimation"]) {
        return [self playableMediaInfoFromContainerObject:[content objectForKey:@"animation"]
                                          downloadMissing:downloadMissing
                                                  timeout:timeout
                                       didRequestDownload:didRequestDownload];
    }
    if ([type isEqualToString:@"messageDocument"]) {
        id documentObject = [content objectForKey:@"document"];
        if ([documentObject isKindOfClass:[NSDictionary class]]) {
            id mimeTypeObject = [(NSDictionary *)documentObject objectForKey:@"mime_type"];
            NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
            if ([mimeType hasPrefix:@"video/"] || [mimeType hasPrefix:@"audio/"]) {
                return [self playableMediaInfoFromContainerObject:documentObject
                                                  downloadMissing:NO
                                                          timeout:timeout
                                               didRequestDownload:didRequestDownload];
            }
        }
    }
    return nil;
}

- (NSDictionary *)downloadableInfoFromMessageContentObject:(id)contentObject {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *content = (NSDictionary *)contentObject;
    id typeObject = [content objectForKey:@"@type"];
    if (![typeObject isKindOfClass:[NSString class]]) {
        return nil;
    }

    NSString *type = (NSString *)typeObject;
    NSDictionary *container = nil;
    if ([type isEqualToString:@"messageDocument"]) {
        id documentObject = [content objectForKey:@"document"];
        if ([documentObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)documentObject;
        }
    } else if ([type isEqualToString:@"messagePhoto"]) {
        id photoObject = [content objectForKey:@"photo"];
        if ([photoObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *photoInfo = [self photoInfoFromPhotoSizes:[(NSDictionary *)photoObject objectForKey:@"sizes"]
                                                    downloadMissing:NO
                                                            timeout:0.0
                                                 didRequestDownload:NULL];
            if (photoInfo) {
                NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:photoInfo];
                id fileID = [photoInfo objectForKey:@"full_file_id"];
                if (fileID) {
                    [info setObject:fileID forKey:@"file_id"];
                }
                [info setObject:@"photo.jpg" forKey:@"file_name"];
                return info;
            }
        }
    } else if ([type isEqualToString:@"messageVideo"]) {
        id videoObject = [content objectForKey:@"video"];
        if ([videoObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)videoObject;
        }
    } else if ([type isEqualToString:@"messageAnimation"]) {
        id animationObject = [content objectForKey:@"animation"];
        if ([animationObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)animationObject;
        }
    } else if ([type isEqualToString:@"messageVoiceNote"]) {
        id voiceObject = [content objectForKey:@"voice_note"];
        if ([voiceObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)voiceObject;
        }
    } else if ([type isEqualToString:@"messageAudio"]) {
        id audioObject = [content objectForKey:@"audio"];
        if ([audioObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)audioObject;
        }
    } else if ([type isEqualToString:@"messageVideoNote"]) {
        id videoNoteObject = [content objectForKey:@"video_note"];
        if ([videoNoteObject isKindOfClass:[NSDictionary class]]) {
            container = (NSDictionary *)videoNoteObject;
        }
    }

    if (![container isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *mediaFile = [self mediaFileObjectFromContainerObject:container];
    NSNumber *fileID = [self fileIDFromFileObject:mediaFile];
    if (!fileID) {
        return nil;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:fileID forKey:@"file_id"];
    NSString *localPath = [self completedLocalPathFromFileObject:mediaFile];
    if ([localPath length] > 0) {
        [info setObject:localPath forKey:@"local_path"];
    }

    id fileNameObject = [container objectForKey:@"file_name"];
    if ([fileNameObject isKindOfClass:[NSString class]] && [(NSString *)fileNameObject length] > 0) {
        [info setObject:fileNameObject forKey:@"file_name"];
    }
    id mimeTypeObject = [container objectForKey:@"mime_type"];
    if ([mimeTypeObject isKindOfClass:[NSString class]] && [(NSString *)mimeTypeObject length] > 0) {
        [info setObject:mimeTypeObject forKey:@"mime_type"];
    }
    id sizeObject = [container objectForKey:@"size"];
    if (![sizeObject respondsToSelector:@selector(longLongValue)] && [mediaFile isKindOfClass:[NSDictionary class]]) {
        sizeObject = [mediaFile objectForKey:@"size"];
    }
    if ([sizeObject respondsToSelector:@selector(longLongValue)] && [sizeObject longLongValue] > 0) {
        [info setObject:[NSNumber numberWithLongLong:[sizeObject longLongValue]] forKey:@"file_size"];
    }
    return info;
}

- (BOOL)shouldAutoDownloadMessageContentObject:(id)contentObject downloadableInfo:(NSDictionary *)downloadableInfo {
    if (![contentObject isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSString *contentType = [(NSDictionary *)contentObject objectForKey:@"@type"];
    if (![contentType isKindOfClass:[NSString class]]) {
        return NO;
    }
    id fileSizeObject = [downloadableInfo objectForKey:@"file_size"];
    long long declaredBytes = [fileSizeObject respondsToSelector:@selector(longLongValue)] ? [fileSizeObject longLongValue] : 0;
    return TGResourcePolicyAllowsAutoDownloadForMessageContent(contentType, declaredBytes);
}

- (NSDictionary *)stickerPreviewInfoFromStickerObject:(id)stickerObject
                                      downloadMissing:(BOOL)downloadMissing
                                              timeout:(NSTimeInterval)timeout
                                   didRequestDownload:(BOOL *)didRequestDownload {
    if (![stickerObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *sticker = (NSDictionary *)stickerObject;
    NSDictionary *mediaInfo = [self visualMediaInfoFromContainerObject:sticker
                                                       downloadMissing:downloadMissing
                                                               timeout:timeout
                                                    didRequestDownload:didRequestDownload];
    NSMutableDictionary *info = mediaInfo ? [NSMutableDictionary dictionaryWithDictionary:mediaInfo] : [NSMutableDictionary dictionary];
    NSDictionary *stickerFile = [self mediaFileObjectFromContainerObject:sticker];
    NSNumber *fileID = [self fileIDFromFileObject:stickerFile];
    NSDictionary *formatObject = [[sticker objectForKey:@"format"] isKindOfClass:[NSDictionary class]] ? [sticker objectForKey:@"format"] : nil;
    NSString *formatType = [[formatObject objectForKey:@"@type"] isKindOfClass:[NSString class]] ? [formatObject objectForKey:@"@type"] : @"";
    if ([formatType length] == 0) {
        id isAnimatedObject = [sticker objectForKey:@"is_animated"];
        id isVideoObject = [sticker objectForKey:@"is_video"];
        if ([isVideoObject respondsToSelector:@selector(boolValue)] && [isVideoObject boolValue]) {
            formatType = @"stickerFormatWebm";
        } else if ([isAnimatedObject respondsToSelector:@selector(boolValue)] && [isAnimatedObject boolValue]) {
            formatType = @"stickerFormatTgs";
        } else {
            formatType = @"stickerFormatWebp";
        }
    }
    if ([formatType length] > 0) {
        [info setObject:formatType forKey:@"sticker_format"];
    }
    if (fileID) {
        [info setObject:fileID forKey:@"file_id"];
        [info setObject:fileID forKey:@"full_file_id"];
    }

    NSString *fullLocalPath = [self completedLocalPathFromFileObject:stickerFile];
    BOOL shouldDownloadFullSticker = ([formatType isEqualToString:@"stickerFormatWebp"] ||
                                      [formatType isEqualToString:@"stickerFormatTgs"] ||
                                      [formatType isEqualToString:@"stickerFormatWebm"]);
    if (shouldDownloadFullSticker &&
        [fullLocalPath length] == 0 && downloadMissing && fileID) {
        if (didRequestDownload) {
            *didRequestDownload = YES;
        }
        NSDictionary *downloadedInfo = [self downloadedFileInfoForFileID:fileID timeout:timeout];
        fullLocalPath = [downloadedInfo objectForKey:@"local_path"];
    }
    if ([fullLocalPath length] > 0) {
        [info setObject:fullLocalPath forKey:@"full_local_path"];
        if ([formatType isEqualToString:@"stickerFormatWebm"]) {
            [info setObject:fullLocalPath forKey:@"playable_local_path"];
        }
        if ([formatType isEqualToString:@"stickerFormatWebp"] ||
            [[info objectForKey:@"local_path"] length] == 0) {
            [info setObject:fullLocalPath forKey:@"local_path"];
        }
    }

    /* TODO: Add a Mavericks-compatible WEBM/VP9 renderer if AVFoundation cannot play a given video sticker. */
    id emojiObject = [sticker objectForKey:@"emoji"];
    if ([emojiObject isKindOfClass:[NSString class]] && [(NSString *)emojiObject length] > 0) {
        [info setObject:emojiObject forKey:@"emoji"];
        [info setObject:[NSString stringWithFormat:@"Sticker %@", emojiObject] forKey:@"label"];
    }
    [info setObject:@"messageSticker" forKey:@"content_type"];
    NSString *placeholder = ([emojiObject isKindOfClass:[NSString class]] && [(NSString *)emojiObject length] > 0) ? (NSString *)emojiObject : @"Sticker";
    [info setObject:placeholder forKey:@"placeholder"];
    return ([info count] > 0) ? info : nil;
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

- (NSDictionary *)userSenderSummaryForUserID:(NSNumber *)userID timeout:(NSTimeInterval)timeout {
    if (![userID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getUser" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[userID longLongValue]] forKey:@"user_id"];

    NSDictionary *userResponse = [self sendTDLibRequestAndWaitForExtra:request
                                                           extraPrefix:@"telegraphica-message-sender-user"
                                                               timeout:timeout
                                                             errorCode:86
                                                                 error:NULL];
    id userType = [userResponse objectForKey:@"@type"];
    if (![userType isKindOfClass:[NSString class]] || ![(NSString *)userType isEqualToString:@"user"]) {
        return nil;
    }

    id firstName = [userResponse objectForKey:@"first_name"];
    id lastName = [userResponse objectForKey:@"last_name"];
    id username = [userResponse objectForKey:@"username"];
    NSMutableArray *nameParts = [NSMutableArray array];
    if ([firstName isKindOfClass:[NSString class]] && [(NSString *)firstName length] > 0) {
        [nameParts addObject:firstName];
    }
    if ([lastName isKindOfClass:[NSString class]] && [(NSString *)lastName length] > 0) {
        [nameParts addObject:lastName];
    }

    NSString *displayName = ([nameParts count] > 0) ? [nameParts componentsJoinedByString:@" "] : nil;
    if ([displayName length] == 0 && [username isKindOfClass:[NSString class]] && [(NSString *)username length] > 0) {
        displayName = [NSString stringWithFormat:@"@%@", username];
    }
    if ([displayName length] == 0) {
        displayName = [NSString stringWithFormat:@"User %lld", [userID longLongValue]];
    }

    NSMutableDictionary *summary = [NSMutableDictionary dictionary];
    [summary setObject:userID forKey:@"sender_id"];
    [summary setObject:@"messageSenderUser" forKey:@"sender_type"];
    [summary setObject:[self singleLineTrimmedString:displayName maximumLength:80] forKey:@"display_name"];

    BOOL didRequestAvatarDownload = NO;
    NSDictionary *avatarInfo = [self photoInfoFromChatPhotoObject:[userResponse objectForKey:@"profile_photo"]
                                                  downloadMissing:YES
                                                          timeout:0.7
                                               didRequestDownload:&didRequestAvatarDownload];
    NSString *avatarPath = [avatarInfo objectForKey:@"local_path"];
    if ([avatarPath length] > 0) {
        [summary setObject:avatarPath forKey:@"avatar_local_path"];
    }
    return summary;
}

- (NSDictionary *)senderSummaryFromMessageObject:(NSDictionary *)messageObject timeout:(NSTimeInterval)timeout {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id senderObject = [messageObject objectForKey:@"sender_id"];
    if (![senderObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *senderType = [(NSDictionary *)senderObject objectForKey:@"@type"];
    id senderIDObject = nil;
    if ([senderType isEqualToString:@"messageSenderUser"]) {
        senderIDObject = [(NSDictionary *)senderObject objectForKey:@"user_id"];
    } else if ([senderType isEqualToString:@"messageSenderChat"]) {
        senderIDObject = [(NSDictionary *)senderObject objectForKey:@"chat_id"];
    }
    if (![senderType isKindOfClass:[NSString class]] || ![senderIDObject respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    NSNumber *senderID = [NSNumber numberWithLongLong:[senderIDObject longLongValue]];
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%lld", senderType, [senderID longLongValue]];
    @synchronized (self) {
        NSDictionary *cached = [_senderSummaryCache objectForKey:cacheKey];
        if (cached) {
            return cached;
        }
    }

    NSDictionary *summary = nil;
    NSTimeInterval safeTimeout = timeout;
    if (safeTimeout <= 0.0 || safeTimeout > 1.0) {
        safeTimeout = 1.0;
    }
    if ([senderType isEqualToString:@"messageSenderUser"]) {
        summary = [self userSenderSummaryForUserID:senderID timeout:safeTimeout];
    } else if ([senderType isEqualToString:@"messageSenderChat"]) {
        NSError *chatError = nil;
        summary = [self chatSummaryForChatID:senderID downloadAvatar:YES timeout:safeTimeout error:&chatError];
        if (summary) {
            NSMutableDictionary *chatSummary = [NSMutableDictionary dictionaryWithDictionary:summary];
            NSString *title = [chatSummary objectForKey:@"title"];
            if ([title length] > 0) {
                [chatSummary setObject:title forKey:@"display_name"];
            }
            [chatSummary setObject:senderID forKey:@"sender_id"];
            [chatSummary setObject:senderType forKey:@"sender_type"];
            summary = chatSummary;
        }
    }

    if ([summary count] == 0) {
        return nil;
    }
    NSDictionary *summaryCopy = [[summary copy] autorelease];
    @synchronized (self) {
        [_senderSummaryCache setObject:summaryCopy forKey:cacheKey];
    }
    return summaryCopy;
}

- (NSNumber *)replyMessageIDFromMessageObject:(NSDictionary *)messageObject {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id directReplyID = [messageObject objectForKey:@"reply_to_message_id"];
    if ([directReplyID respondsToSelector:@selector(longLongValue)] && [directReplyID longLongValue] > 0) {
        return [NSNumber numberWithLongLong:[directReplyID longLongValue]];
    }

    id replyObject = [messageObject objectForKey:@"reply_to"];
    if ([replyObject isKindOfClass:[NSDictionary class]]) {
        id nestedReplyID = [(NSDictionary *)replyObject objectForKey:@"message_id"];
        if ([nestedReplyID respondsToSelector:@selector(longLongValue)] && [nestedReplyID longLongValue] > 0) {
            return [NSNumber numberWithLongLong:[nestedReplyID longLongValue]];
        }
    }
    return nil;
}

- (NSString *)replyPreviewFromMessageObject:(NSDictionary *)messageObject {
    id replyObject = [messageObject objectForKey:@"reply_to"];
    if (![replyObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id quoteObject = [(NSDictionary *)replyObject objectForKey:@"quote"];
    if ([quoteObject isKindOfClass:[NSDictionary class]]) {
        NSString *quoteText = [self textFromFormattedTextObject:[(NSDictionary *)quoteObject objectForKey:@"text"]];
        if ([quoteText length] > 0) {
            return [self singleLineTrimmedString:quoteText maximumLength:96];
        }
    }
    id originObject = [(NSDictionary *)replyObject objectForKey:@"origin"];
    if ([originObject isKindOfClass:[NSDictionary class]]) {
        id originType = [(NSDictionary *)originObject objectForKey:@"@type"];
        if ([originType isKindOfClass:[NSString class]]) {
            return @"Reply";
        }
    }
    return nil;
}

- (NSDictionary *)replyContextForMessageObject:(NSDictionary *)messageObject chatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout {
    NSNumber *replyMessageID = [self replyMessageIDFromMessageObject:messageObject];
    if (![replyMessageID respondsToSelector:@selector(longLongValue)] || [replyMessageID longLongValue] <= 0) {
        return nil;
    }

    NSNumber *targetChatID = chatID;
    id rawChatID = [messageObject objectForKey:@"chat_id"];
    if (![targetChatID respondsToSelector:@selector(longLongValue)] && [rawChatID respondsToSelector:@selector(longLongValue)]) {
        targetChatID = [NSNumber numberWithLongLong:[rawChatID longLongValue]];
    }
    if (![targetChatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getMessage" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[targetChatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithLongLong:[replyMessageID longLongValue]] forKey:@"message_id"];

    NSError *error = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-get-reply-message"
                                                           timeout:timeout
                                                         errorCode:96
                                                             error:&error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        return nil;
    }

    NSString *preview = [self messageContentPreviewForObject:[response objectForKey:@"content"]];
    preview = [self singleLineTrimmedString:preview maximumLength:96];
    if (TGPreviewLooksLikePlainMediaLabel(preview)) {
        preview = nil;
    }
    NSDictionary *senderSummary = [self senderSummaryFromMessageObject:response timeout:0.4];
    NSString *senderName = [senderSummary objectForKey:@"display_name"];

    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    if ([preview length] > 0) {
        [context setObject:preview forKey:@"preview"];
    }
    if ([senderName length] > 0) {
        [context setObject:senderName forKey:@"sender_name"];
    }
    return ([context count] > 0) ? context : nil;
}

- (NSString *)forwardSourceDisplayNameFromMessageObject:(NSDictionary *)messageObject timeout:(NSTimeInterval)timeout {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id forwardInfo = [messageObject objectForKey:@"forward_info"];
    id originObject = nil;
    if ([forwardInfo isKindOfClass:[NSDictionary class]]) {
        originObject = [(NSDictionary *)forwardInfo objectForKey:@"origin"];
    }
    if (![originObject isKindOfClass:[NSDictionary class]]) {
        originObject = [messageObject objectForKey:@"forward_origin"];
    }
    if (![originObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSString *originType = [(NSDictionary *)originObject objectForKey:@"@type"];
    id senderUserID = [(NSDictionary *)originObject objectForKey:@"sender_user_id"];
    if ([senderUserID respondsToSelector:@selector(longLongValue)]) {
        NSDictionary *summary = [self userSenderSummaryForUserID:[NSNumber numberWithLongLong:[senderUserID longLongValue]]
                                                         timeout:timeout];
        NSString *displayName = [summary objectForKey:@"display_name"];
        if ([displayName length] > 0) {
            return displayName;
        }
    }

    id senderChatID = [(NSDictionary *)originObject objectForKey:@"sender_chat_id"];
    if (![senderChatID respondsToSelector:@selector(longLongValue)]) {
        senderChatID = [(NSDictionary *)originObject objectForKey:@"chat_id"];
    }
    if ([senderChatID respondsToSelector:@selector(longLongValue)]) {
        NSError *chatError = nil;
        NSDictionary *summary = [self chatSummaryForChatID:[NSNumber numberWithLongLong:[senderChatID longLongValue]]
                                            downloadAvatar:NO
                                                   timeout:timeout
                                                     error:&chatError];
        NSString *title = [summary objectForKey:@"title"];
        if ([title length] > 0) {
            return title;
        }
    }

    id senderName = [(NSDictionary *)originObject objectForKey:@"sender_name"];
    if ([senderName isKindOfClass:[NSString class]] && [(NSString *)senderName length] > 0) {
        return [self singleLineTrimmedString:senderName maximumLength:80];
    }
    if ([originType isKindOfClass:[NSString class]]) {
        return @"Forwarded";
    }
    return nil;
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
    if ([type isEqualToString:@"messagePoll"]) {
        NSDictionary *pollInfo = TGMessagePollInfoFromContentObject(content);
        NSString *pollPreview = TGMessagePollPreviewTextFromInfo(pollInfo);
        return ([pollPreview length] > 0) ? pollPreview : @"Poll";
    }

    NSDictionary *labels = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"Image", @"messagePhoto",
                            @"Video", @"messageVideo",
                            @"Animation", @"messageAnimation",
                            @"Document", @"messageDocument",
                            @"Audio", @"messageAudio",
                            @"Voice message", @"messageVoiceNote",
                            @"Video note", @"messageVideoNote",
                            @"Sticker", @"messageSticker",
                            @"Contact", @"messageContact",
                            @"Location", @"messageLocation",
                            @"Poll", @"messagePoll",
                            @"Call", @"messageCall",
                            @"Invoice", @"messageInvoice",
                            @"Unsupported message", @"messageUnsupported",
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
        if ([document isKindOfClass:[NSDictionary class]]) {
            if ([self isVisualDocumentObject:document]) {
                label = [self documentVisualLabelFromObject:document];
            } else {
                id fileNameObject = [document objectForKey:@"file_name"];
                if ([fileNameObject isKindOfClass:[NSString class]] && [(NSString *)fileNameObject length] > 0) {
                    label = (NSString *)fileNameObject;
                }
            }
        }
    }

    NSString *caption = [self textFromFormattedTextObject:[content objectForKey:@"caption"]];
    if ([caption length] > 0) {
        return [NSString stringWithFormat:@"%@ %@", label, caption];
    }
    return label;
}

- (NSDictionary *)reactionInfoFromMessageObject:(NSDictionary *)messageObject {
    if (![messageObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id interactionInfo = [messageObject objectForKey:@"interaction_info"];
    if (![interactionInfo isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id reactionsObject = [(NSDictionary *)interactionInfo objectForKey:@"reactions"];
    if (![reactionsObject isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    id reactions = [(NSDictionary *)reactionsObject objectForKey:@"reactions"];
    if (![reactions isKindOfClass:[NSArray class]] || [(NSArray *)reactions count] == 0) {
        return nil;
    }

    NSMutableArray *parts = [NSMutableArray array];
    NSMutableArray *chosenEmojis = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)reactions count]; index++) {
        id reactionObject = [(NSArray *)reactions objectAtIndex:index];
        if (![reactionObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *reaction = (NSDictionary *)reactionObject;
        id typeObject = [reaction objectForKey:@"type"];
        NSString *emoji = nil;
        if ([typeObject isKindOfClass:[NSDictionary class]]) {
            id reactionType = [(NSDictionary *)typeObject objectForKey:@"@type"];
            id emojiObject = [(NSDictionary *)typeObject objectForKey:@"emoji"];
            if ([reactionType isKindOfClass:[NSString class]] &&
                [(NSString *)reactionType isEqualToString:@"reactionTypeEmoji"] &&
                [emojiObject isKindOfClass:[NSString class]] &&
                [(NSString *)emojiObject length] > 0) {
                emoji = (NSString *)emojiObject;
            }
        }
        if ([emoji length] == 0) {
            continue;
        }

        NSInteger count = 1;
        id countObject = [reaction objectForKey:@"total_count"];
        if ([countObject respondsToSelector:@selector(integerValue)] && [countObject integerValue] > 0) {
            count = [countObject integerValue];
        }
        if ([parts count] < 3) {
            if (count == 1) {
                [parts addObject:emoji];
            } else {
                [parts addObject:[NSString stringWithFormat:@"%@ %ld", emoji, (long)count]];
            }
        }

        id chosenObject = [reaction objectForKey:@"is_chosen"];
        if ([chosenObject respondsToSelector:@selector(boolValue)] &&
            [chosenObject boolValue] &&
            ![chosenEmojis containsObject:emoji]) {
            [chosenEmojis addObject:emoji];
        }
    }

    if ([parts count] == 0 && [chosenEmojis count] == 0) {
        return nil;
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if ([parts count] > 0) {
        [info setObject:[parts componentsJoinedByString:@"  "] forKey:@"summary"];
    }
    if ([chosenEmojis count] > 0) {
        [info setObject:chosenEmojis forKey:@"chosen_emojis"];
    }
    return info;
}

- (BOOL)chatNotificationsMutedFromObject:(NSDictionary *)chatObject {
    if (![chatObject isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id settingsObject = [chatObject objectForKey:@"notification_settings"];
    if (![settingsObject isKindOfClass:[NSDictionary class]]) {
        return NO;
    }

    id muteFor = [(NSDictionary *)settingsObject objectForKey:@"mute_for"];
    if ([muteFor respondsToSelector:@selector(integerValue)] && [muteFor integerValue] > 0) {
        return YES;
    }

    return NO;
}

- (NSString *)syntheticMediaAlbumMessageKeyForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    return [NSString stringWithFormat:@"%lld|%lld", [chatID longLongValue], [messageID longLongValue]];
}

- (NSNumber *)syntheticMediaAlbumIDForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID {
    NSString *key = [self syntheticMediaAlbumMessageKeyForChatID:chatID messageID:messageID];
    if ([key length] == 0) {
        return nil;
    }
    id value = [_syntheticMediaAlbumIDByMessageKey objectForKey:key];
    return [value respondsToSelector:@selector(longLongValue)] ? value : nil;
}

- (void)rememberSyntheticMediaAlbumForMessages:(NSArray *)messages chatID:(NSNumber *)chatID {
    if (![messages isKindOfClass:[NSArray class]] || [messages count] < 2 || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }
    long long firstMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [messages count]; index++) {
        id message = [messages objectAtIndex:index];
        id messageID = [message isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)message objectForKey:@"id"] : nil;
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] != 0) {
            firstMessageID = [messageID longLongValue];
            break;
        }
    }
    if (firstMessageID == 0) {
        return;
    }
    NSNumber *syntheticAlbumID = [NSNumber numberWithLongLong:llabs(firstMessageID)];
    NSUInteger remembered = 0;
    for (index = 0; index < [messages count]; index++) {
        id message = [messages objectAtIndex:index];
        id messageID = [message isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)message objectForKey:@"id"] : nil;
        NSString *key = [self syntheticMediaAlbumMessageKeyForChatID:chatID messageID:messageID];
        if ([key length] == 0) {
            continue;
        }
        [_syntheticMediaAlbumIDByMessageKey setObject:syntheticAlbumID forKey:key];
        remembered++;
    }
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib media album fallback: remembered %lu message id(s) under synthetic album %@.",
                                  (unsigned long)remembered,
                                  syntheticAlbumID]];
}

- (NSArray *)messagePreviewItemsFromMessages:(NSArray *)messages chatID:(NSNumber *)chatID {
    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    NSUInteger visualMediaDownloadsRemaining = 30;
    NSUInteger playableMediaDownloadsRemaining = 12;
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

        NSNumber *safeChatID = chatID;
        id rawChatID = [message objectForKey:@"chat_id"];
        if (!safeChatID && [rawChatID respondsToSelector:@selector(longLongValue)]) {
            safeChatID = [NSNumber numberWithLongLong:[rawChatID longLongValue]];
        }

        TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:safeChatID
                                                           messageID:safeMessageID
                                                                date:safeDate
                                                            outgoing:outgoing
                                                             preview:preview] autorelease];
        [item setContentType:contentType];
        if ([contentType isEqualToString:@"messagePoll"] && [contentObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *pollInfo = TGMessagePollInfoFromContentObject(contentObject);
            if ([pollInfo count] > 0) {
                NSString *question = [pollInfo objectForKey:TGMessagePollQuestionKey];
                if ([question length] > 0) {
                    [item setPollQuestion:question];
                    [item setPreview:question];
                }
                NSArray *options = [pollInfo objectForKey:TGMessagePollOptionsKey];
                if ([options isKindOfClass:[NSArray class]]) {
                    [item setPollOptions:options];
                }
                [item setPollTotalVoterCount:[pollInfo objectForKey:TGMessagePollTotalVoterCountKey]];
                [item setPollID:[pollInfo objectForKey:TGMessagePollIDKey]];
                [item setPollClosed:[[pollInfo objectForKey:TGMessagePollClosedKey] boolValue]];
                [item setPollAnonymous:[[pollInfo objectForKey:TGMessagePollAnonymousKey] boolValue]];
                [item setPollMultipleChoice:[[pollInfo objectForKey:TGMessagePollMultipleChoiceKey] boolValue]];
                [item setPollQuiz:[[pollInfo objectForKey:TGMessagePollQuizKey] boolValue]];
            }
        }
        id pinnedObject = [message objectForKey:@"is_pinned"];
        if ([pinnedObject respondsToSelector:@selector(boolValue)]) {
            [item setPinned:[pinnedObject boolValue]];
        }
        NSNumber *replyMessageID = [self replyMessageIDFromMessageObject:message];
        if (replyMessageID) {
            [item setReplyToMessageID:replyMessageID];
            NSString *replyPreview = [self replyPreviewFromMessageObject:message];
            NSString *replySenderName = nil;
            if ([replyPreview length] == 0 || [replyPreview isEqualToString:@"Reply"]) {
                NSDictionary *replyContext = [self replyContextForMessageObject:message chatID:safeChatID timeout:0.65];
                NSString *contextPreview = [replyContext objectForKey:@"preview"];
                if ([contextPreview length] > 0) {
                    replyPreview = contextPreview;
                }
                replySenderName = [replyContext objectForKey:@"sender_name"];
            }
            if ([replySenderName length] > 0) {
                [item setReplySenderDisplayName:replySenderName];
            }
            if ([replyPreview length] == 0 || [replyPreview isEqualToString:@"Reply"]) {
                replyPreview = @"Original message";
            }
            [item setReplyPreview:replyPreview];
        }
        NSString *forwardSource = [self forwardSourceDisplayNameFromMessageObject:message timeout:0.6];
        if ([forwardSource length] > 0) {
            [item setForwardSourceDisplayName:forwardSource];
        }
        if ([contentType isEqualToString:@"messageText"] && [contentObject isKindOfClass:[NSDictionary class]]) {
            NSString *editableText = [self textFromFormattedTextObject:[(NSDictionary *)contentObject objectForKey:@"text"]];
            if ([editableText length] > 0) {
                [item setEditableText:editableText];
            }
        }
        NSDictionary *capabilities = TGTDLibMessageCapabilitiesFromObject(message);
        if (capabilities) {
            [item setCapabilitiesKnown:YES];
            [item setCanBeReplied:[[capabilities objectForKey:@"can_be_replied"] boolValue]];
            [item setCanBeEdited:[[capabilities objectForKey:@"can_be_edited"] boolValue]];
            [item setCanBeDeletedOnlyForSelf:[[capabilities objectForKey:@"can_be_deleted_only_for_self"] boolValue]];
            [item setCanBeDeletedForAllUsers:[[capabilities objectForKey:@"can_be_deleted_for_all_users"] boolValue]];
            [item setEditDate:[capabilities objectForKey:@"edit_date"]];
        }
        if (TGTDLibCanGetMessageThreadFromObject(message)) {
            [item setCanGetMessageThread:YES];
        }
        NSDictionary *interactionInfo = [message objectForKey:@"interaction_info"];
        NSDictionary *replyInfo = [interactionInfo isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)interactionInfo objectForKey:@"reply_info"] : nil;
        id replyCount = [replyInfo isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)replyInfo objectForKey:@"reply_count"] : nil;
        if ([replyCount respondsToSelector:@selector(integerValue)] && [replyCount integerValue] >= 0) {
            [item setMessageThreadReplyCount:[NSNumber numberWithInteger:[replyCount integerValue]]];
            if ([replyCount integerValue] > 0 || TGTDLibCanGetMessageThreadFromObject(message)) {
                [item setCanGetMessageThread:YES];
            }
        }
        if (!outgoing) {
            NSDictionary *senderSummary = [self senderSummaryFromMessageObject:message timeout:0.9];
            id senderID = [senderSummary objectForKey:@"sender_id"];
            if ([senderID respondsToSelector:@selector(longLongValue)]) {
                [item setSenderID:[NSNumber numberWithLongLong:[senderID longLongValue]]];
            }
            NSString *senderName = [senderSummary objectForKey:@"display_name"];
            if ([senderName length] > 0) {
                [item setSenderDisplayName:senderName];
            }
            NSString *senderAvatar = [senderSummary objectForKey:@"avatar_local_path"];
            if ([senderAvatar length] > 0) {
                [item setSenderAvatarLocalPath:senderAvatar];
            }
        }
        [item setSending:([[message objectForKey:@"sending_state"] isKindOfClass:[NSDictionary class]])];
        NSDictionary *reactionInfo = [self reactionInfoFromMessageObject:message];
        id reactionSummary = [reactionInfo objectForKey:@"summary"];
        if ([reactionSummary isKindOfClass:[NSString class]]) {
            [item setReactionSummary:reactionSummary];
        }
        id chosenReactionEmojis = [reactionInfo objectForKey:@"chosen_emojis"];
        if ([chosenReactionEmojis isKindOfClass:[NSArray class]]) {
            [item setChosenReactionEmojis:chosenReactionEmojis];
        }
        id mediaAlbumID = [message objectForKey:@"media_album_id"];
        if ([mediaAlbumID respondsToSelector:@selector(longLongValue)] && [mediaAlbumID longLongValue] > 0) {
            [item setMediaAlbumID:[NSNumber numberWithLongLong:[mediaAlbumID longLongValue]]];
        } else {
            NSNumber *syntheticAlbumID = [self syntheticMediaAlbumIDForChatID:safeChatID messageID:safeMessageID];
            if ([syntheticAlbumID respondsToSelector:@selector(longLongValue)] && [syntheticAlbumID longLongValue] > 0) {
                [item setMediaAlbumID:syntheticAlbumID];
            }
        }
        NSDictionary *downloadInfo = [self downloadableInfoFromMessageContentObject:contentObject];
        BOOL policyAllowsAutoDownload = [self shouldAutoDownloadMessageContentObject:contentObject downloadableInfo:downloadInfo];
        BOOL didRequestMediaDownload = NO;
        NSDictionary *photoInfo = [self visualMediaInfoFromMessageContentObject:contentObject
                                                                downloadMissing:(policyAllowsAutoDownload && visualMediaDownloadsRemaining > 0)
                                                                        timeout:1.5
                                                             didRequestDownload:&didRequestMediaDownload];
        if (didRequestMediaDownload && visualMediaDownloadsRemaining > 0) {
            visualMediaDownloadsRemaining--;
        }
        BOOL didRequestPlayableDownload = NO;
        NSDictionary *playableInfo = [self playableMediaInfoFromMessageContentObject:contentObject
                                                                     downloadMissing:(policyAllowsAutoDownload && playableMediaDownloadsRemaining > 0)
                                                                             timeout:1.5
                                                                  didRequestDownload:&didRequestPlayableDownload];
        if (didRequestPlayableDownload && playableMediaDownloadsRemaining > 0) {
            playableMediaDownloadsRemaining--;
        }
        NSString *mediaPath = [photoInfo objectForKey:@"local_path"];
        if ([mediaPath length] > 0) {
            [item setMediaLocalPath:mediaPath];
        }
        NSString *playablePath = [playableInfo objectForKey:@"local_path"];
        if ([playablePath length] > 0 && [mediaPath length] == 0) {
            [item setMediaLocalPath:playablePath];
        }
        [item setMediaWidth:[photoInfo objectForKey:@"width"]];
        [item setMediaHeight:[photoInfo objectForKey:@"height"]];
        NSNumber *playableFileID = [playableInfo objectForKey:@"file_id"];
        if (!playableFileID) {
            playableFileID = [photoInfo objectForKey:@"full_file_id"];
        }
        if (!playableFileID) {
            playableFileID = [photoInfo objectForKey:@"file_id"];
        }
        if (!playableFileID) {
            playableFileID = [downloadInfo objectForKey:@"file_id"];
        }
        [item setMediaFileID:playableFileID];
        [item setMediaDuration:[playableInfo objectForKey:@"duration"]];
        NSString *mimeType = [playableInfo objectForKey:@"mime_type"];
        if ([mimeType length] == 0) {
            mimeType = [downloadInfo objectForKey:@"mime_type"];
        }
        [item setMediaMimeType:mimeType];
        id fileName = [downloadInfo objectForKey:@"file_name"];
        if ([fileName isKindOfClass:[NSString class]]) {
            [item setDownloadFileName:fileName];
        }
        id fileSize = [downloadInfo objectForKey:@"file_size"];
        if ([fileSize respondsToSelector:@selector(longLongValue)]) {
            [item setDownloadFileSize:[NSNumber numberWithLongLong:[fileSize longLongValue]]];
        }
        BOOL hasDisplayablePhotoInfo = ([[photoInfo objectForKey:@"local_path"] length] > 0);
        if ([contentType isEqualToString:@"messagePhoto"] && !hasDisplayablePhotoInfo && ([preview isEqualToString:@"Image"] || [preview isEqualToString:@"[Photo]"])) {
            continue;
        }
        BOOL canKeepStickerFallback = ([contentType isEqualToString:@"messageSticker"] && [photoInfo count] > 0);
        if ([photoInfo count] > 0 && (hasDisplayablePhotoInfo || canKeepStickerFallback) && [item isVisualMediaMessage]) {
            NSMutableDictionary *mediaInfo = [NSMutableDictionary dictionaryWithDictionary:photoInfo];
            if ([contentType length] > 0) {
                [mediaInfo setObject:contentType forKey:@"content_type"];
            }
            if (playableFileID) {
                [mediaInfo setObject:playableFileID forKey:@"playable_file_id"];
            }
            if ([[playableInfo objectForKey:@"local_path"] length] > 0) {
                [mediaInfo setObject:[playableInfo objectForKey:@"local_path"] forKey:@"playable_local_path"];
            }
            if ([item mediaDuration]) {
                [mediaInfo setObject:[item mediaDuration] forKey:@"duration"];
            }
            if ([[item mediaMimeType] length] > 0) {
                [mediaInfo setObject:[item mediaMimeType] forKey:@"mime_type"];
            }
            if ([[item downloadFileName] length] > 0) {
                [mediaInfo setObject:[item downloadFileName] forKey:@"file_name"];
            }
            if ([[item downloadFileSize] respondsToSelector:@selector(longLongValue)]) {
                [mediaInfo setObject:[item downloadFileSize] forKey:@"file_size"];
            }
            if ([safeMessageID respondsToSelector:@selector(longLongValue)]) {
                [mediaInfo setObject:safeMessageID forKey:@"message_id"];
            }
            NSString *placeholder = [item visualMediaPlaceholderTitle];
            if ([placeholder length] > 0) {
                [mediaInfo setObject:placeholder forKey:@"placeholder"];
            }
            [item setMediaItems:[NSArray arrayWithObject:mediaInfo]];
        }
        [items addObject:item];
    }
    return [self messagePreviewItemsByGroupingMediaAlbums:items];
}

- (NSArray *)messagePreviewItemsByGroupingMediaAlbums:(NSArray *)items {
    if ([items count] == 0) {
        return items;
    }

    NSMutableArray *groupedItems = [NSMutableArray array];
    NSMutableDictionary *albumItemsByKey = [NSMutableDictionary dictionary];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }

        TGMessageItem *item = (TGMessageItem *)candidate;
        NSNumber *albumID = [item mediaAlbumID];
        if (![albumID respondsToSelector:@selector(longLongValue)] || [albumID longLongValue] <= 0 || ![item isVisualMediaMessage]) {
            [groupedItems addObject:item];
            continue;
        }

        long long chatValue = [[item chatID] respondsToSelector:@selector(longLongValue)] ? [[item chatID] longLongValue] : 0;
        NSString *albumKey = [NSString stringWithFormat:@"%lld|%lld|%d", chatValue, [albumID longLongValue], [item outgoing] ? 1 : 0];
        TGMessageItem *albumItem = [albumItemsByKey objectForKey:albumKey];
        if (!albumItem) {
            albumItem = [[item copy] autorelease];
            [albumItem setMediaItems:[albumItem visualMediaItems]];
            [albumItemsByKey setObject:albumItem forKey:albumKey];
            [groupedItems addObject:albumItem];
            continue;
        }

        [albumItem addVisualMediaFromMessageItem:item];
        if (TGPreviewLooksLikePlainMediaLabel([albumItem preview]) && !TGPreviewLooksLikePlainMediaLabel([item preview])) {
            [albumItem setPreview:[item preview]];
        }

        id albumMessageID = [albumItem messageID];
        id itemMessageID = [item messageID];
        if ([albumMessageID respondsToSelector:@selector(longLongValue)] &&
            [itemMessageID respondsToSelector:@selector(longLongValue)] &&
            [itemMessageID longLongValue] < [albumMessageID longLongValue]) {
            [albumItem setMessageID:[NSNumber numberWithLongLong:[itemMessageID longLongValue]]];
        }

        id albumDate = [albumItem date];
        id itemDate = [item date];
        if ([albumDate respondsToSelector:@selector(integerValue)] &&
            [itemDate respondsToSelector:@selector(integerValue)] &&
            [itemDate integerValue] < [albumDate integerValue]) {
            [albumItem setDate:[NSNumber numberWithInteger:[itemDate integerValue]]];
        }
    }

    return groupedItems;
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
        threadID = [threadInfo objectForKey:@"forum_topic_id"];
    }
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
    BOOL serverMuted = [self chatNotificationsMutedFromObject:threadInfo];
    [item setServerNotificationsMuted:serverMuted];
    [item setNotificationsMuted:serverMuted];
    [item setForumTopic:YES];
    [item setParentChatID:chatID];
    [item setMessageThreadID:[NSNumber numberWithLongLong:[threadID longLongValue]]];
    [item setMessageTopicKind:@"thread"];
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
            if (![threadID respondsToSelector:@selector(longLongValue)]) {
                threadID = [topic objectForKey:@"forum_topic_id"];
            }
            NSString *topicKind = [topic objectForKey:@"message_topic_kind"];
            if (![topicKind isKindOfClass:[NSString class]] || [topicKind length] == 0) {
                topicKind = @"forum";
            }
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
            BOOL serverMuted = [self chatNotificationsMutedFromObject:topic];
            [topicItem setServerNotificationsMuted:serverMuted];
            [topicItem setNotificationsMuted:serverMuted];
            id lastReadOutboxValue = [topic objectForKey:@"last_read_outbox_message_id"];
            if ([lastReadOutboxValue respondsToSelector:@selector(longLongValue)]) {
                [topicItem setLastReadOutboxMessageID:[NSNumber numberWithLongLong:[lastReadOutboxValue longLongValue]]];
            }
            [topicItem setForumTopic:YES];
            [topicItem setParentChatID:chatID];
            [topicItem setMessageThreadID:[NSNumber numberWithLongLong:[threadID longLongValue]]];
            [topicItem setMessageTopicKind:topicKind];
            [topicItems addObject:topicItem];
        }
        return topicItems;
    }

    if (forumTopicError && error) {
        *error = forumTopicError;
    }
    return [NSArray array];

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
        NSNumber *threadID = [self messageThreadIDFromMessageObject:message];
        NSString *threadKind = [self messageTopicKindFromMessageObject:message];
        if (![threadID respondsToSelector:@selector(longLongValue)] || [threadID longLongValue] <= 0) {
            if (TGTDLibCanGetMessageThreadFromObject(message) && [messageID respondsToSelector:@selector(longLongValue)]) {
                threadID = [NSNumber numberWithLongLong:[messageID longLongValue]];
                threadKind = @"thread";
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
            if (threadItem && [threadKind length] > 0) {
                [threadItem setMessageTopicKind:threadKind];
            }
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
            [threadItem setMessageTopicKind:([threadKind length] > 0 ? threadKind : @"thread")];
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
    return [self recentMessagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind fromMessageID:nil limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self messagePreviewItemsForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil fromMessageID:fromMessageID limit:limit timeout:timeout error:error];
}

- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
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

    BOOL threadHistory = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    NSString *safeTopicKind = [messageTopicKind isKindOfClass:[NSString class]] ? messageTopicKind : nil;
    BOOL knownFreshForumTopic = [safeTopicKind isEqualToString:@"forum"];
    BOOL knownLegacyForumTopic = [safeTopicKind isEqualToString:@"forum_legacy"];
    BOOL knownThreadTopic = [safeTopicKind isEqualToString:@"thread"];
    BOOL allowForumSchema = threadHistory && !knownThreadTopic;
    BOOL allowThreadSchema = threadHistory && !knownFreshForumTopic && !knownLegacyForumTopic;
    BOOL allowLegacyThreadSchema = threadHistory && !knownFreshForumTopic;

    NSError *primaryHistoryError = nil;
    NSDictionary *response = nil;
    if (threadHistory && allowForumSchema) {
        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        [request setObject:@"getForumTopicHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"forum_topic_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        response = [self sendTDLibRequestAndWaitForExtra:request
                                             extraPrefix:@"telegraphica-forum-topic-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!threadHistory) {
        NSMutableDictionary *request = [NSMutableDictionary dictionary];
        [request setObject:@"getChatHistory" forKey:@"@type"];
        [request setObject:chatID forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [request setObject:[NSNumber numberWithBool:NO] forKey:@"only_local"];
        response = [self sendTDLibRequestAndWaitForExtra:request
                                             extraPrefix:@"telegraphica-chat-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }

    if (!response && threadHistory && allowThreadSchema) {
        NSMutableDictionary *legacyThreadRequest = [NSMutableDictionary dictionary];
        [legacyThreadRequest setObject:@"getMessageThreadHistory" forKey:@"@type"];
        [legacyThreadRequest setObject:chatID forKey:@"chat_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [legacyThreadRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [legacyThreadRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        response = [self sendTDLibRequestAndWaitForExtra:legacyThreadRequest
                                             extraPrefix:@"telegraphica-message-thread-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!response && threadHistory && allowForumSchema) {
        NSMutableDictionary *searchRequest = [NSMutableDictionary dictionary];
        [searchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [searchRequest setObject:chatID forKey:@"chat_id"];
        [searchRequest setObject:@"" forKey:@"query"];
        [searchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [searchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [searchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [searchRequest setObject:[NSNull null] forKey:@"filter"];
        NSDictionary *forumTopic = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"messageTopicForum", @"@type",
                                    [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"forum_topic_id",
                                    nil];
        [searchRequest setObject:forumTopic forKey:@"topic_id"];
        response = [self sendTDLibRequestAndWaitForExtra:searchRequest
                                               extraPrefix:@"telegraphica-thread-search-history"
                                                   timeout:timeout
                                                 errorCode:40
                                                     error:&primaryHistoryError];
    }
    if (!response && threadHistory && allowThreadSchema) {
        NSMutableDictionary *searchRequest = [NSMutableDictionary dictionary];
        [searchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [searchRequest setObject:chatID forKey:@"chat_id"];
        [searchRequest setObject:@"" forKey:@"query"];
        [searchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [searchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [searchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [searchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [searchRequest setObject:[NSNull null] forKey:@"filter"];
        NSDictionary *messageThread = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"messageTopicThread", @"@type",
                                       [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"message_thread_id",
                                       nil];
        [searchRequest setObject:messageThread forKey:@"topic_id"];
        response = [self sendTDLibRequestAndWaitForExtra:searchRequest
                                             extraPrefix:@"telegraphica-message-thread-search-history"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!response && threadHistory && allowLegacyThreadSchema) {
        NSMutableDictionary *legacySearchRequest = [NSMutableDictionary dictionary];
        [legacySearchRequest setObject:@"searchChatMessages" forKey:@"@type"];
        [legacySearchRequest setObject:chatID forKey:@"chat_id"];
        [legacySearchRequest setObject:@"" forKey:@"query"];
        [legacySearchRequest setObject:[NSNull null] forKey:@"sender_id"];
        [legacySearchRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
        [legacySearchRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
        [legacySearchRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
        [legacySearchRequest setObject:[NSNull null] forKey:@"filter"];
        [legacySearchRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:legacySearchRequest
                                             extraPrefix:@"telegraphica-thread-search-history-legacy"
                                                 timeout:timeout
                                               errorCode:40
                                                   error:&primaryHistoryError];
    }
    if (!response) {
        if (error) {
            *error = primaryHistoryError;
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id messages = [response objectForKey:@"messages"];
    BOOL expectedMessagesResponse = ([responseType isKindOfClass:[NSString class]] &&
                                     ([(NSString *)responseType isEqualToString:@"messages"] ||
                                      [(NSString *)responseType isEqualToString:@"foundChatMessages"]));
    if (!expectedMessagesResponse || ![messages isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getChatHistory returned an unexpected response." code:41];
        }
        return nil;
    }

    return [self messagePreviewItemsFromMessages:(NSArray *)messages chatID:chatID];
}

- (NSDictionary *)searchMessagesFilterForName:(NSString *)filterName {
    if (![filterName isKindOfClass:[NSString class]] || [filterName length] == 0 || [filterName isEqualToString:@"all"]) {
        return (NSDictionary *)[NSNull null];
    }
    NSString *type = nil;
    if ([filterName isEqualToString:@"photos"]) {
        type = @"searchMessagesFilterPhoto";
    } else if ([filterName isEqualToString:@"videos"]) {
        type = @"searchMessagesFilterVideo";
    } else if ([filterName isEqualToString:@"documents"]) {
        type = @"searchMessagesFilterDocument";
    } else if ([filterName isEqualToString:@"links"]) {
        type = @"searchMessagesFilterUrl";
    } else if ([filterName isEqualToString:@"voice"]) {
        type = @"searchMessagesFilterVoiceNote";
    } else if ([filterName isEqualToString:@"audio"]) {
        type = @"searchMessagesFilterAudio";
    } else if ([filterName isEqualToString:@"animations"] || [filterName isEqualToString:@"gifs"]) {
        type = @"searchMessagesFilterAnimation";
    } else if ([filterName isEqualToString:@"videoNotes"]) {
        type = @"searchMessagesFilterVideoNote";
    } else if ([filterName isEqualToString:@"stickers"]) {
        type = @"searchMessagesFilterSticker";
    } else if ([filterName isEqualToString:@"polls"]) {
        type = @"searchMessagesFilterPoll";
    }
    if ([type length] == 0) {
        return (NSDictionary *)[NSNull null];
    }
    return [NSDictionary dictionaryWithObject:type forKey:@"@type"];
}

- (NSArray *)messagesFromSearchResponse:(NSDictionary *)response error:(NSError **)error {
    id responseType = [response objectForKey:@"@type"];
    id messages = [response objectForKey:@"messages"];
    BOOL expectedMessagesResponse = ([responseType isKindOfClass:[NSString class]] &&
                                     ([(NSString *)responseType isEqualToString:@"messages"] ||
                                      [(NSString *)responseType isEqualToString:@"foundMessages"] ||
                                      [(NSString *)responseType isEqualToString:@"foundChatMessages"]));
    if (!expectedMessagesResponse || ![messages isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib search returned an unexpected response." code:92];
        }
        return nil;
    }
    return (NSArray *)messages;
}

- (NSArray *)searchMessagePreviewItemsForChatID:(NSNumber *)chatID
                                messageThreadID:(NSNumber *)messageThreadID
                               messageTopicKind:(NSString *)messageTopicKind
                                          query:(NSString *)query
                                         filter:(NSString *)filter
                                  fromMessageID:(NSNumber *)fromMessageID
                                          limit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing for search." code:93];
        }
        return nil;
    }
    NSString *safeQuery = [query isKindOfClass:[NSString class]] ? query : @"";
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }

    NSMutableArray *requests = [NSMutableArray array];
    NSDictionary *filterObject = [self searchMessagesFilterForName:filter];
    long long anchorMessageID = ([fromMessageID respondsToSelector:@selector(longLongValue)] ? [fromMessageID longLongValue] : 0LL);

    NSMutableDictionary *baseRequest = [NSMutableDictionary dictionary];
    [baseRequest setObject:@"searchChatMessages" forKey:@"@type"];
    [baseRequest setObject:chatID forKey:@"chat_id"];
    [baseRequest setObject:safeQuery forKey:@"query"];
    [baseRequest setObject:[NSNull null] forKey:@"sender_id"];
    [baseRequest setObject:[NSNumber numberWithLongLong:anchorMessageID] forKey:@"from_message_id"];
    [baseRequest setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [baseRequest setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [baseRequest setObject:filterObject forKey:@"filter"];

    if ([messageThreadID respondsToSelector:@selector(longLongValue)]) {
        if ([messageTopicKind isEqualToString:@"thread"]) {
            NSMutableDictionary *topicRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
            NSDictionary *messageThread = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"messageTopicThread", @"@type",
                                           [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"message_thread_id",
                                           nil];
            [topicRequest setObject:messageThread forKey:@"topic_id"];
            [requests addObject:topicRequest];
        }
        NSMutableDictionary *forumRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
        NSDictionary *forumTopic = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"messageTopicForum", @"@type",
                                    [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"forum_topic_id",
                                    nil];
        [forumRequest setObject:forumTopic forKey:@"topic_id"];
        [requests addObject:forumRequest];

        NSMutableDictionary *legacyThreadRequest = [NSMutableDictionary dictionaryWithDictionary:baseRequest];
        [legacyThreadRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        [requests addObject:legacyThreadRequest];
    }
    [requests addObject:baseRequest];

    NSError *lastError = nil;
    NSUInteger index = 0;
    for (index = 0; index < [requests count]; index++) {
        NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:[requests objectAtIndex:index]
                                                            extraPrefix:@"telegraphica-search-chat-messages"
                                                                timeout:timeout
                                                              errorCode:93
                                                                  error:&lastError];
        NSArray *messages = response ? [self messagesFromSearchResponse:response error:&lastError] : nil;
        if (messages) {
            return [self messagePreviewItemsFromMessages:messages chatID:chatID];
        }
    }
    if (error) {
        *error = lastError;
    }
    return nil;
}

- (NSArray *)globalSearchMessagePreviewItemsWithQuery:(NSString *)query
                                               filter:(NSString *)filter
                                               offset:(NSString **)offset
                                                limit:(NSUInteger)limit
                                              timeout:(NSTimeInterval)timeout
                                                error:(NSError **)error {
    NSString *safeQuery = [query isKindOfClass:[NSString class]] ? query : @"";
    if ([safeQuery length] == 0) {
        return [NSArray array];
    }
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 30;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchMessages" forKey:@"@type"];
    [request setObject:safeQuery forKey:@"query"];
    [request setObject:(offset && [*offset length] > 0 ? *offset : @"") forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [request setObject:[self searchMessagesFilterForName:filter] forKey:@"filter"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"min_date"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"max_date"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-search-global-messages"
                                                           timeout:timeout
                                                         errorCode:94
                                                             error:error];
    NSArray *messages = response ? [self messagesFromSearchResponse:response error:error] : nil;
    if (!messages) {
        return nil;
    }
    if (offset) {
        id nextOffset = [response objectForKey:@"next_offset"];
        if ([nextOffset isKindOfClass:[NSString class]]) {
            *offset = [(NSString *)nextOffset copy];
        } else {
            *offset = [@"" copy];
        }
    }
    return [self messagePreviewItemsFromMessages:messages chatID:nil];
}

- (TGMessageItem *)messagePreviewItemForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Message lookup target is missing." code:95];
        }
        return nil;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"message_id"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-get-message"
                                                           timeout:timeout
                                                         errorCode:95
                                                             error:error];
    if (!response) {
        return nil;
    }
    NSArray *items = [self messagePreviewItemsFromMessages:[NSArray arrayWithObject:response] chatID:chatID];
    return [items count] > 0 ? [items objectAtIndex:0] : nil;
}

- (NSArray *)messageContextPreviewItemsForChatID:(NSNumber *)chatID
                                messageThreadID:(NSNumber *)messageThreadID
                               messageTopicKind:(NSString *)messageTopicKind
                                centerMessageID:(NSNumber *)messageID
                                          limit:(NSUInteger)limit
                                        timeout:(NSTimeInterval)timeout
                                          error:(NSError **)error {
    if (![messageID respondsToSelector:@selector(longLongValue)]) {
        return [NSArray array];
    }
    NSUInteger safeLimit = limit;
    if (safeLimit < 5) {
        safeLimit = 12;
    }
    if (safeLimit > 40) {
        safeLimit = 40;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getChatHistory" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"from_message_id"];
    [request setObject:[NSNumber numberWithInt:-((int)safeLimit / 2)] forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"only_local"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-message-context"
                                                           timeout:timeout
                                                         errorCode:96
                                                             error:error];
    NSArray *messages = response ? [self messagesFromSearchResponse:response error:error] : nil;
    if (messages) {
        return [self messagePreviewItemsFromMessages:messages chatID:chatID];
    }
    TGMessageItem *centerItem = [self messagePreviewItemForChatID:chatID messageID:messageID timeout:timeout error:error];
    return centerItem ? [NSArray arrayWithObject:centerItem] : nil;
}

- (TGMessageItem *)legacyPinnedMessagePreviewItemForChatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getChat" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-get-chat-pinned"
                                                           timeout:timeout
                                                         errorCode:97
                                                             error:error];
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    id pinnedMessageID = [response objectForKey:@"pinned_message_id"];
    if (![pinnedMessageID respondsToSelector:@selector(longLongValue)] || [pinnedMessageID longLongValue] == 0) {
        return nil;
    }
    return [self messagePreviewItemForChatID:chatID
                                   messageID:[NSNumber numberWithLongLong:[pinnedMessageID longLongValue]]
                                    timeout:timeout
                                      error:error];
}

- (TGMessageItem *)pinnedMessagePreviewItemForChatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSArray *items = [self pinnedMessagePreviewItemsForChatID:chatID limit:1 timeout:timeout error:NULL];
    if ([items count] > 0) {
        return [items objectAtIndex:0];
    }
    return [self legacyPinnedMessagePreviewItemForChatID:chatID timeout:timeout error:error];
}

- (NSArray *)pinnedMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return [NSArray array];
    }
    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 50) {
        safeLimit = 20;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchChatMessages" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:@"" forKey:@"query"];
    [request setObject:[NSNull null] forKey:@"sender_id"];
    [request setObject:[NSNumber numberWithLongLong:0] forKey:@"from_message_id"];
    [request setObject:[NSNumber numberWithInt:0] forKey:@"offset"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];
    [request setObject:[NSDictionary dictionaryWithObject:@"searchMessagesFilterPinned" forKey:@"@type"] forKey:@"filter"];

    NSError *searchError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-search-pinned-messages"
                                                           timeout:timeout
                                                         errorCode:97
                                                             error:&searchError];
    NSArray *messages = response ? [self messagesFromSearchResponse:response error:&searchError] : nil;
    if (messages) {
        NSArray *items = [self messagePreviewItemsFromMessages:messages chatID:chatID];
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            id candidate = [items objectAtIndex:index];
            if ([candidate isKindOfClass:[TGMessageItem class]]) {
                [(TGMessageItem *)candidate setPinned:YES];
            }
        }
        return items;
    }

    TGMessageItem *fallback = [self legacyPinnedMessagePreviewItemForChatID:chatID timeout:timeout error:error];
    if (fallback) {
        [fallback setPinned:YES];
        return [NSArray arrayWithObject:fallback];
    }
    if (error && *error == nil) {
        *error = searchError;
    }
    return [NSArray array];
}

- (NSArray *)messageViewersForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat or message identifier is missing." code:149];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load message viewers. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:149];
        }
        return nil;
    }

    if (limit == 0 || limit > 100) {
        limit = 50;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getMessageViewers" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];

    NSError *viewersError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-message-viewers"
                                                           timeout:timeout
                                                         errorCode:149
                                                             error:&viewersError];
    if (!response) {
        if (error) {
            *error = viewersError;
        }
        return nil;
    }

    id viewersObject = [response objectForKey:@"viewers"];
    if (![viewersObject isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned no viewer list for this message." code:149];
        }
        return nil;
    }

    NSMutableArray *viewers = [NSMutableArray array];
    NSArray *viewerObjects = (NSArray *)viewersObject;
    NSUInteger index = 0;
    for (index = 0; index < [viewerObjects count] && [viewers count] < limit; index++) {
        id viewer = [viewerObjects objectAtIndex:index];
        id userIDObject = viewer;
        id viewDate = nil;
        if ([viewer isKindOfClass:[NSDictionary class]]) {
            userIDObject = [(NSDictionary *)viewer objectForKey:@"user_id"];
            viewDate = [(NSDictionary *)viewer objectForKey:@"view_date"];
        }
        if (![userIDObject respondsToSelector:@selector(longLongValue)]) {
            continue;
        }

        NSNumber *userID = [NSNumber numberWithLongLong:[userIDObject longLongValue]];
        NSDictionary *senderSummary = [self userSenderSummaryForUserID:userID timeout:MIN(timeout, 2.0)];
        NSMutableDictionary *viewerSummary = [NSMutableDictionary dictionary];
        [viewerSummary setObject:userID forKey:@"user_id"];
        NSString *displayName = [senderSummary objectForKey:@"display_name"];
        [viewerSummary setObject:([displayName length] > 0 ? displayName : [NSString stringWithFormat:@"User %@", userID]) forKey:@"display_name"];
        NSString *avatarPath = [senderSummary objectForKey:@"avatar_local_path"];
        if ([avatarPath length] > 0) {
            [viewerSummary setObject:avatarPath forKey:@"avatar_local_path"];
        }
        if ([viewDate respondsToSelector:@selector(integerValue)]) {
            [viewerSummary setObject:[NSNumber numberWithInteger:[viewDate integerValue]] forKey:@"view_date"];
        }
        [viewers addObject:viewerSummary];
    }

    return viewers;
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self markMessagesAsReadForChatID:chatID messageThreadID:nil messageIDs:messageIDs timeout:timeout error:error];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self markMessagesAsReadForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil messageIDs:messageIDs timeout:timeout error:error];
}

- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)messageTopicKind;
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
        NSError *legacySchemaError = nil;
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:@"telegraphica-view-messages-legacy"
                                                 timeout:timeout
                                               errorCode:59
                                                   error:&legacySchemaError];
        if (!response) {
            if (error && *error == nil) {
                *error = legacySchemaError ? legacySchemaError : currentSchemaError;
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

- (BOOL)toggleChatPinnedForChatID:(NSNumber *)chatID chatFilterID:(NSNumber *)chatFilterID pinned:(BOOL)pinned timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:94];
        }
        return NO;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to update pinned chats. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:95];
        }
        return NO;
    }

    NSDictionary *chatList = [self chatListObjectForChatFilterID:chatFilterID];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"toggleChatIsPinned" forKey:@"@type"];
    [request setObject:chatList forKey:@"chat_list"];
    [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithBool:pinned] forKey:@"is_pinned"];

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-toggle-chat-pinned"
                                                           timeout:timeout
                                                         errorCode:96
                                                             error:error];
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error && *error == nil) {
            *error = [self errorWithDescription:@"TDLib toggleChatIsPinned returned an unexpected response." code:97];
        }
        return NO;
    }
    return YES;
}

- (BOOL)setMessagePinnedForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID pinned:(BOOL)pinned timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat or message identifier is missing." code:98];
        }
        return NO;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to update pinned messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:99];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    if (pinned) {
        [request setObject:@"pinChatMessage" forKey:@"@type"];
        [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
        [request setObject:[NSNumber numberWithBool:NO] forKey:@"disable_notification"];
        [request setObject:[NSNumber numberWithBool:NO] forKey:@"only_for_self"];
    } else {
        [request setObject:@"unpinChatMessage" forKey:@"@type"];
        [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
        [request setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
    }

    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:(pinned ? @"telegraphica-pin-chat-message" : @"telegraphica-unpin-chat-message")
                                                           timeout:timeout
                                                         errorCode:(pinned ? 100 : 101)
                                                             error:error];
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error && *error == nil) {
            *error = [self errorWithDescription:@"TDLib pin/unpin message returned an unexpected response." code:102];
        }
        return NO;
    }
    return YES;
}

- (BOOL)setPollAnswerForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID optionIndexes:(NSArray *)optionIndexes timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat or poll message identifier is missing." code:152];
        }
        return NO;
    }
    if (![optionIndexes isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"Poll answer options are missing." code:152];
        }
        return NO;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to vote in polls. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:153];
        }
        return NO;
    }

    NSMutableArray *safeOptions = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [optionIndexes count]; index++) {
        id option = [optionIndexes objectAtIndex:index];
        if ([option respondsToSelector:@selector(integerValue)] && [option integerValue] >= 0) {
            [safeOptions addObject:[NSNumber numberWithInteger:[option integerValue]]];
        }
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setPollAnswer" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithLongLong:[messageID longLongValue]] forKey:@"message_id"];
    [request setObject:safeOptions forKey:@"option_ids"];

    NSError *pollError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-set-poll-answer"
                                                           timeout:timeout
                                                         errorCode:154
                                                             error:&pollError];
    id responseType = [response objectForKey:@"@type"];
    if (!response || ![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = pollError ? pollError : [self errorWithDescription:@"TDLib did not accept the poll answer." code:154];
        }
        return NO;
    }
    return YES;
}

- (BOOL)setDraftMessageForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    (void)messageTopicKind;
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:150];
        }
        return NO;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to sync draft messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:150];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setChatDraftMessage" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[chatID longLongValue]] forKey:@"chat_id"];
    if ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0) {
        [request setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
    }

    NSString *draftText = ([text isKindOfClass:[NSString class]] ? text : @"");
    if ([draftText length] > 0) {
        NSMutableDictionary *formattedText = [NSMutableDictionary dictionary];
        [formattedText setObject:@"formattedText" forKey:@"@type"];
        [formattedText setObject:draftText forKey:@"text"];
        [formattedText setObject:[NSArray array] forKey:@"entities"];

        NSMutableDictionary *inputContent = [NSMutableDictionary dictionary];
        [inputContent setObject:@"inputMessageText" forKey:@"@type"];
        [inputContent setObject:formattedText forKey:@"text"];
        [inputContent setObject:[NSNumber numberWithBool:NO] forKey:@"clear_draft"];

        NSMutableDictionary *draft = [NSMutableDictionary dictionary];
        [draft setObject:@"draftMessage" forKey:@"@type"];
        [draft setObject:inputContent forKey:@"input_message_text"];
        [draft setObject:[NSNumber numberWithInteger:(NSInteger)[[NSDate date] timeIntervalSince1970]] forKey:@"date"];
        if ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) {
            NSDictionary *replyTarget = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"inputMessageReplyToMessage", @"@type",
                                         [NSNumber numberWithLongLong:[replyToMessageID longLongValue]], @"message_id",
                                         nil];
            [draft setObject:replyTarget forKey:@"reply_to"];
        }
        [request setObject:draft forKey:@"draft_message"];
    } else {
        [request setObject:[NSNull null] forKey:@"draft_message"];
    }

    NSError *draftError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-set-draft"
                                                           timeout:timeout
                                                         errorCode:150
                                                             error:&draftError];
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error && *error == nil) {
            *error = draftError ? draftError : [self errorWithDescription:@"TDLib setChatDraftMessage returned an unexpected response." code:150];
        }
        return NO;
    }
    return YES;
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendTextMessageToChatID:chatID messageThreadID:nil text:text timeout:timeout error:error];
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendTextMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil text:text timeout:timeout error:error];
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendTextMessageToChatID:chatID
                         messageThreadID:messageThreadID
                        messageTopicKind:messageTopicKind
                                     text:text
                         replyToMessageID:nil
                                  timeout:timeout
                                    error:error];
}

- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
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
    [request setObject:content forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSDictionary *response = nil;
    if ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) {
        NSMutableDictionary *replyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        NSDictionary *replyTarget = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"inputMessageReplyToMessage", @"@type",
                                     [NSNumber numberWithLongLong:[replyToMessageID longLongValue]], @"message_id",
                                     nil];
        [replyRequest setObject:replyTarget forKey:@"reply_to"];
        response = [self sendMessageRequest:replyRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-text-reply"
                                    timeout:timeout
                                  errorCode:46
                                      error:&sendError];
        if (!response) {
            NSMutableDictionary *legacyReplyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
            [legacyReplyRequest setObject:[NSNumber numberWithLongLong:[replyToMessageID longLongValue]] forKey:@"reply_to_message_id"];
            sendError = nil;
            response = [self sendMessageRequest:legacyReplyRequest
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                    extraPrefix:@"telegraphica-send-text-legacy-reply"
                                        timeout:timeout
                                      errorCode:46
                                          error:&sendError];
        }
    } else {
        response = [self sendMessageRequest:request
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-text"
                                    timeout:timeout
                                  errorCode:46
                                      error:&sendError];
    }
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm sendMessage before timeout. The message may or may not have been sent." code:46];
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

- (NSString *)sendPollMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind question:(NSString *)question options:(NSArray *)options allowMultipleAnswers:(BOOL)allowMultipleAnswers anonymous:(BOOL)anonymous timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:170];
        }
        return nil;
    }
    NSString *safeQuestion = ([question isKindOfClass:[NSString class]] ? [question stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"");
    if ([safeQuestion length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Poll question is empty." code:171];
        }
        return nil;
    }
    NSMutableArray *safeOptions = [NSMutableArray array];
    NSMutableSet *seenOptions = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [options count] && [safeOptions count] < 10; index++) {
        id optionObject = [options objectAtIndex:index];
        NSString *option = ([optionObject isKindOfClass:[NSString class]] ? [(NSString *)optionObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"");
        NSString *normalized = [option lowercaseString];
        if ([option length] == 0 || [seenOptions containsObject:normalized]) {
            continue;
        }
        [seenOptions addObject:normalized];
        [safeOptions addObject:option];
    }
    if ([safeOptions count] < 2) {
        if (error) {
            *error = [self errorWithDescription:@"Poll needs at least two unique options." code:172];
        }
        return nil;
    }
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send polls. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:173];
        }
        return nil;
    }

    NSMutableDictionary *questionText = [NSMutableDictionary dictionary];
    [questionText setObject:@"formattedText" forKey:@"@type"];
    [questionText setObject:safeQuestion forKey:@"text"];
    [questionText setObject:[NSArray array] forKey:@"entities"];

    NSMutableArray *inputOptions = [NSMutableArray array];
    NSMutableArray *legacyOptions = [NSMutableArray array];
    for (index = 0; index < [safeOptions count]; index++) {
        NSString *option = [safeOptions objectAtIndex:index];
        NSMutableDictionary *optionText = [NSMutableDictionary dictionary];
        [optionText setObject:@"formattedText" forKey:@"@type"];
        [optionText setObject:option forKey:@"text"];
        [optionText setObject:[NSArray array] forKey:@"entities"];
        NSDictionary *inputOption = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"inputPollOption", @"@type",
                                     optionText, @"text",
                                     nil];
        [inputOptions addObject:inputOption];
        [legacyOptions addObject:option];
    }

    NSDictionary *pollType = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"pollTypeRegular", @"@type",
                              [NSNumber numberWithBool:allowMultipleAnswers], @"allow_multiple_answers",
                              nil];
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setObject:@"inputMessagePoll" forKey:@"@type"];
    [content setObject:questionText forKey:@"question"];
    [content setObject:inputOptions forKey:@"options"];
    [content setObject:[NSNumber numberWithBool:anonymous] forKey:@"is_anonymous"];
    [content setObject:pollType forKey:@"type"];
    [content setObject:[NSNumber numberWithInt:0] forKey:@"open_period"];
    [content setObject:[NSNumber numberWithInt:0] forKey:@"close_date"];
    [content setObject:[NSNumber numberWithBool:NO] forKey:@"is_closed"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:content forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSDictionary *response = [self sendMessageRequest:request
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-send-poll"
                                              timeout:timeout
                                            errorCode:174
                                                error:&sendError];
    if (!response) {
        NSMutableDictionary *legacyContent = [NSMutableDictionary dictionary];
        [legacyContent setObject:@"inputMessagePoll" forKey:@"@type"];
        [legacyContent setObject:safeQuestion forKey:@"question"];
        [legacyContent setObject:legacyOptions forKey:@"options"];
        [legacyContent setObject:[NSNumber numberWithBool:anonymous] forKey:@"is_anonymous"];
        [legacyContent setObject:pollType forKey:@"type"];
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest setObject:legacyContent forKey:@"input_message_content"];
        sendError = nil;
        response = [self sendMessageRequest:legacyRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-poll-legacy"
                                    timeout:timeout
                                  errorCode:174
                                      error:&sendError];
    }
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm poll send." code:174];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib poll send returned an unexpected response." code:175];
        }
        return nil;
    }
    return @"poll submitted";
}

- (NSString *)forwardMessagesFromChatID:(NSNumber *)fromChatID messageIDs:(NSArray *)messageIDs toChatID:(NSNumber *)toChatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![fromChatID respondsToSelector:@selector(longLongValue)] || ![toChatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Forward source or destination chat is missing." code:98];
        }
        return nil;
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
        if (error) {
            *error = [self errorWithDescription:@"No message identifiers are available to forward." code:99];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to forward messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:100];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"forwardMessages" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[toChatID longLongValue]] forKey:@"chat_id"];
    [request setObject:[NSNumber numberWithLongLong:[fromChatID longLongValue]] forKey:@"from_chat_id"];
    [request setObject:safeMessageIDs forKey:@"message_ids"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"send_copy"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"remove_caption"];

    NSError *forwardError = nil;
    NSDictionary *response = [self sendMessageRequest:request
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-forward-messages"
                                              timeout:timeout
                                            errorCode:101
                                                error:&forwardError];
    if (!response) {
        if (error) {
            *error = forwardError ? forwardError : [self errorWithDescription:@"TDLib did not confirm forwardMessages before timeout." code:101];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] ||
        (![(NSString *)responseType isEqualToString:@"messages"] && ![(NSString *)responseType isEqualToString:@"ok"])) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib forwardMessages returned an unexpected response." code:102];
        }
        return nil;
    }
    return @"messages forwarded";
}

- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendPhotoMessageToChatID:chatID messageThreadID:nil messageTopicKind:nil localPath:localPath caption:caption timeout:timeout error:error];
}

- (NSMutableDictionary *)requestByApplyingReplyToMessageID:(NSNumber *)replyToMessageID
                                                    request:(NSDictionary *)request
                                              currentSchema:(BOOL)currentSchema {
    NSMutableDictionary *replyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
    if (![replyToMessageID respondsToSelector:@selector(longLongValue)] || [replyToMessageID longLongValue] <= 0) {
        return replyRequest;
    }
    if (currentSchema) {
        NSDictionary *replyTarget = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"inputMessageReplyToMessage", @"@type",
                                     [NSNumber numberWithLongLong:[replyToMessageID longLongValue]], @"message_id",
                                     nil];
        [replyRequest setObject:replyTarget forKey:@"reply_to"];
    } else {
        [replyRequest setObject:[NSNumber numberWithLongLong:[replyToMessageID longLongValue]] forKey:@"reply_to_message_id"];
    }
    return replyRequest;
}

- (NSDictionary *)photoInputMessageContentForInputFile:(NSDictionary *)inputFile caption:(NSDictionary *)formattedCaption width:(NSNumber *)width height:(NSNumber *)height currentSchema:(BOOL)currentSchema {
    NSNumber *safeWidth = ([width respondsToSelector:@selector(intValue)] && [width intValue] > 0) ? width : [NSNumber numberWithInt:0];
    NSNumber *safeHeight = ([height respondsToSelector:@selector(intValue)] && [height intValue] > 0) ? height : [NSNumber numberWithInt:0];
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setObject:@"inputMessagePhoto" forKey:@"@type"];
    [content setObject:formattedCaption forKey:@"caption"];
    if (currentSchema) {
        NSDictionary *inputPhoto = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"inputPhoto", @"@type",
                                    inputFile, @"photo",
                                    [NSNull null], @"thumbnail",
                                    [NSNull null], @"video",
                                    [NSArray array], @"added_sticker_file_ids",
                                    safeWidth, @"width",
                                    safeHeight, @"height",
                                    nil];
        [content setObject:inputPhoto forKey:@"photo"];
        [content setObject:[NSNumber numberWithBool:NO] forKey:@"show_caption_above_media"];
        [content setObject:[NSNull null] forKey:@"self_destruct_type"];
        [content setObject:[NSNumber numberWithBool:NO] forKey:@"has_spoiler"];
    } else {
        [content setObject:inputFile forKey:@"photo"];
        [content setObject:[NSNull null] forKey:@"thumbnail"];
        [content setObject:[NSArray array] forKey:@"added_sticker_file_ids"];
        [content setObject:safeWidth forKey:@"width"];
        [content setObject:safeHeight forKey:@"height"];
        [content setObject:[NSNumber numberWithInt:0] forKey:@"ttl"];
    }
    return content;
}

- (NSDictionary *)sendMessageRequest:(NSDictionary *)request
                      messageThreadID:(NSNumber *)messageThreadID
                     messageTopicKind:(NSString *)messageTopicKind
                          extraPrefix:(NSString *)extraPrefix
                              timeout:(NSTimeInterval)timeout
                            errorCode:(NSInteger)errorCode
                                error:(NSError **)error {
    BOOL threadSend = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    NSString *safeTopicKind = [messageTopicKind isKindOfClass:[NSString class]] ? messageTopicKind : nil;
    BOOL knownFreshForumTopic = [safeTopicKind isEqualToString:@"forum"];
    BOOL knownLegacyForumTopic = [safeTopicKind isEqualToString:@"forum_legacy"];
    BOOL knownThreadTopic = [safeTopicKind isEqualToString:@"thread"];
    BOOL allowForumSchema = threadSend && !knownThreadTopic;
    BOOL allowThreadSchema = threadSend && !knownFreshForumTopic && !knownLegacyForumTopic;
    BOOL allowLegacyThreadSchema = threadSend && !knownFreshForumTopic;

    NSDictionary *response = nil;
    if (threadSend && allowForumSchema) {
        NSMutableDictionary *forumRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        NSDictionary *forumTopic = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"messageTopicForum", @"@type",
                                    [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"forum_topic_id",
                                    nil];
        [forumRequest setObject:forumTopic forKey:@"topic_id"];
        response = [self sendTDLibRequestAndWaitForExtra:forumRequest
                                             extraPrefix:[extraPrefix stringByAppendingString:@"-forum-topic"]
                                                 timeout:timeout
                                               errorCode:errorCode
                                                   error:error];
    }
    if (!response && threadSend && allowThreadSchema) {
        NSMutableDictionary *threadRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        NSDictionary *messageThread = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @"messageTopicThread", @"@type",
                                       [NSNumber numberWithLongLong:[messageThreadID longLongValue]], @"message_thread_id",
                                       nil];
        [threadRequest setObject:messageThread forKey:@"topic_id"];
        response = [self sendTDLibRequestAndWaitForExtra:threadRequest
                                             extraPrefix:[extraPrefix stringByAppendingString:@"-message-thread"]
                                                 timeout:timeout
                                               errorCode:errorCode
                                                   error:error];
    }
    if (!response && threadSend && allowLegacyThreadSchema) {
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyRequest setObject:[NSNumber numberWithLongLong:[messageThreadID longLongValue]] forKey:@"message_thread_id"];
        response = [self sendTDLibRequestAndWaitForExtra:legacyRequest
                                             extraPrefix:[extraPrefix stringByAppendingString:@"-legacy-thread"]
                                                 timeout:timeout
                                               errorCode:errorCode
                                                   error:error];
    }
    if (!response && !threadSend) {
        response = [self sendTDLibRequestAndWaitForExtra:request
                                             extraPrefix:extraPrefix
                                                 timeout:timeout
                                               errorCode:errorCode
                                                   error:error];
    }
    return response;
}

- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendPhotoMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption replyToMessageID:nil timeout:timeout error:error];
}

- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:62];
        }
        return nil;
    }
    if (![localPath isKindOfClass:[NSString class]] || [localPath length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Photo path is missing." code:63];
        }
        return nil;
    }
    NSString *standardPath = [localPath stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardPath isDirectory:&isDirectory] || isDirectory) {
        if (error) {
            *error = [self errorWithDescription:@"Photo file does not exist." code:64];
        }
        return nil;
    }

    NSString *safeCaption = [caption isKindOfClass:[NSString class]] ? caption : @"";
    if ([safeCaption length] > 1024) {
        if (error) {
            *error = [self errorWithDescription:@"Photo caption is too long for this spike." code:65];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send photos. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:66];
        }
        return nil;
    }

    NSDictionary *inputFile = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"inputFileLocal", @"@type",
                               standardPath, @"path",
                               nil];
    NSDictionary *formattedCaption = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"formattedText", @"@type",
                                      safeCaption, @"text",
                                      [NSArray array], @"entities",
                                      nil];
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setObject:@"inputMessagePhoto" forKey:@"@type"];
    [content setObject:inputFile forKey:@"photo"];
    [content setObject:[NSNull null] forKey:@"thumbnail"];
    [content setObject:[NSArray array] forKey:@"added_sticker_file_ids"];
    [content setObject:[NSNumber numberWithInt:0] forKey:@"width"];
    [content setObject:[NSNumber numberWithInt:0] forKey:@"height"];
    [content setObject:formattedCaption forKey:@"caption"];
    [content setObject:[NSNumber numberWithInt:0] forKey:@"ttl"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:content forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSMutableDictionary *effectiveRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:request currentSchema:YES];
    NSDictionary *response = [self sendMessageRequest:effectiveRequest
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0 ? @"telegraphica-send-photo-reply" : @"telegraphica-send-photo")
                                              timeout:timeout
                                            errorCode:67
                                                error:&sendError];
    if (!response && [replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) {
        sendError = nil;
        NSMutableDictionary *legacyReplyRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:request currentSchema:NO];
        response = [self sendMessageRequest:legacyReplyRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-photo-legacy-reply"
                                    timeout:timeout
                                  errorCode:67
                                      error:&sendError];
    }
    if (!response && TGTDLibPhotoSendErrorLooksLikeSchemaMismatch(sendError)) {
        NSDictionary *inputPhoto = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"inputPhoto", @"@type",
                                    inputFile, @"photo",
                                    [NSNull null], @"thumbnail",
                                    [NSNull null], @"video",
                                    [NSArray array], @"added_sticker_file_ids",
                                    [NSNumber numberWithInt:0], @"width",
                                    [NSNumber numberWithInt:0], @"height",
                                    nil];
        NSMutableDictionary *currentContent = [NSMutableDictionary dictionary];
        [currentContent setObject:@"inputMessagePhoto" forKey:@"@type"];
        [currentContent setObject:inputPhoto forKey:@"photo"];
        [currentContent setObject:formattedCaption forKey:@"caption"];
        [currentContent setObject:[NSNumber numberWithBool:NO] forKey:@"show_caption_above_media"];
        [currentContent setObject:[NSNull null] forKey:@"self_destruct_type"];
        [currentContent setObject:[NSNumber numberWithBool:NO] forKey:@"has_spoiler"];

        NSMutableDictionary *currentRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [currentRequest setObject:currentContent forKey:@"input_message_content"];
        NSMutableDictionary *effectiveCurrentRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:currentRequest currentSchema:YES];
        response = [self sendMessageRequest:effectiveCurrentRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0 ? @"telegraphica-send-photo-current-reply" : @"telegraphica-send-photo-current")
                                    timeout:timeout
                                  errorCode:67
                                      error:&sendError];
    }
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm photo send before timeout. The photo may or may not have been sent." code:67];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib sendMessage for photo returned an unexpected response." code:68];
        }
        return nil;
    }

    return @"photo submitted";
}

- (NSString *)sendMediaAlbumToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localMediaItems:(NSArray *)localMediaItems caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendMediaAlbumToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localMediaItems:localMediaItems caption:caption replyToMessageID:nil timeout:timeout error:error];
}

- (NSString *)sendMediaAlbumToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localMediaItems:(NSArray *)localMediaItems caption:(NSString *)caption replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:103];
        }
        return nil;
    }
    if (![localMediaItems isKindOfClass:[NSArray class]] || [localMediaItems count] < 2) {
        if (error) {
            *error = [self errorWithDescription:@"Media album needs at least two items." code:103];
        }
        return nil;
    }
    if ([localMediaItems count] > 10) {
        if (error) {
            *error = [self errorWithDescription:@"Media album cannot contain more than 10 items." code:103];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send media albums. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:104];
        }
        return nil;
    }

    NSMutableArray *legacyContents = [NSMutableArray array];
    NSMutableArray *currentContents = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [localMediaItems count]; index++) {
        id itemObject = [localMediaItems objectAtIndex:index];
        if (![itemObject isKindOfClass:[NSDictionary class]]) {
            if (error) {
                *error = [self errorWithDescription:@"Media album item is invalid." code:105];
            }
            return nil;
        }
        NSDictionary *item = (NSDictionary *)itemObject;
        NSString *kind = [[item objectForKey:@"kind"] isKindOfClass:[NSString class]] ? [item objectForKey:@"kind"] : @"";
        NSString *path = [[item objectForKey:@"path"] isKindOfClass:[NSString class]] ? [item objectForKey:@"path"] : @"";
        NSNumber *width = [[item objectForKey:@"width"] respondsToSelector:@selector(intValue)] ? [item objectForKey:@"width"] : nil;
        NSNumber *height = [[item objectForKey:@"height"] respondsToSelector:@selector(intValue)] ? [item objectForKey:@"height"] : nil;
        NSString *standardPath = nil;
        NSString *label = [kind isEqualToString:@"video"] ? @"Video" : @"Photo";
        if (![self validateLocalSendFilePath:path label:label outPath:&standardPath error:error code:105]) {
            return nil;
        }
        if (![kind isEqualToString:@"photo"] && ![kind isEqualToString:@"video"]) {
            if (error) {
                *error = [self errorWithDescription:@"Media albums currently support only photos and videos." code:106];
            }
            return nil;
        }

        NSDictionary *inputFile = [self inputFileLocalForPath:standardPath];
        NSString *captionForItem = (index == 0 && [caption isKindOfClass:[NSString class]]) ? caption : @"";
        NSDictionary *formattedCaption = [self formattedCaptionForSendCaption:captionForItem];
        NSDictionary *legacyContent = [kind isEqualToString:@"video"]
            ? [self genericInputMessageContentForInputFile:inputFile contentType:@"inputMessageVideo" caption:formattedCaption currentSchema:NO]
            : [self photoInputMessageContentForInputFile:inputFile caption:formattedCaption width:width height:height currentSchema:NO];
        NSDictionary *currentContent = [kind isEqualToString:@"video"]
            ? [self genericInputMessageContentForInputFile:inputFile contentType:@"inputMessageVideo" caption:formattedCaption currentSchema:YES]
            : [self photoInputMessageContentForInputFile:inputFile caption:formattedCaption width:width height:height currentSchema:YES];
        [legacyContents addObject:legacyContent];
        [currentContents addObject:currentContent];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:standardPath error:NULL];
        id fileSizeObject = [attributes objectForKey:NSFileSize];
        unsigned long long byteSize = [fileSizeObject respondsToSelector:@selector(unsignedLongLongValue)] ? [fileSizeObject unsignedLongLongValue] : 0;
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib media album item %lu/%lu kind=%@ file=%@ bytes=%llu size=%@x%@.",
                                      (unsigned long)(index + 1),
                                      (unsigned long)[localMediaItems count],
                                      kind,
                                      [standardPath lastPathComponent],
                                      byteSize,
                                      width ? [width stringValue] : @"0",
                                      height ? [height stringValue] : @"0"]];
    }

    NSMutableDictionary *currentRequest = [NSMutableDictionary dictionary];
    [currentRequest setObject:@"sendMessageAlbum" forKey:@"@type"];
    [currentRequest setObject:chatID forKey:@"chat_id"];
    if ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) {
        NSDictionary *replyTarget = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"inputMessageReplyToMessage", @"@type",
                                     [NSNumber numberWithLongLong:[replyToMessageID longLongValue]], @"message_id",
                                     nil];
        [currentRequest setObject:replyTarget forKey:@"reply_to"];
    } else {
        [currentRequest setObject:[NSNull null] forKey:@"reply_to"];
    }
    [currentRequest setObject:[NSNull null] forKey:@"options"];
    [currentRequest setObject:currentContents forKey:@"input_message_contents"];

    NSError *sendError = nil;
    NSString *acceptedSchema = @"current";
    NSDictionary *response = [self sendMessageRequest:currentRequest
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-send-media-album-current"
                                              timeout:timeout
                                            errorCode:107
                                                error:&sendError];
    if (!response && TGTDLibPhotoSendErrorLooksLikeSchemaMismatch(sendError)) {
        acceptedSchema = @"legacy";
        NSMutableDictionary *legacyRequest = [NSMutableDictionary dictionary];
        [legacyRequest setObject:@"sendMessageAlbum" forKey:@"@type"];
        [legacyRequest setObject:chatID forKey:@"chat_id"];
        [legacyRequest setObject:[NSNumber numberWithLongLong:([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) ? [replyToMessageID longLongValue] : 0LL] forKey:@"reply_to_message_id"];
        [legacyRequest setObject:[NSNull null] forKey:@"options"];
        [legacyRequest setObject:legacyContents forKey:@"input_message_contents"];
        response = [self sendMessageRequest:legacyRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-media-album-legacy"
                                    timeout:timeout
                                  errorCode:107
                                      error:&sendError];
    }
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm media album send." code:107];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"messages"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib sendMessageAlbum returned an unexpected response." code:108];
        }
        return nil;
    }
    NSMutableArray *albumIDs = [NSMutableArray array];
    id messages = [response objectForKey:@"messages"];
    if ([messages isKindOfClass:[NSArray class]]) {
        NSUInteger responseIndex = 0;
        for (responseIndex = 0; responseIndex < [(NSArray *)messages count]; responseIndex++) {
            id message = [(NSArray *)messages objectAtIndex:responseIndex];
            id albumID = [message isKindOfClass:[NSDictionary class]] ? [(NSDictionary *)message objectForKey:@"media_album_id"] : nil;
            if ([albumID respondsToSelector:@selector(longLongValue)] && [albumID longLongValue] > 0) {
                [albumIDs addObject:[albumID stringValue]];
            }
        }
        if ([albumIDs count] == 0 && [(NSArray *)messages count] > 1) {
            [self rememberSyntheticMediaAlbumForMessages:(NSArray *)messages chatID:chatID];
        }
    }
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib media album accepted using %@ schema; response message count=%lu album_ids=%@.",
                                  acceptedSchema,
                                  [messages isKindOfClass:[NSArray class]] ? (unsigned long)[(NSArray *)messages count] : 0,
                                  albumIDs]];
    return @"media album submitted";
}

- (BOOL)validateLocalSendFilePath:(NSString *)localPath
                            label:(NSString *)label
                         outPath:(NSString **)outPath
                            error:(NSError **)error
                             code:(NSInteger)code {
    if (![localPath isKindOfClass:[NSString class]] || [localPath length] == 0) {
        if (error) {
            *error = [self errorWithDescription:[NSString stringWithFormat:@"%@ path is missing.", label] code:code];
        }
        return NO;
    }
    NSString *standardPath = [localPath stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardPath isDirectory:&isDirectory] || isDirectory) {
        if (error) {
            *error = [self errorWithDescription:[NSString stringWithFormat:@"%@ file does not exist.", label] code:code];
        }
        return NO;
    }
    if (outPath) {
        *outPath = standardPath;
    }
    return YES;
}

- (NSDictionary *)formattedCaptionForSendCaption:(NSString *)caption {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"formattedText", @"@type",
            ([caption isKindOfClass:[NSString class]] ? caption : @""), @"text",
            [NSArray array], @"entities",
            nil];
}

- (NSDictionary *)inputFileLocalForPath:(NSString *)path {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"inputFileLocal", @"@type",
            path, @"path",
            nil];
}

- (NSDictionary *)inputDocumentForInputFile:(NSDictionary *)inputFile {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"inputDocument", @"@type",
            inputFile, @"document",
            [NSNull null], @"thumbnail",
            [NSNumber numberWithBool:NO], @"disable_content_type_detection",
            nil];
}

- (NSDictionary *)inputVideoForInputFile:(NSDictionary *)inputFile {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"inputVideo", @"@type",
            inputFile, @"video",
            [NSNull null], @"thumbnail",
            [NSArray array], @"added_sticker_file_ids",
            [NSNumber numberWithInt:0], @"duration",
            [NSNumber numberWithInt:0], @"width",
            [NSNumber numberWithInt:0], @"height",
            [NSNumber numberWithBool:YES], @"supports_streaming",
            nil];
}

- (NSDictionary *)inputAudioForInputFile:(NSDictionary *)inputFile duration:(NSNumber *)duration {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"inputAudio", @"@type",
            inputFile, @"audio",
            [NSNull null], @"album_cover_thumbnail",
            duration ? duration : [NSNumber numberWithInt:0], @"duration",
            @"", @"title",
            @"", @"performer",
            nil];
}

- (NSDictionary *)inputVoiceNoteForInputFile:(NSDictionary *)inputFile duration:(NSNumber *)duration {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"inputVoiceNote", @"@type",
            inputFile, @"voice_note",
            duration ? duration : [NSNumber numberWithInt:0], @"duration",
            @"", @"waveform",
            nil];
}

- (NSDictionary *)genericInputMessageContentForInputFile:(NSDictionary *)inputFile
                                             contentType:(NSString *)contentType
                                                 caption:(NSDictionary *)formattedCaption
                                          currentSchema:(BOOL)currentSchema {
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    if ([contentType isEqualToString:@"inputMessageVideo"]) {
        [content setObject:@"inputMessageVideo" forKey:@"@type"];
        [content setObject:(currentSchema ? [self inputVideoForInputFile:inputFile] : inputFile) forKey:@"video"];
        [content setObject:formattedCaption forKey:@"caption"];
        if (currentSchema) {
            [content setObject:[NSNumber numberWithBool:NO] forKey:@"show_caption_above_media"];
            [content setObject:[NSNull null] forKey:@"self_destruct_type"];
            [content setObject:[NSNumber numberWithBool:NO] forKey:@"has_spoiler"];
        } else {
            [content setObject:[NSNull null] forKey:@"thumbnail"];
            [content setObject:[NSArray array] forKey:@"added_sticker_file_ids"];
            [content setObject:[NSNumber numberWithInt:0] forKey:@"duration"];
            [content setObject:[NSNumber numberWithInt:0] forKey:@"width"];
            [content setObject:[NSNumber numberWithInt:0] forKey:@"height"];
            [content setObject:[NSNumber numberWithBool:NO] forKey:@"supports_streaming"];
            [content setObject:[NSNumber numberWithInt:0] forKey:@"ttl"];
        }
    } else if ([contentType isEqualToString:@"inputMessageAudio"]) {
        [content setObject:@"inputMessageAudio" forKey:@"@type"];
        [content setObject:(currentSchema ? [self inputAudioForInputFile:inputFile duration:[NSNumber numberWithInt:0]] : inputFile) forKey:@"audio"];
        [content setObject:formattedCaption forKey:@"caption"];
        if (!currentSchema) {
            [content setObject:[NSNull null] forKey:@"album_cover_thumbnail"];
            [content setObject:[NSNumber numberWithInt:0] forKey:@"duration"];
            [content setObject:@"" forKey:@"title"];
            [content setObject:@"" forKey:@"performer"];
        }
    } else {
        [content setObject:@"inputMessageDocument" forKey:@"@type"];
        [content setObject:(currentSchema ? [self inputDocumentForInputFile:inputFile] : inputFile) forKey:@"document"];
        [content setObject:formattedCaption forKey:@"caption"];
        if (!currentSchema) {
            [content setObject:[NSNull null] forKey:@"thumbnail"];
            [content setObject:[NSNumber numberWithBool:NO] forKey:@"disable_content_type_detection"];
        }
    }
    return content;
}

- (NSString *)sendGenericFileMessageToChatID:(NSNumber *)chatID
                              messageThreadID:(NSNumber *)messageThreadID
                             messageTopicKind:(NSString *)messageTopicKind
                                     localPath:(NSString *)localPath
                                       caption:(NSString *)caption
                                   contentType:(NSString *)contentType
                                        label:(NSString *)label
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID
                                messageThreadID:messageThreadID
                               messageTopicKind:messageTopicKind
                                      localPath:localPath
                                        caption:caption
                                    contentType:contentType
                                          label:label
                               replyToMessageID:nil
                                        timeout:timeout
                                          error:error];
}

- (NSString *)sendGenericFileMessageToChatID:(NSNumber *)chatID
                              messageThreadID:(NSNumber *)messageThreadID
                             messageTopicKind:(NSString *)messageTopicKind
                                     localPath:(NSString *)localPath
                                       caption:(NSString *)caption
                                   contentType:(NSString *)contentType
                                         label:(NSString *)label
                              replyToMessageID:(NSNumber *)replyToMessageID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:69];
        }
        return nil;
    }

    NSString *standardPath = nil;
    if (![self validateLocalSendFilePath:localPath label:label outPath:&standardPath error:error code:69]) {
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send %@. Current auth state: %@", [label lowercaseString], authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:70];
        }
        return nil;
    }

    NSDictionary *inputFile = [self inputFileLocalForPath:standardPath];
    NSDictionary *formattedCaption = [self formattedCaptionForSendCaption:caption];
    NSDictionary *content = [self genericInputMessageContentForInputFile:inputFile
                                                             contentType:contentType
                                                                 caption:formattedCaption
                                                           currentSchema:NO];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:content forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSMutableDictionary *effectiveRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:request currentSchema:YES];
    NSDictionary *response = [self sendMessageRequest:effectiveRequest
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:[NSString stringWithFormat:@"telegraphica-send-%@%@", [label lowercaseString], ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0 ? @"-reply" : @"")]
                                              timeout:timeout
                                            errorCode:71
                                                error:&sendError];
    if (!response && [replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0) {
        sendError = nil;
        NSMutableDictionary *legacyReplyRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:request currentSchema:NO];
        response = [self sendMessageRequest:legacyReplyRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:[NSString stringWithFormat:@"telegraphica-send-%@-legacy-reply", [label lowercaseString]]
                                    timeout:timeout
                                  errorCode:71
                                      error:&sendError];
    }
    if (!response && TGTDLibPhotoSendErrorLooksLikeSchemaMismatch(sendError)) {
        NSDictionary *currentContent = [self genericInputMessageContentForInputFile:inputFile
                                                                        contentType:contentType
                                                                            caption:formattedCaption
                                                                      currentSchema:YES];
        NSMutableDictionary *currentRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [currentRequest setObject:currentContent forKey:@"input_message_content"];
        NSMutableDictionary *effectiveCurrentRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:currentRequest currentSchema:YES];
        response = [self sendMessageRequest:effectiveCurrentRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:[NSString stringWithFormat:@"telegraphica-send-%@-current%@", [label lowercaseString], ([replyToMessageID respondsToSelector:@selector(longLongValue)] && [replyToMessageID longLongValue] > 0 ? @"-reply" : @"")]
                                    timeout:timeout
                                  errorCode:71
                                      error:&sendError];
    }
    if (!response && ![contentType isEqualToString:@"inputMessageDocument"]) {
        NSDictionary *documentContent = [self genericInputMessageContentForInputFile:inputFile
                                                                         contentType:@"inputMessageDocument"
                                                                             caption:formattedCaption
                                                                       currentSchema:NO];
        NSMutableDictionary *fallbackRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [fallbackRequest setObject:documentContent forKey:@"input_message_content"];
        NSMutableDictionary *effectiveFallbackRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:fallbackRequest currentSchema:YES];
        response = [self sendMessageRequest:effectiveFallbackRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:[NSString stringWithFormat:@"telegraphica-send-%@-document-fallback", [label lowercaseString]]
                                    timeout:timeout
                                  errorCode:71
                                      error:&sendError];
    }
    if (!response && ![contentType isEqualToString:@"inputMessageDocument"] && TGTDLibPhotoSendErrorLooksLikeSchemaMismatch(sendError)) {
        NSDictionary *currentDocumentContent = [self genericInputMessageContentForInputFile:inputFile
                                                                               contentType:@"inputMessageDocument"
                                                                                   caption:formattedCaption
                                                                             currentSchema:YES];
        NSMutableDictionary *currentFallbackRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [currentFallbackRequest setObject:currentDocumentContent forKey:@"input_message_content"];
        NSMutableDictionary *effectiveCurrentFallbackRequest = [self requestByApplyingReplyToMessageID:replyToMessageID request:currentFallbackRequest currentSchema:YES];
        response = [self sendMessageRequest:effectiveCurrentFallbackRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:[NSString stringWithFormat:@"telegraphica-send-%@-document-current-fallback", [label lowercaseString]]
                                    timeout:timeout
                                  errorCode:71
                                      error:&sendError];
    }

    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:[NSString stringWithFormat:@"TDLib did not confirm %@ send.", [label lowercaseString]] code:71];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:[NSString stringWithFormat:@"TDLib %@ send returned an unexpected response.", [label lowercaseString]] code:71];
        }
        return nil;
    }
    return [NSString stringWithFormat:@"%@ submitted", [label lowercaseString]];
}

- (NSString *)sendDocumentMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageDocument" label:@"Document" timeout:timeout error:error];
}

- (NSString *)sendDocumentMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageDocument" label:@"Document" replyToMessageID:replyToMessageID timeout:timeout error:error];
}

- (NSString *)sendVideoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageVideo" label:@"Video" timeout:timeout error:error];
}

- (NSString *)sendVideoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageVideo" label:@"Video" replyToMessageID:replyToMessageID timeout:timeout error:error];
}

- (NSString *)sendAudioMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageAudio" label:@"Audio" timeout:timeout error:error];
}

- (NSString *)sendAudioMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    return [self sendGenericFileMessageToChatID:chatID messageThreadID:messageThreadID messageTopicKind:messageTopicKind localPath:localPath caption:caption contentType:@"inputMessageAudio" label:@"Audio" replyToMessageID:replyToMessageID timeout:timeout error:error];
}

- (NSArray *)recentStickerItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load stickers. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:80];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 24;
    }
    if (safeLimit > 80) {
        safeLimit = 80;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getRecentStickers" forKey:@"@type"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"is_attached"];

    NSError *stickerError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-recent-stickers"
                                                           timeout:timeout
                                                         errorCode:80
                                                             error:&stickerError];
    if (!response) {
        if (error) {
            *error = stickerError ? stickerError : [self errorWithDescription:@"TDLib did not return recent stickers." code:80];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"stickers"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned an unexpected recent-stickers response." code:81];
        }
        return nil;
    }

    id stickersObject = [response objectForKey:@"stickers"];
    if (![stickersObject isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    NSUInteger downloadsRemaining = safeLimit;
    for (index = 0; index < [(NSArray *)stickersObject count] && [items count] < safeLimit; index++) {
        BOOL didRequestDownload = NO;
        NSDictionary *info = [self stickerPreviewInfoFromStickerObject:[(NSArray *)stickersObject objectAtIndex:index]
                                                       downloadMissing:(downloadsRemaining > 0)
                                                               timeout:1.0
                                                    didRequestDownload:&didRequestDownload];
        if (didRequestDownload && downloadsRemaining > 0) {
            downloadsRemaining--;
        }
        if ([info count] > 0) {
            [items addObject:info];
        }
    }
    return items;
}

- (NSArray *)stickerItemsFromStickerResponse:(NSDictionary *)response limit:(NSUInteger)limit errorCode:(NSInteger)errorCode error:(NSError **)error {
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"stickers"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib returned an unexpected sticker response." code:errorCode];
        }
        return nil;
    }

    id stickersObject = [response objectForKey:@"stickers"];
    if (![stickersObject isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0) {
        safeLimit = 24;
    }
    if (safeLimit > 80) {
        safeLimit = 80;
    }

    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    NSUInteger downloadsRemaining = safeLimit;
    for (index = 0; index < [(NSArray *)stickersObject count] && [items count] < safeLimit; index++) {
        BOOL didRequestDownload = NO;
        NSDictionary *info = [self stickerPreviewInfoFromStickerObject:[(NSArray *)stickersObject objectAtIndex:index]
                                                       downloadMissing:(downloadsRemaining > 0)
                                                               timeout:1.0
                                                    didRequestDownload:&didRequestDownload];
        if (didRequestDownload && downloadsRemaining > 0) {
            downloadsRemaining--;
        }
        if ([info count] > 0) {
            [items addObject:info];
        }
    }
    return items;
}

- (NSArray *)favoriteStickerItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load favorite stickers. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:160];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getFavoriteStickers" forKey:@"@type"];

    NSError *stickerError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-favorite-stickers"
                                                           timeout:timeout
                                                         errorCode:161
                                                             error:&stickerError];
    if (!response) {
        if (error) {
            *error = stickerError ? stickerError : [self errorWithDescription:@"TDLib did not return favorite stickers." code:161];
        }
        return nil;
    }
    return [self stickerItemsFromStickerResponse:response limit:limit errorCode:162 error:error];
}

- (NSArray *)stickerItemsForEmoji:(NSString *)emoji limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *safeEmoji = [emoji isKindOfClass:[NSString class]] ? [emoji stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if ([safeEmoji length] == 0) {
        return [NSArray array];
    }
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to search stickers. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:163];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 80) {
        safeLimit = 40;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"searchStickers" forKey:@"@type"];
    [request setObject:safeEmoji forKey:@"emoji"];
    [request setObject:[NSNumber numberWithInt:(int)safeLimit] forKey:@"limit"];

    NSError *stickerError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-search-stickers"
                                                           timeout:timeout
                                                         errorCode:164
                                                             error:&stickerError];
    if (!response) {
        if (error) {
            *error = stickerError ? stickerError : [self errorWithDescription:@"TDLib did not return sticker search results." code:164];
        }
        return nil;
    }
    return [self stickerItemsFromStickerResponse:response limit:safeLimit errorCode:165 error:error];
}

- (NSArray *)installedStickerSetInfoItemsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load sticker sets. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:155];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getInstalledStickerSets" forKey:@"@type"];
    [request setObject:[NSNumber numberWithBool:NO] forKey:@"is_masks"];

    NSError *setError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-installed-sticker-sets"
                                                           timeout:timeout
                                                         errorCode:156
                                                             error:&setError];
    if (!response) {
        if (error) {
            *error = setError ? setError : [self errorWithDescription:@"TDLib did not return installed sticker sets." code:156];
        }
        return nil;
    }

    id setsObject = [response objectForKey:@"sets"];
    if (![setsObject isKindOfClass:[NSArray class]]) {
        setsObject = [response objectForKey:@"sticker_sets"];
    }
    if (![setsObject isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [(NSArray *)setsObject count]; index++) {
        id setObject = [(NSArray *)setsObject objectAtIndex:index];
        if (![setObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSDictionary *set = (NSDictionary *)setObject;
        id setID = [set objectForKey:@"id"];
        if (![setID respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        NSMutableDictionary *item = [NSMutableDictionary dictionary];
        [item setObject:[NSNumber numberWithLongLong:[setID longLongValue]] forKey:@"id"];
        id title = [set objectForKey:@"title"];
        if ([title isKindOfClass:[NSString class]] && [(NSString *)title length] > 0) {
            [item setObject:title forKey:@"title"];
        }
        id name = [set objectForKey:@"name"];
        if ([name isKindOfClass:[NSString class]] && [(NSString *)name length] > 0) {
            [item setObject:name forKey:@"name"];
        }
        id count = [set objectForKey:@"sticker_count"];
        if ([count respondsToSelector:@selector(integerValue)]) {
            [item setObject:[NSNumber numberWithInteger:[count integerValue]] forKey:@"sticker_count"];
        }
        NSDictionary *thumbnail = [self stickerPreviewInfoFromStickerObject:[set objectForKey:@"thumbnail"]
                                                            downloadMissing:YES
                                                                    timeout:0.5
                                                         didRequestDownload:NULL];
        if ([thumbnail count] > 0) {
            [item setObject:thumbnail forKey:@"thumbnail"];
        }
        [items addObject:item];
    }
    return items;
}

- (NSArray *)stickerItemsForStickerSetID:(NSNumber *)stickerSetID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![stickerSetID respondsToSelector:@selector(longLongValue)] || [stickerSetID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"Sticker set identifier is missing." code:157];
        }
        return nil;
    }
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load a sticker set. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:158];
        }
        return nil;
    }

    NSUInteger safeLimit = limit;
    if (safeLimit == 0 || safeLimit > 120) {
        safeLimit = 80;
    }
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getStickerSet" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[stickerSetID longLongValue]] forKey:@"set_id"];

    NSError *setError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-sticker-set"
                                                           timeout:timeout
                                                         errorCode:159
                                                             error:&setError];
    if (!response) {
        if (error) {
            *error = setError ? setError : [self errorWithDescription:@"TDLib did not return the sticker set." code:159];
        }
        return nil;
    }
    id stickersObject = [response objectForKey:@"stickers"];
    if (![stickersObject isKindOfClass:[NSArray class]]) {
        return [NSArray array];
    }

    NSMutableArray *items = [NSMutableArray array];
    NSUInteger index = 0;
    NSUInteger downloadsRemaining = safeLimit;
    for (index = 0; index < [(NSArray *)stickersObject count] && [items count] < safeLimit; index++) {
        BOOL didRequestDownload = NO;
        NSDictionary *info = [self stickerPreviewInfoFromStickerObject:[(NSArray *)stickersObject objectAtIndex:index]
                                                       downloadMissing:(downloadsRemaining > 0)
                                                               timeout:1.0
                                                    didRequestDownload:&didRequestDownload];
        if (didRequestDownload && downloadsRemaining > 0) {
            downloadsRemaining--;
        }
        if ([info count] > 0) {
            [items addObject:info];
        }
    }
    return items;
}

- (BOOL)setStickerSetInstalledForStickerSetID:(NSNumber *)stickerSetID installed:(BOOL)installed timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![stickerSetID respondsToSelector:@selector(longLongValue)] || [stickerSetID longLongValue] == 0LL) {
        if (error) {
            *error = [self errorWithDescription:@"Sticker set identifier is missing." code:166];
        }
        return NO;
    }
    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to change sticker set installation. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:167];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"setStickerSetIsInstalled" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[stickerSetID longLongValue]] forKey:@"sticker_set_id"];
    [request setObject:[NSNumber numberWithBool:installed] forKey:@"is_installed"];

    NSError *changeError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-set-sticker-set-installed"
                                                           timeout:timeout
                                                         errorCode:168
                                                             error:&changeError];
    if (!response) {
        if (error) {
            *error = changeError ? changeError : [self errorWithDescription:@"TDLib did not confirm sticker set change." code:168];
        }
        return NO;
    }
    return YES;
}

- (NSString *)sendStickerMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind stickerFileID:(NSNumber *)stickerFileID emoji:(NSString *)emoji width:(NSNumber *)width height:(NSNumber *)height timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![stickerFileID respondsToSelector:@selector(integerValue)] || [stickerFileID integerValue] <= 0) {
        if (error) {
            *error = [self errorWithDescription:@"Sticker target or file identifier is missing." code:82];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send stickers. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:83];
        }
        return nil;
    }

    NSDictionary *inputFile = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"inputFileId", @"@type",
                               stickerFileID, @"id",
                               nil];
    NSMutableDictionary *content = [NSMutableDictionary dictionary];
    [content setObject:@"inputMessageSticker" forKey:@"@type"];
    [content setObject:inputFile forKey:@"sticker"];
    [content setObject:[NSNull null] forKey:@"thumbnail"];
    [content setObject:(width ? width : [NSNumber numberWithInt:0]) forKey:@"width"];
    [content setObject:(height ? height : [NSNumber numberWithInt:0]) forKey:@"height"];
    [content setObject:([emoji length] > 0 ? emoji : @"") forKey:@"emoji"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:content forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSDictionary *response = [self sendMessageRequest:request
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-send-sticker"
                                              timeout:timeout
                                            errorCode:84
                                                error:&sendError];
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm sticker send." code:84];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib sticker send returned an unexpected response." code:85];
        }
        return nil;
    }
    return @"sticker submitted";
}

- (NSString *)sendVoiceMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath duration:(NSNumber *)duration caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:86];
        }
        return nil;
    }
    if (![localPath isKindOfClass:[NSString class]] || [localPath length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Voice file path is missing." code:87];
        }
        return nil;
    }

    NSString *standardPath = [localPath stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardPath isDirectory:&isDirectory] || isDirectory) {
        if (error) {
            *error = [self errorWithDescription:@"Voice file does not exist." code:88];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send voice. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:89];
        }
        return nil;
    }

    NSDictionary *inputFile = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"inputFileLocal", @"@type",
                               standardPath, @"path",
                               nil];
    NSDictionary *formattedCaption = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"formattedText", @"@type",
                                      ([caption isKindOfClass:[NSString class]] ? caption : @""), @"text",
                                      [NSArray array], @"entities",
                                      nil];
    NSNumber *safeDuration = ([duration respondsToSelector:@selector(integerValue)] && [duration integerValue] > 0) ? duration : [NSNumber numberWithInt:0];

    NSMutableDictionary *voiceContent = [NSMutableDictionary dictionary];
    [voiceContent setObject:@"inputMessageVoiceNote" forKey:@"@type"];
    [voiceContent setObject:[self inputVoiceNoteForInputFile:inputFile duration:safeDuration] forKey:@"voice_note"];
    [voiceContent setObject:formattedCaption forKey:@"caption"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"sendMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:voiceContent forKey:@"input_message_content"];

    NSError *sendError = nil;
    NSDictionary *response = [self sendMessageRequest:request
                                      messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind
                                          extraPrefix:@"telegraphica-send-voice"
                                              timeout:timeout
                                            errorCode:90
                                                error:&sendError];
    if (!response) {
        NSMutableDictionary *legacyVoiceContent = [NSMutableDictionary dictionary];
        [legacyVoiceContent setObject:@"inputMessageVoiceNote" forKey:@"@type"];
        [legacyVoiceContent setObject:inputFile forKey:@"voice_note"];
        [legacyVoiceContent setObject:@"" forKey:@"waveform"];
        [legacyVoiceContent setObject:formattedCaption forKey:@"caption"];
        [legacyVoiceContent setObject:safeDuration forKey:@"duration"];

        NSMutableDictionary *legacyVoiceRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [legacyVoiceRequest setObject:legacyVoiceContent forKey:@"input_message_content"];
        response = [self sendMessageRequest:legacyVoiceRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-voice-legacy"
                                    timeout:timeout
                                  errorCode:90
                                      error:&sendError];
    }
    if (!response) {
        NSMutableDictionary *audioContent = [NSMutableDictionary dictionary];
        [audioContent setObject:@"inputMessageAudio" forKey:@"@type"];
        [audioContent setObject:[self inputAudioForInputFile:inputFile duration:safeDuration] forKey:@"audio"];
        [audioContent setObject:formattedCaption forKey:@"caption"];

        NSMutableDictionary *audioRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [audioRequest setObject:audioContent forKey:@"input_message_content"];
        response = [self sendMessageRequest:audioRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-audio-fallback"
                                    timeout:timeout
                                  errorCode:90
                                      error:&sendError];
    }
    if (!response) {
        NSMutableDictionary *audioContent = [NSMutableDictionary dictionary];
        [audioContent setObject:@"inputMessageAudio" forKey:@"@type"];
        [audioContent setObject:inputFile forKey:@"audio"];
        [audioContent setObject:[NSNull null] forKey:@"album_cover_thumbnail"];
        [audioContent setObject:safeDuration forKey:@"duration"];
        [audioContent setObject:@"" forKey:@"title"];
        [audioContent setObject:@"" forKey:@"performer"];
        [audioContent setObject:formattedCaption forKey:@"caption"];

        NSMutableDictionary *audioRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [audioRequest setObject:audioContent forKey:@"input_message_content"];
        response = [self sendMessageRequest:audioRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-audio-legacy-fallback"
                                    timeout:timeout
                                  errorCode:90
                                      error:&sendError];
    }
    if (!response) {
        NSMutableDictionary *documentContent = [NSMutableDictionary dictionary];
        [documentContent setObject:@"inputMessageDocument" forKey:@"@type"];
        [documentContent setObject:[self inputDocumentForInputFile:inputFile] forKey:@"document"];
        [documentContent setObject:formattedCaption forKey:@"caption"];

        NSMutableDictionary *documentRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [documentRequest setObject:documentContent forKey:@"input_message_content"];
        response = [self sendMessageRequest:documentRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-voice-document-fallback"
                                    timeout:timeout
                                  errorCode:90
                                      error:&sendError];
    }
    if (!response) {
        NSMutableDictionary *documentContent = [NSMutableDictionary dictionary];
        [documentContent setObject:@"inputMessageDocument" forKey:@"@type"];
        [documentContent setObject:inputFile forKey:@"document"];
        [documentContent setObject:[NSNull null] forKey:@"thumbnail"];
        [documentContent setObject:[NSNumber numberWithBool:NO] forKey:@"disable_content_type_detection"];
        [documentContent setObject:formattedCaption forKey:@"caption"];

        NSMutableDictionary *documentRequest = [NSMutableDictionary dictionaryWithDictionary:request];
        [documentRequest setObject:documentContent forKey:@"input_message_content"];
        response = [self sendMessageRequest:documentRequest
                            messageThreadID:messageThreadID
                           messageTopicKind:messageTopicKind
                                extraPrefix:@"telegraphica-send-voice-document-legacy-fallback"
                                    timeout:timeout
                                  errorCode:90
                                      error:&sendError];
    }
    if (!response) {
        if (error) {
            *error = sendError ? sendError : [self errorWithDescription:@"TDLib did not confirm voice/audio send." code:90];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib voice/audio send returned an unexpected response." code:91];
        }
        return nil;
    }
    return @"voice submitted";
}

- (NSDictionary *)messageActionCapabilitiesForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Message target is missing." code:92];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to inspect message actions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:93];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getMessage" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"message_id"];

    NSError *messageError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-message-actions"
                                                           timeout:timeout
                                                         errorCode:94
                                                             error:&messageError];
    NSDictionary *capabilities = TGTDLibMessageCapabilitiesFromObject(response);
    if (capabilities) {
        return capabilities;
    }

    NSMutableDictionary *propertiesRequest = [NSMutableDictionary dictionary];
    [propertiesRequest setObject:@"getMessageProperties" forKey:@"@type"];
    [propertiesRequest setObject:chatID forKey:@"chat_id"];
    [propertiesRequest setObject:messageID forKey:@"message_id"];
    NSError *propertiesError = nil;
    NSDictionary *propertiesResponse = [self sendTDLibRequestAndWaitForExtra:propertiesRequest
                                                                  extraPrefix:@"telegraphica-message-properties"
                                                                      timeout:timeout
                                                                    errorCode:95
                                                                        error:&propertiesError];
    capabilities = TGTDLibMessageCapabilitiesFromObject(propertiesResponse);
    if (capabilities) {
        return capabilities;
    }

    if (error) {
        *error = messageError ? messageError : (propertiesError ? propertiesError : [self errorWithDescription:@"TDLib did not provide message action capabilities." code:95]);
    }
    return nil;
}

- (NSString *)editTextMessageInChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Message target is missing." code:96];
        }
        return nil;
    }
    if (![text isKindOfClass:[NSString class]] || [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Edited message text is empty." code:97];
        }
        return nil;
    }
    if ([text length] > 4096) {
        if (error) {
            *error = [self errorWithDescription:@"Edited message text is too long." code:98];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to edit messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:99];
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
    [content setObject:[NSNumber numberWithBool:NO] forKey:@"clear_draft"];

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"editMessageText" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"message_id"];
    [request setObject:[NSNull null] forKey:@"reply_markup"];
    [request setObject:content forKey:@"input_message_content"];

    NSError *editError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-edit-message-text"
                                                           timeout:timeout
                                                         errorCode:100
                                                             error:&editError];
    if (!response) {
        if (error) {
            *error = editError ? editError : [self errorWithDescription:@"TDLib did not confirm message edit." code:100];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"message"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib message edit returned an unexpected response." code:101];
        }
        return nil;
    }
    return @"message edited";
}

- (NSString *)deleteMessagesInChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs revoke:(BOOL)revoke timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Chat identifier is missing." code:102];
        }
        return nil;
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
        if (error) {
            *error = [self errorWithDescription:@"Message identifier is missing." code:103];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to delete messages. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:104];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"deleteMessages" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:safeMessageIDs forKey:@"message_ids"];
    [request setObject:[NSNumber numberWithBool:revoke] forKey:@"revoke"];

    NSError *deleteError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-delete-messages"
                                                           timeout:timeout
                                                         errorCode:105
                                                             error:&deleteError];
    if (!response) {
        if (error) {
            *error = deleteError ? deleteError : [self errorWithDescription:@"TDLib did not confirm message deletion." code:105];
        }
        return nil;
    }
    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib message deletion returned an unexpected response." code:106];
        }
        return nil;
    }
    return @"messages deleted";
}

- (NSString *)addReactionToChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Message target is missing." code:69];
        }
        return nil;
    }
    if (![emoji isKindOfClass:[NSString class]] || [emoji length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Reaction emoji is missing." code:70];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to send reactions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:71];
        }
        return nil;
    }

    NSDictionary *reactionType = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"reactionTypeEmoji", @"@type",
                                  emoji, @"emoji",
                                  nil];
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"addMessageReaction" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"message_id"];
    [request setObject:reactionType forKey:@"reaction_type"];
    [request setObject:[NSNumber numberWithBool:YES] forKey:@"is_big"];
    [request setObject:[NSNumber numberWithBool:YES] forKey:@"update_recent_reactions"];

    NSError *reactionError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-add-reaction"
                                                           timeout:timeout
                                                         errorCode:72
                                                             error:&reactionError];
    if (!response) {
        if (error) {
            *error = reactionError ? reactionError : [self errorWithDescription:@"TDLib did not accept the reaction request. This TDLib build may not support message reactions." code:72];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib reaction request returned an unexpected response." code:73];
        }
        return nil;
    }
    return @"reaction submitted";
}

- (NSString *)removeReactionFromChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![messageID respondsToSelector:@selector(longLongValue)]) {
        if (error) {
            *error = [self errorWithDescription:@"Message target is missing." code:74];
        }
        return nil;
    }
    if (![emoji isKindOfClass:[NSString class]] || [emoji length] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"Reaction emoji is missing." code:75];
        }
        return nil;
    }

    NSString *authorizationState = [self currentAuthorizationStatePreparingIfNeededWithTimeout:timeout error:error];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to remove reactions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:76];
        }
        return nil;
    }

    NSDictionary *reactionType = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"reactionTypeEmoji", @"@type",
                                  emoji, @"emoji",
                                  nil];
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"removeMessageReaction" forKey:@"@type"];
    [request setObject:chatID forKey:@"chat_id"];
    [request setObject:messageID forKey:@"message_id"];
    [request setObject:reactionType forKey:@"reaction_type"];

    NSError *reactionError = nil;
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                       extraPrefix:@"telegraphica-remove-reaction"
                                                           timeout:timeout
                                                         errorCode:77
                                                             error:&reactionError];
    if (!response) {
        if (error) {
            *error = reactionError ? reactionError : [self errorWithDescription:@"TDLib did not accept the remove reaction request. This TDLib build may not support removing message reactions." code:77];
        }
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"ok"]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib remove reaction request returned an unexpected response." code:78];
        }
        return nil;
    }
    return @"reaction removed";
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

- (NSDictionary *)activeSessionsSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self cachedAuthorizationStateSummary];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to load active sessions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:92];
        }
        return nil;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"getActiveSessions" forKey:@"@type"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-active-sessions"
                                                            timeout:timeout
                                                          errorCode:93
                                                              error:error];
    if (!response) {
        return nil;
    }

    id responseType = [response objectForKey:@"@type"];
    id sessionsObject = [response objectForKey:@"sessions"];
    id inactiveSessionTTLDays = [response objectForKey:@"inactive_session_ttl_days"];
    if (![responseType isKindOfClass:[NSString class]] || ![(NSString *)responseType isEqualToString:@"sessions"] ||
        ![sessionsObject isKindOfClass:[NSArray class]]) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib getActiveSessions returned an unexpected response." code:93];
        }
        return nil;
    }

    NSArray *numberKeys = [NSArray arrayWithObjects:@"id", @"session_id", @"last_active_date", nil];
    NSArray *booleanKeys = [NSArray arrayWithObjects:@"is_current", nil];
    NSArray *stringKeys = [NSArray arrayWithObjects:@"application_name", @"application_version", @"device_model", @"platform", @"system_version", @"location", nil];
    NSMutableArray *safeSessions = [NSMutableArray arrayWithCapacity:[(NSArray *)sessionsObject count]];
    NSUInteger sessionIndex = 0;
    for (sessionIndex = 0; sessionIndex < [(NSArray *)sessionsObject count]; sessionIndex++) {
        id sessionObject = [(NSArray *)sessionsObject objectAtIndex:sessionIndex];
        if (![sessionObject isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *message = [NSString stringWithFormat:@"TDLib getActiveSessions returned a non-dictionary session at index %lu.", (unsigned long)sessionIndex];
                *error = [self errorWithDescription:message code:93];
            }
            return nil;
        }

        NSDictionary *session = (NSDictionary *)sessionObject;
        NSMutableDictionary *safeSession = [NSMutableDictionary dictionary];
        NSUInteger keyIndex = 0;
        for (keyIndex = 0; keyIndex < [numberKeys count]; keyIndex++) {
            NSString *key = [numberKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            long long numberValue = 0;
            BOOL hasNumberValue = NO;
            if ([value isKindOfClass:[NSNumber class]] && !TGTDLibObjectIsBoolean(value)) {
                numberValue = [value longLongValue];
                hasNumberValue = YES;
            } else if ([value isKindOfClass:[NSString class]]) {
                NSString *stringValue = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([stringValue length] > 0) {
                    NSScanner *scanner = [NSScanner scannerWithString:stringValue];
                    long long scannedValue = 0;
                    if ([scanner scanLongLong:&scannedValue] && [scanner isAtEnd]) {
                        numberValue = scannedValue;
                        hasNumberValue = YES;
                    }
                }
            }
            if (!hasNumberValue) {
                continue;
            }
            [safeSession setObject:[NSNumber numberWithLongLong:numberValue] forKey:key];
        }
        for (keyIndex = 0; keyIndex < [booleanKeys count]; keyIndex++) {
            NSString *key = [booleanKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            if (!TGTDLibObjectIsBoolean(value)) {
                continue;
            }
            [safeSession setObject:[NSNumber numberWithBool:[value boolValue]] forKey:key];
        }
        for (keyIndex = 0; keyIndex < [stringKeys count]; keyIndex++) {
            NSString *key = [stringKeys objectAtIndex:keyIndex];
            id value = [session objectForKey:key];
            if (![value isKindOfClass:[NSString class]]) {
                continue;
            }
            [safeSession setObject:value forKey:key];
        }
        if (![[safeSession objectForKey:@"location"] length]) {
            NSMutableArray *locationParts = [NSMutableArray array];
            id region = [session objectForKey:@"region"];
            id country = [session objectForKey:@"country"];
            if ([region isKindOfClass:[NSString class]] && [(NSString *)region length] > 0) {
                [locationParts addObject:region];
            }
            if ([country isKindOfClass:[NSString class]] && [(NSString *)country length] > 0 &&
                ![country isEqual:region]) {
                [locationParts addObject:country];
            }
            if ([locationParts count] > 0) {
                [safeSession setObject:[locationParts componentsJoinedByString:@", "] forKey:@"location"];
            }
        }
        [safeSessions addObject:[NSDictionary dictionaryWithDictionary:safeSession]];
    }

    NSMutableDictionary *safeSummary = [NSMutableDictionary dictionaryWithObject:[NSArray arrayWithArray:safeSessions]
                                                                           forKey:@"sessions"];
    if ([inactiveSessionTTLDays isKindOfClass:[NSNumber class]] &&
        !TGTDLibObjectIsBoolean(inactiveSessionTTLDays)) {
        [safeSummary setObject:[NSNumber numberWithInteger:[inactiveSessionTTLDays integerValue]]
                        forKey:@"inactive_session_ttl_days"];
    } else if ([inactiveSessionTTLDays isKindOfClass:[NSString class]]) {
        NSString *ttlString = [(NSString *)inactiveSessionTTLDays stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSScanner *ttlScanner = [NSScanner scannerWithString:ttlString];
        NSInteger ttlValue = 0;
        if ([ttlScanner scanInteger:&ttlValue] && [ttlScanner isAtEnd]) {
            [safeSummary setObject:[NSNumber numberWithInteger:ttlValue]
                            forKey:@"inactive_session_ttl_days"];
        }
    }
    return [NSDictionary dictionaryWithDictionary:safeSummary];
}

- (BOOL)terminateActiveSessionWithID:(NSNumber *)sessionID timeout:(NSTimeInterval)timeout error:(NSError **)error {
    NSString *authorizationState = [self cachedAuthorizationStateSummary];
    if (![authorizationState isEqualToString:@"ready"]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"TDLib is not ready to terminate active sessions. Current auth state: %@", authorizationState ? authorizationState : @"unknown"];
            *error = [self errorWithDescription:message code:94];
        }
        return NO;
    }
    if (![sessionID respondsToSelector:@selector(longLongValue)] || [sessionID longLongValue] == 0) {
        if (error) {
            *error = [self errorWithDescription:@"TDLib terminateSession requires a valid session id." code:94];
        }
        return NO;
    }

    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    [request setObject:@"terminateSession" forKey:@"@type"];
    [request setObject:[NSNumber numberWithLongLong:[sessionID longLongValue]] forKey:@"session_id"];
    NSDictionary *response = [self sendTDLibRequestAndWaitForExtra:request
                                                        extraPrefix:@"telegraphica-terminate-session"
                                                            timeout:timeout
                                                          errorCode:94
                                                              error:error];
    if (!response) {
        return NO;
    }

    id responseType = [response objectForKey:@"@type"];
    if ([responseType isKindOfClass:[NSString class]] && [(NSString *)responseType isEqualToString:@"ok"]) {
        return YES;
    }
    if (error) {
        *error = [self errorWithDescription:@"TDLib terminateSession returned an unexpected response." code:94];
    }
    return NO;
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
