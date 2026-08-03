#import "TGTDLibCapabilities.h"

NSString * const TGTDLibCapabilityQRCodeAuthentication = @"authorization.qr";
NSString * const TGTDLibCapabilityEmailAuthentication = @"authorization.email";
NSString * const TGTDLibCapabilityRegistration = @"authorization.registration";
NSString * const TGTDLibCapabilityPasswordRecovery = @"authorization.password_recovery";
NSString * const TGTDLibCapabilityAvailableReactions = @"messages.available_reactions";
NSString * const TGTDLibCapabilityAddedReactionUsers = @"messages.added_reaction_users";
NSString * const TGTDLibCapabilityCustomEmoji = @"messages.custom_emoji";
NSString * const TGTDLibCapabilityModernTextEntities = @"messages.modern_text_entities";
NSString * const TGTDLibCapabilityChatFolderManagement = @"chat_folders.management";
NSString * const TGTDLibCapabilitySharedChatFolders = @"chat_folders.shared";
NSString * const TGTDLibCapabilityForumTopics = @"forums.topics";
NSString * const TGTDLibCapabilitySecretChatTTL = @"secret_chats.ttl";
NSString * const TGTDLibCapabilityStreamingMedia = @"media.streaming_resume";
NSString * const TGTDLibCapabilityRecurringMessages = @"messages.recurring";
NSString * const TGTDLibCapabilityChecklists = @"messages.checklists";
NSString * const TGTDLibCapabilityHDPhotos = @"media.hd_photos";
NSString * const TGTDLibCapabilityVoiceTrimming = @"media.voice_trimming";
NSString * const TGTDLibCapabilityStoriesViewer = @"stories.viewer";
NSString * const TGTDLibCapabilityGroupCalls = @"calls.group";
NSString * const TGTDLibCapabilityMiniApps = @"bots.mini_apps";

static NSString * const TGTDLibCapabilitySupportStateKey = @"support_state";
static NSString * const TGTDLibCapabilityLastProbeStateKey = @"last_probe_state";
static NSString * const TGTDLibCapabilityReasonKey = @"reason";
static NSString * const TGTDLibCapabilitySourceKey = @"source";
static NSString * const TGTDLibCapabilityProbeCachedKey = @"probe_cached";

