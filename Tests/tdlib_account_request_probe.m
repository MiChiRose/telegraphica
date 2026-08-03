#import <Foundation/Foundation.h>
#import "TGTDLibClient+Account.h"

@implementation TGTDLibClient
@end

@interface TGAccountProbeClient : TGTDLibClient {
    NSMutableArray *_capturedRequests;
}
@property (nonatomic, retain) NSMutableArray *capturedRequests;
@end

@implementation TGAccountProbeClient

@synthesize capturedRequests = _capturedRequests;

- (id)init {
    self = [super init];
    if (self) {
        self.capturedRequests = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [_capturedRequests release];
    [super dealloc];
}

- (NSString *)currentAuthorizationStatePreparingIfNeededWithTimeout:(NSTimeInterval)timeout
                                                               error:(NSError **)error {
    (void)timeout;
    (void)error;
    return @"ready";
}

- (NSString *)cachedAuthorizationStateSummary {
    return @"ready";
}

- (NSDictionary *)sendTDLibRequestAndWaitForExtra:(NSDictionary *)request
                                      extraPrefix:(NSString *)extraPrefix
                                          timeout:(NSTimeInterval)timeout
                                        errorCode:(NSInteger)errorCode
                                            error:(NSError **)error {
    (void)extraPrefix;
    (void)timeout;
    (void)errorCode;
    (void)error;
    [self.capturedRequests addObject:request];
    NSString *type = [request objectForKey:@"@type"];
    if ([type isEqualToString:@"getMe"]) {
        NSDictionary *usernames = [NSDictionary dictionaryWithObject:
                                   [NSArray arrayWithObject:@"telegraphica"]
                                                              forKey:@"active_usernames"];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"user", @"@type",
                [NSNumber numberWithLongLong:42], @"id",
                @"Tele", @"first_name",
                @"Graphica", @"last_name",
                usernames, @"usernames",
                @"12345", @"phone_number",
                nil];
    }
    if ([type isEqualToString:@"getUserFullInfo"]) {
        NSDictionary *bio = [NSDictionary dictionaryWithObject:@"Legacy Telegram client"
                                                          forKey:@"text"];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"userFullInfo", @"@type", bio, @"bio", nil];
    }
    if ([type isEqualToString:@"getActiveSessions"]) {
        NSDictionary *session = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithLongLong:77], @"id",
                                 [NSNumber numberWithLongLong:77], @"session_id",
                                 [NSNumber numberWithInteger:1234], @"last_active_date",
                                 [NSNumber numberWithBool:YES], @"is_current",
                                 @"Telegraphica", @"application_name",
                                 @"OS X", @"platform",
                                 @"Minsk", @"region",
                                 @"Belarus", @"country",
                                 nil];
        return [NSDictionary dictionaryWithObjectsAndKeys:
                @"sessions", @"@type",
                [NSArray arrayWithObject:session], @"sessions",
                [NSNumber numberWithInteger:365], @"inactive_session_ttl_days",
                nil];
    }
    return [NSDictionary dictionaryWithObject:@"ok" forKey:@"@type"];
}

- (NSError *)errorWithDescription:(NSString *)description code:(NSInteger)code {
    return [NSError errorWithDomain:@"TGAccountProbe"
                               code:code
                           userInfo:[NSDictionary dictionaryWithObject:description
                                                                forKey:NSLocalizedDescriptionKey]];
}

- (NSString *)summaryForAuthorizationStateObject:(id)object {
    return [object description];
}

- (NSString *)textFromFormattedTextObject:(id)object {
    id text = [object objectForKey:@"text"];
    return [text isKindOfClass:[NSString class]] ? text : @"";
}

- (NSDictionary *)photoInfoFromChatPhotoObject:(id)photoObject
                               downloadMissing:(BOOL)downloadMissing
                                       timeout:(NSTimeInterval)timeout
                            didRequestDownload:(BOOL *)didRequestDownload {
    (void)photoObject;
    (void)downloadMissing;
    (void)timeout;
    if (didRequestDownload) {
        *didRequestDownload = NO;
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLongLong:314], @"file_id",
            @"/tmp/telegraphica-profile-avatar.jpg", @"local_path",
            nil];
}

@end

static void TGAccountAssert(BOOL condition, NSString *message) {
    if (!condition) {
        fprintf(stderr, "TDLib account request probe failed: %s\n", [message UTF8String]);
        exit(1);
    }
}

