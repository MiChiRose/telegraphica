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
- (NSArray *)mainChatPreviewItemsWithLimit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSArray *)recentMessagePreviewItemsForChatID:(NSNumber *)chatID limit:(NSUInteger)limit timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPhoneNumber:(NSString *)phoneNumber timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationCode:(NSString *)code timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)submitAuthenticationPassword:(NSString *)password timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)receiverStatusSummary;
- (NSString *)loadedLibraryPath;

@end
