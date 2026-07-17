#import "TGTypingIndicatorPresentation.h"
#import "../Core/TGMessageItem.h"

NSString *TGTypingActionTextForSummary(NSDictionary *summary) {
    NSString *actionType = [summary objectForKey:@"action_type"];
    if (![actionType isKindOfClass:[NSString class]]) {
        return @"пишет...";
    }
    if ([actionType isEqualToString:@"chatActionRecordingVoiceNote"]) {
        return @"записывает голосовое...";
    }
    if ([actionType isEqualToString:@"chatActionUploadingPhoto"]) {
        return @"отправляет фото...";
    }
    if ([actionType isEqualToString:@"chatActionUploadingVideo"]) {
        return @"отправляет видео...";
    }
    if ([actionType isEqualToString:@"chatActionUploadingDocument"]) {
        return @"отправляет файл...";
    }
    if ([actionType isEqualToString:@"chatActionRecordingVideoNote"]) {
        return @"записывает кружок...";
    }
    if ([actionType isEqualToString:@"chatActionUploadingVideoNote"]) {
        return @"отправляет кружок...";
    }
    if ([actionType isEqualToString:@"chatActionChoosingSticker"]) {
        return @"выбирает стикер...";
    }
    return @"пишет...";
}

NSString *TGTypingSenderNameForSummary(NSDictionary *summary,
                                       NSString *selectedChatTypeSummary,
                                       NSString *selectedChatTitle,
                                       NSArray *messageItems) {
    NSString *title = ([selectedChatTitle length] > 0) ? selectedChatTitle : @"";
    if ([selectedChatTypeSummary isEqualToString:@"Private"] && [title length] > 0) {
        return title;
    }

    NSNumber *senderID = [summary objectForKey:@"sender_id"];
    if ([senderID respondsToSelector:@selector(longLongValue)]) {
        NSEnumerator *enumerator = [messageItems reverseObjectEnumerator];
        TGMessageItem *item = nil;
        while ((item = [enumerator nextObject])) {
            if (![item isKindOfClass:[TGMessageItem class]]) {
                continue;
            }
            NSNumber *itemSenderID = [item senderID];
            if ([itemSenderID respondsToSelector:@selector(longLongValue)] &&
                [itemSenderID longLongValue] == [senderID longLongValue] &&
                [[item senderDisplayName] length] > 0) {
                return [item senderDisplayName];
            }
        }
    }

    return @"Кто-то";
}

NSString *TGTypingIndicatorTextForSummary(NSDictionary *summary,
                                          NSString *selectedChatTypeSummary,
                                          NSString *selectedChatTitle,
                                          NSArray *messageItems) {
    NSString *actionText = TGTypingActionTextForSummary(summary);
    if ([selectedChatTypeSummary isEqualToString:@"Private"]) {
        return actionText;
    }
    NSString *senderName = TGTypingSenderNameForSummary(summary, selectedChatTypeSummary, selectedChatTitle, messageItems);
    return [NSString stringWithFormat:@"%@ %@", senderName, actionText];
}
