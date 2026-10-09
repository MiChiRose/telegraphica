#import <Cocoa/Cocoa.h>
#import "TGChatDisplayPreferences.h"
#import "TGCustomEmojiImageLoader.h"
#import "TGLocalization.h"
#import "TGMediaItemSupport.h"
#import "TGMediaSecurityLimits.h"
#import "TGOpusVoiceTranscoder.h"
#import "TGMessageItem.h"
#import "TGMessageLayoutSupport.h"
#import "TGReactionChipLayout.h"
#import "TGMessagePollSupport.h"
#import "TGOutgoingMessageTextChunker.h"
#import "TGResourcePolicy.h"
#import "TGTheme.h"
#import "TGVisualWorldThemeSpec.h"
#include <math.h>

NSString * const TGInlineMediaKindGIF = @"gif";
NSString * const TGInlineMediaKindVideo = @"video";
NSString * const TGInlineMediaKindWebM = @"webm";
NSString * const TGInlineMediaKindTGS = @"tgs";
NSString * const TGInlineMediaIdentifierKey = @"identifier";
NSString * const TGInlineMediaPathKey = @"path";
NSString * const TGInlineMediaFrameKey = @"frame";
NSString * const TGInlineMediaKindKey = @"kind";
NSString * const TGInlineMediaPlaybackDiagnosticNotification = @"TGInlineMediaPlaybackDiagnosticNotification";
NSString * const TGInlineMediaPlaybackDiagnosticMessageKey = @"message";

NSImage *TGImageWithCorrectOrientationFromFile(NSString *path) {
    (void)path;
    return nil;
}

NSImage *TGImageThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize) {
    (void)path;
    (void)maximumPixelSize;
    return nil;
}

NSImage *TGMediaCachedThumbnailFromFile(NSString *path, NSUInteger maximumPixelSize) {
    (void)path;
    (void)maximumPixelSize;
    return nil;
}

NSImage *TGImageThumbnailFromData(NSData *data, NSUInteger maximumPixelSize) {
    (void)data;
    (void)maximumPixelSize;
    return nil;
}

NSImage *TGCustomEmojiCachedImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize) {
    (void)entity;
    (void)maximumPixelSize;
    return nil;
}

void TGCustomEmojiRequestImageForEntity(NSDictionary *entity, NSUInteger maximumPixelSize) {
    (void)entity;
    (void)maximumPixelSize;
}

NSImage *TGIconAssetImageNamed(NSString *name) {
    (void)name;
    return nil;
}

void TGDrawTemplateIconAsset(NSString *name, NSRect rect, NSColor *color, CGFloat alpha, BOOL flipped) {
    (void)name;
    (void)rect;
    (void)color;
    (void)alpha;
    (void)flipped;
}

NSImage *TGTemplateIconAssetImage(NSString *name, NSSize size, NSColor *color, CGFloat alpha) {
    (void)name;
    (void)size;
    (void)color;
    (void)alpha;
    return nil;
}

static int TGProbeFailures = 0;

static void TGAssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        TGProbeFailures++;
        fprintf(stderr, "core_logic_probe: %s\n", [[message description] UTF8String]);
    }
}

static void TGAssertEqualObjects(id left, id right, NSString *message) {
    BOOL equal = (left == right) || [left isEqual:right];
    if (!equal) {
        TGProbeFailures++;
        fprintf(stderr, "core_logic_probe: %s (left=%s right=%s)\n",
                [[message description] UTF8String],
                [[[left description] description] UTF8String],
                [[[right description] description] UTF8String]);
    }
}

static void TGClearProbeDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *keys = [NSArray arrayWithObjects:
                     TGThemeDefaultsKey,
                     @"TelegraphicaLanguageCode",
                     @"TelegraphicaChatMessagesAsBlocks",
                     @"TelegraphicaChatMessageTextSizeLevel",
                     @"TelegraphicaChatMessagesAsBlocksOverrides",
                     @"TelegraphicaChatMessageTextSizeLevelOverrides",
                     @"TelegraphicaResourcePolicyInitialized",
                     @"TelegraphicaEconomyModeEnabled",
                     @"TelegraphicaAutoDownloadPhotos",
                     @"TelegraphicaAutoDownloadVideos",
                     @"TelegraphicaAutoDownloadDocuments",
                     @"TelegraphicaAutoDownloadVoiceMessages",
                     @"TelegraphicaLinkPreviewsEnabled",
                     @"TelegraphicaMaxAutoDownloadBytes",
                     @"TelegraphicaAutoplayAnimatedStickers",
                     @"TelegraphicaMaximumActiveAnimations",
                     @"TelegraphicaStopAnimationsWhenInactive",
                     @"TelegraphicaMediaCacheLimitBytes",
                     nil];
    NSUInteger index = 0;
    for (index = 0; index < [keys count]; index++) {
        [defaults removeObjectForKey:[keys objectAtIndex:index]];
    }
    [defaults synchronize];
}

static void TGTestThemes(void) {
    NSArray *identifiers = TGThemeIdentifiers();
    TGAssertTrue([identifiers count] >= 10, @"theme list should include all shipped themes");
    TGAssertTrue(TGThemeIdentifierIsValid(TGThemeIdentifierVKBlue), @"VK Blue identifier should be valid");
    TGAssertTrue(TGThemeIdentifierIsValid(TGThemeIdentifierSkeuomorphicBlue), @"Skeuomorphic Blue identifier should be valid");
    TGAssertTrue(TGThemeIdentifierIsValid(TGThemeIdentifierFrutigerMetroDark), @"Frutiger Metro Dark identifier should be valid");
    TGAssertTrue(!TGThemeIdentifierIsValid(@"missing-theme"), @"unknown theme identifier should be rejected");

    TGSetActiveThemeIdentifier(TGThemeIdentifierFrutigerAeroDream);
    TGAssertEqualObjects(TGCurrentThemeIdentifier(), TGThemeIdentifierFrutigerAeroDream, @"active theme should switch to a valid identifier");
    TGAssertTrue(TGThemeIsFrutigerAeroDream(), @"Frutiger Aero Dream helper should match active theme");
    NSColor *aeroPanelColor = [[TGClassicPanelBottomColor() retain] autorelease];
    TGSetActiveThemeIdentifier(TGThemeIdentifierSkeuomorphicBlue);
    NSColor *skeuomorphicPanelColor = [[TGClassicPanelBottomColor() retain] autorelease];
    TGAssertTrue(![aeroPanelColor isEqual:skeuomorphicPanelColor], @"theme palette cache should invalidate when the active theme changes");
    TGSetActiveThemeIdentifier(@"missing-theme");
    TGAssertEqualObjects(TGCurrentThemeIdentifier(), TGThemeIdentifierVKBlue, @"invalid active theme should fall back to VK Blue");

    NSArray *categories = TGThemeCategoryIdentifiers();
    TGAssertTrue([categories containsObject:TGThemeCategoryIdentifierLight], @"light theme category should exist");
    TGAssertTrue([categories containsObject:TGThemeCategoryIdentifierDark], @"dark theme category should exist");
    TGAssertTrue([categories containsObject:TGThemeCategoryIdentifierOldSchool], @"retro theme category should exist");
    TGAssertTrue([categories containsObject:TGThemeCategoryIdentifierExperimental], @"experimental theme category should exist");
    TGAssertTrue([categories containsObject:TGThemeCategoryIdentifierVisualWorlds], @"visual worlds theme category should exist");
    TGAssertEqualObjects(TGThemeCategoryIdentifierForThemeIdentifier(TGThemeIdentifierMatrixRain),
                         TGThemeCategoryIdentifierExperimental,
                         @"Matrix Rain should be experimental");
    TGAssertTrue([TGThemeDisplayNameForIdentifier(TGThemeIdentifierY2KChrome) length] > 0, @"theme display name should be non-empty");

    NSArray *visualIdentifiers = TGThemeIdentifiersForCategory(TGThemeCategoryIdentifierVisualWorlds);
    TGAssertTrue([visualIdentifiers count] == 10, @"Visual Worlds should ship ten themes");
    TGAssertTrue(TGThemeIdentifierIsValid(TGThemeIdentifierVisualMacintoshDesktop), @"Macintosh Desktop visual theme should be valid");
    TGAssertTrue(TGThemeIdentifierIsValid(TGThemeIdentifierVisualPostcard), @"Postcard visual theme should be valid");
    TGAssertEqualObjects(TGThemeCategoryIdentifierForThemeIdentifier(TGThemeIdentifierVisualBlueprint),
                         TGThemeCategoryIdentifierVisualWorlds,
                         @"Blueprint should belong to Visual Worlds");
    TGAssertTrue(TGVisualWorldThemeIdentifierIsValid(TGThemeIdentifierVisualCRTTerminal), @"CRT spec should be registered");
    TGVisualWorldThemeSpec *visualSpec = TGVisualWorldThemeSpecForIdentifier(TGThemeIdentifierVisualNotebook);
    TGAssertTrue([visualSpec.displayName length] > 0, @"Visual spec should have a display name");
    TGAssertTrue([visualSpec.themeDescription length] > 0, @"Visual spec should have a description");
    TGAssertTrue(visualSpec.backgroundHex != 0 && visualSpec.textHex != 0, @"Visual spec should define colors");
    TGAssertTrue(TGVisualWorldThemeSpecForIdentifier(@"missing-visual-world") == nil, @"Unknown visual theme spec should fail closed");
    TGSetActiveThemeIdentifier(TGThemeIdentifierVisualSpaceTerminal);
    TGAssertTrue(TGThemeIsVisualWorld(), @"Visual helper should match active visual theme");
    TGAssertEqualObjects(TGCurrentThemeIdentifier(), TGThemeIdentifierVisualSpaceTerminal, @"visual theme should persist in active theme state");
}