static NSString *TGTDLibSafeCapabilityText(id value) {
    if (![value isKindOfClass:[NSString class]]) {
        return @"";
    }
    NSString *text = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *parts = [text componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    text = [parts componentsJoinedByString:@" "];
    while ([text rangeOfString:@"  "].location != NSNotFound) {
        text = [text stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    if ([text length] > 240) {
        text = [[text substringToIndex:237] stringByAppendingString:@"..."];
    }
    return text;
}

static BOOL TGTDLibCapabilityMessageContainsAny(NSString *message, NSArray *needles) {
    NSString *lowercase = [message lowercaseString];
    NSUInteger index = 0;
    for (index = 0; index < [needles count]; index++) {
        if ([lowercase rangeOfString:[needles objectAtIndex:index]].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static TGTDLibCapabilityState TGTDLibProbeStateForError(NSInteger code, NSString *message) {
    if (code == 403 || TGTDLibCapabilityMessageContainsAny(message, [NSArray arrayWithObjects:
            @"chat_admin_required", @"not enough rights", @"have no access", @"access denied",
            @"forbidden", @"not allowed for this chat", nil])) {
        return TGTDLibCapabilityStateForbidden;
    }

    if (TGTDLibCapabilityMessageContainsAny(message, [NSArray arrayWithObjects:
            @"unknown request", @"unknown function", @"method not found", @"not supported",
            @"unsupported", @"can't parse request", @"cannot parse request", @"unexpected @type",
            @"unknown class", nil])) {
        return TGTDLibCapabilityStateUnsupported;
    }

    if (code == 429 || code >= 500 || TGTDLibCapabilityMessageContainsAny(message, [NSArray arrayWithObjects:
            @"timeout", @"timed out", @"temporarily unavailable", @"network", @"flood_wait",
            @"too many requests", @"connection", @"did not return", nil])) {
        return TGTDLibCapabilityStateTemporarilyUnavailable;
    }

    return TGTDLibCapabilityStateTemporarilyUnavailable;
}

@implementation TGTDLibCapabilities

- (id)initWithLoadedLibraryPath:(NSString *)loadedLibraryPath {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _entries = [[NSMutableDictionary alloc] init];
        [self updateLoadedLibraryPath:loadedLibraryPath];

        NSArray *identifiers = [[self class] knownCapabilityIdentifiers];
        NSUInteger index = 0;
        for (index = 0; index < [identifiers count]; index++) {
            NSString *identifier = [identifiers objectAtIndex:index];
            NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInteger:TGTDLibCapabilityStateUnknown], TGTDLibCapabilitySupportStateKey,
                                   [NSNumber numberWithInteger:TGTDLibCapabilityStateUnknown], TGTDLibCapabilityLastProbeStateKey,
                                   @"No safe runtime probe has completed.", TGTDLibCapabilityReasonKey,
                                   @"initial", TGTDLibCapabilitySourceKey,
                                   [NSNumber numberWithBool:NO], TGTDLibCapabilityProbeCachedKey,
                                   nil];
            [_entries setObject:entry forKey:identifier];
        }
    }
    return self;
}

- (void)dealloc {
    [_lock release];
    [_entries release];
    [_loadedLibraryPath release];
    [_tdlibVersion release];
    [_tdlibCommit release];
    [_buildStatus release];
    [_mtprotoLayer release];
    [super dealloc];
}

- (void)updateLoadedLibraryPath:(NSString *)loadedLibraryPath {
    NSString *safePath = [loadedLibraryPath isKindOfClass:[NSString class]] ? loadedLibraryPath : @"";
    TGTDLibLane lane = TGTDLibLaneUnknown;
    if ([safePath length] > 0) {
        NSString *lowercase = [safePath lowercaseString];
        lane = ([lowercase rangeOfString:@"mountain-lion"].location != NSNotFound)
            ? TGTDLibLaneMountainLionFallback : TGTDLibLaneMavericksOrNewer;
    }

    [_lock lock];
    [_loadedLibraryPath release];
    _loadedLibraryPath = [safePath copy];
    _lane = lane;
    [_lock unlock];
}

- (TGTDLibLane)lane {
    [_lock lock];
    TGTDLibLane lane = _lane;
    [_lock unlock];
    return lane;
}

- (NSString *)laneName {
    return [[self class] nameForLane:[self lane]];
}

- (NSString *)loadedLibraryPath {
    [_lock lock];
    NSString *value = [_loadedLibraryPath copy];
    [_lock unlock];
    return [value autorelease];
}

- (NSString *)tdlibVersion {
    [_lock lock];
    NSString *value = [_tdlibVersion copy];
    [_lock unlock];
    return [value autorelease];
}

- (NSString *)tdlibCommit {
    [_lock lock];
    NSString *value = [_tdlibCommit copy];
    [_lock unlock];
    return [value autorelease];
}

- (NSNumber *)mtprotoLayer {
    [_lock lock];
    NSNumber *value = [_mtprotoLayer retain];
    [_lock unlock];
    return [value autorelease];
}

- (NSString *)buildStatus {
    [_lock lock];
    NSString *value = [_buildStatus copy];
    [_lock unlock];
    return [value autorelease];
}

- (void)recordTDLibVersion:(NSString *)version
                    commit:(NSString *)commit
              mtprotoLayer:(NSNumber *)mtprotoLayer
               buildStatus:(NSString *)buildStatus {
    NSString *safeVersion = TGTDLibSafeCapabilityText(version);
    NSString *safeCommit = TGTDLibSafeCapabilityText(commit);
    NSString *safeBuildStatus = TGTDLibSafeCapabilityText(buildStatus);
    NSNumber *safeLayer = [mtprotoLayer respondsToSelector:@selector(integerValue)] ? mtprotoLayer : nil;

    [_lock lock];
    [_tdlibVersion release];
    _tdlibVersion = [safeVersion length] > 0 ? [safeVersion copy] : nil;
    [_tdlibCommit release];
    _tdlibCommit = [safeCommit length] > 0 ? [safeCommit copy] : nil;
    [_buildStatus release];
    _buildStatus = [safeBuildStatus length] > 0 ? [safeBuildStatus copy] : nil;
    [_mtprotoLayer release];
    _mtprotoLayer = [safeLayer retain];
    [_lock unlock];
}

- (void)recordProbeResponse:(NSDictionary *)response
                      error:(NSError *)error
              forCapability:(NSString *)capability
                     source:(NSString *)source {
    if (![capability isKindOfClass:[NSString class]] || [capability length] == 0) {
        return;
    }

    TGTDLibCapabilityState probeState = TGTDLibCapabilityStateTemporarilyUnavailable;
    NSString *reason = @"The capability probe returned no response.";
    NSString *type = [response isKindOfClass:[NSDictionary class]] ? [response objectForKey:@"@type"] : nil;
    if ([type isKindOfClass:[NSString class]] && ![type isEqualToString:@"error"]) {
        probeState = TGTDLibCapabilityStateSupported;
        reason = @"The loaded TDLib accepted the request.";
    } else {
        NSInteger code = 0;
        NSString *message = nil;
        id codeObject = [response objectForKey:@"code"];
        if ([codeObject respondsToSelector:@selector(integerValue)]) {
            code = [codeObject integerValue];
        }
        id messageObject = [response objectForKey:@"message"];
        if ([messageObject isKindOfClass:[NSString class]]) {
            message = messageObject;
        }
        if ([message length] == 0 && error) {
            message = [error localizedDescription];
        }
        probeState = TGTDLibProbeStateForError(code, message ? message : @"");
        reason = [message length] > 0 ? message : reason;
    }

    TGTDLibCapabilityState supportState = TGTDLibCapabilityStateUnknown;
    if (probeState == TGTDLibCapabilityStateSupported || probeState == TGTDLibCapabilityStateForbidden) {
        supportState = TGTDLibCapabilityStateSupported;
    } else if (probeState == TGTDLibCapabilityStateUnsupported) {
        supportState = TGTDLibCapabilityStateUnsupported;
    } else {
        supportState = [self supportStateForCapability:capability];
    }
    [self recordCapability:capability
              supportState:supportState
             lastProbeState:probeState
                     reason:reason
                     source:source];
}

- (void)recordCapability:(NSString *)capability
             supportState:(TGTDLibCapabilityState)supportState
            lastProbeState:(TGTDLibCapabilityState)lastProbeState
                    reason:(NSString *)reason
                    source:(NSString *)source {
    if (![capability isKindOfClass:[NSString class]] || [capability length] == 0) {
        return;
    }
    NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithInteger:supportState], TGTDLibCapabilitySupportStateKey,
                           [NSNumber numberWithInteger:lastProbeState], TGTDLibCapabilityLastProbeStateKey,
                           TGTDLibSafeCapabilityText(reason), TGTDLibCapabilityReasonKey,
                           TGTDLibSafeCapabilityText(source), TGTDLibCapabilitySourceKey,
                           [NSNumber numberWithBool:YES], TGTDLibCapabilityProbeCachedKey,
                           nil];
    [_lock lock];
    [_entries setObject:entry forKey:capability];
    [_lock unlock];
}

- (TGTDLibCapabilityState)supportStateForCapability:(NSString *)capability {
    NSDictionary *details = [self detailsForCapability:capability];
    id value = [details objectForKey:TGTDLibCapabilitySupportStateKey];
    return [value respondsToSelector:@selector(integerValue)]
        ? (TGTDLibCapabilityState)[value integerValue] : TGTDLibCapabilityStateUnknown;
}

- (TGTDLibCapabilityState)lastProbeStateForCapability:(NSString *)capability {
    NSDictionary *details = [self detailsForCapability:capability];
    id value = [details objectForKey:TGTDLibCapabilityLastProbeStateKey];
    return [value respondsToSelector:@selector(integerValue)]
        ? (TGTDLibCapabilityState)[value integerValue] : TGTDLibCapabilityStateUnknown;
}

- (BOOL)supportsCapability:(NSString *)capability {
    return [self supportStateForCapability:capability] == TGTDLibCapabilityStateSupported;
}

- (BOOL)hasCachedProbeForCapability:(NSString *)capability {
    return [[[self detailsForCapability:capability] objectForKey:TGTDLibCapabilityProbeCachedKey] boolValue];
}

- (NSString *)reasonForCapability:(NSString *)capability {
    id value = [[self detailsForCapability:capability] objectForKey:TGTDLibCapabilityReasonKey];
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

- (NSDictionary *)detailsForCapability:(NSString *)capability {
    if (![capability isKindOfClass:[NSString class]]) {
        return [NSDictionary dictionary];
    }
    [_lock lock];
    NSDictionary *details = [[_entries objectForKey:capability] copy];
    [_lock unlock];
    return details ? [details autorelease] : [NSDictionary dictionary];
}

- (NSDictionary *)snapshot {
    [_lock lock];
    NSDictionary *snapshot = [[NSDictionary alloc] initWithDictionary:_entries copyItems:YES];
    [_lock unlock];
    return [snapshot autorelease];
}

- (NSString *)diagnosticSummary {
    NSDictionary *snapshot = [self snapshot];
    NSUInteger supported = 0;
    NSUInteger unsupported = 0;
    NSUInteger unresolved = 0;
    NSEnumerator *enumerator = [snapshot objectEnumerator];
    NSDictionary *entry = nil;
    while ((entry = [enumerator nextObject])) {
        TGTDLibCapabilityState state = (TGTDLibCapabilityState)[[entry objectForKey:TGTDLibCapabilitySupportStateKey] integerValue];
        if (state == TGTDLibCapabilityStateSupported) {
            supported++;
        } else if (state == TGTDLibCapabilityStateUnsupported) {
            unsupported++;
        } else {
            unresolved++;
        }
    }
    return [NSString stringWithFormat:@"lane=%@; build=%@; version=%@; commit=%@; layer=%@; supported=%lu; unsupported=%lu; unresolved=%lu",
            [self laneName],
            [self buildStatus] ? [self buildStatus] : @"unknown",
            [self tdlibVersion] ? [self tdlibVersion] : @"unknown",
            [self tdlibCommit] ? [self tdlibCommit] : @"unknown",
            [self mtprotoLayer] ? [[self mtprotoLayer] stringValue] : @"unknown",
            (unsigned long)supported,
            (unsigned long)unsupported,
            (unsigned long)unresolved];
}

+ (NSArray *)knownCapabilityIdentifiers {
    return [NSArray arrayWithObjects:
            TGTDLibCapabilityQRCodeAuthentication,
            TGTDLibCapabilityEmailAuthentication,
            TGTDLibCapabilityRegistration,
            TGTDLibCapabilityPasswordRecovery,
            TGTDLibCapabilityAvailableReactions,
            TGTDLibCapabilityAddedReactionUsers,
            TGTDLibCapabilityCustomEmoji,
            TGTDLibCapabilityModernTextEntities,
            TGTDLibCapabilityChatFolderManagement,
            TGTDLibCapabilitySharedChatFolders,
            TGTDLibCapabilityForumTopics,
            TGTDLibCapabilitySecretChatTTL,
            TGTDLibCapabilityStreamingMedia,
            TGTDLibCapabilityRecurringMessages,
            TGTDLibCapabilityChecklists,
            TGTDLibCapabilityHDPhotos,
            TGTDLibCapabilityVoiceTrimming,
            TGTDLibCapabilityStoriesViewer,
            TGTDLibCapabilityGroupCalls,
            TGTDLibCapabilityMiniApps,
            nil];
}

+ (NSString *)capabilityIdentifierForRequestType:(NSString *)requestType {
    if (![requestType isKindOfClass:[NSString class]]) {
        return nil;
    }
    static NSDictionary *mapping = nil;
    if (!mapping) {
        @synchronized(self) {
            if (!mapping) {
                mapping = [[NSDictionary alloc] initWithObjectsAndKeys:
                    TGTDLibCapabilityQRCodeAuthentication, @"requestQrCodeAuthentication",
                    TGTDLibCapabilityEmailAuthentication, @"setAuthenticationEmailAddress",
                    TGTDLibCapabilityEmailAuthentication, @"checkAuthenticationEmailCode",
                    TGTDLibCapabilityRegistration, @"registerUser",
                    TGTDLibCapabilityPasswordRecovery, @"requestAuthenticationPasswordRecovery",
                    TGTDLibCapabilityPasswordRecovery, @"checkAuthenticationPasswordRecoveryCode",
                    TGTDLibCapabilityPasswordRecovery, @"recoverAuthenticationPassword",
                    TGTDLibCapabilityAvailableReactions, @"getMessageAvailableReactions",
                    TGTDLibCapabilityAddedReactionUsers, @"getMessageAddedReactions",
                    TGTDLibCapabilityCustomEmoji, @"getCustomEmojiStickers",
                    TGTDLibCapabilityModernTextEntities, @"getTextEntities",
                    TGTDLibCapabilityModernTextEntities, @"parseTextEntities",
                    TGTDLibCapabilityChatFolderManagement, @"getChatFolder",
                    TGTDLibCapabilityChatFolderManagement, @"getChatFilter",
                    TGTDLibCapabilityChatFolderManagement, @"createChatFolder",
                    TGTDLibCapabilityChatFolderManagement, @"createChatFilter",
                    TGTDLibCapabilitySharedChatFolders, @"checkChatFolderInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"addChatFolderByInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"createChatFolderInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"getChatFolderInviteLinks",
                    TGTDLibCapabilitySharedChatFolders, @"getChatsForChatFolderInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"editChatFolderInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"deleteChatFolderInviteLink",
                    TGTDLibCapabilitySharedChatFolders, @"getChatFolderNewChats",
                    TGTDLibCapabilitySharedChatFolders, @"processChatFolderNewChats",
                    TGTDLibCapabilitySharedChatFolders, @"getRecommendedChatFolders",
                    TGTDLibCapabilityForumTopics, @"getForumTopics",
                    TGTDLibCapabilityForumTopics, @"createForumTopic",
                    TGTDLibCapabilitySecretChatTTL, @"getSecretChat",
                    TGTDLibCapabilitySecretChatTTL, @"setChatMessageAutoDeleteTime",
                    TGTDLibCapabilitySecretChatTTL, @"closeSecretChat",
                    TGTDLibCapabilityChecklists, @"sendChecklist",
                    TGTDLibCapabilityVoiceTrimming, @"sendVoiceNoteWithTrim",
                    TGTDLibCapabilityStoriesViewer, @"getChatActiveStories",
                    TGTDLibCapabilityStoriesViewer, @"getStory",
                    TGTDLibCapabilityGroupCalls, @"createVoiceChat",
                    TGTDLibCapabilityGroupCalls, @"joinGroupCall",
                    TGTDLibCapabilityMiniApps, @"openWebApp",
                    TGTDLibCapabilityMiniApps, @"getWebAppLinkUrl",
                    nil];
            }
        }
    }
    return [mapping objectForKey:requestType];
}

+ (NSString *)nameForCapabilityState:(TGTDLibCapabilityState)state {
    switch (state) {
        case TGTDLibCapabilityStateSupported: return @"supported";
        case TGTDLibCapabilityStateUnsupported: return @"unsupported";
        case TGTDLibCapabilityStateForbidden: return @"forbidden";
        case TGTDLibCapabilityStateTemporarilyUnavailable: return @"temporarily_unavailable";
        default: return @"unknown";
    }
}

+ (NSString *)nameForLane:(TGTDLibLane)lane {
    switch (lane) {
        case TGTDLibLaneMountainLionFallback: return @"mountain_lion_fallback";
        case TGTDLibLaneMavericksOrNewer: return @"mavericks_or_newer";
        default: return @"unknown";
    }
}

@end
