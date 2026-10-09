#import <Foundation/Foundation.h>

// Tracks the main window's selected conversation. Topics share their parent
// chat, while linked discussions use their actual destination chat identifier.
@interface TGChatOpenState : NSObject {
    NSNumber *_desiredChatID;
    NSNumber *_openedChatID;
    NSString *_pendingOpenExtra;
    NSUInteger _openAttemptCount;
    NSUInteger _requestSequence;
    NSUInteger _selectionGeneration;
}
- (void)setDesiredChatID:(NSNumber *)chatID;
// Read lease requires an acknowledged open and expires on selection or transport changes.
- (NSNumber *)selectionGenerationForDesiredChatID:(NSNumber *)chatID;
// Called only when a TDLib transport exists and can accept these requests.
- (NSArray *)requestsForCurrentSelection;
// YES asks the owner to schedule one bounded retry after a transient error.
- (BOOL)handleOpenResponse:(NSDictionary *)response;
// A destroyed/replaced transport must reopen even the same selected chat.
- (void)resetTransport;
@end
