#import <Cocoa/Cocoa.h>
@class TGNotificationReadState;

/* The supplied center is account/application scoped by the caller. */
void TGRemoveConfirmedReadNotifications(id center, TGNotificationReadState *readState);
