#import <Foundation/Foundation.h>

@interface TGTDLibClient : NSObject

- (BOOL)loadLibraryWithError:(NSError **)error;
- (NSString *)tdlibProbeSummaryWithError:(NSError **)error;
- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)localTDLibConfigurationPathWithError:(NSError **)error;
- (NSString *)bundledTDLibConfigurationPath;
- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)prepareAuthorizationFlowWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)postLoginProbeSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
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
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendPhotoMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentStickerItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendStickerMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind stickerFileID:(NSNumber *)stickerFileID emoji:(NSString *)emoji width:(NSNumber *)width height:(NSNumber *)height timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendVoiceMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind localPath:(NSString *)localPath duration:(NSNumber *)duration caption:(NSString *)caption timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)addReactionToChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)removeReactionFromChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID emoji:(NSString *)emoji timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)logOutWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)drainSafeUpdateSummaries;
- (NSString *)receiverStatusSummary;
- (NSString *)loadedLibraryPath;
- (void)shutdownWithTimeout:(NSTimeInterval)timeout;

@end
