#import <Cocoa/Cocoa.h>

@interface TGMediaFileActions : NSObject

// Called on the main thread, including after the Save panel's nested event loop.
+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                      shouldContinue:(BOOL (^)(void))shouldContinue
                             error:(NSError **)error;

+ (BOOL)confirmDeleteLocalCopyWithFileName:(NSString *)fileName;
+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                             error:(NSError **)error;
+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                       toDirectory:(NSString *)directoryPath
                             error:(NSError **)error;
+ (BOOL)revealFileAtPath:(NSString *)path;

@end
