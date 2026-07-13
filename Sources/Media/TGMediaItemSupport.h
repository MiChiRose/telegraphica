#import <Cocoa/Cocoa.h>

NSString *TGMediaItemLocalPath(NSDictionary *mediaItem);
NSString *TGMediaItemFullLocalPath(NSDictionary *mediaItem);
NSData *TGMediaItemMiniThumbnailData(NSDictionary *mediaItem);
NSNumber *TGMediaItemFullFileID(NSDictionary *mediaItem);
NSString *TGMediaItemContentType(NSDictionary *mediaItem);
BOOL TGMediaItemIsAnimation(NSDictionary *mediaItem);
BOOL TGMediaItemIsVideo(NSDictionary *mediaItem);
BOOL TGMediaItemIsPlayable(NSDictionary *mediaItem);
BOOL TGMediaItemIsAudioOnlyPlayable(NSDictionary *mediaItem);
NSString *TGMediaItemPlayableLocalPath(NSDictionary *mediaItem);
NSString *TGInlinePlaybackPathForMediaItem(NSDictionary *mediaItem);
NSString *TGInlinePlaybackKindForMediaItem(NSDictionary *mediaItem);
BOOL TGMediaItemSupportsPreview(NSDictionary *mediaItem);
