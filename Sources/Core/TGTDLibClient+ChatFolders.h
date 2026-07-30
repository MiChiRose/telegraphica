#import "TGTDLibClient.h"

@interface TGTDLibClient (ChatFolders)

- (NSArray *)chatFolderDefinitionsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSNumber *)saveChatFolderDefinition:(NSDictionary *)definition timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)reorderChatFolderDefinitions:(NSArray *)definitions timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSDictionary *)chatFolderInvitePreviewForLink:(NSString *)inviteLink timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)importChatFolderWithInviteLink:(NSString *)inviteLink chatIDs:(NSArray *)chatIDs timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)deleteChatFolderWithID:(NSNumber *)folderID apiKind:(NSString *)apiKind timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)chatFolderAPIKindSupportsSharing:(NSString *)apiKind;
- (NSString *)shareLinkForChatFolderID:(NSNumber *)folderID title:(NSString *)title timeout:(NSTimeInterval)timeout error:(NSError **)error;

@end
