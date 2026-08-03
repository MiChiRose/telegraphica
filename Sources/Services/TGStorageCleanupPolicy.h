#import <Foundation/Foundation.h>

extern NSString * const TGStorageCleanupSelectionAll;
extern NSString * const TGStorageCleanupSelectionPhotos;
extern NSString * const TGStorageCleanupSelectionVideos;
extern NSString * const TGStorageCleanupSelectionDocuments;
extern NSString * const TGStorageCleanupSelectionVoice;
extern NSString * const TGStorageCleanupSelectionAudio;

NSArray *TGStorageCleanupFileTypeObjectsForSelection(NSString *selection);
NSArray *TGStorageCleanupNormalizedChatIDs(NSArray *chatIDs);
