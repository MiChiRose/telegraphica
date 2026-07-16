#import "TGMessageLayoutSupport.h"
#import "TGIconAssets.h"
#import "TGTheme.h"
#import "../Core/TGMessageItem.h"
#import "../Media/TGMediaImageLoader.h"
#import "../Media/TGMediaItemSupport.h"
#include <math.h>

static CGFloat const TGMessageBubbleMaximumWidth = 500.0;
static CGFloat const TGMessagePhotoMaximumSide = 320.0;

NSString *TGInitialsForTitle(NSString *title) {
    if (![title isKindOfClass:[NSString class]] || [title length] == 0) {
        return @"T";
    }

    NSArray *parts = [title componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableString *initials = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < [parts count]; index++) {
        NSString *part = [parts objectAtIndex:index];
        if (![part isKindOfClass:[NSString class]] || [part length] == 0) {
            continue;
        }
        NSRange range = [part rangeOfComposedCharacterSequenceAtIndex:0];
        [initials appendString:[[part substringWithRange:range] uppercaseString]];
        if ([initials length] >= 2) {
            break;
        }
    }
    if ([initials length] == 0) {
        NSRange range = [title rangeOfComposedCharacterSequenceAtIndex:0];
        [initials appendString:[[title substringWithRange:range] uppercaseString]];
    }
    return ([initials length] > 0) ? initials : @"T";
}

NSColor *TGAvatarColorForTitle(NSString *title) {
    static NSUInteger colors[] = {
        0x4f78a8, 0x7c8f55, 0xa66a4e, 0x8a6a9d,
        0x4d8a87, 0xa07d42, 0x63738f, 0x9a5969
    };
    NSUInteger count = sizeof(colors) / sizeof(colors[0]);
    NSUInteger index = 0;
    if ([title isKindOfClass:[NSString class]] && [title length] > 0) {
        index = [title hash] % count;
    }
    return TGColorFromHex(colors[index]);
}

void TGDrawImageInRect(NSImage *image, NSRect rect, BOOL drawingInFlippedView) {
    (void)drawingInFlippedView;
    if (!image || NSIsEmptyRect(rect)) {
        return;
    }
    NSSize imageSize = [image size];
    NSRect sourceRect = NSZeroRect;
    if (imageSize.width > 0.0 && imageSize.height > 0.0) {
        sourceRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
    }
    [image drawInRect:rect
             fromRect:sourceRect
            operation:NSCompositeSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:nil];
}

void TGDrawImageAspectFillInRect(NSImage *image, NSRect rect, BOOL drawingInFlippedView) {
    (void)drawingInFlippedView;
    if (!image || NSIsEmptyRect(rect)) {
        return;
    }

    NSSize imageSize = [image size];
    if (imageSize.width <= 0.0 || imageSize.height <= 0.0) {
        TGDrawImageInRect(image, rect, drawingInFlippedView);
        return;
    }

    CGFloat imageRatio = imageSize.width / imageSize.height;
    CGFloat rectRatio = NSWidth(rect) / NSHeight(rect);
    NSRect sourceRect = NSZeroRect;
    if (imageRatio > rectRatio) {
        CGFloat sourceWidth = imageSize.height * rectRatio;
        sourceRect = NSMakeRect(floor((imageSize.width - sourceWidth) / 2.0), 0.0, sourceWidth, imageSize.height);
    } else {
        CGFloat sourceHeight = imageSize.width / rectRatio;
        sourceRect = NSMakeRect(0.0, floor((imageSize.height - sourceHeight) / 2.0), imageSize.width, sourceHeight);
    }
    [image drawInRect:rect
             fromRect:sourceRect
            operation:NSCompositeSourceOver
             fraction:1.0
       respectFlipped:YES
                hints:nil];
}

void TGDrawAvatarInRect(NSString *imagePath, NSString *title, NSRect rect, BOOL selected, BOOL drawingInFlippedView) {
    NSBezierPath *avatarPath = [NSBezierPath bezierPathWithOvalInRect:rect];
    NSImage *image = nil;
    if ([imagePath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
        image = TGImageWithCorrectOrientationFromFile(imagePath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
        }
    }

    if (image) {
        [NSGraphicsContext saveGraphicsState];
        [avatarPath addClip];
        TGDrawImageInRect(image, rect, drawingInFlippedView);
        [NSGraphicsContext restoreGraphicsState];
    } else {
        [(selected ? TGClassicSelectedRowTextColor() : TGAvatarColorForTitle(title)) set];
        [avatarPath fill];
        NSString *initials = TGInitialsForTitle(title);
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont boldSystemFontOfSize:10.0], NSFontAttributeName,
                                    [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                    nil];
        NSSize textSize = [initials sizeWithAttributes:attributes];
        NSRect textRect = NSMakeRect(NSMidX(rect) - floor(textSize.width / 2.0),
                                     NSMidY(rect) - floor(textSize.height / 2.0) - 1.0,
                                     textSize.width,
                                     textSize.height);
        [initials drawInRect:textRect withAttributes:attributes];
    }

    [TGClassicPanelStrokeColor() set];
    [avatarPath setLineWidth:1.0];
    [avatarPath stroke];
}

