#import "TGTDLibOperation.h"
#import <dispatch/dispatch.h>

NSString * const TGTDLibOperationErrorDomain = @"TelegraphicaTDLibOperationError";
NSString * const TGTDLibOperationRetryableErrorKey = @"TelegraphicaRetryable";

@interface TGTDLibOperation ()
- (void)finishWithResult:(id)result error:(NSError *)error;
- (BOOL)shouldRetryError:(NSError *)error attempt:(NSUInteger)attempt;
@end

@implementation TGTDLibOperation

- (id)initWithGeneration:(NSUInteger)generation
                 timeout:(NSTimeInterval)timeout
              idempotent:(BOOL)idempotent
       maximumRetryCount:(NSUInteger)maximumRetryCount
                    work:(TGTDLibOperationWorkBlock)work
         generationCheck:(TGTDLibOperationGenerationCheckBlock)generationCheck
              completion:(TGTDLibOperationCompletionBlock)completion {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _operationID = [[[NSProcessInfo processInfo] globallyUniqueString] copy];
        _generation = generation;
        _timeout = MAX(0.5, MIN(30.0, timeout));
        _idempotent = idempotent;
        _maximumRetryCount = idempotent ? MIN((NSUInteger)1U, maximumRetryCount) : 0U;
        _workBlock = [work copy];
        _generationCheckBlock = [generationCheck copy];
        _completionBlock = [completion copy];
    }
    return self;
}

- (void)dealloc {
    [_lock release];
    [_operationID release];
    [_workBlock release];
    [_generationCheckBlock release];
    [_completionBlock release];
    [super dealloc];
}

- (NSString *)operationID {
    return _operationID;
}

- (NSUInteger)generation {
    return _generation;
}

- (BOOL)isCancelled {
    [_lock lock];
    BOOL value = _cancelled;
    [_lock unlock];
    return value;
}

- (BOOL)isCompleted {
    [_lock lock];
    BOOL value = _completed;
    [_lock unlock];
    return value;
}

- (void)start {
    [_lock lock];
    if (_started || _cancelled || _completed) {
        [_lock unlock];
        return;
    }
    _started = YES;
    TGTDLibOperationWorkBlock workBlock = [_workBlock copy];
    [_lock unlock];
    if (!workBlock) {
        NSError *error = [NSError errorWithDomain:TGTDLibOperationErrorDomain
                                             code:1
                                         userInfo:[NSDictionary dictionaryWithObject:@"Operation has no work block."
                                                                              forKey:NSLocalizedDescriptionKey]];
        [self finishWithResult:nil error:error];
        return;
    }

    dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * (double)NSEC_PER_SEC));
    dispatch_after(deadline, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *timeoutError = [NSError errorWithDomain:TGTDLibOperationErrorDomain
                                                    code:2
                                                userInfo:[NSDictionary dictionaryWithObject:@"The operation timed out."
                                                                                     forKey:NSLocalizedDescriptionKey]];
        [self finishWithResult:nil error:timeoutError];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSUInteger attempt = 0U;
        id result = nil;
        NSError *error = nil;
        do {
            if ([self isCancelled] || [self isCompleted]) {
                break;
            }
            error = nil;
            result = workBlock(&error);
            if (result || ![self shouldRetryError:error attempt:attempt]) {
                break;
            }
            attempt++;
        } while (attempt <= _maximumRetryCount);
        [self finishWithResult:result error:error];
        [workBlock release];
        [pool drain];
    });
}

- (BOOL)shouldRetryError:(NSError *)error attempt:(NSUInteger)attempt {
    if (!_idempotent || attempt >= _maximumRetryCount || !error) {
        return NO;
    }
    return [[[error userInfo] objectForKey:TGTDLibOperationRetryableErrorKey] boolValue];
}

- (void)cancel {
    [_lock lock];
    _cancelled = YES;
    _completed = YES;
    [_workBlock release];
    _workBlock = nil;
    [_generationCheckBlock release];
    _generationCheckBlock = nil;
    [_completionBlock release];
    _completionBlock = nil;
    [_lock unlock];
}

- (void)finishWithResult:(id)result error:(NSError *)error {
    [_lock lock];
    if (_completed || _cancelled) {
        [_lock unlock];
        return;
    }
    _completed = YES;
    id retainedResult = [result retain];
    NSError *retainedError = [error retain];
    TGTDLibOperationGenerationCheckBlock generationCheckBlock = [_generationCheckBlock copy];
    TGTDLibOperationCompletionBlock completionBlock = [_completionBlock copy];
    [_workBlock release];
    _workBlock = nil;
    [_generationCheckBlock release];
    _generationCheckBlock = nil;
    [_completionBlock release];
    _completionBlock = nil;
    [_lock unlock];

    dispatch_async(dispatch_get_main_queue(), ^{
        [_lock lock];
        BOOL shouldDeliver = !_cancelled;
        [_lock unlock];
        if (shouldDeliver && generationCheckBlock) {
            shouldDeliver = generationCheckBlock(_generation);
        }
        if (shouldDeliver && completionBlock) {
            completionBlock(retainedResult, retainedError);
        }
        [generationCheckBlock release];
        [completionBlock release];
        [retainedResult release];
        [retainedError release];
    });
}

+ (NSError *)retryableErrorWithDescription:(NSString *)description code:(NSInteger)code {
    NSString *safeDescription = [description length] > 0 ? description : @"Temporary operation failure.";
    return [NSError errorWithDomain:TGTDLibOperationErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                     safeDescription, NSLocalizedDescriptionKey,
                                     [NSNumber numberWithBool:YES], TGTDLibOperationRetryableErrorKey,
                                     nil]];
}

@end
