#import <Foundation/Foundation.h>

@interface TGTDLibClient : NSObject

- (BOOL)loadLibraryWithError:(NSError **)error;
- (NSString *)tdlibProbeSummaryWithError:(NSError **)error;
- (NSString *)authorizationStateSummaryWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)setLocalTDLibParametersWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)checkDatabaseEncryptionKeyWithTimeout:(NSTimeInterval)timeout error:(NSError **)error;
- (NSString *)loadedLibraryPath;

@end
