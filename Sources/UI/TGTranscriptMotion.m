#import "TGTranscriptMotion.h"
#import "TGAnimationSupport.h"
#import "TGResourcePolicy.h"
#import <objc/runtime.h>

static char TGTranscriptMotionAssociationKey;
static const NSTimeInterval TGTranscriptMotionDuration = 0.18;
static const NSUInteger TGTranscriptMaximumMotions = 4;

static NSString *TGTranscriptMotionKey(NSNumber *chatID, NSNumber *messageID) {
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![messageID respondsToSelector:@selector(longLongValue)]) return nil;
    return [NSString stringWithFormat:@"%lld:%lld", [chatID longLongValue], [messageID longLongValue]];
}

NSPoint TGTranscriptMotionOffset(CGFloat progress, BOOL outgoing, BOOL flipped, BOOL removing) {
    progress = MAX(0.0, MIN(1.0, progress));
    CGFloat amount = removing ? progress * progress : (1.0 - progress) * (1.0 - progress);
    return NSMakePoint((outgoing ? 12.0 : -12.0) * amount,
                       (flipped ? 8.0 : -8.0) * amount);
}

CGFloat TGTranscriptMotionOpacity(CGFloat progress, BOOL removing) {
    progress = MAX(0.0, MIN(1.0, progress));
    return removing ? 1.0 - progress : 0.35 + 0.65 * progress;
}

@interface TGTranscriptMotionController ()
- (NSDictionary *)motionForKey:(NSString *)key;
- (void)tick:(NSTimer *)timer;
- (void)finishKey:(NSString *)key;
- (void)policyOrApplicationDidChange:(NSNotification *)notification;
@end

