#import <Foundation/Foundation.h>

@interface TGWorkshopArchiveExtractor : NSObject

@property(nonatomic, assign) NSUInteger maximumEntryCount;
@property(nonatomic, assign) unsigned long long maximumTotalSize;
@property(nonatomic, assign) unsigned long long maximumFileSize;
@property(nonatomic, assign) NSUInteger maximumPathLength;
@property(nonatomic, assign) NSUInteger maximumPathDepth;

- (BOOL)extractArchiveAtPath:(NSString *)archivePath
         toEmptyDirectoryPath:(NSString *)destinationPath
                       error:(NSError **)error;

@end
