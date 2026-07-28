#import <Cocoa/Cocoa.h>

typedef void (^TGLocationSearchCompletion)(NSArray *results, NSError *error);

@interface TGLocationSearchService : NSObject

- (BOOL)isAvailable;
- (void)searchForQuery:(NSString *)query
        centerLatitude:(double)latitude
       centerLongitude:(double)longitude
            completion:(TGLocationSearchCompletion)completion;
- (void)cancel;

@end
