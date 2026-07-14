#import <Cocoa/Cocoa.h>

NSString *TGMediaItemLocalPath(NSDictionary *mediaItem);
NSString *TGMediaItemFullLocalPath(NSDictionary *mediaItem);
NSData *TGMediaItemMiniThumbnailData(NSDictionary *mediaItem);
NSNumber *TGMediaItemFullFileID(NSDictionary *mediaItem);
NSString *TGMediaItemContentType(NSDictionary *mediaItem);
NSString *TGMediaItemStickerFormat(NSDictionary *mediaItem);
BOOL TGMediaItemIsAnimation(NSDictionary *mediaItem);
BOOL TGMediaItemIsVideo(NSDictionary *mediaItem);
BOOL TGMediaItemIsTGSSticker(NSDictionary *mediaItem);
BOOL TGMediaItemIsWebMSticker(NSDictionary *mediaItem);
BOOL TGMediaItemIsPlayable(NSDictionary *mediaItem);
BOOL TGMediaItemIsAudioOnlyPlayable(NSDictionary *mediaItem);
NSString *TGMediaItemPlayableLocalPath(NSDictionary *mediaItem);
NSString *TGInlinePlaybackPathForMediaItem(NSDictionary *mediaItem);
NSString *TGInlinePlaybackKindForMediaItem(NSDictionary *mediaItem);
NSString *TGMediaItemInlinePlaybackDiagnosticSummary(NSDictionary *mediaItem);
BOOL TGMediaItemSupportsPreview(NSDictionary *mediaItem);
