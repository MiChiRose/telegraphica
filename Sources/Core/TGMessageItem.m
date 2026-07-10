#import "TGMessageItem.h"

static NSString *TGReactionSummaryByMergingSummaries(NSString *leftSummary, NSString *rightSummary) {
    if ([leftSummary length] == 0) {
        return rightSummary;
    }
    if ([rightSummary length] == 0) {
        return leftSummary;
    }

    NSMutableDictionary *countsByEmoji = [NSMutableDictionary dictionary];
    NSMutableArray *orderedEmojis = [NSMutableArray array];
    NSArray *summaries = [NSArray arrayWithObjects:leftSummary, rightSummary, nil];
    NSUInteger summaryIndex = 0;
    for (summaryIndex = 0; summaryIndex < [summaries count]; summaryIndex++) {
        NSString *summary = [summaries objectAtIndex:summaryIndex];
        NSArray *parts = [summary componentsSeparatedByString:@"  "];
        NSUInteger partIndex = 0;
        for (partIndex = 0; partIndex < [parts count]; partIndex++) {
            NSString *part = [[parts objectAtIndex:partIndex] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSRange separator = [part rangeOfString:@" " options:NSBackwardsSearch];
            NSString *emoji = nil;
            NSInteger count = 1;
            if (separator.location == NSNotFound || separator.location == 0 || NSMaxRange(separator) >= [part length]) {
                emoji = part;
            } else {
                emoji = [part substringToIndex:separator.location];
                NSString *countText = [[part substringFromIndex:NSMaxRange(separator)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSInteger parsedCount = [countText integerValue];
                if (parsedCount > 0) {
                    count = parsedCount;
                }
            }
            if ([emoji length] == 0 || count <= 0) {
                continue;
            }
            NSNumber *existingCount = [countsByEmoji objectForKey:emoji];
            if (!existingCount) {
                [orderedEmojis addObject:emoji];
                existingCount = [NSNumber numberWithInteger:0];
            }
            [countsByEmoji setObject:[NSNumber numberWithInteger:([existingCount integerValue] + count)] forKey:emoji];
        }
    }

    NSMutableArray *parts = [NSMutableArray array];
    NSUInteger emojiIndex = 0;
    for (emojiIndex = 0; emojiIndex < [orderedEmojis count]; emojiIndex++) {
        NSString *emoji = [orderedEmojis objectAtIndex:emojiIndex];
        NSNumber *count = [countsByEmoji objectForKey:emoji];
        if ([emoji length] > 0 && [count integerValue] > 0) {
            if ([count integerValue] == 1) {
                [parts addObject:emoji];
            } else {
                [parts addObject:[NSString stringWithFormat:@"%@ %ld", emoji, (long)[count integerValue]]];
            }
        }
    }
    return ([parts count] > 0) ? [parts componentsJoinedByString:@"  "] : leftSummary;
}

@implementation TGMessageItem

@synthesize chatID = _chatID;
@synthesize messageID = _messageID;
@synthesize date = _date;
@synthesize outgoing = _outgoing;
@synthesize sending = _sending;
@synthesize outgoingRead = _outgoingRead;
@synthesize preview = _preview;
@synthesize contentType = _contentType;
@synthesize mediaLocalPath = _mediaLocalPath;
@synthesize mediaWidth = _mediaWidth;
@synthesize mediaHeight = _mediaHeight;
@synthesize mediaAlbumID = _mediaAlbumID;
@synthesize mediaItems = _mediaItems;
@synthesize mediaFileID = _mediaFileID;
@synthesize mediaDuration = _mediaDuration;
@synthesize mediaMimeType = _mediaMimeType;
@synthesize downloadFileName = _downloadFileName;
@synthesize downloadFileSize = _downloadFileSize;
@synthesize reactionSummary = _reactionSummary;
@synthesize chosenReactionEmojis = _chosenReactionEmojis;

- (instancetype)initWithChatID:(NSNumber *)chatID
                     messageID:(NSNumber *)messageID
                          date:(NSNumber *)date
                      outgoing:(BOOL)outgoing
                       preview:(NSString *)preview {
    self = [super init];
    if (self) {
        self.chatID = chatID;
        self.messageID = messageID;
        self.date = date ? date : [NSNumber numberWithInteger:0];
        self.outgoing = outgoing;
        self.sending = NO;
        self.outgoingRead = NO;
        self.preview = ([preview length] > 0) ? preview : @"[Message]";
    }
    return self;
}

- (BOOL)isPhotoMessage {
    return [self.contentType isEqualToString:@"messagePhoto"];
}

- (BOOL)isStickerMessage {
    return [self.contentType isEqualToString:@"messageSticker"];
}

- (BOOL)isDocumentMessage {
    return [self.contentType isEqualToString:@"messageDocument"];
}

- (BOOL)isVisualMediaMessage {
    if ([self.mediaItems count] > 0) {
        return YES;
    }
    if ([self isDocumentMessage]) {
        NSString *label = [self.preview length] > 0 ? self.preview : @"";
        BOOL visualLabel = ([label hasPrefix:@"[Photo]"] ||
                            [label hasPrefix:@"[Video]"] ||
                            [label hasPrefix:@"[GIF]"] ||
                            [label hasPrefix:@"[Sticker]"]);
        BOOL playableFallback = (([label hasPrefix:@"[Video]"] || [label hasPrefix:@"[GIF]"]) &&
                                 [self.mediaFileID respondsToSelector:@selector(integerValue)] &&
                                 [self.mediaFileID integerValue] > 0);
        return (visualLabel && ([self.mediaLocalPath length] > 0 || [self.mediaItems count] > 0 || playableFallback));
    }
    if ([self isPhotoMessage]) {
        return ([self.mediaLocalPath length] > 0 || [self.mediaItems count] > 0);
    }
    return ([self isStickerMessage] ||
            [self.contentType isEqualToString:@"messageAnimation"] ||
            [self.contentType isEqualToString:@"messageVideo"] ||
            [self.contentType isEqualToString:@"messageVideoNote"]);
}

- (BOOL)isVoiceNoteMessage {
    return [self.contentType isEqualToString:@"messageVoiceNote"];
}

- (BOOL)isVideoNoteMessage {
    return [self.contentType isEqualToString:@"messageVideoNote"];
}

- (BOOL)isPlayableMediaMessage {
    if ([self isVoiceNoteMessage] || [self isVideoNoteMessage]) {
        return YES;
    }
    return ([self.contentType isEqualToString:@"messageAudio"] ||
            [self.contentType isEqualToString:@"messageVideo"] ||
            [self.contentType isEqualToString:@"messageAnimation"]);
}

- (BOOL)isMediaAlbumMessage {
    return ([self.mediaItems count] > 1);
}

- (NSDictionary *)visualMediaDictionary {
    if (![self isVisualMediaMessage]) {
        return nil;
    }

    NSMutableDictionary *media = [NSMutableDictionary dictionary];
    if ([self.mediaLocalPath length] > 0) {
        [media setObject:self.mediaLocalPath forKey:@"local_path"];
    }
    if ([self.mediaWidth respondsToSelector:@selector(floatValue)] && [self.mediaWidth floatValue] > 0.0) {
        [media setObject:self.mediaWidth forKey:@"width"];
    }
    if ([self.mediaHeight respondsToSelector:@selector(floatValue)] && [self.mediaHeight floatValue] > 0.0) {
        [media setObject:self.mediaHeight forKey:@"height"];
    }
    if ([self.contentType length] > 0) {
        [media setObject:self.contentType forKey:@"content_type"];
    }
    if ([self.messageID respondsToSelector:@selector(longLongValue)]) {
        [media setObject:self.messageID forKey:@"message_id"];
    }
    if ([self.reactionSummary length] > 0) {
        [media setObject:self.reactionSummary forKey:@"reaction_summary"];
    }
    if ([self.mediaFileID respondsToSelector:@selector(integerValue)]) {
        [media setObject:self.mediaFileID forKey:@"playable_file_id"];
    }
    if ([self.mediaDuration respondsToSelector:@selector(integerValue)]) {
        [media setObject:self.mediaDuration forKey:@"duration"];
    }
    if ([self.mediaMimeType length] > 0) {
        [media setObject:self.mediaMimeType forKey:@"mime_type"];
    }
    if ([self.downloadFileName length] > 0) {
        [media setObject:self.downloadFileName forKey:@"file_name"];
    }
    if ([self.downloadFileSize respondsToSelector:@selector(longLongValue)]) {
        [media setObject:self.downloadFileSize forKey:@"file_size"];
    }
    NSString *placeholder = [self visualMediaPlaceholderTitle];
    if ([placeholder length] > 0) {
        [media setObject:placeholder forKey:@"placeholder"];
    }
    return ([media count] > 0) ? media : nil;
}

- (NSArray *)visualMediaItems {
    if ([self.mediaItems count] > 0) {
        return self.mediaItems;
    }
    NSDictionary *media = [self visualMediaDictionary];
    return media ? [NSArray arrayWithObject:media] : [NSArray array];
}

- (void)addVisualMediaFromMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isVisualMediaMessage]) {
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    if ([self.mediaItems count] > 0) {
        [items addObjectsFromArray:self.mediaItems];
    } else {
        NSDictionary *ownMedia = [self visualMediaDictionary];
        if (ownMedia) {
            [items addObject:ownMedia];
        }
    }

    NSArray *incomingItems = [item visualMediaItems];
    NSUInteger index = 0;
    for (index = 0; index < [incomingItems count]; index++) {
        id media = [incomingItems objectAtIndex:index];
        if ([media isKindOfClass:[NSDictionary class]]) {
            [items addObject:media];
        }
    }

    NSSortDescriptor *messageIDSort = [[[NSSortDescriptor alloc] initWithKey:@"message_id" ascending:YES] autorelease];
    self.mediaItems = [items sortedArrayUsingDescriptors:[NSArray arrayWithObject:messageIDSort]];

    NSString *incomingReaction = [item reactionSummary];
    if ([incomingReaction length] > 0) {
        self.reactionSummary = TGReactionSummaryByMergingSummaries(self.reactionSummary, incomingReaction);
    }
}

- (NSString *)visualMediaPlaceholderTitle {
    if ([self isMediaAlbumMessage]) {
        return @"Media";
    }
    if ([self isStickerMessage]) {
        NSString *preview = ([self.preview length] > 0) ? self.preview : @"";
        NSString *stickerPrefix = @"[Sticker] ";
        if ([preview hasPrefix:stickerPrefix] && [preview length] > [stickerPrefix length]) {
            return [preview substringFromIndex:[stickerPrefix length]];
        }
        return @"Sticker";
    }
    if ([self.contentType isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([self isVideoNoteMessage]) {
        return @"Video note";
    }
    if ([self.contentType isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    if ([self isDocumentMessage]) {
        return @"Media";
    }
    return @"Photo";
}

- (NSString *)directionSummary {
    return self.outgoing ? @"Outgoing" : @"Incoming";
}

- (id)copyWithZone:(NSZone *)zone {
    TGMessageItem *copy = [[[self class] allocWithZone:zone] initWithChatID:_chatID
                                                                  messageID:_messageID
                                                                       date:_date
                                                                   outgoing:_outgoing
                                                                    preview:_preview];
    [copy setSending:_sending];
    [copy setOutgoingRead:_outgoingRead];
    [copy setContentType:_contentType];
    [copy setMediaLocalPath:_mediaLocalPath];
    [copy setMediaWidth:_mediaWidth];
    [copy setMediaHeight:_mediaHeight];
    [copy setMediaAlbumID:_mediaAlbumID];
    [copy setMediaItems:_mediaItems];
    [copy setMediaFileID:_mediaFileID];
    [copy setMediaDuration:_mediaDuration];
    [copy setMediaMimeType:_mediaMimeType];
    [copy setDownloadFileName:_downloadFileName];
    [copy setDownloadFileSize:_downloadFileSize];
    [copy setReactionSummary:_reactionSummary];
    [copy setChosenReactionEmojis:_chosenReactionEmojis];
    return copy;
}

- (id)valueForTableColumnIdentifier:(id)identifier {
    if ([identifier isEqual:@"date"]) {
        return self.date;
    }
    if ([identifier isEqual:@"direction"]) {
        return [self directionSummary];
    }
    if ([identifier isEqual:@"preview"]) {
        return self.preview;
    }
    if ([identifier isEqual:@"message_id"]) {
        return self.messageID;
    }
    if ([identifier isEqual:@"chat_id"]) {
        return self.chatID;
    }
    return @"";
}

- (void)dealloc {
    [_chatID release];
    [_messageID release];
    [_date release];
    [_preview release];
    [_contentType release];
    [_mediaLocalPath release];
    [_mediaWidth release];
    [_mediaHeight release];
    [_mediaAlbumID release];
    [_mediaItems release];
    [_mediaFileID release];
    [_mediaDuration release];
    [_mediaMimeType release];
    [_downloadFileName release];
    [_downloadFileSize release];
    [_reactionSummary release];
    [_chosenReactionEmojis release];
    [super dealloc];
}

@end