static NSDictionary *TGAccountLastRequestOfType(NSArray *requests, NSString *type) {
    NSInteger index = (NSInteger)[requests count] - 1;
    for (; index >= 0; index--) {
        NSDictionary *request = [requests objectAtIndex:(NSUInteger)index];
        if ([[request objectForKey:@"@type"] isEqualToString:type]) {
            return request;
        }
    }
    return nil;
}

int main(void) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TGAccountProbeClient *client = [[[TGAccountProbeClient alloc] init] autorelease];

    NSDictionary *profile = [client currentUserProfileSummaryWithTimeout:2.0 error:NULL];
    TGAccountAssert([[profile objectForKey:@"display_name"] isEqualToString:@"Tele Graphica"],
                    @"profile display name");
    TGAccountAssert([[profile objectForKey:@"username"] isEqualToString:@"telegraphica"],
                    @"active username fallback");
    TGAccountAssert([[profile objectForKey:@"bio"] isEqualToString:@"Legacy Telegram client"],
                    @"profile bio");
    TGAccountAssert([[profile objectForKey:@"avatar_file_id"] longLongValue] == 314,
                    @"profile avatar file identifier");
    TGAccountAssert([[profile objectForKey:@"avatar_path"] isEqualToString:@"/tmp/telegraphica-profile-avatar.jpg"],
                    @"profile avatar local path");

    BOOL updated = [client updateCurrentUserFirstName:@"New"
                                             lastName:@"Name"
                                             username:@"newname"
                                                  bio:@"Bio"
                                              timeout:2.0
                                                error:NULL];
    TGAccountAssert(updated, @"profile update response");
    NSDictionary *setName = TGAccountLastRequestOfType(client.capturedRequests, @"setName");
    NSDictionary *setUsername = TGAccountLastRequestOfType(client.capturedRequests, @"setUsername");
    NSDictionary *setBio = TGAccountLastRequestOfType(client.capturedRequests, @"setBio");
    TGAccountAssert([[setName objectForKey:@"first_name"] isEqualToString:@"New"], @"setName first name");
    TGAccountAssert([[setUsername objectForKey:@"username"] isEqualToString:@"newname"], @"setUsername value");
    TGAccountAssert([[setBio objectForKey:@"bio"] isEqualToString:@"Bio"], @"setBio value");

    NSString *photoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"telegraphica-profile-probe.jpg"];
    [[NSData dataWithBytes:"x" length:1] writeToFile:photoPath atomically:YES];
    TGAccountAssert([client setCurrentUserProfilePhotoAtPath:photoPath timeout:2.0 error:NULL],
                    @"profile photo response");
    NSDictionary *photoRequest = TGAccountLastRequestOfType(client.capturedRequests, @"setProfilePhoto");
    NSDictionary *photo = [photoRequest objectForKey:@"photo"];
    NSDictionary *inputFile = [photo objectForKey:@"photo"];
    TGAccountAssert([[photo objectForKey:@"@type"] isEqualToString:@"inputChatPhotoStatic"],
                    @"static profile photo type");
    TGAccountAssert([[inputFile objectForKey:@"path"] isEqualToString:photoPath],
                    @"profile photo local path");
    [[NSFileManager defaultManager] removeItemAtPath:photoPath error:NULL];

    NSDictionary *sessions = [client activeSessionsSummaryWithTimeout:2.0 error:NULL];
    NSArray *sessionItems = [sessions objectForKey:@"sessions"];
    TGAccountAssert([sessionItems count] == 1, @"active session count");
    NSDictionary *session = [sessionItems objectAtIndex:0];
    TGAccountAssert([[session objectForKey:@"location"] isEqualToString:@"Minsk, Belarus"],
                    @"session location fallback");
    TGAccountAssert([[session objectForKey:@"is_current"] boolValue], @"current session flag");

    TGAccountAssert([client terminateActiveSessionWithID:[NSNumber numberWithLongLong:77]
                                                 timeout:2.0
                                                   error:NULL],
                    @"terminate session response");
    NSDictionary *terminate = TGAccountLastRequestOfType(client.capturedRequests, @"terminateSession");
    TGAccountAssert([[terminate objectForKey:@"session_id"] longLongValue] == 77,
                    @"terminate session identifier");

    printf("TDLib account request probe passed.\n");
    [pool drain];
    return 0;
}
