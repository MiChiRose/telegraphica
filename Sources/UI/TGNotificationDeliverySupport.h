#import <Cocoa/Cocoa.h>
@class TGNotificationReadState;

/* The supplied center is account/application scoped by the caller. */
void TGRemoveConfirmedReadNotifications(id center, TGNotificationReadState *readState);
/* Only authoritative ordinary-chat snapshots may advance chat-wide reads. */
void TGRecordConfirmedNotificationChatReads(NSArray *items, TGNotificationReadState *readState);
