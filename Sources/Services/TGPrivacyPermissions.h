#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, TGPrivacyPermissionState) {
    TGPrivacyPermissionStateNotDetermined = 0,
    TGPrivacyPermissionStateAllowed = 1,
    TGPrivacyPermissionStateDenied = 2
};

extern NSString * const TGPrivacyPermissionsDidChangeNotification;

@interface TGPrivacyPermissions : NSObject

+ (TGPrivacyPermissionState)microphonePermissionState;
+ (TGPrivacyPermissionState)locationPermissionState;

+ (BOOL)requestMicrophonePermission;
+ (BOOL)requestLocationPermission;

+ (void)setMicrophoneAllowed:(BOOL)allowed;
+ (void)setLocationAllowed:(BOOL)allowed;

@end
