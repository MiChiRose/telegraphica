#import <Foundation/Foundation.h>
#import "TGStorageCleanupPolicy.h"
#include <stdio.h>

static NSString *TGFirstType(NSArray *types) {
    NSDictionary *value = ([types count] > 0 && [[types objectAtIndex:0] isKindOfClass:[NSDictionary class]])
        ? [types objectAtIndex:0] : nil;
    return [value objectForKey:@"@type"];
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int result = 0;
    if ([TGStorageCleanupFileTypeObjectsForSelection(TGStorageCleanupSelectionAll) count] != 0) {
        fprintf(stderr, "all-files selection must use an empty TDLib filter\n");
        result = 2;
    }
    NSArray *videos = TGStorageCleanupFileTypeObjectsForSelection(TGStorageCleanupSelectionVideos);
    if (result == 0 && ([videos count] != 3 || ![TGFirstType(videos) isEqualToString:@"fileTypeVideo"])) {
        fprintf(stderr, "video filter must include regular video, notes, and animations\n");
        result = 3;
    }
    if (result == 0 && ![TGFirstType(TGStorageCleanupFileTypeObjectsForSelection(TGStorageCleanupSelectionVoice))
                         isEqualToString:@"fileTypeVoiceNote"]) {
        fprintf(stderr, "voice filter is invalid\n");
        result = 4;
    }
    NSArray *chatIDs = TGStorageCleanupNormalizedChatIDs([NSArray arrayWithObjects:@1, @0, @1, @-2, @"bad", nil]);
    if (result == 0 && ![chatIDs isEqual:[NSArray arrayWithObjects:@1, @-2, nil]]) {
        fprintf(stderr, "chat identifiers were not normalized and deduplicated\n");
        result = 5;
    }
    if (result == 0) {
        fprintf(stdout, "Storage cleanup policy probe passed.\n");
    }
    [pool drain];
    return result;
}
