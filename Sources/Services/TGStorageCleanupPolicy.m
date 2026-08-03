#import "TGStorageCleanupPolicy.h"

NSString * const TGStorageCleanupSelectionAll = @"all";
NSString * const TGStorageCleanupSelectionPhotos = @"photos";
NSString * const TGStorageCleanupSelectionVideos = @"videos";
NSString * const TGStorageCleanupSelectionDocuments = @"documents";
NSString * const TGStorageCleanupSelectionVoice = @"voice";
NSString * const TGStorageCleanupSelectionAudio = @"audio";

static NSDictionary *TGStorageFileTypeObject(NSString *type) {
    if (![type isKindOfClass:[NSString class]] || [type length] == 0) {
        return nil;
    }
    return [NSDictionary dictionaryWithObject:type forKey:@"@type"];
}

NSArray *TGStorageCleanupFileTypeObjectsForSelection(NSString *selection) {
    if (![selection isKindOfClass:[NSString class]] ||
        [selection length] == 0 ||
        [selection isEqualToString:TGStorageCleanupSelectionAll]) {
        return [NSArray array];
    }
    if ([selection isEqualToString:TGStorageCleanupSelectionPhotos]) {
        return [NSArray arrayWithObject:TGStorageFileTypeObject(@"fileTypePhoto")];
    }
    if ([selection isEqualToString:TGStorageCleanupSelectionVideos]) {
        return [NSArray arrayWithObjects:
                TGStorageFileTypeObject(@"fileTypeVideo"),
                TGStorageFileTypeObject(@"fileTypeVideoNote"),
                TGStorageFileTypeObject(@"fileTypeAnimation"),
                nil];
    }
    if ([selection isEqualToString:TGStorageCleanupSelectionDocuments]) {
        return [NSArray arrayWithObject:TGStorageFileTypeObject(@"fileTypeDocument")];
    }
    if ([selection isEqualToString:TGStorageCleanupSelectionVoice]) {
        return [NSArray arrayWithObject:TGStorageFileTypeObject(@"fileTypeVoiceNote")];
    }
    if ([selection isEqualToString:TGStorageCleanupSelectionAudio]) {
        return [NSArray arrayWithObject:TGStorageFileTypeObject(@"fileTypeAudio")];
    }
    return [NSArray array];
}

NSArray *TGStorageCleanupNormalizedChatIDs(NSArray *chatIDs) {
    if (![chatIDs isKindOfClass:[NSArray class]] || [chatIDs count] == 0) {
        return [NSArray array];
    }
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (id value in chatIDs) {
        if (![value respondsToSelector:@selector(longLongValue)]) {
            continue;
        }
        long long chatID = [value longLongValue];
        if (chatID == 0LL) {
            continue;
        }
        NSNumber *normalized = [NSNumber numberWithLongLong:chatID];
        if (![seen containsObject:normalized]) {
            [seen addObject:normalized];
            [result addObject:normalized];
        }
        if ([result count] >= 100) {
            break;
        }
    }
    return result;
}
