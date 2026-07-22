#import <Foundation/Foundation.h>

@interface TGOpusVoiceTranscodeCancellationToken : NSObject {
    NSLock *_lock;
    BOOL _cancelled;
}
- (void)cancel;
- (BOOL)isCancelled;
@end

BOOL TGVoicePathLooksLikeOggOpus(NSString *path, NSString *mimeType, BOOL audioOnly);
NSOperationQueue *TGCreateSerialVoiceTranscodeQueue(void);
NSString *TGPlayableVoicePathByTranscodingIfNeeded(NSString *path, NSString *mimeType, BOOL audioOnly, NSError **error);
NSString *TGPlayableVoicePathByTranscodingIfNeededWithCancellation(NSString *path,
                                                                   NSString *mimeType,
                                                                   BOOL audioOnly,
                                                                   TGOpusVoiceTranscodeCancellationToken *cancellationToken,
                                                                   NSError **error);
