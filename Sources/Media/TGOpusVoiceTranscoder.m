#import "TGOpusVoiceTranscoder.h"
#import "TGMediaSecurityLimits.h"
#import "../Services/TGLogger.h"

static NSString *TGOpusTranscoderErrorDomain = @"TelegraphicaOpusTranscoder";

@implementation TGOpusVoiceTranscodeCancellationToken

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
        _cancelled = NO;
    }
    return self;
}

- (void)cancel {
    [_lock lock];
    _cancelled = YES;
    [_lock unlock];
}

- (BOOL)isCancelled {
    [_lock lock];
    BOOL cancelled = _cancelled;
    [_lock unlock];
    return cancelled;
}

- (void)dealloc {
    [_lock release];
    [super dealloc];
}

@end

NSOperationQueue *TGCreateSerialVoiceTranscodeQueue(void) {
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    [queue setMaxConcurrentOperationCount:1];
    return queue;
}

BOOL TGVoicePathLooksLikeOggOpus(NSString *path, NSString *mimeType, BOOL audioOnly) {
    if (!audioOnly) {
        return NO;
    }
    NSString *extension = [[path pathExtension] lowercaseString];
    NSString *mime = [mimeType isKindOfClass:[NSString class]] ? [mimeType lowercaseString] : @"";
    return ([extension isEqualToString:@"ogg"] ||
            [extension isEqualToString:@"oga"] ||
            [extension isEqualToString:@"opus"] ||
            [mime rangeOfString:@"ogg"].location != NSNotFound ||
            [mime rangeOfString:@"opus"].location != NSNotFound);
}

static NSString *TGOpusVoiceCacheDirectory(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *basePath = [paths count] > 0 ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Telegraphica/VoiceTranscodes"];
}

static NSString *TGOpusVoiceCachePathForSource(NSString *path) {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    unsigned long long size = 0;
    id sizeObject = [attributes objectForKey:NSFileSize];
    if ([sizeObject respondsToSelector:@selector(unsignedLongLongValue)]) {
        size = [sizeObject unsignedLongLongValue];
    }
    NSDate *modified = [attributes objectForKey:NSFileModificationDate];
    long long modifiedStamp = [modified respondsToSelector:@selector(timeIntervalSince1970)] ? (long long)[modified timeIntervalSince1970] : 0;
    NSString *cacheName = [NSString stringWithFormat:@"%@-%llu-%lld.wav",
                           [[path lastPathComponent] stringByDeletingPathExtension],
                           size,
                           modifiedStamp];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"];
    NSMutableString *safeName = [NSMutableString stringWithCapacity:[cacheName length]];
    NSUInteger index = 0;
    for (index = 0; index < [cacheName length]; index++) {
        unichar ch = [cacheName characterAtIndex:index];
        if ([allowed characterIsMember:ch]) {
            [safeName appendFormat:@"%C", ch];
        } else {
            [safeName appendString:@"_"];
        }
    }
    return [TGOpusVoiceCacheDirectory() stringByAppendingPathComponent:safeName];
}

static NSString *TGOpusDecoderHelperPath(void) {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"tgopusdec" ofType:nil inDirectory:@"Helpers"];
    if ([path length] > 0) {
        return path;
    }
    return nil;
}

static NSError *TGOpusTranscoderError(NSInteger code, NSString *message) {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:(message ? message : @"Opus transcoding failed.")
                                                         forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:TGOpusTranscoderErrorDomain code:code userInfo:userInfo];
}

NSString *TGPlayableVoicePathByTranscodingIfNeeded(NSString *path, NSString *mimeType, BOOL audioOnly, NSError **error) {
    return TGPlayableVoicePathByTranscodingIfNeededWithCancellation(path, mimeType, audioOnly, nil, error);
}

