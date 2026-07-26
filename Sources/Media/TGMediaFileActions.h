#import <Cocoa/Cocoa.h>

@interface TGMediaFileActions : NSObject

+ (BOOL)confirmDeleteLocalCopyWithFileName:(NSString *)fileName;
+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                             error:(NSError **)error;
+ (BOOL)revealFileAtPath:(NSString *)path;

@end
