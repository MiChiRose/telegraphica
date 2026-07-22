#import <Foundation/Foundation.h>
#include <limits.h>

static const NSUInteger TGMediaMaximumDecodedSide = 4096;
static const unsigned long long TGMediaMaximumDecodedBytes = 128ULL * 1024ULL * 1024ULL;
static const NSUInteger TGMediaMaximumAnimatedFrameCount = 180;
static const unsigned long long TGMediaMaximumCompressedWebMFrameBytes = 8ULL * 1024ULL * 1024ULL;
static const NSUInteger TGMediaMaximumTGSRepeaterCopies = 256;
static const unsigned long long TGMediaMaximumOpusInputBytes = 128ULL * 1024ULL * 1024ULL;
static const unsigned long long TGMediaMaximumDecodedVoiceBytes = 512ULL * 1024ULL * 1024ULL;
static const NSTimeInterval TGMediaMaximumVoiceTranscodeSeconds = 120.0;

static inline BOOL TGMediaDimensionsFitDecodedBudget(NSUInteger width,
                                                     NSUInteger height,
                                                     NSUInteger bytesPerPixel,
                                                     unsigned long long maximumBytes) {
    if (width == 0 || height == 0 || bytesPerPixel == 0 ||
        width > TGMediaMaximumDecodedSide || height > TGMediaMaximumDecodedSide) {
        return NO;
    }
    if ((unsigned long long)width > ULLONG_MAX / (unsigned long long)height) {
        return NO;
    }
    unsigned long long pixels = (unsigned long long)width * (unsigned long long)height;
    if (pixels > ULLONG_MAX / (unsigned long long)bytesPerPixel) {
        return NO;
    }
    return pixels * (unsigned long long)bytesPerPixel <= maximumBytes;
}