static NSUInteger TGNotificationCountForName(NSString *name, void (^block)(void)) {
    __block NSUInteger count = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:name
                                                                    object:nil
                                                                     queue:nil
                                                                usingBlock:^(NSNotification *note) {
        (void)note;
        count++;
    }];
    block();
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    return count;
}

static void TGTestChatDisplayPreferences(void) {
    TGClearProbeDefaults();
    TGAssertTrue(!TGChatMessagesAsBlocksEnabled(), @"messages-as-blocks should default to off");
    NSUInteger blockNotifications = TGNotificationCountForName(TGChatDisplayPreferencesDidChangeNotification, ^{
        TGSetChatMessagesAsBlocksEnabled(YES);
        TGSetChatMessagesAsBlocksEnabled(YES);
        TGSetChatMessagesAsBlocksEnabled(NO);
    });
    TGAssertTrue(blockNotifications == 2, @"messages-as-blocks should notify only on real changes");
    TGAssertTrue(!TGChatMessagesAsBlocksEnabled(), @"messages-as-blocks should save off state");

    TGAssertTrue(TGChatMessageTextSizeLevel() == TGChatMessageTextSizeNormal, @"text size should default to normal");
    TGSetChatMessageTextSizeLevel(-10);
    TGAssertTrue(TGChatMessageTextSizeLevel() == TGChatMessageTextSizeSmall, @"text size should clamp low values");
    TGSetChatMessageTextSizeLevel(99);
    TGAssertTrue(TGChatMessageTextSizeLevel() == TGChatMessageTextSizeVeryLarge, @"text size should clamp high values");
    TGAssertEqualObjects(TGChatMessageTextSizeLocalizationKeyForLevel(99),
                         @"settings.chatText.veryLarge",
                         @"text size localization key should clamp high values");
    TGAssertTrue(TGChatMessageBodyFontSize() >= 16.0, @"very large text should increase body font size");

    NSNumber *chatID = [NSNumber numberWithLongLong:42];
    NSNumber *threadID = [NSNumber numberWithLongLong:7];
    TGSetChatMessagesAsBlocksEnabled(NO);
    TGSetChatMessagesAsBlocksEnabledForTarget(chatID, threadID, YES);
    TGAssertTrue(TGChatMessagesAsBlocksEnabledForTarget(chatID, threadID), @"per-chat block override should win over global off");
    TGClearChatMessagesAsBlocksOverrideForTarget(chatID, threadID);
    TGAssertTrue(!TGChatMessagesAsBlocksEnabledForTarget(chatID, threadID), @"cleared per-chat block override should fall back to global off");

    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeSmall);
    TGSetChatMessageTextSizeLevelForTarget(chatID, threadID, TGChatMessageTextSizeVeryLarge);
    TGAssertTrue(TGChatMessageTextSizeLevelForTarget(chatID, threadID) == TGChatMessageTextSizeVeryLarge, @"per-chat text size override should win");
    TGClearChatMessageTextSizeOverrideForTarget(chatID, threadID);
    TGAssertTrue(TGChatMessageTextSizeLevelForTarget(chatID, threadID) == TGChatMessageTextSizeSmall, @"cleared per-chat text size should fall back to global");
}

static void TGTestResourcePolicy(void) {
    TGClearProbeDefaults();
    TGResourcePolicyApplyDefaultsIfNeeded();
    TGAssertTrue(!TGResourcePolicyEconomyModeEnabled(), @"economy mode should default off");
    TGAssertTrue(TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadPhoto), @"photos should auto-download by default");
    TGAssertTrue(TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVideo), @"videos should auto-download by default");
    TGAssertTrue(TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVoice), @"voice messages should auto-download by default");
    TGAssertTrue(TGResourcePolicyLinkPreviewsEnabled(), @"link previews should default on");
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 5, @"active animation default should be five");

    TGResourcePolicySetEconomyModeEnabled(YES);
    TGAssertTrue(TGResourcePolicyEconomyModeEnabled(), @"economy mode should save on");
    TGAssertTrue(!TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVideo), @"economy mode should disable video auto-download");
    TGAssertTrue(TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVoice), @"economy mode should keep small voice messages available");
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 1, @"economy mode should lower active animations");

    TGResourcePolicySetEconomyModeEnabled(NO);
    TGResourcePolicySetMaxAutoDownloadBytes(20LL * 1024LL * 1024LL);
    TGAssertTrue(TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messagePhoto", 1024), @"known media with a declared safe size should auto-download");
    TGAssertTrue(TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messageSticker", 1024), @"an individual sticker with a declared safe size should auto-download");
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messagePhoto", 0), @"missing media size should fail closed");
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(nil, 1024), @"missing message type should fail closed");
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messagePhoto", 21LL * 1024LL * 1024LL), @"oversized media should not auto-download");
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messageUnknown", 1024), @"unknown message content should fail closed");
    TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadDocument, NO);
    TGAssertTrue(TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messageVoiceNote", 1024), @"voice notes should have an independent auto-download category");
    TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadVoice, NO);
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messageVoiceNote", 1024), @"disabled voice category should not auto-download");
    TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadVideo, NO);
    TGAssertTrue(!TGResourcePolicyAllowsAutoDownloadForMessageContent(@"messageVideo", 1024), @"disabled media category should not auto-download");
    TGResourcePolicySetLinkPreviewsEnabled(NO);
    TGAssertTrue(!TGResourcePolicyLinkPreviewsEnabled(), @"link preview preference should persist off");
    TGResourcePolicySetLinkPreviewsEnabled(YES);
    TGAssertTrue(TGResourcePolicyLinkPreviewsEnabled(), @"link preview preference should persist on");

    TGResourcePolicySetMaxAutoDownloadBytes(-1);
    TGAssertTrue(TGResourcePolicyMaxAutoDownloadBytes() > 0, @"invalid auto-download size should fall back to a positive value");
    TGResourcePolicySetMaximumActiveAnimations(0);
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 1, @"active animation count should clamp to one");
    TGResourcePolicySetMaximumActiveAnimations(100);
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 8, @"active animation count should clamp to eight");
    TGAssertEqualObjects(TGResourcePolicyReadableSize(0), @"0 B", @"zero bytes should format safely");
    TGAssertEqualObjects(TGResourcePolicyReadableSize(1536), @"1.5 KB", @"kilobyte formatting should be stable");
}

static NSDictionary *TGMedia(NSString *contentType, NSString *path, NSString *fullPath, NSString *format, NSString *mimeType) {
    NSMutableDictionary *media = [NSMutableDictionary dictionary];
    if (contentType) [media setObject:contentType forKey:@"content_type"];
    if (path) [media setObject:path forKey:@"local_path"];
    if (fullPath) [media setObject:fullPath forKey:@"full_local_path"];
    if (format) [media setObject:format forKey:@"sticker_format"];
    if (mimeType) [media setObject:mimeType forKey:@"mime_type"];
    return media;
}

static void TGTestMediaSupport(void) {
    NSString *temporaryDirectory = NSTemporaryDirectory();
    NSString *gifPath = [temporaryDirectory stringByAppendingPathComponent:@"telegraphica-probe.gif"];
    NSString *webmPath = [temporaryDirectory stringByAppendingPathComponent:@"telegraphica-probe.webm"];
    NSString *tgsPath = [temporaryDirectory stringByAppendingPathComponent:@"telegraphica-probe.tgs"];
    [@"" writeToFile:gifPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"" writeToFile:webmPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"" writeToFile:tgsPath atomically:YES encoding:NSUTF8StringEncoding error:nil];

    TGAssertTrue(TGMediaItemSupportsPreview(TGMedia(@"messagePhoto", nil, nil, nil, nil)), @"photos should support preview");
    TGAssertTrue(!TGMediaItemSupportsPreview(TGMedia(@"messageSticker", nil, nil, nil, nil)), @"stickers should not open the media preview");
    TGAssertTrue(TGMediaItemIsPlayable(TGMedia(@"messageAnimation", gifPath, nil, nil, @"image/gif")), @"animations should be playable");
    TGAssertTrue(TGMediaItemIsAudioOnlyPlayable(TGMedia(@"messageVoiceNote", nil, nil, nil, @"audio/ogg")), @"voice notes should be audio-only playable");
    TGAssertEqualObjects(TGInlinePlaybackKindForMediaItem(TGMedia(@"messageAnimation", gifPath, nil, nil, @"image/gif")),
                         TGInlineMediaKindGIF,
                         @"gif playback kind should be detected");
    TGAssertEqualObjects(TGInlinePlaybackKindForMediaItem(TGMedia(@"messageSticker", nil, webmPath, @"stickerFormatWebm", @"video/webm")),
                         TGInlineMediaKindWebM,
                         @"webm sticker playback kind should be detected");
    TGAssertEqualObjects(TGInlinePlaybackPathForMediaItem(TGMedia(@"messageSticker", nil, tgsPath, @"stickerFormatTgs", nil)),
                         tgsPath,
                         @"tgs sticker should use full local path");
    TGAssertTrue(TGInlinePlaybackPathForMediaItem(nil) == nil, @"nil media should not produce playback path");

    [[NSFileManager defaultManager] removeItemAtPath:gifPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:webmPath error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:tgsPath error:nil];
}

