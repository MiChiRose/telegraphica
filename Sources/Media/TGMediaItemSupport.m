#import "TGMediaItemSupport.h"
#import "TGInlineMediaPlaybackCoordinator.h"

NSString *TGMediaItemLocalPath(NSDictionary *mediaItem) {
    id path = [mediaItem objectForKey:@"local_path"];
    return [path isKindOfClass:[NSString class]] ? (NSString *)path : nil;
}

NSString *TGMediaItemFullLocalPath(NSDictionary *mediaItem) {
    id path = [mediaItem objectForKey:@"full_local_path"];
    return [path isKindOfClass:[NSString class]] ? (NSString *)path : nil;
}

NSData *TGMediaItemMiniThumbnailData(NSDictionary *mediaItem) {
    id data = [mediaItem objectForKey:@"minithumbnail_data"];
    return [data isKindOfClass:[NSData class]] ? (NSData *)data : nil;
}

NSNumber *TGMediaItemFullFileID(NSDictionary *mediaItem) {
    id fileID = [mediaItem objectForKey:@"full_file_id"];
    if ([fileID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[fileID integerValue]];
    }
    fileID = [mediaItem objectForKey:@"playable_file_id"];
    if ([fileID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[fileID integerValue]];
    }
    fileID = [mediaItem objectForKey:@"file_id"];
    if ([fileID respondsToSelector:@selector(integerValue)]) {
        return [NSNumber numberWithInteger:[fileID integerValue]];
    }
    return nil;
}

NSString *TGMediaItemContentType(NSDictionary *mediaItem) {
    id contentType = [mediaItem objectForKey:@"content_type"];
    return [contentType isKindOfClass:[NSString class]] ? (NSString *)contentType : nil;
}

BOOL TGMediaItemIsAnimation(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageAnimation"];
}

BOOL TGMediaItemIsVideo(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    return ([contentType isEqualToString:@"messageVideo"] ||
            [contentType isEqualToString:@"messageVideoNote"]);
}

BOOL TGMediaItemIsPlayable(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    if ([contentType isEqualToString:@"messageAnimation"] ||
        [contentType isEqualToString:@"messageVideo"] ||
        [contentType isEqualToString:@"messageVideoNote"]) {
        return YES;
    }
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
    return ([mimeType hasPrefix:@"video/"] || [mimeType hasPrefix:@"audio/"]);
}

BOOL TGMediaItemIsAudioOnlyPlayable(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    if ([contentType isEqualToString:@"messageVideo"] ||
        [contentType isEqualToString:@"messageVideoNote"] ||
        [contentType isEqualToString:@"messageAnimation"]) {
        return NO;
    }
    if ([contentType isEqualToString:@"messageVoiceNote"] ||
        [contentType isEqualToString:@"messageAudio"]) {
        return YES;
    }
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : nil;
    return [mimeType hasPrefix:@"audio/"];
}

NSString *TGMediaItemPlayableLocalPath(NSDictionary *mediaItem) {
    id path = [mediaItem objectForKey:@"playable_local_path"];
    if ([path isKindOfClass:[NSString class]] && [(NSString *)path length] > 0) {
        return (NSString *)path;
    }
    path = [mediaItem objectForKey:@"full_local_path"];
    if ([path isKindOfClass:[NSString class]] && [(NSString *)path length] > 0) {
        return (NSString *)path;
    }
    path = TGMediaItemLocalPath(mediaItem);
    if ([path isKindOfClass:[NSString class]] && [(NSString *)path length] > 0) {
        NSString *extension = [[(NSString *)path pathExtension] lowercaseString];
        NSArray *extensions = [NSArray arrayWithObjects:@"mp4", @"mov", @"m4v", @"webm", @"gif",
                               @"mp3", @"m4a", @"aac", @"ogg", @"opus", nil];
        if ([extensions containsObject:extension]) {
            return (NSString *)path;
        }
    }
    return nil;
}

NSString *TGInlinePlaybackPathForMediaItem(NSDictionary *mediaItem) {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *fullPath = TGMediaItemFullLocalPath(mediaItem);
    id stickerFormatObject = [mediaItem objectForKey:@"sticker_format"];
    NSString *stickerFormat = [stickerFormatObject isKindOfClass:[NSString class]] ? (NSString *)stickerFormatObject : @"";
    if ([TGMediaItemContentType(mediaItem) isEqualToString:@"messageSticker"] &&
        [stickerFormat isEqualToString:@"stickerFormatTgs"]) {
        return [[NSFileManager defaultManager] fileExistsAtPath:fullPath] ? fullPath : nil;
    }

    NSString *playablePath = TGMediaItemPlayableLocalPath(mediaItem);
    NSString *localPath = TGMediaItemLocalPath(mediaItem);
    NSArray *candidatePaths = [NSArray arrayWithObjects:
                               playablePath ? playablePath : @"",
                               fullPath ? fullPath : @"",
                               localPath ? localPath : @"",
                               nil];
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : @"";
    BOOL animationContent = TGMediaItemIsAnimation(mediaItem);
    NSUInteger index = 0;
    for (index = 0; index < [candidatePaths count]; index++) {
        NSString *path = [candidatePaths objectAtIndex:index];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            continue;
        }
        NSString *extension = [[path pathExtension] lowercaseString];
        BOOL supported = ([extension isEqualToString:@"gif"] ||
                          [extension isEqualToString:@"mp4"] ||
                          [extension isEqualToString:@"mov"] ||
                          [extension isEqualToString:@"m4v"]);
        if (supported || (animationContent && ([mimeType isEqualToString:@"image/gif"] || [mimeType isEqualToString:@"video/mp4"]))) {
            return path;
        }
    }
    return nil;
}

NSString *TGInlinePlaybackKindForMediaItem(NSDictionary *mediaItem) {
    id stickerFormatObject = [mediaItem objectForKey:@"sticker_format"];
    NSString *stickerFormat = [stickerFormatObject isKindOfClass:[NSString class]] ? (NSString *)stickerFormatObject : @"";
    if ([TGMediaItemContentType(mediaItem) isEqualToString:@"messageSticker"] &&
        [stickerFormat isEqualToString:@"stickerFormatTgs"]) {
        return TGInlineMediaKindTGS;
    }
    NSString *path = TGInlinePlaybackPathForMediaItem(mediaItem);
    if ([[[path pathExtension] lowercaseString] isEqualToString:@"gif"]) {
        return TGInlineMediaKindGIF;
    }
    return TGInlineMediaKindVideo;
}

BOOL TGMediaItemSupportsPreview(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    return ([contentType isEqualToString:@"messagePhoto"] ||
            [contentType isEqualToString:@"messageVideo"] ||
            [contentType isEqualToString:@"messageVideoNote"]);
}
