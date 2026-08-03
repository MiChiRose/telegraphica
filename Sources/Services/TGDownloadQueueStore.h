#import <Foundation/Foundation.h>

extern NSString * const TGDownloadQueueRecordsDefaultsKey;

NSArray *TGDownloadQueueNormalizedRecords(id storedValue);
NSArray *TGDownloadQueueSerializableRecords(NSArray *records);

