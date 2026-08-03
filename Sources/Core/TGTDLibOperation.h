#import <Foundation/Foundation.h>

extern NSString * const TGTDLibOperationErrorDomain;
extern NSString * const TGTDLibOperationRetryableErrorKey;

typedef id (^TGTDLibOperationWorkBlock)(NSError **error);
typedef BOOL (^TGTDLibOperationGenerationCheckBlock)(NSUInteger generation);
typedef void (^TGTDLibOperationCompletionBlock)(id result, NSError *error);

/*
 * A small MRC-safe asynchronous operation for idempotent TDLib reads.
 * Cancellation suppresses owner callbacks; timeout and worker completion race
 * through a single exactly-once gate.
 */
@interface TGTDLibOperation : NSObject {
@private
    NSLock *_lock;
    NSString *_operationID;
    NSUInteger _generation;
    NSTimeInterval _timeout;
    BOOL _idempotent;
    NSUInteger _maximumRetryCount;
    BOOL _cancelled;
    BOOL _completed;
    BOOL _started;
    TGTDLibOperationWorkBlock _workBlock;
    TGTDLibOperationGenerationCheckBlock _generationCheckBlock;
    TGTDLibOperationCompletionBlock _completionBlock;
}

@property (nonatomic, readonly, copy) NSString *operationID;
@property (nonatomic, readonly, assign) NSUInteger generation;
@property (nonatomic, readonly, assign, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, assign, getter=isCompleted) BOOL completed;

- (id)initWithGeneration:(NSUInteger)generation
                 timeout:(NSTimeInterval)timeout
              idempotent:(BOOL)idempotent
       maximumRetryCount:(NSUInteger)maximumRetryCount
                    work:(TGTDLibOperationWorkBlock)work
         generationCheck:(TGTDLibOperationGenerationCheckBlock)generationCheck
              completion:(TGTDLibOperationCompletionBlock)completion;
- (void)start;
- (void)cancel;

+ (NSError *)retryableErrorWithDescription:(NSString *)description code:(NSInteger)code;

@end
