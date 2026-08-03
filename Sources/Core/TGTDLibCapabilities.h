#import <Foundation/Foundation.h>

typedef enum {
    TGTDLibLaneUnknown = 0,
    TGTDLibLaneMountainLionFallback = 1,
    TGTDLibLaneMavericksOrNewer = 2
} TGTDLibLane;

typedef enum {
    TGTDLibCapabilityStateUnknown = 0,
    TGTDLibCapabilityStateSupported = 1,
    TGTDLibCapabilityStateUnsupported = 2,
    TGTDLibCapabilityStateForbidden = 3,
    TGTDLibCapabilityStateTemporarilyUnavailable = 4
} TGTDLibCapabilityState;

extern NSString * const TGTDLibCapabilityQRCodeAuthentication;
extern NSString * const TGTDLibCapabilityEmailAuthentication;
extern NSString * const TGTDLibCapabilityRegistration;
extern NSString * const TGTDLibCapabilityPasswordRecovery;
extern NSString * const TGTDLibCapabilityAvailableReactions;
extern NSString * const TGTDLibCapabilityCustomEmoji;
extern NSString * const TGTDLibCapabilityModernTextEntities;
extern NSString * const TGTDLibCapabilityChatFolderManagement;
extern NSString * const TGTDLibCapabilitySharedChatFolders;
extern NSString * const TGTDLibCapabilityForumTopics;
extern NSString * const TGTDLibCapabilitySecretChatTTL;
extern NSString * const TGTDLibCapabilityStreamingMedia;
extern NSString * const TGTDLibCapabilityRecurringMessages;
extern NSString * const TGTDLibCapabilityChecklists;
extern NSString * const TGTDLibCapabilityHDPhotos;
extern NSString * const TGTDLibCapabilityVoiceTrimming;
extern NSString * const TGTDLibCapabilityStoriesViewer;
extern NSString * const TGTDLibCapabilityGroupCalls;
extern NSString * const TGTDLibCapabilityMiniApps;

@interface TGTDLibCapabilities : NSObject {
@private
    NSLock *_lock;
    NSMutableDictionary *_entries;
    NSString *_loadedLibraryPath;
    NSString *_tdlibVersion;
    NSString *_tdlibCommit;
    NSNumber *_mtprotoLayer;
    TGTDLibLane _lane;
}

- (id)initWithLoadedLibraryPath:(NSString *)loadedLibraryPath;
- (void)updateLoadedLibraryPath:(NSString *)loadedLibraryPath;

- (TGTDLibLane)lane;
- (NSString *)laneName;
- (NSString *)loadedLibraryPath;
- (NSString *)tdlibVersion;
- (NSString *)tdlibCommit;
- (NSNumber *)mtprotoLayer;
- (void)recordTDLibVersion:(NSString *)version commit:(NSString *)commit mtprotoLayer:(NSNumber *)mtprotoLayer;

- (void)recordProbeResponse:(NSDictionary *)response
                      error:(NSError *)error
              forCapability:(NSString *)capability
                     source:(NSString *)source;
- (void)recordCapability:(NSString *)capability
             supportState:(TGTDLibCapabilityState)supportState
            lastProbeState:(TGTDLibCapabilityState)lastProbeState
                    reason:(NSString *)reason
                    source:(NSString *)source;

- (TGTDLibCapabilityState)supportStateForCapability:(NSString *)capability;
- (TGTDLibCapabilityState)lastProbeStateForCapability:(NSString *)capability;
- (BOOL)supportsCapability:(NSString *)capability;
- (BOOL)hasCachedProbeForCapability:(NSString *)capability;
- (NSString *)reasonForCapability:(NSString *)capability;
- (NSDictionary *)detailsForCapability:(NSString *)capability;
- (NSDictionary *)snapshot;
- (NSString *)diagnosticSummary;

+ (NSArray *)knownCapabilityIdentifiers;
+ (NSString *)capabilityIdentifierForRequestType:(NSString *)requestType;
+ (NSString *)nameForCapabilityState:(TGTDLibCapabilityState)state;
+ (NSString *)nameForLane:(TGTDLibLane)lane;

@end
