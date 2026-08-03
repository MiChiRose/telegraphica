#import "TGAuthorizationFlow.h"

NSString * const TGAuthorizationFlowStateKey = @"state";
NSString * const TGAuthorizationFlowTitleLocalizationKey = @"title_key";
NSString * const TGAuthorizationFlowHintLocalizationKey = @"hint_key";
NSString * const TGAuthorizationFlowLabelLocalizationKey = @"label_key";
NSString * const TGAuthorizationFlowEmptyErrorLocalizationKey = @"empty_error_key";
NSString * const TGAuthorizationFlowSecureInputKey = @"secure_input";
NSString * const TGAuthorizationFlowSecondaryActionKey = @"secondary_action";

NSString * const TGAuthorizationFlowSecondaryActionNone = @"none";
NSString * const TGAuthorizationFlowSecondaryActionQRCode = @"qr";
NSString * const TGAuthorizationFlowSecondaryActionResendCode = @"again";
NSString * const TGAuthorizationFlowSecondaryActionRecoverPassword = @"help";

static NSDictionary *TGAuthorizationDescriptor(NSString *state,
                                               NSString *titleKey,
                                               NSString *hintKey,
                                               NSString *labelKey,
                                               NSString *emptyErrorKey,
                                               BOOL secureInput,
                                               NSString *secondaryAction) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            state ? state : @"", TGAuthorizationFlowStateKey,
            titleKey ? titleKey : @"login.connecting.title", TGAuthorizationFlowTitleLocalizationKey,
            hintKey ? hintKey : @"login.connecting.hint", TGAuthorizationFlowHintLocalizationKey,
            labelKey ? labelKey : @"login.status", TGAuthorizationFlowLabelLocalizationKey,
            emptyErrorKey ? emptyErrorKey : @"login.error.general", TGAuthorizationFlowEmptyErrorLocalizationKey,
            [NSNumber numberWithBool:secureInput], TGAuthorizationFlowSecureInputKey,
            secondaryAction ? secondaryAction : TGAuthorizationFlowSecondaryActionNone, TGAuthorizationFlowSecondaryActionKey,
            nil];
}

@implementation TGAuthorizationFlow

+ (BOOL)isInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitEmailAddress"] ||
           [state isEqualToString:@"waitEmailCode"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitRegistration"] ||
           [state isEqualToString:@"waitPassword"];
}

+ (NSDictionary *)descriptorForState:(NSString *)state {
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        return TGAuthorizationDescriptor(state, @"login.title", @"login.phone.hint", @"login.phone.label",
                                         @"login.empty.phone", NO, TGAuthorizationFlowSecondaryActionQRCode);
    }
    if ([state isEqualToString:@"waitEmailAddress"]) {
        return TGAuthorizationDescriptor(state, @"login.email.title", @"login.email.hint", @"login.email.label",
                                         @"login.empty.email", NO, TGAuthorizationFlowSecondaryActionNone);
    }
    if ([state isEqualToString:@"waitEmailCode"]) {
        return TGAuthorizationDescriptor(state, @"login.emailCode.title", @"login.emailCode.hint", @"login.emailCode.label",
                                         @"login.empty.emailCode", NO, TGAuthorizationFlowSecondaryActionResendCode);
    }
    if ([state isEqualToString:@"waitCode"]) {
        return TGAuthorizationDescriptor(state, @"login.code.title", @"login.code.hint", @"login.code.label",
                                         @"login.empty.code", NO, TGAuthorizationFlowSecondaryActionResendCode);
    }
    if ([state isEqualToString:@"waitRegistration"]) {
        return TGAuthorizationDescriptor(state, @"login.registration.title", @"login.registration.hint", @"login.registration.label",
                                         @"login.empty.registration", NO, TGAuthorizationFlowSecondaryActionNone);
    }
    if ([state isEqualToString:@"waitPassword"]) {
        return TGAuthorizationDescriptor(state, @"login.password.title", @"login.password.hint", @"login.password.label",
                                         @"login.empty.password", YES, TGAuthorizationFlowSecondaryActionRecoverPassword);
    }
    return TGAuthorizationDescriptor(state, nil, nil, nil, nil, NO, TGAuthorizationFlowSecondaryActionNone);
}

