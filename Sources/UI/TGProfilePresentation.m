#import "TGProfilePresentation.h"

NSString *TGProfileDisplayName(NSString *profileDisplayName) {
    return ([profileDisplayName length] > 0) ? profileDisplayName : @"Telegraphica";
}

NSString *TGProfileFullName(NSString *profileDisplayName,
                            NSString *profileFirstName,
                            NSString *profileLastName,
                            NSString *fallbackText) {
    if ([profileDisplayName length] == 0) {
        return fallbackText ? fallbackText : @"";
    }
    if ([profileFirstName length] > 0 && [profileLastName length] > 0) {
        return [NSString stringWithFormat:@"%@ %@", profileFirstName, profileLastName];
    }
    if ([profileFirstName length] > 0) {
        return profileFirstName;
    }
    return profileDisplayName;
}

NSString *TGProfileUsernameText(NSString *profileUsername) {
    if ([profileUsername length] == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"@%@", profileUsername];
}

NSString *TGProfilePhoneText(NSString *profilePhoneNumber) {
    if ([profilePhoneNumber length] == 0) {
        return @"";
    }
    if ([profilePhoneNumber hasPrefix:@"+"]) {
        return profilePhoneNumber;
    }
    return [@"+" stringByAppendingString:profilePhoneNumber];
}

NSString *TGProfileIDText(NSNumber *profileUserID) {
    if (![profileUserID respondsToSelector:@selector(longLongValue)]) {
        return @"";
    }
    return [NSString stringWithFormat:@"%lld", [profileUserID longLongValue]];
}

NSString *TGProfileSubtitleText(NSString *profileUsername, NSNumber *profileUserID) {
    NSString *usernameText = TGProfileUsernameText(profileUsername);
    NSString *idText = TGProfileIDText(profileUserID);
    if ([usernameText length] > 0 && [idText length] > 0) {
        return [NSString stringWithFormat:@"%@ (%@)", usernameText, idText];
    }
    if ([usernameText length] > 0) {
        return usernameText;
    }
    if ([idText length] > 0) {
        return [NSString stringWithFormat:@"(%@)", idText];
    }
    return @"";
}
