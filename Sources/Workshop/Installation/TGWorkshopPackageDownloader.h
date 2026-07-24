#import <Foundation/Foundation.h>

@class TGWorkshopCatalogEntry;

typedef void (^TGWorkshopDownloadProgress)(unsigned long long receivedBytes, unsigned long long expectedBytes);
typedef void (^TGWorkshopDownloadCompletion)(NSString *packagePath, NSError *error);

@interface TGWorkshopPackageDownloader : NSObject <NSURLConnectionDataDelegate> {
@private
    TGWorkshopCatalogEntry *_entry;
    NSURLConnection *_connection;
    NSOutputStream *_outputStream;
    NSString *_partialPath;
    unsigned long long _receivedBytes;
    TGWorkshopDownloadProgress _progress;
    TGWorkshopDownloadCompletion _completion;
}

- (void)downloadCatalogEntry:(TGWorkshopCatalogEntry *)entry
                    progress:(TGWorkshopDownloadProgress)progress
                  completion:(TGWorkshopDownloadCompletion)completion;
- (void)cancel;

@end