static void TGTestMediaSecurityLimits(void) {
    TGAssertTrue(TGMediaDimensionsFitDecodedBudget(512, 512, 4, TGMediaMaximumDecodedBytes),
                 @"ordinary media dimensions should fit the decode budget");
    TGAssertTrue(!TGMediaDimensionsFitDecodedBudget(0, 512, 4, TGMediaMaximumDecodedBytes),
                 @"zero-width media should fail closed");
    TGAssertTrue(!TGMediaDimensionsFitDecodedBudget(TGMediaMaximumDecodedSide + 1, 512, 4, TGMediaMaximumDecodedBytes),
                 @"oversized media dimensions should fail closed");
    TGAssertTrue(!TGMediaDimensionsFitDecodedBudget(4096, 4096, 16, TGMediaMaximumDecodedBytes),
                 @"media exceeding the decoded-byte budget should fail closed");
    TGAssertTrue(TGMediaMaximumAnimatedFrameCount > 0 && TGMediaMaximumAnimatedFrameCount <= 180,
                 @"animated media should keep a bounded frame budget");
    TGAssertTrue(TGMediaMaximumCompressedWebMFrameBytes <= 8ULL * 1024ULL * 1024ULL,
                 @"compressed WebM blocks should keep a bounded allocation budget");
    TGAssertTrue(TGMediaMaximumTGSRepeaterCopies <= 256,
                 @"TGS repeaters should keep a bounded copy budget");

    TGOpusVoiceTranscodeCancellationToken *token = [[[TGOpusVoiceTranscodeCancellationToken alloc] init] autorelease];
    TGAssertTrue(![token isCancelled], @"new voice preparation token should be active");
    [token cancel];
    TGAssertTrue([token isCancelled], @"voice preparation token should retain cancellation state");
    NSError *cancelError = nil;
    NSString *cancelledPath = TGPlayableVoicePathByTranscodingIfNeededWithCancellation(@"/tmp/missing.opus",
                                                                                       @"audio/opus",
                                                                                       YES,
                                                                                       token,
                                                                                       &cancelError);
    TGAssertTrue(cancelledPath == nil && [cancelError code] == 9, @"cancelled voice preparation should stop before decoder work");
    NSOperationQueue *voiceQueue = TGCreateSerialVoiceTranscodeQueue();
    TGAssertTrue([voiceQueue maxConcurrentOperationCount] == 1, @"voice preparation queue should serialize decoder jobs");
}