NSString *TGPlayableVoicePathByTranscodingIfNeededWithCancellation(NSString *path,
                                                                   NSString *mimeType,
                                                                   BOOL audioOnly,
                                                                   TGOpusVoiceTranscodeCancellationToken *cancellationToken,
                                                                   NSError **error) {
    if ([cancellationToken isCancelled]) {
        if (error) {
            *error = TGOpusTranscoderError(9, @"Voice preparation was cancelled.");
        }
        return nil;
    }
    if (!TGVoicePathLooksLikeOggOpus(path, mimeType, audioOnly)) {
        return path;
    }
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = TGOpusTranscoderError(1, @"Voice source file is missing.");
        }
        return nil;
    }

    NSDictionary *sourceAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    unsigned long long sourceSize = [[sourceAttributes objectForKey:NSFileSize] respondsToSelector:@selector(unsignedLongLongValue)]
        ? [[sourceAttributes objectForKey:NSFileSize] unsignedLongLongValue]
        : 0;
    if (sourceSize == 0 || sourceSize > TGMediaMaximumOpusInputBytes) {
        if (error) {
            *error = TGOpusTranscoderError(7, @"Voice source exceeds the safe decode size limit.");
        }
        return nil;
    }

    NSString *helperPath = TGOpusDecoderHelperPath();
    if ([helperPath length] == 0 || ![[NSFileManager defaultManager] isExecutableFileAtPath:helperPath]) {
        if (error) {
            *error = TGOpusTranscoderError(2, @"Bundled Opus decoder helper is missing.");
        }
        return nil;
    }

    NSString *cacheDirectory = TGOpusVoiceCacheDirectory();
    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:&directoryError]) {
        if (error) {
            *error = directoryError ? directoryError : TGOpusTranscoderError(3, @"Could not create voice cache directory.");
        }
        return nil;
    }

    NSString *outputPath = TGOpusVoiceCachePathForSource(path);
    NSDictionary *outputAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:NULL];
    id outputSize = [outputAttributes objectForKey:NSFileSize];
    if ([outputSize respondsToSelector:@selector(unsignedLongLongValue)] && [outputSize unsignedLongLongValue] > 44) {
        if ([outputSize unsignedLongLongValue] <= TGMediaMaximumDecodedVoiceBytes) {
            return outputPath;
        }
        [[NSFileManager defaultManager] removeItemAtPath:outputPath error:NULL];
    }

    NSString *uniqueSuffix = [[NSProcessInfo processInfo] globallyUniqueString];
    NSString *temporaryOutputPath = [outputPath stringByAppendingFormat:@".%@.tmp", uniqueSuffix];
    [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];

    NSString *errorLogPath = [temporaryOutputPath stringByAppendingString:@".stderr"];
    [[NSFileManager defaultManager] removeItemAtPath:errorLogPath error:NULL];
    [[NSFileManager defaultManager] createFileAtPath:errorLogPath contents:nil attributes:nil];
    NSFileHandle *errorHandle = [NSFileHandle fileHandleForWritingAtPath:errorLogPath];
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:helperPath];
    [task setArguments:[NSArray arrayWithObjects:path, temporaryOutputPath, nil]];
    [task setStandardError:errorHandle ? errorHandle : [NSFileHandle fileHandleWithNullDevice]];
    [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];

    BOOL cancelled = NO;
    BOOL timedOut = NO;
    BOOL outputLimitExceeded = NO;
    @try {
        [task launch];
        NSDate *startedAt = [NSDate date];
        while ([task isRunning]) {
            [NSThread sleepForTimeInterval:0.05];
            if ([cancellationToken isCancelled]) {
                cancelled = YES;
                [task terminate];
                continue;
            }
            NSDictionary *temporaryAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:temporaryOutputPath error:NULL];
            id temporarySize = [temporaryAttributes objectForKey:NSFileSize];
            if ([temporarySize respondsToSelector:@selector(unsignedLongLongValue)] &&
                [temporarySize unsignedLongLongValue] > TGMediaMaximumDecodedVoiceBytes) {
                outputLimitExceeded = YES;
                [task terminate];
            } else if (-[startedAt timeIntervalSinceNow] > TGMediaMaximumVoiceTranscodeSeconds) {
                timedOut = YES;
                [task terminate];
            }
        }
    } @catch (NSException *exception) {
        [errorHandle closeFile];
        if (error) {
            *error = TGOpusTranscoderError(4, [NSString stringWithFormat:@"Could not start Opus decoder: %@", [exception reason]]);
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:errorLogPath error:NULL];
        return nil;
    }

    [errorHandle closeFile];
    NSData *stderrData = [NSData dataWithContentsOfFile:errorLogPath];
    if ([stderrData length] > 16 * 1024) {
        stderrData = [stderrData subdataWithRange:NSMakeRange(0, 16 * 1024)];
    }
    NSString *stderrText = [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease];
    [[NSFileManager defaultManager] removeItemAtPath:errorLogPath error:NULL];
    if (cancelled || [cancellationToken isCancelled]) {
        if (error) {
            *error = TGOpusTranscoderError(9, @"Voice preparation was cancelled.");
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }
    if (timedOut || outputLimitExceeded || [task terminationStatus] != 0) {
        NSString *limitMessage = timedOut
            ? @"Opus decoder exceeded the safe time limit"
            : (outputLimitExceeded ? @"Opus decoder exceeded the safe output size limit" : nil);
        NSString *message = [NSString stringWithFormat:@"Opus decoder failed with status %d%@%@",
                             [task terminationStatus],
                             [limitMessage length] > 0 || [stderrText length] > 0 ? @": " : @"",
                             [limitMessage length] > 0 ? limitMessage : ([stderrText length] > 0 ? stderrText : @"")];
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Playback: %@", message]];
        if (error) {
            *error = TGOpusTranscoderError(5, message);
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }

    NSDictionary *decodedAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:temporaryOutputPath error:NULL];
    id decodedSizeObject = [decodedAttributes objectForKey:NSFileSize];
    unsigned long long decodedSize = [decodedSizeObject respondsToSelector:@selector(unsignedLongLongValue)]
        ? [decodedSizeObject unsignedLongLongValue]
        : 0;
    if (decodedSize <= 44 || decodedSize > TGMediaMaximumDecodedVoiceBytes) {
        if (error) {
            *error = TGOpusTranscoderError(8, @"Decoded voice output is empty or exceeds the safe size limit.");
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }
    if ([cancellationToken isCancelled]) {
        if (error) {
            *error = TGOpusTranscoderError(9, @"Voice preparation was cancelled.");
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }

    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:NULL];
    NSError *moveError = nil;
    if (![[NSFileManager defaultManager] moveItemAtPath:temporaryOutputPath toPath:outputPath error:&moveError]) {
        if (error) {
            *error = moveError ? moveError : TGOpusTranscoderError(6, @"Could not store decoded voice file.");
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }

    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Playback: decoded Opus voice %@ -> %@",
                                  [path lastPathComponent],
                                  [outputPath lastPathComponent]]];
    return outputPath;
}
