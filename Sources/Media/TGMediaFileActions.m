#import "TGMediaFileActions.h"
#import "../UI/TGLocalization.h"

@implementation TGMediaFileActions

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
    BOOL isDirectory = NO;
    if (![sourcePath isKindOfClass:[NSString class]] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:sourcePath isDirectory:&isDirectory] ||
        isDirectory) {
        if (error) {
            *error = [NSError errorWithDomain:@"TelegraphicaMediaFileActions"
                                         code:1
                                     userInfo:[NSDictionary dictionaryWithObject:TGLoc(@"media.center.saveAs.sourceMissing")
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
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

+ (BOOL)revealFileAtPath:(NSString *)path {
    if (![path isKindOfClass:[NSString class]] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return NO;
    }
    return [[NSWorkspace sharedWorkspace] selectFile:path
                           inFileViewerRootedAtPath:[path stringByDeletingLastPathComponent]];
}

@end
