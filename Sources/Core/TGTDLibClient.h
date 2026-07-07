#import <Foundation/Foundation.h>

@interface TGTDLibClient : NSObject

- (BOOL)loadLibraryWithError:(NSError **)error;
- (NSString *)tdlibVersionWithError:(NSError **)error;
- (NSString *)loadedLibraryPath;

@end
