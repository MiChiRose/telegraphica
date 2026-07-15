#import "TGOpusVoiceTranscoder.h"
#import "../Services/TGLogger.h"

static NSString *TGOpusTranscoderErrorDomain = @"TelegraphicaOpusTranscoder";

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
    if (!TGVoicePathLooksLikeOggOpus(path, mimeType, audioOnly)) {
        return path;
    }
    if ([path length] == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = TGOpusTranscoderError(1, @"Voice source file is missing.");
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
        return outputPath;
    }

    NSString *temporaryOutputPath = [outputPath stringByAppendingString:@".tmp"];
    [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];

    NSPipe *errorPipe = [NSPipe pipe];
    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:helperPath];
    [task setArguments:[NSArray arrayWithObjects:path, temporaryOutputPath, nil]];
    [task setStandardError:errorPipe];
    [task setStandardOutput:[NSPipe pipe]];

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        if (error) {
            *error = TGOpusTranscoderError(4, [NSString stringWithFormat:@"Could not start Opus decoder: %@", [exception reason]]);
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryOutputPath error:NULL];
        return nil;
    }

    NSData *stderrData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
    NSString *stderrText = [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease];
    if ([task terminationStatus] != 0) {
        NSString *message = [NSString stringWithFormat:@"Opus decoder failed with status %d%@%@",
                             [task terminationStatus],
                             [stderrText length] > 0 ? @": " : @"",
                             [stderrText length] > 0 ? stderrText : @""];
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Media Playback: %@", message]];
        if (error) {
            *error = TGOpusTranscoderError(5, message);
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
