#import "TGChatOpenState.h"

@implementation TGChatOpenState

- (void)setDesiredChatID:(NSNumber *)chatID {
    NSNumber *normalized = ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] != 0)
        ? [NSNumber numberWithLongLong:[chatID longLongValue]] : nil;
    @synchronized(self) {
        if ((_desiredChatID == normalized) || (_desiredChatID && normalized && [_desiredChatID isEqualToNumber:normalized])) {
            return;
        }
        [_desiredChatID release];
        _desiredChatID = [normalized retain];
        _openAttemptCount = 0;
    }
}

- (NSArray *)requestsForCurrentSelection {
    @synchronized(self) {
        if ((_openedChatID == _desiredChatID) || (_openedChatID && _desiredChatID && [_openedChatID isEqualToNumber:_desiredChatID])) {
            return [NSArray array];
        }
        NSMutableArray *requests = [NSMutableArray array];
        if (_openedChatID) {
            [requests addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                @"closeChat", @"@type", _openedChatID, @"chat_id", nil]];
            [_openedChatID release];
            _openedChatID = nil;
        }
        [_pendingOpenExtra release];
        _pendingOpenExtra = nil;
        if (_desiredChatID && _openAttemptCount < 3) {
            _openAttemptCount++;
            _requestSequence++;
            _pendingOpenExtra = [[NSString stringWithFormat:@"telegraphica-visible-chat-%lu", (unsigned long)_requestSequence] copy];
            [requests addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                @"openChat", @"@type", _desiredChatID, @"chat_id", _pendingOpenExtra, @"@extra", nil]];
            _openedChatID = [_desiredChatID retain];
        }
        return requests;
    }
}

- (BOOL)handleOpenResponse:(NSDictionary *)response {
    @synchronized(self) {
        if (![[response objectForKey:@"@extra"] isEqual:_pendingOpenExtra] || !_pendingOpenExtra) {
            return NO;
        }
        [_pendingOpenExtra release];
        _pendingOpenExtra = nil;
        if (![[response objectForKey:@"@type"] isEqual:@"error"]) {
            return NO;
        }
        BOOL stillSelected = (_openedChatID && _desiredChatID && [_openedChatID isEqualToNumber:_desiredChatID]);
        [_openedChatID release];
        _openedChatID = nil;
        NSInteger code = [[response objectForKey:@"code"] integerValue];
        BOOL transient = (code == 429 || code >= 500);
        if (stillSelected && !transient) {
            _openAttemptCount = 3;
        }
        return stillSelected && transient && _openAttemptCount < 3;
    }
}

- (void)resetTransport {
    @synchronized(self) {
        [_openedChatID release];
        _openedChatID = nil;
        [_pendingOpenExtra release];
        _pendingOpenExtra = nil;
        _openAttemptCount = 0;
    }
}

- (void)dealloc {
    [_desiredChatID release];
    [_openedChatID release];
    [_pendingOpenExtra release];
    [super dealloc];
}
@end
