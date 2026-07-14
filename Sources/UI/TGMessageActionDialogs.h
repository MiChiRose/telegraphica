#import <Cocoa/Cocoa.h>

typedef enum {
    TGMessageDeleteChoiceCancel = 0,
    TGMessageDeleteChoiceOnlyForSelf = 1,
    TGMessageDeleteChoiceForEveryone = 2
} TGMessageDeleteChoice;

@interface TGMessageActionDialogs : NSObject

+ (NSString *)editedTextForCurrentText:(NSString *)currentText;
+ (TGMessageDeleteChoice)deleteChoiceWithCanDeleteOnlyForSelf:(BOOL)canDeleteOnlyForSelf
                                         canDeleteForAllUsers:(BOOL)canDeleteForAllUsers;

@end
