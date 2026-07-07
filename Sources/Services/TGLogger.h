#import <Cocoa/Cocoa.h>

@interface TGLogger : NSObject

+ (instancetype)sharedLogger;
+ (BOOL)diagnosticsEnabled;
- (void)startDiagnosticSession;
- (void)log:(NSString *)message;
- (NSString *)currentLog;
- (void)clearLog;

@end
