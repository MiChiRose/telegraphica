#import <Cocoa/Cocoa.h>

@interface TGDatePickerDialog : NSObject

+ (NSDate *)dateWithTitle:(NSString *)title
                     help:(NSString *)help
              actionTitle:(NSString *)actionTitle
              initialDate:(NSDate *)initialDate
                  minDate:(NSDate *)minDate;

@end
