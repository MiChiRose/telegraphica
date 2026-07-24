#import "TGGameSaveStore.h"
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static NSError *TGGameSavePOSIXError(NSString *operation, NSString *path) {
    NSString *description = [NSString stringWithFormat:@"%@ failed for %@: %s",
                             operation, path, strerror(errno)];
    return [NSError errorWithDomain:NSPOSIXErrorDomain
                               code:errno
                           userInfo:[NSDictionary dictionaryWithObject:description
                                                                forKey:NSLocalizedDescriptionKey]];
}

@implementation TGGameSaveStore

- (id)initWithDataDirectoryURL:(NSURL *)dataDirectoryURL fileName:(NSString *)fileName {
    self = [super init];
    if (self) {
        _dataDirectoryURL = [dataDirectoryURL retain];
        _fileName = [(fileName ? fileName : @"state.plist") copy];
    }
    return self;
}

- (NSString *)filePath {
    return [[_dataDirectoryURL path] stringByAppendingPathComponent:_fileName];
}

- (BOOL)ensureDirectory:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtPath:[_dataDirectoryURL path]
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:error];
}

- (NSDictionary *)loadDictionaryQuarantiningCorruptFile:(NSError **)error {
    NSString *path = [self filePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) return nil;
    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    id object = [NSPropertyListSerialization propertyListWithData:data
                                                          options:NSPropertyListImmutable
                                                           format:&format
                                                            error:error];
    if ([object isKindOfClass:[NSDictionary class]]) {
        return object;
    }

    [self quarantineCurrentSave];
    return nil;
}

- (BOOL)quarantineCurrentSave {
    NSString *path = [self filePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
    NSString *quarantineName = [NSString stringWithFormat:@"%@.corrupt-%lld",
                                _fileName,
                                (long long)[[NSDate date] timeIntervalSince1970]];
    NSString *quarantinePath = [[_dataDirectoryURL path] stringByAppendingPathComponent:quarantineName];
    return [[NSFileManager defaultManager] moveItemAtPath:path toPath:quarantinePath error:NULL];
}

- (BOOL)saveDictionary:(NSDictionary *)dictionary error:(NSError **)error {
    if (![self ensureDirectory:error]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary
                                                              format:NSPropertyListBinaryFormat_v1_0
                                                             options:0
                                                               error:error];
    if (!data) return NO;
    NSString *path = [self filePath];
    NSString *temporaryPath = [NSString stringWithFormat:@"%@.tmp-%d-%u",
                               path, (int)getpid(), arc4random()];
    if (![data writeToFile:temporaryPath options:0 error:error]) {
        return NO;
    }
    chmod([temporaryPath fileSystemRepresentation], S_IRUSR | S_IWUSR);

    int temporaryFD = open([temporaryPath fileSystemRepresentation], O_RDONLY);
    if (temporaryFD < 0 || fsync(temporaryFD) != 0) {
        NSError *posixError = TGGameSavePOSIXError(@"fsync", temporaryPath);
        if (temporaryFD >= 0) close(temporaryFD);
        [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:NULL];
        if (error) *error = posixError;
        return NO;
    }
    close(temporaryFD);

    if (rename([temporaryPath fileSystemRepresentation], [path fileSystemRepresentation]) != 0) {
        NSError *posixError = TGGameSavePOSIXError(@"rename", path);
        [[NSFileManager defaultManager] removeItemAtPath:temporaryPath error:NULL];
        if (error) *error = posixError;
        return NO;
    }

    int directoryFD = open([[_dataDirectoryURL path] fileSystemRepresentation], O_RDONLY);
    if (directoryFD >= 0) {
        fsync(directoryFD);
        close(directoryFD);
    }
    return YES;
}

- (BOOL)clearData:(NSError **)error {
    NSString *directory = [_dataDirectoryURL path];
    if (![[NSFileManager defaultManager] fileExistsAtPath:directory]) return YES;
    return [[NSFileManager defaultManager] removeItemAtPath:directory error:error];
}

- (void)dealloc {
    [_dataDirectoryURL release];
    [_fileName release];
    [super dealloc];
}

@end