NSString *TGShortTimeStringFromDateValue(NSNumber *dateValue) {
    if (![dateValue respondsToSelector:@selector(integerValue)] || [dateValue integerValue] <= 0) {
        return @"";
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[dateValue integerValue]];
    return [NSDateFormatter localizedStringFromDate:date
                                          dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
}

NSString *TGDisplayTextForMessageItem(TGMessageItem *item) {
    if (!item) {
        return @"";
    }
    NSString *preview = ([item.preview length] > 0) ? item.preview : @"";
    if ([item isVisualMediaMessage]) {
        NSArray *mediaLabels = [NSArray arrayWithObjects:
                                @"[Photo]",
                                @"[Sticker]",
                                @"[Animation]",
                                @"[GIF]",
                                @"[Video]",
                                nil];
        NSUInteger index = 0;
        for (index = 0; index < [mediaLabels count]; index++) {
            NSString *mediaLabel = [mediaLabels objectAtIndex:index];
            if ([preview isEqualToString:mediaLabel]) {
                return @"";
            }
            NSString *mediaPrefix = [mediaLabel stringByAppendingString:@" "];
            if ([preview hasPrefix:mediaPrefix]) {
                return [preview substringFromIndex:[mediaPrefix length]];
            }
        }
    }
    return preview;
}

static NSDataDetector *TGSharedLinkDetector(void) {
    static NSDataDetector *detector = nil;
    if (!detector) {
        NSError *error = nil;
        detector = [[NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error] retain];
    }
    return detector;
}

NSTextCheckingResult *TGFirstLinkResultInString(NSString *text) {
    if (![text isKindOfClass:[NSString class]] || [text length] == 0) {
        return nil;
    }
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector) {
        return nil;
    }
    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] == NSTextCheckingTypeLink && [result URL]) {
            return result;
        }
    }
    return nil;
}

NSURL *TGFirstURLInMessageItem(TGMessageItem *item) {
    NSTextCheckingResult *result = TGFirstLinkResultInString(TGDisplayTextForMessageItem(item));
    return [result URL];
}

BOOL TGIsSupportedPhotoPath(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return NO;
    }

    NSString *standardPath = [path stringByStandardizingPath];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:standardPath isDirectory:&isDirectory] || isDirectory) {
        return NO;
    }

    NSString *extension = [[standardPath pathExtension] lowercaseString];
    NSArray *allowedExtensions = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"tif", @"tiff", nil];
    return [allowedExtensions containsObject:extension];
}

NSString *TGFirstSupportedPhotoPathFromPasteboard(NSPasteboard *pasteboard) {
    if (!pasteboard) {
        return nil;
    }
    NSArray *paths = [pasteboard propertyListForType:NSFilenamesPboardType];
    if (![paths isKindOfClass:[NSArray class]]) {
        return nil;
    }

    NSUInteger index = 0;
    for (index = 0; index < [paths count]; index++) {
        id candidate = [paths objectAtIndex:index];
        if ([candidate isKindOfClass:[NSString class]] && TGIsSupportedPhotoPath((NSString *)candidate)) {
            return (NSString *)candidate;
        }
    }
    return nil;
}

NSURL *TGURLAtCharacterIndexInString(NSString *text, NSUInteger characterIndex) {
    if (![text isKindOfClass:[NSString class]] || characterIndex >= [text length]) {
        return nil;
    }
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector) {
        return nil;
    }
    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] == NSTextCheckingTypeLink && [result URL] && NSLocationInRange(characterIndex, [result range])) {
            return [result URL];
        }
    }
    return nil;
}

NSAttributedString *TGAttributedMessageString(NSString *text, NSDictionary *baseAttributes) {
    if (![text isKindOfClass:[NSString class]]) {
        text = @"";
    }
    NSMutableAttributedString *attributed = [[[NSMutableAttributedString alloc] initWithString:text
                                                                                   attributes:baseAttributes] autorelease];
    NSDataDetector *detector = TGSharedLinkDetector();
    if (!detector || [text length] == 0) {
        return attributed;
    }

    NSArray *matches = [detector matchesInString:text options:0 range:NSMakeRange(0, [text length])];
    NSUInteger index = 0;
    for (index = 0; index < [matches count]; index++) {
        NSTextCheckingResult *result = [matches objectAtIndex:index];
        if ([result resultType] != NSTextCheckingTypeLink || ![result URL]) {
            continue;
        }
        [attributed addAttribute:NSForegroundColorAttributeName value:TGClassicLinkColor() range:[result range]];
        [attributed addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:[result range]];
    }
    return attributed;
}

NSString *TGDurationStringFromSecondsValue(id durationValue) {
    NSInteger seconds = [durationValue respondsToSelector:@selector(integerValue)] ? [durationValue integerValue] : 0;
    if (seconds <= 0) {
        return @"";
    }
    NSInteger minutes = seconds / 60;
    NSInteger remainder = seconds % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)remainder];
}

NSString *TGVoicePreviewTimeString(NSTimeInterval seconds) {
    if (seconds < 0.0) {
        seconds = 0.0;
    }
    NSInteger totalSeconds = (NSInteger)floor(seconds);
    NSInteger minutes = totalSeconds / 60;
    NSInteger remainder = totalSeconds % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)remainder];
}

NSString *TGMediaItemPlaceholder(NSDictionary *mediaItem) {
    id placeholder = [mediaItem objectForKey:@"placeholder"];
    if ([placeholder isKindOfClass:[NSString class]] && [(NSString *)placeholder length] > 0) {
        return (NSString *)placeholder;
    }
    NSString *contentType = TGMediaItemContentType(mediaItem);
    if ([contentType isEqualToString:@"messageSticker"]) {
        return @"Sticker";
    }
    if ([contentType isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([contentType isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    return @"Photo";
}

BOOL TGMediaItemIsSticker(NSDictionary *mediaItem) {
    return [TGMediaItemContentType(mediaItem) isEqualToString:@"messageSticker"];
}

void TGDrawMediaKindBadge(NSString *badgeText, NSRect rect, BOOL flipped) {
    if (![badgeText isKindOfClass:[NSString class]] || [badgeText length] == 0 || NSIsEmptyRect(rect)) {
        return;
    }

    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont boldSystemFontOfSize:9.0], NSFontAttributeName,
                                [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                nil];
    NSSize badgeSize = [badgeText sizeWithAttributes:attributes];
    CGFloat badgeWidth = ceil(badgeSize.width) + 12.0;
    CGFloat badgeHeight = 18.0;
    CGFloat badgeX = NSMinX(rect) + 6.0;
    CGFloat badgeY = flipped ? (NSMaxY(rect) - badgeHeight - 6.0) : (NSMinY(rect) + 6.0);
    NSRect badgeRect = NSMakeRect(badgeX, badgeY, badgeWidth, badgeHeight);
    NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:9.0 yRadius:9.0];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.38] set];
    [badgePath fill];

    NSRect textRect = NSMakeRect(NSMinX(badgeRect),
                                 NSMinY(badgeRect) + floor((NSHeight(badgeRect) - badgeSize.height) / 2.0) - 1.0,
                                 NSWidth(badgeRect),
                                 badgeSize.height + 2.0);
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setAlignment:NSCenterTextAlignment];
    NSMutableDictionary *centeredAttributes = [NSMutableDictionary dictionaryWithDictionary:attributes];
    [centeredAttributes setObject:paragraph forKey:NSParagraphStyleAttributeName];
    [badgeText drawInRect:textRect withAttributes:centeredAttributes];
}

