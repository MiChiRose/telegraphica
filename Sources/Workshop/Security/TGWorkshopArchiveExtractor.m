#import "TGWorkshopArchiveExtractor.h"
#import "../API/TGWorkshopModuleDefinitions.h"
#import "../Host/TGWorkshopPaths.h"
#import "../../../Vendor/minizip/unzip.h"
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>
#import <zlib.h>

static NSError *TGWorkshopArchiveError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:TGWorkshopErrorDomain
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]];
}

static BOOL TGWorkshopArchiveRelativePathIsSafe(NSString *path, NSUInteger maximumLength, NSUInteger maximumDepth) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0 || [path length] > maximumLength ||
        [path hasPrefix:@"/"] || [path rangeOfString:@"\\"].location != NSNotFound ||
        [path rangeOfString:@":"].location != NSNotFound ||
        [path rangeOfString:@"\0"].location != NSNotFound) {
        return NO;
    }
    NSArray *components = [path pathComponents];
    if ([components count] == 0 || [components count] > maximumDepth) {
        return NO;
    }
    NSString *component = nil;
    for (component in components) {
        if ([component length] == 0 || [component isEqualToString:@"."] || [component isEqualToString:@".."] ||
            [component isEqualToString:@"/"]) {
            return NO;
        }
    }
    return YES;
}

static BOOL TGWorkshopArchiveEntryIsDirectory(NSString *name, unz_file_info64 info) {
    mode_t mode = (mode_t)((info.external_fa >> 16) & 0170000);
    return [name hasSuffix:@"/"] || mode == S_IFDIR;
}

static BOOL TGWorkshopArchiveEntryTypeIsAllowed(NSString *name, unz_file_info64 info) {
    mode_t mode = (mode_t)((info.external_fa >> 16) & 0170000);
    if (mode == 0) {
        return YES;
    }
    if (TGWorkshopArchiveEntryIsDirectory(name, info)) {
        return mode == S_IFDIR;
    }
    return mode == S_IFREG;
}

@implementation TGWorkshopArchiveExtractor

@synthesize maximumEntryCount = _maximumEntryCount;
@synthesize maximumTotalSize = _maximumTotalSize;
@synthesize maximumFileSize = _maximumFileSize;
@synthesize maximumPathLength = _maximumPathLength;
@synthesize maximumPathDepth = _maximumPathDepth;

- (id)init {
    self = [super init];
    if (self) {
        _maximumEntryCount = 5000;
        _maximumTotalSize = 200ULL * 1024ULL * 1024ULL;
        _maximumFileSize = 50ULL * 1024ULL * 1024ULL;
        _maximumPathLength = 512;
        _maximumPathDepth = 16;
    }
    return self;
}

