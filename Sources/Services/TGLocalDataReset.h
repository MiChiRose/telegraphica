#import <Foundation/Foundation.h>

@class TGTDLibClient;

extern NSString * const TGLocalDataResetRemovedCountKey;
extern NSString * const TGLocalDataResetErrorMessagesKey;
extern NSString * const TGLocalDataResetOfflineNoteKey;

@interface TGLocalDataReset : NSObject

+ (NSDictionary *)resetLocalDataWithClient:(TGTDLibClient *)client
                                   timeout:(NSTimeInterval)timeout;

@end