void TGDrawMediaPlayBadge(NSRect rect, BOOL flipped) {
    (void)flipped;
    CGFloat badgeSide = 34.0;
    NSRect badgeRect = NSMakeRect(NSMidX(rect) - (badgeSide / 2.0),
                                  NSMidY(rect) - (badgeSide / 2.0),
                                  badgeSide,
                                  badgeSide);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:badgeRect];
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.34] set];
    [circle fill];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.82] set];
    [circle setLineWidth:1.0];
    [circle stroke];

    NSRect iconRect = NSInsetRect(badgeRect, 10.0, 10.0);
    TGDrawTemplateIconAsset(@"play",
                            iconRect,
                            [NSColor colorWithCalibratedWhite:1.0 alpha:0.92],
                            1.0,
                            flipped);
}

static NSString *TGMediaFallbackIconNameForPlaceholder(NSString *placeholder) {
    if ([placeholder isEqualToString:@"Photo"]) {
        return @"image";
    }
    if ([placeholder isEqualToString:@"Sticker"]) {
        return @"image";
    }
    if ([placeholder isEqualToString:@"GIF"]) {
        return @"play";
    }
    if ([placeholder isEqualToString:@"Video"]) {
        return @"youtube";
    }
    if ([placeholder isEqualToString:@"Document"]) {
        return @"document";
    }
    return nil;
}

static NSString *TGStickerFallbackEmojiForMediaItem(NSDictionary *mediaItem) {
    id emoji = [mediaItem objectForKey:@"emoji"];
    if ([emoji isKindOfClass:[NSString class]] && [(NSString *)emoji length] > 0) {
        return (NSString *)emoji;
    }

    NSString *placeholder = TGMediaItemPlaceholder(mediaItem);
    if ([placeholder length] > 0 && ![placeholder isEqualToString:@"Sticker"]) {
        return placeholder;
    }
    return @"☺";
}

static NSString *TGStickerFallbackCaptionForMediaItem(NSDictionary *mediaItem) {
    id label = [mediaItem objectForKey:@"label"];
    if ([label isKindOfClass:[NSString class]] && [(NSString *)label length] > 0) {
        NSString *stickerPrefix = @"[Sticker] ";
        if ([(NSString *)label hasPrefix:stickerPrefix] && [(NSString *)label length] > [stickerPrefix length]) {
            return [(NSString *)label substringFromIndex:[stickerPrefix length]];
        }
        return (NSString *)label;
    }

    NSString *placeholder = TGMediaItemPlaceholder(mediaItem);
    if ([placeholder length] > 0 && ![placeholder isEqualToString:@"Sticker"]) {
        return placeholder;
    }
    return @"Sticker";
}

static NSString *TGStickerFallbackFormatBadgeForMediaItem(NSDictionary *mediaItem) {
    NSString *format = TGMediaItemStickerFormat(mediaItem);
    if ([format isEqualToString:@"stickerFormatTgs"]) {
        return @"TGS";
    }
    if ([format isEqualToString:@"stickerFormatWebm"]) {
        return @"WEBM";
    }
    if ([format isEqualToString:@"stickerFormatWebp"]) {
        return @"WEBP";
    }
    return @"STICKER";
}

static void TGDrawStickerFallbackInRect(NSDictionary *mediaItem, NSRect rect, BOOL flipped) {
    NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:11.0 yRadius:11.0];
    [[NSColor colorWithCalibratedWhite:0.985 alpha:0.96] set];
    [backgroundPath fill];

    NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 7.0, 7.0) xRadius:9.0 yRadius:9.0];
    [[NSColor colorWithCalibratedWhite:0.93 alpha:0.72] set];
    [innerPath fill];

    NSString *emoji = TGStickerFallbackEmojiForMediaItem(mediaItem);
    NSString *caption = TGStickerFallbackCaptionForMediaItem(mediaItem);
    NSFont *emojiFont = [NSFont fontWithName:@"Apple Color Emoji" size:38.0];
    if (!emojiFont) {
        emojiFont = [NSFont systemFontOfSize:38.0];
    }
    NSMutableParagraphStyle *centeredParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [centeredParagraph setAlignment:NSCenterTextAlignment];
    [centeredParagraph setLineBreakMode:NSLineBreakByTruncatingTail];
    NSDictionary *emojiAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     emojiFont, NSFontAttributeName,
                                     TGClassicInkColor(), NSForegroundColorAttributeName,
                                     centeredParagraph, NSParagraphStyleAttributeName,
                                     nil];
    NSSize emojiSize = [emoji sizeWithAttributes:emojiAttributes];
    CGFloat emojiY = NSMidY(rect) - floor(emojiSize.height / 2.0) - 8.0;
    NSRect emojiRect = NSMakeRect(NSMinX(rect) + 8.0,
                                  emojiY,
                                  NSWidth(rect) - 16.0,
                                  emojiSize.height + 4.0);
    [emoji drawInRect:emojiRect withAttributes:emojiAttributes];

    if ([caption length] > 0 && ![caption isEqualToString:emoji]) {
        NSDictionary *captionAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSFont boldSystemFontOfSize:11.0], NSFontAttributeName,
                                           TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                           centeredParagraph, NSParagraphStyleAttributeName,
                                           nil];
        NSSize captionSize = [caption sizeWithAttributes:captionAttributes];
        CGFloat captionY = NSMaxY(emojiRect) + 2.0;
        if (!flipped) {
            captionY = NSMinY(emojiRect) - captionSize.height - 3.0;
        }
        NSRect captionRect = NSMakeRect(NSMinX(rect) + 8.0,
                                        captionY,
                                        NSWidth(rect) - 16.0,
                                        captionSize.height + 3.0);
        [caption drawInRect:captionRect withAttributes:captionAttributes];
    }

    TGDrawMediaKindBadge(TGStickerFallbackFormatBadgeForMediaItem(mediaItem), rect, flipped);
}

