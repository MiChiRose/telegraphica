#import <Cocoa/Cocoa.h>
#import "TGChatDisplayPreferences.h"
#import "TGLocalization.h"
#import "TGMediaItemSupport.h"
#import "TGMediaSecurityLimits.h"
#import "TGMessageItem.h"
#import "TGMessageLayoutSupport.h"
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
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 5, @"active animation default should be five");

    TGResourcePolicySetEconomyModeEnabled(YES);
    TGAssertTrue(TGResourcePolicyEconomyModeEnabled(), @"economy mode should save on");
    TGAssertTrue(!TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadVideo), @"economy mode should disable video auto-download");
    TGAssertTrue(TGResourcePolicyMaximumActiveAnimations() == 1, @"economy mode should lower active animations");

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
    TGClearProbeDefaults();
    [pool drain];
    if (TGProbeFailures > 0) {
        return 1;
    }
    printf("Core logic probe passed: themes, preferences, resource policy, media support, localization, message layout.\n");
    return 0;
}
