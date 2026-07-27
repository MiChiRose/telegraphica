#import "TGTDLibClient.h"

@interface TGTDLibClient (MapThumbnail)

- (NSString *)mapThumbnailPathForLatitude:(double)latitude
                                longitude:(double)longitude
                                     zoom:(NSInteger)zoom
                                    width:(NSInteger)width
                                   height:(NSInteger)height
                                  timeout:(NSTimeInterval)timeout
                                    error:(NSError **)error;

@end
