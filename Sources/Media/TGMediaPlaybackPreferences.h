#import <Foundation/Foundation.h>

NSArray *TGMediaPlaybackSupportedRates(void);
double TGMediaPlaybackNormalizedRate(double rate);
double TGMediaPlaybackPreferredRate(BOOL audioOnly);
void TGMediaPlaybackSetPreferredRate(BOOL audioOnly, double rate);
BOOL TGMediaPlaybackSequentialAudioEnabled(void);
void TGMediaPlaybackSetSequentialAudioEnabled(BOOL enabled);
