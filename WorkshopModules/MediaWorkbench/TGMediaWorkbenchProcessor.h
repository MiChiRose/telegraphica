#import <Cocoa/Cocoa.h>

extern NSString * const TGMediaWorkbenchOutputJPEG;
extern NSString * const TGMediaWorkbenchOutputPNG;
extern NSString * const TGMediaWorkbenchOutputTIFF;

@interface TGMediaWorkbenchProcessor : NSObject

+ (NSDictionary *)imageInformationAtPath:(NSString *)path error:(NSError **)error;
+ (BOOL)processImageAtPath:(NSString *)sourcePath
                outputPath:(NSString *)outputPath
                    format:(NSString *)format
          maximumDimension:(NSUInteger)maximumDimension
                   quality:(CGFloat)quality
                     error:(NSError **)error;

@end