NSSize TGDisplaySizeForMediaDictionary(NSDictionary *mediaItem, CGFloat maximumWidth) {
    BOOL sticker = TGMediaItemIsSticker(mediaItem);
    CGFloat maximumSide = sticker ? 128.0 : TGMessagePhotoMaximumSide;
    CGFloat minimumWidth = sticker ? 88.0 : 140.0;
    CGFloat minimumHeight = sticker ? 88.0 : 92.0;
    CGFloat width = sticker ? 112.0 : 220.0;
    CGFloat height = sticker ? 112.0 : 160.0;
    id widthObject = [mediaItem objectForKey:@"width"];
    id heightObject = [mediaItem objectForKey:@"height"];
    if ([widthObject respondsToSelector:@selector(floatValue)] && [widthObject floatValue] > 0.0) {
        width = [widthObject floatValue];
    }
    if ([heightObject respondsToSelector:@selector(floatValue)] && [heightObject floatValue] > 0.0) {
        height = [heightObject floatValue];
    }
    if (width <= 0.0 || height <= 0.0) {
        width = sticker ? 112.0 : 220.0;
        height = sticker ? 112.0 : 160.0;
    }
    if (sticker && [TGMediaItemLocalPath(mediaItem) length] == 0) {
        width = 112.0;
        height = 112.0;
    }
    CGFloat scale = maximumSide / ((width > height) ? width : height);
    if (scale < 1.0) {
        width *= scale;
        height *= scale;
    }
    if (width < minimumWidth) {
        CGFloat grow = minimumWidth / width;
        width *= grow;
        height *= grow;
    }
    if (height < minimumHeight) {
        CGFloat grow = minimumHeight / height;
        width *= grow;
        height *= grow;
    }
    if (width > maximumSide) {
        CGFloat shrink = maximumSide / width;
        width *= shrink;
        height *= shrink;
    }
    if (height > maximumSide) {
        CGFloat shrink = maximumSide / height;
        width *= shrink;
        height *= shrink;
    }
    if (maximumWidth > 0.0 && width > maximumWidth) {
        CGFloat shrink = maximumWidth / width;
        width *= shrink;
        height *= shrink;
    }
    return NSMakeSize(ceil(width), ceil(height));
}

NSSize TGPhotoDisplaySizeForMessageItem(TGMessageItem *item, CGFloat maximumWidth) {
    NSArray *mediaItems = [item visualMediaItems];
    if ([mediaItems count] > 1) {
        CGFloat albumWidth = maximumWidth;
        if (albumWidth > 360.0) {
            albumWidth = 360.0;
        }
        if (albumWidth < 220.0) {
            albumWidth = 220.0;
        }
        NSUInteger count = [mediaItems count];
        CGFloat albumHeight = 210.0;
        if (count == 2) {
            albumHeight = 170.0;
        } else if (count == 3) {
            albumHeight = 260.0;
        } else {
            albumHeight = 286.0;
        }
        if (albumHeight > albumWidth) {
            albumHeight = albumWidth;
        }
        return NSMakeSize(ceil(albumWidth), ceil(albumHeight));
    }
    if ([mediaItems count] == 1) {
        return TGDisplaySizeForMediaDictionary((NSDictionary *)[mediaItems objectAtIndex:0], maximumWidth);
    }

    BOOL sticker = [item isStickerMessage];
    CGFloat maximumSide = sticker ? 128.0 : TGMessagePhotoMaximumSide;
    CGFloat minimumWidth = sticker ? 88.0 : 140.0;
    CGFloat minimumHeight = sticker ? 88.0 : 92.0;
    CGFloat width = sticker ? 112.0 : 220.0;
    CGFloat height = sticker ? 112.0 : 160.0;
    if ([item.mediaWidth respondsToSelector:@selector(floatValue)] && [item.mediaWidth floatValue] > 0.0) {
        width = [item.mediaWidth floatValue];
    }
    if ([item.mediaHeight respondsToSelector:@selector(floatValue)] && [item.mediaHeight floatValue] > 0.0) {
        height = [item.mediaHeight floatValue];
    }
    if (width <= 0.0 || height <= 0.0) {
        width = sticker ? 112.0 : 220.0;
        height = sticker ? 112.0 : 160.0;
    }
    if (sticker && [[item mediaLocalPath] length] == 0) {
        width = 112.0;
        height = 112.0;
    }
    CGFloat scale = maximumSide / ((width > height) ? width : height);
    if (scale < 1.0) {
        width *= scale;
        height *= scale;
    }
    if (width < minimumWidth) {
        CGFloat grow = minimumWidth / width;
        width *= grow;
        height *= grow;
    }
    if (height < minimumHeight) {
        CGFloat grow = minimumHeight / height;
        width *= grow;
        height *= grow;
    }
    if (width > maximumSide) {
        CGFloat shrink = maximumSide / width;
        width *= shrink;
        height *= shrink;
    }
    if (height > maximumSide) {
        CGFloat shrink = maximumSide / height;
        width *= shrink;
        height *= shrink;
    }
    if (maximumWidth > 0.0 && width > maximumWidth) {
        CGFloat shrink = maximumWidth / width;
        width *= shrink;
        height *= shrink;
    }
    return NSMakeSize(ceil(width), ceil(height));
}

