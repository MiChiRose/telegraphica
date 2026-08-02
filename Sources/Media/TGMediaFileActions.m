#import "TGMediaFileActions.h"
#import "../UI/TGLocalization.h"

static void TGAnnounceCompletedDownloadAtPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return;
    }

    // Finder notices ordinary file-system changes, but the Downloads stack in
    // the Dock only animates when applications explicitly announce a finished
    // download. This legacy notification is understood throughout our unified
    // OS X 10.8-macOS 10.13 lane.
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:@"com.apple.DownloadFileFinished"
                      object:path];
    [[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];
}

@implementation TGMediaFileActions

+ (BOOL)validateSourceFileAtPath:(NSString *)sourcePath error:(NSError **)error {
    BOOL isDirectory = NO;
    if ([sourcePath isKindOfClass:[NSString class]] &&
        [[NSFileManager defaultManager] fileExistsAtPath:sourcePath isDirectory:&isDirectory] &&
        !isDirectory) {
        return YES;
    }
    if (error) {
        *error = [NSError errorWithDomain:@"TelegraphicaMediaFileActions"
                                     code:1
                                 userInfo:[NSDictionary dictionaryWithObject:TGLoc(@"media.center.saveAs.sourceMissing")
                                                                      forKey:NSLocalizedDescriptionKey]];
    }
    return NO;
}

+ (BOOL)confirmDeleteLocalCopyWithFileName:(NSString *)fileName {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(@"media.center.deleteLocal.confirm.title")];
    NSString *safeName = [fileName length] > 0 ? fileName : TGLoc(@"media.center.unnamedFile");
    [alert setInformativeText:[NSString stringWithFormat:TGLoc(@"media.center.deleteLocal.confirm.hint"), safeName]];
    [alert addButtonWithTitle:TGLoc(@"media.center.deleteLocal")];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    return ([alert runModal] == NSAlertFirstButtonReturn);
}

+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                             error:(NSError **)error {
    if (![self validateSourceFileAtPath:sourcePath error:error]) {
        return nil;
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    NSString *safeName = [suggestedFileName length] > 0 ? suggestedFileName : [sourcePath lastPathComponent];
    [panel setNameFieldStringValue:safeName];
    if ([panel runModal] != NSFileHandlingPanelOKButton) {
        return nil;
    }
    NSString *destinationPath = [[panel URL] path];
    if ([destinationPath length] == 0 || [destinationPath isEqualToString:sourcePath]) {
        return sourcePath;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *destinationDirectory = [destinationPath stringByDeletingLastPathComponent];
    NSString *temporaryName = [NSString stringWithFormat:@".telegraphica-save-%@",
                               [[NSProcessInfo processInfo] globallyUniqueString]];
    NSString *temporaryPath = [destinationDirectory stringByAppendingPathComponent:temporaryName];
    if (![fileManager copyItemAtPath:sourcePath toPath:temporaryPath error:error]) {
        return nil;
    }
    BOOL saved = NO;
    if ([fileManager fileExistsAtPath:destinationPath]) {
        saved = [fileManager replaceItemAtURL:[NSURL fileURLWithPath:destinationPath]
                               withItemAtURL:[NSURL fileURLWithPath:temporaryPath]
                              backupItemName:nil
                                     options:0
                            resultingItemURL:NULL
                                       error:error];
    } else {
        saved = [fileManager moveItemAtPath:temporaryPath toPath:destinationPath error:error];
    }
    if (!saved) {
        [fileManager removeItemAtPath:temporaryPath error:NULL];
        return nil;
    }
    return destinationPath;
}

+ (NSString *)saveCopyOfFileAtPath:(NSString *)sourcePath
                 suggestedFileName:(NSString *)suggestedFileName
                       toDirectory:(NSString *)directoryPath
                             error:(NSError **)error {
    if (![self validateSourceFileAtPath:sourcePath error:error]) {
        return nil;
    }
    if (![directoryPath isKindOfClass:[NSString class]] || [directoryPath length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaMediaFileActions"
                                         code:2
                                     userInfo:[NSDictionary dictionaryWithObject:@"The downloads folder is not configured."
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL directoryExists = NO;
    BOOL isDirectory = NO;
    directoryExists = [fileManager fileExistsAtPath:directoryPath isDirectory:&isDirectory];
    if ((!directoryExists || !isDirectory) &&
        ![fileManager createDirectoryAtPath:directoryPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:error]) {
        return nil;
    }

    NSString *safeName = [[suggestedFileName lastPathComponent] stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([safeName length] == 0) {
        safeName = [sourcePath lastPathComponent];
    }
    if ([safeName length] == 0) {
        safeName = @"download";
    }
    if ([[safeName pathExtension] length] == 0 && [[sourcePath pathExtension] length] > 0) {
        safeName = [safeName stringByAppendingPathExtension:[sourcePath pathExtension]];
    }

    NSString *destinationPath = [directoryPath stringByAppendingPathComponent:safeName];
    NSString *baseName = [safeName stringByDeletingPathExtension];
    NSString *extension = [safeName pathExtension];
    NSUInteger suffix = 2;
    while ([fileManager fileExistsAtPath:destinationPath]) {
        NSString *candidateName = [NSString stringWithFormat:@"%@ (%lu)",
                                   baseName,
                                   (unsigned long)suffix];
        if ([extension length] > 0) {
            candidateName = [candidateName stringByAppendingPathExtension:extension];
        }
        destinationPath = [directoryPath stringByAppendingPathComponent:candidateName];
        suffix += 1;
    }

    NSString *temporaryName = [NSString stringWithFormat:@".telegraphica-download-%@",
                               [[NSProcessInfo processInfo] globallyUniqueString]];
    NSString *temporaryPath = [directoryPath stringByAppendingPathComponent:temporaryName];
    if (![fileManager copyItemAtPath:sourcePath toPath:temporaryPath error:error]) {
        return nil;
    }
    if (![fileManager moveItemAtPath:temporaryPath toPath:destinationPath error:error]) {
        [fileManager removeItemAtPath:temporaryPath error:NULL];
        return nil;
    }
    TGAnnounceCompletedDownloadAtPath(destinationPath);
    return destinationPath;
}

+ (BOOL)revealFileAtPath:(NSString *)path {
    if (![path isKindOfClass:[NSString class]] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
    return [[NSWorkspace sharedWorkspace] selectFile:path
                           inFileViewerRootedAtPath:[path stringByDeletingLastPathComponent]];
}

@end
