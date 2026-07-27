#import <Cocoa/Cocoa.h>

@interface TGContactManagementDialogs : NSObject

+ (NSDictionary *)contactToAdd;
+ (NSString *)phoneNumberForInvitation;
+ (BOOL)confirmRemovalOfContactNamed:(NSString *)displayName;

@end