NSArray *TGMediaTileRectsForMessageItem(TGMessageItem *item, NSRect imageRect) {
    NSMutableArray *rects = [NSMutableArray array];
    NSArray *mediaItems = [item visualMediaItems];
    NSUInteger count = [mediaItems count];
    CGFloat gap = 3.0;
    if (count <= 1 || NSIsEmptyRect(imageRect)) {
        [rects addObject:[NSValue valueWithRect:imageRect]];
        return rects;
    }

    if (count == 2) {
        CGFloat tileWidth = floor((NSWidth(imageRect) - gap) / 2.0);
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), tileWidth, NSHeight(imageRect))]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + tileWidth + gap, NSMinY(imageRect), NSWidth(imageRect) - tileWidth - gap, NSHeight(imageRect))]];
        return rects;
    }

    if (count == 3) {
        CGFloat leftWidth = floor((NSWidth(imageRect) - gap) * 0.62);
        CGFloat rightWidth = NSWidth(imageRect) - leftWidth - gap;
        CGFloat halfHeight = floor((NSHeight(imageRect) - gap) / 2.0);
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), leftWidth, NSHeight(imageRect))]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + leftWidth + gap, NSMinY(imageRect), rightWidth, halfHeight)]];
        [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + leftWidth + gap, NSMinY(imageRect) + halfHeight + gap, rightWidth, NSHeight(imageRect) - halfHeight - gap)]];
        return rects;
    }

    CGFloat columnWidth = floor((NSWidth(imageRect) - gap) / 2.0);
    CGFloat rowHeight = floor((NSHeight(imageRect) - gap) / 2.0);
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect), columnWidth, rowHeight)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + columnWidth + gap, NSMinY(imageRect), NSWidth(imageRect) - columnWidth - gap, rowHeight)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect), NSMinY(imageRect) + rowHeight + gap, columnWidth, NSHeight(imageRect) - rowHeight - gap)]];
    [rects addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(imageRect) + columnWidth + gap, NSMinY(imageRect) + rowHeight + gap, NSWidth(imageRect) - columnWidth - gap, NSHeight(imageRect) - rowHeight - gap)]];
    return rects;
}

NSRect TGStickerAdjustedMediaRect(NSDictionary *mediaItem, NSRect rect, BOOL drawingInFlippedView) {
    if (TGMediaItemIsSticker(mediaItem)) {
        rect.origin.y += drawingInFlippedView ? 6.0 : -6.0;
    }
    return rect;
}

void TGDrawMediaItemInRect(NSDictionary *mediaItem, NSRect rect, BOOL outgoing, BOOL flipped, BOOL aspectFill, NSUInteger overflowCount) {
    if (![mediaItem isKindOfClass:[NSDictionary class]] || NSIsEmptyRect(rect)) {
        return;
    }

    NSBezierPath *mediaPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:7.0 yRadius:7.0];
    NSString *localPath = TGMediaItemLocalPath(mediaItem);
    NSImage *image = nil;
    if ([localPath length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        image = TGImageWithCorrectOrientationFromFile(localPath);
        if (!image) {
            image = [[[NSImage alloc] initWithContentsOfFile:localPath] autorelease];
        }
    }

    if (!image) {
        NSData *miniThumbnailData = TGMediaItemMiniThumbnailData(mediaItem);
        if ([miniThumbnailData length] > 0) {
            image = [[[NSImage alloc] initWithData:miniThumbnailData] autorelease];
        }
    }

    BOOL sticker = TGMediaItemIsSticker(mediaItem);
    if (image) {
        [NSGraphicsContext saveGraphicsState];
        [mediaPath addClip];
        if (aspectFill) {
            TGDrawImageAspectFillInRect(image, rect, flipped);
        } else {
            TGDrawImageInRect(image, rect, flipped);
        }
        [NSGraphicsContext restoreGraphicsState];
    } else if (sticker) {
        TGDrawStickerFallbackInRect(mediaItem, rect, flipped);
    } else {
        [[NSColor colorWithCalibratedWhite:0.96 alpha:0.92] set];
        [mediaPath fill];
        NSString *fallbackText = TGMediaItemPlaceholder(mediaItem);
        NSString *fallbackIconName = TGMediaFallbackIconNameForPlaceholder(fallbackText);
        if ([fallbackIconName length] > 0) {
            CGFloat iconSide = 34.0;
            NSRect fallbackIconRect = NSMakeRect(NSMidX(rect) - floor(iconSide / 2.0),
                                                 NSMidY(rect) - floor(iconSide / 2.0) - 7.0,
                                                 iconSide,
                                                 iconSide);
            TGDrawTemplateIconAsset(fallbackIconName,
                                    fallbackIconRect,
                                    TGClassicMutedInkColor(),
                                    0.86,
                                    flipped);
        }
        CGFloat fallbackFontSize = ([fallbackText length] <= 4) ? 34.0 : 13.0;
        NSMutableParagraphStyle *fallbackParagraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [fallbackParagraph setAlignment:NSCenterTextAlignment];
        NSDictionary *fallbackAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:fallbackFontSize], NSFontAttributeName,
                                            TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                            fallbackParagraph, NSParagraphStyleAttributeName,
                                            nil];
        NSSize fallbackSize = [fallbackText sizeWithAttributes:fallbackAttributes];
        CGFloat fallbackTextCenterY = [fallbackIconName length] > 0 ? (NSMidY(rect) + 26.0) : NSMidY(rect);
        NSRect fallbackRect = NSMakeRect(NSMinX(rect) + 4.0,
                                         fallbackTextCenterY - ceil(fallbackSize.height / 2.0) - 1.0,
                                         NSWidth(rect) - 8.0,
                                         fallbackSize.height + 4.0);
        [fallbackText drawInRect:fallbackRect withAttributes:fallbackAttributes];
    }

    [(outgoing ? TGClassicOutgoingBubbleStrokeColor() : TGClassicIncomingBubbleStrokeColor()) set];
    [mediaPath setLineWidth:1.0];
    [mediaPath stroke];

    if (overflowCount == 0) {
        if (TGMediaItemIsAnimation(mediaItem)) {
            TGDrawMediaKindBadge(@"GIF", rect, flipped);
        } else if (TGMediaItemIsVideo(mediaItem)) {
            TGDrawMediaKindBadge(@"VIDEO", rect, flipped);
        }
        if (TGMediaItemIsPlayable(mediaItem) && !sticker) {
            TGDrawMediaPlayBadge(rect, flipped);
        }
    }

    if (overflowCount > 0) {
        [NSGraphicsContext saveGraphicsState];
        [mediaPath addClip];
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.38] set];
        NSRectFillUsingOperation(rect, NSCompositeSourceOver);
        [NSGraphicsContext restoreGraphicsState];

        NSString *overflowText = [NSString stringWithFormat:@"+%lu", (unsigned long)overflowCount];
        NSDictionary *overflowAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSFont boldSystemFontOfSize:22.0], NSFontAttributeName,
                                            [NSColor colorWithCalibratedWhite:1.0 alpha:0.96], NSForegroundColorAttributeName,
                                            nil];
        NSSize overflowSize = [overflowText sizeWithAttributes:overflowAttributes];
        NSRect overflowRect = NSMakeRect(NSMidX(rect) - floor(overflowSize.width / 2.0),
                                         NSMidY(rect) - floor(overflowSize.height / 2.0) - 1.0,
                                         overflowSize.width,
                                         overflowSize.height + 2.0);
        [overflowText drawInRect:overflowRect withAttributes:overflowAttributes];
    }
}

