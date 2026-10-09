#import <Cocoa/Cocoa.h>

/* Automatic read/openChat eligibility only; explicit user actions may use their
 * own policy. Call on the main thread with the current account/navigation state. */
BOOL TGConversationTranscriptIsVisible(NSView *transcriptView,
                                       NSWindow *hostWindow,
                                       BOOL applicationActive,
                                       BOOL chatsSectionActive,
                                       BOOL userConversationClosed,
                                       BOOL mediaCenterVisible);