static void TGTestMessageItemsAndLayout(void) {
    TGClearProbeDefaults();
    TGMessageItem *empty = [[[TGMessageItem alloc] initWithChatID:nil messageID:nil date:nil outgoing:NO preview:nil] autorelease];
    TGAssertEqualObjects([empty preview], @"[Message]", @"empty message preview should be safe");
    TGAssertTrue(![empty isVisualMediaMessage], @"empty message should not be visual media");

    TGMessageItem *textItem = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithLongLong:1]
                                                           messageID:[NSNumber numberWithLongLong:2]
                                                                date:[NSNumber numberWithInteger:1700000000]
                                                            outgoing:YES
                                                             preview:@"Hello\n\nWorld"] autorelease];
    CGFloat normalHeight = TGMessageBubbleHeightForItem(textItem, 640.0, NO);
    TGAssertTrue(normalHeight >= 42.0, @"text bubble should have a minimum safe height");
    TGAssertTrue(!NSIsEmptyRect(TGMessageBubbleRectForItem(textItem, NSMakeRect(0, 0, 640, normalHeight), NO)), @"text bubble rect should be non-empty");
    TGAssertTrue([[TGAttributedMessageString([textItem preview], nil) string] isEqualToString:[textItem preview]], @"attributed text should preserve paragraph text");
    NSDictionary *strikeType = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"textEntityTypeStrikethrough", @"@type",
                                nil];
    NSDictionary *quoteType = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"textEntityTypeBlockQuote", @"@type",
                               nil];
    NSDictionary *strikeEntity = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInteger:0], @"offset",
                                  [NSNumber numberWithInteger:5], @"length",
                                  strikeType, @"type",
                                  nil];
    NSDictionary *quoteEntity = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithInteger:7], @"offset",
                                 [NSNumber numberWithInteger:5], @"length",
                                 quoteType, @"type",
                                 nil];
    [textItem setFormattedEntities:[NSArray arrayWithObjects:strikeEntity, quoteEntity, nil]];
    NSAttributedString *formattedText = TGAttributedMessageStringForItem(textItem, [textItem preview], nil);
    TGAssertTrue([[formattedText attribute:NSStrikethroughStyleAttributeName atIndex:1 effectiveRange:NULL] integerValue] == NSUnderlineStyleSingle,
                 @"TDLib strikethrough entities should reach message rendering");
    NSParagraphStyle *quoteParagraph = [formattedText attribute:NSParagraphStyleAttributeName atIndex:8 effectiveRange:NULL];
    TGAssertTrue([[quoteParagraph textBlocks] count] == 1,
                 @"TDLib block quote entities should receive a visible quote block");
    NSTextBlock *quoteBlock = [[quoteParagraph textBlocks] objectAtIndex:0];
    TGAssertTrue([quoteBlock widthForLayer:NSTextBlockBorder edge:NSMinXEdge] >= 3.0,
                 @"TDLib block quote entities should render a visible leading bar");

    TGMessageItem *customEmojiItem = [[[TGMessageItem alloc] initWithChatID:@1
                                                                  messageID:@3
                                                                       date:nil
                                                                   outgoing:NO
                                                                    preview:@"xy"] autorelease];
    NSDictionary *customEmojiType = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"textEntityTypeCustomEmoji", @"@type",
                                     @101, @"custom_emoji_id",
                                     nil];
    NSDictionary *customEmojiEntity = [NSDictionary dictionaryWithObjectsAndKeys:
                                       @0, @"offset",
                                       @1, @"length",
                                       customEmojiType, @"type",
                                       @101, @"custom_emoji_id",
                                       @"stickerFormatTgs", @"custom_emoji_format",
                                       nil];
    [customEmojiItem setFormattedEntities:[NSArray arrayWithObject:customEmojiEntity]];
    NSAttributedString *customEmojiText = TGAttributedMessageStringForItem(customEmojiItem,
                                                                           [customEmojiItem preview],
                                                                           nil);
    TGAssertEqualObjects([customEmojiText string], @"◇y",
                         @"unsupported custom emoji should render a stable visible placeholder");

    TGSetChatMessagesAsBlocksEnabled(YES);
    CGFloat blockHeight = TGMessageBubbleHeightForItem(textItem, 640.0, NO);
    NSRect blockRect = TGMessageBubbleRectForItem(textItem, NSMakeRect(0, 0, 640, blockHeight), NO);
    TGAssertTrue(blockHeight >= 44.0, @"block message row should have a safe height");
    TGAssertTrue(fabs(NSWidth(blockRect) - 628.0) < 0.1, @"block message rect should span the list width");

    TGMessageItem *document = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                           messageID:[NSNumber numberWithInt:3]
                                                                date:nil
                                                            outgoing:NO
                                                             preview:@"report.rtf"] autorelease];
    [document setContentType:@"messageDocument"];
    [document setDownloadFileName:@"report.rtf"];
    [document setDownloadFileSize:[NSNumber numberWithLongLong:2048]];
    TGAssertTrue(TGMessageItemIsNonVisualDocument(document), @"document message should be detected as a non-visual document");
    TGAssertTrue(TGDocumentBubbleHeightForItem(document) >= 58.0, @"document bubble height should be safe");
    CGFloat documentBlockHeight = TGMessageBubbleHeightForItem(document, 360.0, NO);
    NSRect documentBlockRect = TGMessageBubbleRectForItem(document,
                                                         NSMakeRect(0.0, 0.0, 360.0, documentBlockHeight),
                                                         NO);
    TGAssertTrue(documentBlockHeight >= 82.0, @"block document rows should reserve enough room for their controls");
    TGAssertTrue(NSMaxY(documentBlockRect) <= documentBlockHeight,
                 @"block document geometry should stay inside its table row");

    TGSetChatMessagesAsBlocksEnabled(NO);
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeVeryLarge);
    TGAssertTrue(TGMessageUsesSeparateMetadataFooter(),
                 @"large message text should use a separate footer for time and delivery checks");
    CGFloat largeTextHeight = TGMessageBubbleHeightForItem(textItem, 360.0, NO);
    TGAssertTrue(largeTextHeight > normalHeight,
                 @"large message text should increase the row height instead of clipping metadata");
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeNormal);
    TGAssertTrue(TGMessageUsesSeparateMetadataFooter(),
                 @"normal message text should keep time and delivery checks in a non-wrapping footer");

    NSDictionary *idleMedia = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithInt:42], @"file_id",
                               @"Image", @"placeholder",
                               nil];
    NSDictionary *loadingMedia = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:42], @"file_id",
                                  [NSNumber numberWithBool:YES], @"loading",
                                  @"Image", @"placeholder",
                                  nil];
    TGAssertTrue(!TGMediaItemNeedsLoadingSpinner(idleMedia),
                 @"downloadable media should not spin until a download is actually active");
    TGAssertTrue(TGMediaItemNeedsLoadingSpinner(loadingMedia),
                 @"actively loading media should keep its progress spinner");

    TGMessageItem *photoA = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                         messageID:[NSNumber numberWithInt:4]
                                                              date:nil
                                                          outgoing:NO
                                                           preview:@"Image"] autorelease];
    [photoA setContentType:@"messagePhoto"];
    [photoA setMediaLocalPath:@"/tmp/a.jpg"];
    [photoA setMediaWidth:[NSNumber numberWithInt:800]];
    [photoA setMediaHeight:[NSNumber numberWithInt:600]];
    TGMessageItem *photoB = [[photoA copy] autorelease];
    [photoB setMessageID:[NSNumber numberWithInt:5]];
    [photoA addVisualMediaFromMessageItem:photoB];
    TGAssertTrue([photoA isMediaAlbumMessage], @"merged visual media should become an album");
    TGAssertTrue([[photoA visualMediaItems] count] == 2, @"album should keep both media items");

    TGMessageItem *callItem = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                           messageID:[NSNumber numberWithInt:7]
                                                                date:[NSNumber numberWithInteger:1700000000]
                                                            outgoing:YES
                                                             preview:@"Call"] autorelease];
    [callItem setContentType:@"messageCall"];
    [callItem setCallDuration:[NSNumber numberWithUnsignedInteger:66U]];
    [callItem setCallDiscardReason:@"callDiscardReasonHungUp"];
    TGAssertTrue([callItem isCallMessage] && TGMessageItemIsCallContent(callItem),
                 @"call messages should retain their semantic content type");
    TGAssertTrue(TGCallBubbleHeightForItem(callItem) >= 60.0,
                 @"call bubbles should reserve room for direction and duration");
    TGAssertTrue(TGCallBubbleWidthForItem(callItem, 360.0) <= 360.0,
                 @"call bubbles should respect the available width");
    TGMessageItem *callCopy = [[callItem copy] autorelease];
    TGAssertEqualObjects([callCopy callDuration], [callItem callDuration],
                         @"call duration should survive message-item copying");
    TGAssertEqualObjects([callCopy callDiscardReason], [callItem callDiscardReason],
                         @"call discard reason should survive message-item copying");

    TGMessageItem *pendingPhoto = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                                messageID:[NSNumber numberWithInt:6]
                                                                     date:nil
                                                                 outgoing:YES
                                                                  preview:@"Image"] autorelease];
    [pendingPhoto setContentType:@"messagePhoto"];
    [pendingPhoto setMediaItems:[NSArray arrayWithObject:
                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:42], @"file_id",
                                  [NSNumber numberWithInt:1280], @"width",
                                  [NSNumber numberWithInt:720], @"height",
                                  @"Photo", @"placeholder",
                                  nil]]];
    TGAssertTrue([pendingPhoto isVisualMediaMessage], @"a photo awaiting download must remain a visual message");
    TGAssertTrue([[pendingPhoto visualMediaItems] count] == 1, @"a photo awaiting download must keep its placeholder metadata");

    NSDictionary *pollContent = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"messagePoll", @"@type",
                                 [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSDictionary dictionaryWithObject:@"Coffee?" forKey:@"text"], @"question",
                                  [NSArray arrayWithObjects:
                                   [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSDictionary dictionaryWithObject:@"Yes" forKey:@"text"], @"text",
                                    [NSNumber numberWithInt:3], @"voter_count",
                                    [NSNumber numberWithBool:YES], @"is_chosen",
                                    nil],
                                   [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSDictionary dictionaryWithObject:@"No" forKey:@"text"], @"text",
                                    [NSNumber numberWithInt:1], @"vote_count",
                                    nil],
                                   nil], @"options",
                                  [NSNumber numberWithInt:4], @"total_voter_count",
                                  [NSDictionary dictionaryWithObjectsAndKeys:
                                   @"pollTypeRegular", @"@type",
                                   [NSNumber numberWithBool:NO], @"allow_multiple_answers",
                                   nil], @"type",
                                  nil], @"poll",
                                 nil];
    NSDictionary *pollInfo = TGMessagePollInfoFromContentObject(pollContent);
    TGAssertEqualObjects(TGMessagePollPreviewTextFromInfo(pollInfo), @"Coffee?", @"poll preview should use the question");
    TGAssertTrue([[pollInfo objectForKey:TGMessagePollOptionsKey] count] == 2, @"poll parser should keep options");
    NSArray *pollOptions = [pollInfo objectForKey:TGMessagePollOptionsKey];
    TGAssertTrue([[[pollOptions objectAtIndex:0] objectForKey:TGMessagePollOptionVoteCountKey] integerValue] == 3,
                 @"poll parser should read TDLib voter_count values");
    TGMessageItem *pollItem = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                           messageID:[NSNumber numberWithInt:6]
                                                                date:nil
                                                            outgoing:NO
                                                             preview:TGMessagePollPreviewTextFromInfo(pollInfo)] autorelease];
    [pollItem setContentType:@"messagePoll"];
    [pollItem setPollQuestion:[pollInfo objectForKey:TGMessagePollQuestionKey]];
    [pollItem setPollOptions:[pollInfo objectForKey:TGMessagePollOptionsKey]];
    [pollItem setPollTotalVoterCount:[pollInfo objectForKey:TGMessagePollTotalVoterCountKey]];
    TGAssertTrue([pollItem isPollMessage], @"message item should recognize polls");
    TGAssertTrue(TGMessageItemIsPollContent(pollItem), @"layout helper should recognize polls");
    TGAssertTrue(TGPollBubbleHeightForItem(pollItem) > 70.0, @"poll bubble should reserve room for options");
    NSRect pollBubbleRect = NSMakeRect(12.0, 20.0, 280.0, TGPollBubbleHeightForItem(pollItem));
    NSRect firstPollOption = TGPollOptionRectForItem(pollItem, pollBubbleRect, 0, YES);
    TGAssertTrue(!NSIsEmptyRect(firstPollOption), @"poll option hit rect should be calculable");
    TGAssertTrue(TGPollOptionIndexForPoint(pollItem,
                                           pollBubbleRect,
                                           NSMakePoint(NSMidX(firstPollOption), NSMidY(firstPollOption)),
                                           YES) == 0,
                 @"poll option hit testing should match rendered option rectangles");
    TGAssertTrue(TGPollOptionIndexForPoint(pollItem,
                                           pollBubbleRect,
                                           NSMakePoint(NSMinX(pollBubbleRect) + 2.0, NSMinY(pollBubbleRect) + 2.0),
                                           YES) == NSNotFound,
                 @"poll hit testing should ignore the question and margins");
    [pollItem setPendingPollOptionIndexes:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInteger:0], [NSNumber numberWithUnsignedInteger:1], nil]];
    [pollItem setPollMultipleChoice:YES];
    NSRect confirmRect = TGPollConfirmRectForItem(pollItem, pollBubbleRect, YES);
    TGAssertTrue(!NSIsEmptyRect(confirmRect), @"multiple polls with pending options should expose a submit rect");
    TGAssertTrue(TGPollPointIsInConfirmRect(pollItem,
                                            pollBubbleRect,
                                            NSMakePoint(NSMidX(confirmRect), NSMidY(confirmRect)),
                                            YES),
                 @"multiple poll submit hit testing should match rendered confirm button");
    [pollItem setPollClosed:YES];
    TGAssertTrue(TGPollOptionIndexForPoint(pollItem,
                                           pollBubbleRect,
                                           NSMakePoint(NSMidX(firstPollOption), NSMidY(firstPollOption)),
                                           YES) == NSNotFound,
                 @"closed polls should not be clickable");

    TGMessageItem *pinnedA = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                          messageID:[NSNumber numberWithInt:7]
                                                               date:nil
                                                           outgoing:NO
                                                            preview:@"Pinned A"] autorelease];
    TGMessageItem *pinnedB = [[[TGMessageItem alloc] initWithChatID:[NSNumber numberWithInt:1]
                                                          messageID:[NSNumber numberWithInt:8]
                                                               date:nil
                                                           outgoing:NO
                                                            preview:@"Pinned B"] autorelease];
    [pinnedA setPinned:YES];
    [pinnedB setPinned:YES];
    NSArray *pinnedItems = [NSArray arrayWithObjects:pinnedA, pinnedB, nil];
    TGAssertTrue([pinnedItems count] == 2, @"multiple pinned messages should be representable");
    TGAssertTrue([[pinnedItems objectAtIndex:0] isPinned] && [[pinnedItems objectAtIndex:1] isPinned], @"pinned flags should be retained for carousel candidates");
    TGMessageItem *pinnedCopy = [[pinnedA copy] autorelease];
    TGAssertTrue([pinnedCopy isPinned], @"pinned flag should survive message item copies");
    NSArray *emptyPinnedItems = [NSArray array];
    TGAssertTrue([emptyPinnedItems count] == 0, @"empty pinned message lists should be representable");

    NSArray *emptyChunks = TGOutgoingTextMessageChunks(nil);
    TGAssertTrue([emptyChunks count] == 0, @"nil outgoing text should produce no chunks");
    NSMutableString *longText = [NSMutableString string];
    NSUInteger index = 0;
    for (index = 0; index < TGOutgoingTextMessageMaximumLength + 50; index++) {
        [longText appendString:@"a"];
    }
    NSArray *chunks = TGOutgoingTextMessageChunks(longText);
    TGAssertTrue([chunks count] == 2, @"long outgoing text should split into multiple chunks");
    TGAssertTrue([[chunks objectAtIndex:0] length] <= TGOutgoingTextMessageMaximumLength, @"first text chunk should respect the Telegram limit");
}