CGFloat TGReactionBandHeightForMessageItem(TGMessageItem *item);
CGFloat TGMessageSenderHeaderHeightForItem(TGMessageItem *item, BOOL showSenderDetails);

CGFloat TGMaximumBubbleWidthForItem(TGMessageItem *item, CGFloat availableWidth) {
    CGFloat widthRatio = ([item isVisualMediaMessage] ? 0.78 : 0.68);
    CGFloat maximumWidth = availableWidth * widthRatio;
    if (maximumWidth > TGMessageBubbleMaximumWidth) {
        maximumWidth = TGMessageBubbleMaximumWidth;
    }
    if (maximumWidth < 180.0) {
        maximumWidth = 180.0;
    }
    return maximumWidth;
}

BOOL TGMessageItemIsNonVisualPlayableMedia(TGMessageItem *item) {
    return ([item isKindOfClass:[TGMessageItem class]] &&
            [item isPlayableMediaMessage] &&
            ![item isVisualMediaMessage]);
}

BOOL TGMessageItemIsAudioOnlyPlayableMedia(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return NO;
    }
    if ([item isVoiceNoteMessage] || [[item contentType] isEqualToString:@"messageAudio"]) {
        return YES;
    }
    if ([item isVideoNoteMessage] || [[item contentType] isEqualToString:@"messageVideo"] || [[item contentType] isEqualToString:@"messageAnimation"]) {
        return NO;
    }
    NSString *mimeType = [[item mediaMimeType] lowercaseString];
    return [mimeType hasPrefix:@"audio/"];
}

BOOL TGMessageItemHasDownloadableAttachment(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return NO;
    }
    if ([[item mediaFileID] respondsToSelector:@selector(integerValue)] && [[item mediaFileID] integerValue] > 0) {
        return YES;
    }
    if ([[item mediaLocalPath] length] > 0) {
        return YES;
    }
    NSArray *mediaItems = [item visualMediaItems];
    NSUInteger index = 0;
    for (index = 0; index < [mediaItems count]; index++) {
        id media = [mediaItems objectAtIndex:index];
        if (![media isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        if ([TGMediaItemLocalPath(media) length] > 0 ||
            [TGMediaItemFullLocalPath(media) length] > 0 ||
            [TGMediaItemFullFileID(media) respondsToSelector:@selector(integerValue)]) {
            return YES;
        }
    }
    return NO;
}

NSString *TGPlayableMediaTitleForMessageItem(TGMessageItem *item) {
    if ([item isVoiceNoteMessage]) {
        return @"Voice message";
    }
    if ([item isVideoNoteMessage]) {
        return @"Video message";
    }
    if ([[item contentType] isEqualToString:@"messageAudio"]) {
        return @"Audio";
    }
    if ([[item contentType] isEqualToString:@"messageAnimation"]) {
        return @"GIF";
    }
    if ([[item contentType] isEqualToString:@"messageVideo"]) {
        return @"Video";
    }
    return @"Media";
}

CGFloat TGPlayableMediaBubbleWidthForItem(TGMessageItem *item, CGFloat maximumWidth) {
    (void)item;
    CGFloat width = 228.0;
    if (width > maximumWidth) {
        width = maximumWidth;
    }
    if (width < 170.0) {
        width = 170.0;
    }
    return width;
}

CGFloat TGPlayableMediaBubbleHeightForItem(TGMessageItem *item) {
    CGFloat height = [item isVoiceNoteMessage] ? 58.0 : 62.0;
    height += TGReactionBandHeightForMessageItem(item);
    return height;
}

CGFloat TGReactionBandHeightForMessageItem(TGMessageItem *item) {
    return ([[item reactionSummary] length] > 0) ? 22.0 : 0.0;
}

CGFloat TGMessageSenderHeaderHeightForItem(TGMessageItem *item, BOOL showSenderDetails) {
    if (!showSenderDetails || ![item isKindOfClass:[TGMessageItem class]] || [item outgoing]) {
        return 0.0;
    }
    return ([[item senderDisplayName] length] > 0) ? 17.0 : 0.0;
}

CGFloat TGOutgoingStatusDotsWidthForItem(TGMessageItem *item) {
    return ([item isKindOfClass:[TGMessageItem class]] && [item outgoing]) ? 11.0 : 0.0;
}

CGFloat TGComposerMinimumInputHeight(void) {
    return 20.0;
}

CGFloat TGComposerMaximumInputHeight(void) {
    return 84.0;
}

CGFloat TGComposerLineHeight(void) {
    return 16.0;
}

NSString *TGOutgoingStatusDotsInlineTextForItem(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item outgoing]) {
        return @"";
    }

    BOOL delivered = ![item sending];
    BOOL read = delivered && [item outgoingRead];
    unichar chars[2];
    chars[0] = delivered ? 0x25CF : 0x25CB;
    chars[1] = read ? 0x25CF : 0x25CB;
    return [NSString stringWithCharacters:chars length:2];
}

