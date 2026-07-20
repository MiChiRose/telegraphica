#import <Foundation/Foundation.h>

typedef enum {
    TGFileTransferStatePreparing = 0,
    TGFileTransferStateSending = 1,
    TGFileTransferStateSucceeded = 2,
    TGFileTransferStateFailed = 3,
    TGFileTransferStateCancelled = 4
} TGFileTransferStateKind;

@interface TGFileTransferState : NSObject
@property (nonatomic, assign) TGFileTransferStateKind state;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) BOOL progressKnown;
@property (nonatomic, copy) NSString *message;
+ (TGFileTransferState *)stateWithKind:(TGFileTransferStateKind)kind message:(NSString *)message;
+ (TGFileTransferState *)stateWithState:(TGFileTransferStateKind)state progressKnown:(BOOL)progressKnown progress:(double)progress message:(NSString *)message;
@end

@class TGAttachmentDescriptor;

@interface TGAttachmentQueueItem : NSObject
@property (nonatomic, retain) TGAttachmentDescriptor *descriptor;
@property (nonatomic, retain) TGFileTransferState *transferState;
@property (nonatomic, assign) NSUInteger index;
+ (TGAttachmentQueueItem *)itemWithDescriptor:(TGAttachmentDescriptor *)descriptor index:(NSUInteger)index state:(TGFileTransferStateKind)state message:(NSString *)message;
- (BOOL)isFailed;
- (BOOL)isTerminal;
@end
