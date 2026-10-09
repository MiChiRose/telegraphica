#import <Cocoa/Cocoa.h>

/* Decorative motion never changes row geometry, scroll anchors or hit testing. */
NSPoint TGTranscriptMotionOffset(CGFloat progress, BOOL outgoing, BOOL flipped, BOOL removing);
CGFloat TGTranscriptMotionOpacity(CGFloat progress, BOOL removing);

@interface TGTranscriptMotionController : NSObject {
    NSTableView *_tableView; /* The owning controller owns the table. */
    NSMutableDictionary *_motions;
    NSTimer *_timer;
}
- (id)initWithTableView:(NSTableView *)tableView;
- (void)beginArrivalForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID
                        row:(NSUInteger)row outgoing:(BOOL)outgoing;
/* Completion also runs on cancellation, so confirmed model deletion is never lost. */
- (void)beginRemovalForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID
                        row:(NSUInteger)row outgoing:(BOOL)outgoing completion:(void (^)(void))completion;
- (void)cancelAllAnimations;
- (NSUInteger)activeAnimationCount;
- (NSUInteger)activeRemovalCount;
@end

BOOL TGTranscriptMotionBeginCellDrawing(NSView *view, NSNumber *chatID, NSNumber *messageID);
void TGTranscriptMotionEndCellDrawing(BOOL didBegin);