void TGDrawOutgoingStatusDotsForItem(TGMessageItem *item, NSRect timeRect, BOOL flipped) {
    (void)flipped;
    if (![item isKindOfClass:[TGMessageItem class]] || ![item outgoing] || NSIsEmptyRect(timeRect)) {
        return;
    }

    CGFloat dotSide = 4.0;
    CGFloat dotGap = 3.0;
    CGFloat dotX = NSMaxX(timeRect) + 4.0;
    CGFloat dotY = NSMinY(timeRect) + floor((NSHeight(timeRect) - dotSide) / 2.0) + 1.0;
    NSColor *strokeColor = [NSColor colorWithCalibratedWhite:0.470 alpha:0.72];
    NSColor *fillColor = [NSColor colorWithCalibratedWhite:0.470 alpha:0.86];
    BOOL delivered = ![item sending];
    BOOL read = delivered && [item outgoingRead];

    NSUInteger index = 0;
    for (index = 0; index < 2; index++) {
        NSRect dotRect = NSMakeRect(dotX + ((dotSide + dotGap) * (CGFloat)index), dotY, dotSide, dotSide);
        NSBezierPath *dotPath = [NSBezierPath bezierPathWithOvalInRect:dotRect];
        if ((index == 0 && delivered) || (index == 1 && read)) {
            [fillColor set];
            [dotPath fill];
        }
        [strokeColor set];
        [dotPath setLineWidth:0.8];
        [dotPath stroke];
    }
}

CGFloat TGMessageMediaFooterHeightForItem(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isVisualMediaMessage]) {
        return 0.0;
    }

    NSString *messageText = [item isStickerMessage] ? @"" : TGDisplayTextForMessageItem(item);
    if ([messageText length] > 0) {
        return 0.0;
    }

    return ([TGShortTimeStringFromDateValue([item date]) length] > 0) ? 18.0 : 0.0;
}

CGFloat TGMessageBubbleHeightForItem(TGMessageItem *item, CGFloat availableWidth, BOOL showSenderDetails) {
    if (!item) {
        return 48.0;
    }
    CGFloat maximumTextWidth = TGMaximumBubbleWidthForItem(item, availableWidth);

    NSString *text = ([item isStickerMessage] || TGMessageItemIsNonVisualPlayableMedia(item)) ? @"" : TGDisplayTextForMessageItem(item);
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                paragraph, NSParagraphStyleAttributeName,
                                nil];
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    nil];
    CGFloat textHeight = 0.0;
    if ([text length] > 0) {
        NSMutableAttributedString *composedText = [[[NSMutableAttributedString alloc] initWithString:text attributes:attributes] autorelease];
        NSString *timeString = TGShortTimeStringFromDateValue([item date]);
        if ([timeString length] > 0) {
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"  %@", timeString]
                                                                                  attributes:timeAttributes] autorelease];
            [composedText appendAttributedString:timeSuffixText];
            NSString *statusDots = TGOutgoingStatusDotsInlineTextForItem(item);
            if ([statusDots length] > 0) {
                NSMutableDictionary *statusAttributes = [NSMutableDictionary dictionaryWithDictionary:timeAttributes];
                [statusAttributes setObject:[NSFont boldSystemFontOfSize:7.0] forKey:NSFontAttributeName];
                NSAttributedString *statusSuffixText = [[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@", statusDots]
                                                                                        attributes:statusAttributes] autorelease];
                [composedText appendAttributedString:statusSuffixText];
            }
        }
        NSRect textRect = [composedText boundingRectWithSize:NSMakeSize(maximumTextWidth - 24.0, 1000.0)
                                                     options:NSStringDrawingUsesLineFragmentOrigin];
        textHeight = ceil(NSHeight(textRect));
    }

    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat height = textHeight + 26.0 + senderHeaderHeight;
    if (TGMessageItemIsNonVisualPlayableMedia(item)) {
        height = TGPlayableMediaBubbleHeightForItem(item) + senderHeaderHeight;
    }
    if ([item isVisualMediaMessage]) {
        NSSize photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumTextWidth - 16.0);
        height = photoSize.height + 24.0 + TGMessageMediaFooterHeightForItem(item) + senderHeaderHeight + ((textHeight > 0.0) ? (textHeight + 8.0) : 0.0);
    }
    if (height < 42.0) {
        height = 42.0;
    }
    if (!TGMessageItemIsNonVisualPlayableMedia(item)) {
        height += TGReactionBandHeightForMessageItem(item);
    }
    return height + 10.0;
}

