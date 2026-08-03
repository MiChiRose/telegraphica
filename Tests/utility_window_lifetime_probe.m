#import <Foundation/Foundation.h>
#import "TGUtilityWindowLifetime.h"

static void TGLifetimeAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "Utility window lifetime probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGUtilityWindowLifetime *lifetime = [[[TGUtilityWindowLifetime alloc] init] autorelease];

    TGLifetimeAssert(![lifetime isActive], @"new lifetime should be inactive");
    NSUInteger presentation = [lifetime beginPresentation];
    TGLifetimeAssert([lifetime isCurrentGeneration:presentation], @"presentation generation should be current");

    NSUInteger firstOperation = [lifetime beginOperation];
    TGLifetimeAssert(firstOperation != presentation, @"operation should advance generation");
    TGLifetimeAssert(![lifetime isCurrentGeneration:presentation], @"previous generation should become stale");
    TGLifetimeAssert([lifetime isCurrentGeneration:firstOperation], @"latest operation should be current");

    [lifetime invalidate];
    TGLifetimeAssert(![lifetime isActive], @"closed lifetime should be inactive");
    TGLifetimeAssert(![lifetime isCurrentGeneration:firstOperation], @"closed window should reject late completion");

    NSUInteger reopened = [lifetime beginPresentation];
    TGLifetimeAssert([lifetime isCurrentGeneration:reopened], @"reopened window should accept only its new generation");
    TGLifetimeAssert(![lifetime isCurrentGeneration:firstOperation], @"reopen must not revive an old callback");

    printf("Utility window lifetime probe passed.\n");
    [pool drain];
    return 0;
}
