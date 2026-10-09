#import <Cocoa/Cocoa.h>
@class TGNotificationReadState;

/* The supplied center is account/application scoped by the caller. */
void TGRemoveConfirmedReadNotifications(id center, TGNotificationReadState *readState);
/* Only after a successful explicit logout: remove this app's message entries,
   preserving call/update notifications and unrelated or malformed entries. */
void TGRemoveMessageNotificationsAfterLogout(id center);
/* Only authoritative ordinary-chat snapshots may advance chat-wide reads. */
void TGRecordConfirmedNotificationChatReads(NSArray *items, TGNotificationReadState *readState);
