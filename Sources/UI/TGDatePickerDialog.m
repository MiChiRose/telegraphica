#import "TGDatePickerDialog.h"
#import "TGLocalization.h"

@implementation TGDatePickerDialog

+ (NSDate *)dateWithTitle:(NSString *)title
                     help:(NSString *)help
              actionTitle:(NSString *)actionTitle
              initialDate:(NSDate *)initialDate
                  minDate:(NSDate *)minDate {
    NSView *accessory = [[[NSView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 360.0, 48.0)] autorelease];
    NSDatePicker *picker = [[[NSDatePicker alloc] initWithFrame:NSMakeRect(0.0, 10.0, 360.0, 28.0)] autorelease];
    [picker setDatePickerStyle:NSTextFieldAndStepperDatePickerStyle];
    [picker setDatePickerElements:(NSYearMonthDayDatePickerElementFlag |
                                   NSHourMinuteDatePickerElementFlag)];
    [picker setMinDate:minDate];
    [picker setDateValue:initialDate ? initialDate : [NSDate date]];
    [picker setAutoresizingMask:NSViewWidthSizable];
    [accessory addSubview:picker];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title ? title : @""];
    [alert setInformativeText:help ? help : @""];
    [alert setAccessoryView:accessory];
    [alert addButtonWithTitle:actionTitle ? actionTitle : @"OK"];
    [alert addButtonWithTitle:TGLoc(@"cancel")];
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    return [[[picker dateValue] retain] autorelease];
}

@end
