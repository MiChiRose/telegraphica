#import <Foundation/Foundation.h>

@class TGMessageItem;

extern NSString * const TGTDLibChatFiltersDidChangeNotification;

@interface TGTDLibClient : NSObject

- (BOOL)loadLibraryWithError:(NSError **)error;
- (NSString *)tdlibProbeSummaryWithError:(NSError **)error;
- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)localTDLibConfigurationPathWithError:(NSError **)error;
- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)prepareAuthorizationFlowWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)postLoginProbeSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)activeSessionsSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)chatFilterInfoItemsWithTimeout:(NSTimeInterval)timeout;
- (NSDictionary *)chatSummaryForChatID:(NSNumber *)chatID downloadAvatar:(BOOL)downloadAvatar timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)mainChatPreviewItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)chatPreviewItemsForChatFilterID:(NSNumber *)filterID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout exhausted:(BOOL *)exhausted error:(NSError **)error;
- (BOOL)mainChatListExhausted;
- (void)invalidateMainChatListExhaustion;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)forumTopicPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)threadPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)searchMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind query:(NSString *)query filter:(NSString *)filter fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)globalSearchMessagePreviewItemsWithQuery:(NSString *)query filter:(NSString *)filter offset:(NSString **)offset limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (TGMessageItem *)messagePreviewItemForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messageContextPreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind centerMessageID:(NSNumber *)messageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (TGMessageItem *)pinnedMessagePreviewItemForChatID:(NSNumber *)chatID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)pinnedMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messageViewersForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)toggleChatPinnedForChatID:(NSNumber *)chatID chatFilterID:(NSNumber *)chatFilterID pinned:(BOOL)pinned timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)setDraftMessageForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text replyToMessageID:(NSNumber *)replyToMessageID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)forwardMessagesFromChatID:(NSNumber *)fromChatID messageIDs:(NSArray *)messageIDs toChatID:(NSNumber *)toChatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendDocumentMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendVideoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendAudioMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentStickerItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendStickerMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind stickerFileID:(NSNumber *)stickerFileID emoji:(NSString *)emoji width:(NSNumber *)width height:(NSNumber *)height timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendVoiceMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath duration:(NSNumber *)duration caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)addReactionToChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)removeReactionFromChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)messageActionCapabilitiesForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)editTextMessageInChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)deleteMessagesInChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs revoke:(BOOL)revoke timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)storageUsageSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)clearDownloadedMediaCacheWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)logOutWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)drainSafeUpdateSummaries;
- (NSString *)receiverStatusSummary;
- (NSString *)loadedLibraryPath;
- (void)shutdownWithTimeout:(NSTimeInterval)timeout;

@end
