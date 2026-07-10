#import <Foundation/Foundation.h>

@interface TGTDLibClient : NSObject

- (BOOL)loadLibraryWithError:(NSError **)error;
- (NSString *)tdlibProbeSummaryWithError:(NSError **)error;
- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)prepareAuthorizationFlowWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)postLoginProbeSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)currentUserProfileSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)chatFilterInfoItemsWithTimeout:(NSTimeInterval)timeout;
- (NSArray *)mainChatPreviewItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)chatPreviewItemsForChatFilterID:(NSNumber *)filterID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout exhausted:(BOOL *)exhausted error:(NSError **)error;
- (BOOL)mainChatListExhausted;
- (void)invalidateMainChatListExhaustion;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)forumTopicPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)threadPreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)messagePreviewItemsForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID fromMessageID:(NSNumber *)fromMessageID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)markMessagesAsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageIDs:(NSArray *)messageIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)sendTextMessageToChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID text:(NSString *)text timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)logOutWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)drainSafeUpdateSummaries;
- (NSString *)receiverStatusSummary;
- (NSString *)loadedLibraryPath;
- (void)shutdownWithTimeout:(NSTimeInterval)timeout;

@end
