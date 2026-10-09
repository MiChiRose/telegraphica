#import "TGNotificationDeliverySupport.h"
#import "TGNotificationReadState.h"

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