@implementation TGTranscriptMotionController
- (id)initWithTableView:(NSTableView *)tableView {
    self = [super init];
    if (self) {
        _tableView = tableView;
        _motions = [[NSMutableDictionary alloc] init];
        objc_setAssociatedObject(tableView, &TGTranscriptMotionAssociationKey, self, OBJC_ASSOCIATION_ASSIGN);
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(policyOrApplicationDidChange:) name:TGResourcePolicyDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(policyOrApplicationDidChange:) name:NSApplicationDidResignActiveNotification object:nil];
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
    [_timer release];
    if (objc_getAssociatedObject(_tableView, &TGTranscriptMotionAssociationKey) == self)
        objc_setAssociatedObject(_tableView, &TGTranscriptMotionAssociationKey, nil, OBJC_ASSOCIATION_ASSIGN);
    [_motions release];
    [super dealloc];
}
- (NSUInteger)activeAnimationCount { return [_motions count]; }
- (NSUInteger)activeRemovalCount {
    NSUInteger count = 0;
    for (NSDictionary *motion in [_motions allValues]) {
        if ([[motion objectForKey:@"removing"] boolValue]) count++;
    }
    return count;
}
- (void)invalidateRow:(NSUInteger)row {
    if (row >= (NSUInteger)[_tableView numberOfRows]) return;
    NSRect dirty = NSInsetRect([_tableView rectOfRow:(NSInteger)row], -14.0, -10.0);
    [_tableView setNeedsDisplayInRect:NSIntersectionRect(dirty, [_tableView visibleRect])];
}
- (void)finishKey:(NSString *)key {
    NSDictionary *motion = [[_motions objectForKey:key] retain];
    if (!motion) return;
    [_motions removeObjectForKey:key];
    [self invalidateRow:[[motion objectForKey:@"row"] unsignedIntegerValue]];
    void (^completion)(void) = [motion objectForKey:@"completion"];
    if (completion) completion();
    [motion release];
}
- (void)cancelAllAnimations {
    [self retain];
    /* Stop before completions: those may synchronously start another UI action. */
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    NSArray *keys = [[_motions allKeys] copy];
    for (NSString *key in keys) [self finishKey:key];
    [keys release];
    [self release];
}
- (void)policyOrApplicationDidChange:(NSNotification *)notification {
    (void)notification;
    if (!TGInterfaceAnimationsEnabledForView(_tableView)) [self cancelAllAnimations];
}
- (void)beginMotionForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID
                       row:(NSUInteger)row outgoing:(BOOL)outgoing removing:(BOOL)removing completion:(void (^)(void))completion {
    NSString *key = TGTranscriptMotionKey(chatID, messageID);
    BOOL eligible = (key && TGInterfaceAnimationsEnabledForView(_tableView) &&
                     row < (NSUInteger)[_tableView numberOfRows] &&
                     NSIntersectsRect([_tableView rectOfRow:(NSInteger)row], [_tableView visibleRect]));
    if (!eligible || [_motions count] >= TGTranscriptMaximumMotions) {
        if (completion) completion();
        return;
    }
    if ([_motions objectForKey:key]) {
        if (!removing) return;
        [self finishKey:key];
    }
    NSMutableDictionary *motion = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedInteger:row], @"row",
        [NSNumber numberWithBool:outgoing], @"outgoing",
        [NSNumber numberWithBool:removing], @"removing",
        [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate]], @"started", nil];
    if (completion) {
        id copiedCompletion = [completion copy];
        [motion setObject:copiedCompletion forKey:@"completion"];
        [copiedCompletion release];
    }
    [_motions setObject:motion forKey:key];
    if (!_timer) {
        _timer = [[NSTimer timerWithTimeInterval:(1.0 / 15.0) target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    [self invalidateRow:row];
}
- (void)beginArrivalForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID row:(NSUInteger)row outgoing:(BOOL)outgoing {
    [self beginMotionForChatID:chatID messageID:messageID row:row outgoing:outgoing removing:NO completion:nil];
}
- (void)beginRemovalForChatID:(NSNumber *)chatID messageID:(NSNumber *)messageID row:(NSUInteger)row outgoing:(BOOL)outgoing completion:(void (^)(void))completion {
    [self beginMotionForChatID:chatID messageID:messageID row:row outgoing:outgoing removing:YES completion:completion];
}
- (NSDictionary *)motionForKey:(NSString *)key { return key ? [_motions objectForKey:key] : nil; }
- (void)tick:(NSTimer *)timer {
    [self retain];
    (void)timer;
    if (!TGInterfaceAnimationsEnabledForView(_tableView)) {
        [self cancelAllAnimations];
        [self release];
        return;
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSArray *keys = [[_motions allKeys] copy];
    for (NSString *key in keys) {
        NSDictionary *motion = [_motions objectForKey:key];
        NSUInteger row = [[motion objectForKey:@"row"] unsignedIntegerValue];
        if ((now - [[motion objectForKey:@"started"] doubleValue]) >= TGTranscriptMotionDuration ||
            row >= (NSUInteger)[_tableView numberOfRows] ||
            !NSIntersectsRect([_tableView rectOfRow:(NSInteger)row], [_tableView visibleRect])) {
            [self finishKey:key];
        } else [self invalidateRow:row];
    }
    [keys release];
    if ([_motions count] == 0) {
        [_timer invalidate];
        [_timer release];
        _timer = nil;
    }
    [self release];
}
@end

BOOL TGTranscriptMotionBeginCellDrawing(NSView *view, NSNumber *chatID, NSNumber *messageID) {
    TGTranscriptMotionController *controller = objc_getAssociatedObject(view, &TGTranscriptMotionAssociationKey);
    NSDictionary *motion = [controller motionForKey:TGTranscriptMotionKey(chatID, messageID)];
    if (!motion) return NO;
    CGFloat progress = ([NSDate timeIntervalSinceReferenceDate] - [[motion objectForKey:@"started"] doubleValue]) / TGTranscriptMotionDuration;
    BOOL removing = [[motion objectForKey:@"removing"] boolValue];
    NSPoint offset = TGTranscriptMotionOffset(progress, [[motion objectForKey:@"outgoing"] boolValue], [view isFlipped], removing);
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform *transform = [NSAffineTransform transform];
    [transform translateXBy:offset.x yBy:offset.y];
    [transform concat];
    CGContextSetAlpha((CGContextRef)[[NSGraphicsContext currentContext] graphicsPort], TGTranscriptMotionOpacity(progress, removing));
    return YES;
}
void TGTranscriptMotionEndCellDrawing(BOOL didBegin) {
    if (didBegin) [NSGraphicsContext restoreGraphicsState];
}
