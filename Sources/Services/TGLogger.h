#import <Cocoa/Cocoa.h>

@interface TGLogger : NSObject

+ (instancetype)sharedLogger;
+ (BOOL)diagnosticsEnabled;
+ (NSString *)redactedDiagnosticMessage:(NSString *)message;
- (void)startDiagnosticSession;
- (void)log:(NSString *)message;
- (NSString *)currentLog;
- (void)clearLog;
- (void)clearDiagnosticFile;

@end
