#import "TGTDLibClient.h"

@interface TGTDLibClient (ChatFolders)

- (NSArray *)chatFolderDefinitionsWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSNumber *)saveChatFolderDefinition:(NSDictionary *)definition timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)deleteChatFolderWithID:(NSNumber *)folderID apiKind:(NSString *)apiKind timeout:(NSTimeInterval)timeout error:(NSError **)error;
- (BOOL)chatFolderAPIKindSupportsSharing:(NSString *)apiKind;
- (NSString *)shareLinkForChatFolderID:(NSNumber *)folderID title:(NSString *)title timeout:(NSTimeInterval)timeout error:(NSError **)error;

@end
