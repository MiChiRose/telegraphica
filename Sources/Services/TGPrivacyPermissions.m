#import "TGPrivacyPermissions.h"

#import "../UI/TGLocalization.h"

NSString * const TGPrivacyPermissionsDidChangeNotification =
    @"TGPrivacyPermissionsDidChangeNotification";

static NSString * const TGMicrophonePermissionDefaultsKey =
    @"TelegraphicaMicrophonePermissionDecisionV2";
static NSString * const TGCameraPermissionDefaultsKey =
    @"TelegraphicaCameraPermissionDecisionV1";
static NSString * const TGLocationPermissionDefaultsKey =
    @"TelegraphicaLocationPermissionDecisionV1";

@implementation TGPrivacyPermissions

+ (TGPrivacyPermissionState)permissionStateForKey:(NSString *)key {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (![value respondsToSelector:@selector(integerValue)]) {
        return TGPrivacyPermissionStateNotDetermined;
    }
    NSInteger state = [value integerValue];
    return (state == TGPrivacyPermissionStateAllowed ||
            state == TGPrivacyPermissionStateDenied)
        ? (TGPrivacyPermissionState)state
        : TGPrivacyPermissionStateNotDetermined;
}

+ (void)setPermissionState:(TGPrivacyPermissionState)state key:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setInteger:state forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TGPrivacyPermissionsDidChangeNotification
                      object:self];
}

+ (TGPrivacyPermissionState)microphonePermissionState {
    return [self permissionStateForKey:TGMicrophonePermissionDefaultsKey];
}

+ (TGPrivacyPermissionState)cameraPermissionState {
    return [self permissionStateForKey:TGCameraPermissionDefaultsKey];
}

+ (TGPrivacyPermissionState)locationPermissionState {
    return [self permissionStateForKey:TGLocationPermissionDefaultsKey];
}

+ (BOOL)requestPermissionWithTitleKey:(NSString *)titleKey
                           messageKey:(NSString *)messageKey
                           defaultsKey:(NSString *)defaultsKey {
    TGPrivacyPermissionState state = [self permissionStateForKey:defaultsKey];
    if (state == TGPrivacyPermissionStateAllowed) {
        return YES;
    }
    if (state == TGPrivacyPermissionStateDenied) {
        NSAlert *disabledAlert = [[[NSAlert alloc] init] autorelease];
        [disabledAlert setMessageText:TGLoc(@"privacy.permissions.disabled.title")];
        [disabledAlert setInformativeText:TGLoc(@"privacy.permissions.disabled.message")];
        [disabledAlert addButtonWithTitle:TGLoc(@"ok")];
        [disabledAlert runModal];
        return NO;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:TGLoc(titleKey)];
    [alert setInformativeText:TGLoc(messageKey)];
    [alert addButtonWithTitle:TGLoc(@"privacy.permissions.allow")];
    [alert addButtonWithTitle:TGLoc(@"privacy.permissions.deny")];
    BOOL allowed = ([alert runModal] == NSAlertFirstButtonReturn);
    [self setPermissionState:(allowed
        ? TGPrivacyPermissionStateAllowed
        : TGPrivacyPermissionStateDenied)
                         key:defaultsKey];
    return allowed;
}

+ (BOOL)requestMicrophonePermission {
    return [self requestPermissionWithTitleKey:@"privacy.permissions.microphonePrompt.title"
                                   messageKey:@"privacy.permissions.microphonePrompt.message"
                                  defaultsKey:TGMicrophonePermissionDefaultsKey];
}

+ (BOOL)requestCameraPermission {
    return [self requestPermissionWithTitleKey:@"privacy.permissions.cameraPrompt.title"
                                   messageKey:@"privacy.permissions.cameraPrompt.message"
                                  defaultsKey:TGCameraPermissionDefaultsKey];
}

+ (BOOL)requestLocationPermission {
    return [self requestPermissionWithTitleKey:@"privacy.permissions.locationPrompt.title"
                                   messageKey:@"privacy.permissions.locationPrompt.message"
                                  defaultsKey:TGLocationPermissionDefaultsKey];
}

+ (void)setMicrophoneAllowed:(BOOL)allowed {
    [self setPermissionState:(allowed
        ? TGPrivacyPermissionStateAllowed
        : TGPrivacyPermissionStateDenied)
                         key:TGMicrophonePermissionDefaultsKey];
}

+ (void)setCameraAllowed:(BOOL)allowed {
    [self setPermissionState:(allowed
        ? TGPrivacyPermissionStateAllowed
        : TGPrivacyPermissionStateDenied)
                         key:TGCameraPermissionDefaultsKey];
}

+ (void)setLocationAllowed:(BOOL)allowed {
    [self setPermissionState:(allowed
        ? TGPrivacyPermissionStateAllowed
        : TGPrivacyPermissionStateDenied)
                         key:TGLocationPermissionDefaultsKey];
}

@end
