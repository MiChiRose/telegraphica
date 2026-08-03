#import "TGMediaPlaybackSequence.h"
#import "../Core/TGMessageItem.h"

BOOL TGMessageItemCanParticipateInSequentialAudio(TGMessageItem *item) {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isPlayableMediaMessage] ||
        [item isVideoNoteMessage]) {
        return NO;
    }
    NSString *contentType = [item contentType];
    NSString *mimeType = [[item mediaMimeType] lowercaseString];
    return ([item isVoiceNoteMessage] ||
            [contentType isEqualToString:@"messageAudio"] ||
            [mimeType hasPrefix:@"audio/"]);
}

TGMessageItem *TGNextSequentialAudioMessageItem(NSArray *messageItems,
                                                TGMessageItem *completedItem) {
    if (![messageItems isKindOfClass:[NSArray class]] ||
        ![completedItem isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }

    NSUInteger completedIndex = [messageItems indexOfObjectIdenticalTo:completedItem];
    if (completedIndex == NSNotFound) {
        NSUInteger index = 0;
        for (index = 0; index < [messageItems count]; index++) {
            id object = [messageItems objectAtIndex:index];
            if (![object isKindOfClass:[TGMessageItem class]]) {
                continue;
            }
            TGMessageItem *candidate = (TGMessageItem *)object;
            if ([[candidate chatID] isEqual:[completedItem chatID]] &&
                [[candidate messageID] isEqual:[completedItem messageID]]) {
                completedIndex = index;
                break;
            }
        }
    }
    if (completedIndex == NSNotFound) {
        return nil;
    }

    NSUInteger index = completedIndex + 1;
    for (; index < [messageItems count]; index++) {
        id object = [messageItems objectAtIndex:index];
        if (![object isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *candidate = (TGMessageItem *)object;
        if ([[candidate chatID] isEqual:[completedItem chatID]] &&
            TGMessageItemCanParticipateInSequentialAudio(candidate)) {
            return candidate;
        }
    }
    return nil;
}
