#import "TGMediaPlaybackPreferences.h"
#include <math.h>

static NSString * const TGMediaPlaybackAudioRateDefaultsKey = @"TelegraphicaAudioPlaybackRate";
static NSString * const TGMediaPlaybackVideoRateDefaultsKey = @"TelegraphicaVideoPlaybackRate";

NSArray *TGMediaPlaybackSupportedRates(void) {
    return [NSArray arrayWithObjects:
            [NSNumber numberWithDouble:1.0],
            [NSNumber numberWithDouble:1.5],
            [NSNumber numberWithDouble:2.0],
            nil];
}

double TGMediaPlaybackNormalizedRate(double rate) {
    NSArray *rates = TGMediaPlaybackSupportedRates();
    NSUInteger index = 0;
    for (index = 0; index < [rates count]; index++) {
        double supported = [[rates objectAtIndex:index] doubleValue];
        if (fabs(rate - supported) < 0.01) {
            return supported;
        }
    }
    return 1.0;
}

double TGMediaPlaybackPreferredRate(BOOL audioOnly) {
    NSString *key = audioOnly ? TGMediaPlaybackAudioRateDefaultsKey : TGMediaPlaybackVideoRateDefaultsKey;
    NSNumber *stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return TGMediaPlaybackNormalizedRate([stored respondsToSelector:@selector(doubleValue)] ? [stored doubleValue] : 1.0);
}

void TGMediaPlaybackSetPreferredRate(BOOL audioOnly, double rate) {
    NSString *key = audioOnly ? TGMediaPlaybackAudioRateDefaultsKey : TGMediaPlaybackVideoRateDefaultsKey;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:TGMediaPlaybackNormalizedRate(rate)]
                                              forKey:key];
}