+ (NSDictionary *)safeDetailsFromAuthorizationStateObject:(NSDictionary *)stateObject {
    if (![stateObject isKindOfClass:[NSDictionary class]]) {
        return [NSDictionary dictionary];
    }
    NSString *type = [[stateObject objectForKey:@"@type"] isKindOfClass:[NSString class]]
        ? [stateObject objectForKey:@"@type"] : nil;
    if (![type hasPrefix:@"authorizationState"]) {
        return [NSDictionary dictionary];
    }

    NSMutableDictionary *details = [NSMutableDictionary dictionary];
    NSString *shortName = [type substringFromIndex:[@"authorizationState" length]];
    if ([shortName length] > 0) {
        NSString *state = [[[shortName substringToIndex:1] lowercaseString]
            stringByAppendingString:[shortName substringFromIndex:1]];
        [details setObject:state forKey:TGAuthorizationFlowStateKey];
    }

    NSDictionary *codeInfo = [[stateObject objectForKey:@"code_info"] isKindOfClass:[NSDictionary class]]
        ? [stateObject objectForKey:@"code_info"] : nil;
    id timeout = [codeInfo objectForKey:@"timeout"];
    if ([timeout respondsToSelector:@selector(integerValue)]) {
        NSInteger seconds = [timeout integerValue];
        if (seconds > 0 && seconds < 86400) {
            [details setObject:[NSNumber numberWithInteger:seconds] forKey:@"resend_timeout"];
        }
    }
    id length = [codeInfo objectForKey:@"length"];
    if ([length respondsToSelector:@selector(integerValue)] && [length integerValue] > 0) {
        [details setObject:[NSNumber numberWithInteger:[length integerValue]] forKey:@"code_length"];
    }
    id emailPattern = [codeInfo objectForKey:@"email_address_pattern"];
    if ([emailPattern isKindOfClass:[NSString class]] && [(NSString *)emailPattern length] > 0) {
        [details setObject:emailPattern forKey:@"email_pattern"];
    }
    if ([codeInfo objectForKey:@"next_type"] && [codeInfo objectForKey:@"next_type"] != [NSNull null]) {
        [details setObject:[NSNumber numberWithBool:YES] forKey:@"can_resend"];
    }
    if ([type isEqualToString:@"authorizationStateWaitEmailCode"]) {
        [details setObject:[NSNumber numberWithBool:YES] forKey:@"can_resend"];
    }

    id recoveryPattern = [stateObject objectForKey:@"recovery_email_address_pattern"];
    if ([recoveryPattern isKindOfClass:[NSString class]] && [(NSString *)recoveryPattern length] > 0) {
        [details setObject:recoveryPattern forKey:@"recovery_email_pattern"];
        [details setObject:[NSNumber numberWithBool:YES] forKey:@"can_recover_password"];
    }
    id hasRecovery = [stateObject objectForKey:@"has_recovery_email_address"];
    if ([hasRecovery respondsToSelector:@selector(boolValue)] && [hasRecovery boolValue]) {
        [details setObject:[NSNumber numberWithBool:YES] forKey:@"can_recover_password"];
    }
    return details;
}

+ (NSDictionary *)registrationNamesFromCombinedInput:(NSString *)input error:(NSError **)error {
    NSString *trimmed = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed length] == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"TGAuthorizationFlow" code:1
                                     userInfo:[NSDictionary dictionaryWithObject:@"A first name is required."
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *nonEmptyParts = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [parts count]; index++) {
        NSString *part = [parts objectAtIndex:index];
        if ([part length] > 0) {
            [nonEmptyParts addObject:part];
        }
    }
    NSString *firstName = [nonEmptyParts count] > 0 ? [nonEmptyParts objectAtIndex:0] : @"";
    NSString *lastName = [nonEmptyParts count] > 1
        ? [[nonEmptyParts subarrayWithRange:NSMakeRange(1, [nonEmptyParts count] - 1)] componentsJoinedByString:@" "]
        : @"";
    if ([firstName length] > 64 || [lastName length] > 64) {
        if (error) {
            *error = [NSError errorWithDomain:@"TGAuthorizationFlow" code:2
                                     userInfo:[NSDictionary dictionaryWithObject:@"The first or last name is too long."
                                                                          forKey:NSLocalizedDescriptionKey]];
        }
        return nil;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:firstName, @"first_name", lastName, @"last_name", nil];
}

+ (NSDictionary *)emailCodeAuthenticationObjectForCode:(NSString *)code {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            @"emailAddressAuthenticationCode", @"@type",
            code ? code : @"", @"code",
            nil];
}

+ (NSDictionary *)resendCodeReasonObject {
    return [NSDictionary dictionaryWithObject:@"resendCodeReasonUserRequest" forKey:@"@type"];
}

@end
