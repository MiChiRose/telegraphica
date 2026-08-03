#import <Foundation/Foundation.h>

extern NSString * const TGAuthorizationFlowStateKey;
extern NSString * const TGAuthorizationFlowTitleLocalizationKey;
extern NSString * const TGAuthorizationFlowHintLocalizationKey;
extern NSString * const TGAuthorizationFlowLabelLocalizationKey;
extern NSString * const TGAuthorizationFlowEmptyErrorLocalizationKey;
extern NSString * const TGAuthorizationFlowSecureInputKey;
extern NSString * const TGAuthorizationFlowSecondaryActionKey;

extern NSString * const TGAuthorizationFlowSecondaryActionNone;
extern NSString * const TGAuthorizationFlowSecondaryActionQRCode;
extern NSString * const TGAuthorizationFlowSecondaryActionResendCode;
extern NSString * const TGAuthorizationFlowSecondaryActionRecoverPassword;

@interface TGAuthorizationFlow : NSObject

+ (BOOL)isInputState:(NSString *)state;
+ (NSDictionary *)descriptorForState:(NSString *)state;
+ (NSDictionary *)safeDetailsFromAuthorizationStateObject:(NSDictionary *)stateObject;
+ (NSDictionary *)registrationNamesFromCombinedInput:(NSString *)input error:(NSError **)error;
+ (NSDictionary *)emailCodeAuthenticationObjectForCode:(NSString *)code;
+ (NSDictionary *)resendCodeReasonObject;

@end
