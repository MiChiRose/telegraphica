#import "TGUtilityWindowLifetime.h"

@implementation TGUtilityWindowLifetime

- (NSUInteger)generation {
    return _generation;
}

- (BOOL)isActive {
    return _active;
}

- (NSUInteger)advanceGeneration {
    _generation++;
    if (_generation == 0U) {
        _generation = 1U;
    }
    return _generation;
}

- (NSUInteger)beginPresentation {
    _active = YES;
    return [self advanceGeneration];
}

- (NSUInteger)beginOperation {
    if (!_active) {
        return _generation;
    }
    return [self advanceGeneration];
}

- (void)invalidate {
    _active = NO;
    [self advanceGeneration];
}

- (BOOL)isCurrentGeneration:(NSUInteger)generation {
    return _active && generation != 0U && generation == _generation;
}

@end