NSRect TGMessageBubbleRectForItem(TGMessageItem *item, NSRect cellFrame, BOOL showSenderDetails) {
    if (![item isKindOfClass:[TGMessageItem class]] || NSIsEmptyRect(cellFrame)) {
        return NSZeroRect;
    }

    NSString *messageText = ([item isStickerMessage] || TGMessageItemIsNonVisualPlayableMedia(item)) ? @"" : TGDisplayTextForMessageItem(item);
    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));
    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
            NSString *statusDots = TGOutgoingStatusDotsInlineTextForItem(item);
            if ([statusDots length] > 0) {
                NSMutableDictionary *statusAttributes = [NSMutableDictionary dictionaryWithDictionary:timeAttributes];
                [statusAttributes setObject:[NSFont boldSystemFontOfSize:7.0] forKey:NSFontAttributeName];
                [statusAttributes setObject:[NSColor colorWithCalibratedWhite:0.470 alpha:0.78] forKey:NSForegroundColorAttributeName];
                NSString *statusSuffix = [NSString stringWithFormat:@" %@", statusDots];
                NSAttributedString *statusSuffixText = [[[NSAttributedString alloc] initWithString:statusSuffix attributes:statusAttributes] autorelease];
                [composedMessageText appendAttributedString:statusSuffixText];
            }
        }
    }

    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [composedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                         options:NSStringDrawingUsesLineFragmentOrigin];
    }
    NSSize photoSize = NSZeroSize;
    BOOL nonVisualPlayable = TGMessageItemIsNonVisualPlayableMedia(item);
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }
    CGFloat mediaFooterHeight = TGMessageMediaFooterHeightForItem(item);

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (nonVisualPlayable) {
        bubbleWidth = TGPlayableMediaBubbleWidthForItem(item, maximumBubbleWidth);
    }
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0 + senderHeaderHeight;
    if (nonVisualPlayable) {
        bubbleHeight = TGPlayableMediaBubbleHeightForItem(item) + senderHeaderHeight;
    }
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0 + mediaFooterHeight + senderHeaderHeight;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    if (!nonVisualPlayable) {
        bubbleHeight += TGReactionBandHeightForMessageItem(item);
    }

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    return NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
}

void TGDrawPlayableMediaContentForItem(TGMessageItem *item, NSRect bubbleRect, BOOL flipped) {
    if (![item isKindOfClass:[TGMessageItem class]] || NSIsEmptyRect(bubbleRect)) {
        return;
    }

    CGFloat reactionBandHeight = TGReactionBandHeightForMessageItem(item);
    CGFloat usableHeight = NSHeight(bubbleRect) - reactionBandHeight;
    if (usableHeight < 42.0) {
        usableHeight = NSHeight(bubbleRect);
    }
    NSRect playableRect = NSMakeRect(NSMinX(bubbleRect),
                                     flipped ? NSMinY(bubbleRect) : (NSMaxY(bubbleRect) - usableHeight),
                                     NSWidth(bubbleRect),
                                     usableHeight);
    CGFloat circleSide = 34.0;
    NSRect playCircleRect = NSMakeRect(NSMinX(playableRect) + 12.0,
                                       NSMidY(playableRect) - (circleSide / 2.0),
                                       circleSide,
                                       circleSide);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:playCircleRect];
    [TGClassicNavigationSelectedColor(0.90) set];
    [circle fill];
    [TGClassicNavigationSelectedStrokeColor(0.78) set];
    [circle setLineWidth:1.0];
    [circle stroke];

    NSRect playIconRect = NSInsetRect(playCircleRect, 10.0, 10.0);
    TGDrawTemplateIconAsset(@"play", playIconRect, TGClassicHeaderTextColor(0.96), 1.0, flipped);

    NSString *title = TGPlayableMediaTitleForMessageItem(item);
    NSDictionary *titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSFont boldSystemFontOfSize:12.0], NSFontAttributeName,
                                     TGClassicInkColor(), NSForegroundColorAttributeName,
                                     nil];
    NSString *duration = TGDurationStringFromSecondsValue([item mediaDuration]);
    if ([duration length] == 0) {
        duration = @"Tap to play";
    }
    NSDictionary *durationAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:10.0], NSFontAttributeName,
                                        TGClassicMutedInkColor(), NSForegroundColorAttributeName,
                                        nil];
    CGFloat textX = NSMaxX(playCircleRect) + 10.0;
    CGFloat textWidth = NSWidth(playableRect) - (textX - NSMinX(playableRect)) - 68.0;
    if (textWidth < 80.0) {
        textWidth = 80.0;
    }
    [title drawInRect:NSMakeRect(textX, NSMidY(playableRect) - 4.0, textWidth, 16.0)
       withAttributes:titleAttributes];
    [duration drawInRect:NSMakeRect(textX, NSMidY(playableRect) - 19.0, textWidth, 14.0)
          withAttributes:durationAttributes];

    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    if ([timeString length] > 0) {
        NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                        TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                        nil];
        NSSize timeSize = [timeString sizeWithAttributes:timeAttributes];
        CGFloat statusWidth = TGOutgoingStatusDotsWidthForItem(item);
        CGFloat statusGap = (statusWidth > 0.0) ? 5.0 : 0.0;
        CGFloat timeY = flipped ? (NSMaxY(playableRect) - 16.0) : (NSMinY(playableRect) + 5.0);
        NSRect timeRect = NSMakeRect(NSMaxX(playableRect) - timeSize.width - statusWidth - statusGap - 12.0,
                                     timeY,
                                     timeSize.width,
                                     10.0);
        [timeString drawInRect:timeRect withAttributes:timeAttributes];
        TGDrawOutgoingStatusDotsForItem(item, timeRect, flipped);
    }
}

long long TGMessageSortValue(id value) {
    if ([value respondsToSelector:@selector(longLongValue)]) {
        return [value longLongValue];
    }
    return 0;
}

NSInteger TGCompareMessageItemsAscending(id left, id right, void *context) {
    (void)context;
    long long leftDate = 0;
    long long rightDate = 0;
    long long leftMessageID = 0;
    long long rightMessageID = 0;

    if ([left isKindOfClass:[TGMessageItem class]]) {
        leftDate = TGMessageSortValue([(TGMessageItem *)left date]);
        leftMessageID = TGMessageSortValue([(TGMessageItem *)left messageID]);
    }
    if ([right isKindOfClass:[TGMessageItem class]]) {
        rightDate = TGMessageSortValue([(TGMessageItem *)right date]);
        rightMessageID = TGMessageSortValue([(TGMessageItem *)right messageID]);
    }

    if (leftDate < rightDate) {
        return NSOrderedAscending;
    }
    if (leftDate > rightDate) {
        return NSOrderedDescending;
    }
    if (leftMessageID < rightMessageID) {
        return NSOrderedAscending;
    }
    if (leftMessageID > rightMessageID) {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}
