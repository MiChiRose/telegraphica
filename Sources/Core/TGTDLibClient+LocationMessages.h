#import "TGTDLibClient.h"

@interface TGTDLibClient (LocationMessages)

- (NSDictionary *)locationMediaInfoFromMessageContentObject:(id)contentObject
                                                    timeout:(NSTimeInterval)timeout;

@end
