#import <Foundation/Foundation.h>

extern NSString * const TGResourcePolicyDidChangeNotification;

typedef enum {
    TGResourceAutoDownloadPhoto = 0,
    TGResourceAutoDownloadVideo = 1,
    TGResourceAutoDownloadDocument = 2
} TGResourceAutoDownloadType;

BOOL TGResourcePolicyEconomyModeEnabled(void);
void TGResourcePolicySetEconomyModeEnabled(BOOL enabled);

BOOL TGResourcePolicyAutoDownloadEnabledForType(TGResourceAutoDownloadType type);
void TGResourcePolicySetAutoDownloadEnabledForType(TGResourceAutoDownloadType type, BOOL enabled);

long long TGResourcePolicyMaxAutoDownloadBytes(void);
void TGResourcePolicySetMaxAutoDownloadBytes(long long bytes);
NSArray *TGResourcePolicyMaxAutoDownloadChoices(void);
NSString *TGResourcePolicyReadableSize(long long bytes);

BOOL TGResourcePolicyAutoplayAnimatedStickers(void);
void TGResourcePolicySetAutoplayAnimatedStickers(BOOL enabled);
BOOL TGResourcePolicyAutoplayAnimatedStickersEnabled(void);
void TGResourcePolicySetAutoplayAnimatedStickersEnabled(BOOL enabled);

NSUInteger TGResourcePolicyMaximumActiveAnimations(void);
void TGResourcePolicySetMaximumActiveAnimations(NSUInteger count);
NSArray *TGResourcePolicyMaximumActiveAnimationChoices(void);
NSUInteger TGResourcePolicyMaxActiveAnimations(void);
void TGResourcePolicySetMaxActiveAnimations(NSUInteger count);
NSArray *TGResourcePolicyMaxActiveAnimationChoices(void);

BOOL TGResourcePolicyStopAnimationsWhenInactive(void);
void TGResourcePolicySetStopAnimationsWhenInactive(BOOL enabled);
BOOL TGResourcePolicyStopAnimationsWhenInactiveEnabled(void);
void TGResourcePolicySetStopAnimationsWhenInactiveEnabled(BOOL enabled);

long long TGResourcePolicyMediaCacheLimitBytes(void);
void TGResourcePolicySetMediaCacheLimitBytes(long long bytes);
NSArray *TGResourcePolicyMediaCacheLimitChoices(void);

long long TGResourcePolicyLargeAttachmentWarningBytes(void);
void TGResourcePolicyApplyDefaultsIfNeeded(void);
