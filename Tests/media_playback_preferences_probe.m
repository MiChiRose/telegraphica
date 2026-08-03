#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#import "../Sources/Media/TGMediaPlaybackPreferences.h"

static void TGAssert(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "Media playback preference assertion failed: %s\n", message);
        exit(1);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGAssert([TGMediaPlaybackSupportedRates() count] == 3, "legacy-safe rate catalog should be bounded");
    TGAssert(TGMediaPlaybackNormalizedRate(1.5) == 1.5, "supported rate should survive normalization");
    TGAssert(TGMediaPlaybackNormalizedRate(9.0) == 1.0, "unsupported rate should fail safe");
    TGMediaPlaybackSetPreferredRate(YES, 2.0);
    TGMediaPlaybackSetPreferredRate(NO, 1.5);
    TGAssert(TGMediaPlaybackPreferredRate(YES) == 2.0, "audio rate should persist independently");
    TGAssert(TGMediaPlaybackPreferredRate(NO) == 1.5, "video rate should persist independently");
    TGMediaPlaybackSetSequentialAudioEnabled(NO);
    TGAssert(!TGMediaPlaybackSequentialAudioEnabled(), "sequential audio should be disabled");
    TGMediaPlaybackSetSequentialAudioEnabled(YES);
    TGAssert(TGMediaPlaybackSequentialAudioEnabled(), "sequential audio preference should persist");
    TGMediaPlaybackSetSequentialAudioEnabled(NO);
    fprintf(stdout, "Media playback preferences probe passed.\n");
    [pool drain];
    return 0;
}
