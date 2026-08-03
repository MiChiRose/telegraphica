#import "TGTDLibClient.h"

@interface TGTDLibClient (Files)

- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError **)error;
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;
- (BOOL)deleteCachedFileForFileID:(NSNumber *)fileID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error;

// Shared by message/media parsers that opportunistically materialize a file.
- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error;
- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID
                                       timeout:(NSTimeInterval)timeout;

@end
