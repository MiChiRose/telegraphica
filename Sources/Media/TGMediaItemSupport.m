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

NSString *TGMediaItemStickerFormat(NSDictionary *mediaItem) {
    id stickerFormat = [mediaItem objectForKey:@"sticker_format"];
    return [stickerFormat isKindOfClass:[NSString class]] ? (NSString *)stickerFormat : @"";
}

BOOL TGMediaItemIsAnimation(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageAnimation"];
}

BOOL TGMediaItemIsVideo(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    return ([contentType isEqualToString:@"messageVideo"] ||
            [contentType isEqualToString:@"messageVideoNote"]);
}

static BOOL TGMediaItemIsStickerContent(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageSticker"];
}

BOOL TGMediaItemIsTGSSticker(NSDictionary *mediaItem) {
    return (TGMediaItemIsStickerContent(mediaItem) &&
            [TGMediaItemStickerFormat(mediaItem) isEqualToString:@"stickerFormatTgs"]);
}

BOOL TGMediaItemIsWebMSticker(NSDictionary *mediaItem) {
    NSString *stickerFormat = TGMediaItemStickerFormat(mediaItem);
    if (TGMediaItemIsStickerContent(mediaItem) && [stickerFormat isEqualToString:@"stickerFormatWebm"]) {
        return YES;
    }
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? [(NSString *)mimeTypeObject lowercaseString] : @"";
    NSString *localPath = TGMediaItemFullLocalPath(mediaItem);
    if ([localPath length] == 0) {
        localPath = TGMediaItemLocalPath(mediaItem);
    }
    return (TGMediaItemIsStickerContent(mediaItem) &&
            ([mimeType isEqualToString:@"video/webm"] ||
             [[[localPath pathExtension] lowercaseString] isEqualToString:@"webm"]));
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
    if (TGMediaItemIsTGSSticker(mediaItem)) {
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
                          [extension isEqualToString:@"webm"] ||
                          [extension isEqualToString:@"mp4"] ||
                          [extension isEqualToString:@"mov"] ||
                          [extension isEqualToString:@"m4v"]);
        if (supported || (animationContent && ([mimeType isEqualToString:@"image/gif"] ||
                                               [mimeType isEqualToString:@"video/mp4"] ||
                                               [mimeType isEqualToString:@"video/webm"]))) {
            return path;
        }
    }
    return nil;
}

NSString *TGInlinePlaybackKindForMediaItem(NSDictionary *mediaItem) {
    if (TGMediaItemIsTGSSticker(mediaItem)) {
        return TGInlineMediaKindTGS;
    }
    NSString *path = TGInlinePlaybackPathForMediaItem(mediaItem);
    if ([[[path pathExtension] lowercaseString] isEqualToString:@"gif"]) {
        return TGInlineMediaKindGIF;
    }
    return TGInlineMediaKindVideo;
}

NSString *TGMediaItemInlinePlaybackDiagnosticSummary(NSDictionary *mediaItem) {
    if (![mediaItem isKindOfClass:[NSDictionary class]]) {
        return @"media item is missing";
    }
    NSString *contentType = TGMediaItemContentType(mediaItem);
    NSString *stickerFormat = TGMediaItemStickerFormat(mediaItem);
    id mimeTypeObject = [mediaItem objectForKey:@"mime_type"];
    NSString *mimeType = [mimeTypeObject isKindOfClass:[NSString class]] ? (NSString *)mimeTypeObject : @"";
    NSString *localPath = TGMediaItemLocalPath(mediaItem);
    NSString *fullPath = TGMediaItemFullLocalPath(mediaItem);
    NSString *playablePath = TGMediaItemPlayableLocalPath(mediaItem);
    NSString *inlinePath = TGInlinePlaybackPathForMediaItem(mediaItem);
    NSString *kind = TGInlinePlaybackKindForMediaItem(mediaItem);
    BOOL inlinePathExists = ([inlinePath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:inlinePath]);
    NSString *fileName = [inlinePath length] > 0 ? [inlinePath lastPathComponent] : @"missing";
    return [NSString stringWithFormat:@"content=%@ format=%@ mime=%@ kind=%@ inline=%@ exists=%@ local=%@ full=%@ playable=%@",
            [contentType length] > 0 ? contentType : @"unknown",
            [stickerFormat length] > 0 ? stickerFormat : @"none",
            [mimeType length] > 0 ? mimeType : @"none",
            [kind length] > 0 ? kind : @"unknown",
            fileName,
            inlinePathExists ? @"yes" : @"no",
            [localPath length] > 0 ? [localPath lastPathComponent] : @"missing",
            [fullPath length] > 0 ? [fullPath lastPathComponent] : @"missing",
            [playablePath length] > 0 ? [playablePath lastPathComponent] : @"missing"];
}

BOOL TGMediaItemSupportsPreview(NSDictionary *mediaItem) {
    NSString *contentType = TGMediaItemContentType(mediaItem);
    return ([contentType isEqualToString:@"messagePhoto"] ||
            [contentType isEqualToString:@"messageVideo"] ||
            [contentType isEqualToString:@"messageVideoNote"]);
}
