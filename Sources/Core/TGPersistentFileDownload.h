#import <Foundation/Foundation.h>

typedef NSDictionary *(^TGFileDownloadRequestBlock)(NSDictionary *request, NSTimeInterval timeout, NSError **error);
typedef BOOL (^TGFileDownloadCancellationBlock)(void);
typedef void (^TGFileDownloadProgressBlock)(long long downloadedBytes, long long totalBytes, BOOL reconnecting);
typedef NSTimeInterval (^TGFileDownloadClockBlock)(void);
typedef void (^TGFileDownloadWaitBlock)(NSTimeInterval seconds);

// RPC timeouts bound individual requests, never the lifetime of an explicit
// transfer. TDLib owns the partial data; offset/limit remain 0 for full files.
NSString *TGPersistentFileDownload(NSNumber *fileID, NSTimeInterval requestTimeout,
                                 TGFileDownloadRequestBlock request,
                                 TGFileDownloadCancellationBlock cancelled,
                                 TGFileDownloadProgressBlock progress,
                                 TGFileDownloadClockBlock clock,
                                 TGFileDownloadWaitBlock wait,
                                 NSError **error);