- (BOOL)extractArchiveAtPath:(NSString *)archivePath
         toEmptyDirectoryPath:(NSString *)destinationPath
                       error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *existing = [fileManager contentsOfDirectoryAtPath:destinationPath error:error];
    if (!existing || [existing count] != 0) {
        if (error && !*error) *error = TGWorkshopArchiveError(320, @"Workshop staging directory is not empty.");
        return NO;
    }

    unzFile archive = unzOpen64([archivePath fileSystemRepresentation]);
    if (!archive) {
        if (error) *error = TGWorkshopArchiveError(321, @"Workshop package is not a readable ZIP archive.");
        return NO;
    }

    unz_global_info64 globalInfo;
    if (unzGetGlobalInfo64(archive, &globalInfo) != UNZ_OK || globalInfo.number_entry == 0 ||
        globalInfo.number_entry > _maximumEntryCount) {
        unzClose(archive);
        if (error) *error = TGWorkshopArchiveError(322, @"Workshop package contains an invalid number of files.");
        return NO;
    }

    NSMutableSet *normalizedNames = [NSMutableSet setWithCapacity:(NSUInteger)globalInfo.number_entry];
    unsigned long long totalBytes = 0;
    int result = unzGoToFirstFile(archive);
    NSUInteger entryIndex = 0;
    BOOL success = YES;
    for (entryIndex = 0; entryIndex < (NSUInteger)globalInfo.number_entry && result == UNZ_OK; entryIndex++) {
        unz_file_info64 info;
        if (unzGetCurrentFileInfo64(archive, &info, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK ||
            info.size_filename == 0 || info.size_filename > _maximumPathLength * 4) {
            success = NO;
            if (error) *error = TGWorkshopArchiveError(323, @"Workshop package contains an invalid file name.");
            break;
        }

        char *filenameBytes = calloc((size_t)info.size_filename + 1, 1);
        if (!filenameBytes ||
            unzGetCurrentFileInfo64(archive, &info, filenameBytes, (uLong)info.size_filename + 1, NULL, 0, NULL, 0) != UNZ_OK) {
            free(filenameBytes);
            success = NO;
            if (error) *error = TGWorkshopArchiveError(324, @"Workshop package file name could not be read.");
            break;
        }
        NSString *relativePath = [[[NSString alloc] initWithBytes:filenameBytes
                                                           length:(NSUInteger)info.size_filename
                                                         encoding:NSUTF8StringEncoding] autorelease];
        free(filenameBytes);

        NSString *deduplicatedName = [[relativePath precomposedStringWithCanonicalMapping] lowercaseString];
        BOOL encrypted = ((info.flag & 1U) != 0);
        BOOL supportedCompression = (info.compression_method == 0 || info.compression_method == Z_DEFLATED);
        if (!TGWorkshopArchiveRelativePathIsSafe(relativePath, _maximumPathLength, _maximumPathDepth) ||
            [normalizedNames containsObject:deduplicatedName] ||
            !TGWorkshopArchiveEntryTypeIsAllowed(relativePath, info) ||
            encrypted ||
            !supportedCompression ||
            info.uncompressed_size > _maximumFileSize ||
            totalBytes + info.uncompressed_size > _maximumTotalSize) {
            success = NO;
            if (error) *error = TGWorkshopArchiveError(325, @"Workshop package contains an unsafe or oversized entry.");
            break;
        }
        [normalizedNames addObject:deduplicatedName];

        NSString *outputPath = [destinationPath stringByAppendingPathComponent:relativePath];
        NSString *standardDestination = [destinationPath stringByStandardizingPath];
        NSString *standardOutput = [outputPath stringByStandardizingPath];
        NSString *requiredPrefix = [standardDestination stringByAppendingString:@"/"];
        if (![standardOutput hasPrefix:requiredPrefix]) {
            success = NO;
            if (error) *error = TGWorkshopArchiveError(326, @"Workshop package attempted to escape its staging directory.");
            break;
        }

        BOOL isDirectory = TGWorkshopArchiveEntryIsDirectory(relativePath, info);
        if (isDirectory) {
            if (!TGWorkshopEnsureDirectory(standardOutput, error)) {
                success = NO;
                break;
            }
        } else {
            if (!TGWorkshopEnsureDirectory([standardOutput stringByDeletingLastPathComponent], error)) {
                success = NO;
                break;
            }
            if (unzOpenCurrentFile(archive) != UNZ_OK) {
                success = NO;
                if (error) *error = TGWorkshopArchiveError(327, @"Workshop package entry could not be opened.");
                break;
            }

            int fileDescriptor = open([standardOutput fileSystemRepresentation],
                                      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
                                      S_IRUSR | S_IWUSR);
            if (fileDescriptor < 0) {
                unzCloseCurrentFile(archive);
                success = NO;
                if (error) *error = TGWorkshopArchiveError(328, @"Workshop package entry could not be created securely.");
                break;
            }

            unsigned long long fileBytes = 0;
            uint8_t buffer[64 * 1024];
            int readLength = 0;
            while ((readLength = unzReadCurrentFile(archive, buffer, sizeof(buffer))) > 0) {
                fileBytes += (unsigned long long)readLength;
                totalBytes += (unsigned long long)readLength;
                if (fileBytes > _maximumFileSize || totalBytes > _maximumTotalSize) {
                    success = NO;
                    if (error) *error = TGWorkshopArchiveError(329, @"Workshop package exceeded extraction limits.");
                    break;
                }
                ssize_t writtenTotal = 0;
                while (writtenTotal < readLength) {
                    ssize_t written = write(fileDescriptor, buffer + writtenTotal, (size_t)(readLength - writtenTotal));
                    if (written <= 0) {
                        success = NO;
                        if (error) *error = TGWorkshopArchiveError(330, @"Workshop package entry could not be written.");
                        break;
                    }
                    writtenTotal += written;
                }
                if (!success) break;
            }
            fsync(fileDescriptor);
            close(fileDescriptor);
            int closeResult = unzCloseCurrentFile(archive);
            if (readLength < 0 || closeResult != UNZ_OK || fileBytes != info.uncompressed_size) {
                success = NO;
                if (error && !*error) *error = TGWorkshopArchiveError(331, @"Workshop package entry failed integrity checks.");
            }
            if (!success) {
                [fileManager removeItemAtPath:standardOutput error:NULL];
                break;
            }

            mode_t archivedMode = (mode_t)((info.external_fa >> 16) & 0777);
            mode_t safeMode = (archivedMode & 0111) ? (S_IRUSR | S_IWUSR | S_IXUSR) : (S_IRUSR | S_IWUSR);
            chmod([standardOutput fileSystemRepresentation], safeMode);
        }
        result = unzGoToNextFile(archive);
    }

    if (success && entryIndex != (NSUInteger)globalInfo.number_entry) {
        success = NO;
        if (error) *error = TGWorkshopArchiveError(332, @"Workshop package ended unexpectedly.");
    }
    unzClose(archive);
    return success;
}

@end
