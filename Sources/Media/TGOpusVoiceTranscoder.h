#import <Foundation/Foundation.h>

BOOL TGVoicePathLooksLikeOggOpus(NSString *path, NSString *mimeType, BOOL audioOnly);
NSString *TGPlayableVoicePathByTranscodingIfNeeded(NSString *path, NSString *mimeType, BOOL audioOnly, NSError **error);