static void TGTestCommentPresentation(void) {
    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@0 outgoing:NO preview:@"Comments"] autorelease];
    [item setCanGetMessageThread:YES];
    NSArray *counts = [NSArray arrayWithObjects:@1, @2, @4, @5, @11, @12, @14, @21, @22, @111, @112, nil];
    NSArray *languages = [NSArray arrayWithObjects:@"en", @"ru", @"be", nil];
    NSArray *expectedByLanguage = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"1 comment", @"2 comments", @"4 comments", @"5 comments", @"11 comments", @"12 comments", @"14 comments", @"21 comments", @"22 comments", @"111 comments", @"112 comments", nil],
        [NSArray arrayWithObjects:@"1 комментарий", @"2 комментария", @"4 комментария", @"5 комментариев", @"11 комментариев", @"12 комментариев", @"14 комментариев", @"21 комментарий", @"22 комментария", @"111 комментариев", @"112 комментариев", nil],
        [NSArray arrayWithObjects:@"1 каментар", @"2 каментары", @"4 каментары", @"5 каментароў", @"11 каментароў", @"12 каментароў", @"14 каментароў", @"21 каментар", @"22 каментары", @"111 каментароў", @"112 каментароў", nil], nil];
    NSUInteger languageIndex = 0;
    for (languageIndex = 0; languageIndex < [languages count]; languageIndex++) {
        TGSetLanguageCode([languages objectAtIndex:languageIndex]);
        NSUInteger index = 0;
        for (index = 0; index < [counts count]; index++) {
            [item setMessageThreadReplyCount:[counts objectAtIndex:index]];
            TGAssertEqualObjects(TGMessageCommentTitleForItem(item), [[expectedByLanguage objectAtIndex:languageIndex] objectAtIndex:index], @"comment titles must follow the selected language's plural forms");
        }
        [item setMessageThreadReplyCount:@0];
        TGAssertEqualObjects(TGMessageCommentTitleForItem(item), TGLoc(@"message.comments.add"), @"zero comments should invite adding one");
    }
    TGSetLanguageCode(@"ru"); [item setMessageThreadReplyCount:@22];
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeNormal);
    CGFloat normalHeight = TGMessageCommentBarHeightForItem(item);
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeVeryLarge);
    CGFloat largeHeight = TGMessageCommentBarHeightForItem(item);
    CGFloat measuredTitleHeight = ceil([TGMessageCommentTitleForItem(item) sizeWithAttributes:
        [NSDictionary dictionaryWithObject:TGChatMessageBoldSecondaryFont() forKey:NSFontAttributeName]].height);
    TGAssertTrue(largeHeight >= normalHeight, @"large text must not shrink the comment bar");
    NSRect bubble = NSMakeRect(0.0, 0.0, 320.0, 180.0);
    NSRect flippedBar = TGMessageCommentBarRectForItem(item, bubble, YES);
    NSRect unflippedBar = TGMessageCommentBarRectForItem(item, bubble, NO);
    TGAssertTrue(NSHeight(flippedBar) >= measuredTitleHeight + 8.0 && NSHeight(unflippedBar) >= measuredTitleHeight + 8.0, @"comment title must fit the actual largest secondary font with vertical padding in both coordinate systems");
    TGAssertTrue(NSContainsRect(bubble, flippedBar) && NSContainsRect(bubble, unflippedBar), @"expanded comment bar should remain inside its bubble");
    [item setCanGetMessageThread:NO]; [item setMessageThreadReplyCount:nil];
    TGAssertTrue(TGMessageCommentBarHeightForItem(item) == 0.0, @"messages without discussions must reserve no comment bar space");
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeNormal);
}

static CGFloat TGProbeColorLuminance(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    CGFloat channels[] = {[rgb redComponent], [rgb greenComponent], [rgb blueComponent]};
    NSUInteger index = 0;
    for (index = 0; index < 3; index++) {
        channels[index] = channels[index] <= 0.04045 ? channels[index] / 12.92 : pow((channels[index] + 0.055) / 1.055, 2.4);
    }
    return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
}

