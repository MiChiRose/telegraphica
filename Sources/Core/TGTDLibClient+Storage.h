#import "TGTDLibClient.h"

@interface TGTDLibClient (Storage)

- (NSDictionary *)storageUsageSummaryWithTimeout:(NSTimeInterval)timeout
                                             error:(NSError **)error;
- (NSDictionary *)clearDownloadedMediaCacheForFileTypes:(NSArray *)fileTypes
                                                  chatIDs:(NSArray *)chatIDs
                                                  timeout:(NSTimeInterval)timeout
                                                    error:(NSError **)error;
- (NSDictionary *)clearDownloadedMediaCacheWithTimeout:(NSTimeInterval)timeout
                                                   error:(NSError **)error;

@end
