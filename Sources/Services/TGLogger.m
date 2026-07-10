#import "TGLogger.h"

@interface TGLogger ()
@property (nonatomic, retain) NSMutableArray *logLines;
@end

@implementation TGLogger

@synthesize logLines = _logLines;

static NSUInteger const TGLoggerMaxInMemoryLines = 500;

static BOOL TGLoggerFlagEnabled(NSString *value) {
    if (!value) return NO;
    NSString *normalized = [[value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    return [normalized isEqualToString:@"1"] ||
           [normalized isEqualToString:@"yes"] ||
           [normalized isEqualToString:@"true"] ||
           [normalized isEqualToString:@"on"] ||
           [normalized isEqualToString:@"debug"];
}

static NSString *TGLoggerThreadLabel(void) {
    return [NSThread isMainThread] ? @"main" : @"background";
}

static NSString *TGLoggerRedactedByPattern(NSString *message, NSString *pattern, NSString *replacement) {
    if (![message isKindOfClass:[NSString class]] || [message length] == 0) {
        return @"";
    }
    NSError *error = nil;
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                                       options:NSRegularExpressionCaseInsensitive
                                                                                         error:&error];
    if (!regularExpression || error) {
        return message;
    }
    return [regularExpression stringByReplacingMatchesInString:message
                                                       options:0
                                                         range:NSMakeRange(0, [message length])
                                                  withTemplate:replacement];
}

static NSString *TGLoggerRedactedMessage(NSString *message) {
    if (!message) return @"";
    NSString *lowercase = [message lowercaseString];
    NSArray *sensitiveMarkers = [NSArray arrayWithObjects:@"api_hash", @"authentication_code", @"authentication code", @"auth code", @"phone_number", @"phone number", @"database_encryption_key", @"encryption_key", @"password", @"\"code\"", @"login code", @"api id", @"api_id", nil];
    NSUInteger index = 0;
    for (index = 0; index < [sensitiveMarkers count]; index++) {
        if ([lowercase rangeOfString:[sensitiveMarkers objectAtIndex:index]].location != NSNotFound) {
            return @"<redacted sensitive log line>";
        }
    }
    NSString *redacted = message;
    redacted = TGLoggerRedactedByPattern(redacted, @"([?&](token|hash|code|key|password)=)[^\\s&]+", @"$1<redacted>");
    redacted = TGLoggerRedactedByPattern(redacted, @"\\+?[0-9][0-9 ()-]{7,}[0-9]", @"<redacted-number>");
    redacted = TGLoggerRedactedByPattern(redacted, @"\\b[A-Fa-f0-9]{32,}\\b", @"<redacted-token>");
    return redacted;
}

+ (instancetype)sharedLogger {
    static TGLogger *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        shared.logLines = [NSMutableArray array];
    });
    return shared;
}

+ (BOOL)diagnosticsEnabled {
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *envFlag = [environment objectForKey:@"TELEGRAPHICA_DEBUG"];
    if (!envFlag) {
        envFlag = [environment objectForKey:@"TELEGRAPHICA_DEV_LOGS"];
    }
    if ([envFlag length] > 0) {
        return TGLoggerFlagEnabled(envFlag);
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"TelegraphicaDebugEnabled"];
}

- (NSString *)diagnosticLogPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support"];
    NSString *directory = [basePath stringByAppendingPathComponent:@"Telegraphica/Logs"];
    return [directory stringByAppendingPathComponent:@"Telegraphica-Debug.log"];
}

- (void)appendDiagnosticLine:(NSString *)line {
    if (!line || ![TGLogger diagnosticsEnabled]) {
        return;
    }

    @synchronized (self) {
        NSString *path = [self diagnosticLogPath];
        NSString *parent = [path stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:parent
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) {
            [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
            handle = [NSFileHandle fileHandleForWritingAtPath:path];
        }

        if (handle) {
            NSData *data = [[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding];
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        }
    }
}

- (void)startDiagnosticSession {
    if (![TGLogger diagnosticsEnabled]) {
        return;
    }

    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *osString = [[NSProcessInfo processInfo] operatingSystemVersionString];

    [self appendDiagnosticLine:@""];
    [self appendDiagnosticLine:@"==================== Telegraphica Diagnostic Session ===================="];
    [self log:[NSString stringWithFormat:@"App version: %@ (%@)", bundleVersion ? bundleVersion : @"unknown", build ? build : @"unknown"]];
    [self log:[NSString stringWithFormat:@"Bundle path: %@", bundlePath ? bundlePath : @"unknown"]];
    [self log:[NSString stringWithFormat:@"OS: %@", osString ? osString : @"unknown"]];
    [self log:[NSString stringWithFormat:@"Process: %@ pid=%d", [[NSProcessInfo processInfo] processName], [[NSProcessInfo processInfo] processIdentifier]]];
}

- (void)log:(NSString *)message {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterShortStyle
                                                         timeStyle:NSDateFormatterLongStyle];
    NSString *safeMessage = TGLoggerRedactedMessage(message);
    NSString *line = [NSString stringWithFormat:@"[%@][%@] %@", timestamp, TGLoggerThreadLabel(), safeMessage];

    @synchronized (self) {
        [self.logLines addObject:line];
        while ([self.logLines count] > TGLoggerMaxInMemoryLines) {
            [self.logLines removeObjectAtIndex:0];
        }
    }

    NSLog(@"%@", line);
    [self appendDiagnosticLine:line];
}

- (NSString *)currentLog {
    @synchronized (self) {
        return [self.logLines componentsJoinedByString:@"\n"];
    }
}

- (void)clearLog {
    @synchronized (self) {
        [self.logLines removeAllObjects];
    }
}

- (void)dealloc {
    [_logLines release];
    [super dealloc];
}

@end
