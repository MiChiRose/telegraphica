#import "TGTDLibClient.h"
#import "TGPersistentFileDownload.h"

@interface TGTDLibClient (Files)

// Account identity for persisted download ownership; no profile/avatar work.
- (NSNumber *)downloadAccountIDWithError:(NSError **)error;

// Worker-only metadata lookup. Remote identity survives TDLib numeric-ID changes.
// A nonempty remote ID takes precedence; the returned file may use a canonical alias.
- (NSDictionary *)downloadFileIdentityForFileID:(NSNumber *)fileID
                                  remoteFileID:(NSString *)remoteID
                                         error:(NSError **)error;

- (NSString *)downloadedLocalPathForFileID:(NSNumber *)fileID
                                    timeout:(NSTimeInterval)timeout
                                      error:(NSError **)error;
- (BOOL)cancelDownloadForFileID:(NSNumber *)fileID
                         timeout:(NSTimeInterval)timeout
                           error:(NSError **)error;
- (BOOL)deleteCachedFileForFileID:(NSNumber *)fileID
                           timeout:(NSTimeInterval)timeout
                             error:(NSError **)error;

// Explicit user saves run on a worker and survive individual RPC timeouts.
- (NSString *)persistentDownloadedLocalPathForFileID:(NSNumber *)fileID
                                          cancelled:(TGFileDownloadCancellationBlock)cancelled
                                           progress:(TGFileDownloadProgressBlock)progress
                                              error:(NSError **)error;

// Shared by message/media parsers that opportunistically materialize a file.
- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID
                                       timeout:(NSTimeInterval)timeout
                                         error:(NSError **)error;
- (NSDictionary *)downloadedFileInfoForFileID:(NSNumber *)fileID
                                       timeout:(NSTimeInterval)timeout;

@end
