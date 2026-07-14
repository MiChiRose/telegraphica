#import <Cocoa/Cocoa.h>

BOOL TGVersionStringIsNewer(NSString *candidate, NSString *current);
BOOL TGUserDefaultBoolWithDefault(NSString *key, BOOL defaultValue);
BOOL TGStatusErrorLooksOffline(NSString *message);
NSString *TGDefaultDownloadFolderPath(void);
NSString *TGConfiguredDownloadFolderPath(void);
NSString *TGDisplayPathForDownloadFolder(NSString *path);
void TGSetConfiguredDownloadFolderPath(NSString *path);
NSString *TGCurrentYearString(void);
NSString *TGLogTimestampString(void);
NSString *TGLogSectionForDetail(NSString *detail);