static void TGTestCompactMessageGeometry(void) {
    TGClearProbeDefaults();
    TGSetChatMessagesAsBlocksEnabled(NO);
    for (NSNumber *outgoing in [NSArray arrayWithObjects:@NO, @YES, nil]) {
        TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@1700000000
                                                          outgoing:[outgoing boolValue] preview:@"конечно буду)"] autorelease];
        [item setContentType:@"messageText"];
        for (NSNumber *level in [NSArray arrayWithObjects:@0, @1, @2, @3, nil]) {
            TGSetChatMessageTextSizeLevel([level integerValue]);
            CGFloat maximum = TGMaximumBubbleWidthForItem(item, 640.0);
            TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, maximum, NO), @"short text must put complete metadata beside body at every text size");
            NSRect bubble = TGMessageBubbleRectForItem(item, NSMakeRect(0.0, 0.0, 640.0, 1000.0), NO);
            TGAssertTrue(NSHeight(bubble) < 50.0 && NSWidth(bubble) <= maximum, @"one-line bubble must be compact without exceeding width budget");
            TGAssertTrue(TGMessageBubbleHeightForItem(item, 640.0, NO) >= 42.0, @"compact bubbles retain a safe full row hit area");
            NSRect bodyFrame = TGMessageInlineTextRectForItem(item, bubble, YES);
            NSAttributedString *bodyString = TGAttributedMessageStringForItem(item, [item preview],
                [NSDictionary dictionaryWithObjectsAndKeys:TGChatMessageBodyFont(), NSFontAttributeName,
                 TGMessageTextParagraphStyle(), NSParagraphStyleAttributeName, nil]);
            NSTextStorage *bodyStorage = [[[NSTextStorage alloc] initWithAttributedString:bodyString] autorelease];
            NSLayoutManager *bodyLayout = [[[NSLayoutManager alloc] init] autorelease];
            NSTextContainer *bodyContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSWidth(bodyFrame), 12000.0)] autorelease];
            [bodyContainer setLineFragmentPadding:0.0];
            [bodyLayout addTextContainer:bodyContainer]; [bodyStorage addLayoutManager:bodyLayout];
            NSRange bodyGlyphs = [bodyLayout glyphRangeForTextContainer:bodyContainer];
            NSRange lineGlyphs = NSMakeRange(0, 0);
            [bodyLayout lineFragmentRectForGlyphAtIndex:bodyGlyphs.location effectiveRange:&lineGlyphs];
            TGAssertTrue(NSMaxRange(lineGlyphs) >= NSMaxRange(bodyGlyphs), @"actual text-container glyph layout must occupy one visual line");
            NSRect usedBody = [bodyLayout usedRectForTextContainer:bodyContainer];
            TGAssertTrue(NSHeight(usedBody) <= NSHeight(bodyFrame) + 0.5, @"measured body must contain actual rendered line height");
            for (NSNumber *flip in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                NSRect body = TGMessageInlineTextRectForItem(item, bubble, [flip boolValue]);
                NSRect time = TGMessageInlineTimeRectForItem(item, bubble, [flip boolValue]);
                TGAssertTrue(NSContainsRect(bubble, body) && NSContainsRect(bubble, time), @"body and complete 12/24-hour time fit both coordinate orientations");
                TGAssertTrue(NSMaxX(body) + 7.9 <= NSMinX(time), @"text selection must exclude timestamp with a real gap");
                TGAssertTrue(NSIntersectsRect(NSMakeRect(NSMinX(body), NSMinY(body), NSMaxX(time) - NSMinX(body), NSHeight(body)), time), @"time must share the body line");
                CGFloat statusRight = NSMaxX(time) + (TGOutgoingStatusDotsWidthForItem(item) > 0.0 ? 5.0 + TGOutgoingStatusDotsWidthForItem(item) : 0.0);
                TGAssertTrue(statusRight <= NSMaxX(bubble) - 11.9, @"delivery status must retain right inset");
                TGAssertTrue(!NSPointInRect(NSMakePoint(NSMidX(time), NSMidY(time)), body), @"time hit cannot begin selecting message text");
            }
            // Exact measurement boundary: body+metadata either fit as one unit or
            // all metadata move to the normal footer; no AM/PM suffix wrapping.
            TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, NSWidth(bubble), NO), @"exact measured width should fit");
            TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, NSWidth(bubble) - 0.5, NO), @"a narrower budget must use a separate footer");
        }
        TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeNormal);
        NSRect compact = TGMessageBubbleRectForItem(item, NSMakeRect(0.0, 0.0, 640.0, 1000.0), NO);
        [item setSending:YES];
        TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"sending status does not make a short body wrap");
        [item setSending:NO]; [item setOutgoingRead:YES];
        TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"read status remains inside the inline metadata unit");
        [item setFailedToSend:YES];
        TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"failed-send status keeps compact body geometry");
        [item setFailedToSend:NO];
        [item setReactionSummary:@"👍 1"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"any reaction requires footer below text");
        NSRect reacted = TGMessageBubbleRectForItem(item, NSMakeRect(0.0, 0.0, 640.0, 1000.0), NO);
        TGAssertTrue(NSHeight(reacted) > NSHeight(compact), @"adding a reaction creates a separate lower row");
        CGFloat bandHeight = TGReactionBandHeightForMessageItemWidth(item, NSWidth(reacted));
        for (NSNumber *flip in [NSArray arrayWithObjects:@NO, @YES, nil]) {
            BOOL flipped = [flip boolValue];
            NSRect band = NSMakeRect(NSMinX(reacted) + 10.0, flipped ? NSMaxY(reacted) - bandHeight : NSMinY(reacted), NSWidth(reacted) - 20.0, bandHeight);
            NSRect time = TGMessageReactionTimeRect(item, band, flipped);
            TGAssertTrue(NSContainsRect(band, time), @"reaction and time share the separate footer");
            TGAssertTrue(flipped ? NSMinY(time) > NSMinY(reacted) + 25.0 : NSMaxY(time) < NSMaxY(reacted) - 25.0, @"reaction time sits below the body in both orientations");
        }
        [item setReactionSummary:nil];
        [item setSenderDisplayName:@"Sender"];
        TGAssertTrue([item outgoing] || !TGMessageUsesInlineMetadataForItem(item, 400.0, YES), @"incoming author heading keeps ordinary header space");
        [item setReplyPreview:@"Reply context"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"reply block must retain separate geometry");
        [item setReplyPreview:nil]; [item setForwardSourceDisplayName:@"Forward"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"forward block must retain separate geometry");
        [item setForwardSourceDisplayName:nil]; [item setCanGetMessageThread:YES];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"comment control must retain separate geometry");
        [item setCanGetMessageThread:NO]; [item setPinned:YES];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"pinned icon must not overlap compact body");
        [item setPinned:NO]; [item setPreview:@"line one\nline two"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"explicit multiline messages keep normal wrapping");
        [item setPreview:[@"wide message " stringByPaddingToLength:200 withString:@"wide message " startingAtIndex:0]];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"long visual wrapping stays on normal layout");
        [item setPreview:@"https://a.co"];
        TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"plain short link remains compact");
        NSRect linkBubble = TGMessageBubbleRectForItem(item, NSMakeRect(0, 0, 640, 1000), NO);
        NSRect linkBody = TGMessageInlineTextRectForItem(item, linkBubble, YES);
        NSRect linkTime = TGMessageInlineTimeRectForItem(item, linkBubble, YES);
        TGAssertTrue(TGURLAtCharacterIndexInString([item preview], 2) != nil, @"body retains actual clickable URL characters");
        TGAssertTrue(!NSPointInRect(NSMakePoint(NSMidX(linkTime), NSMidY(linkTime)), linkBody), @"metadata hit is outside compact clickable link body");
        [item setLinkPreviewInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"https://a.co", @"url", @"Preview", @"title", nil]];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"link card keeps its complete separate geometry");
        [item setLinkPreviewInfo:nil];
        [item setFormattedEntities:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
            @0, @"offset", @3, @"length", [NSDictionary dictionaryWithObject:@"textEntityTypeBlockQuote" forKey:@"@type"], @"type", nil]]];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"quote paragraph must retain block padding");
        [item setFormattedEntities:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
            @0, @"offset", @3, @"length", [NSDictionary dictionaryWithObject:@"textEntityTypeBold" forKey:@"@type"], @"type", nil]]];
        TGAssertTrue(TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"one-line bold text uses actual attributed glyph measurement");
        [item setFormattedEntities:nil];
        [item setContentType:@"messageDocument"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"document controls keep existing layout");
        [item setContentType:@"messagePhoto"];
        TGAssertTrue(!TGMessageUsesInlineMetadataForItem(item, 400.0, NO), @"media captions retain existing layout");
    }
    TGMessageItem *tiny = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:nil outgoing:NO preview:@"1"] autorelease];
    NSRect tinyBubble = TGMessageBubbleRectForItem(tiny, NSMakeRect(0, 0, 640, 1000), NO);
    TGAssertTrue(NSWidth(tinyBubble) < 60.0 && NSHeight(tinyBubble) >= 32.0, @"one character does not inherit the old 96pt bubble width floor");
    TGAssertTrue(NSIsEmptyRect(TGMessageInlineTimeRectForItem(tiny, tinyBubble, YES)), @"missing timestamp does not allocate phantom footer text");
    TGSetChatMessagesAsBlocksEnabled(YES);
    TGAssertTrue(!TGMessageUsesInlineMetadataForItem(tiny, 400.0, NO), @"full-width list layout remains unchanged");
    TGClearProbeDefaults();
}

static void TGTestReactionFooter(void) {
    TGClearProbeDefaults();
    TGSetChatMessagesAsBlocksEnabled(NO);
    for (NSString *theme in TGThemeIdentifiers()) {
        TGSetActiveThemeIdentifier(theme);
        for (NSNumber *outgoing in [NSArray arrayWithObjects:@NO, @YES, nil]) {
            TGMessageItem *sample = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@1700000000 outgoing:[outgoing boolValue] preview:@"Theme"] autorelease];
            for (NSNumber *blocks in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                TGSetChatMessagesAsBlocksEnabled([blocks boolValue]);
                for (NSNumber *flipped in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                    CGFloat surface = TGProbeColorLuminance(TGMessageMetadataSurfaceColor(sample, [flipped boolValue]));
                    CGFloat ink = TGProbeColorLuminance(TGMessageMetadataInkColor(sample, [flipped boolValue]));
                    CGFloat contrast = (MAX(surface, ink) + 0.05) / (MIN(surface, ink) + 0.05);
                    TGAssertTrue(contrast >= 4.5, [NSString stringWithFormat:@"small timestamp needs readable contrast in %@", theme]);
                    for (NSNumber *active in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                        CGFloat statusInk = TGProbeColorLuminance(TGMessageDeliveryStatusInkColor(sample, [active boolValue], [flipped boolValue]));
                        CGFloat statusContrast = (MAX(surface, statusInk) + 0.05) / (MIN(surface, statusInk) + 0.05);
                        TGAssertTrue(statusContrast >= ([active boolValue] ? 4.5 : 3.0), @"delivery state must stay visible on every footer surface");
                    }
                }
            }
        }
        TGSetChatMessagesAsBlocksEnabled(NO);
        NSUInteger chosen = 0;
        for (chosen = 0; chosen < 2; chosen++) {
            CGFloat background = TGProbeColorLuminance(TGReactionChipBackgroundColor(chosen != 0));
            CGFloat ink = TGProbeColorLuminance(TGReactionChipInkColor(chosen != 0));
            CGFloat contrast = (MAX(background, ink) + 0.05) / (MIN(background, ink) + 0.05);
            TGAssertTrue(contrast >= 4.5, [NSString stringWithFormat:@"reaction digits need readable contrast in %@", theme]);
        }
    }
    for (NSNumber *outgoing in [NSArray arrayWithObjects:@NO, @YES, nil]) {
        TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@1700000000 outgoing:[outgoing boolValue] preview:@"Hello"] autorelease];
        [item setReactionSummary:@"👍 1  ❤️ 23  😱 104  🔥 5  🎉 3  👏 6"];
        [item setCanGetMessageThread:YES];
        [item setMessageThreadReplyCount:@4];
        for (NSNumber *width in [NSArray arrayWithObjects:@280, @400, @640, nil]) {
            NSRect bubble = TGMessageBubbleRectForItem(item, NSMakeRect(0, 0, [width doubleValue], 1000), NO);
            CGFloat bandHeight = TGReactionBandHeightForMessageItemWidth(item, NSWidth(bubble));
            for (NSNumber *flipped in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                BOOL flip = [flipped boolValue];
                NSRect band = NSMakeRect(NSMinX(bubble) + 10.0, flip ? NSMaxY(bubble) - bandHeight : NSMinY(bubble), NSWidth(bubble) - 20.0, bandHeight);
                CGFloat chipWidth = TGMessageReactionContentWidth(item, NSWidth(band));
                NSArray *chips = TGReactionChipLayoutForItem(item, chipWidth);
                NSRect time = TGMessageReactionTimeRect(item, band, flip);
                TGAssertTrue([chips count] == 6 && NSContainsRect(band, time), @"complete reactions and timestamp must stay inside footer");
                NSRect lastChip = [[[chips lastObject] objectForKey:@"frame"] rectValue];
                CGFloat lastCenter = flip ? NSMinY(band) + 2.0 + NSMidY(lastChip) : NSMaxY(band) - 2.0 - NSMidY(lastChip);
                TGAssertTrue(fabs(lastCenter - NSMidY(time)) <= 2.0, @"timestamp must share the last reaction row baseline");
                for (NSDictionary *chip in chips) {
                    NSRect local = [[chip objectForKey:@"frame"] rectValue];
                    NSRect actual = NSMakeRect(NSMinX(band) + NSMinX(local), flip ? NSMinY(band) + 2.0 + NSMinY(local) : NSMaxY(band) - 2.0 - NSMaxY(local), NSWidth(local), NSHeight(local));
                    TGAssertTrue(!NSIntersectsRect(actual, time), @"timestamp and every reaction chip must remain separate");
                }
                NSRect comment = TGMessageCommentBarRectForItem(item, bubble, flip);
                TGAssertTrue(!NSIntersectsRect(comment, time), @"comment control must not overlap shared reaction/time footer");
            }
        }
    }
    TGClearProbeDefaults();
}

