#import <Foundation/Foundation.h>

NSString *TGProfileDisplayName(NSString *profileDisplayName);
NSString *TGProfileFullName(NSString *profileDisplayName,
                            NSString *profileFirstName,
                            NSString *profileLastName,
                            NSString *fallbackText);
NSString *TGProfileUsernameText(NSString *profileUsername);
NSString *TGProfilePhoneText(NSString *profilePhoneNumber);
NSString *TGProfileIDText(NSNumber *profileUserID);
NSString *TGProfileSubtitleText(NSString *profileUsername, NSNumber *profileUserID);
