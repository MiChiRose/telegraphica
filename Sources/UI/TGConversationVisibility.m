#import "TGConversationVisibility.h"

BOOL TGConversationTranscriptIsVisible(NSView *transcriptView,
                                       NSWindow *hostWindow,
                                       BOOL applicationActive,
                                       BOOL chatsSectionActive,
                                       BOOL userConversationClosed,
                                       BOOL mediaCenterVisible) {
    if (!applicationActive || !chatsSectionActive || userConversationClosed || mediaCenterVisible)
        return NO;
    if (!transcriptView || !hostWindow || ![hostWindow isVisible] ||
        ![hostWindow isKeyWindow] || [hostWindow isMiniaturized]) return NO;
    if ([transcriptView window] != hostWindow) return NO;

    NSView *contentView = [hostWindow contentView];
    NSView *ancestor = transcriptView;
    while (ancestor) {
        if ([ancestor isHidden]) return NO;
        if (ancestor == contentView) return YES;
        ancestor = [ancestor superview];
    }
    return NO;
}