static void TGTestAnimatedReactionFooterBounds(void) {
    TGClearProbeDefaults();
    NSString *summary = @"👍 9999999  ❤️ 123  😱 10  🔥 5  🎉 3  👏 6";
    for (NSString *language in [NSArray arrayWithObjects:@"ru", @"be", @"en", nil]) {
        TGSetLanguageCode(language);
        for (NSInteger level = 0; level <= 3; level++) {
            TGSetChatMessageTextSizeLevel(level);
            for (NSNumber *blocks in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                BOOL list = [blocks boolValue];
                TGSetChatMessagesAsBlocksEnabled(list);
                for (NSNumber *outgoing in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                    TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2
                        date:@1700000000 outgoing:[outgoing boolValue] preview:@"Animated footer"] autorelease];
                    [item setCanGetMessageThread:YES];
                    [item setMessageThreadReplyCount:@1234];
                    [item setReactionAnimationDisplaySummary:summary];
                    [item setReactionAnimationChangesHeight:YES];
                    for (NSNumber *width in [NSArray arrayWithObjects:@280, @320, @400, @640, nil]) {
                        CGFloat available = [width doubleValue];
                        for (NSNumber *flipped in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                            BOOL flip = [flipped boolValue];
                            for (NSNumber *removing in [NSArray arrayWithObjects:@NO, @YES, nil]) {
                                [item setReactionAnimationRemoving:[removing boolValue]];
                                [item setReactionSummary:[removing boolValue] ? @"" : summary];
                                for (NSUInteger step = 0; step <= 20; step++) {
                                    [item setReactionAnimationProgress:(CGFloat)step / 20.0];
                                    NSRect owner = list
                                        ? NSInsetRect(NSMakeRect(0, 0, available,
                                            TGMessageBubbleHeightForItem(item, available, NO)), 6.0, 2.0)
                                        : TGMessageBubbleRectForItem(item, NSMakeRect(0, 0, available, 1000), NO);
                                    CGFloat reactionWidth = list ? MAX(40.0, available - 86.0) : NSWidth(owner) - 20.0;
                                    CGFloat height = TGReactionChipsHeightForItem(item,
                                        TGMessageReactionContentWidth(item, reactionWidth));
                                    CGFloat inset = list ? 3.0 : 0.0;
                                    NSRect band = NSMakeRect(NSMinX(owner) + (list ? 50.0 : 10.0),
                                        flip ? NSMaxY(owner) - height - inset : NSMinY(owner) + inset,
                                        reactionWidth, height);
                                    NSRect time = TGMessageReactionTimeRect(item, band, flip);
                                    TGAssertTrue(NSIsEmptyRect(time) || NSContainsRect(band, time),
                                        @"animated timestamp must remain inside the allocated reaction band");
                                    TGAssertTrue(NSIsEmptyRect(time) || NSContainsRect(owner, time),
                                        @"animated timestamp must not enter a neighbouring message");
                                    NSRect comment = TGMessageCommentBarRectForItem(item, owner, flip);
                                    TGAssertTrue(NSIsEmptyRect(time) || !NSIntersectsRect(comment, time),
                                        @"animated timestamp must not overlap the comment action");
                                    if (![removing boolValue] && step == 20) {
                                        TGAssertTrue(!NSIsEmptyRect(time), @"fully expanded footer must display its timestamp");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    TGClearProbeDefaults();
}

static void TGTestReactionGeometry(void) {
    TGClearProbeDefaults();
    TGSetChatMessagesAsBlocksEnabled(NO);
    TGMessageItem *chipItem = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@0 outgoing:NO preview:@"Hi"] autorelease];
    [chipItem setReactionSummary:@"❤️ 48  😁 20  👍 7"];
    NSArray *chips = TGReactionChipLayoutForItem(chipItem, 400.0);
    TGAssertTrue([chips count] == 3, @"reaction summary must produce one chip for each emoji/count pair");
    if ([chips count] == 3) {
        TGAssertEqualObjects([[chips objectAtIndex:0] objectForKey:@"count"], @"48", @"reaction count must preserve the complete decimal number");
        TGAssertEqualObjects([[chips objectAtIndex:1] objectForKey:@"count"], @"20", @"count must not be split into individual glyphs");
        TGAssertEqualObjects([[chips objectAtIndex:2] objectForKey:@"count"], @"7", @"single digit reaction count must remain visible");
        NSString *heart = [[chips objectAtIndex:0] objectForKey:@"display_emoji"];
        TGAssertTrue([heart length] > 0 && [heart rangeOfString:@"?"].location == NSNotFound, @"stock heart emoji must normalize its presentation selector without a question-mark fallback");
    }
    [chipItem setReactionSummary:@"👍 1  ❤️ 48  🔥 7  🎉 6  👏 5  😁 20"];
    chips = TGReactionChipLayoutForItem(chipItem, 80.0);
    TGAssertTrue([chips count] == 6, @"narrow layout must retain every reaction chip");
    NSUInteger chipIndex = 0;
    for (chipIndex = 0; chipIndex < [chips count]; chipIndex++) {
        NSRect frame = [[[chips objectAtIndex:chipIndex] objectForKey:@"frame"] rectValue];
        TGAssertTrue(NSMinX(frame) >= 0.0 && NSMaxX(frame) <= 80.0 && NSHeight(frame) == 24.0, @"wrapped chips must stay within the available band width");
        NSUInteger previous = 0;
        for (previous = 0; previous < chipIndex; previous++) {
            NSRect previousFrame = [[[chips objectAtIndex:previous] objectForKey:@"frame"] rectValue];
            TGAssertTrue(!NSIntersectsRect(frame, previousFrame), @"wrapped chips must never overlap");
        }
    }
    if ([chips count] > 0) {
        TGAssertEqualObjects([[chips objectAtIndex:0] objectForKey:@"count"], @"1", @"a single reaction must still show its numeric count");
        TGAssertTrue(NSMinY([[[chips lastObject] objectForKey:@"frame"] rectValue]) > 0.0, @"narrow chip layout must wrap beyond its first row");
    }
    [chipItem setReactionSummary:@"👍 123456789012"];
    NSRect wideCountBubble = TGMessageBubbleRectForItem(chipItem, NSMakeRect(0.0, 0.0, 640.0, 1000.0), NO);
    TGAssertTrue(NSWidth(wideCountBubble) >= TGReactionChipsMinimumWidthForItem(chipItem) + 20.0, @"short text bubble must widen enough to fit a whole large reaction count");
    NSString *summary = @"👍 12  ❤️ 8  🔥 7  🎉 6  👏 5  😁 4  🤔 3  👎 2";
    NSArray *types = [NSArray arrayWithObjects:@"messageText", @"messageVoiceNote", @"messageDocument", @"messagePoll", @"messageCall", @"messagePhoto", nil];
    for (NSString *type in types) {
        TGMessageItem *item = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@0 outgoing:NO preview:@"Hi"] autorelease];
        [item setContentType:type];
        NSRect frame = NSMakeRect(0.0, 0.0, 360.0, 1000.0);
        CGFloat contentHeight = NSHeight(TGMessageBubbleRectForItem(item, frame, NO));
        CGFloat playableHeight = TGPlayableMediaBubbleHeightForItem(item);
        [item setReactionSummary:summary];
        NSRect bubble = TGMessageBubbleRectForItem(item, frame, NO);
        CGFloat band = TGReactionBandHeightForMessageItemWidth(item, NSWidth(bubble));
        TGAssertTrue(band >= 58.0, @"several chips in a narrow bubble should wrap into multiple rows");
        TGAssertTrue(fabs(NSHeight(bubble) - contentHeight - band) < 0.01, @"every content type must reserve the reaction band exactly once");
        CGFloat rowHeight = TGMessageBubbleHeightForItem(item, NSWidth(frame), NO);
        TGAssertTrue(fabs(rowHeight - NSHeight(bubble) - 10.0 - TGMessageExtraBlockVerticalPadding() - TGMessageTopAccessoryHeightForItem(item)) < 0.01, @"row height must match the bubble geometry used for drawing and hit testing");
        TGAssertTrue(fabs(playableHeight - TGPlayableMediaBubbleHeightForItem(item)) < 0.01, @"playable content height must not include reactions already removed by its owning cell");
        [item setCanGetMessageThread:YES];
        [item setMessageThreadReplyCount:@4];
        bubble = TGMessageBubbleRectForItem(item, frame, NO);
        NSRect flippedBar = TGMessageCommentBarRectForItem(item, bubble, YES);
        NSRect unflippedBar = TGMessageCommentBarRectForItem(item, bubble, NO);
        TGAssertTrue(NSContainsRect(bubble, flippedBar) && NSContainsRect(bubble, unflippedBar), @"comments must remain within the enlarged bubble");
        TGAssertTrue(NSMaxY(flippedBar) <= NSMaxY(bubble) - band && NSMinY(unflippedBar) >= NSMinY(bubble) + band, @"comments and wrapped reactions must not overlap in either coordinate system");
        CGFloat footerHeight = band + TGMessageCommentBarHeightForItem(item);
        NSRect flippedContent = TGMessageContentRectByRemovingFooter(bubble, footerHeight, YES);
        NSRect unflippedContent = TGMessageContentRectByRemovingFooter(bubble, footerHeight, NO);
        TGAssertTrue(fabs(NSMinY(flippedContent) - NSMinY(bubble)) < 0.01 &&
            fabs(NSMaxY(unflippedContent) - NSMaxY(bubble)) < 0.01,
            @"footer cropping must preserve the body top in both coordinate systems");
        TGAssertTrue(NSHeight(flippedContent) > 0.0 && NSHeight(unflippedContent) > 0.0 &&
            NSContainsRect(bubble, flippedContent) && NSContainsRect(bubble, unflippedContent),
            @"removing wrapped reactions and comments must leave body content inside the bubble");
        TGAssertTrue(!NSIntersectsRect(NSInsetRect(flippedContent, 0.0, 4.0), flippedBar) &&
            !NSIntersectsRect(NSInsetRect(unflippedContent, 0.0, 4.0), unflippedBar),
            @"body drawing inside its existing padding must not overlap comment controls after footer cropping");
        NSRect flippedBand = NSMakeRect(NSMinX(bubble), NSMaxY(bubble) - band, NSWidth(bubble), band);
        NSRect unflippedBand = NSMakeRect(NSMinX(bubble), NSMinY(bubble), NSWidth(bubble), band);
        TGAssertTrue(!NSIntersectsRect(flippedContent, flippedBand) && !NSIntersectsRect(unflippedContent, unflippedBand),
            @"body content must never extend into wrapped reaction chips");
        if ([type isEqualToString:@"messageDocument"]) {
            NSRect icon = TGDocumentIconRectForBubbleRect(unflippedContent);
            TGAssertTrue(NSContainsRect(unflippedContent, icon) && !NSIntersectsRect(icon, unflippedBar) && !NSIntersectsRect(icon, unflippedBand),
                @"unflipped document icon and download spinner target must remain above footer controls");
        }
        if ([type isEqualToString:@"messagePoll"]) {
            NSRect option = TGPollOptionRectForItem(item, unflippedContent, 0, NO);
            TGAssertTrue(!NSIsEmptyRect(option) && NSContainsRect(unflippedContent, option) &&
                !NSIntersectsRect(option, unflippedBar) && !NSIntersectsRect(option, unflippedBand),
                @"unflipped poll hit targets must remain above comments and wrapped reactions");
        }
    }
    TGMessageItem *compact = [[[TGMessageItem alloc] initWithChatID:@1 messageID:@2 date:@0 outgoing:NO preview:@"Compact"] autorelease];
    TGSetChatMessagesAsBlocksEnabled(YES);
    CGFloat compactHeight = TGMessageBubbleHeightForItem(compact, 250.0, NO);
    [compact setReactionSummary:summary];
    CGFloat compactBand = TGReactionChipsHeightForItem(compact, 250.0 - 86.0);
    TGAssertTrue(fabs(TGMessageBubbleHeightForItem(compact, 250.0, NO) - compactHeight - compactBand) < 0.01, @"compact rows must measure reactions using the renderer's available content width");
    [compact setCanGetMessageThread:YES];
    [compact setMessageThreadReplyCount:@4];
    TGSetChatMessageTextSizeLevel(TGChatMessageTextSizeVeryLarge);
    CGFloat compactRowHeight = TGMessageBubbleHeightForItem(compact, 250.0, NO);
    NSRect compactRect = TGMessageBubbleRectForItem(compact, NSMakeRect(0.0, 0.0, 250.0, compactRowHeight), NO);
    NSRect compactComment = TGMessageCommentBarRectForItem(compact, compactRect, YES);
    TGAssertTrue(fabs(NSWidth(compactComment) - (250.0 - 86.0)) < 0.01, @"compact comment hit testing must share the reaction content width");
    TGAssertTrue(NSContainsRect(compactRect, compactComment) && NSMaxY(compactComment) <= NSMaxY(compactRect) - compactBand, @"compact comment hit testing must stay above all wrapped reaction rows");
    [compact setReactionAnimationDisplaySummary:summary];
    [compact setReactionAnimationChangesHeight:YES];
    [compact setReactionAnimationRemoving:NO];
    [compact setReactionAnimationProgress:0.0];
    TGAssertTrue(TGReactionChipsHeightForItem(compact, 164.0) == 0.0, @"reaction insertion must start without reserving its final band height");
    [compact setReactionAnimationProgress:1.0];
    TGAssertTrue(fabs(TGReactionChipsHeightForItem(compact, 164.0) - compactBand) < 0.01, @"reaction insertion must end at the full wrapped band height");
    [compact setReactionAnimationRemoving:YES];
    TGAssertTrue(TGReactionChipsHeightForItem(compact, 164.0) == 0.0, @"reaction removal must release all wrapped row space");
    TGClearProbeDefaults();
}

static void TGTestLocalization(void) {
    TGSetLanguageCode(@"ru");
    TGAssertEqualObjects(TGLanguageCode(), @"ru", @"Russian language should be saved");
    TGAssertEqualObjects(TGLoc(@"drawer.all"), @"Все чаты", @"drawer label should be localized in Russian");
    TGSetLanguageCode(@"be");
    TGAssertEqualObjects(TGLoc(@"pinned.title"), @"Замацаванае паведамленне", @"pinned title should be localized in Belarusian");
    TGSetLanguageCode(@"en");
    TGAssertEqualObjects(TGLoc(@"missing.localization.key"), @"missing.localization.key", @"missing localization should fall back to the key");
    TGSetLanguageCode(@"bad");
    TGAssertEqualObjects(TGLanguageCode(), @"ru", @"invalid language should fall back to Russian");
}

int main(int argc, const char **argv) {
    (void)argc;
    (void)argv;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGClearProbeDefaults();
    TGTestThemes();
    TGTestChatDisplayPreferences();
    TGTestResourcePolicy();
    TGTestMediaSupport();
    TGTestMediaSecurityLimits();
    TGTestMessageItemsAndLayout();
    TGTestLocalization();
    TGTestCommentPresentation();
    TGTestReactionGeometry();
    TGTestCompactMessageGeometry();
    TGTestReactionFooter();
    TGTestAnimatedReactionFooterBounds();
    TGClearProbeDefaults();
    [pool drain];
    if (TGProbeFailures > 0) {
        return 1;
    }
    printf("Core logic probe passed: themes, preferences, resource policy, media support, localization, message layout.\n");
    return 0;
}
