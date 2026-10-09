#import "TGNotificationDeliverySupport.h"
#import "TGNotificationReadState.h"
#import "../Core/TGChatItem.h"

void TGRecordConfirmedNotificationChatReads(NSArray *items, TGNotificationReadState *readState) {
    if (![items isKindOfClass:[NSArray class]]) { return; }
    for (id value in items) {
        if (![value isKindOfClass:[TGChatItem class]] || [value isForumTopic]) { continue; }
        [readState recordReadInboxMessageID:[value lastReadInboxMessageID] chatID:[value chatID]];
    }
}

void TGRemoveConfirmedReadNotifications(id center, TGNotificationReadState *readState) {
    if (![center respondsToSelector:@selector(deliveredNotifications)] ||
        ![center respondsToSelector:@selector(removeDeliveredNotification:)]) { return; }
    NSArray *delivered = [[center deliveredNotifications] copy];
    for (id notification in delivered) {
        if ([notification respondsToSelector:@selector(userInfo)] &&
            [readState isReadNotificationInfo:[notification userInfo]]) {
            [center removeDeliveredNotification:notification];
        }
    }
    [delivered release];
}
