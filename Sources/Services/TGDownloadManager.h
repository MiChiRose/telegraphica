#import <Foundation/Foundation.h>

@class TGTDLibClient;

extern NSString * const TGDownloadManagerDidChangeNotification;

typedef void (^TGDownloadCompletionBlock)(NSString *savedPath, NSError *error, BOOL cancelled);

@interface TGDownloadManager : NSObject

+ (TGDownloadManager *)sharedManager;
- (void)setClient:(TGTDLibClient *)client;
- (void)resumePendingDownloads;
- (NSString *)enqueueFileID:(NSNumber *)fileID
          suggestedFileName:(NSString *)suggestedFileName
          fallbackLocalPath:(NSString *)fallbackLocalPath
                 completion:(TGDownloadCompletionBlock)completion;
- (NSArray *)itemsSnapshot;
- (NSString *)presentationStateForFileID:(NSNumber *)fileID
                               savedPath:(NSString **)savedPathOut;
- (void)cancelDownloadWithIdentifier:(NSString *)identifier;
- (void)cancelDownloadsForFileID:(NSNumber *)fileID;
- (void)retryDownloadWithIdentifier:(NSString *)identifier
                         completion:(TGDownloadCompletionBlock)completion;
- (void)clearFinishedDownloads;

@end
