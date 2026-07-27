#import <Cocoa/Cocoa.h>

@class TGTDLibClient;

typedef enum {
    TGMessageDeleteChoiceCancel = 0,
    TGMessageDeleteChoiceOnlyForSelf = 1,
    TGMessageDeleteChoiceForEveryone = 2
} TGMessageDeleteChoice;

@interface TGMessageActionDialogs : NSObject

+ (NSString *)editedTextForCurrentText:(NSString *)currentText;
+ (NSDictionary *)contactToShare;
+ (NSDictionary *)locationToShareWithClient:(TGTDLibClient *)client;
+ (NSDictionary *)venueToShareWithClient:(TGTDLibClient *)client;
+ (NSDictionary *)liveLocationToShareWithClient:(TGTDLibClient *)client;
+ (BOOL)confirmPlainDeleteMessage;
+ (TGMessageDeleteChoice)deleteChoiceWithCanDeleteOnlyForSelf:(BOOL)canDeleteOnlyForSelf
                                         canDeleteForAllUsers:(BOOL)canDeleteForAllUsers;

@end
