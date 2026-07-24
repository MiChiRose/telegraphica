#import <Foundation/Foundation.h>

@interface TGWorkshopIntegrity : NSObject

+ (NSString *)SHA256ForFileAtPath:(NSString *)path error:(NSError **)error;
+ (BOOL)fileAtPath:(NSString *)path matchesSHA256:(NSString *)expectedSHA256 error:(NSError **)error;
+ (BOOL)verifySignature:(NSData *)signature
              overData:(NSData *)data
                domain:(NSString *)domain
 certificateDERAtPath:(NSString *)certificatePath
                 error:(NSError **)error;

@end
