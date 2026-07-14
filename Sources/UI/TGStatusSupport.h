#import <Cocoa/Cocoa.h>

BOOL TGVersionStringIsNewer(NSString *candidate, NSString *current);
BOOL TGUserDefaultBoolWithDefault(NSString *key, BOOL defaultValue);
BOOL TGStatusErrorLooksOffline(NSString *message);
NSString *TGCurrentYearString(void);
NSString *TGLogTimestampString(void);
NSString *TGLogSectionForDetail(NSString *detail);
